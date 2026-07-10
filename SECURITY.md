# Security

## What NetForge does

NetForge modifies **local** Windows network settings: DNS, TCP stack, firewall profiles, adapter metrics, and optional service hardening. It runs via scheduled tasks on your PC or manually from PowerShell.

**It does not:**

- Upload network details, adapter names, or logs to any server
- Require accounts, API keys, or cloud services
- Change router, ISP, or mesh Wi-Fi admin settings

Logs are written only to `%LOCALAPPDATA%\NetForge\network-auto.log` on your machine.

## Permissions required

| Requirement | Why |
|-------------|-----|
| Administrator | DNS, firewall, services, and adapter changes need elevation |
| Scheduled tasks (optional) | Run automatically at logon and network connect |

## Safe installation

1. Download only from [github.com/Pitchfork-and-Torch/netforge-windows](https://github.com/Pitchfork-and-Torch/netforge-windows).
2. Prefer `git clone` and read the scripts before running.
3. If using `irm ... | iex`, review [install.ps1](install.ps1) first — it clones this repo and runs the installer.
4. Do not run forks or third-party mirrors unless you audit them.

## Default hardening (review before install)

| Setting | Default | Impact |
|---------|---------|--------|
| `DisableFileShare` | `$true` | Disables SMB sharing and network discovery |
| `DisableSshd` | `$true` | Disables OpenSSH Server if installed |
| Public firewall | Block inbound | May block services you intentionally expose |

Set these to `$false` in `config/defaults.psd1` if you need those features.

## Edge cases

| Situation | Guidance |
|-----------|----------|
| Captive portal (hotel/airport Wi-Fi) | Forced DoH can block the portal. Temporarily disable DoH or NetForge tasks, open the portal page, then re-enable. |
| Corporate VPN | Adapter metrics may fight split-tunnel VPN. Set metrics manually or skip automation while on VPN. |
| Offline | After install, scheduled runs only need local APIs — no cloud. |
| Multi-homed / Hyper-V switches | Virtual adapters are skipped when inactive; verify with `Get-NetForgeStatus.ps1`. |

Prefer `.\src\Get-NetForgeStatus.ps1` (read-only) before changing anything.

## Reporting issues

Open a [GitHub issue](https://github.com/Pitchfork-and-Torch/netforge-windows/issues). For sensitive findings, use GitHub private vulnerability reporting if enabled.

## Uninstall

```powershell
.\src\Uninstall-NetworkAuto.ps1
```

Removes scheduled tasks only. Revert DNS, firewall, and services manually if needed.