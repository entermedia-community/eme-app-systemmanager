import 'package:intl/intl.dart';

/// Language codes the server uses in multilanguage maps.
const knownLanguages = {
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
  'zh': '中文',
  'ar': 'العربية',
  'bn': 'বাংলা',
  'ja': '日本語',
};

/// A multilanguage value is a map of language codes to strings, e.g. {"en":"Articles","es":"Artículos"}.
bool isLanguageMap(Object? v) =>
    v is Map &&
    v.isNotEmpty &&
    !v.containsKey('id') &&
    v.keys.every((k) => k is String && k.length <= 5) &&
    v.values.every((x) => x is String);

String localized(Object? v, [String lang = 'en']) {
  if (v == null) return '';
  if (v is String) return v;
  if (v is Map) {
    if (isLanguageMap(v)) {
      final s = v[lang] ?? v['en'] ?? v.values.first;
      return '$s';
    }
    final name = v['name'];
    if (name != null) return localized(name, lang);
    return '${v['id'] ?? ''}';
  }
  return '$v';
}

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}');

DateTime? parseDate(Object? v) {
  if (v is! String || !_isoDate.hasMatch(v)) return null;
  return DateTime.tryParse(v)?.toLocal();
}

String formatDate(DateTime d, {bool withTime = false}) => withTime
    ? DateFormat.yMMMd().add_jm().format(d)
    : DateFormat.yMMMd().format(d);

/// Server ISO format: yyyy-MM-dd'T'HH:mm:ss.SSSZ in UTC.
String toServerDate(DateTime d) => d.toUtc().toIso8601String();

/// Human readable rendering of any serialized field value.
String displayValue(Object? v, {String lang = 'en'}) {
  if (v == null) return '';
  if (v is List) {
    return v
        .map((e) => displayValue(e, lang: lang))
        .where((s) => s.isNotEmpty)
        .join(', ');
  }
  if (v is Map) return localized(v, lang);
  final s = '$v';
  final d = parseDate(s);
  if (d != null) return formatDate(d, withTime: d.hour != 0 || d.minute != 0);
  if (s == 'true') return 'Yes';
  if (s == 'false') return 'No';
  return s;
}

/// Ids out of a list/multi value: "x", {"id":"x"} or [{"id":"x"}, ...].
List<String> valueIds(Object? v) {
  if (v == null) return const [];
  if (v is List) return v.expand(valueIds).toList();
  if (v is Map) return v['id'] == null ? const [] : ['${v['id']}'];
  final s = '$v';
  return s.isEmpty ? const [] : [s];
}

String formatBytes(Object? v) {
  final n = num.tryParse('${v ?? ''}');
  if (n == null) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = n.toDouble();
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(i == 0 ? 0 : (size < 10 ? 2 : 1))} ${units[i]}';
}

/// Encodes each path segment of a sourcepath for use in a URL.
String encodePath(String path) =>
    path.split('/').map(Uri.encodeComponent).join('/');
