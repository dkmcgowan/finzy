# Jellyfin vs Plex API Mapping

This doc compares the two APIs against our `MediaServerClient` surface. **TL;DR:** They’re the same *concepts* (libraries, items, playback URL, progress, playlists, etc.). The differences are **auth flow**, **ID/labels**, and **response shapes**. Implementation is mostly “call Jellyfin endpoint → parse JSON → build our existing Plex-shaped DTOs”; no fundamental mismatch.

---

## 1. Auth

| Aspect | Plex | Jellyfin |
|--------|------|----------|
| **Flow** | plex.tv: PIN or token → `clients.plex.tv` for server list → connect to each server with token | Direct to server: user enters server URL + username/password → `POST /Users/AuthenticateByName` → get `AccessToken` |
| **Header** | `X-Plex-Token: <token>` | `Authorization: MediaBrowser Client="Plezy", Device="...", DeviceId="...", Version="...", Token="<token>"` (or legacy `X-Emby-Token`) |
| **Server discovery** | Central (plex.tv returns list of servers) | Per-server (user adds server URL; no central discovery) |

**Implementation:** Different auth screen path and one extra “add server” step for Jellyfin. Once you have a base URL + token, the rest is the same idea.

---

## 2. Libraries & browsing

| Our method | Plex | Jellyfin |
|------------|------|----------|
| `getLibraries()` | `GET /library/sections` → `Directory[]` | `GET /Users/{userId}/Views` → `BaseItemDto[]` (views = libraries) |
| `getLibraryContent(sectionId, start, size, filters)` | `GET /library/sections/{id}/all` + pagination/filters | `GET /Users/{userId}/Items?ParentId={id}&StartIndex=...&Limit=...` + filters |
| `getMetadataWithImages(ratingKey)` | `GET /library/metadata/{ratingKey}` + query params | `GET /Users/{userId}/Items/{id}` (item by id) or `GET /Items/{id}` |
| `getChildren(ratingKey)` | `GET /library/metadata/{ratingKey}/children` | `GET /Users/{userId}/Items?ParentId={id}` |
| `getRecentlyAdded()` | `GET /library/recentlyAdded` | `GET /Users/{userId}/Items?SortBy=DateCreated&SortOrder=Descending` or dedicated resume/recent endpoint |
| `getOnDeck()` / Continue Watching | `GET /library/onDeck` | Resume items: `GET /Users/{userId}/Items/Resume` or similar (ResumeItems) |
| `search(query)` | `GET /hubs/search?query=...` | `GET /Users/{userId}/Items?SearchTerm=...` or `GET /Search/Hints` |

**Mapping:** Straight 1:1. Plex “sections” = Jellyfin “views”; Plex `ratingKey` = Jellyfin item `Id` (GUID string). We just map `BaseItemDto` → `PlexMetadata` (and view → `PlexLibrary`). Field names differ (e.g. `Name` vs `title`, `Id` vs `ratingKey`) but the data is there.

---

## 3. Playback & progress

| Our method | Plex | Jellyfin |
|------------|------|----------|
| `getVideoPlaybackData(ratingKey)` | `GET /library/metadata/{ratingKey}`; build URL from `Part.key` + token | `POST /Items/{id}/PlaybackInfo` (or similar) → get stream URL; item has `MediaSources`, `MediaStreams` |
| `getChapters` / `getMarkers` | In metadata response or `includeChapters` / `includeMarkers` | Item has `Chapters` or similar; markers may be in stream metadata |
| `updateProgress(ratingKey, time, state, duration)` | `POST /:/timeline` with ratingKey, time, state, duration | `POST /Sessions/Playing/Progress` (PlaybackProgressInfo: position in ticks, paused, etc.) |
| `markAsWatched` / `markAsUnwatched` | `GET /:/scrobble` / `GET /:/unscrobble` | Playstate API: report played / mark unplayed |
| `getFileInfo` | From metadata `Media` / `Part` | From item `MediaSources` / `MediaStreams` |

**Mapping:** Same flow—get item → get stream URL → play; report position/state; mark watched/unwatched. Jellyfin uses ticks (10M per second) for position; we already use milliseconds in our API so convert once. Stream URL might be direct or transcoding; both servers support both.

---

## 4. Images & thumbnails

| Our method | Plex | Jellyfin |
|------------|------|----------|
| `getThumbnailUrl(thumbPath)` | `{baseUrl}/{thumbPath}?X-Plex-Token=...` | `GET /Items/{id}/Images/Primary` or `/{imageType}`; full URL is `{baseUrl}/Items/{id}/Images/Primary?...` (token in header or query) |

**Mapping:** Plex gives a path; Jellyfin gives item ID + image type. We can implement `getThumbnailUrl` for Jellyfin by either (a) storing item ID and building the Jellyfin image URL, or (b) adding a small “image URL for this item” helper that takes our internal item reference. No conceptual gap.

---

## 5. Playlists & collections

