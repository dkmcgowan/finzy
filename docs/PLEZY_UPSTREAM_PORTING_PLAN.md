# Plezy Upstream Porting Plan

This plan identifies which commits from [UPSTREAM_PLEZY_ANALYSIS.md](UPSTREAM_PLEZY_ANALYSIS.md) are worth porting to Finzy, based on comparing Plezy's code changes to Finzy's current codebase. Finzy has diverged for Jellyfin, so many commits are not applicable.

---

## Summary

| Category | Count | Action |
|----------|-------|--------|
| **Port** | ~25 | Apply changes; Finzy has equivalent code |
| **Review** | ~30 | Inspect diff; may apply with adaptation |
| **Skip** | ~160 | Plex-specific, Watch Together, Sentry/Sparkle, or no equivalent |

---

## Tier 1: Port (High confidence, clear benefit) [REVIEWED]

These fixes address bugs or UX improvements in code Finzy shares with Plezy. The changes are small and the benefit is clear.

### 1. Guard missing library in libraries screen
- **Plezy:** [04ef1b8](https://github.com/edde746/plezy/commit/04ef1b8ad2c6bbb6f7a5e72e17090598c082a18b)
- **Finzy file:** `lib/screens/libraries/libraries_screen.dart`
- **Change:** Use `firstOrNull` instead of `firstWhere` when resolving `selectedLibrary` and in `_LibraryManagementSheetState`. Prevents `StateError` when the selected library is temporarily absent during server re-probe (e.g. after LOW_MEMORY).
- **Finzy status:** Uses `firstWhere` with `orElse` in similar places (lines ~1355, ~915, ~1204). The Plezy patch adds a defensive `selectedLibrary` variable and guards `if (selectedLibrary != null)` before rendering tab content.

### 2. Guard scrollListToIndex against multiple scroll positions
- **Plezy:** [9a296b3](https://github.com/edde746/plezy/commit/9a296b3da8dec05da4d30ba45675dba433549ec1)
- **Finzy file:** `lib/utils/scroll_utils.dart`
- **Change:** Replace `!controller.hasClients` with `controller.positions.length != 1`. Prevents issues when the controller temporarily has multiple positions during widget rebuilds (e.g. Android TV).
- **Finzy status:** Uses `hasClients` (line 17). One-line change.

### 3. Guard ScrollController.position in HorizontalScrollWithArrows
- **Plezy:** [cb7de47](https://github.com/edde746/plezy/commit/cb7de47aed42067163e68c7f15c754ade1072db4)
- **Finzy file:** `lib/widgets/horizontal_scroll_with_arrows.dart`
- **Change:** In `_updateScrollState()` and `_animateScroll()`, guard with `_scrollController.positions.length != 1` before accessing `position`. Prevents "Too many elements" StateError on Android TV during rebuilds.
- **Finzy status:** No guard; directly accesses `position` (lines 58–59, 67–68).

### 4. Overlay timestamp inside timeline thumbnail preview
- **Plezy:** [4147bd0](https://github.com/edde746/plezy/commit/4147bd0d863fb5200fba447ea6b1bfd1c4e5bd86)
- **Finzy file:** `lib/widgets/video_controls/widgets/timeline_slider.dart`
- **Change:** Overlay the timestamp inside the thumbnail (bottom of image) instead of below it. Uses a Stack; timestamp is a semi-transparent badge at bottom of thumbnail. When no thumbnail, show timestamp only.
- **Finzy status:** Uses Column with thumbnail and timestamp below (lines 117–145). Finzy uses `_ThumbnailContainer` (URL-based) vs Plezy's `Image.memory`; adapt by wrapping thumbnail in Stack and overlaying timestamp.

### 5. Guard mpv event handler during disposal
- **Plezy:** [f04b49e](https://github.com/edde746/plezy/commit/f04b49e260d8b496b8ef7056f4a155e415799f68)
- **Finzy file:** `android/app/src/main/kotlin/com/dkmcgowan/finzy/mpv/MpvPlayerCore.kt`
- **Change:** Add `if (disposing) return` at the start of `event(eventId: Int)` to avoid handling events after disposal.
- **Finzy status:** Has `event()` at line 403; no disposal guard.

### 6. Guard unsafe .first/.last calls
- **Plezy:** [73fe9e0](https://github.com/edde746/plezy/commit/73fe9e054f7089267ccf104dbcf022b8fbef5603)
- **Finzy:** Search for `.first` and `.last` without null-safety; replace with `firstOrNull`/`lastOrNull` or `firstWhere(..., orElse: ...)` where appropriate.
- **Scope:** Libraries, hub, media detail, and other screens that select from lists.

---

## Tier 2: Review (Worth inspecting; may need adaptation)

These touch shared areas but may require Jellyfin-specific adjustments or depend on structure that has diverged.

### Player / ExoPlayer / MPV [DONE]
- **3ea3455** – SurfaceControl use-after-free (Android ExoPlayerCore, MpvPlayerCore). Finzy has `ExoPlayerCore.kt` and `MpvPlayerCore.kt` under `com.dkmcgowan.finzy`. Port the dispose ordering and `postAtFrontOfQueue` pattern if structure matches.
- **0100b2a** – Preserve start position and subtitles in ExoPlayer→MPV fallback. Check if Finzy's Android fallback flow is similar.
- **5dbaf96** – ASS subtitles broken when DV mode enabled. Check if Finzy has same DV/ASS interaction.
- **e13b16f** – mpv boolean NPE on dispose (Android). Kotlin null-safety fix.
- **9dc0654** – dispatchWindowVisibilityChanged NPE during disposal (Android).
- **3627707** – cap demuxer buffers + sync mpv dispose (Android).
- **f96ef07** – move JSON parsing off main thread (Android).
- **6bee1a6** – opensles audio fallback (Android).
- **a4008d3** – move mpv operations off UI thread.
- **4121d56** – sanitize mpv event channel strings for valid UTF-8.
- **551bd83** – player disposed race condition.

### Track selection / subtitles [DONE]
- **5f597ef** – prefer exact language code match in track selection.
- **de28691** – track selection persistence with stale cache.
- **8baa84c** – use player.state.track for selected subtitle check.
- **94395fe** – sub-visibility toggle.
- **4bce668** – asymmetric divider in track sheet on landscape.
- **7001032** – combine audio & subtitle track sheets into one (UX change; Finzy has separate sheets).

### Downloads [DONE]
- **7a979be** – harden download callbacks against stale status events.
- **e46bd71** – prevent completed downloads from restarting on app launch.
- **b5904bc** – auto-retry large downloads after native retries exhausted.
- **c6ace69** – clean up download code duplication.

### Network / playback [DONE]
- **828d57a** – auto-reconnect stream after network loss during playback.
- **23a100a** – auto-reconnect VOD playback after network loss.
- **a3b5557** – use stream-lavf-o instead of stream-lavf-o-append for reconnect.
- **3c491be** – handle mpv end-file errors with global snackbar.
- **1b67374** – handle int end-file reason from mpv on Windows/Linux.

### UI / focus / dpad [SKIP]
- Finzy already has equivalent or better coverage via InputModeTracker, FocusableWrapper, overlay sheet autofocus-in-dpad-only, search focus, and scroll-into-view. No port needed.
- **8433d59** – Cmd/Ctrl+F shortcut to open search.
- **bbc7f0f** – focus search input on search tab.
- **dd11e8d** – scroll list tiles into view on dpad focus.
- **cde6e99** – dpad nav skipping episodes on single-season shows.
- **307fd35** – make overlay sheets dismissible when no descendant is focused.
- **8a28a2c** – only autofocus bottom sheets in keyboard/dpad mode.
- **0dbba64** – hide hero carousel indicators in dpad mode.
- **7cfa18e** – remove redundant thumbnail popup during dpad timeline seeking.
- **c56e73e** – add content strip for dpad navigation.
- **1629801** – swipe-up content strip for mobile video controls.

### Live TV [DONE]
- **e968a20** – soften EPG grid program styling. **Ported.** guide_tab.dart: reduce opacity (focused 0.25→0.15, airing→onSurface 0.12, else 0.05), add isFirst/isLast for border.
- **7a6b866** – fetch boundary-spanning programs. **Skip.** Plex API only.
- **6ccbaed** – always bold EPG program titles in guide grid. **Ported.** bodySmall→bodyMedium, fontWeight w600.
- **0372840** – localize EPG day names and reduce channel column width. **Ported.** DateFormat('EEEE', locale) for _dayLabel; _channelColumnWidth 140→100.
- **3bf7ff3** – improve LiveTV guide visual contrast and polish. **Skipped.** Finzy tabs/styling kept as-is.
- **e69fab8** – handle DVR tune error responses and show to user. **Ported.** showErrorSnackBar in _switchLiveChannel catch.
- **a3e7387** – handle Metadata as list in DVR tune response. **Skip.** Plex API only.

### Other [DONE]
- **67c66ff** – prevent layout shift for image placeholders. **Ported.** OptimizedImage: SizedBox around placeholder when width/height known.
- **78052dc** / **6fa6b34** – player stuck on skip credits with no next episode. **Ported.** video_controls: onBack when outro at end + no next; video_player_screen: exit when completed + no next.
- **174c78b** – handle connectivity_plus PlatformException on Windows. **Ported.** offline_mode_provider, download_manager_service: try/catch, assume network on error.
- **580c1d8** – stuck network check on Linux without NetworkManager. **Ported.** Same pattern in connectivity checks.
- **a17458f** – handle DBusServiceUnknownException on Linux. **Ported.** onError on connectivity stream; Sentry skipped (Finzy has none).
- **34e8c17** – guard PiP calls on unsupported platforms. **Ported.** PipService: _isAvailable (Android/iOS/macOS only).
- **5ab6af1** – respect system 24h time format setting. **Ported.** TimeFormat.system, use24HourTime(context), formatFinishTime(use24Hour).
- **34252b9** – persist aspect ratio and shader settings. **Ported.** SettingsService get/setDefaultBoxFitMode; VideoFilterManager initialBoxFitMode, onBoxFitModeChanged.
- **c372920** – resolve out-of-scope settingsService in video player. **Ported.** Covered by 34252b9.

---

## Tier 3: Skip (Not applicable)

### Plex-specific
- **1f7fb22** – handle null ratingKey (Plex API).
- **a82c3d2** – grouping/type filtering for shared libraries (Plex /library/shared).
- **551be5b** – dynamic library tabs and shared library navigation (Plex model).
- **819d7b0** – scope library display settings per user profile (Plex profile model).
- **682a04f** – per-server connection status on splash (Plex multi-server UI).

### Watch Together (Finzy uses SyncPlay; not implemented)
- **beff4f9**, **efac1a9**, **8f3d521**, **cf8f184** – Watch Together flows and teardown.

### Sentry / Rustrak / Glitchtip / Sparkle
- **25c7f32**, **c62e406**, **19c36ca**, **e60b8d1**, **a9e4091**, **7825490** – Sentry/Rustrak/Glitchtip.
- **92dfe5b**, **965d954**, **cc86afb**, **bec8b59** – Sparkle / auto_updater (macOS).

### Cronet / OkHttp (Android networking) [DONE]
- **af0de5c** – switch from OkHttp to Cronet. **Ported.** ExoPlayerCore: CronetDataSource, HTTP/2 multiplexing.
- **d01628a** – OkHttp connection pooling. **Superseded by af0de5c** (Cronet includes connection reuse + larger buffers).

### Dolby Vision / libdovi (platform-specific)
- **317d5db** – DV Profile 7/8.1 RPU conversion via libdovi.
- **268f293** – deduplicate Dolby Vision conversion code.
- **5f4e4bf** – ExoPlayer fallback for unsupported DV formats. **Ported.**

### Refactors — Skip (not applicable)
Plezy refactors that target its own structure; Finzy has diverged and these do not map.
- **3c2f72d**, **23906dd**, **630755c**, **e9f1979** – remove dead code in Plezy services/providers/utils/models (Finzy structure differs; no 1:1 mapping).
- **db6161d** – NavigationTabId (Plex tab model; Finzy uses different navigation).
- **5538e06** – remove SeasonDetailScreen, unify into MediaDetailScreen (Finzy keeps SeasonDetailScreen by design).
- **551be5b** – dynamic library tabs (Plex shared-library model; Jellyfin differs).

### Other — analysis

**Worth porting**
- **45726a5** – log git commit hash. **Ported.** GIT_COMMIT from build, startup log, logs-screen copy header. CI passes GIT_COMMIT via dart-define.
- **7ac888c** – fix(windows): installer norun arg. **Ported.** `finzy-installer.exe /NORUN=1` skips post-install launch.

**Already handled / not applicable**
- **8f1b40d** – childCount as string. Finzy's `_toInt()` already handles String via `int.tryParse`. Skip.
- **8571ee7** – addedAt for on-deck sort. Finzy sorts Continue Watching by `lastPlayedAt ?? updatedAt ?? addedAt`. Different API, already correct. Skip.
- **9c7cb74** – winget support. Finzy has `update-winget.yml` and manifests. Skip.

**Plex/Jellyfin-specific — skip**
- **863f90f** – series-level subtitle mode (Plex model).
- **9e2e1f7** – remove debug token i18n (Plex-specific).
- **c64c7de** – disable session tracking (Plex).

**Infrastructure / config — skip**
- **02e175e**, **cd36e3a**, **229d6b2** – crash reporting (Rustrak/BugSink). Finzy has no crash reporting.
- **33d5760** – play store release config.
- **8b2c68f** – Windows libmpv from SourceForge. Finzy uses shinchiro/mpv-winbuild-cmake on GitHub.
- **92b5892** – libcurl4-openssl-dev. Finzy's Linux build uses gnutls for ffmpeg, not libcurl.

**Consider separately**
- **66628e1** – add pt, ja, ru, pl, da, nb translations. Finzy has en, de, es, fr, it, nl, ko, sv, zh. Optional i18n expansion.
- **c8e6cac**, **938291d**, **7c0e86c** – bump mpv/mpvkit versions. Check when upgrading.
- **f571598** – migrate iOS to scene lifecycle. Finzy builds iOS; evaluate if needed for Flutter/iOS best practice.

---

## Recommended implementation order

1. **scroll_utils.dart** (9a296b3) – one-line fix.
2. **horizontal_scroll_with_arrows.dart** (cb7de47) – small guard.
3. **libraries_screen.dart** (04ef1b8) – defensive firstOrNull.
4. **MpvPlayerCore.kt** (f04b49e) – disposal guard in event handler.
5. **timeline_slider.dart** (4147bd0) – timestamp overlay UX.
6. **73fe9e0** – audit and fix unsafe .first/.last across lib.
7. Then work through Tier 2 as needed, starting with player/ExoPlayer/MPV and downloads.

---

## How to use this plan

1. Run `.\scripts\check_plezy_upstream.ps1 -WriteDoc` to fetch new Plezy commits since last run (incremental). Use `-Full` for a full comparison from the fork.
2. Pick a commit from Tier 1 or Tier 2.
3. Open the Plezy commit link and view the diff.
4. Locate the equivalent file(s) in Finzy.
5. Apply the change, adapting for Jellyfin where necessary.
6. Test on the affected platforms (especially Android for player changes).
7. Mark the commit as done in this doc (e.g. add `**Ported.**` next to the SHA).
