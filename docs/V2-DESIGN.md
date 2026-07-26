# NetForge v2.0 design (suite)

## Gap analysis (v1.0.x → goals)

| Goal | Windows v1 | Linux/macOS v1 | v2 approach |
|------|------------|----------------|-------------|
| Captive portal | Manual DoH/DNS reset only | Thin nmcli/networksetup hints | Probe portal endpoints, plaintext DNS, state file, restore |
| Status/diagnostics | Basic adapter/DNS/services | Basic nmcli/resolved | Last-run, DNS RTT, metrics, JSON, offline HTML |
| VPN / multi-home | Filters VPN from discovery only | Little awareness | Detect VPN ifaces; `RespectVpn` skips metric/DNS fight |
| Dry-run | None | None | `-DryRun` / `--dry-run` prints planned actions |
| Packaging | install.ps1 only | install.sh only | winget / brew / packaging notes |
| Config profiles | Single defaults | Single defaults | example profiles: home, travel, corporate, privacy-max |
| Uninstall revert | Tasks only | Partial | Optional `--revert` best-effort restore |
| Landing | GitHub only | GitHub only | netforge.jonbailey.xyz |

## Shared config concepts (names)

| Concept | Windows (psd1) | Unix (conf) |
|---------|----------------|-------------|
| Prefer Ethernet metrics | EthernetMetric / WiFi* | ETHERNET_METRIC / WIFI_* |
| DNS servers | DnsServers | DNS_SERVERS |
| Encrypted DNS | DoH (hardcoded templates) | DNS_OVER_TLS |
| Respect VPN | RespectVpn | RESPECT_VPN |
| Captive portal DNS | CaptivePortalDns | CAPTIVE_PORTAL_DNS |
| Auto restore seconds | CaptiveAutoRestoreSeconds | CAPTIVE_AUTO_RESTORE_SECONDS |
| Dry-run | -DryRun switch | --dry-run |
| Optional hardening | DisableSshd / DisableFileShare | DISABLE_SSHD / DISABLE_FILE_SHARE |

## Non-goals preserved

No telemetry, no accounts, no cloud required for apply, no router control.

## Version

**2.0.0** across all three repositories.
