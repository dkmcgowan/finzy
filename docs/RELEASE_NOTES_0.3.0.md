Streaming quality in Settings, direct login for passwordless users (tap Demo tile), transcoding and download improvements, floating back button, and fixes across playback and Settings.

Full release notes

## Video Playback & Quality

- **Streaming Quality** and **Live TV Quality** added to Settings → Video Playback
- **Revert on failure**: when playback fails after a quality change, setting reverts and shows "Reverted to previous quality"
- Collapsed playback mode and transcode preset into simpler quality options
- **Download quality** setting for offline downloads
- **Pause/cancel** for transcoded playback
- Quality settings persist across app restarts
- Live TV quality list no longer spins indefinitely
- Transcode download: Dio fallback on desktop (fixes 0 bytes on Windows), progress polling, cancel deletes partial files
- Transcode UX: indeterminate bar when starting, "Starting..." label, speed display on desktop
- Playback initialization and video controls improvements
- Sleep timer UI consistency
- i18n updates for quality and related strings

## Login

- **Direct login for passwordless users**: tap the Demo (or any passwordless) user tile to log in—no manual login required (matches Jellyfin web behavior)

## UI & Navigation

- **Floating back button** on mobile during video playback
- **Touch scroll restoration**: fixed focus before navigate so grid position is restored when tapping items (InkWell canRequestFocus)
- **Settings screen refresh**: when switching to Settings tab after changing quality in the video overlay, values now update correctly
- **Store-aware update dialog**: "Update" routes to Play Store, App Store, or Amazon based on install source; skips for TestFlight

## Other Fixes

- Extras tv_banner filename fixed
- Remove unused _microsoftStoreUrl (analyzer fix)
- Move RELEASE_0.1.2 to docs folder

## Build & CI

- Microsoft Store logos (300×300, 150×150, 71×71) for Partner Center
- Fix GH_TOKEN to use `secrets.GITHUB_TOKEN` in Microsoft Store and Amazon upload workflows
- Simplified testing instructions (tap Demo tile instead of manual login)
- Android launcher icons updated (foreground, monochrome) with SVG sources

## Plezy Porting

- Upstream porting work and related improvements
