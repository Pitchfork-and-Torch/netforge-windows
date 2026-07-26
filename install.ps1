#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap installer for NetForge — clones repo and registers scheduled tasks.
.DESCRIPTION
    Safe to inspect before running. Does not embed credentials or network details.
    Usage:
      irm https://raw.githubusercontent.com/Pitchfork-and-Torch/netforge-windows/main/install.ps1 | iex
      .\install.ps1
#>
[CmdletBinding()]
param(
    [string]$RepoUrl = 'https://github.com/Pitchfork-and-Torch/netforge-windows.git',
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'NetForge\repo'),
    [string]$Branch = 'main'
)

$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent()
    )
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    Write-Host 'NetForge requires Administrator privileges.' -ForegroundColor Red
    Write-Host 'Right-click PowerShell and choose "Run as administrator", then re-run this script.'
    exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host 'Git is required for bootstrap install. Install from https://git-scm.com or clone manually.' -ForegroundColor Red
    exit 1
}

$parent = Split-Path -Parent $InstallDir
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

if (Test-Path (Join-Path $InstallDir '.git')) {
    Write-Host "Updating existing install at $InstallDir ..."
    git -C $InstallDir fetch --depth 1 origin $Branch 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Fetch failed (offline?). Using existing tree at $InstallDir"
    } else {
        git -C $InstallDir pull --ff-only origin $Branch 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Fast-forward pull failed (local edits?). Re-cloning clean copy."
            Remove-Item -Path $InstallDir -Recurse -Force
            git clone --branch $Branch --single-branch $RepoUrl $InstallDir
        }
    }
} else {
    if (Test-Path $InstallDir) {
        Remove-Item -Path $InstallDir -Recurse -Force
    }
    Write-Host "Cloning $RepoUrl (branch: $Branch) ..."
    git clone --branch $Branch --single-branch $RepoUrl $InstallDir
}

$installer = Join-Path $InstallDir 'src\Install-NetworkAuto.ps1'
if (-not (Test-Path $installer)) {
    throw "Installer not found after clone: $installer"
}

& $installer -RepoRoot $InstallDir