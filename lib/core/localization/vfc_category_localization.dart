import 'package:get/get.dart';

/// Label for a VFC JSON category tab/dropdown. Uses [id] as translation key
/// `vfc_cat_<id>`; if missing, shows [fallbackFromJson] from the asset.
String localizedVfcCategoryName(String id, String fallbackFromJson) {
  if (id.isEmpty) return fallbackFromJson;
  final key = 'vfc_cat_$id';
  final translated = key.tr;
  return translated == key ? fallbackFromJson : translated;
}
