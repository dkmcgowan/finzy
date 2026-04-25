# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Finzy is a Flutter-based Jellyfin client targeting iOS, Android (phone + TV), macOS, Windows, and Linux. It is a fork of Plezy (a Plex client) adapted to the Jellyfin API — that heritage shows up in architecture and comments, and the `docs/UPSTREAM_PLEZY_ANALYSIS.md` / `docs/PLEZY_UPSTREAM_PORTING_PLAN.md` files track ongoing alignment with upstream.

`pubspec.yaml` pins **Dart SDK `^3.8.1`** (which ships with Flutter ≥ 3.32). CI builds on `channel: stable` for most jobs; **Windows and Linux ARM64 are forced onto `channel: master`** because ARM64 isn't on the stable channel yet, and within master those jobs are pinned to a specific revision (`5f58b37fdaa`) before an unresolved upstream regression in ARM input handling — see `.github/workflows/build.yml` and [flutter/flutter#184954](https://github.com/flutter/flutter/issues/184954). When the upstream fix lands (or stable picks up ARM64) the pin can be dropped.

## Common commands

```bash
# First-time / after pulling
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift + json_serializable codegen
dart run slang                                             # regenerate lib/i18n/strings*.g.dart

# Run
flutter run                                                # default connected device
flutter run --dart-define=GIT_COMMIT=$(git rev-parse HEAD) # stamp commit in startup log / About screen

# Local checks
find lib -name "*.dart" ! -name "*.g.dart" -print0 \
  | xargs -0 dart format --output=none --set-exit-if-changed
flutter analyze                              # see notes — warnings exist today and aren't a hard gate
dart run dart_code_linter:metrics check-unused-code lib
dart run dart_code_linter:metrics check-unused-files lib
```

Notes:
- **The build must succeed** — that's the hard requirement. `flutter analyze` currently surfaces a backlog of *warnings*; resolving them is ongoing cleanup work but not a blocker for changes you make. Don't introduce new warnings, but don't gate your work on getting analyze to zero either. (`.github/workflows/ci.yml` still fails on warnings; treat that as aspirational rather than a current invariant.)
- Analyzer **errors** are still a hard no — fix any you introduce.
- `*.g.dart` is excluded from analyzer and format checks — do not hand-edit; regenerate with `build_runner`.
- Line width is 120 (`analysis_options.yaml` → `formatter.page_width`).
- After editing any model with `@JsonSerializable` or any `drift` table, re-run `build_runner`.
- After editing any `lib/i18n/*.i18n.json`, re-run `dart run slang`.
- **No `test/` directory exists yet** — `flutter test` is a no-op today. If you add tests, the CI job already handles them.

## Setup gotchas

- **Git-sourced dependencies.** `os_media_controls` and `wakelock_plus` are pinned to forks under `github.com/dkmcgowan/*` in `pubspec.yaml`, not pub.dev. `flutter pub get` needs network access to those repos.
- **`source_gen` override.** `dependency_overrides` forces `source_gen: ^4.1.2` — without it, `build_runner` breaks against analyzer 8+ (the comment in `pubspec.yaml` explains why). Don't "tidy it away."
- **`scripts/release.sh` requires `.env`** at repo root and hard-exits if missing. It shells out to the `claude` CLI to trim per-store changelogs.

## Architecture

### Entry point and DI

`lib/main.dart` is the composition root. It instantiates long-lived singletons (`MultiServerManager`, `DataAggregationService`, `AppDatabase`, `DownloadManagerService`, `OfflineWatchSyncService`) once inside `_MainAppState.initState`, then exposes them through a `MultiProvider` tree from the `provider` package. The tree uses `ChangeNotifierProxyProvider` / `ProxyProvider2` to encode real dependencies between providers — e.g. `OfflineModeProvider` depends on `MultiServerProvider`; `OfflineWatchProvider` depends on the sync service + `DownloadProvider`. Order matters; adding a provider out of order can silently break wiring. New shared state should be wired here, not constructed ad-hoc in screens.

`SetupScreen` is the bootstrap gate: it loads registered servers from `ServerRegistry`, calls `ServerConnectionOrchestrator.connectAndInitialize` (with a 2-second retry for cold-start TCP flakiness on mobile/TV), and routes to `AuthScreen` or `MainScreen` — including a dedicated offline `MainScreen(isOfflineMode: true)` branch when no server is reachable.

### Multi-server model

Finzy supports multiple Jellyfin servers simultaneously. The layers:

- `lib/services/jellyfin_client.dart` — per-server `JellyfinClient` wrapping the Jellyfin REST API via `dio`. Single source of truth for API calls; extend it rather than creating parallel clients. Intentionally has **no 401 interceptor**: runtime 401s mark a server offline rather than bouncing to login.
- `lib/services/server_registry.dart` — persistence of registered servers in `SharedPreferences`.
- `lib/services/multi_server_manager.dart` — owns the set of active `JellyfinClient`s, health checks, reconnection.
- `lib/services/data_aggregation_service.dart` — cross-server queries (unified hubs, search, etc.).
- `lib/services/server_connection_orchestrator.dart` — startup/reconnect flow that stitches the above together.
- `lib/providers/multi_server_provider.dart` + `server_state_provider.dart` — UI-facing `ChangeNotifier`s.

