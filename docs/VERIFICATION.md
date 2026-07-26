# Verification checklist — NetForge v2.0.0

## Windows

1. `.\src\Get-NetForgeStatus.ps1` — health, adapters, no changes  
2. `.\src\NetworkAuto.ps1 -DryRun` — planned actions only  
3. Admin: `.\src\Install-NetworkAuto.ps1` — tasks + apply; check last-run.json  
4. `.\src\Clear-CaptivePortal.ps1 -ProbeOnly`  
5. Admin: captive apply → browser portal → `-Restore`  
6. Connect VPN — re-run apply — VPN iface not forced to public DNS when RespectVpn  
7. `.\src\Uninstall-NetworkAuto.ps1` then optional `-RevertSettings`  

## Linux / macOS

1. `./src/netforge-status.sh` / `--json`  
2. `sudo ./src/network-auto.sh --dry-run`  
3. `sudo ./src/install-network-auto.sh`  
4. Captive: `--probe-only` → apply → `--restore`  
5. VPN up: confirm skip logs / metrics  
6. Uninstall script  

## Pass criteria

- No crash on dry-run without root (Unix dry-run / Windows -DryRun)  
- Idempotent second apply  
- Logs local only  
- Captive restore returns DoH/DoT/DNS policy  
