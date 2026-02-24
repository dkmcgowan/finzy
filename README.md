<h1>
  <img src="assets/finzy.png" alt="Finzy Logo" height="24" style="vertical-align: middle;" />
  Finzy
</h1>

A modern Jellyfin client for desktop and mobile. Built with Flutter for native performance and a clean interface.

Finzy is a fork of [Plezy](https://github.com/edde746/plezy), a modern cross-platform Plex client built with Flutter, adapted for [Jellyfin](https://jellyfin.org) instead of Plex.

<p align="center">
  <img src="assets/screenshots/macos-home.png" alt="Finzy macOS Home Screen" width="800" />
</p>

*More screenshots in the [screenshots folder](assets/screenshots/#readme)*

## Download

- [Windows (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest)
- [macOS (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest)
- [Linux (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest) - .deb, .rpm, .pkg.tar.zst, and portable tar.gz available

## Features

### 🔐 Authentication
- Sign in with Jellyfin (server URL + username/password or Quick Connect)
- Multi-user support with profile switching

### 📚 Media Browsing
- Browse libraries with rich metadata
- Advanced search across all media
- Collections and playlists
- "More Like This" similar items on detail screens
- Genre, favorites, and recommended tabs

### 🎬 Playback
- Wide codec support (HEVC, AV1, VP9, and more)
- HDR and Dolby Vision (iOS, macOS, Windows)
- Full ASS/SSA subtitle support with custom styling
- External subtitles (load on demand)
- Trickplay timeline thumbnails
- Chapter images and chapter navigation

### ⏭️ Media Segments
- Skip Intro, Skip Outro, Skip Recap, Skip Preview, Skip Ads
- Individual auto-skip toggles for each segment type
- Configurable auto-skip delay
- Manual skip button always available during playback

### 📥 Downloads
- Download media for offline viewing
- Background downloads with queue management

## Building from Source

### Prerequisites
- Flutter SDK 3.8.1+
- A Jellyfin server

### Setup

```bash
git clone https://github.com/dkmcgowan/finzy.git
cd finzy
flutter pub get
dart run build_runner build
dart run slang
flutter run
```

### Code Generation

After modifying model classes:

```bash
dart run build_runner build --delete-conflicting-outputs
```

After modifying i18n files:

```bash
dart run slang
```

## Acknowledgments

- **Based on [Plezy](https://github.com/edde746/plezy)** — modern cross-platform Plex client built with Flutter; Finzy is a fork for Jellyfin.
- Built with [Flutter](https://flutter.dev)
- Designed for [Jellyfin](https://jellyfin.org)
- Playback powered by [mpv](https://mpv.io) via [MPVKit](https://github.com/mpvkit/MPVKit) and [libmpv-android](https://github.com/jarnedemeulemeester/libmpv-android)
