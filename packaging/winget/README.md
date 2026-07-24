# winget packaging notes (NetForge Windows v2)

1. Tag `v2.0.0` and attach `netforge-windows-2.0.0.zip` (repo root without `.git`).
2. `Get-FileHash netforge-windows-2.0.0.zip -Algorithm SHA256`
3. Replace `InstallerSha256` in the installer manifest.
4. Submit to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) following their PR template.
5. Until published, install via git clone or `install.ps1`.

NetForge remains **local-first**; winget only distributes files—no cloud account is required at runtime.
