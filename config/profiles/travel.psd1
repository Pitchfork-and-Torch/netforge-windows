# Travel: captive-portal friendly defaults; keep file share off; shorter auto-restore
@{
    AppName                   = 'NetForge'
    DnsServers                = @('1.1.1.1', '1.0.0.1', '8.8.8.8')
    QosPrefix                 = 'NetForge-Priority'
    EthernetMetric            = 5
    WiFiMetricAlone           = 10
    WiFiMetricWithEth         = 40
    LockSeconds               = 60
    MaxLogLines               = 2000
    DisableSshd               = $true
    DisableFileShare          = $true
    HighPerformancePower      = $false
    RespectVpn                = $true
    CaptivePortalDns          = @('1.1.1.1', '8.8.8.8')
    CaptiveAutoRestoreSeconds = 600
}