In practice, most single-server screens receive a concrete `JellyfinClient` via constructor (e.g. `MainScreen(client: ...)` in `main.dart`). Use `MultiServerProvider` / `DataAggregationService` when the feature is cross-server or server-agnostic; don't force everything through the aggregation layer.

### Offline / downloads / cache

`lib/database/app_database.dart` is a Drift (SQLite) database with four tables: `DownloadedMedia`, `DownloadQueue`, `ApiCache`, `OfflineWatchProgress`. `schemaVersion` is currently 11 — bump it and add a migration branch in `MigrationStrategy.onUpgrade` when schema changes. The v10 path uses destructive `deleteTable` + `createAll`; the v11 `isTranscoded` addition uses an idempotent `PRAGMA table_info` check before `addColumn`. Follow the v11 pattern for new migrations — destructive migrations wipe user download state.

- `DownloadManagerService` + `DownloadStorageService` drive downloads; `background_downloader` + `workmanager` handle the platform side.
- `ApiCache` (see `lib/services/api_cache.dart`) stores JSON responses so offline mode can still render metadata.
- `OfflineWatchSyncService` + `OfflineWatchProvider` reconcile locally-recorded playback progress back to the server when connectivity returns. It listens to `OfflineModeProvider`'s connectivity stream — see the provider wiring in `main.dart`.

### Playback

Two backends behind a shared `Player` abstraction in `lib/mpv/` (internal code under `lib/`, not a separate pub package):

- macOS, iOS, Windows, Linux: **libmpv** via `lib/mpv/player/player_native.dart` (plus `platform/player_linux.dart`, `player_windows.dart`). iOS/macOS link MPVKit; desktop uses libmpv directly. Shader assets live in `assets/shaders/{nvscaler,anime4k}/` and are loaded via `ShaderService` / `ShaderProvider`.
- Android: **ExoPlayer** through `lib/mpv/player/player_android.dart`.

`lib/services/playback_initialization_service.dart`, `playback_progress_tracker.dart`, `track_selection_service.dart`, and the orchestrators under `lib/widgets/video_controls/` compose the player with Jellyfin-specific concerns (progress reporting, subtitle/audio track selection, trickplay, chapters, skip-intro segments, ambient lighting, PiP). External player support (VLC/PotPlayer/etc.) goes through `external_player_service.dart`.

### UI structure

- `lib/screens/` — top-level routes. `main_screen.dart` is the post-auth shell; tabs live under `screens/libraries/tabs/`, `screens/livetv/tabs/`, etc. `video_player_screen.dart` is the playback surface.
- `lib/widgets/` — shared widgets. Most are focus-aware (`focusable_*`) because the app must be fully usable with a D-pad on Android TV and with keyboard/gamepad on desktop.
- `lib/theme/` — `mono_tokens.dart` + `mono_theme.dart` define the design system; `ThemeProvider` exposes it to `MaterialApp`.
- `lib/focus/` — the **focus/input-mode system**. `InputModeTracker` (wrapped around `MaterialApp` in `main.dart`) distinguishes keyboard/D-pad navigation from pointer input so focus rings only appear in keyboard mode. `dpad_navigator.dart`, `focus_memory_tracker.dart`, and `locked_hub_controller.dart` implement TV-style navigation. When adding a widget that can receive focus, check if a `focusable_*` counterpart already exists in `lib/widgets/` before rolling your own.

### Android TV / D-pad navigation (read before any UX change)

Android TV is a first-class target and **UX changes routinely break D-pad navigation** when contributors don't follow the existing patterns — wrong widget choice, missing focus restoration on back, broken Back-key handling in modals, or hand-rolled focus logic that ignores `InputModeTracker`. Before modifying any screen, dialog, list, grid, or tab strip, look at the canonical examples below and reuse the existing primitives instead of rolling your own.

**Reference patterns to copy from:**

- **Dialogs / bottom sheets** — `lib/screens/libraries/filters_bottom_sheet.dart` is the canonical example: multiple focus zones, manual `KeyEventResult` handling for Back/Up/Down/Select, `ExcludeFocusTraversal` to prevent default traversal while keeping manual control, and Back-key suppression to avoid double-dismiss after popping a nested view. `lib/screens/libraries/sort_bottom_sheet.dart` is a simpler version of the same pattern (single focus zone, calls `OverlaySheetController.refocus()` after state changes).
- **Detail pages with app bar + grid** — `lib/screens/hub_detail_screen.dart` and the `FocusableDetailScreenMixin` in `lib/screens/focusable_detail_screen_mixin.dart`. They handle app-bar button cycling, grid focus restoration via `GridFocusNodeMixin` (`lastFocusedGridIndex` / `shouldRestoreGridFocus`), and auto-focus the first grid item when arriving in keyboard mode.
- **Tabbed screens** — `lib/screens/libraries/libraries_screen.dart` plus `TabNavigationMixin`: gamepad L1/R1 tab switching, `FocusableTabChip` for tab focus, and focus suppression during programmatic tab changes.

