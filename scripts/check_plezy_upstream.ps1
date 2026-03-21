#!/usr/bin/env pwsh
# Analyzes upstream Plezy commits for UI/player fixes relevant to Finzy.
# Filters out Plex-specific changes.
#
# Uses incremental mode when docs/UPSTREAM_PLEZY_ANALYSIS.md exists: only fetches
# commits since "Last Plezy commit processed". Otherwise does full comparison
# from plezy-jellyfin fork.
#
# Usage:
#   .\scripts\check_plezy_upstream.ps1              # Preview only (console output)
#   .\scripts\check_plezy_upstream.ps1 -WriteDoc     # Update docs/UPSTREAM_PLEZY_ANALYSIS.md
#   .\scripts\check_plezy_upstream.ps1 -Full         # Force full comparison (ignore last SHA)

param(
    [switch]$WriteDoc,
    [switch]$Full
)

$ErrorActionPreference = "Stop"

$DocPath = Join-Path (Split-Path $PSScriptRoot -Parent) "docs\UPSTREAM_PLEZY_ANALYSIS.md"

# Include: commit message contains any of these (case-insensitive)
$IncludePatterns = @(
    "fix", "feat", "refactor",
    "player", "mpv", "playback", "video", "subtitle", "audio",
    "ui", "widget", "scroll", "focus", "icon", "gradient", "timestamp",
    "crash", "memory", "SurfaceControl", "trickplay", "timeline",
    "download", "livetv", "epg", "chapter", "library", "hub",
    "dpad", "focus"
)

# Exclude: commit message contains any of these (Plex-specific)
$ExcludePatterns = @(
    "plex", "Plex", "PMS", "plex\.tv", "sign.?in.?with.?plex",
    "GDM", "Docker.*bridge", "server discovery"
)

function Test-CommitRelevant {
    param([string]$Message)
    $msg = $Message.ToLowerInvariant()
    foreach ($pat in $ExcludePatterns) {
        if ($msg -match $pat) { return $false }
    }
    foreach ($pat in $IncludePatterns) {
        if ($msg -match $pat) { return $true }
    }
    return $false
}

# Determine comparison base: incremental (since last check) or full (since fork)
$LastSha = $null
if (-not $Full -and (Test-Path $DocPath)) {
    $docContent = Get-Content -Path $DocPath -Raw
    if ($docContent -match 'Last Plezy commit processed:.*?([a-f0-9]{7,40})') {
        $LastSha = $Matches[1]
    }
}

if ($LastSha) {
    Write-Host "Fetching Plezy commits since last check ($LastSha)..." -ForegroundColor Cyan
    $CompareUrl = "https://api.github.com/repos/edde746/plezy/compare/${LastSha}...main"
    $Incremental = $true
} else {
    Write-Host "Fetching Plezy commits since plezy-jellyfin fork (full)..." -ForegroundColor Cyan
    $CompareUrl = "https://api.github.com/repos/edde746/plezy/compare/dkmcgowan:plezy-jellyfin:main...main"
    $Incremental = $false
}

$Response = Invoke-RestMethod -Uri $CompareUrl -Headers @{ Accept = "application/vnd.github+json" }

$BaseCommit = $Response.base_commit.sha.Substring(0, 7)
$TotalCommits = $Response.total_commits
$AllCommits = $Response.commits

# Commits are oldest-first; reverse for newest-first display
$AllCommits = $AllCommits | Sort-Object { $_.commit.author.date } -Descending

$Relevant = @()
foreach ($c in $AllCommits) {
    $firstLine = ($c.commit.message -split "`n")[0]
    if (Test-CommitRelevant -Message $firstLine) {
        $Relevant += [PSCustomObject]@{
            Sha     = $c.sha.Substring(0, 7)
            Date    = $c.commit.author.date
            Message = $firstLine
            Url     = $c.html_url
        }
    }
}

# Summary
$RangeDesc = if ($Incremental) { "since last check ($BaseCommit)" } else { "since plezy-jellyfin fork" }
Write-Host "`n--- Plezy upstream analysis ($RangeDesc) ---" -ForegroundColor Green
Write-Host "Base: $BaseCommit | New commits: $TotalCommits"
Write-Host "Potentially relevant (UI/player, non-Plex): $($Relevant.Count)"

# Table
Write-Host "`n--- Potentially relevant commits (newest first) ---" -ForegroundColor Green
$Relevant | ForEach-Object {
    $d = [DateTime]::Parse($_.Date).ToString("yyyy-MM-dd")
    Write-Host "  $d  $($_.Sha)  $($_.Message)"
    Write-Host "      $($_.Url)"
}

if ($WriteDoc) {
    $LastSha = if ($AllCommits.Count -gt 0) { $AllCommits[0].sha.Substring(0, 7) } else { $BaseCommit }
    $LastDate = (Get-Date).ToString("yyyy-MM-dd")

    $Md = @"
# Upstream Plezy Commit Analysis

**Last checked:** $LastDate
**Last Plezy commit processed:** ``$LastSha`` (main)
**Fork baseline:** `dkmcgowan/plezy-jellyfin:main`

Finzy is a fork of Plezy (adapted for Jellyfin). This doc lists Plezy commits that may contain UI or media-player improvements relevant to Finzy. Plex-specific changes are filtered out.

Re-running the script fetches only commits since ``$LastSha`` (incremental). Use ``-Full`` to compare from the fork.

## How to re-check

``````powershell
.\scripts\check_plezy_upstream.ps1 -WriteDoc   # Incremental (since last SHA)
.\scripts\check_plezy_upstream.ps1 -Full -WriteDoc   # Full comparison from fork
``````

## Potentially relevant commits (newest first)

| Date | SHA | Message | Link |
|------|-----|---------|------|
"@
    foreach ($r in $Relevant) {
        $d = [DateTime]::Parse($r.Date).ToString("yyyy-MM-dd")
        $msg = $r.Message -replace '\|', '\|' -replace '\r?\n', ' '
        $Md += "`n| $d | $($r.Sha) | $msg | [view]($($r.Url)) |"
    }
    $Md += "`n"

    Set-Content -Path $DocPath -Value $Md.TrimEnd() -NoNewline
    Write-Host "`nWrote $DocPath" -ForegroundColor Green
} else {
    Write-Host "`nRun with -WriteDoc to update docs/UPSTREAM_PLEZY_ANALYSIS.md" -ForegroundColor Cyan
}
