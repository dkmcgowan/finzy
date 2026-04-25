// ignore_for_file: avoid_print

// Applies tool/i18n_fill.json to lib/i18n/*.i18n.json when value still matches English.
// Run: dart run tool/apply_i18n_fill.dart

import 'dart:convert';
import 'dart:io';

void main() {
  final fillPath = File('tool/i18n_fill.json');
  if (!fillPath.existsSync()) {
    stderr.writeln('Missing tool/i18n_fill.json');
    exit(1);
  }
  final fill = jsonDecode(fillPath.readAsStringSync()) as Map<String, dynamic>;
  final enPath = File('lib/i18n/en.i18n.json');
  final enFlat = _flatten(jsonDecode(enPath.readAsStringSync()) as Map<String, dynamic>);

  for (final loc in ['de', 'es', 'fr', 'it', 'ko', 'nl', 'sv', 'zh']) {
    final f = File('lib/i18n/$loc.i18n.json');
    final root = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    var changed = 0;
    for (final e in fill.entries) {
      final flatKey = e.key;
      final perLoc = e.value as Map<String, dynamic>;
      if (!perLoc.containsKey(loc)) continue;
      final newVal = perLoc[loc];
      if (newVal is! String) continue;
      if (!enFlat.containsKey(flatKey)) continue;
      final enVal = enFlat[flatKey];
      if (enVal is! String) continue;
      final cur = _readPath(root, flatKey);
      if (cur is! String) continue;
      if (cur != enVal) continue; // already translated differently
      _writePath(root, flatKey, newVal);
      changed++;
    }
    if (changed > 0) {
      f.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(root)}\n');
      print('$loc: updated $changed strings');
    } else {
      print('$loc: no changes');
    }
  }
}

dynamic _readPath(Map<String, dynamic> root, String flatKey) {
  final parts = flatKey.split('.');
  dynamic cur = root;
  for (final p in parts) {
    if (cur is! Map<String, dynamic>) return null;
    cur = cur[p];
  }
  return cur;
}

void _writePath(Map<String, dynamic> root, String flatKey, String value) {
  final parts = flatKey.split('.');
  dynamic cur = root;
  for (var i = 0; i < parts.length - 1; i++) {
    cur = (cur as Map<String, dynamic>)[parts[i]] as Map<String, dynamic>;
  }
  (cur as Map<String, dynamic>)[parts.last] = value;
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
