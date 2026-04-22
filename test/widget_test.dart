import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:prank_call_app/app/translations/app_translations.dart';
import 'package:prank_call_app/modules/home/controllers/home_controller.dart';
import 'package:prank_call_app/modules/home/views/home_view.dart';

void main() {
  testWidgets(
    'HomeView shows home sections',
    (WidgetTester tester) async {
      Get.testMode = true;
      Get.put(HomeController());

      await tester.pumpWidget(
        GetMaterialApp(
          translations: AppTranslations(),
          locale: const Locale('en', 'US'),
          fallbackLocale: const Locale('en', 'US'),
          home: const HomeView(),
        ),
      );

      expect(find.text('Fake Video Call'), findsWidgets);
      expect(find.text('Main Features'), findsOneWidget);

      Get.reset();
    },
    skip: true,
  );
}
