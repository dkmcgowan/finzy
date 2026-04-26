# Testing strategy plan

Status: not yet started. Captured here for when there's bandwidth to act on it.

The codebase has no `test/` directory today. CI's `Unit Tests` job already runs `flutter test` and currently no-ops because there's nothing to run — so adding tests requires zero workflow changes for Tiers 1–3.

## Why test-shape matters here

The actual bug pattern in this codebase, based on recent fix commits, is:

- `cc2673f` — mpv 400 from comma-bearing `Authorization` header
- `c65f9c3` — ExoPlayer subtitle selection on Android
- `35168c7` — DVR recording type fix
- earlier — mpv shader path resolution, transcoding param construction

Every one of these lives at the **boundary between Finzy and the player or server** — but the *cause* in each case was Finzy-side data being wrong before it crossed the boundary. So tests of "what we put on the wire" (URLs, headers, params, parsed responses) catch a disproportionate share of real regressions, even though they don't exercise the platform-specific player code itself.

What is **not** the bug pattern: pure UI rendering bugs caught by golden tests, or full E2E flows broken end-to-end. Don't optimize for those.

## Tiers, in build order

### Tier 1 — Pure Dart unit tests

**Cost:** very low. **CI:** runs in the existing `test` job. No infra changes.

Target the logic-dense layers that don't touch Flutter or platform code:

- **`JellyfinClient` parsing** — feed canned JSON, assert the `MediaMetadata` / `Hub` / `MediaLibrary` model objects. Catches schema drift.
- **URL construction** — streaming URLs (direct play, transcoded, subtitle download), `api_key` placement, transcoding params. *This is where a regression test for the mpv 400 fix would belong: assert the streaming URL the player will hit and assert the headers `requestHeaders` carries (no `Authorization`).*
- **Auth header builder** — `JellyfinConfig.authorizationHeader`. Lock in the `MediaBrowser ...` format.
- **Drift migrations** — use Drift's migration testing helpers. Spin up an in-memory DB at v10 with seed rows, run the v11 migration, assert state is preserved. The v10→v11 (`isTranscoded`) transition is exactly the kind of thing where a bad branch silently nukes downloads. Test every future migration.
- **`ApiCache`** — write/read/expiry semantics.
- **`OfflineWatchProgress` reconciliation** — given local progress + server progress, assert which wins.
- **Hidden libraries key format** — the `'${serverId}:$librarySectionId'` join key (relevant if multi-server is ever stripped — the test makes the format change explicit).
- **Track selection heuristics** — audio/subtitle picking logic in `track_selection_service.dart`.
- **Skip-intro / chapter / trickplay logic** — pure data transforms.

Target: 30–50 tests. Run time: <30s in CI.

### Tier 2 — Fake-server integration tests

**Cost:** low–medium. **CI:** runs in the existing `test` job (in-process `dart:io` HttpServer or dio interceptor — no external service needed).

