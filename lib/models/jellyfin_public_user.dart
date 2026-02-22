/// A user returned from Jellyfin's public user list (no auth required).
/// Used on the login screen to show selectable users with optional avatar.
class JellyfinPublicUser {
  final String id;
  final String name;
  final String? primaryImageTag;
  final bool hasPassword;

  JellyfinPublicUser({
    required this.id,
    required this.name,
    this.primaryImageTag,
    this.hasPassword = false,
  });

  factory JellyfinPublicUser.fromJson(Map<String, dynamic> json) {
    return JellyfinPublicUser(
      id: json['Id'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      primaryImageTag: json['PrimaryImageTag'] as String?,
      hasPassword: json['HasPassword'] as bool? ?? json['HasConfiguredPassword'] as bool? ?? false,
    );
  }

  /// Build image URL for this user's avatar (no auth; server may allow unauthenticated access).
  String imageUrl(String baseUrl) {
    if (primaryImageTag == null || primaryImageTag!.isEmpty) return '';
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '${base}Users/$id/Images/Primary?tag=${Uri.encodeComponent(primaryImageTag!)}';
  }
}
