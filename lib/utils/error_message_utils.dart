import 'dart:async';

import 'package:dio/dio.dart';

import '../i18n/strings.g.dart';
import 'app_logger.dart';

/// Extracts a short, user-safe message from an error.
/// Prefers .message when available; falls back to first line of toString().
/// Callers should always log the full error + stackTrace separately.
String safeUserMessage(Object error) {
  // Known types with .message
  if (error is DioException) {
    return error.message ?? error.type.toString();
  }
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  if (error is TimeoutException) return error.message ?? 'Timeout';

  // Try dynamic .message (covers many SDK exceptions)
  try {
    final m = (error as dynamic).message;
    if (m is String && m.isNotEmpty) return m;
  } catch (_) {}

  // Fallback: toString(), first line only (safety for chained/verbose errors)
  return error.toString().split('\n').first.trim();
}

/// Logs full error and stack trace. Use in catch blocks that show errors to users.
void logErrorWithStackTrace(String context, Object error, [StackTrace? stackTrace]) {
  appLogger.e(context, error: error, stackTrace: stackTrace);
}

/// Maps auth-related errors to user-friendly translated messages.
/// Logs full error + stack trace, returns safe display message.
String mapAuthErrorToMessage(Object error, [StackTrace? stackTrace]) {
  logErrorWithStackTrace('Auth error', error, stackTrace);

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return t.auth.connectionTimeout;
      case DioExceptionType.connectionError:
        return t.auth.serverUnreachable;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return t.auth.invalidPassword;
        if (status == 403) return t.auth.notAuthorized;
        if (status != null && status >= 500) return t.auth.serverError;
        break;
      default:
        break;
    }
    // DioException with message
    return error.message ?? t.errors.authenticationFailed(error: safeUserMessage(error));
  }

  // Generic Exception - check message for common patterns
  final msg = error.toString().toLowerCase();
  if (msg.contains('invalid') || msg.contains('401') || msg.contains('unauthorized')) {
    return t.auth.invalidPassword;
  }
  if (msg.contains('timeout') || msg.contains('timed out')) {
    return t.auth.connectionTimeout;
  }

  return t.errors.authenticationFailed(error: safeUserMessage(error));
}

/// Shared helpers for translating network errors into user-friendly messages.
String mapDioErrorToMessage(DioException error, {required String context}) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
      return t.errors.connectionTimeout(context: context);
    case DioExceptionType.connectionError:
      return t.errors.connectionFailed;
    default:
      appLogger.e('Error loading $context', error: error);
      return t.errors.failedToLoad(context: context, error: error.message ?? t.common.unknown);
  }
}

/// Generic fallback for unexpected errors.
String mapUnexpectedErrorToMessage(dynamic error, {required String context, StackTrace? stackTrace}) {
  logErrorWithStackTrace('Unexpected error in $context', error, stackTrace);
  return t.errors.failedToLoad(context: context, error: safeUserMessage(error));
}
