#Requires -Version 5.1
<#
.SYNOPSIS
  Read-only NetForge health report (no system changes).
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [switch]$Json,
    [string]$HtmlPath,
    [switch]$SkipDnsProbe
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $PSScriptRoot
$ConfigFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $Root 'config\defaults.psd1' }
$cfg = if (Test-Path $ConfigFile) { Import-PowerShellDataFile $ConfigFile } else {
    @{ AppName = 'NetForge'; DnsServers = @('1.1.1.1', '1.0.0.1', '8.8.8.8') }
}
$version = (Get-Content (Join-Path $Root 'VERSION') -ErrorAction SilentlyContinue | Select-Object -First 1)
$dataDir = Join-Path $env:LOCALAPPDATA ($cfg.AppName)
$log = Join-Path $dataDir 'network-auto.log'
$lastRunPath = Join-Path $dataDir 'last-run.json'

$report = [ordered]@{
    tool = 'NetForge'; platform = 'windows'; version = $version
    timestamp = (Get-Date).ToString('o'); configPath = $ConfigFile; dataDir = $dataDir
    lastRun = $null; adapters = @(); vpnAdapters = @(); doh = @(); firewall = @()
    services = @(); dnsLatencyMs = @(); tcpHints = @(); logTail = @(); health = 'unknown'; healthNotes = @()
}
if (Test-Path $lastRunPath) {
    try { $report.lastRun = Get-Content $lastRunPath -Raw | ConvertFrom-Json } catch {}
}

function Test-VpnDesc([string]$d) {
    $d -match 'VPN|TAP|TUN|Wintun|WireGuard|OpenVPN|AnyConnect|GlobalProtect|Zscaler|Tailscale|WARP|Mullvad|Proton'
}

foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })) {
    if (Test-VpnDesc "$($a.Name) $($a.InterfaceDescription)") {
        $report.vpnAdapters += [ordered]@{ name = $a.Name; description = $a.InterfaceDescription }
        continue
    }
    if ($a.InterfaceDescription -match 'Hyper-V|WSL|Loopback|vEthernet|Bluetooth') { continue }
    $metric = (Get-NetIPInterface -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).InterfaceMetric
    $dns = @((Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses)
    $report.adapters += [ordered]@{
        name = $a.Name; status = "$($a.Status)"; metric = $metric; dns = $dns
        description = $a.InterfaceDescription; linkSpeed = "$($a.LinkSpeed)"
    }
}

try {
    Get-DnsClientDohServerAddress -ErrorAction Stop | ForEach-Object {
        $report.doh += [ordered]@{ server = $_.ServerAddress; template = $_.DohTemplate; autoUpgrade = $_.AutoUpgrade }
    }
} catch {}

Get-NetFirewallProfile -ErrorAction SilentlyContinue | ForEach-Object {
    $report.firewall += [ordered]@{ name = $_.Name; inbound = "$($_.DefaultInboundAction)"; outbound = "$($_.DefaultOutboundAction)" }
}
foreach ($svcName in @('sshd', 'LanmanServer', 'FDResPub', 'SSDPSRV')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc) { $report.services += [ordered]@{ name = $svc.Name; status = "$($svc.Status)"; startType = "$($svc.StartType)" } }
    else { $report.services += [ordered]@{ name = $svcName; status = 'not-installed'; startType = '' } }
}

if (-not $SkipDnsProbe) {
    $targets = @($cfg.DnsServers); if (-not $targets) { $targets = @('1.1.1.1', '8.8.8.8') }
    foreach ($ip in $targets) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Resolve-DnsName -Name 'example.com' -Server $ip -Type A -DnsOnly -ErrorAction Stop
            $sw.Stop()
            $report.dnsLatencyMs += [ordered]@{ server = $ip; ms = [int]$sw.ElapsedMilliseconds; ok = $true }
        } catch {
            $report.dnsLatencyMs += [ordered]@{ server = $ip; ms = $null; ok = $false; error = $_.Exception.Message }
        }
    }
}

try {
    netsh int tcp show global 2>$null | Select-String -Pattern 'Receive Window|RSS|ECN|Fast Open|Timestamps|RSC' |
        ForEach-Object { $report.tcpHints += $_.Line.Trim() }
} catch {}

if (Test-Path $log) { $report.logTail = @(Get-Content $log -Tail 8 -ErrorAction SilentlyContinue) }

