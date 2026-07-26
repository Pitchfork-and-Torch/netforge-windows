# NetForge suite

Cross-platform **local** network performance tuning and optional security hardening. Same ethos on every OS: idempotent scripts, config-driven defaults, no cloud telemetry, review before you elevate.

| Platform | Repository | Install | Status (read-only) |
|----------|------------|---------|----------------------|
| Windows 10/11 | [netforge-windows](https://github.com/Pitchfork-and-Torch/netforge-windows) | `Install-NetworkAuto.ps1` | `Get-NetForgeStatus.ps1` |
| Linux (NetworkManager) | [netforge-linux](https://github.com/Pitchfork-and-Torch/netforge-linux) | `src/install-network-auto.sh` | `src/netforge-status.sh` |
| macOS 12+ | [netforge-macos](https://github.com/Pitchfork-and-Torch/netforge-macos) | `src/install-network-auto.sh` | `src/netforge-status.sh` |

## Shared design

- **Discover adapters/services at runtime** — no hard-coded NIC names  
- **Prefer Ethernet over Wi-Fi** when both are up  
- **DNS** toward resilient public resolvers (DoH on Windows; DoT/resolved on Linux; `networksetup` on macOS)  
- **Optional hardening** (file sharing / SSH / mDNS) behind config flags  
- **Triggers** on boot/logon and network connect  
- **Lock + log** so concurrent runs do not clobber each other  

## Platform differences (edge cases)

| Topic | Windows | Linux | macOS |
|-------|---------|-------|-------|
| DNS privacy | DoH APIs | systemd-resolved DoT | Plain DNS via networksetup (no public DoH API) |
| Permissions | Administrator PowerShell | root/sudo | root/sudo |
| Captive portals | May need temporary DoH off | May need temporary DoT off | Usually OK |
| VPN / split tunnel | Metrics may fight corporate VPN | NM + VPN profiles can override | Service order may interact with VPN |
| Offline | Scripts need no network to *apply* local settings | Same | Same |

## Related Pitchfork-and-Torch tools

| Tool | Role |
|------|------|
| [trench-coat](https://github.com/Pitchfork-and-Torch/trench-coat) | Multi-hop privacy cloak (Tor / proxy chains) — **privacy routing**, not LAN tuning |
| [ghost-continuum](https://github.com/Pitchfork-and-Torch/ghost-continuum) | Defense / deception / forensics plane (optional Trench Coat integration) |
| [Fl1pp3r69](https://github.com/Pitchfork-and-Torch/Fl1pp3r69) | Authorized RF/NFC field ops (separate domain) |

NetForge hardens **your host’s network stack**. Trench Coat and Ghost Continuum address **egress privacy** and **defense**. They compose; they do not replace each other.

## Non-goals

- No router/mesh admin automation  
- No ISP line repair  
- No phone-home analytics  

## Support

Bug reports via each repo’s GitHub Issues. All NetForge repos are MIT.
