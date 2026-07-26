#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs NetForge scheduled tasks for automatic network optimization.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $RepoRoot 'src\NetworkAuto.ps1'
$cfgPath = Join-Path $RepoRoot 'config\defaults.psd1'

if (-not (Test-Path $scriptPath)) {
    throw "NetworkAuto.ps1 not found at: $scriptPath"
}

$cfg = Import-PowerShellDataFile -Path $cfgPath
$app = $cfg.AppName
$taskLogon = "$app-NetworkAuto-Logon"
$taskConnect = "$app-NetworkAuto-Connect"
$psArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`" -ConfigPath `"$cfgPath`""

schtasks /Delete /TN $taskLogon /F 2>$null | Out-Null
schtasks /Delete /TN $taskConnect /F 2>$null | Out-Null

schtasks /Create /TN $taskLogon `
    /TR "powershell.exe $psArgs -Trigger logon" `
    /SC ONLOGON /DELAY 0000:30 /RL HIGHEST /F | Out-Null

schtasks /Create /TN $taskConnect `
    /TR "powershell.exe $psArgs -Trigger network-connect" `
    /SC ONEVENT /EC Microsoft-Windows-NetworkProfile/Operational `
    /MO "*[System[Provider[@Name='Microsoft-Windows-NetworkProfile'] and EventID=10000]]" `
    /RL HIGHEST /DELAY 0000:10 /F | Out-Null

& $scriptPath -Trigger install -ConfigPath $cfgPath

$dataDir = Join-Path $env:LOCALAPPDATA $app
$log = Join-Path $dataDir 'network-auto.log'
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Installed tasks: $taskLogon, $taskConnect"

Write-Host ""
Write-Host "$app installed successfully." -ForegroundColor Green
Write-Host "  Logon task:    $taskLogon (30s after sign-in)"
Write-Host "  Connect task:  $taskConnect (on any network join)"
Write-Host "  Log file:      $log"
Write-Host ""
Write-Host "Run manually:  powershell -ExecutionPolicy Bypass -File `"$scriptPath`""
Write-Host ""