import 'package:flutter/material.dart';
import '../i18n/strings.g.dart';
import '../services/settings_service.dart';
import '../utils/library_refresh_notifier.dart';

class SettingsProvider extends ChangeNotifier {
  SettingsService? _settingsService;
  LibraryDensity _libraryDensity = LibraryDensity.normal;
  ViewMode _viewMode = ViewMode.grid;
  EpisodePosterMode _episodePosterMode = EpisodePosterMode.seriesPoster;
  TimeFormat _timeFormat = TimeFormat.twelveHour;
  bool _showHeroSection = true;
  bool _useGlobalHubs = true;
  bool _showServerNameOnHubs = false;
  bool _showJellyfinRecommendations = false;
  bool _alwaysKeepSidebarOpen = false;
  bool _showUnwatchedCount = true;
  PerformanceProfile _imageQuality = PerformanceProfile.medium;
  PerformanceProfile _posterSize = PerformanceProfile.medium;
  bool _animationsEnabled = true;
  GridPreloadLevel _gridPreload = GridPreloadLevel.medium;
  bool _hideSupportDevelopment = false;
  bool _showDownloads = true;
  bool _isInitialized = false;
  Future<void>? _initFuture;

  SettingsProvider() {
    // Start initialization eagerly to reduce race conditions
    _initFuture = _initializeSettings();
  }

  /// Ensures the provider is initialized. Call this before accessing settings
  /// in contexts where you need the actual persisted values.
  Future<void> ensureInitialized() => _initFuture ?? _initializeSettings();

  Future<void> _initializeSettings() async {
    if (_isInitialized) return;

    _settingsService = await SettingsService.getInstance();
    _libraryDensity = _settingsService!.getLibraryDensity();
    _viewMode = _settingsService!.getViewMode();
    _episodePosterMode = _settingsService!.getEpisodePosterMode();
    _timeFormat = _settingsService!.getTimeFormat();
    _showHeroSection = _settingsService!.getShowHeroSection();
    _useGlobalHubs = _settingsService!.getUseGlobalHubs();
    _showServerNameOnHubs = _settingsService!.getShowServerNameOnHubs();
    _showJellyfinRecommendations = _settingsService!.getShowJellyfinRecommendations();
    _alwaysKeepSidebarOpen = _settingsService!.getAlwaysKeepSidebarOpen();
    _imageQuality = _settingsService!.getImageQuality();
    _posterSize = _settingsService!.getPosterSize();
    _animationsEnabled = _settingsService!.getAnimationsEnabled();
    _gridPreload = _settingsService!.getGridPreload();
    _hideSupportDevelopment = _settingsService!.getHideSupportDevelopment();
    _showDownloads = _settingsService!.getShowDownloads();
    _isInitialized = true;
    notifyListeners();
  }

  /// Whether the provider has completed initialization
  bool get isInitialized => _isInitialized;

  /// Re-read all settings from storage (e.g. after reset).
  Future<void> refresh() async {
    _isInitialized = false;
    await _initializeSettings();
  }

  LibraryDensity get libraryDensity => _libraryDensity;

  ViewMode get viewMode => _viewMode;

  EpisodePosterMode get episodePosterMode => _episodePosterMode;

  TimeFormat get timeFormat => _timeFormat;

  bool get use24HourTime => _timeFormat == TimeFormat.twentyFourHour;

  bool get showHeroSection => _showHeroSection;

  bool get useGlobalHubs => _useGlobalHubs;

  bool get showServerNameOnHubs => _showServerNameOnHubs;

  bool get showJellyfinRecommendations => _showJellyfinRecommendations;

  bool get alwaysKeepSidebarOpen => _alwaysKeepSidebarOpen;

  bool get showUnwatchedCount => _showUnwatchedCount;

  PerformanceProfile get imageQuality => _imageQuality;

  PerformanceProfile get posterSize => _posterSize;

  bool get animationsEnabled => _animationsEnabled;

  bool get disableAnimations => !_animationsEnabled;

  GridPreloadLevel get gridPreload => _gridPreload;

  bool get hideSupportDevelopment => _hideSupportDevelopment;

  bool get showDownloads => _showDownloads;

