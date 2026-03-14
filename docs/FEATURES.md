# Features

This document lists feature gaps between Finzy and Jellyfin (web + API). It serves as a single source of truth so you can stop hunting through web and API docs. Each item is categorized as Planned, Later, Not Adding, or Implemented.

## Implemented (Already Done)

### Core Library & Browsing

- **Libraries / Views:** `GET /Users/{userId}/Views` — Browse libraries, movies, shows, collections, playlists
- **Library content:** `GET /Users/{userId}/Items` with filters (type, genre, year, tags, officialRating, video quality)
- **Library hubs:** Home page hubs (Next Up, Recently Added, Recommendations per library)
- **Global hubs:** Next Up, Recently Added Movies/Shows across all libraries
- **Collections:** Create, add/remove items, delete collections (`/Collections`, `/Items/{id}`)
- **Playlists:** CRUD playlists, add/remove items (`/Playlists`, `/Playlists/{id}/Items`)
- **Favorites:** Toggle favorites (`/FavoriteItems`, `/PlayedItems`)
- **Library filters & sorts:** Genres, years, tags, official ratings, video quality; sort options per library type
- **Library scan/refresh:** `POST /Library/Refresh`, `POST /Items/{sectionId}/Refresh`

### Authentication

- **Authenticate by name:** `POST /Users/AuthenticateByName`
- **Quick Connect:** Initiate, poll, authenticate (`/QuickConnect/Initiate`, `/QuickConnect/Connect`, `/Users/AuthenticateWithQuickConnect`)

### Media Detail & Metadata

- **Item metadata:** `GET /Users/{userId}/Items/{id}` with images
- **Similar items:** `GET /Items/{itemId}/Similar`
- **Items by person:** `GET /Users/{userId}/Items` filtered by person
- **Extras / trailers:** Local trailers (`/Items/{id}/LocalTrailers`), fallback to RemoteTrailers
- **Movie recommendations:** `GET /Movies/Recommendations` (Because you watched, etc.)
- **Chapters / markers:** `GET /Items/{itemId}` with Chapters, MediaSources; MediaSegments for trickplay markers

### Playback

- **Playback info:** `POST /Items/{itemId}/PlaybackInfo` for transcoding/direct play
- **Live stream open:** `POST /LiveStreams/Open` when required
- **Progress reporting:** `POST /Sessions/Playing/Progress`, `/Sessions/Playing/Stopped`
- **Mark watched/unwatched:** `POST /Users/{userId}/PlayedItems/{id}`, `DELETE`
- **User rating:** `POST /Users/{userId}/Items/{id}/Rating`
- **Delete item:** `DELETE /Items/{itemId}` (when user has permission)
- **Resume / continue watching:** `GET /Users/{userId}/Items/Resume`

### Offline Downloads

- Offline download/cache for movies, shows, and episodes. Uses normal playback streaming; watch without network.

### Live TV & DVR

- **DVR detection:** `GET /LiveTv/Info`
- **Channels:** `GET /LiveTv/Channels`
- **Programs / EPG:** `GET /LiveTv/Programs`, `/LiveTv/Programs/Recommended`
- **Live tune:** `POST /Items/{channelId}/PlaybackInfo`, `POST /LiveStreams/Open`
- **Timers:** Create, list, delete (`/LiveTv/Timers`, `/LiveTv/SeriesTimers`)
- **Recordings:** `GET /LiveTv/Recordings`
- **Live timeline:** Progress reporting for live streams

### Sessions

- **List sessions:** `GET /Sessions` (used for remote control UI)

---

## Planned

### SyncPlay (Server-Native)

- **Effort:** High
- **API:** `POST /SyncPlay/`* (New, Join, Leave, Play, Pause, Seek, SetPlaylistItem, etc.)
- Jellyfin has built-in synchronized playback coordinated by the server. Unlike the removed Watch Together feature (which used a custom relay), SyncPlay requires no external infrastructure — it's all server-side.

### Remote Control / Session Commands

