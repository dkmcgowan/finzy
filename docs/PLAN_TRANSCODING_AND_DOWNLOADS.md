# Plan: Transcoding & Download Quality

This document outlines the plan for adding transcoding support to streaming playback and transcoded download options for offline content. Not yet implemented.

---

## 1. Streaming Playback Mode

### Location
**Settings → Video Playback** (existing section). Add new controls here. No on-screen display (OSD) controls—changing on the fly adds complexity; settings-only is sufficient for now.

### Playback Mode Options

| Value | Behavior |
|-------|----------|
| **Auto** (default) | Use `POST /Items/{id}/PlaybackInfo`—server decides direct play vs remux vs transcode based on device profile. Aligns with jellyfin-web and jellyfin-android. |
| **Direct Play** | Force direct play. Build stream URL with `static=true`, `allowVideoStreamCopy=true`, `allowAudioStreamCopy=true` (current behavior). Bypass PlaybackInfo. |
| **Force Transcode** | Force transcoding with quality preset. Use stream URL *without* static/copy params, add transcoding params. Sub-options: |

### Force Transcode Sub-Options

When "Force Transcode" is selected, user picks a quality preset:

| Preset | Stream URL Params |
|--------|-------------------|
| **1080p** | `maxWidth=1920&maxHeight=1080` |
| **720p** | `maxWidth=1280&maxHeight=720` |
| **480p** | `maxWidth=854&maxHeight=480` |
| **Save bandwidth** | `maxWidth=1920&maxHeight=1080&videoBitRate=3000000` (or similar—tune as needed) |

- No granular controls (bitrate slider, custom resolution) for now.
- Can add "Custom" preset later if desired.

### Implementation Notes

- **Current state:** On-demand video bypasses PlaybackInfo and always builds direct-play URL in `jellyfin_client.getVideoPlaybackData()`.
- **Change:** Add `PlaybackMode` enum and `TranscodeQualityPreset` enum to settings. When Auto: call PlaybackInfo for on-demand (like Live TV), use server's `DirectStreamUrl` or `TranscodingUrl`. When Direct Play: keep current URL-building logic. When Force Transcode: build URL with transcoding params, no static/copy.
- **Live TV:** Already uses PlaybackInfo; no change.

### preferredVideoCodec / preferredAudioCodec

These exist in `SettingsService` but are **never used** for playback—only in `getAllSettings()` for debug export. No UI exposes them.

- **Options:** (a) Remove as dead code, (b) Use when forcing transcode (e.g. `videoCodec=h264`), or (c) Leave for future "Custom" preset.
- **Recommendation:** Use when forcing transcode—pass `videoCodec`/`audioCodec` to stream URL if we add a preference. For MVP, can default to h264/aac when forcing transcode and skip these settings.

---

## 2. Offline Download Quality

### Location
**Settings → Libraries** (section with Show Downloads, Download Location, Download on WiFi only). Add "Download quality" as a new row.

### Download Quality Options

| Value | Behavior |
|-------|----------|
| **Original** (default) | Download the direct stream (current behavior). Full file, no transcoding. |
| **1080p** | Request transcoded stream: `maxWidth=1920&maxHeight=1080`, container mp4. Server transcodes; we download the resulting stream. |
| **720p** | `maxWidth=1280&maxHeight=720`, mp4 |
| **480p** | `maxWidth=854&maxHeight=480`, mp4 |
| **Save storage** | `maxWidth=1920&maxHeight=1080&videoBitRate=3000000`, mp4 |

### Implementation

- **Output:** Local MP4 file. Server returns a transcoded stream; we download it via HTTP and write to file. Same flow as today—just a different URL.
- **No play-while-download:** User clicks download, waits for completion. No progressive playback.
- **No FFmpeg:** Cross-platform; server does all transcoding. We do not run FFmpeg locally.
- **DownloadManagerService:** When preparing download, check `getDownloadQuality()` setting. If not Original, build transcoded stream URL (same params as playback Force Transcode) and use that instead of `getVideoPlaybackData()`'s direct URL. File extension stays `.mp4`.

### API

- Use `GET /Videos/{itemId}/stream.mp4` with transcoding query params.
- Omit `static=true` and stream-copy params to trigger transcoding.

---

## 3. Summary

| Area | Setting Location | Default | Notes |
|------|------------------|---------|-------|
| Playback mode | Video Playback | Auto (PlaybackInfo) | Auto, Direct Play, Force Transcode (1080p/720p/480p/Save bandwidth) |
| Download quality | Libraries | Original | Original, 1080p, 720p, 480p, Save storage |

---

## 4. Files to Touch (When Implementing)

### Playback
- `lib/services/settings_service.dart` — Add `PlaybackMode`, `TranscodeQualityPreset`, getters/setters
- `lib/services/jellyfin_client.dart` — Add `getVideoPlaybackData(..., playbackMode, transcodePreset)`, implement PlaybackInfo for on-demand when Auto
- `lib/services/playback_initialization_service.dart` — Pass playback settings to client
- `lib/screens/settings/settings_screen.dart` — Add playback mode + transcode preset UI in `_buildVideoPlaybackContent`
- `lib/i18n/*.i18n.json` — New strings

### Downloads
- `lib/services/settings_service.dart` — Add `DownloadQuality` enum, getter/setter
- `lib/services/download_manager_service.dart` — In `_prepareAndEnqueueDownload`, when quality != Original, build transcoded stream URL
- `lib/screens/settings/settings_screen.dart` — Add download quality row in `_buildDownloadsItems`
- `lib/i18n/*.i18n.json` — New strings

---

## 5. Out of Scope (For Now)

- OSD / in-player quality switching
- Granular controls (custom resolution, bitrate slider)
- Play-while-download
- Local FFmpeg
- Session Capabilities reporting (can add later for better device profile)
