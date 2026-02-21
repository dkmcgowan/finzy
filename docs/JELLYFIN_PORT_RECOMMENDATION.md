# Jellyfin Port: Recommendation & Approach

## Current state (Plezy + Plex)

- **No backend abstraction.** All server access goes through `PlexClient`; UI and providers use `PlexMetadata`, `PlexLibrary`, `PlexServer`, etc. by name.
- **Multi-server is generic.** `serverId` / `serverName` and “client per server” fit any backend; only the *type* of client is Plex-specific.
- **Reusable as-is:** Flutter UI, navigation, MPV player, multi-server and offline patterns, caching idea, and app flow (login → browse → play → progress).

So the main work is introducing a **media-server abstraction** and either implementing it only for Jellyfin (full replacement) or for both Plex and Jellyfin (dual support).

---

## Recommendation: **Dual support (Plex + Jellyfin)** if you want to merge back

Reasons:

1. **Single codebase** – one app, one repo, easier to maintain and to propose upstream.
2. **Original author merge** – adding an abstraction + Jellyfin keeps Plex working and is a clean, reviewable PR.
3. **Abstraction is manageable** – `PlexClient` is the single bottleneck; one interface + two implementations is a well-understood pattern.
4. **Full replacement** is similar effort for the “client + models” layer but gives you a Jellyfin-only fork with no path to merge.

So: **implement a media-server abstraction and a Jellyfin client alongside Plex**, then wire the app to the abstraction. That gives you the option to merge back with “Plex + Jellyfin” support.

---

## High-level architecture for dual support

### 1. Media server abstraction

Introduce an interface (e.g. `MediaServerClient`) that covers what the app needs:

- **Connection:** `testConnection()`, `getServerId()`, offline mode, token/endpoint updates.
- **Discovery/browse:** `getLibraries()`, `getLibraryContent()`, `getMetadata()`, `getChildren()`, `getRecentlyAdded()`, `getOnDeck()`, search, filters/sorts, hubs, folders.
- **Playback:** `getVideoPlaybackData()` (or equivalent), `getChapters()`, `getMarkers()`, stream selection / preferences.
- **Progress & state:** `markAsWatched` / `markAsUnwatched`, `updateProgress()`, `removeFromOnDeck()`, sessions.
- **Playlists & collections:** CRUD playlists, add/remove/move items, collections.
- **Play queues:** create/get/update play queue (if Jellyfin has an equivalent).
- **Extras:** rating, delete, file info, thumbnails, library management (scan, refresh, etc.).
- **Live TV:** if you want parity, DVR/channels/EPG/tune (Jellyfin has Live TV APIs).

`PlexClient` already implements all of this; you’d extract the interface from its public methods and make `PlexClient` implement that interface. Then implement the same interface as `JellyfinClient`.

### 2. Shared vs backend-specific models

Two viable approaches:

- **Option A – Shared DTOs:** Define app-level models (e.g. `MediaItem`, `Library`, `Playlist`, `VideoPlaybackInfo`) and have each client map from Plex/Jellyfin responses into these. UI only knows the shared types. More refactor up front, single set of screens.
- **Option B – Adapter in the client:** Keep existing Plex models for Plex; add Jellyfin models and have `JellyfinClient` return types that implement a small common interface (e.g. `HasId`, `HasTitle`, `HasServerId`) so the UI can work with both via that interface. Less refactor, some `is PlexMetadata` / `is JellyfinItem` or pattern matching where needed.

Recommendation: **Option A** if you want the cleanest path to merge and minimal branching in the UI. **Option B** if you want to ship Jellyfin faster and refactor to shared DTOs later.

### 3. Where to plug in the abstraction

- **`MultiServerManager`** – Today it holds `Map<String, PlexClient>`. Change to `Map<String, MediaServerClient>` (or a sealed type “Plex | Jellyfin” if you need backend-specific APIs in a few places). It still creates “clients” per server; for Jellyfin you’ll create `JellyfinClient` instead of `PlexClient`.
- **`provider_extensions.dart`** – `getClientForServer` etc. should return `MediaServerClient` (or the sealed type). All call sites that only need browse/playback/progress keep working.
- **Auth:** Plex uses plex.tv (PIN, tokens, `clients.plex.tv` for servers). Jellyfin uses **direct server auth**: user enters server URL + username/password (or API key). So:
  - **Auth screen:** “Sign in with Plex” vs “Sign in with Jellyfin”. For Jellyfin: server URL + credentials → call Jellyfin auth API → get token; then “server” list is the single server (or multiple Jellyfin servers if you allow adding more).
  - **Server registry:** Store backend type (Plex vs Jellyfin) per server and use it when creating clients in `MultiServerManager` and when showing the right auth flow.

### 4. Jellyfin-specific notes (API)

- **Auth:** [Jellyfin API](https://api.jellyfin.org/) uses `POST /Users/AuthenticateByName` (or similar) with username/password; response includes an access token. Use `Authorization: MediaBrowser Token="..."` (and optionally Client, DeviceId, etc.).
- **Libraries:** Items and libraries are under endpoints like `/Users/{userId}/Items`, `/Library/...`; structure differs from Plex’s XML/JSON but concepts map (libraries, movies, shows, seasons, episodes).
- **Playback:** You get a direct stream URL (or transcoding URL) per item; report progress with the Playback API (e.g. progress reports, scrobble).
- **Sessions:** Session API for active sessions and remote control.

So: auth and URL shapes differ, but “libraries → items → playback URL + progress” is the same idea. Implementing `MediaServerClient` for Jellyfin is mostly mapping their REST API to the same methods you already have on `PlexClient`.

---

## If you do a Jellyfin-only fork instead

- Replace `PlexClient` with `JellyfinClient` (same surface area as above, but no interface).
- Replace Plex models with Jellyfin (or shared) DTOs.
- Replace `PlexAuthService` with a Jellyfin login flow (server URL + username/password or API key).
- Keep: `MultiServerManager` (with Jellyfin clients), most of the UI, MPV, offline/cache pattern.
- No need to abstract; faster to a single-backend app, but no merge path to the original repo.

---

## Suggested order of work (dual support)

1. **Define `MediaServerClient`** – Extract the interface from `PlexClient` (browse, metadata, playback, progress, playlists, etc.).
2. **Implement `PlexClient` as `MediaServerClient`** – Make `PlexClient` implement the new interface; ensure the app still works with Plex only.
3. **Add Jellyfin auth** – New auth path: server URL + credentials → Jellyfin token; store backend type with server.
4. **Implement `JellyfinClient`** – Same interface, calling Jellyfin REST API; start with connection test, libraries, metadata, playback URL, progress.
5. **MultiServerManager + registry** – Create `PlexClient` or `JellyfinClient` based on stored backend type; wire `getClientForServer` to the abstraction.
6. **Auth screen** – “Plex” vs “Jellyfin” choice and the two flows.
7. **Shared or parallel models** – Prefer shared DTOs (Option A) for a cleaner merge; otherwise adapt UI to both model types (Option B).
8. **Playlists, collections, Live TV** – Add Jellyfin support for these in `JellyfinClient` as needed.

Once Plex and Jellyfin both work behind `MediaServerClient`, you can open a PR to the original Plezy repo with “optional Jellyfin support” and a clear separation of backend-specific code.
