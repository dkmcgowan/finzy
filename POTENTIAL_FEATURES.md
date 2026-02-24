# Potential Features

Features available in the Jellyfin API that could be implemented. Organized by estimated value and effort.

## Worth Considering

### Live TV
- **Effort:** Very High
- **API:** `GET /LiveTv/Channels`, `GET /LiveTv/Programs`, `GET /LiveTv/Programs/Recommended`, `GET /LiveTv/Recordings`, `GET /LiveTv/Timers`, `GET /LiveTv/GuideInfo`, `GET /LiveTv/LiveStreamFiles/{streamId}/stream.{container}`, plus timer/series-timer CRUD
- Jellyfin has a full Live TV subsystem supporting HDHomeRun tuners, M3U/IPTV playlists, and guide data (Schedules Direct, XMLTV). Features include: browsing channels, viewing the program guide (EPG), watching live streams, managing recordings, and setting one-time or series recording timers. This is a large surface area covering channel browsing, guide grid UI, live stream playback, recording management, and DVR scheduling.

### Person / Actor Browsing
- **Effort:** Low-Medium
- **API:** `GET /Persons/{name}`, `GET /Items?PersonIds={id}&PersonTypes=Actor`
- Tap on a cast member in the detail screen to see their full filmography. The cast section already displays actors; this would add a person detail screen showing all movies/shows they appear in. Jellyfin stores person metadata including bio, birth date, and images.

### SyncPlay (Server-Native)
- **Effort:** High
- **API:** `POST /SyncPlay/*` (New, Join, Leave, Play, Pause, Seek, SetPlaylistItem, etc.)
- Jellyfin has built-in synchronized playback coordinated by the server. Unlike the removed Watch Together feature (which used a custom relay), SyncPlay requires no external infrastructure — it's all server-side. Worth considering if synchronized viewing is desired again.

### Remote Control / Session Commands
- **Effort:** Medium
- **API:** `POST /Sessions/{sessionId}/Playing`, `POST /Sessions/{sessionId}/Command`
- Send play commands to other active Jellyfin sessions (play, pause, seek, queue items on another device). Enables "cast to" another Jellyfin client scenario.

### Playback Statistics / Activity
- **Effort:** Medium
- **API:** Session activity endpoints, playback reporting
- Show recently played history, viewing habits, or playback stats. Some servers use the Playback Reporting plugin which exposes additional data.

### Instant Mix
- **Effort:** Low-Medium
- **API:** `GET /Items/{id}/InstantMix`, `GET /Artists/InstantMix`, `GET /MusicGenres/{name}/InstantMix`
- Auto-generate playlists from an album, artist, song, genre, or existing playlist. Primarily a music feature, but the API exists for any item type.

### Item Metadata Editing
- **Effort:** Medium
- **API:** `PUT /Items/{id}` (ItemUpdateController)
- Edit item metadata (title, description, genres, tags, ratings, year, etc.) directly from the client. Useful for fixing incorrect metadata without switching to the web dashboard.

### Metadata Refresh
- **Effort:** Low
- **API:** `POST /Items/{id}/Refresh` (ItemRefreshController)
- Trigger a server-side metadata re-scan for an item. Useful when artwork or info is wrong. Could be added as a context menu option on media cards or the detail screen.

## Probably Not Worth Adding

### Music Playback
- **Effort:** Very High
- Full music support: artists, albums, songs, queue management, background audio, gapless playback, lyrics (Jellyfin has a Lyrics API), Now Playing UI. Dedicated music clients like Finamp already serve this well.

### Music Videos / Books / Photos
- Jellyfin supports these media types but they are niche for a video-focused client.

### User Management / Admin Panel
- Creating/deleting users, setting parental controls, managing server configuration. Best left to the Jellyfin web dashboard.

### Plugin Management
- Installing/uninstalling server plugins from the client. Better handled via the web dashboard.

### Notifications API
- Server-side admin notifications to users. Low value for a client app.

### Branding / Server Configuration
- Custom login messages, server branding. Admin-level functionality.
