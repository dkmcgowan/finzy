# Finzy

A modern Jellyfin client for desktop and mobile. Built with Flutter for native performance and a clean interface.

Finzy is a fork of [Plezy](https://github.com/edde746/plezy), a modern cross-platform Plex client built with Flutter, adapted for [Jellyfin](https://jellyfin.org) instead of Plex.

**Support development** — If you enjoy Finzy, you can leave a tip via [PayPal](https://paypal.me/dkmcgowan). Optional and much appreciated. You can also find this in Settings → Support Development.

<p align="center">
  <img src="assets/screenshots/desktop-home.png" alt="Finzy Desktop Home Screen" width="800" />
</p>

*More screenshots in the [screenshots folder](assets/screenshots/#readme)*

## Platforms

Finzy runs on:


| Platform    | Variants                                                    |
| ----------- | ----------------------------------------------------------- |
| **iOS**     | iPhone, iPad                                                |
| **Android** | Phone, Tablet, TV (universal APK)                            |
| **Windows** | x64, arm64 — installer and portable (.zip)                 |
| **macOS**   | x64, arm64 (universal .dmg)                                 |
| **Linux**   | x64, arm64 — .deb, .rpm, and portable .tar.gz               |


## Download

All builds are available in the [releases](https://github.com/dkmcgowan/finzy/releases/latest) folder. Choose the build for your platform and architecture.

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

### 📺 Live TV & DVR

- Watch live channels and browse the EPG
- Schedule and manage recordings (timers, series timers)
- Access recordings library

### 🔜 Coming Up

- **SyncPlay** — Synchronized playback with friends (server-native, no relay)
- **Remote control** — Cast to or control other Jellyfin sessions on your network

*For a full feature list and roadmap, see [FEATURES.md](FEATURES.md).*

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