**Primitives to reuse, not reinvent:**

- `lib/focus/`: `dpad_navigator.dart` (`isBackKey` / `isSelectKey` / `isDpadDirection` extensions), `focus_memory_tracker.dart` (restore last-focused item), `locked_hub_controller.dart` (per-hub focus memory + column hint), `focus_theme.dart` (shared focus decoration), `focus_utils.dart` (find-and-focus first focusable in a subtree), `focusable_chip_mixin.dart`, `focusable_wrapper.dart` (base wrapper with D-pad + long-press + nav callbacks).
- `lib/widgets/focusable_*.dart`: `focusable_media_card.dart` (grid item with auto-scroll), `focusable_list_tile.dart`, `focusable_tab_chip.dart`, `focusable_filter_chip.dart`, plus the shared `focus_builders.dart` static helpers (`buildFocusableChip`, `buildFocusableCard`, `buildLockedFocusWrapper`).
- Mixins: `tab_navigation_mixin.dart`, `grid_focus_node_mixin.dart`, `focusable_detail_screen_mixin.dart`.

If a UX change adds, removes, or rearranges focusable elements, verify D-pad behaviour explicitly: tab in/out with Up/Down/Left/Right, Back returns to the prior focus, and focus rings appear only in keyboard/D-pad mode (not after a mouse click). If you can't run an Android TV build, say so rather than claiming success.

### i18n

`slang` with JSON sources in `lib/i18n/{locale}.i18n.json` and generated code in `lib/i18n/strings*.g.dart`. Access via the generated `t.section.key` after `LocaleSettings.setLocale(...)` and wrapping with `TranslationProvider` (done in `main.dart`). See `docs/CONTRIBUTING.md` for workflow; always rerun `dart run slang` after edits.

### Generated files

All `*.g.dart` (including `lib/i18n/strings*.g.dart` and `lib/database/app_database.g.dart`) are generated and excluded from analyzer and format checks. Regenerate from sources; do not hand-edit.

## Linter rules

`analysis_options.yaml` layers `flutter_lints` + `dart_code_linter`'s `recommended` preset, then selectively enables TV/Flutter-specific rules (`avoid-border-all`, `avoid-shrink-wrap-in-lists`, `prefer-const-border-radius`, `use-setstate-synchronously`, etc.) and disables noisy ones (`no-magic-number`, `avoid-dynamic`, `member-ordering`, `prefer-trailing-comma`, …). Metric thresholds are deliberately loose (`cyclomatic-complexity: 70`, `source-lines-of-code: 500`, `long-method: 500` lines); violations surface as `info`-level messages and are tolerated by CI. The hard CI gates are: zero analyzer errors, zero analyzer warnings, no unused code, and no unused files.

## Platform quirks to keep in mind

- **iPadOS 26.1+ modal bug**: `main.dart` installs a global pointer guard (`_installZeroOffsetPointerGuard`) that cancels fake `(0,0)` touch events. Remove when Flutter #179643 ships — the comment tracks the upstream fix.
- **Android cold start**: network/TCP may not be ready on app resume; `_MainAppState.didChangeAppLifecycleState` delays `checkServerHealth`/`reconnectOfflineServers` by 2 seconds. Mirror this pattern if adding resume-time network work.
- **Desktop-only init**: `window_manager`, `MacOSTitlebarService`, and `GamepadService` are guarded by `Platform.isMacOS/isWindows/isLinux` in `main()`.
- **Android TV** is a first-class target — anything focus/gesture-related should be verified with the D-pad, not just mouse/touch. See **Architecture → Android TV / D-pad navigation** for the canonical patterns and primitives; UX changes that don't follow them tend to break TV navigation.

## Other top-level directories

- `server/` — a **standalone Go WebSocket relay** (room-based, with rate limiting and `autocert` TLS). Not built or referenced by the Flutter client; it's a companion service and out of scope for app-side changes unless you're explicitly working on it.
- `tool/` — i18n translation-fill helpers (`apply_i18n_fill.dart`, `compare_i18n.dart`, `gen_i18n_fill.py`, `i18n_fill.json`). Used when syncing strings across locales.
- `Casks/finzy.rb` — Homebrew cask manifest. Updated by `.github/workflows/update-cask.yml`; don't hand-edit.
- `winget/manifests/` — Windows Package Manager manifests. Updated by `.github/workflows/update-winget.yml` and `scripts/update-winget.ps1`; don't hand-edit.
- `scripts/release.sh` — release/changelog tooling; shells out to the `claude` CLI to trim per-store changelogs. Requires `.env`.

## Useful docs in-tree

- `docs/CONTRIBUTING.md` — the authoritative how-to for i18n and local checks.
- `docs/FEATURES.md` — full feature inventory and roadmap.
- `docs/PLAN_TRANSCODING_AND_DOWNLOADS.md` — design notes for the downloads/transcoding pipeline.
- `docs/UPSTREAM_PLEZY_ANALYSIS.md`, `docs/PLEZY_UPSTREAM_PORTING_PLAN.md` — context when porting changes from Plezy.
