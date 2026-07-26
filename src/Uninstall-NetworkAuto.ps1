#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Removes NetForge scheduled tasks; optional best-effort settings revert.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [switch]$RevertSettings
)

$cfgPath = Join-Path $RepoRoot 'config\defaults.psd1'
$cfg = if (Test-Path $cfgPath) { Import-PowerShellDataFile $cfgPath } else { @{ AppName = 'NetForge'; QosPrefix = 'NetForge-Priority' } }
$app = $cfg.AppName

schtasks /Delete /TN "$app-NetworkAuto-Logon" /F 2>$null | Out-Null
schtasks /Delete /TN "$app-NetworkAuto-Connect" /F 2>$null | Out-Null
schtasks /Delete /TN "$app-CaptiveRestore" /F 2>$null | Out-Null
Write-Host "$app scheduled tasks removed." -ForegroundColor Yellow

if ($RevertSettings) {
    Write-Host 'Best-effort settings revert...' -ForegroundColor Cyan
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object {
        try {
            Set-DnsClientServerAddress -InterfaceAlias $_.Name -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-Host "  DNS DHCP: $($_.Name)"
        } catch {}
    }
    foreach ($svc in @('LanmanServer', 'FDResPub', 'SSDPSRV', 'sshd')) {
        try { Set-Service -Name $svc -StartupType Manual -ErrorAction SilentlyContinue; Write-Host "  service Manual: $svc" } catch {}
    }
    foreach ($qos in Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($cfg.QosPrefix)-*" }) {
        Remove-NetQosPolicy -InputObject $qos -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "  removed QoS $($qos.Name)"
    }
    foreach ($srv in @('1.1.1.1', '1.0.0.1', '8.8.8.8')) {
        try { Set-DnsClientDohServerAddress -ServerAddress $srv -AllowFallbackToUdp $true -ErrorAction SilentlyContinue } catch {}
    }
    Write-Host 'Revert finished (partial). Reboot recommended.' -ForegroundColor Yellow
} else {
    Write-Host 'Settings not reverted. Use -RevertSettings for best-effort restore.'
}
