# Privacy-max: aggressive local hardening (review before use on work machines)
@{
    AppName                   = 'NetForge'
    DnsServers                = @('1.1.1.1', '1.0.0.1')
    QosPrefix                 = 'NetForge-Priority'
    EthernetMetric            = 5
    WiFiMetricAlone           = 15
    WiFiMetricWithEth         = 50
    LockSeconds               = 90
    MaxLogLines               = 2000
    DisableSshd               = $true
    DisableFileShare          = $true
    HighPerformancePower      = $true
    RespectVpn                = $true
    CaptivePortalDns          = @('1.1.1.1', '8.8.8.8')
    CaptiveAutoRestoreSeconds = 900
}
