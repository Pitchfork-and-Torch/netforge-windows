#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes NetForge scheduled tasks (does not revert system settings).
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

$cfgPath = Join-Path $RepoRoot 'config\defaults.psd1'
$cfg = Import-PowerShellDataFile -Path $cfgPath
$app = $cfg.AppName

schtasks /Delete /TN "$app-NetworkAuto-Logon" /F 2>$null | Out-Null
schtasks /Delete /TN "$app-NetworkAuto-Connect" /F 2>$null | Out-Null

Write-Host "$app scheduled tasks removed." -ForegroundColor Yellow
Write-Host "Previous DNS, firewall, and adapter settings were not reverted."
Write-Host "Reboot or adjust settings manually if you want to restore defaults."