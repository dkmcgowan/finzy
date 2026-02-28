import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/app_logger.dart';

/// Manages user session lifecycle (initialization, logout, server refresh).
class UserProfileProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;

  StorageService? _storageService;

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

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      final storage = _storageService ?? await StorageService.getInstance();
      await storage.clearUserData();
      _storageService = null;
      _isInitialized = false;
      notifyListeners();
      appLogger.i('User logged out successfully');
    } catch (e) {
      appLogger.e('Error during logout', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshForNewServer([BuildContext? context]) async {
    _storageService = await StorageService.getInstance();
    _isInitialized = true;
    notifyListeners();
  }
}
