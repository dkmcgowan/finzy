Filters reworked for Jellyfin (grouped categories, multi-value, full TV/keyboard nav), smoother offline/reconnect UX, transcoded playback fixes, ExoPlayer subtitle and mpv streaming fixes, playback speeds up to 8×, and the startup update dialog is gone — updates are now a quiet check on the About screen.

Full release notes

## Connectivity & Offline

- **"Go offline" button** on the setup screen when initial connect is stuck — a manual escape hatch instead of being dumped straight into offline mode
- Offline auto-navigation is held until the button is tappable, then resumes after a ~30s window if no action is taken
- Reconnect indicator: spinning icon with a 5s visual minimum so it doesn't flash, button reserves its space to avoid layout jumps, re-clicking the button stops the spinner

## Library Filters & Browsing

- **Filters sheet rework**: grouped categories (Filters, Features, Genres, …), multi-value Jellyfin filters, full TV/keyboard navigation, Escape/Back parity with header buttons
- Better overlay focus handling: retain sheet focus on sub-page transitions, focus recovery after toggles, side rail no longer steals focus while a sheet is open
- **Fix**: filter sheet no longer locks open when you back out of a subsection without selecting anything (TV/D-pad)
- Sort sheet, bottom sheet header, and library browse integration polish

## Playback & Transcoding

- **Transcoded playback navigation fixed** — seek/skip work correctly across reseeks
- Playback OSD stays visible across transcode reseeks (no more flicker-on-seek)
- Progress reporting now uses **movie time, not stream time**, for transcoded playback (resume position is correct)
- **Fix mpv 400 Bad Request** on Windows / macOS / Linux streaming
- **Fix subtitle selection on ExoPlayer** (Fire TV / Android)
- Playback speed range extended from 3× to **8×**
- DVR recording type fixed
- Removed leftover Plex-residue UI from the player

## Live TV & Metadata

- **Image cache busted on metadata refresh** via Jellyfin `ImageTag` — refreshed posters actually update now
- Image cache busted on Live TV channels and EPG programs
- Program details sheet image rendered at native aspect ratio
- Home hubs refresh on return from playback so progress / recently-watched are up to date

## Settings & About

- Settings list reordered: About remains the last navigable section, Quick Connect below it, Logout last
- **Startup update dialog removed.** App no longer interrupts launch to nag about updates. The About screen shows the current version, "New version X available" passively when relevant, and a manual "Check for updates" button — the OS stores (App Store, Play Store, Microsoft Store, winget, Brew) handle their own updates
- "Check for updates" moved into the Card list for TV reachability; re-entry guarded inside the action so the tile stays interactive
- Audio and subtitle overlay sheets merged into a single **TrackSheet** opened from one control
- In-app support/donation entry point removed (PayPal tip kept in README for visitors)
- New `update.checking` / `newVersionAvailable` / `checkForUpdatesButton` strings translated across all locales

## Android TV / D-pad Polish

- **TV detail back** scrolls with the hero animation (smoother return)
- Pointer-exit no longer hides the OSD on Android TV (kept the remote-friendly behavior)
- Search results list no longer clips focused card edges
- Dropped unused track sheets that complicated focus traversal

## Other Fixes

- Jellyfin profile avatars now display correctly when no image tag is stored locally
- Streamlined sign-in UI flow

## Build, CI, Tooling

- Windows + Linux ARM64 build jobs stay on the Flutter `master` channel because ARM64 isn't on `stable` yet, and are pinned to a specific master revision (`7b7832a30f`) to avoid an upstream input-handling regression on ARM ([flutter/flutter#184954](https://github.com/flutter/flutter/issues/184954), reported by us, not yet merged). Other targets (x64 / macOS / Android) remain on `stable`.
- Windows ARM64 long-path build fixed
- Amazon Appstore upload retries transient 5xx and connection errors
- Dropped the `ENABLE_UPDATE_CHECK` build flag — update check is always on now
- Added `CLAUDE.md` for in-repo Claude Code project guidance; `.claude/settings.local.json` gitignored
- `docs/PLAN_TESTING.md` — staged plan for the eventual test harness
- April 2026 Plezy upstream sweep added to the porting plan
- Removed debug logging from library sheets / overlay code
- Translation-fill helpers in `tool/`
- Android adaptive launcher foreground assets refreshed; Gradle, Windows CMake, and pubspec dependency updates