  Future<void> setShowDownloads(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_showDownloads != value) {
      _showDownloads = value;
      await _settingsService!.setShowDownloads(value);
      notifyListeners();
    }
  }

  Future<void> setLibraryDensity(LibraryDensity density) async {
    if (!_isInitialized) await _initializeSettings();
    if (_libraryDensity != density) {
      _libraryDensity = density;
      await _settingsService!.setLibraryDensity(density);
      notifyListeners();
    }
  }

  Future<void> setViewMode(ViewMode mode) async {
    if (!_isInitialized) await _initializeSettings();
    if (_viewMode != mode) {
      _viewMode = mode;
      await _settingsService!.setViewMode(mode);
      notifyListeners();
    }
  }

  Future<void> setEpisodePosterMode(EpisodePosterMode mode) async {
    if (!_isInitialized) await _initializeSettings();
    if (_episodePosterMode != mode) {
      _episodePosterMode = mode;
      await _settingsService!.setEpisodePosterMode(mode);
      notifyListeners();
    }
  }

  Future<void> setTimeFormat(TimeFormat format) async {
    if (!_isInitialized) await _initializeSettings();
    if (_timeFormat != format) {
      _timeFormat = format;
      await _settingsService!.setTimeFormat(format);
      notifyListeners();
    }
  }

  Future<void> setShowHeroSection(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_showHeroSection != value) {
      _showHeroSection = value;
      await _settingsService!.setShowHeroSection(value);
      notifyListeners();
    }
  }

  Future<void> setUseGlobalHubs(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_useGlobalHubs != value) {
      _useGlobalHubs = value;
      await _settingsService!.setUseGlobalHubs(value);
      notifyListeners();
    }
  }

  Future<void> setShowServerNameOnHubs(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_showServerNameOnHubs != value) {
      _showServerNameOnHubs = value;
      await _settingsService!.setShowServerNameOnHubs(value);
      notifyListeners();
    }
  }

  Future<void> setShowJellyfinRecommendations(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_showJellyfinRecommendations != value) {
      _showJellyfinRecommendations = value;
      await _settingsService!.setShowJellyfinRecommendations(value);
      notifyListeners();
      LibraryRefreshNotifier().notifyRecommendationsChanged();
    }
  }

  Future<void> setAlwaysKeepSidebarOpen(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_alwaysKeepSidebarOpen != value) {
      _alwaysKeepSidebarOpen = value;
      await _settingsService!.setAlwaysKeepSidebarOpen(value);
      notifyListeners();
    }
  }

  Future<void> setShowUnwatchedCount(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_showUnwatchedCount != value) {
      _showUnwatchedCount = value;
      await _settingsService!.setShowUnwatchedCount(value);
      notifyListeners();
    }
  }

  Future<void> setImageQuality(PerformanceProfile value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_imageQuality != value) {
      _imageQuality = value;
      await _settingsService!.setImageQuality(value);
      notifyListeners();
    }
  }

  Future<void> setPosterSize(PerformanceProfile value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_posterSize != value) {
      _posterSize = value;
      await _settingsService!.setPosterSize(value);
      notifyListeners();
    }
  }

  Future<void> setAnimationsEnabled(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_animationsEnabled != value) {
      _animationsEnabled = value;
      await _settingsService!.setAnimationsEnabled(value);
      notifyListeners();
    }
  }

  Future<void> setGridPreload(GridPreloadLevel value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_gridPreload != value) {
      _gridPreload = value;
      await _settingsService!.setGridPreload(value);
      notifyListeners();
    }
  }

  Future<void> setHideSupportDevelopment(bool value) async {
    if (!_isInitialized) await _initializeSettings();
    if (_hideSupportDevelopment != value) {
      _hideSupportDevelopment = value;
      await _settingsService!.setHideSupportDevelopment(value);
      notifyListeners();
    }
  }

  String get libraryDensityDisplayName {
    switch (_libraryDensity) {
      case LibraryDensity.compact:
        return 'Compact';
      case LibraryDensity.normal:
        return 'Normal';
      case LibraryDensity.comfortable:
        return 'Comfortable';
    }
  }

  String get episodePosterModeDisplayName {
    switch (_episodePosterMode) {
      case EpisodePosterMode.seriesPoster:
        return t.settings.seriesPoster;
      case EpisodePosterMode.seasonPoster:
        return t.settings.seasonPoster;
      case EpisodePosterMode.episodeThumbnail:
        return t.settings.episodeThumbnail;
    }
  }

  String get timeFormatDisplayName {
    switch (_timeFormat) {
      case TimeFormat.twelveHour:
        return t.settings.twelveHour;
      case TimeFormat.twentyFourHour:
        return t.settings.twentyFourHour;
    }
  }

  String get imageQualityDisplayName {
    switch (_imageQuality) {
      case PerformanceProfile.small:
        return t.settings.performanceSmall;
      case PerformanceProfile.medium:
        return t.settings.performanceMedium;
      case PerformanceProfile.large:
        return t.settings.performanceLarge;
    }
  }

  String get posterSizeDisplayName {
    switch (_posterSize) {
      case PerformanceProfile.small:
        return t.settings.performanceSmall;
      case PerformanceProfile.medium:
        return t.settings.performanceMedium;
      case PerformanceProfile.large:
        return t.settings.performanceLarge;
    }
  }

  String get gridPreloadDisplayName {
    switch (_gridPreload) {
      case GridPreloadLevel.low:
        return t.settings.performanceLow;
      case GridPreloadLevel.medium:
        return t.settings.performanceMedium;
      case GridPreloadLevel.high:
        return t.settings.performanceHigh;
    }
  }

  /// Cache extent in logical pixels for scroll views (from grid preload setting).
  double get gridPreloadCacheExtent => _gridPreload.cacheExtent;
}
