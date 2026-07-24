# NetForge for Windows

**Automatic network performance tuning and security hardening for Windows 10/11.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-2.0.0-informational)](VERSION)

Local-first. Zero telemetry. Prefer Ethernet, DoH DNS, TCP tuning, optional hardening.

**Suite landing:** [netforge.jonbailey.xyz](https://netforge.jonbailey.xyz)

## Quick install (Admin PowerShell)

```powershell
git clone https://github.com/Pitchfork-and-Torch/netforge-windows.git
cd netforge-windows
.\src\Get-NetForgeStatus.ps1
.\src\NetworkAuto.ps1 -DryRun
.\src\Install-NetworkAuto.ps1
```

## Captive portals

```powershell
.\src\Clear-CaptivePortal.ps1 -ProbeOnly
.\src\Clear-CaptivePortal.ps1          # admin: relax DNS
.\src\Clear-CaptivePortal.ps1 -Restore # after login
```

## Status

```powershell
.\src\Get-NetForgeStatus.ps1
.\src\Get-NetForgeStatus.ps1 -Json
.\src\Get-NetForgeStatus.ps1 -HtmlPath "$env:USERPROFILE\Desktop\netforge-status.html"
```

## Suite

| Platform | Repo |
|----------|------|
| Windows | this repo |
| Linux | [netforge-linux](https://github.com/Pitchfork-and-Torch/netforge-linux) |
| macOS | [netforge-macos](https://github.com/Pitchfork-and-Torch/netforge-macos) |

Related: [trench-coat](https://github.com/Pitchfork-and-Torch/trench-coat) · [ghost-continuum](https://github.com/Pitchfork-and-Torch/ghost-continuum)

## License

MIT - see [LICENSE](LICENSE).
