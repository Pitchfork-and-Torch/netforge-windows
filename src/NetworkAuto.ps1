#Requires -Version 5.1
<#
.SYNOPSIS
  NetForge Windows apply - prefer Ethernet, DoH, TCP tuning, optional hardening.
.PARAMETER DryRun
  Preview planned actions without changing the system.
#>
[CmdletBinding()]
param(
    [string]$Trigger = 'manual',
    [string]$ConfigPath,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
$script:DryRun = [bool]$DryRun
$script:Root = Split-Path -Parent $PSScriptRoot
$script:ConfigFile = if ($ConfigPath) { $ConfigPath } else { Join-Path $script:Root 'config\defaults.psd1' }
$script:Plan = New-Object System.Collections.Generic.List[string]

if (-not $script:DryRun) {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error 'NetworkAuto.ps1 requires Administrator (or use -DryRun).'
        exit 1
    }
}

function Import-NetForgeConfig {
    if (Test-Path $script:ConfigFile) { return Import-PowerShellDataFile $script:ConfigFile }
    return @{
        AppName = 'NetForge'; DnsServers = @('1.1.1.1', '1.0.0.1', '8.8.8.8')
        QosPrefix = 'NetForge-Priority'; EthernetMetric = 5; WiFiMetricAlone = 10; WiFiMetricWithEth = 50
        LockSeconds = 90; MaxLogLines = 2000; DisableSshd = $true; DisableFileShare = $true
        HighPerformancePower = $true; RespectVpn = $true
    }
}

function Add-Plan([string]$m) {
    $script:Plan.Add($m) | Out-Null
    if ($script:DryRun) { Write-Host "  [would] $m" -ForegroundColor Yellow }
}
function Invoke-NF([string]$Description, [scriptblock]$Action) {
    Add-Plan $Description
    if (-not $script:DryRun) { & $Action }
}

$cfg = Import-NetForgeConfig
$respectVpn = if ($null -ne $cfg.RespectVpn) { [bool]$cfg.RespectVpn } else { $true }
$dataDir = Join-Path $env:LOCALAPPDATA $cfg.AppName
$log = Join-Path $dataDir 'network-auto.log'
$lock = Join-Path $dataDir 'network-auto.lock'
$lastRun = Join-Path $dataDir 'last-run.json'

function Write-NetForgeLog([string]$Message) {
    if ($script:DryRun) { return }
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
    Add-Content -Path $log -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ErrorAction SilentlyContinue
}

function Test-IsVpnAdapter($Adapter) {
    "$($Adapter.Name) $($Adapter.InterfaceDescription)" -match 'VPN|TAP|TUN|Wintun|WireGuard|OpenVPN|NordLynx|AnyConnect|GlobalProtect|Zscaler|Fortinet|Tailscale|ZeroTier|WARP|warp|Mullvad|ProtonVPN|Outline'
}
function Test-IsWirelessAdapter($Adapter) {
    $Adapter.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN' -or $Adapter.MediaType -eq 'Native 802.11' -or $Adapter.Name -match 'Wi-?Fi'
}
function Test-IsEthernetAdapter($Adapter) {
    -not (Test-IsWirelessAdapter $Adapter) -and -not (Test-IsVpnAdapter $Adapter) -and (
        $Adapter.InterfaceDescription -match 'Ethernet|Realtek|Intel.*I2|USB.*Ethernet|2\.5G|Gigabit|LAN' -or $Adapter.MediaType -match '802\.3'
    )
}
function Get-ActiveNetAdaptersSafe {
    $result = @()
    foreach ($a in @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })) {
        if ($a.InterfaceDescription -match 'Hyper-V|WSL|Loopback|vEthernet|Bluetooth') { continue }
        if ($respectVpn -and (Test-IsVpnAdapter $a)) { Write-NetForgeLog "RespectVpn: skip $($a.Name)"; continue }
        if (-not (Test-IsWirelessAdapter $a) -and -not (Test-IsEthernetAdapter $a)) {
            if ($a.InterfaceDescription -match 'Virtual|TAP|TUN') { continue }
        }
        $result += $a
    }
    return $result
}

if (-not $script:DryRun) {
    if (Test-Path $lock) {
        $age = (Get-Date) - (Get-Item $lock).LastWriteTime
        if ($age.TotalSeconds -lt $cfg.LockSeconds) { exit 0 }
    }
    New-Item -Path $lock -ItemType File -Force | Out-Null
}

