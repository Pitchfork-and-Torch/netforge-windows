# Corporate-friendly: respect VPN, do not disable SSH/file share, no power plan force
@{
    AppName                   = 'NetForge'
    DnsServers                = @('1.1.1.1', '1.0.0.1', '8.8.8.8')
    QosPrefix                 = 'NetForge-Priority'
    EthernetMetric            = 10
    WiFiMetricAlone           = 20
    WiFiMetricWithEth         = 50
    LockSeconds               = 90
    MaxLogLines               = 2000
    DisableSshd               = $false
    DisableFileShare          = $false
    HighPerformancePower      = $false
    RespectVpn                = $true
    CaptivePortalDns          = @('1.1.1.1', '8.8.8.8')
    CaptiveAutoRestoreSeconds = 900
}
