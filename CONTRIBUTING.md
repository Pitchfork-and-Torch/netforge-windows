# Contributing to NetForge

Thanks for helping improve NetForge for Windows.

## Before you start

- Test changes on Windows 10 or 11 with Administrator PowerShell
- Do **not** commit personal network data (IPs, SSIDs, MACs, hostnames, usernames in paths)
- Keep scripts idempotent — safe to run repeatedly

## Development setup

```powershell
git clone https://github.com/Pitchfork-and-Torch/netforge-windows.git
cd netforge-windows
.\src\NetworkAuto.ps1 -Trigger manual
```

Logs write to `%LOCALAPPDATA%\NetForge\network-auto.log`.

## Pull requests

1. Fork and create a feature branch
2. Test install, manual run, and uninstall paths
3. Describe what changed and any security/compat tradeoffs
4. One logical change per PR when possible

## Reporting issues

Include:

- Windows version (`winver`)
- PowerShell version (`$PSVersionTable`)
- Relevant log lines from `%LOCALAPPDATA%\NetForge\network-auto.log` (redact personal info)
- Whether Ethernet, Wi-Fi, or VPN adapters are involved

## Code style

- PowerShell 5.1 compatible (no PS 7-only syntax unless gated)
- Prefer `-ErrorAction SilentlyContinue` for optional driver-specific settings
- Use `$PSScriptRoot` and config files — never hardcode user paths