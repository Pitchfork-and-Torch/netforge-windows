# NetForge for Windows (moved)

This repository has been **merged** into the cross-platform monorepo:

**https://github.com/Pitchfork-and-Torch/netforge**

Source of truth: [`windows/`](https://github.com/Pitchfork-and-Torch/netforge/tree/main/windows) in that repo. Live site: [netforge.jonbailey.xyz](https://netforge.jonbailey.xyz).

## Quick install (Admin PowerShell, from the monorepo)

Dry-run before install — do not skip that step:

```powershell
git clone https://github.com/Pitchfork-and-Torch/netforge.git
cd netforge\windows
.\src\Get-NetForgeStatus.ps1
.\src\NetworkAuto.ps1 -DryRun
.\src\Install-NetworkAuto.ps1
```

Bootstrap (clones monorepo, installs Windows platform):

```powershell
irm https://raw.githubusercontent.com/Pitchfork-and-Torch/netforge/main/windows/install.ps1 | iex
```

## Captive portals

```powershell
.\src\Clear-CaptivePortal.ps1 -ProbeOnly
.\src\Clear-CaptivePortal.ps1
.\src\Clear-CaptivePortal.ps1 -Restore
```

| Platform | Path |
|----------|------|
| Windows | [windows/](https://github.com/Pitchfork-and-Torch/netforge/tree/main/windows) |
| Linux | [linux/](https://github.com/Pitchfork-and-Torch/netforge/tree/main/linux) |
| macOS | [macos/](https://github.com/Pitchfork-and-Torch/netforge/tree/main/macos) |

Please clone, star, and open issues on **netforge** going forward. This stub remains only as a pointer.
