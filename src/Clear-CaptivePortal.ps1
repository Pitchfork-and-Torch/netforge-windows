#Requires -Version 5.1
<#
.SYNOPSIS
  Captive-portal recovery: probe, relax DNS/DoH, optional auto-restore.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Restore,
    [switch]$ProbeOnly,
    [switch]$NoAutoRestore
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
$ConfigFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $Root 'config\defaults.psd1' }
$cfg = if (Test-Path $ConfigFile) { Import-PowerShellDataFile $ConfigFile } else {
    @{ AppName = 'NetForge'; CaptivePortalDns = @('1.1.1.1', '8.8.8.8'); CaptiveAutoRestoreSeconds = 900
       CaptiveProbeUrls = @('http://captive.apple.com/hotspot-detect.html', 'http://connectivitycheck.gstatic.com/generate_204', 'http://www.msftconnecttest.com/connecttest.txt') }
}
$dataDir = Join-Path $env:LOCALAPPDATA $cfg.AppName
$stateFile = Join-Path $dataDir 'captive-portal-state.json'
$log = Join-Path $dataDir 'network-auto.log'
$scriptPath = Join-Path $Root 'src\NetworkAuto.ps1'
$urls = if ($cfg.CaptiveProbeUrls) { @($cfg.CaptiveProbeUrls) } else {
    @('http://captive.apple.com/hotspot-detect.html', 'http://connectivitycheck.gstatic.com/generate_204', 'http://www.msftconnecttest.com/connecttest.txt')
}

function Write-CPLog([string]$m) {
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
    Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] captive: $m" -ErrorAction SilentlyContinue
}

function Test-CaptiveProbes {
    $results = @()
    foreach ($u in $urls) {
        $item = [ordered]@{ url = $u; ok = $false; status = $null; note = '' }
        try {
            $resp = Invoke-WebRequest -Uri $u -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 5 -ErrorAction Stop
            $item.status = [int]$resp.StatusCode
            $item.ok = ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400)
            if ($resp.StatusCode -eq 511) { $item.note = 'network authentication required (511)'; $item.ok = $false }
        } catch {
            $item.note = $_.Exception.Message
            if ($item.note -match 'redirect|302|301|307|308') { $item.note = 'redirect (possible portal)'; $item.ok = $false }
        }
        $results += [pscustomobject]$item
    }
    return $results
}

if ($Restore) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { Write-Error 'Restore requires Administrator.'; exit 1 }
    Write-Host 'Restoring NetForge policy via NetworkAuto.ps1 ...' -ForegroundColor Cyan
    & $scriptPath -Trigger captive-restore -ConfigPath $ConfigFile
    if (Test-Path $stateFile) { Remove-Item $stateFile -Force -ErrorAction SilentlyContinue }
    schtasks /Delete /TN "$($cfg.AppName)-CaptiveRestore" /F 2>$null | Out-Null
    Write-Host 'Restore complete.' -ForegroundColor Green
    exit 0
}

Write-Host 'NetForge captive-portal recovery' -ForegroundColor Cyan
Write-Host 'Probing connectivity endpoints...' -ForegroundColor DarkGray
$probe = Test-CaptiveProbes
foreach ($r in $probe) {
    $color = if ($r.ok) { 'Green' } else { 'Yellow' }
    Write-Host ("  [{0}] {1}  {2}" -f $(if ($r.ok) { 'ok' } else { '!!' }), $r.url, $(if ($r.status) { "HTTP $($r.status)" } else { $r.note })) -ForegroundColor $color
}
if ($ProbeOnly) {
    Write-Host 'Probe-only; no changes.' -ForegroundColor Cyan
    exit 0
}

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$p = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Apply requires Administrator. Use -ProbeOnly without elevation.'
    exit 1
}

if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$saved = @{ timestamp = (Get-Date).ToString('o'); adapters = @() }
Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
    $if = $_.Name
    $dns = @(Get-DnsClientServerAddress -InterfaceAlias $if -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ServerAddresses)
    $saved.adapters += @{ name = $if; dns = $dns }
    Write-Host "  adapter: $if"
    foreach ($srv in @('1.1.1.1', '1.0.0.1', '8.8.8.8')) {
        try { Set-DnsClientDohServerAddress -ServerAddress $srv -AllowFallbackToUdp $true -ErrorAction SilentlyContinue } catch {}
    }
    try {
        Set-DnsClientServerAddress -InterfaceAlias $if -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Host '    DNS reset to DHCP' -ForegroundColor Green
    } catch {
        $plain = if ($cfg.CaptivePortalDns) { @($cfg.CaptivePortalDns) } else { @('1.1.1.1', '8.8.8.8') }
        Set-DnsClientServerAddress -InterfaceAlias $if -ServerAddresses $plain -ErrorAction SilentlyContinue
        Write-Host "    DNS temporary plaintext: $($plain -join ', ')" -ForegroundColor Yellow
    }
}
$saved | ConvertTo-Json -Depth 5 | Set-Content -Path $stateFile -Encoding UTF8
Write-CPLog "relaxed DNS/DoH; state=$stateFile"
Clear-DnsClientCache -ErrorAction SilentlyContinue

$secs = if ($cfg.CaptiveAutoRestoreSeconds) { [int]$cfg.CaptiveAutoRestoreSeconds } else { 900 }
if (-not $NoAutoRestore -and $secs -gt 0) {
    $task = "$($cfg.AppName)-CaptiveRestore"
    $tr = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Restore -ConfigPath `"$ConfigFile`""
    schtasks /Delete /TN $task /F 2>$null | Out-Null
    $when = (Get-Date).AddSeconds($secs).ToString('HH:mm')
    schtasks /Create /TN $task /TR $tr /SC ONCE /ST $when /RL HIGHEST /F 2>$null | Out-Null
    Write-Host "Auto-restore scheduled in ~${secs}s (task $task)." -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  1. Open http://captive.apple.com or http://neverssl.com'
Write-Host '  2. Complete portal login'
Write-Host '  3. Restore:  .\Clear-CaptivePortal.ps1 -Restore'
