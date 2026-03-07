# Finzy 0.1.4 Release Notes

## Features & Improvements

- **Multi-server & profiles**
  - Profile switching in Settings
  - Quick Connect and logout options
  - Improved startup: if server is reachable but auth fails, redirect to login instead of offline mode

- **Settings**
  - New **Show Downloads** toggle to show/hide the Downloads tab
  - **Animations** setting inverted: now "Enable animations" (on by default) instead of "Reduce animations"
  - About section moved to last in Settings
  - MPV Config shown when using MPV for Live TV (not just on-demand playback)

- **TV & keyboard navigation**
  - D-pad support for sort and filter bottom sheets
  - View All navigation improvements
  - Focus restore after trailers and when returning to screens
  - Left-as-back in some flows
  - Top row focus fixes
  - Channel logos in Live TV

- **Video player**
  - Live TV UP arrow now works correctly
  - ESC: hide controls first, then exit
  - Keyboard navigation enabled by default

- **Downloads**
  - Header/tab layout fixes
  - Pull-to-refresh

- **Libraries**
  - Header/tab layout fixes
  - View All consistency across sections
  - Genre tab focus fixes
  - Favorites reset behavior

- **Live TV**
  - Header/tab layout fixes

- **App bar & layout**
  - App bar layout improvements
  - Floating back button on mobile

- **Discover**
  - Scroll behavior fixes

## Stability & Performance

- **Tooltips removed** entirely for stability
- **Animations** setting respected in more places (e.g. settings scroll)

## Build & CI

- **Single universal Android APK** instead of split-per-abi (arm64, armeabi-v7a, x86_64)
- Removed unused code and variables for CI
- Fixed analyzer warnings

## Screenshots

- Updated screenshots for phone, tablet, TV, desktop, and Windows
- Added WebP versions for smaller assets

## Code Cleanup

- Removed `library_inline_*` views (favorites, genre, list)
- Removed `sliver_adaptive_media_builder`
- Removed `handleBackKeyNavigation` and other dead code
