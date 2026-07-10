#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Applies network performance tuning and security hardening on Windows.
.DESCRIPTION
    Network-agnostic: discovers active Ethernet and Wi-Fi adapters at runtime.
    Safe to run repeatedly (logon, network connect, or manual).
#>
[CmdletBinding()]
param(
    [string]$Trigger = 'manual',
    [string]$ConfigPath
)

$ErrorActionPreference = 'Continue'

$script:Root = Split-Path -Parent $PSScriptRoot
if ($ConfigPath) {
    $script:ConfigFile = $ConfigPath
} else {
    $script:ConfigFile = Join-Path $script:Root 'config\defaults.psd1'
}

function Import-NetForgeConfig {
    if (Test-Path $script:ConfigFile) {
        return Import-PowerShellDataFile -Path $script:ConfigFile
    }
    return @{
        AppName           = 'NetForge'
        DnsServers        = @('1.1.1.1', '1.0.0.1', '8.8.8.8')
        QosPrefix         = 'NetForge-Priority'
        EthernetMetric    = 5
        WiFiMetricAlone   = 10
        WiFiMetricWithEth = 50
        LockSeconds       = 90
        MaxLogLines       = 2000
        DisableSshd       = $true
        DisableFileShare  = $true
        HighPerformancePower = $true
    }
}

$cfg = Import-NetForgeConfig
$dataDir = Join-Path $env:LOCALAPPDATA $cfg.AppName
$log = Join-Path $dataDir 'network-auto.log'
$lock = Join-Path $dataDir 'network-auto.lock'

function Write-NetForgeLog {
    param([string]$Message)
    if (-not (Test-Path $dataDir)) {
        New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
    }
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Add-Content -Path $log -Value $line -ErrorAction SilentlyContinue
}

function Invoke-LogRotation {
    if (-not (Test-Path $log)) { return }
    try {
        $lines = Get-Content $log -ErrorAction Stop
        if ($lines.Count -gt $cfg.MaxLogLines) {
            $lines | Select-Object -Last $cfg.MaxLogLines | Set-Content $log -Encoding UTF8
        }
    } catch {}
}

function Get-ActiveNetAdapters {
    Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Status -eq 'Up' -and
            $_.InterfaceDescription -notmatch 'Virtual|VPN|Hyper-V|WSL|Loopback|TAP|TUN|vEthernet|Bluetooth'
        }
}

function Test-IsWirelessAdapter {
    param($Adapter)
    $Adapter.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN' -or
    $Adapter.MediaType -eq 'Native 802.11' -or
    $Adapter.Name -match 'Wi-?Fi'
}

function Test-IsEthernetAdapter {
    param($Adapter)
    $Adapter.InterfaceDescription -match 'Ethernet|Realtek|Intel.*I219|USB.*Ethernet|2\.5G|Gigabit' -and
    -not (Test-IsWirelessAdapter $Adapter)
}

function Set-AdapterDns {
    param([string]$InterfaceAlias)
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $cfg.DnsServers -ErrorAction SilentlyContinue
}

function Set-WifiAdvancedProperties {
    param([string]$AdapterName)
    foreach ($advProp in @(
        @{ DisplayName = 'MIMO Power Save Mode'; DisplayValue = 'No SMPS' }
        @{ DisplayName = 'Throughput Booster'; DisplayValue = 'Enabled' }
        @{ DisplayName = 'Transmit Power'; DisplayValue = '5. Highest' }
        @{ DisplayName = 'Roaming Aggressiveness'; DisplayValue = '5. Highest' }
    )) {
        try {
            Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName $advProp.DisplayName -DisplayValue $advProp.DisplayValue -NoRestart -ErrorAction Stop
        } catch {}
    }
    try {
        $bandSetting = Get-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName 'Preferred Band' -ErrorAction Stop
        $preferred = $bandSetting.ValidDisplayValues | Where-Object { $_ -match 'Prefer 5GHz band' -and $_ -notmatch '6GHz' } | Select-Object -First 1
        if (-not $preferred) {
            $preferred = $bandSetting.ValidDisplayValues | Where-Object { $_ -match '5GHz' } | Select-Object -First 1
        }
        if ($preferred) {
            Set-NetAdapterAdvancedProperty -Name $AdapterName -DisplayName 'Preferred Band' -DisplayValue $preferred -NoRestart -ErrorAction Stop
        }
    } catch {}
}

if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalSeconds -lt $cfg.LockSeconds) { exit 0 }
}
New-Item -Path $lock -ItemType File -Force | Out-Null

