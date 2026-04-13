// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

void main() {
  final base = Directory('lib/i18n');
  final enPath = File('${base.path}/en.i18n.json');
  final en = _flatten(jsonDecode(enPath.readAsStringSync()) as Map<String, dynamic>);

  final skipExact = <String>{
    'Finzy', 'Jellyfin', 'OK', 'TV', 'HD', 'SD', 'UHD', '4K', '8K', 'CD', 'DVD', 'BD',
    'HTTP', 'HTTPS', 'URL', 'API', 'JSON', 'XML', 'GPU', 'CPU', 'GB', 'MB', 'KB',
    'Wi-Fi', 'WiFi', 'LAN', 'WAN', 'IPv4', 'IPv6', 'fps', 'FPS', 'kbps', 'Mbps', 'Gbps',
    'ms', 'AM', 'PM', 'PiP', 'PIP', 'CJK', 'Linux', 'Windows', 'macOS', 'Android', 'iOS',
    'Flutter', 'Dart', 'GitHub', 'OpenSubtitles', 'IMDb', 'TMDB', 'ISO', 'UTF-8', 'SQLite',
    'SQL', 'DRM', 'AAC', 'FLAC', 'OGG', 'OPUS', 'PCM', 'WAV', 'MKV', 'MP4', 'WebM', 'MPEG',
    'GIF', 'PNG', 'JPEG', 'JPG', 'SVG', 'PDF', 'CSV', 'N/A', 'UI', 'UX', 'LED', 'OLED', 'LCD',
    'VRR', 'HDMI', 'USB', 'USB-C', 'SSD', 'HDD', 'NVMe', 'VPN', 'DNS', 'QR', 'ASCII',
    'HDR', 'SDR', 'PQ', 'HLG', 'HEVC', 'AV1', 'VP9', 'ASS', 'SSA', 'MPV', 'ExoPlayer',
    'Dolby Vision', 'Dolby Atmos', 'TrueHD', 'DTS', 'H.264', 'H.265', 'BT.709', 'BT.2020',
    'VA-API', 'VDPAU', 'FFmpeg', 'libass', 'Plex', 'Navidrome', 'Emby',
  };

  for (final loc in ['de', 'es', 'fr', 'it', 'ko', 'nl', 'sv', 'zh']) {
    final f = File('${base.path}/$loc.i18n.json');
    if (!f.existsSync()) continue;
    final locFlat = _flatten(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    final same = <String, String>{};
    for (final e in locFlat.entries) {
      final k = e.key;
      final v = e.value;
      if (!en.containsKey(k)) continue;
      final ev = en[k]!;
      if (v is! String || ev is! String) continue;
      if (v != ev) continue;
      if (v.length <= 2) continue;
      if (skipExact.contains(v)) continue;
      if (v.contains(r'$') || v.contains('{')) continue;
      if (loc == 'zh' && v.runes.any((c) => c >= 0x4e00 && c <= 0x9fff)) continue;
      if (loc == 'ko' && v.runes.any((c) => c >= 0xac00 && c <= 0xd7a3)) continue;
      same[k] = v;
    }
    stdout.writeln('$loc: ${same.length} keys identical to English');
    final keys = same.keys.toList()..sort();
    for (var i = 0; i < keys.length && i < 120; i++) {
      final k = keys[i];
      var val = same[k]!;
      if (val.length > 90) val = '${val.substring(0, 90)}…';
      stdout.writeln('  $k: $val');
    }
    if (keys.length > 120) stdout.writeln('  ... +${keys.length - 120} more');
  }
}

Map<String, dynamic> _flatten(Map<String, dynamic> d, [String prefix = '']) {
  final out = <String, dynamic>{};
  for (final e in d.entries) {
    final key = prefix.isEmpty ? e.key : '$prefix.${e.key}';
    if (e.value is Map<String, dynamic>) {
      out.addAll(_flatten(e.value as Map<String, dynamic>, key));
    } else {
      out[key] = e.value;
    }
  }
  return out;
}
