@{
    # Display name used for scheduled tasks and log directory (%LOCALAPPDATA%\{AppName}\)
    AppName              = 'NetForge'

    # DNS resolvers applied to all active adapters (IPv4)
    DnsServers           = @('1.1.1.1', '1.0.0.1', '8.8.8.8')

    # Prefix for QoS policy names (must be unique on your system)
    QosPrefix            = 'NetForge-Priority'

    # Lower metric = higher routing priority
    EthernetMetric       = 5
    WiFiMetricAlone      = 10   # when no Ethernet adapter is up
    WiFiMetricWithEth    = 50   # when Ethernet is also up (prefer wired)

    LockSeconds          = 90   # skip run if another instance finished within N seconds
    MaxLogLines          = 2000 # rotate log after this many lines

    # Set to $false if you need these services
    DisableSshd          = $true
    DisableFileShare     = $true

    HighPerformancePower = $true
}