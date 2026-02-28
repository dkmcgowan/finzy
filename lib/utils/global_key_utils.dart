/// Parses a globalKey string (format: "serverId:itemId") into its components.
///
/// Returns `null` if the key does not contain a colon separator.
/// Uses [indexOf] so itemIds containing colons are handled correctly.
({String serverId, String itemId})? parseGlobalKey(String globalKey) {
  final idx = globalKey.indexOf(':');
  if (idx < 0) return null;
  return (serverId: globalKey.substring(0, idx), itemId: globalKey.substring(idx + 1));
}
