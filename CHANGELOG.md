# Changelog

## 2.0.0 - 2026-07-24

### User-facing
- Captive portal excellence: probes, temporary DHCP/plaintext DNS, DoH UDP fallback, `-Restore`, optional auto-restore task
- Richer status: last-run stamp, DNS latency, VPN listing, health, `-Json`, offline `-HtmlPath`
- VPN respect (`RespectVpn`, default true)
- Dry-run: `NetworkAuto.ps1 -DryRun`
- Uninstall `-RevertSettings` best-effort restore
- Config profiles: home, travel, corporate, privacy-max
- Packaging: winget example under `packaging/winget/`
- Landing: https://netforge.jonbailey.xyz

### Migration
1. Pull v2.0.0
2. Merge local `defaults.psd1` with new keys
3. Re-run `Install-NetworkAuto.ps1`

## 1.0.2
Prior stable Windows release.
