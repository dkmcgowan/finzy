Library filters reworked for Jellyfin (grouped categories, multi-value, full TV/keyboard navigation), simplified settings, transcoded playback fixes, and the startup update dialog is gone — updates are now a quiet check on the About screen.

Full release notes

## Library Filters & Browsing

- **Filters sheet rework**: grouped categories (Filters, Features, Genres, …), multi-value Jellyfin filters, full TV/keyboard navigation, Escape/Back parity with header buttons
- Better overlay focus handling: retain sheet focus on sub-page transitions, focus recovery after toggles, side rail no longer steals focus while a sheet is open
- **Fix**: filter sheet no longer locks open when you back out of a subsection without selecting anything (TV/D-pad)
- Sort sheet, bottom sheet header, and library browse integration polish

## Playback & Transcoding

- **Transcoded playback navigation fixed** — seek/skip work correctly across reseeks
- Playback OSD stays visible across transcode reseeks (no more flicker-on-seek)
- Progress reporting now uses **movie time, not stream time**, for transcoded playback (resume position is correct)
- Removed leftover Plex-residue UI from the player

## Settings & About

- Settings list reordered: About remains the last navigable section, Quick Connect below it, Logout last
- **Startup update dialog removed.** App no longer interrupts launch to nag about updates. The About screen shows the current version, "New version X available" passively when relevant, and a manual "Check for updates" button — the OS stores (App Store, Play Store, Microsoft Store, winget, Brew) handle their own updates
- Audio and subtitle overlay sheets merged into a single **TrackSheet** opened from one control
- In-app support/donation entry point removed (PayPal tip kept in README for visitors)
- New `update.checking` / `newVersionAvailable` / `checkForUpdatesButton` strings translated across all locales

## Android TV / D-pad Polish

- **TV detail back** scrolls with the hero animation (smoother return)
- Pointer-exit no longer hides the OSD on Android TV (kept the remote-friendly behavior)
- Dropped unused track sheets that complicated focus traversal

## Other Fixes

- Jellyfin profile avatars now display correctly when no image tag is stored locally
- Streamlined sign-in UI flow

## Build, CI, Tooling

- Windows + Linux ARM64 build jobs stay on the Flutter `master` channel because ARM64 isn't on `stable` yet, and are pinned to a specific master revision to avoid an upstream input-handling regression on ARM ([flutter/flutter#184954](https://github.com/flutter/flutter/issues/184954), reported by us, not yet merged). Other targets (x64 / macOS / Android) remain on `stable`.
- Dropped the `ENABLE_UPDATE_CHECK` build flag — update check is always on now
- Added `CLAUDE.md` for in-repo Claude Code project guidance
- `.claude/settings.local.json` now gitignored (per-developer Claude Code state)
- Removed debug logging from library sheets / overlay code
- Translation-fill helpers in `tool/`
- Android adaptive launcher foreground assets refreshed; Gradle, Windows CMake, and pubspec dependency updates
