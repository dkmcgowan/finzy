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

---

## April 2026 sweep (since `4147bd0`, through `d6b47f9` ~ 2026-04-26)

371 new upstream commits, 198 keyword-flagged. After manual triage, most of the volume was Plezy-direction work that doesn't apply to Finzy (see **Skip wholesale** below). The candidates that *are* worth a look are listed here as a queue — promote any of them into Tier 1 / Tier 2 above when you actually start porting. The doc bookmark in `UPSTREAM_PLEZY_ANALYSIS.md` has **not** been advanced; running `-WriteDoc` will refresh the table and move the bookmark forward in one shot when you're ready.

> **Likely the last sweep.** Plezy's direction has diverged enough (trakt, anime trackers, tvOS, networking rewrite, Plex shared-library UX, Sentry deep-integration) that incremental cherry-picking is hitting diminishing returns. After the planned de-multi-serverify refactor, line-level porting from Plezy will mostly stop being viable. Treat this as a final pass.

### Port (small, clearly applicable)

- **62e3cbc** – chain adjacent-episode load behind play queue.
- **3433dcb** – clean up stale SAF target file before re-enqueue (Android downloads).
- **23d958f** – guard `ensureAbsolutePath` against `RangeError` on short paths.
- **425da3a** – overlay-sheet barrier in `Positioned.fill`.
- **557ef69** – guard `setState`/context against disposed widget.
- **fd898e0** – JSON parse safety; stop mutating input maps.
- **f7e3408** – guard empty-list access in alpha jump bar / download tree.
- **2126a38** – bounds-safe action-bar focus-node access.
- **cd3db94** – guard library dropdown against empty list.
- **17eb37c** – back navigation on screens with no app-bar actions.
- **d56067e** – skip back navigation when overlay route is on top.
- **7c3cee6** – one-shot select-key activation in focus helpers.
- **9cca404** – guard player back pop with `canPop`.
- **f1867dd** – preserve PiP during episode auto-play.
- **f055759** – suppress position sync when app backgrounded.
- **82e605a** – don't close database on mobile suspend.
- **010ace5** – dispose `TextEditingController`s in settings dialogs.
- **4663c43** – artwork directory null crash on orientation change.
- **9984f42** – tabular figures on timeline timestamps.
- **8f326e6** – dpad nav trapping in density slider.
- **8d40ba3** – reduce blank space at media-card bottom.
- **5b493a7** – snackbar on playback speed change.
- **e0308be** – `mounted` check in `_toggleLibraryVisibility`.
- **f9d8549** – clamp tooltip upper bound to prevent `ArgumentError`.
- **122cff3** – await database close on desktop app exit.
- **4665f2a** – dispose services/subscriptions, persist client id.

### Review (player / mpv / ExoPlayer — may need adaptation)

- **8b34307** – re-select audio on renderer capabilities change (ExoPlayer).
- **59346f4** – restore `playWhenReady` after renderer recreation (ExoPlayer).
- **f87f0b0** – suppress spurious media pause during frame-rate switch.
- **2f7c87d** – subtitle background not rendering on mpv 0.38+ (verify our mpv version).
- **5880451** – try DV conversion before MPV fallback on decoder hang.
- **3c59452** – subtitle track matching (forced flag parsing, title scoring).
- **ef96ccb** – ordinal tiebreaker for identical track matching.
- **91057c1** – bold/italic subtitle toggles.
- **7ab6b97** – ±60s subtitle sync slider.
- **1cb793d** – `sub-ass-override` setting.
- **c034f9b** – request UTF-8 for external subtitles.
- **65e1970** – ExoPlayer external sub attach, non-ASS render.
- **81bac6e** – ExoPlayer libass performance.
- **a60e1e7** – ExoPlayer audio-delay and sub-delay support.
- **7b8a47a** – include previous episodes in play queue.
- **c6f2e94** – use configured skip setting for dpad/timeline seeking.
- **7c331e5** – auto-skip credits honors auto-play-next.
- **5cf53f8** – chapter keyboard shortcuts navigate chapters, not episodes.
- **8b40e09** – normalize EOF playback state.
- **fd1d187** – timeline thumbnail on dpad key-repeat.
- **3a69e49** – parallelize playback startup.
- **6d265e7** – episode next/prev hotkeys.
- **f47bcb6** – auto-hide performance overlay with controls.
- **c20bb93** – always show track selection button.
- **0b20300** – noisy audio pause on Android TV.
- **4322ffc** – disable Android TV PiP lifecycle regressions.
- **062fd82** – recover audio after Windows sleep via `ao-null-reload`.

### Review (UI / focus / TV)

