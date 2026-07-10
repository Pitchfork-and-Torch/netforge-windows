#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only health report for NetForge on Windows (no system changes).
.DESCRIPTION
    Prints adapter, DNS, DoH, firewall profile, and service state so you can
    verify NetForge without re-applying tuning.
.EXAMPLE
    .\src\Get-NetForgeStatus.ps1
#>
[CmdletBinding()]
param(
    [string]$ConfigPath
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
$ConfigFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $Root 'config\defaults.psd1' }
$cfg = if (Test-Path $ConfigFile) {
    Import-PowerShellDataFile -Path $ConfigFile
} else {
    @{ AppName = 'NetForge'; DnsServers = @('1.1.1.1', '1.0.0.1', '8.8.8.8') }
}

$dataDir = Join-Path $env:LOCALAPPDATA ($cfg.AppName)
$log = Join-Path $dataDir 'network-auto.log'

function Write-Section([string]$Title) {
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

Write-Host "NetForge status (read-only) — $(Get-Date -Format o)" -ForegroundColor Green
Write-Host "Config: $ConfigFile"

Write-Section 'Active adapters'
$adapters = Get-NetAdapter -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch 'Virtual|VPN|Hyper-V|WSL|Loopback|TAP|TUN|vEthernet|Bluetooth'
    }
if (-not $adapters) {
    Write-Host '  (none detected)' -ForegroundColor Yellow
} else {
    foreach ($a in $adapters) {
        $metric = (Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
        $dns = (Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ', '
        Write-Host ("  {0,-20} {1,-10} metric={2}  DNS=[{3}]" -f $a.Name, $a.Status, $metric, $dns)
        Write-Host ("    {0}" -f $a.InterfaceDescription) -ForegroundColor DarkGray
    }
}

Write-Section 'DNS-over-HTTPS (DoH) servers'
try {
    $doh = Get-DnsClientDohServerAddress -ErrorAction Stop
    if (-not $doh) { Write-Host '  (none configured)' }
    else {
        $doh | ForEach-Object {
            Write-Host ("  {0}  template={1}  autoUpgrade={2}" -f $_.ServerAddress, $_.DohTemplate, $_.AutoUpgrade)
        }
    }
} catch {
    Write-Host "  (unavailable: $($_.Exception.Message))" -ForegroundColor Yellow
}

Write-Section 'Firewall profiles'
Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ("  {0,-10} inbound={1,-12} outbound={2}" -f $_.Name, $_.DefaultInboundAction, $_.DefaultOutboundAction)
}

Write-Section 'Hardening-related services'
foreach ($svcName in @('sshd', 'LanmanServer', 'FDResPub', 'SSDPSRV')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host ("  {0,-14} status={1,-12} start={2}" -f $svc.Name, $svc.Status, $svc.StartType)
    } else {
        Write-Host ("  {0,-14} (not installed)" -f $svcName) -ForegroundColor DarkGray
    }
}

Write-Section 'TCP (sample global)'
try {
    $tcp = netsh int tcp show global 2>$null
    $tcp | Select-String -Pattern 'Receive Window|RSS|ECN|Fast Open|Timestamps|RSC' | ForEach-Object {
        Write-Host ("  {0}" -f $_.Line.Trim())
    }
} catch {
    Write-Host '  (netsh unavailable)' -ForegroundColor Yellow
}

Write-Section 'Runtime data'
Write-Host "  Data dir: $dataDir"
if (Test-Path $log) {
    $len = (Get-Item $log).Length
    $tail = Get-Content $log -Tail 5 -ErrorAction SilentlyContinue
    Write-Host "  Log: $log ($len bytes)"
    Write-Host '  Last log lines:' -ForegroundColor DarkGray
    $tail | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
} else {
    Write-Host '  Log: (not created yet — run Install-NetworkAuto.ps1 first)' -ForegroundColor Yellow
}

Write-Host ""
Write-Host 'No settings were changed.' -ForegroundColor Green
