# Finzy

A modern Jellyfin client for desktop and mobile. Built with Flutter for native performance and a clean interface.

Finzy is a fork of [Plezy](https://github.com/edde746/plezy), a modern cross-platform Plex client built with Flutter, adapted for [Jellyfin](https://jellyfin.org) instead of Plex.

**Support development** — If you enjoy Finzy, you can leave a tip via [PayPal](https://paypal.me/dkmcgowan). Optional and much appreciated. You can also find this in Settings → Support Development.

<p align="center">
  <img src="assets/screenshots/desktop-home.png" alt="Finzy Desktop Home Screen" width="800" />
</p>

*More screenshots in the [screenshots folder](assets/screenshots/#readme)*

## Download

<a href='https://apps.apple.com/us/app/id6754315964'><img height='60' alt='Download on the App Store' src='./assets/app-store-badge.png'/></a>
<a href='https://play.google.com/store/apps/details?id=com.dkmcgowan.finzy'><img height='60' alt='Get it on Google Play' src='./assets/play-store-badge.png'/></a>
<a href='https://www.amazon.com/gp/product/B0GRRLSYDX'><img height='60' alt='Available at the Amazon App Store' src='./assets/amazon-badge.png'/></a>

- [Windows (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest/download/finzy-windows-installer.exe)
- [macOS (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest/download/finzy-macos.dmg)
- [Linux (x64, arm64)](https://github.com/dkmcgowan/finzy/releases/latest) - .deb, .rpm, .pkg.tar.zst, and portable tar.gz available
## - [NixOS/Nix](https://github.com/mio-19/nurpkgs/tree/main/pkgs/finzy) - Community package by [@mio-19](https://github.com/mio-19)
- **Homebrew** (macOS):
  ```bash
  brew tap dkmcgowan/finzy https://github.com/dkmcgowan/finzy
  brew install --cask finzy
  ```
## - **WinGet** (Windows):
##   ```bash
##   winget install dkmcgowan.finzy
##   ```

## Features

### 🔐 Authentication

- Sign in with Jellyfin (server URL + username/password or Quick Connect)
- Multi-user support with profile switching
- Quick Connect from Settings to add or re-authorize devices

### 📚 Media Browsing

- Browse libraries with rich metadata
- Advanced search across all media
- Collections and playlists
- "More Like This" similar items on detail screens
- Genre, favorites, and recommended tabs
- Cast and crew — browse person detail pages and their filmography

### 🎬 Playback

- Wide codec support (HEVC, AV1, VP9, and more)
- HDR and Dolby Vision (iOS, macOS, Windows)
- Full ASS/SSA subtitle support with custom styling
- External subtitles (load on demand)
- Trickplay timeline thumbnails
- Chapter images and chapter navigation
- Sleep timer
- Picture-in-Picture (PIP)
- External player option (VLC, PotPlayer, etc.)
- Ambient lighting effect for letterbox bars
- Player backends: MPV (desktop) or ExoPlayer (Android)

### ⏭️ Media Segments

- Skip Intro, Skip Outro, Skip Recap, Skip Preview, Skip Ads
- Individual auto-skip toggles for each segment type
- Configurable auto-skip delay
- Manual skip button always available during playback

### 📥 Downloads

- Download media for offline viewing
- Offline mode — browse and play downloaded content when disconnected
- Background downloads with queue management

### 📺 Live TV & DVR

- Watch live channels and browse the EPG
- Schedule and manage recordings (timers, series timers)
- Access recordings library

### 📦 Content & Library

- Rate items
- Delete content (when you have permission)
- Refresh library metadata
- Trailers (local and remote) on detail screens

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

