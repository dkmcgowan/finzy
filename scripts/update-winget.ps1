#!/usr/bin/env pwsh
# Updates winget manifests with version and SHA256 from a GitHub release.
# Usage: .\scripts\update-winget.ps1 [-Version 0.1.5]
# If -Version is omitted, uses the latest release from GitHub.

param(
    [string]$Version
)

$ErrorActionPreference = "Stop"
$Repo = "dkmcgowan/finzy"
$InstallerName = "finzy-windows-installer.exe"

if (-not $Version) {
    Write-Host "Fetching latest release from GitHub..." -ForegroundColor Cyan
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ Accept = "application/vnd.github+json" }
    $Version = $Release.tag_name
    Write-Host "Latest version: $Version" -ForegroundColor Green
} else {
    $Release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Version" -Headers @{ Accept = "application/vnd.github+json" }
}

$InstallerUrl = "https://github.com/$Repo/releases/download/$Version/$InstallerName"

# Find SHA256 from release assets
$Asset = $Release.assets | Where-Object { $_.name -eq $InstallerName } | Select-Object -First 1
if (-not $Asset) {
    Write-Error "Could not find $InstallerName in release $Version"
}
$Sha256 = $Asset.digest -replace "^sha256:", ""

Write-Host "Installer SHA256: $Sha256" -ForegroundColor Green

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$TemplateDir = Join-Path $ProjectRoot "winget\manifests\d\dkmcgowan\finzy\0.1.4"
$TargetDir = Join-Path $ProjectRoot "winget\manifests\d\dkmcgowan\finzy\$Version"

New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
Get-ChildItem $TemplateDir -Filter "*.yaml" | ForEach-Object {
    $Content = (Get-Content $_.FullName -Raw) `
        -replace "PackageVersion: [^\r\n]+", "PackageVersion: $Version" `
        -replace "InstallerUrl: https://github\.com/[^\r\n]+", "InstallerUrl: $InstallerUrl" `
        -replace "InstallerSha256: [a-f0-9]+", "InstallerSha256: $Sha256"
    Set-Content -Path (Join-Path $TargetDir $_.Name) -Value $Content.TrimEnd() -NoNewline
    Write-Host "Updated $($_.Name)" -ForegroundColor Green
}

Write-Host "`nDone. Validate with: winget validate $TargetDir" -ForegroundColor Cyan