- **Effort:** Medium
- **API:** `POST /Sessions/{sessionId}/Playing`, `POST /Sessions/{sessionId}/Command`
- Send play commands to other active Jellyfin sessions (play, pause, seek, queue items on another device). Enables "cast to" another Jellyfin client scenario.

### Playback Statistics / Activity

- **Effort:** Medium
- **API:** Session activity endpoints, playback reporting
- Show recently played history, viewing habits, or playback stats. Some servers use the Playback Reporting plugin which exposes additional data.

## Later

### Item Metadata Editing

- **Effort:** Medium
- **API:** `PUT /Items/{id}` (ItemUpdateController)
- Edit item metadata (title, description, genres, tags, ratings, year, etc.) directly from the client. Useful for fixing incorrect metadata without switching to the web dashboard.

### Subtitle Search & Download

- **Effort:** Medium
- **API:** `GET /Items/{itemId}/RemoteSearch/Subtitles/{language}`, `POST /Items/{itemId}/RemoteSearch/Subtitles/{subtitleId}`
- Search for subtitles from providers like OpenSubtitles and download them to the server for an item. Currently the app can select existing subtitle tracks during playback, but cannot search for or add new ones.

### Theme Music / Theme Videos

- **Effort:** Low
- **API:** `GET /Items/{id}/ThemeMedia`, `GET /Items/{id}/ThemeSongs`, `GET /Items/{id}/ThemeVideos`
- Play series or movie theme music on detail pages. Jellyfin stores theme songs and theme videos per item.

### Upcoming Episodes

- **Effort:** Low
- **API:** `GET /Shows/Upcoming`
- View upcoming new episodes across all shows. Complements the existing Next Up feature which tracks unwatched episodes.

### Display Preferences Sync

- **Effort:** Low
- **API:** `GET/POST /DisplayPreferences/{displayPreferencesId}`
- Save library sort order, filter, and view mode preferences to the server so they persist across clients.

## Not Adding

### Edit Subtitles

- Upload, delete, or manage subtitle files on the server. Better handled via the web dashboard.

### Edit Images

- Browse remote image providers, upload, or delete poster/backdrop/logo images on items. Better handled via the web dashboard.

### Merge / Split Movie Versions

- Combine alternate versions of a movie or split them apart. Server-side management best done in the web dashboard.

### Instant Mix

- **API:** `GET /Items/{id}/InstantMix`, `GET /Artists/InstantMix`, `GET /MusicGenres/{name}/InstantMix`
- Auto-generate playlists from an album, artist, song, genre, or existing playlist. Primarily a music feature.

### Music Playback

- Full music support: artists, albums, songs, queue management, background audio, gapless playback, lyrics. Dedicated music clients like Finamp already serve this well.

### Music Videos / Books / Photos

- Jellyfin supports these media types but they are niche for a video-focused client.

### User Management / Admin Panel

- Creating/deleting users, setting parental controls, managing server configuration. Best left to the Jellyfin web dashboard.

### Plugin Management

- Installing/uninstalling server plugins from the client. Better handled via the web dashboard.

### Notifications API

- Server-side admin notifications to users. Low value for a client app.

### Device Management

- View or revoke authorized devices/sessions. Admin feature best handled via the web dashboard.

### Library Structure Management

- Add/remove media folders, rename libraries. Admin feature for the web dashboard.

### Server Configuration / Backup

- Full server settings, scheduled task management, branding, backup/restore. Admin features for the web dashboard.

### Change Password

- **Effort:** Low
- **API:** `POST /Users/{userId}/Password`
- Allow users to change their own password or set a PIN from within the app.

---

## Additional Gaps (Decide: Add or Not Adding)

These Jellyfin API features exist but are not yet in FEATURES.md. Decide whether to add to Planned/Later or explicitly reject.

### Session Capabilities Reporting

- **API:** `POST /Sessions/Capabilities`, `POST /Sessions/Capabilities/Full`
- Report client capabilities (supported commands, transcoding profiles, etc.) so the server and other clients know what this app can do. Jellyfin web posts these on connect.
- **Suggested:** Low effort; consider adding for better server/client interoperability.

### Special Features & Intros