- **eeed34e** – `ListView.builder` for folder tree (perf).
- **49a86e4** – stabilize grid column count when alpha bar shows.
- **93d1965** – clamp playlist focus index on remove.
- **f8132e7** – focus media-detail info rows.
- **77893bb** – detail screen section alignment.
- **91d191b** – file info bitrate units, multi-track display, TV scrolling.
- **3366b83** – hide spoilers in watch-next thumbnails.
- **f30e47d** – enforce min 2× DPR for TV image transcoding.
- **ddb4a91 / 11d2e40** – downsample local artwork in offline grids / hero.
- **dbb3e14** – skip offline video when different version requested.
- **7d35132** – M3 2024 slider style for video player timelines.
- **c9db6e5** – more consistent poster sizing.
- **8a66cf6** – HID key labels for non-keyboard USB pages.
- **16dd352** – hide live badge when timeshifted.
- **f5e0e8c** – "Start in fullscreen" option (Windows/Linux).
- **e63920e** – native monitor-aware fullscreen on Windows.
- **6371d7a** – Windows: black screen while navigating between videos in fullscreen.
- **d6b47f9** – Windows: suppress Steam Input duplicate actions.
- **19a0128** – ArtCNN shader presets (we ship nvscaler/anime4k already; could extend).
- **66b3246** – serialize file picker calls.
- **1b2ecd9** – standardize bool parsing with `flexibleBool` helper.

### Review (downloads / DB)

- **6eb5c84** – download cleanup, retry circuit breaker, SAF resume.
- **77401be** – Android SAF download deletion.
- **f69068e** – index `DownloadedMedia` hot columns (drift migration; bumps schemaVersion).

### Test infrastructure note

- **d4235a2** – unit tests for utils, models, settings, mpv parser. Worth reading when starting `docs/PLAN_TESTING.md` — directly aligned with Tier 1 of that plan (pure-Dart unit tests). Don't port their tests; use the file selection / setup as inspiration for what's testable without a harness.

### Skip wholesale (Plezy-direction, do not port)

- **Trakt + anime trackers** (MAL/AniList/Simkl, oauth proxy, per-tracker library whitelist, sync rules) — `ff2928b`, `1582fdb`, `e8729a4`, `bf2584d`, `e961bc6`, `a715f4e`, `df94e83`, `1949c22`, `3b7b532`, `bc57ffb`, `7f237c9`, `ee020d8`.
- **tvOS support** — `2479e1f`, `1de91a5`, `a13cfed`.
- **Networking rewrite**: dio → `package:http` → `win_http` on Windows + forced HTTP/2 — `15b22f7`, `87c308f`, `52b8944`, `bdd9d24`, `bc2febf`, `4243510`, `7150ea2`, `7528dce`, `e1c9ce6`, `fd701e5`. See "On the dio → win_http + HTTP/2 question" below — strategy decision, not a port.
- **Sentry / crash-reporting deep integration** — `e95475f`, `3be302d`, `66ebc54`, `15de884`, `cef8f5e`, `6cbf098`, `6c61e0e`. Finzy has no crash reporting.
- **Plex-specific UX** — server grouping & hidden-library browsing (`3d02396`), match/unmatch metadata (`431c20f`), square-art / logo metadata editor (`9d9d9bb`), encrypted LAN remote pairing (`d093023`, `cb455d3`, `a55650b`), pin EPG titles + cloud channel filter (`ee20965`), bandwidth-limit modal on stream 500 (`1e62c6c`).
- **Watch Together** — server hardening, room rejoin, buffering indicators — `34815f2`, `1d3ae3e`, `3cf1ebc`, `1e1bb91`, `74c6af2`, `0883fe2`. Finzy uses Jellyfin SyncPlay; not implemented.
- **Plezy-internal refactors** — `87696d7` (json_serializable for 9 manual models), `c36fee1` (DisposableChangeNotifierMixin to 11 providers), `5d87c68` (`sharedCache` routing), `0531c33` (typed `Pref<T>`), `d0a93d5`, `c369f2c`, `65e22fb`, `74b2d76`, `ee020d8`, `5937e5c`, `a262c94`, `1edf3da`, `e6c1923` (mpv box-fit dedup; only meaningful if porting `839465b` ExoPlayer box-fit modes — see Review).
- **Distribution / infra** — `06174af` (.deb crashpad perms), `d04781e` (baseline x86_64 mpv build), `caa70dd` (camera permission removal), `48ba923` (mpvkit/libmpv-android bump — track separately when upgrading), `8380980` (background_downloader fork ref).
- **Plex stream features** — `f926deb` clickable cast → actor filmography (Plex search model), `c10cf55` "transcoding" feat (Plezy adding what Jellyfin gives us natively), `eb49ead` paginate collection/playlist/person endpoints (Plex cursor model — verify before treating as portable).
- **Misc Plex/server-affinity** — `64d5c1f` force rediscover on manual reconnect, `4edf1a8` auto-start remote server, `497259c` close http clients on server replacement, `966b637` preserve download server affinity, `a7ba837` prevent white screen when no servers available — all touch the multi-server scaffolding we're about to remove. Defer until after the de-multi-server refactor.