Spin up a real `HttpServer` (or use `mocktail`/dio's `RequestInterceptor`) that returns canned Jellyfin responses on `/Users/AuthenticateByName`, `/Items`, `/Sessions/Playing/Progress`, etc. Then:

- Exercise `JellyfinClient` end-to-end and **inspect the actual HTTP requests it sends** — assert the Authorization header, assert URL params, assert request bodies. (This is the layer where the mpv 400 regression test actually belongs.)
- Test `MultiServerManager.connectToAllServers` with fakes that return success / timeout / 401 / 503 — verify offline detection and retry behavior.
- Test the offline reconnect timer with a fake `Clock` + fake server flipping between online/offline.
- Test `OfflineWatchSyncService` reconciliation: queue progress while "offline," bring server back, assert PUTs.

Target: 15–25 tests.

### Tier 3 — Flutter widget tests for focus/D-pad

**Cost:** low–medium. **CI:** runs in the existing `test` job (headless via `flutter test`).

Given how much code lives under `lib/focus/` and how often UX changes break Android TV navigation, this has surprisingly good ROI. `WidgetTester` supports `sendKeyEvent(LogicalKeyboardKey.arrowDown)` and friends, so D-pad behavior is testable without a TV.

Tests to write, mirroring the patterns CLAUDE.md already documents as easy to break:

- **Filters bottom sheet** (`lib/screens/libraries/filters_bottom_sheet.dart`) — focus moves between zones on Up/Down, Back closes without double-dismiss, manual `KeyEventResult` handling works.
- **Sort bottom sheet** (`lib/screens/libraries/sort_bottom_sheet.dart`) — `OverlaySheetController.refocus()` after state change.
- **Hub detail screen** (`lib/screens/hub_detail_screen.dart`) — focus restoration via `GridFocusNodeMixin` after Back from a media item.
- **Tabbed screens** (`lib/screens/libraries/libraries_screen.dart`) — gamepad L1/R1 cycles tabs, focus suppression during programmatic tab changes.
- **`focusable_media_card`** — auto-scroll into view when focused via D-pad.
- **`InputModeTracker`** — focus rings appear after keyboard input, disappear after pointer input.

Target: 8–12 tests. These are concentrated in the riskiest UX area.

### Tier 4 — Real Jellyfin smoke job in CI

**Cost:** medium one-time setup, ~3 min/run. **CI:** new job in `ci.yml`.

Pull `jellyfin/jellyfin` Docker image, bootstrap admin via Setup Wizard API, upload a tiny royalty-free clip (or use a built-in test asset), then run a small set of contract tests:

- Authenticate.
- List libraries.
- Fetch a streaming URL and assert it returns video bytes.
- Report playback progress.
- Fetch trickplay manifest if present.

GitHub Actions Linux runners support Docker natively — either as a `services:` block or `docker run` in a step. One Linux job. Don't multiply across platforms; one Linux is enough to lock the contract.

Sketch:

```yaml
real-jellyfin-smoke:
  runs-on: ubuntu-latest
  services:
    jellyfin:
      image: jellyfin/jellyfin:latest
      ports: ["8096:8096"]
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with: { channel: stable, cache: true }
    - run: flutter pub get
    - run: dart run tool/seed_jellyfin.dart  # bootstrap admin + upload clip
    - run: flutter test --tags real-server
```

Use `@Tags(['real-server'])` to keep these out of the default `flutter test` run.

## What to skip (at least until much later)

- **Golden / snapshot tests.** Brittle, churn with every theme tweak, low signal for the bug pattern this codebase actually has.
- **Full E2E `integration_test` runs on real devices.** Device farms across iOS / Android phone / Android TV / Fire TV / macOS / Windows / Linux is a job, not a side project. Manual testing on the platforms you own is cheaper than maintaining that infrastructure.
- **Tests of the native player code itself.** You can't usefully test libmpv vs ExoPlayer vs MPVKit behavior without the real platform. Test the *inputs* you hand them — that's where the bugs are.

## CI feasibility summary

| Tier | Runs in current `ci.yml`? | Workflow changes needed? |
|---|---|---|
| 1 — Pure Dart | Yes — existing `test` job | None |
| 2 — Fake-server | Yes — existing `test` job | None |
| 3 — Widget tests | Yes — existing `test` job | None |
| 4 — Real Jellyfin Docker | Yes (Linux runner supports Docker) | New job, ~30 lines of YAML |

So the entire plan runs on free GitHub-hosted Linux runners. Nothing requires self-hosted, paid runners, simulators, or device farms.

## Suggested first PR

Don't try to land all four tiers at once. The first PR should be **Tier 1 only**:

1. Create `test/` directory.
2. Add `package:test` and `package:mocktail` to `dev_dependencies`.
3. Write 20–30 tests covering URL construction, auth header builder, JSON parsing, and one Drift migration.
4. Verify the existing `test` CI job picks them up (it should, no changes needed).

That alone retroactively covers a meaningful fraction of the last quarter's bugs and gives you a foundation. Add Tier 2 / 3 / 4 incrementally as the urge strikes.
