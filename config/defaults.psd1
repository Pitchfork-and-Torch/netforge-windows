@{
    AppName              = 'NetForge'
    DnsServers           = @('1.1.1.1', '1.0.0.1', '8.8.8.8')
    QosPrefix            = 'NetForge-Priority'
    EthernetMetric       = 5
    WiFiMetricAlone      = 10
    WiFiMetricWithEth    = 50
    LockSeconds          = 90
    MaxLogLines          = 2000
    DisableSshd          = $true
    DisableFileShare     = $true
    HighPerformancePower = $true
}