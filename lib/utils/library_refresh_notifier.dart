import 'base_notifier.dart';

/// Types of library refresh events
enum LibraryRefreshType { collections, playlists, recommendations }

/// Notifier for triggering refreshes of library tabs.
///
/// Singleton pattern with reinitializable state. The controller is lazily
/// created and automatically recreated if disposed and later accessed.
class LibraryRefreshNotifier extends BaseNotifier<LibraryRefreshType> {
  static final LibraryRefreshNotifier _instance = LibraryRefreshNotifier._internal();

  factory LibraryRefreshNotifier() => _instance;

  LibraryRefreshNotifier._internal();

  /// Stream for collections tab (backward compatible)
  Stream<void> get collectionsStream => stream.where((t) => t == LibraryRefreshType.collections).cast<void>();

  /// Stream for playlists tab (backward compatible)
  Stream<void> get playlistsStream => stream.where((t) => t == LibraryRefreshType.playlists).cast<void>();

  /// Stream for recommendations tab (e.g. when Jellyfin recommendations setting toggles)
  Stream<void> get recommendationsStream => stream.where((t) => t == LibraryRefreshType.recommendations).cast<void>();

  /// Notify that collections have changed
  void notifyCollectionsChanged() {
    notify(LibraryRefreshType.collections);
  }

  /// Notify that playlists have changed
  void notifyPlaylistsChanged() {
    notify(LibraryRefreshType.playlists);
  }

  /// Notify that recommendations tab should refresh (e.g. Jellyfin recommendations setting changed)
  void notifyRecommendationsChanged() {
    notify(LibraryRefreshType.recommendations);
  }
}
