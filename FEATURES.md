# Features

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

### Change Password

- **Effort:** Low
- **API:** `POST /Users/{userId}/Password`
- Allow users to change their own password or set a PIN from within the app.

## Not Adding

### Edit Subtitles

- Upload, delete, or manage subtitle files on the server. Better handled via the web dashboard.

### Edit Images

- Browse remote image providers, upload, or delete poster/backdrop/logo images on items. Better handled via the web dashboard.

### Merge / Split Movie Versions

- Combine alternate versions of a movie or split them apart. Server-side management best done in the web dashboard.

### Download Original File

- Download the raw (non-transcoded) media file via the API. Out of scope for a streaming client.

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