try {
    Invoke-LogRotation
    Write-NetForgeLog "=== $($cfg.AppName) trigger=$Trigger ==="

    shutdown /a 2>$null | Out-Null

    $doPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
    if (-not (Test-Path $doPath)) { New-Item -Path $doPath -Force | Out-Null }
    New-ItemProperty -Path $doPath -Name 'DODownloadMode' -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $doPath -Name 'DOMaxDownloadBandwidth' -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $doPath -Name 'DOMaxUploadBandwidth' -Value 0 -PropertyType DWord -Force | Out-Null

    $mmPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    New-ItemProperty -Path $mmPath -Name 'NetworkThrottlingIndex' -Value 0xffffffff -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $mmPath -Name 'SystemResponsiveness' -Value 0 -PropertyType DWord -Force | Out-Null

    $gamePath = 'HKCU:\Software\Microsoft\GameBar'
    if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
    New-ItemProperty -Path $gamePath -Name 'AutoGameModeEnabled' -Value 1 -PropertyType DWord -Force | Out-Null

    if ($cfg.DisableFileShare) {
        foreach ($g in @('File and Printer Sharing', 'Network Discovery', 'Remote Assistance')) {
            netsh advfirewall firewall set rule group="$g" new enable=No 2>$null | Out-Null
        }
        foreach ($svc in @('LanmanServer', 'FDResPub')) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }

    if ($cfg.DisableSshd) {
        Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
        Set-Service -Name sshd -StartupType Disabled -ErrorAction SilentlyContinue
        Get-NetFirewallRule -DisplayName 'OpenSSH*' -ErrorAction SilentlyContinue |
            ForEach-Object { Disable-NetFirewallRule -InputObject $_ -ErrorAction SilentlyContinue }
    }

    Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=True' -ErrorAction SilentlyContinue |
        ForEach-Object {
            Invoke-CimMethod -InputObject $_ -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]2 } -ErrorAction SilentlyContinue | Out-Null
        }

    $llmnrPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    if (-not (Test-Path $llmnrPath)) { New-Item -Path $llmnrPath -Force | Out-Null }
    New-ItemProperty -Path $llmnrPath -Name 'EnableMulticast' -Value 0 -PropertyType DWord -Force | Out-Null
    Stop-Service SSDPSRV -Force -ErrorAction SilentlyContinue
    Set-Service SSDPSRV -StartupType Disabled -ErrorAction SilentlyContinue

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

    if ($cfg.HighPerformancePower) {
        powercfg /SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null | Out-Null
    }

    Set-DnsClientDohServerAddress -ServerAddress '1.1.1.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
    Set-DnsClientDohServerAddress -ServerAddress '1.0.0.1' -DohTemplate 'https://cloudflare-dns.com/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue
    Set-DnsClientDohServerAddress -ServerAddress '8.8.8.8' -DohTemplate 'https://dns.google/dns-query' -AllowFallbackToUdp $false -AutoUpgrade $true -ErrorAction SilentlyContinue

    Set-NetFirewallProfile -Profile Private -LogBlocked True -LogAllowed False -LogMaxSizeKilobytes 16384 -ErrorAction SilentlyContinue
    Set-NetFirewallProfile -Profile Public -DefaultInboundAction Block -DefaultOutboundAction Allow -ErrorAction SilentlyContinue

    try {
        $qosPattern = "$($cfg.QosPrefix)-*"
        foreach ($qos in Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $qosPattern }) {
            Remove-NetQosPolicy -InputObject $qos -Confirm:$false -ErrorAction SilentlyContinue
        }
        foreach ($port in 80, 443, 853) {
            $qosName = "$($cfg.QosPrefix)-Port$port"
            if (-not (Get-NetQosPolicy -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $qosName })) {
                New-NetQosPolicy -Name $qosName -AppPathNameMatchCondition '*' -IPDstPortMatchCondition ([uint16]$port) -ThrottleRateActionBitsPerSecond 0 -PriorityValue8021Action 7 -ErrorAction Stop | Out-Null
            }
        }
    } catch {
        Write-NetForgeLog "QoS skipped: $($_.Exception.Message)"
    }

    $adapters = @()
    for ($i = 0; $i -lt 15; $i++) {
        $adapters = @(Get-ActiveNetAdapters)
        if ($adapters.Count -gt 0) { break }
        Start-Sleep -Seconds 3
    }

    $eth = @($adapters | Where-Object { Test-IsEthernetAdapter $_ })
    $wifi = @($adapters | Where-Object { Test-IsWirelessAdapter $_ })
    $ethNames = @($eth | ForEach-Object { $_.Name })
    $wifiNames = @($wifi | ForEach-Object { $_.Name })
    Write-NetForgeLog "Adapters: $($adapters.Count) (ethernet=$($eth.Count) wifi=$($wifi.Count))"

    foreach ($a in $eth) {
        Enable-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $a.Name -AddressFamily IPv4 -InterfaceMetric $cfg.EthernetMetric -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $a.Name -AddressFamily IPv6 -InterfaceMetric $cfg.EthernetMetric -ErrorAction SilentlyContinue
        Set-AdapterDns -InterfaceAlias $a.Name
        try { Set-NetConnectionProfile -InterfaceAlias $a.Name -NetworkCategory Private -ErrorAction Stop } catch {}
        Write-NetForgeLog "Ethernet [$($a.Name)] metric=$($cfg.EthernetMetric)"
    }

    foreach ($a in $wifi) {
        $metric = if ($eth.Count -gt 0) { $cfg.WiFiMetricWithEth } else { $cfg.WiFiMetricAlone }
        Set-NetIPInterface -InterfaceAlias $a.Name -AddressFamily IPv4 -InterfaceMetric $metric -ErrorAction SilentlyContinue
        Set-NetIPInterface -InterfaceAlias $a.Name -AddressFamily IPv6 -InterfaceMetric $metric -ErrorAction SilentlyContinue
        Set-AdapterDns -InterfaceAlias $a.Name
        try { Set-NetConnectionProfile -InterfaceAlias $a.Name -NetworkCategory Private -ErrorAction Stop } catch {}
        Set-WifiAdvancedProperties -AdapterName $a.Name
        Write-NetForgeLog "Wi-Fi [$($a.Name)] metric=$metric"
    }

    foreach ($a in $adapters) {
        if ($ethNames -contains $a.Name -or $wifiNames -contains $a.Name) { continue }
        Set-AdapterDns -InterfaceAlias $a.Name
        Write-NetForgeLog "Other [$($a.Name)] DNS applied"
    }

    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-NetForgeLog '=== complete ==='
} catch {
    Write-NetForgeLog "ERROR: $_"
} finally {
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}