$issues = @()
if (-not $report.adapters) { $issues += 'no-active-adapters' }
if (-not $report.lastRun) { $issues += 'never-applied' }
$failedDns = @($report.dnsLatencyMs | Where-Object { -not $_.ok })
if ($failedDns.Count -gt 0 -and $failedDns.Count -eq @($report.dnsLatencyMs).Count -and @($report.dnsLatencyMs).Count -gt 0) {
    $issues += 'dns-probes-failed'
}
$report.health = if ($issues.Count -eq 0) { 'ok' } elseif ($issues -contains 'no-active-adapters') { 'degraded' } else { 'attention' }
$report.healthNotes = $issues

if ($Json) { $report | ConvertTo-Json -Depth 6; exit 0 }

function Write-Section([string]$Title) { Write-Host ""; Write-Host "=== $Title ===" -ForegroundColor Cyan }

Write-Host "NetForge status (read-only) - $($report.timestamp)" -ForegroundColor Green
Write-Host "Version: $version  Health: $($report.health)" -ForegroundColor $(if ($report.health -eq 'ok') { 'Green' } else { 'Yellow' })
Write-Host "Config: $ConfigFile"

Write-Section 'Last apply'
if ($report.lastRun) {
    Write-Host "  $($report.lastRun.timestamp)  trigger=$($report.lastRun.trigger)"
} else {
    Write-Host '  (no last-run.json - install/apply has not completed yet)' -ForegroundColor Yellow
}

Write-Section 'Active adapters'
if (-not $report.adapters) { Write-Host '  (none detected)' -ForegroundColor Yellow }
else {
    foreach ($a in $report.adapters) {
        Write-Host ("  {0,-20} metric={1}  speed={2}  DNS=[{3}]" -f $a.name, $a.metric, $a.linkSpeed, ($a.dns -join ', '))
        Write-Host ("    {0}" -f $a.description) -ForegroundColor DarkGray
    }
}
if ($report.vpnAdapters.Count -gt 0) {
    Write-Section 'VPN / tunnel adapters (skipped when RespectVpn=true)'
    foreach ($v in $report.vpnAdapters) { Write-Host ("  {0} - {1}" -f $v.name, $v.description) -ForegroundColor DarkGray }
}

Write-Section 'DNS-over-HTTPS'
if (-not $report.doh) { Write-Host '  (none configured)' }
else { $report.doh | ForEach-Object { Write-Host ("  {0}  {1}" -f $_.server, $_.template) } }

Write-Section 'DNS latency'
if ($SkipDnsProbe) { Write-Host '  (skipped)' }
else {
    foreach ($d in $report.dnsLatencyMs) {
        if ($d.ok) { Write-Host ("  {0,-16} {1} ms" -f $d.server, $d.ms) -ForegroundColor Green }
        else { Write-Host ("  {0,-16} FAIL" -f $d.server) -ForegroundColor Yellow }
    }
}

Write-Section 'Firewall profiles'
$report.firewall | ForEach-Object { Write-Host ("  {0,-10} inbound={1,-12} outbound={2}" -f $_.name, $_.inbound, $_.outbound) }
Write-Section 'Services'
$report.services | ForEach-Object { Write-Host ("  {0,-14} {1,-12} {2}" -f $_.name, $_.status, $_.startType) }
Write-Section 'TCP hints'
$report.tcpHints | ForEach-Object { Write-Host "  $_" }
Write-Section 'Log tail'
if ($report.logTail) { $report.logTail | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
else { Write-Host '  (no log yet)' -ForegroundColor Yellow }

if ($HtmlPath) {
    $rows = ($report.adapters | ForEach-Object { "<tr><td>$($_.name)</td><td>$($_.metric)</td><td>$($_.linkSpeed)</td><td>$($_.dns -join ', ')</td></tr>" }) -join "`n"
    $html = @"
<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"/><title>NetForge status</title>
<style>body{font-family:system-ui,sans-serif;background:#0b0f14;color:#e6edf3;margin:2rem}
h1{color:#7dd3fc}table{border-collapse:collapse;width:100%}td,th{border:1px solid #30363d;padding:.5rem}th{background:#161b22}</style></head>
<body><h1>NetForge status</h1><p>Version $version - Health $($report.health) - $($report.timestamp)</p>
<table><tr><th>Name</th><th>Metric</th><th>Speed</th><th>DNS</th></tr>$rows</table>
<p>Generated offline - no data left this machine.</p></body></html>
"@
    $dir = Split-Path -Parent $HtmlPath
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $HtmlPath -Value $html -Encoding UTF8
    Write-Host ""; Write-Host "HTML report: $HtmlPath" -ForegroundColor Green
}

Write-Host ""; Write-Host 'No settings were changed.' -ForegroundColor Green
