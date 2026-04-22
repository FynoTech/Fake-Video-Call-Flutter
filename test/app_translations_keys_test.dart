import 'package:flutter_test/flutter_test.dart';
import 'package:prank_call_app/app/translations/app_translations.dart';

void main() {
  test('every locale map contains the same keys as en_US', () {
    final translations = AppTranslations();
    final keys = translations.keys;
    final en = keys['en_US']!;
    final enKeySet = en.keys.toSet();

    expect(enKeySet, isNotEmpty);

    for (final entry in keys.entries) {
      final code = entry.key;
      final map = entry.value;
      final mapKeys = map.keys.toSet();

      expect(
        mapKeys,
        enKeySet,
        reason:
            'Locale $code should define exactly the same keys as en_US.\n'
            'Missing: ${enKeySet.difference(mapKeys)}\n'
            'Extra: ${mapKeys.difference(enKeySet)}',
      );
    }
  });
}