- **API:** `GET /Items/{itemId}/SpecialFeatures`, `GET /Items/{itemId}/Intros`
- Special features (behind-the-scenes, deleted scenes, etc.) and skippable intros for series.
- **Suggested:** Low effort; intros are useful for series binge-watching. Add to Later or Planned.

### Critic Reviews

- **API:** `GET /Items/{itemId}/CriticReviews`
- Rotten Tomatoes / external critic reviews displayed on item detail in jellyfin-web.
- **Suggested:** Low effort; nice-to-have for detail pages. Add to Later or Not Adding.

### Forgot Password

- **API:** `POST /Users/ForgotPassword`, `POST /Users/ForgotPassword/Pin`
- Initiate password reset or PIN recovery by email (server must have email configured).
- **Suggested:** Low effort; consider if change-password is in scope. Add to Later or Not Adding.

### Playlist Item Reorder

- **API:** `POST /Playlists/{playlistId}/Items/{itemId}/Move/{newIndex}`
- Reorder items within a playlist. Jellyfin web supports drag-and-drop reorder.
- **Suggested:** Low effort; add to Later if playlist UX is important.

### Items/Suggestions

- **API:** `GET /Items/Suggestions`
- Server-generated suggestions (different from per-library Recommendations).
- **Suggested:** Evaluate if needed; may overlap with existing hub/recommendation logic.

### Remote Images (Download)

- **API:** `GET /Items/{itemId}/RemoteImages`, `GET /Items/{itemId}/RemoteImages/Providers`, `POST /Items/{itemId}/RemoteImages/Download`
- Browse and download poster/backdrop from remote providers (TMDB, etc.). You already marked "Edit Images" as Not Adding; this is the API behind it.
- **Suggested:** Keep as Not Adding (per your Edit Images decision).

### Channels (Plugin Content)

- **API:** `GET /Channels/{channelId}/Items`, `GET /Channels/Features`, `GET /Channels/Items/Latest`
- Jellyfin "Channels" — plugin-based content (e.g. YouTube, podcasts). Niche, plugin-dependent.
- **Suggested:** Not Adding — plugin-driven, low demand for video-focused client.

### External IDs / Remote Search (Metadata)

- **API:** `GET /Items/{itemId}/ExternalIdInfos`, `POST /Items/RemoteSearch/Apply/{itemId}` plus RemoteSearch/Movie, Series, etc.
- Fetch external IDs (IMDB, TMDB) and apply remote search results to fix/update metadata.
- **Suggested:** Overlaps with "Item Metadata Editing". Keep under that umbrella or Not Adding (dashboard).

---

## Reference: Jellyfin API Domains (Stable OpenAPI)

For completeness, key API areas from [api.jellyfin.org](https://api.jellyfin.org):

| Domain | Finzy Status |
|--------|--------------|
| `/System/*` | Partial (Info, Ping) — Restart/Shutdown/Logs/ActivityLog = admin, Not Adding |
| `/Users/*` | Auth, Views, PlayedItems, FavoriteItems — Password/ForgotPassword = see above |
| `/Items/*` | Implemented: query, metadata, Similar, LocalTrailers, PlaybackInfo, ThemeMedia, Intros, SpecialFeatures, CriticReviews = gaps |
| `/Library/*` | Refresh implemented — VirtualFolders = admin, Not Adding |
| `/Sessions/*` | Progress, Stopped, list — Capabilities, Command, Playing = Planned (Remote Control) |
| `/SyncPlay/*` | Planned |
| `/DisplayPreferences/*` | Later |
| `/Playlists/*` | CRUD implemented — Move items = gap |
| `/Collections/*` | Implemented |
| `/LiveTv/*` | Implemented |
| `/QuickConnect/*` | Implemented |
| `/Notifications/*` | Not in OpenAPI stable (likely WebSocket/plugin; jellyfin-web uses it) — Not Adding |
| `/Plugins/*`, `/Packages/*` | Admin — Not Adding |
| `/Devices/*`, `/Auth/Keys/*` | Admin — Not Adding |
| `/DisplayPreferences/*` | Later |
