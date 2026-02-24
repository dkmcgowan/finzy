/// Extension methods for appending authentication tokens to URLs.
extension AuthUrlExtension on String {
  /// Appends an authentication token to this URL string.
  ///
  /// Automatically determines whether to use '?' or '&' as the separator
  /// based on whether the URL already contains query parameters.
  ///
  /// If [token] is null or empty, returns the URL unchanged.
  ///
  /// Example:
  /// ```dart
  /// final url = '/path'.withAuthToken('abc123');
  /// // Result: '/path?ApiKey=abc123'
  ///
  /// final urlWithParams = '/path?type=1'.withAuthToken('abc123');
  /// // Result: '/path?type=1&ApiKey=abc123'
  /// ```
  String withAuthToken(String? token) {
    if (token == null || token.isEmpty) return this;
    final separator = contains('?') ? '&' : '?';
    return '$this${separator}ApiKey=${Uri.encodeComponent(token)}';
  }

  /// Appends a base URL and authentication token to this path string.
  ///
  /// If [token] is null or empty, returns the URL without a token parameter.
  ///
  /// Example:
  /// ```dart
  /// final fullUrl = '/path'.toAuthUrl('https://server.example.com', 'abc123');
  /// // Result: 'https://server.example.com/path?ApiKey=abc123'
  /// ```
  String toAuthUrl(String baseUrl, String? token) {
    return '$baseUrl$this'.withAuthToken(token);
  }
}
