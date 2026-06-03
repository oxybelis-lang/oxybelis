#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Oxybelis installer – one-command setup for Windows.
.DESCRIPTION
    Downloads the pre-built Oxybelis compiler binary and adds it to PATH.
    Requires: g++ (MinGW) – run `winget install GCC` if missing.

    Usage:
        irm https://raw.githubusercontent.com/oxybelis-lang/oxybelis/main/install.ps1 | iex
        .\install.ps1
        .\install.ps1 -Version 0.3.0 -InstallDir D:\ox
#>

param(
    [string]$Version = '0.3.0',
    [string]$InstallDir = ''
)

$ErrorActionPreference = 'Stop'

# ── Defaults ──────────────────────────────────────────────────
$OxHome = if ($InstallDir) { $InstallDir } else { Join-Path $env:LOCALAPPDATA 'oxybelis' }
$BinDir = Join-Path $OxHome 'bin'

# ── Platform ──────────────────────────────────────────────────
$Arch = switch -Wildcard ("$([Environment]::ProcessorArchitecture)$env:PROCESSOR_ARCHITECTURE") {
    '*AMD64*'  { 'x86_64' }
    '*ARM64*'  { 'aarch64' }
    default    { 'x86_64' }
}

function Write-Step($Msg) { Write-Host "  → $Msg" -ForegroundColor Cyan }
function Write-OK($Msg)   { Write-Host "  ✓ $Msg" -ForegroundColor Green }
function Write-Warn($Msg) { Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }

function Add-ToPath($Dir) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($current -split ';' -notcontains $Dir) {
        $new = if ($current) { "$Dir;$current" } else { $Dir }
        [Environment]::SetEnvironmentVariable('Path', $new, 'User')
        $env:Path = "$Dir;$env:Path"
        Write-OK "Prepended $Dir to user PATH"
    } else {
        Write-OK "$Dir already in PATH"
    }
}

# ── Check prerequisites ──────────────────────────────────────
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║       Oxybelis Installer                 ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Step "Platform: Windows ($Arch)"
Write-Step "Version:  $Version"
Write-Step "Install:  $OxHome"

$have_gpp = $false
try { $null = Get-Command g++; $have_gpp = $true } catch {}
if (-not $have_gpp) {
    Write-Warn "g++ (MinGW) not found – Oxybelis needs it to compile programs."
    Write-Host "  Install via: winget install GCC"
    Write-Host "  Or grab it from: https://winlibs.com/"
}

# Check for existing oxybelis from a different source (e.g. pip)
try {
    $existing = Get-Command oxybelis -ErrorAction Stop
    if ($existing.Source -ne (Join-Path $BinDir 'oxybelis.exe')) {
        Write-Warn "oxybelis already on PATH from: $($existing.Source)"
        Write-Host "  The new binary at $BinDir will take priority."
    }
} catch {}

# ── Download ──────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

$repo = 'oxybelis-lang/oxybelis'
$base = "https://github.com/$repo/releases/download/v$Version"
$archive = "oxybelis-$Arch-pc-windows-msvc.zip"
$url = "$base/$archive"
$zipPath = Join-Path $env:TEMP $archive

Write-Step "Downloading $url …"
try {
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
} catch {
    throw "Download failed: $_`n  Make sure v$Version exists at $repo/releases"
}

Write-Step "Extracting…"
Expand-Archive -Path $zipPath -DestinationPath $BinDir -Force
Remove-Item $zipPath

# Add to PATH
Add-ToPath $BinDir

# Verify
Write-Host ""
$exe = Join-Path $BinDir 'oxybelis.exe'
if (Test-Path $exe) {
    $size = (Get-Item $exe).Length / 1KB -as [int]
    Write-OK "oxybelis.exe — $size KB"
    Write-Host ""
    Write-Host "  🎉 Oxybelis installed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Quick start:"
    Write-Host '    echo ''print("hello world")'' > hello.ox'
    Write-Host '    oxybelis hello.ox'
    Write-Host ""
    Write-Host "  Needs g++? Run: winget install GCC" -ForegroundColor Yellow
    Write-Host "  Uninstall: Remove-Item -Recurse $OxHome" -ForegroundColor Yellow
} else {
    throw "Installation failed: $exe not found"
}
