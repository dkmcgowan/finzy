import 'package:flutter/material.dart';
import '../models/home.dart';
import '../models/home_user.dart';
import '../models/user_profile_preferences.dart';
import '../services/storage_service.dart';
import '../utils/app_logger.dart';

/// Stub provider for legacy profile/home users. Finzy is Jellyfin-only; this provider
/// is kept for compatibility (e.g. profile_switch_screen, settings) but does not load legacy data.
class UserProfileProvider extends ChangeNotifier {
  Home? _home;
  HomeUser? _currentUser;
  UserProfilePreferences? _profileSettings;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  Home? get home => _home;
  HomeUser? get currentUser => _currentUser;
  UserProfilePreferences? get profileSettings => _profileSettings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMultipleUsers => _home?.hasMultipleUsers ?? false;
  bool get needsInitialProfileSelection => false;

  StorageService? _storageService;

  Future<void> Function()? _onDataInvalidationRequested;

  void setDataInvalidationCallback(Future<void> Function()? callback) {
    _onDataInvalidationRequested = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _storageService = await StorageService.getInstance();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      appLogger.e('UserProfileProvider: Initialization failure', error: e);
      _isInitialized = false;
    }
  }

  Future<void> refreshProfileSettings() async {}

  Future<void> loadHomeUsers({bool forceRefresh = false}) async {}

  Future<bool> switchToUser(HomeUser user, BuildContext? context) async {
    return false; // Finzy is Jellyfin-only; legacy profile switch is not supported
  }

  Future<void> refreshCurrentUser() async {}

  Future<void> logout() async {
    _setLoading(true);
    try {
      final storage = _storageService ?? await StorageService.getInstance();
      await storage.clearUserData();
      _home = null;
      _currentUser = null;
      _profileSettings = null;
      _onDataInvalidationRequested = null;
      _storageService = null;
      _isInitialized = false;
      _clearError();
      notifyListeners();
      appLogger.i('User logged out successfully');
    } catch (e) {
      appLogger.e('Error during logout', error: e);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshForNewServer([BuildContext? context]) async {
    _storageService = await StorageService.getInstance();
    _home = null;
    _currentUser = null;
    _profileSettings = null;
    _clearError();
    _isInitialized = true;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
