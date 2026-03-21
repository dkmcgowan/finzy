import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:finzy/i18n/strings.g.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('app.finzy/pip');

  /// PiP is only supported on Android, iOS, and macOS
  static bool get _isAvailable => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  // Singleton instance
  static final PipService _instance = PipService._internal();
  factory PipService() => _instance;

  PipService._internal() {
    if (_isAvailable) {
      _channel.setMethodCallHandler(_handleMethodCall);
    }
  }

  /// ValueNotifier for PiP state - widgets can listen to this
  final ValueNotifier<bool> isPipActive = ValueNotifier<bool>(false);

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onPipChanged':
        final isInPip = call.arguments as bool;
        isPipActive.value = isInPip;
        break;
    }
  }

  static Future<bool> isSupported() async {
    if (!_isAvailable) return false;
    return await _channel.invokeMethod<bool>('isSupported') ?? false;
  }

  static Future<(bool success, String? error)> enter({int? width, int? height}) async {
    if (!_isAvailable) {
      return (false, t.videoControls.pipErrors.notSupported);
    }
    final result = await _channel.invokeMethod<Map>('enter', {'width': width, 'height': height});
    if (result == null) {
      return (false, t.videoControls.pipErrors.unknown(error: 'No response'));
    }
    final success = result['success'] as bool? ?? false;
    final errorCode = result['errorCode'] as String?;
    final errorMessage = result['errorMessage'] as String?;
    final error = errorCode != null ? _getLocalizedError(errorCode, errorMessage) : null;
    return (success, error);
  }

  static String _getLocalizedError(String errorCode, String? errorMessage) {
    return switch (errorCode) {
      'android_version' => t.videoControls.pipErrors.androidVersion,
      'permission_disabled' => t.videoControls.pipErrors.permissionDisabled,
      'not_supported' => t.videoControls.pipErrors.notSupported,
      'failed' => t.videoControls.pipErrors.failed,
      _ => t.videoControls.pipErrors.unknown(error: errorMessage ?? 'Unknown error'),
    };
  }
}