try {
    Write-NetForgeLog "=== $($cfg.AppName) v2 trigger=$Trigger dryRun=$($script:DryRun) respectVpn=$respectVpn ==="
    if ($script:DryRun) { Write-Host "NetForge dry-run (no changes) - config: $script:ConfigFile" -ForegroundColor Cyan }

    Invoke-NF 'Abort pending shutdown (shutdown /a)' { shutdown /a 2>$null | Out-Null }

    Invoke-NF 'Delivery Optimization: DODownloadMode=0' {
        $doPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
        if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
        New-ItemProperty -Path $doPath -Name 'DODownloadMode' -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $doPath -Name 'DOMaxDownloadBandwidth' -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $doPath -Name 'DOMaxUploadBandwidth' -Value 0 -PropertyType DWord -Force | Out-Null
    }

    Invoke-NF 'Multimedia: NetworkThrottlingIndex max / SystemResponsiveness 0' {
        $mmPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        New-ItemProperty -Path $mmPath -Name 'NetworkThrottlingIndex' -Value 0xffffffff -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $mmPath -Name 'SystemResponsiveness' -Value 0 -PropertyType DWord -Force | Out-Null
    }

    if ($cfg.DisableFileShare) {
        Invoke-NF 'Hardening: disable File/Printer Sharing, Network Discovery, LanmanServer, FDResPub' {
            foreach ($g in @('File and Printer Sharing', 'Network Discovery', 'Remote Assistance')) {
                netsh advfirewall firewall set rule group="$g" new enable=No 2>$null | Out-Null
            }
            foreach ($svc in @('LanmanServer', 'FDResPub')) {
                Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
            }
        }
    }
    if ($cfg.DisableSshd) {
        Invoke-NF 'Hardening: disable OpenSSH Server (sshd)' {
            Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
            Set-Service -Name sshd -StartupType Disabled -ErrorAction SilentlyContinue
            Get-NetFirewallRule -DisplayName 'OpenSSH*' -ErrorAction SilentlyContinue |
                ForEach-Object { Disable-NetFirewallRule -InputObject $_ -ErrorAction SilentlyContinue }
        }
    }

    Invoke-NF 'Disable NetBIOS; LLMNR off; SSDP disabled' {
        Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue |
            ForEach-Object {
                Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]2 } -ErrorAction SilentlyContinue | Out-Null
            }
        $llmnrPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
        if (-not (Test-Path $llmnrPath)) { New-Item -Path $llmnrPath -Force | Out-Null }
        New-ItemProperty -Path $llmnrPath -Name 'EnableMulticast' -Value 0 -PropertyType DWord -Force | Out-Null
        Stop-Service SSDPSRV -Force -ErrorAction SilentlyContinue
        Set-Service SSDPSRV -StartupType Disabled -ErrorAction SilentlyContinue
    }

    Invoke-NF 'TCP globals: autotune, ECN, Fast Open, RSS, RSC; timestamps off' {
        netsh int tcp set global autotuninglevel=normal | Out-Null
        netsh int tcp set global ecncapability=enabled | Out-Null
        netsh int tcp set global fastopen=enabled | Out-Null
        netsh int tcp set global fastopenfallback=enabled | Out-Null
        netsh int tcp set global rss=enabled | Out-Null
        netsh int tcp set global rsc=enabled | Out-Null
        netsh int tcp set global timestamps=disabled | Out-Null
        netsh int tcp set global nonsackrttresiliency=disabled | Out-Null
        netsh int tcp set global initialrto=2000 | Out-Null
        netsh int tcp set global maxsynretransmissions=2 | Out-Null
        netsh int udp set global uro=enabled 2>$null | Out-Null
        try { Set-NetTCPSetting -SettingName InternetCustom -CongestionProvider CTCP -ErrorAction Stop } catch {}
    }

    if ($cfg.HighPerformancePower) {
        Invoke-NF 'Power plan: High Performance' {
            powercfg /SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
        }
    }

    Invoke-NF 'DoH templates for 1.1.1.1 / 1.0.0.1 / 8.8.8.8' {
        Set-DnsClientDohServerAddress -ServerAddress '1.1.1.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        Set-DnsClientDohServerAddress -ServerAddress '1.0.0.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
        Set-DnsClientDohServerAddress -ServerAddress '8.8.8.8' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
    }

    Invoke-NF 'Firewall: Private log blocked; Public block inbound' {
        Set-NetFirewallProfile -Profile Private -LogBlocked True -LogAllowed False -LogMaxSizeKilobytes 16384 -ErrorAction SilentlyContinue
        Set-NetFirewallProfile -Profile Public -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction SilentlyContinue
    }

    Invoke-NF "QoS $($cfg.QosPrefix)-Port{80,443,853}" {
        try {
            foreach ($qos in Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "$($cfg.QosPrefix)-*" }) {
                Remove-NetQosPolicy -InputObject $qos -Confirm:$false -ErrorAction SilentlyContinue
            }
            foreach ($port in 80, 443, 853) {
                $qosName = "$($cfg.QosPrefix)-Port$port"
                if (-not (Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $qosName })) {
                    New-NetQosPolicy -Name $qosName -AppPathNameMatchCondition '*' -IPDstPortMatchCondition ([uint16]$port) -ThrottleRateActionBitsPerSecond 0 -PriorityValue8021Action 7 -ErrorAction Stop | Out-Null
                }
            }
        } catch { Write-NetForgeLog "QoS skipped: $($_.Exception.Message)" }
    }

    $adapters = @()
    if ($script:DryRun) {
        $adapters = @(Get-ActiveNetAdaptersSafe)
    } else {
        for ($i = 0; $i -lt 15; $i++) {
            $adapters = @(Get-ActiveNetAdaptersSafe)
            if ($adapters.Count -gt 0) { break }
            Start-Sleep -Seconds 3
        }
    }
    $eth = @($adapters | Where-Object { Test-IsEthernetAdapter $_ })
    $wifi = @($adapters | Where-Object { Test-IsWirelessAdapter $_ })
    Add-Plan "Active adapters: total=$($adapters.Count) eth=$($eth.Count) wifi=$($wifi.Count) RespectVpn=$respectVpn"
    Write-NetForgeLog "Adapters: $($adapters.Count) eth=$($eth.Count) wifi=$($wifi.Count)"

    foreach ($a in $eth) {
        $name = $a.Name
        Invoke-NF "Ethernet [$name] metric=$($cfg.EthernetMetric) + DNS" {
            Enable-NetAdapter -Name $name -Confirm:$false -ErrorAction SilentlyContinue
            Set-NetIPInterface -InterfaceAlias $name -AddressFamily IPv4 -InterfaceMetric $cfg.EthernetMetric -ErrorAction SilentlyContinue
            Set-NetIPInterface -InterfaceAlias $name -AddressFamily IPv6 -InterfaceMetric $cfg.EthernetMetric -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceAlias $name -ServerAddresses $cfg.DnsServers -ErrorAction SilentlyContinue
            try { Set-NetConnectionProfile -InterfaceAlias $name -NetworkCategory Private -ErrorAction Stop } catch {}
            Write-NetForgeLog "Ethernet [$name] metric=$($cfg.EthernetMetric)"
        }
    }
    foreach ($a in $wifi) {
        $name = $a.Name
        $metric = if ($eth.Count -gt 0) { $cfg.WiFiMetricWithEth } else { $cfg.WiFiMetricAlone }
        Invoke-NF "Wi-Fi [$name] metric=$metric + DNS + advanced props" {
            Set-NetIPInterface -InterfaceAlias $name -AddressFamily IPv4 -InterfaceMetric $metric -ErrorAction SilentlyContinue
            Set-NetIPInterface -InterfaceAlias $name -AddressFamily IPv6 -InterfaceMetric $metric -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceAlias $name -ServerAddresses $cfg.DnsServers -ErrorAction SilentlyContinue
            try { Set-NetConnectionProfile -InterfaceAlias $name -NetworkCategory Private -ErrorAction Stop } catch {}
            foreach ($advProp in @(
                @{ DisplayName = 'MIMO Power Save Mode'; DisplayValue = 'No SMPS' }
                @{ DisplayName = 'Roaming Aggressiveness'; DisplayValue = '3. Medium' }
            )) {
                try { Set-NetAdapterAdvancedProperty -Name $name -DisplayName $advProp.DisplayName -DisplayValue $advProp.DisplayValue -NoRestart -ErrorAction Stop } catch {}
            }
            Write-NetForgeLog "Wi-Fi [$name] metric=$metric"
        }
    }

    Invoke-NF 'Clear-DnsClientCache' { Clear-DnsClientCache -ErrorAction SilentlyContinue }

    if (-not $script:DryRun) {
        if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
        @{
            timestamp = (Get-Date).ToString('o')
            trigger   = $Trigger
            version   = (Get-Content (Join-Path $script:Root 'VERSION') -ErrorAction SilentlyContinue | Select-Object -First 1)
            eth       = @($eth | ForEach-Object { $_.Name })
            wifi      = @($wifi | ForEach-Object { $_.Name })
        } | ConvertTo-Json | Set-Content -Path $lastRun -Encoding UTF8
        Write-NetForgeLog '=== complete ==='
    } else {
        Write-Host ""
        Write-Host "Dry-run complete: $($script:Plan.Count) planned action(s). No settings changed." -ForegroundColor Green
    }
} catch {
    Write-NetForgeLog "ERROR: $_"
    if ($script:DryRun) { Write-Host "ERROR: $_" -ForegroundColor Red }
} finally {
    if (-not $script:DryRun) { Remove-Item $lock -Force -ErrorAction SilentlyContinue }
}
