# NetForge suite release v2.0.0

## Tag (each repo)

```bash
git tag -a v2.0.0 -m "NetForge 2.0.0"
git push origin main --tags
```

## Release artifacts (optional zip)

```powershell
# from repo root
Compress-Archive -Path * -DestinationPath netforge-windows-2.0.0.zip -Force
Get-FileHash .\netforge-windows-2.0.0.zip -Algorithm SHA256
```

Attach zip + paste SHA256 into GitHub Release notes. Signing: optional Authenticode / cosign — document if used; not required for MIT scripts.

## Checklist

- [ ] VERSION = 2.0.0 on windows / macos / linux  
- [ ] CHANGELOG entries present  
- [ ] Landing deployed at netforge.jonbailey.xyz  
- [ ] GSC sitemap submitted  
- [ ] winget/homebrew stubs updated with real SHA after zip publish  

## Verification plan

| Step | Windows | Unix |
|------|---------|------|
| Status | `Get-NetForgeStatus.ps1` | `./src/netforge-status.sh` |
| Dry-run | `NetworkAuto.ps1 -DryRun` | `sudo ./src/network-auto.sh --dry-run` |
| Apply | `Install-NetworkAuto.ps1` | `sudo ./src/install-network-auto.sh` |
| Captive | `Clear-CaptivePortal.ps1 -ProbeOnly` then apply | `./src/clear-captive-portal.sh --probe-only` |
| VPN | enable VPN, re-apply, confirm tunnel not metric-stomped | same with RESPECT_VPN |
| Uninstall | `Uninstall-NetworkAuto.ps1` / `-RevertSettings` | platform uninstall scripts |

### Edge cases

- No adapters up → status health degraded; apply retries/waits on Windows  
- Portal with HTTPS-only redirects → use neverssl / captive.apple.com HTTP  
- Corporate VPN → `RespectVpn` / `RESPECT_VPN` true  
- Free org policies disabling deploy keys → N/A for NetForge  
- PowerShell 5.1 vs 7 — scripts target 5.1+  
