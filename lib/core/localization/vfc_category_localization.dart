import 'package:get/get.dart';

/// Label for a VFC JSON category tab/dropdown. Uses [id] as translation key
/// `vfc_cat_<id>`; if missing, shows [fallbackFromJson] from the asset.
String localizedVfcCategoryName(String id, String fallbackFromJson) {
  final normalized = _normalizedCategoryKey(id, fallbackFromJson);
  if (normalized.isEmpty) return fallbackFromJson;
  final key = 'vfc_cat_$normalized';
  final translated = key.tr;
  return translated == key ? fallbackFromJson : translated;
}

String _normalizedCategoryKey(String rawId, String fallbackName) {
  String source = rawId.trim().toLowerCase();

  // V2 catalog often uses numeric ids (1, 2, 3...) and a separate "key" field in data.
  // When we only receive numeric id here, derive from visible category name instead.
  if (source.isEmpty || RegExp(r'^\d+$').hasMatch(source)) {
    source = fallbackName.trim().toLowerCase();
  }

  if (source.isEmpty) return '';

  // Keep only letters/digits and collapse separators to underscores.
  source = source.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  source = source.replaceAll(RegExp(r'_+'), '_');
  source = source.replaceAll(RegExp(r'^_|_$'), '');
  return source;
}
