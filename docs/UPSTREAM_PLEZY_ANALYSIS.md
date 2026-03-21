# Upstream Plezy Commit Analysis

**Last checked:** 2026-03-17
**Last Plezy commit processed:** `4147bd0` (main)
**Fork baseline:** dkmcgowan/plezy-jellyfin:main (~408 commits since fork)

Finzy is a fork of Plezy (adapted for Jellyfin). This doc lists Plezy commits since the plezy-jellyfin fork that may contain UI or media-player improvements relevant to Finzy. Plex-specific changes are filtered out.

## How to re-check

```powershell
.\scripts\check_plezy_upstream.ps1 -WriteDoc
```

## Potentially relevant commits (newest first)

| Date | SHA | Message | Link |
|------|-----|---------|------|
| 2026-03-16 | 4147bd0 | feat: overlay timestamp inside timeline thumbnail preview | [view](https://github.com/edde746/plezy/commit/4147bd0d863fb5200fba447ea6b1bfd1c4e5bd86) |
| 2026-03-16 | 3ea3455 | fix: prevent SurfaceControl use-after-free | [view](https://github.com/edde746/plezy/commit/3ea3455772ca5ddca2d0020efbdc1922aa148574) |
| 2026-03-16 | a82c3d2 | feat: add grouping and type filtering for shared libraries | [view](https://github.com/edde746/plezy/commit/a82c3d2d2df5e641f6611ff5ea82e5ac391c9b94) |
| 2026-03-16 | 04ef1b8 | fix: guard against missing library in libraries screen | [view](https://github.com/edde746/plezy/commit/04ef1b8ad2c6bbb6f7a5e72e17090598c082a18b) |
| 2026-03-15 | 3c2f72d | refactor: remove dead methods from services | [view](https://github.com/edde746/plezy/commit/3c2f72d15f9ae8735c5a62ec801b02c2c1c31bd4) |
| 2026-03-15 | 23906dd | refactor: remove dead code from provider files | [view](https://github.com/edde746/plezy/commit/23906dd65dd885a2c7a2f0d7d632efdafae8413b) |
| 2026-03-15 | 630755c | refactor: remove dead utility methods | [view](https://github.com/edde746/plezy/commit/630755cf7bf8b3fbd4365b5797ad9cb709949d92) |
| 2026-03-15 | e9f1979 | refactor: remove dead getters from model classes | [view](https://github.com/edde746/plezy/commit/e9f1979e6c89decad6e14e13457c21705cce6f4a) |
| 2026-03-15 | db6161d | refactor: replace numeric tab indexes with NavigationTabId | [view](https://github.com/edde746/plezy/commit/db6161d84ee67f01723cc414fa0ceed8932e87d9) |
| 2026-03-15 | af0de5c | fix: switch from OkHttp to Cronet | [view](https://github.com/edde746/plezy/commit/af0de5c0a958f8d014fb341f3e9c599ab1a868a8) |
| 2026-03-15 | e0d9b4e | refactor: unify focus restoration for main screen tabs | [view](https://github.com/edde746/plezy/commit/e0d9b4ee93446c167fb625df564693d461fb1f6a) |
| 2026-03-15 | 551be5b | feat: dynamic library tabs and shared library navigation | [view](https://github.com/edde746/plezy/commit/551be5bbef35204a770531eeac8292d6965b40a3) |
| 2026-03-15 | bbc7f0f | fix: focus search input on search tab | [view](https://github.com/edde746/plezy/commit/bbc7f0f6656fc5b420b0993389329c58085fe732) |
| 2026-03-15 | 8433d59 | feat: add Cmd/Ctrl+F shortcut to open search | [view](https://github.com/edde746/plezy/commit/8433d594328d703e06c217cf39069eed8359fb9a) |
| 2026-03-15 | 59b3e6c | fix: eliminate duplicate API requests on startup | [view](https://github.com/edde746/plezy/commit/59b3e6ce81c63a8ff9f4e9d30229612bc192d5af) |
| 2026-03-15 | a5629c5 | feat: mask unfocused digits in TV PIN input | [view](https://github.com/edde746/plezy/commit/a5629c54f6d8ac428e7ec73a336a676ca527f1c8) |
| 2026-03-15 | 45726a5 | feat: log git commit hash | [view](https://github.com/edde746/plezy/commit/45726a57cefe9991606a00f88587bf883794ad82) |
| 2026-03-15 | 5f597ef | fix: prefer exact language code match in track selection | [view](https://github.com/edde746/plezy/commit/5f597ef56704042fdd0649c345a6ae09c57e1b9a) |
| 2026-03-15 | bf464b2 | fix: log full exception chain on ExoPlayer errors | [view](https://github.com/edde746/plezy/commit/bf464b257d2ad89b78bace428a8ada6466d76911) |
| 2026-03-15 | 0100b2a | fix: preserve start position and subtitles in ExoPlayer?MPV fallback | [view](https://github.com/edde746/plezy/commit/0100b2a2ea14852cb8dabfaec58638659ffa734e) |
| 2026-03-15 | 5f18efc | feat: live TV channel favorites | [view](https://github.com/edde746/plezy/commit/5f18efcfb3daf3c0a3b92e754a47f74b6ce6a3cf) |
| 2026-03-15 | 7988816 | fix: add timeout diagnostics | [view](https://github.com/edde746/plezy/commit/79888168aee901a19a4c9d32ca625421b4b4a948) |
| 2026-03-15 | 2427a55 | fix: dispatch EventChannel calls to main thread | [view](https://github.com/edde746/plezy/commit/2427a55901b6666907b45cf61c4993106ff3c9da) |
| 2026-03-15 | ac397f3 | feat: redesign TV player controls | [view](https://github.com/edde746/plezy/commit/ac397f32a3a08cd6739c4e5a6826bc12721a8fc3) |
| 2026-03-15 | d236e7f | fix: tighten and align media detail screen spacing | [view](https://github.com/edde746/plezy/commit/d236e7fec680db0592ef1f3cb85dcd8ebdf3acdb) |
| 2026-03-15 | 6d7cdc4 | fix: preserve chapters/markers in cache during watch state sync | [view](https://github.com/edde746/plezy/commit/6d7cdc4ef4fc349020046ebbbc13ac4069ab1589) |
| 2026-03-14 | 9a296b3 | fix: guard scrollListToIndex against multiple scroll positions | [view](https://github.com/edde746/plezy/commit/9a296b3da8dec05da4d30ba45675dba433549ec1) |
| 2026-03-14 | c9668af | feat: sort home screen hubs by user's library order | [view](https://github.com/edde746/plezy/commit/c9668af2aeb3d797b165b967e2ea9e62efa9fa95) |
| 2026-03-14 | cfb8bf0 | fix: reduce remote playback startup latency | [view](https://github.com/edde746/plezy/commit/cfb8bf04d6fb0afd3ebfa2656d49b866d5a1147d) |
| 2026-03-14 | dd11e8d | fix: scroll list tiles into view on dpad focus | [view](https://github.com/edde746/plezy/commit/dd11e8d3b292ae950a4dd39d7b02e97cc2c62588) |
| 2026-03-14 | cde6e99 | fix: dpad nav skipping episodes on single-season shows | [view](https://github.com/edde746/plezy/commit/cde6e99a175b147b061030fdc15281ac88866a33) |
| 2026-03-14 | e13b16f | fix(android): mpv boolean NPE on dispose | [view](https://github.com/edde746/plezy/commit/e13b16f13c7b30925ece252dc4ddac98cfbfcdfc) |
| 2026-03-13 | e968a20 | fix(livetv): soften EPG grid program styling | [view](https://github.com/edde746/plezy/commit/e968a20f4ca513ab2d8a2e7efb8f591c1a65c065) |
| 2026-03-13 | 7a6b866 | fix(livetv): fetch boundary-spanning programs | [view](https://github.com/edde746/plezy/commit/7a6b866c28f9a05b1cf9d27af26018e64b56794e) |
| 2026-03-13 | 6ccbaed | fix(livetv): always bold EPG program titles in guide grid | [view](https://github.com/edde746/plezy/commit/6ccbaed3fd1eb9c02d7a4e189a559b92b0095d27) |
| 2026-03-13 | d01628a | fix(android): use OkHttp connection pooling to prevent high-bitrate stutter | [view](https://github.com/edde746/plezy/commit/d01628a2628d78a9bb5330ca01252b85926bef82) |
| 2026-03-13 | 675ac84 | fix: use settings-style bottom sheet for browse grouping picker | [view](https://github.com/edde746/plezy/commit/675ac84486174452f14bd66d848e49477aee804e) |
| 2026-03-12 | e84dc93 | fix: prevent tab revert and overflow bleed on mobile tab switch | [view](https://github.com/edde746/plezy/commit/e84dc93910b658a4888293c4a30a68bd84630926) |
| 2026-03-12 | 3d30ea1 | fix(macos): reduce idle CPU when video player is paused | [view](https://github.com/edde746/plezy/commit/3d30ea13428da1e3eee77f9ed8403198478ebfde) |
| 2026-03-12 | 8a28a2c | fix: only autofocus bottom sheets in keyboard/dpad mode | [view](https://github.com/edde746/plezy/commit/8a28a2c398de43c721878f5b6d72585bbd538402) |
| 2026-03-12 | c6fa6af | fix: android thread safety | [view](https://github.com/edde746/plezy/commit/c6fa6afa9bb47d2922e58d210c18dbf7e3d7760b) |
| 2026-03-12 | 912ebc2 | fix: cooldown resume health probes, debounce connectivity, coalesce concurrent checks | [view](https://github.com/edde746/plezy/commit/912ebc2f90e7e54e127c3829e0eaa1a87a4dc61f) |
| 2026-03-12 | f04b49e | fix: guard mpv event handler during disposal | [view](https://github.com/edde746/plezy/commit/f04b49e260d8b496b8ef7056f4a155e415799f68) |
| 2026-03-12 | a17458f | fix: handle DBusServiceUnknownException on Linux without NetworkManager | [view](https://github.com/edde746/plezy/commit/a17458ff9b94496e4edbbb58f13bd395f559eb0b) |
| 2026-03-11 | c062dd9 | feat: inline season tabs and d-pad focus improvements | [view](https://github.com/edde746/plezy/commit/c062dd944e2516977bea9c5ecd07eca31059289c) |
| 2026-03-11 | 1a4516b | Merge branch 'feature/respect-season-mode' | [view](https://github.com/edde746/plezy/commit/1a4516bdd1696433d37f091d14b9a42561876365) |
| 2026-03-11 | 5538e06 | refactor: remove SeasonDetailScreen, unify into MediaDetailScreen | [view](https://github.com/edde746/plezy/commit/5538e0627bcec7dbc7483523328cffb79b47a411) |
| 2026-03-11 | 7febfa9 | fix: deduplicate episode fetching and use lazy list for flattened seasons | [view](https://github.com/edde746/plezy/commit/7febfa97714e5ef3d5b024a211f754440cfa23f3) |
| 2026-03-11 | 160be52 | Fix parsing setting value | [view](https://github.com/edde746/plezy/commit/160be52f0257344efaf821cb55976a9fcc314846) |
| 2026-03-11 | 828d57a | fix: auto-reconnect stream after network loss during playback | [view](https://github.com/edde746/plezy/commit/828d57af2468987a415e93a529c2e1af0847d00e) |
| 2026-03-11 | 7014df7 | Merge pull request #680 from micahmo/fix/always-on-top | [view](https://github.com/edde746/plezy/commit/7014df7a0e67cc9c1e24030582d3f7b48115be12) |
| 2026-03-11 | cb0ed15 | Fix issue with always on top getting stuck | [view](https://github.com/edde746/plezy/commit/cb0ed15c0c023d370bbe17ce19e1d16891a96563) |
| 2026-03-11 | 1f7fb22 | fix: handle null ratingKey in folder browsing | [view](https://github.com/edde746/plezy/commit/1f7fb2201c3ae6e3722c3b91a5229fcdcd6db4f0) |
| 2026-03-11 | d4e9364 | fix: handle TogglePlayPauseEvent for macOS media key | [view](https://github.com/edde746/plezy/commit/d4e9364d295702a9225e27ff8a21c9f2fb9dc1de) |
| 2026-03-11 | 4681d60 | fix: hide admin actions from non-admin users | [view](https://github.com/edde746/plezy/commit/4681d60850f59e3454d20c0603a9bdbe02c2c7cb) |
| 2026-03-11 | 78052dc | fix: player stuck on skip credits with no next episode | [view](https://github.com/edde746/plezy/commit/78052dc07ff13f0de14084eb219ce639a1be3c2b) |
| 2026-03-11 | 67c66ff | fix: prevent layout shift for image placeholders | [view](https://github.com/edde746/plezy/commit/67c66ff0c1603091f78edf791f64821117622577) |
| 2026-03-11 | d1bb996 | feat: configurable intro/credits marker regex patterns | [view](https://github.com/edde746/plezy/commit/d1bb99635aeace6a13ac40a8875a813018adcd15) |
| 2026-03-11 | 25c7f32 | feat: use git commit SHA for sentry release version | [view](https://github.com/edde746/plezy/commit/25c7f325b667f88a6e328c1f9930b6175073c539) |
| 2026-03-11 | 5dbaf96 | fix: ASS subtitles broken when DV mode enabled | [view](https://github.com/edde746/plezy/commit/5dbaf961b776395b860258676cbf7aacc1aec642) |
| 2026-03-11 | b4471fa | fix: add D3D11 fallback for gpu-api on Windows | [view](https://github.com/edde746/plezy/commit/b4471fab496ffcdf75558cd596f45ebd21277cb9) |
| 2026-03-11 | 307fd35 | fix: make overlay sheets dismissible when no descendant is focused | [view](https://github.com/edde746/plezy/commit/307fd354d6a0f8e220523cb0020821056434e5dc) |
| 2026-03-11 | a3b5557 | fix: use stream-lavf-o instead of stream-lavf-o-append for reconnect | [view](https://github.com/edde746/plezy/commit/a3b5557185c85071e6e89fd5f531c52a9996a027) |
| 2026-03-11 | 3c491be | fix: handle mpv end-file errors with global snackbar | [view](https://github.com/edde746/plezy/commit/3c491be690062842a5bb5640118645cff6432fb8) |
| 2026-03-11 | 580c1d8 | fix: stuck network check on Linux without NetworkManager | [view](https://github.com/edde746/plezy/commit/580c1d82e5ffd5af1cffe7844a75923e7f5709c6) |
| 2026-03-11 | 4954c9c | fix: replace tunneling reopen with simple parameter toggle | [view](https://github.com/edde746/plezy/commit/4954c9c5690421fe68314481565ccc4de2011346) |
| 2026-03-11 | 8f1b40d | fix: handle string childCount in collections | [view](https://github.com/edde746/plezy/commit/8f1b40d14371af5e2c408af02b6c1eae6fdd62e6) |
| 2026-03-11 | 666b59c | refactor(native-player): share player helpers | [view](https://github.com/edde746/plezy/commit/666b59c293e463a5a66cee5ad69e7f1769a3340d) |
| 2026-03-10 | 7543a8c | refactor: clean up windows code | [view](https://github.com/edde746/plezy/commit/7543a8c55b8849d5b2b98add79d29ad00eb5bf8c) |
| 2026-03-10 | bfc7be2 | fix: default to Vulkan on Windows | [view](https://github.com/edde746/plezy/commit/bfc7be2b801dc85c9f834b552ba998e31aef020b) |
| 2026-03-10 | 8b2c68f | chore: switch Windows libmpv builds to SourceForge | [view](https://github.com/edde746/plezy/commit/8b2c68f3aea64bcdc6651129688fc0e9df6f179c) |
| 2026-03-10 | 9aa019f | fix: ANR in detachSurface | [view](https://github.com/edde746/plezy/commit/9aa019fe6fcc38733fc5cb90b726f4059515a283) |
| 2026-03-10 | 23a100a | feat: auto-reconnect VOD playback after network loss | [view](https://github.com/edde746/plezy/commit/23a100afdce7cb57cd2cb9ff9b4cc4af337263fb) |
| 2026-03-10 | af2ac2c | fix: suppress ASS GL thread crash, update ass-media to 0.4.0 | [view](https://github.com/edde746/plezy/commit/af2ac2c9938ebb8e44ddd882d1c1ecca045e17c5) |
| 2026-03-10 | 166e73c | fix: sync button focus nodes with actual action count | [view](https://github.com/edde746/plezy/commit/166e73cdaaf2bc856d14132d7d42e04a39491d34) |
| 2026-03-10 | 73fe9e0 | fix: guard unsafe .first/.last calls to prevent StateError | [view](https://github.com/edde746/plezy/commit/73fe9e054f7089267ccf104dbcf022b8fbef5603) |
| 2026-03-10 | 42e0662 | fix: clickable title event bubbling and movie support | [view](https://github.com/edde746/plezy/commit/42e066288fe8d953a0f8c20942c9f17a1a53d96b) |
| 2026-03-10 | 682a04f | feat: show per-server connection status on splash screen | [view](https://github.com/edde746/plezy/commit/682a04f047ff3a1f3d9a03e34c424f28df1b1dd9) |
| 2026-03-10 | 29cb88e | fix: translate remaining strings | [view](https://github.com/edde746/plezy/commit/29cb88e6e28a9a355a3198e99a54cefee228891b) |
| 2026-03-10 | 6daf77c | feat: convert settings dialogs to platform-adaptive menus | [view](https://github.com/edde746/plezy/commit/6daf77c890daa2b2bb0b5a5beeffe42038996346) |
| 2026-03-09 | 0372840 | fix: localize EPG day names and reduce channel column width | [view](https://github.com/edde746/plezy/commit/0372840ee1ca2d7dc07fa1c40b2c38304f01c51f) |
| 2026-03-09 | 3c51760 | feat: mouse-only clickable text on media cards | [view](https://github.com/edde746/plezy/commit/3c517602030f16ec8d4a98b9f011ad922a007ed5) |
| 2026-03-09 | 7784cb7 | fix: TMDB icon gradient | [view](https://github.com/edde746/plezy/commit/7784cb75115bf954ef1430293ba9c821db791ac5) |
| 2026-03-09 | 82b0de9 | feat: display movie edition titles across all views | [view](https://github.com/edde746/plezy/commit/82b0de922396dcaf4cc44c77bbf8176355960d07) |
| 2026-03-09 | 92dfe5b | fix: lazy Sparkle init to prevent macOS startup hang | [view](https://github.com/edde746/plezy/commit/92dfe5b41fed6f043f6cfdf74e3febb08185c8b6) |
| 2026-03-09 | 16e96cd | fix: handle null fields in folder metadata deserialization | [view](https://github.com/edde746/plezy/commit/16e96cdde01306ae9ddff25302da41816a54cfcb) |
| 2026-03-09 | 61e4bda | fix: content strip text colors in light mode | [view](https://github.com/edde746/plezy/commit/61e4bda6166424e0ee28303b8e67facea35fbb0e) |
| 2026-03-09 | e69fab8 | fix: handle DVR tune error responses and show to user | [view](https://github.com/edde746/plezy/commit/e69fab87d01da9df2791206f8b3142d42be752ff) |
| 2026-03-09 | a3e7387 | fix: handle Metadata as list in DVR tune response | [view](https://github.com/edde746/plezy/commit/a3e738773bd7440c7e02f0929144c3fd1004bc1b) |
| 2026-03-09 | 0fc64cd | fix: catch seek PlatformException at source, remove coordinator | [view](https://github.com/edde746/plezy/commit/0fc64cdf814d7700811c1d2002d816a13908a16a) |
| 2026-03-09 | d08c4c9 | fix: gamepad select registering as long press | [view](https://github.com/edde746/plezy/commit/d08c4c905fd1aa4f38181018c070f7c9c6b8d2c8) |
| 2026-03-09 | 43b9bd7 | fix: bump universal_gamepad to 1.5.4 | [view](https://github.com/edde746/plezy/commit/43b9bd7038abd7fae315c9a1d308042ec564d1cd) |
| 2026-03-09 | 2dddd00 | fix: d-pad navigation on Android | [view](https://github.com/edde746/plezy/commit/2dddd00fd3034fcbff388f987bd1d4a66307cd58) |
| 2026-03-09 | 5be7b43 | fix: improve content strip text visibility | [view](https://github.com/edde746/plezy/commit/5be7b43cb852acc49672e46ec7fd4cf38cf8f1aa) |
| 2026-03-08 | 965d954 | fix: double sparkle update check | [view](https://github.com/edde746/plezy/commit/965d9540fa22718e462b40f66a6edf6bf9b5a1ec) |
| 2026-03-08 | 65bb7bd | fix: catch wakelock exceptions on Linux | [view](https://github.com/edde746/plezy/commit/65bb7bd44e41ec13d88ece3c2b8ba57e2d7c8510) |
| 2026-03-08 | a5ade78 | fix: remove unused variable warning | [view](https://github.com/edde746/plezy/commit/a5ade78cd6b3820b13bfe13c1d1e7160878a13c7) |
| 2026-03-08 | 57420e5 | fix: lazy client fetch in context menu | [view](https://github.com/edde746/plezy/commit/57420e51cfe24b7f5150b44cf69beed3131abb19) |
| 2026-03-08 | bec8b59 | fix: bump auto_updater | [view](https://github.com/edde746/plezy/commit/bec8b593bee1bd3d794caef27f42827ac66e50c8) |
| 2026-03-08 | c62e406 | refactor: gate sentry behind build flag | [view](https://github.com/edde746/plezy/commit/c62e406749bce0a804c76ed905a0b9ddf1ead937) |
| 2026-03-08 | 9e2e1f7 | refactor: remove debug token i18n strings | [view](https://github.com/edde746/plezy/commit/9e2e1f72ce7c70b851f3620740c1e690ef75a97e) |
| 2026-03-08 | f85afbe | fix: gamepad ANR on Android | [view](https://github.com/edde746/plezy/commit/f85afbe576b77a81a8092b3e669744f8126ac234) |
| 2026-03-08 | 6fa6b34 | fix: player stuck after show ends with no next episode | [view](https://github.com/edde746/plezy/commit/6fa6b34b595d0005d945614277ba0ab791b9b81b) |
| 2026-03-07 | 7a1f677 | fix: content strip lint warnings | [view](https://github.com/edde746/plezy/commit/7a1f677c756c7ce68c211d2d8836dfa4ff4f8d3c) |
| 2026-03-07 | de28691 | fix: track selection persistence with stale cache | [view](https://github.com/edde746/plezy/commit/de286914818ea993b5f8e6faa43cbbd06c378a28) |
| 2026-03-07 | 686a61a | fix: hero section bottom fade only applies to image | [view](https://github.com/edde746/plezy/commit/686a61ac740e52a5c27db32cf312dd879a53e653) |
| 2026-03-07 | 0b1f64e | refactor: simplify mobile player controls | [view](https://github.com/edde746/plezy/commit/0b1f64ef8adc273b0576aa6fad182029f7613596) |
| 2026-03-07 | 5b910fd | fix: mpv config TextField dpad/back key navigation | [view](https://github.com/edde746/plezy/commit/5b910fd3d71ef3b0c6b7ba8e5c438dbaa4aecd55) |
| 2026-03-07 | c56e73e | feat: add content strip for dpad navigation | [view](https://github.com/edde746/plezy/commit/c56e73eefe294114bad1cb7a5ef63f16dca7525e) |
| 2026-03-07 | 7cfa18e | fix: remove redundant thumbnail popup during dpad timeline seeking | [view](https://github.com/edde746/plezy/commit/7cfa18e1e96de7e4b282e81f6eefe53f628c7a08) |
| 2026-03-07 | 06034bb | feat: scale queue items for tablet screens | [view](https://github.com/edde746/plezy/commit/06034bb8e77addd802e09353969b266efa08c695) |
| 2026-03-07 | 7b20543 | fix: support non-1x playback speed in audio position bypass | [view](https://github.com/edde746/plezy/commit/7b20543fa18e5c9131efd397bb9c8cdd73bd2009) |
| 2026-03-07 | d207185 | fix: bypass DefaultAudioSink position clamp for large audio frames | [view](https://github.com/edde746/plezy/commit/d20718513040c781bf485f8a0d6fb4d6ad3f31c5) |
| 2026-03-06 | 66628e1 | feat: add pt, ja, ru, pl, da, nb translations | [view](https://github.com/edde746/plezy/commit/66628e1bca3e2d017830938391b964f1f7885374) |
| 2026-03-06 | beff4f9 | feat: add watch together playback rejoin flow | [view](https://github.com/edde746/plezy/commit/beff4f9ca01ab61dde484cac7eed63f82d720cb5) |
| 2026-03-06 | 1318c54 | feat: improve performance overlay layout and add decoder details | [view](https://github.com/edde746/plezy/commit/1318c54c0c6d34820f58895579eaf9b16233c4c9) |
| 2026-03-06 | b05d69b | fix: filter hub detail view by library section | [view](https://github.com/edde746/plezy/commit/b05d69b10fbf0b0db14a811152476393e83d647b) |
| 2026-03-06 | 7825490 | fix: filter Windows file-lock cache manager errors from Sentry | [view](https://github.com/edde746/plezy/commit/7825490b0fe45c0f0690ffb3a07ea20b63b57f88) |
| 2026-03-06 | c06b0ef | fix: correct linux package license metadata | [view](https://github.com/edde746/plezy/commit/c06b0efedca1e42a322ee29e615e7c468fc0b34a) |
| 2026-03-06 | 43f4736 | fix: reopen ExoPlayer when tunneling mode changes | [view](https://github.com/edde746/plezy/commit/43f473693621a312aa159623d1882d06304d8670) |
| 2026-03-06 | cf8f184 | fix: harden watch together teardown sync | [view](https://github.com/edde746/plezy/commit/cf8f1849aa98436ca98d67a19c034ff357a08839) |
| 2026-03-06 | c9a1bc9 | fix: remove dead state paths and restore track hotkeys | [view](https://github.com/edde746/plezy/commit/c9a1bc97c4adda190a6aa2b8c82026a0a1772fd0) |
| 2026-03-06 | 581f665 | fix: restore iOS inline player after PiP closes | [view](https://github.com/edde746/plezy/commit/581f665f58b51a1fc92c11840c10eb1087cb9eaf) |
| 2026-03-06 | 7b3a8ad | fix: guard missing client in season detail screen | [view](https://github.com/edde746/plezy/commit/7b3a8ad642c3de4a4c8a036531443f02291a14a2) |
| 2026-03-06 | c1e2bc3 | refactor: share Apple MPV core and media helpers | [view](https://github.com/edde746/plezy/commit/c1e2bc36ea02a2204ad384950a274a1baefe2cb9) |
| 2026-03-06 | 72aed76 | fix: remove unused _applyFilterWithFallback | [view](https://github.com/edde746/plezy/commit/72aed76a1c73ed756037a95b1ec46b0088de2810) |
| 2026-03-06 | 7ae2936 | fix: trust server-computed subtitle selection flags | [view](https://github.com/edde746/plezy/commit/7ae293631a76e7ac919f87d828720a7ee9869674) |
| 2026-03-06 | f7ca80d | Merge pull request #637 from micahmo/fix/setting-episode-artwork | [view](https://github.com/edde746/plezy/commit/f7ca80de770accbd62be5b2f3f7c4724f0601e75) |
| 2026-03-06 | a9c7130 | Fix an issue setting episode artwork | [view](https://github.com/edde746/plezy/commit/a9c7130d5563aa6643ff34913349f3ea44f56634) |
| 2026-03-05 | 985ba5d | fix: toggle PiP button closes PiP when already active | [view](https://github.com/edde746/plezy/commit/985ba5d2c7c554a499d7303cc184886e7ef803cd) |
| 2026-03-05 | 232f018 | fix: report JSON deserialization errors | [view](https://github.com/edde746/plezy/commit/232f018ae705bff77bf84c3c03e614f7e2cdedec) |
| 2026-03-05 | 8571ee7 | fix: use addedAt for unwatched on-deck sort fallback | [view](https://github.com/edde746/plezy/commit/8571ee74c49108a83344ea4451bbda1bf7c3bde3) |
| 2026-03-05 | 863f90f | fix: respect series-level subtitle mode for episodes | [view](https://github.com/edde746/plezy/commit/863f90f65d081a34975ecd44df82a0b9af38f8ef) |
| 2026-03-05 | 22a7332 | fix: respect view mode in detail screens, disable scale in list mode | [view](https://github.com/edde746/plezy/commit/22a733280a3b2a8857d52ebe61e26bf6bd9f908a) |
| 2026-03-05 | a4008d3 | fix: move mpv operations off UI thread | [view](https://github.com/edde746/plezy/commit/a4008d3d6bed29bae9791997666d73993cc4266d) |
| 2026-03-05 | 819d7b0 | fix: scope library display settings per user profile | [view](https://github.com/edde746/plezy/commit/819d7b0f8f58afaf8b1cac59797bd116ee27787f) |
| 2026-03-05 | c785ce1 | fix: queue sheet image loading priority with itemExtent | [view](https://github.com/edde746/plezy/commit/c785ce1f8891d27eeb49d62c4a78ef97f101f2ef) |
| 2026-03-05 | 0c35882 | fix: pause hero auto-scroll on desktop background transition | [view](https://github.com/edde746/plezy/commit/0c3588210a733b34a6d948247eda48a746d8a23f) |
| 2026-03-05 | db57fa7 | feat: add option to hide bottom navigation bar labels | [view](https://github.com/edde746/plezy/commit/db57fa73ce36df4e76fdcf9ba4275616d3f59d10) |
| 2026-03-05 | 0269825 | fix: windows single instance mutex | [view](https://github.com/edde746/plezy/commit/02698251796ef93f39e1fde90dcee4e865a8dfb2) |
| 2026-03-05 | 588b413 | fix: browse tab scrolling after alpha jump libraries | [view](https://github.com/edde746/plezy/commit/588b4132235e1e82bd79ec16dbb1146a40af47da) |
| 2026-03-05 | a2cd339 | fix: desktop context menu position and bottom sheet sizing | [view](https://github.com/edde746/plezy/commit/a2cd3397c9862fa829ed0a4fd7de78c7f3dc523c) |
| 2026-03-05 | 268f293 | refactor: deduplicate Dolby Vision conversion code | [view](https://github.com/edde746/plezy/commit/268f293704d2c14b791c1eb75c3fdd348f52924a) |
| 2026-03-05 | 317d5db | feat: DV Profile 7?8.1 RPU conversion via libdovi | [view](https://github.com/edde746/plezy/commit/317d5dbdd907d7c0f0f4db5c394624dcdcc52874) |
| 2026-03-04 | 7f2d548 | fix: item 0 steals focus after sidenav return | [view](https://github.com/edde746/plezy/commit/7f2d548d3276ec8560012bde83149884cde24c86) |
| 2026-03-04 | 5877673 | fix: reduce UI padding between media items | [view](https://github.com/edde746/plezy/commit/58776737551fc730412f6979ff972eb15401aa3f) |
| 2026-03-04 | 3b351d7 | fix: iOS OOM during PiP playback cycles | [view](https://github.com/edde746/plezy/commit/3b351d76341e11ac53ca51aeb628bb5e29b6cb9b) |
| 2026-03-04 | e6ee83d | fix: preserve home screen scroll position on back navigation | [view](https://github.com/edde746/plezy/commit/e6ee83d9c25a3182d3d417d158ca69b642cec0c6) |
| 2026-03-04 | 8b57e81 | feat: detail screen context menu button | [view](https://github.com/edde746/plezy/commit/8b57e810abd1eb11e0b27210d9c6bce4206144c2) |
| 2026-03-04 | 4121d56 | fix: sanitize mpv event channel strings for valid UTF-8 | [view](https://github.com/edde746/plezy/commit/4121d568c8313ecf508cd458446d154718e87ff7) |
| 2026-03-04 | 551bd83 | fix: player disposed race condition | [view](https://github.com/edde746/plezy/commit/551bd83ffe187827adef4add638fc34c3b94286d) |
| 2026-03-04 | 5f4e4bf | fix: ExoPlayer fallback for unsupported DV formats | [view](https://github.com/edde746/plezy/commit/5f4e4bfdd3cfa9c94321db625a9dc54cd1bd3da4) |
| 2026-03-04 | 8cd48f3 | fix: firstClient null check race | [view](https://github.com/edde746/plezy/commit/8cd48f3af510841bd185ba52be6529f4c0aedda9) |
| 2026-03-04 | 13b5d7b | feat: secondary subtitle tracks | [view](https://github.com/edde746/plezy/commit/13b5d7bae8a8869f02266a61e546f158a25878df) |
| 2026-03-04 | 3a76754 | feat: custom GLSL shader import | [view](https://github.com/edde746/plezy/commit/3a76754af93c6af318901dc2369a13b8b2127bb1) |
| 2026-03-04 | 73eeac3 | fix: disable async codec queueing | [view](https://github.com/edde746/plezy/commit/73eeac35a856ccd31705bb4ccc1f3d9882d7bb93) |
| 2026-03-04 | 18abcef | fix: offload large UTF-8 decoding to background isolate | [view](https://github.com/edde746/plezy/commit/18abcef8a2699a98ad684b6f231ae7b8fe355e92) |
| 2026-03-04 | 85800ab | fix: disable tunneling for video codecs without tunneling support | [view](https://github.com/edde746/plezy/commit/85800abf9f7abfee9081d4dae15a2c1af20a59a7) |
| 2026-03-04 | 2b72327 | fix: hide metal layer when window is occluded | [view](https://github.com/edde746/plezy/commit/2b72327013418f0093932d348e0ee67d47c0ad29) |
| 2026-03-04 | cc86afb | fix: sparkle update detection and startup hang | [view](https://github.com/edde746/plezy/commit/cc86afb31d986f7db86bb2a56b6765faf8f6b164) |
| 2026-03-03 | efac1a9 | fix: watch together stream use after close | [view](https://github.com/edde746/plezy/commit/efac1a9f28b6279a48da75ee900c7b0397b809fd) |
| 2026-03-03 | a9e4091 | fix: disable http breadcrumbs for sentry | [view](https://github.com/edde746/plezy/commit/a9e4091500d23059e2a4e2abe26730d0f9cd1ec4) |
| 2026-03-03 | 891c4f8 | fix: reduce currently-airing program contrast | [view](https://github.com/edde746/plezy/commit/891c4f8c32315fc3af731bf92f3a411e3e745b36) |
| 2026-03-03 | 96f7bd4 | fix: ExoPlayer logs never reaching Dart log output | [view](https://github.com/edde746/plezy/commit/96f7bd431cac514dca9ba7c469cb1a66071a3b17) |
| 2026-03-03 | cd2ab9d | refactor: deduplicate shared patterns, replace hardcoded colors | [view](https://github.com/edde746/plezy/commit/cd2ab9d9cd2aec35a847e984513d2ca714373846) |
| 2026-03-03 | 8f3d521 | fix: watch together sync bugs and code quality | [view](https://github.com/edde746/plezy/commit/8f3d52142dd88ea78783428b522c7c21b17f5151) |
| 2026-03-03 | cb7de47 | fix: guard ScrollController.position access in HorizontalScrollWithArrows | [view](https://github.com/edde746/plezy/commit/cb7de47aed42067163e68c7f15c754ade1072db4) |
| 2026-03-03 | 174c78b | fix: handle connectivity_plus PlatformException on Windows | [view](https://github.com/edde746/plezy/commit/174c78bf67ae11ba5cf1a33adb29552d1a1373cd) |
| 2026-03-03 | 19c36ca | fix: normalize Sentry release version across platforms | [view](https://github.com/edde746/plezy/commit/19c36ca340c5cc0484e662ae37cbad692cd79b6d) |
| 2026-03-03 | e60b8d1 | fix: improve error reporting data sanitization | [view](https://github.com/edde746/plezy/commit/e60b8d13b942a20c03c89ef5be84cbcd65e8eaff) |
| 2026-03-03 | 1b67374 | fix: handle int end-file reason from mpv on Windows/Linux | [view](https://github.com/edde746/plezy/commit/1b673743b23ca8356bd4a3b0a7516f618b84b69a) |
| 2026-03-03 | 34e8c17 | fix: guard PiP calls on unsupported platforms | [view](https://github.com/edde746/plezy/commit/34e8c179fe631847092e18d5b44c4a72b3887302) |
| 2026-03-03 | 33d5760 | fix: uncommend play store release | [view](https://github.com/edde746/plezy/commit/33d5760930f80f9e8f49242f4cfbee07c9148d9c) |
| 2026-03-03 | c8e6cac | bump mpv windows to 20260303 | [view](https://github.com/edde746/plezy/commit/c8e6cac00ca6e253d13d06bd6b08dbaef0d4eeba) |
| 2026-03-03 | c6ace69 | refactor: clean up download code duplication | [view](https://github.com/edde746/plezy/commit/c6ace690cb3eccb799ed5482b7ae6a4b12d2f05d) |
| 2026-03-03 | 7a979be | fix: harden download callbacks against stale status events | [view](https://github.com/edde746/plezy/commit/7a979bed2fac9d8c613541d6c1c76bbef7cd465b) |
| 2026-03-03 | e46bd71 | fix: prevent completed downloads from restarting on app launch | [view](https://github.com/edde746/plezy/commit/e46bd71fa7db959d7b35262a0a480af715c46b2d) |
| 2026-03-03 | c980102 | fix: warnings | [view](https://github.com/edde746/plezy/commit/c98010234f12ed401ab26d431e76e6efbc8bc88f) |
| 2026-03-03 | 02e175e | feat: replace rustrak with glitchtip | [view](https://github.com/edde746/plezy/commit/02e175e4d3f0d47e7a02cbf1367a0592f433bac5) |
| 2026-03-03 | 013bcfb | fix: library continue watching hidden | [view](https://github.com/edde746/plezy/commit/013bcfbece6f30ef7220b97c2d855daddcb7b12b) |
| 2026-03-03 | ebf2d1e | fix: shorten nav labels | [view](https://github.com/edde746/plezy/commit/ebf2d1e51641e781d6c62424000cf4bb73a61a7f) |
| 2026-03-03 | 4bce668 | fix: asymmetric divider in track sheet on landscape | [view](https://github.com/edde746/plezy/commit/4bce668df62bd59694d3448bae7a6b683d1b4376) |
| 2026-03-03 | c64c7de | fix: disable session tracking | [view](https://github.com/edde746/plezy/commit/c64c7defc3a63e1c50a8f4ee4c15c29a43ed4fc5) |
| 2026-03-03 | 1629801 | feat: add swipe-up content strip for mobile video controls | [view](https://github.com/edde746/plezy/commit/16298010742f11aa57b8ac811366cda7572b72d1) |
| 2026-03-03 | cd36e3a | feat: switch crash reporting from BugSink to Rustrak | [view](https://github.com/edde746/plezy/commit/cd36e3acb0ed74280c17397bc556fe3f33083fe6) |
| 2026-03-03 | 7001032 | feat: combine audio & subtitle track sheets into one | [view](https://github.com/edde746/plezy/commit/7001032e5161d9038b57812688caf96534c92231) |
| 2026-03-02 | 1c31f0e | fix: request audio focus before player init guard | [view](https://github.com/edde746/plezy/commit/1c31f0effafdbabb5e656ce81ca0f3241dd693d0) |
| 2026-03-02 | 01e61c5 | fix: tighten startup connection timeouts for dead servers | [view](https://github.com/edde746/plezy/commit/01e61c590ae80c7f556f9acaa63a69cca8d6adf8) |
| 2026-03-02 | a00e2b7 | feat: replace mpv config UI with raw text editor | [view](https://github.com/edde746/plezy/commit/a00e2b78d6c823af3de944885265afe76900823a) |
| 2026-03-02 | b5904bc | fix: auto-retry large downloads after native retries exhausted | [view](https://github.com/edde746/plezy/commit/b5904bc4779a661da50e142d37752301e911565a) |
| 2026-03-02 | 47f2afb | feat: bottom sheet polish | [view](https://github.com/edde746/plezy/commit/47f2afb6653d1e81ce7263a2b0a82f269f202fea) |
| 2026-03-02 | 3b2e278 | fix: hide redundant items in context menu | [view](https://github.com/edde746/plezy/commit/3b2e27886824094d3982b28ae17ee4c088298854) |
| 2026-03-02 | 8baa84c | fix: use player.state.track for selected subtitle check | [view](https://github.com/edde746/plezy/commit/8baa84c06f379ec1b32a0d05cf6b668f9ad2abf4) |
| 2026-03-02 | 92b5892 | fix(ci): add libcurl4-openssl-dev for Linux builds | [view](https://github.com/edde746/plezy/commit/92b589213f033efda5ca3a5a63d301a8a1f875d8) |
| 2026-03-02 | 94395fe | feat: implement sub-visibility toggle | [view](https://github.com/edde746/plezy/commit/94395feaba94d520e3f0f4993d57249481d49c63) |
| 2026-03-02 | c372920 | fix: resolve out-of-scope settingsService in video player | [view](https://github.com/edde746/plezy/commit/c3729209650e98a8f40353937974fa6239ea8664) |
| 2026-03-02 | 8d3f448 | feat(macos): add picture-in-picture support | [view](https://github.com/edde746/plezy/commit/8d3f448fdf2dd8a56f345aa67ed74ced7c543b43) |
| 2026-03-02 | 5ab6af1 | feat: respect system 24h time format setting | [view](https://github.com/edde746/plezy/commit/5ab6af1b0289d0ee3d45d4103a962ec212751323) |
| 2026-03-02 | 34252b9 | fix: persist aspect ratio and shader settings | [view](https://github.com/edde746/plezy/commit/34252b9ba7e06428eacccf2b74e91cd0ea6a7ce6) |
| 2026-03-02 | 7ebbfb9 | fix(i18n): add missing pip keys | [view](https://github.com/edde746/plezy/commit/7ebbfb9ef7aef7c203d2b238463859eea3b19767) |
| 2026-03-02 | a008f86 | feat(ios): add picture-in-picture support | [view](https://github.com/edde746/plezy/commit/a008f86ee2ba901470179711952452166ef1fe60) |
| 2026-03-02 | 5f1c51f | fix: skip specials in playback order | [view](https://github.com/edde746/plezy/commit/5f1c51ff6c577635ffe66d0dabc85fd525eb8468) |
| 2026-03-02 | 229d6b2 | feat: crash log reporting | [view](https://github.com/edde746/plezy/commit/229d6b24e1c9a7426e770f6ed1d131fb03ea99a7) |
| 2026-03-02 | 9dc0654 | fix(android): prevent dispatchWindowVisibilityChanged NPE during disposal | [view](https://github.com/edde746/plezy/commit/9dc0654225663a7f93a94f823fee6bb05ae04c04) |
| 2026-03-02 | 3627707 | fix(android): cap demuxer buffers + sync mpv dispose | [view](https://github.com/edde746/plezy/commit/36277076bd846e768f0e4bb7655159d4cde1b6d9) |
| 2026-03-02 | f96ef07 | fix(android): move JSON parsing off main thread | [view](https://github.com/edde746/plezy/commit/f96ef0740d986777781b8b288715c771e84a4e1c) |
| 2026-03-02 | 6bee1a6 | fix(android): add opensles audio fallback | [view](https://github.com/edde746/plezy/commit/6bee1a6c386f6188205580a0c7977287596331ce) |
| 2026-03-02 | 0dbba64 | fix: hide hero carousel indicators in dpad mode | [view](https://github.com/edde746/plezy/commit/0dbba6439d135bf6326d870d968b3db4c51a719e) |
| 2026-03-01 | 7ac888c | fix(windows): installer norun arg | [view](https://github.com/edde746/plezy/commit/7ac888cd461365712010e2418ea756f284370063) |
| 2026-03-01 | 938291d | bump mpvkit | [view](https://github.com/edde746/plezy/commit/938291dbf693a2039ea1d2ca586f75e6c3cdfcb2) |
| 2026-03-01 | f571598 | feat: migrate iOS to scene lifecycle | [view](https://github.com/edde746/plezy/commit/f5715987fc42f1d824d2b3e28406fdbe1441fc1f) |
| 2026-03-01 | 7c0e86c | bump mpvkit | [view](https://github.com/edde746/plezy/commit/7c0e86c3cf98005e4d73af30ac27f1f7882e6d66) |
| 2026-03-01 | 9c7cb74 | feat: add winget package manager support | [view](https://github.com/edde746/plezy/commit/9c7cb7439f92f481b7db3bf794a476a06da49320) |
| 2026-03-01 | 3bf7ff3 | feat: improve LiveTV guide visual contrast and polish | [view](https://github.com/edde746/plezy/commit/3bf7ff3d488d8c8f0a25b3a60f2a8f7d5d4bfe3f) |
| 2026-03-01 | 138c8f9 | feat: auto picture-in-picture | [view](https://github.com/edde746/plezy/commit/138c8f9fd8609f462972c64d939e1e61d87f9f68) |