| Our method | Plex | Jellyfin |
|------------|------|----------|
| `getPlaylists()` | `GET /playlists` | `GET /Users/{userId}/Items?IncludeItemTypes=Playlist` or similar |
| `getPlaylist(id)` | `GET /playlists/{id}/items` | `GET /Playlists/{id}/Items` |
| `createPlaylist` / add/remove/move | `POST /playlists`, `PUT .../items`, etc. | Playlists API: create, add, remove items by id |
| Collections | `GET /library/sections/{id}/collections`, `GET /library/collections/{id}/children` | Items with type collection; children via `ParentId` or collection endpoint |

**Mapping:** Same operations; Jellyfin uses item IDs and standard REST. We build `PlexPlaylist` / `PlexMetadata` from Jellyfin JSON.

---

## 6. Filters, sorts, hubs

| Our method | Plex | Jellyfin |
|------------|------|----------|
| `getLibraryFilters` / `getFilterValues` | `GET /library/sections/{id}/filters`, filter key as path | Query params on `/Items`: `Genres`, `Tags`, `Years`, etc. or dedicated filter endpoints |
| `getLibrarySorts` | `GET /library/sections/{id}/sorts` | `SortBy`, `SortOrder` on `/Items` (e.g. `SortBy=SortName`, `SortOrder=Ascending`) |
| `getLibraryHubs` / `getGlobalHubs` | `GET /hubs/sections/{id}`, `GET /hubs` | “Home” / “Recommended”: e.g. `GET /Users/{userId}/Views/.../Latest`, or similar; Jellyfin has “suggestions” and “next up” style endpoints |

**Mapping:** Plex has dedicated “hubs” and “filters”; Jellyfin uses the same `/Items` endpoint with different params. We can return `PlexFilter` / `PlexSort` / `PlexHub` built from Jellyfin’s available params and response. Slightly more “build from options” than “parse Plex response,” but still just mapping.

---

## 7. Live TV / DVR

| Our method | Plex | Jellyfin |
|------------|------|----------|
| DVRs, channels, EPG, tune | `GET /livetv/dvrs`, `/livetv/epg/channels`, tune endpoint, etc. | Live TV API: channels, guide, stream URLs; different paths and JSON shape |
| Subscriptions / recordings | Plex-specific subscription endpoints | Jellyfin has recording/series timers and similar concepts |

**Mapping:** Both have Live TV and DVR; endpoints and payloads differ. This is the one area where we do a bit more “translation” and possibly stub or simplify in v1 (e.g. basic channel list + stream URL first, then recordings).

---

## 8. Where you might “struggle” (and why it’s still fine)

- **Response shape:** Plex uses `MediaContainer` with `Metadata` / `Directory` arrays; Jellyfin uses `BaseItemDto` (and sometimes arrays of them). So we don’t “struggle” with the *idea*—we just have a Jellyfin-specific parser that turns `BaseItemDto` into `PlexMetadata` (and views into `PlexLibrary`). One adapter layer.
- **IDs:** Plex `ratingKey` is an opaque string; Jellyfin uses GUIDs and numeric ids. We keep using a single string “item id” in our abstraction; JellyfinClient just uses Jellyfin’s id as that string.
- **Optional/advanced features:** Things like Plex “play queue” or “on deck for library” might map to slightly different Jellyfin endpoints (or we implement a “good enough” version with what Jellyfin has). We can start with the core (libraries, items, playback, progress, playlists) and add the rest incrementally.

So: **we don’t struggle to do an implementation**—the APIs are different in naming and shape but align well in concepts. It’s mostly mapping and DTO construction. Your instinct that “it should mostly just map and work” is right for the bulk of the app; the foundation we added (MediaServerClient) is exactly so we can keep that mapping in one place (JellyfinClient) and reuse all existing UI and models.

---

## 9. Suggested implementation order for JellyfinClient

1. **Auth** – Server URL + username/password → `AuthenticateByName` → store token + userId; use `Authorization: MediaBrowser ... Token="..."` on all requests.
2. **Connection test** – `GET /System/Info` or similar with token.
3. **Libraries** – `GET /Users/{userId}/Views` → map to `PlexLibrary`.
4. **Library content & children** – `GET /Users/{userId}/Items?ParentId=...` → map to `PlexMetadata`.
5. **Item detail** – `GET /Users/{userId}/Items/{id}` → `getMetadataWithImages` / playback prep.
6. **Playback URL** – Use Jellyfin’s playback info endpoint → extract stream URL; build `PlexVideoPlaybackData` (and `PlexMediaInfo` from MediaStreams).
7. **Progress** – `POST /Sessions/Playing/Progress` (and mark watched/unwatched) → `updateProgress`, `markAsWatched`, `markAsUnwatched`.
8. **Images** – `getThumbnailUrl` via `/Items/{id}/Images/Primary` (and token).
9. **Search, resume, recent** – `/Items` with `SearchTerm`, or resume/recent endpoints → same list methods.
10. **Playlists, collections, filters/sorts, Live TV** – Add as needed; all mappable from Jellyfin’s API with the same “parse JSON → fill Plex-shaped DTO” pattern.

Once 1–8 work, the app can browse and play from Jellyfin; the rest is incremental.
