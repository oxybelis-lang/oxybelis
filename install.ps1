#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Oxybelis toolchain installer – rustup-like for Windows.
.DESCRIPTION
    Installs the Oxybelis compiler, formatter, and LSP server as native binaries.
    Detects platform, downloads from GitHub releases (or falls back to local build),
    and adds the tools to PATH.

    Usage:
        irm https://oxybelis.dev/install.ps1 | iex          # auto
        .\install.ps1                                        # local
        .\install.ps1 -Version 0.2.0 -InstallDir D:\ox       # custom
#>

param(
    [string]$Version = '',
    [string]$InstallDir = '',
    [switch]$LocalBuild = $false
)

$ErrorActionPreference = 'Stop'

$RepoRoot = if ($LocalBuild -or -not $Version) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $null }

# ── Defaults ──────────────────────────────────────────────────
$OxHome = if ($InstallDir) { $InstallDir } else { Join-Path $env:LOCALAPPDATA 'oxybelis' }
$BinDir = Join-Path $OxHome 'bin'

if (-not $Version) { $Version = '0.2.0' }

# ── Platform detection ────────────────────────────────────────
$Arch = switch -Wildcard ("$([Environment]::ProcessorArchitecture)$env:PROCESSOR_ARCHITECTURE") {
    '*AMD64*'  { 'x86_64' }
    '*ARM64*'  { 'aarch64' }
    '*X86*'    { 'i686' }
    default    { 'x86_64' }  # fallback
}

# ── Helper functions ──────────────────────────────────────────

function Write-Step($Msg) { Write-Host "  → $Msg" -ForegroundColor Cyan }
function Write-OK($Msg)   { Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn($Msg) { Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }

function Add-ToPath($Dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($current -split ';' -notcontains $Dir) {
        $new = if ($current) { "$current;$Dir" } else { $Dir }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        # Also update current session
        $env:Path = "$env:Path;$Dir"
        Write-OK "Added $Dir to user PATH"
    } else {
        Write-OK "$Dir already in PATH"
    }
}

# ── Install logic ─────────────────────────────────────────────

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║      Oxybelis Toolchain Installer        ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Step "Platform: Windows ($Arch)"
Write-Step "Version:  $Version"
Write-Step "Install:  $OxHome"

# Check existing installation
if (Test-Path (Join-Path $BinDir 'oxybelis.exe')) {
    Write-Warn "Oxybelis already installed at $BinDir"
    $reply = Read-Host "  Overwrite? [y/N]"
    if ($reply -notmatch '^[yY]') { Write-Host "  Aborted."; return }
}

New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

if ($LocalBuild) {
    Write-Step "Using local build…"
    $releaseDir = Join-Path $RepoRoot 'dist' 'release'
    foreach ($bin in @('oxybelis.exe', 'ox-fmt.exe', 'ox-lsp.exe')) {
        $src = Join-Path $releaseDir $bin
        if (-not (Test-Path $src)) { throw "Local build not found: $src`nRun 'python build.py' first." }
        Copy-Item $src (Join-Path $BinDir $bin)
        Write-OK "Copied $bin"
    }
} else {
    # Download from GitHub releases
    $repo = 'oxybelis-lang/oxybelis'
    $base = "https://github.com/$repo/releases/download/v$Version"
    $archive = "oxybelis-x86_64-pc-windows-msvc.zip"
    $url = "$base/$archive"
    $zipPath = Join-Path $env:TEMP $archive

    Write-Step "Downloading $url …"
    try {
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    } catch {
        throw "Download failed: $_`n  Make sure a release v$Version exists at $repo/releases"
    }

    Write-Step "Extracting…"
    Expand-Archive -Path $zipPath -DestinationPath $BinDir -Force
    Remove-Item $zipPath
}

# Add to PATH
Add-ToPath $BinDir

# Verify
Write-Host ""
Write-Step "Verifying installation…"
$testExe = Join-Path $BinDir 'oxybelis.exe'
if (-not (Test-Path $testExe)) { throw "Installation failed: $testExe not found" }

# Test each tool
foreach ($tool in @('oxybelis', 'ox-fmt', 'ox-lsp')) {
    $exe = Join-Path $BinDir "$tool.exe"
    if (Test-Path $exe) {
        Write-OK "$tool — $((Get-Item $exe).Length / 1KB -as [int]) KB"
    } else {
        Write-Warn "$tool.exe not found"
    }
}

Write-Host ""
Write-Host "  🎉 Oxybelis installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "  You can now run:"
Write-Host "    oxybelis --help"
Write-Host "    ox-fmt    --help"
Write-Host "    ox-lsp    --help"
Write-Host ""
Write-Host "  To uninstall, remove $OxHome" -ForegroundColor Yellow
Write-Host ""
