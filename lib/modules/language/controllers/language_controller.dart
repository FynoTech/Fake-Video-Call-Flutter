import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/storage_service.dart';

class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.labelKey,
    required this.locale,
    required this.flagAssetPath,
  });

  final String code;
  final String labelKey;
  final Locale locale;

  /// Flat flag icon shown on language list.
  final String flagAssetPath;

  /// Shown on the language screen in this order: Hindi, Spanish, Portuguese, English,
  /// Arabic, Russian, German, Chinese, Bengali, Turkish.
  static const List<LanguageOption> all = [
    LanguageOption(
      code: 'hi_IN',
      labelKey: 'language_name_hindi',
      locale: Locale('hi', 'IN'),
      flagAssetPath: 'assets/lang/flag_hi_flat.png',
    ),
    LanguageOption(
      code: 'es_ES',
      labelKey: 'language_name_spanish',
      locale: Locale('es', 'ES'),
      flagAssetPath: 'assets/lang/flag_es_flat.png',
    ),
    LanguageOption(
      code: 'pt_BR',
      labelKey: 'language_name_portuguese',
      locale: Locale('pt', 'BR'),
      flagAssetPath: 'assets/lang/flag_pt_flat.png',
    ),
    LanguageOption(
      code: 'en_US',
      labelKey: 'language_name_english',
      locale: Locale('en', 'US'),
      flagAssetPath: 'assets/lang/flag_en_flat.png',
    ),
    LanguageOption(
      code: 'ar_SA',
      labelKey: 'language_name_arabic',
      locale: Locale('ar', 'SA'),
      flagAssetPath: 'assets/lang/flag_ar_flat.png',
    ),
    LanguageOption(
      code: 'ru_RU',
      labelKey: 'language_name_russian',
      locale: Locale('ru', 'RU'),
      flagAssetPath: 'assets/lang/flag_ru_flat.png',
    ),
    LanguageOption(
      code: 'de_DE',
      labelKey: 'language_name_german',
      locale: Locale('de', 'DE'),
      flagAssetPath: 'assets/lang/flag_de_flat.png',
    ),
    LanguageOption(
      code: 'zh_CN',
      labelKey: 'language_name_chinese',
      locale: Locale('zh', 'CN'),
      flagAssetPath: 'assets/lang/flag_cn_flat.png',
    ),
    LanguageOption(
      code: 'bn_BD',
      labelKey: 'language_name_bengali',
      locale: Locale('bn', 'BD'),
      flagAssetPath: 'assets/lang/flag_bd_flat.png',
    ),
    LanguageOption(
      code: 'tr_TR',
      labelKey: 'language_name_turkish',
      locale: Locale('tr', 'TR'),
      flagAssetPath: 'assets/lang/flag_tr_flat.png',
    ),
  ];

  String get label => labelKey.tr;

  /// Label shown in settings; matches [StorageService.languageCode] / [all] entries.
  static String labelForStoredCode(String? code) {
    if (code == null || code.isEmpty) return 'language_name_english'.tr;
    for (final o in all) {
      if (o.code == code) return o.label;
    }
    return 'language_name_english'.tr;
  }
}

class LanguageController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final AdsRemoteConfigService _adsRc = Get.find<AdsRemoteConfigService>();

  List<LanguageOption> get options => LanguageOption.all;

  final selectedCode = RxnString();

  @override
  void onInit() {
    super.onInit();
    if (!_adsRc.languageScreenOn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isClosed) return;
        final args = Get.arguments;
        final fromSettings = args is Map && args['fromSettings'] == true;
        if (fromSettings) {
          Get.back();
          return;
        }
        if (!_storage.onboardingComplete) {
          Get.offAllNamed(AppRoutes.onboarding);
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
      });
      return;
    }
    final args = Get.arguments;
    final fromSettings = args is Map && args['fromSettings'] == true;
    final stored = _storage.languageCode;
    if (stored != null && options.any((o) => o.code == stored)) {
      selectedCode.value = stored;
    } else {
      // First-time language screen: force an explicit user selection.
      selectedCode.value = fromSettings ? 'en_US' : null;
    }
  }

  Future<void> _applyLanguage(String code) async {
    final option = options.firstWhere((o) => o.code == code);
    await _storage.setLanguageCode(code);
    Get.updateLocale(option.locale);
  }

  void select(String code) {
    selectedCode.value = code;
    unawaited(_applyLanguage(code));
  }

  Future<void> confirm() async {
    final code = selectedCode.value;
    if (code == null) return;
    await _applyLanguage(code);

    final args = Get.arguments;
    final fromSettings =
        args is Map && args['fromSettings'] == true;

    if (fromSettings) {
      Get.back();
      return;
    }

    if (!_storage.onboardingComplete) {
      Get.offAllNamed(AppRoutes.onboarding);
    } else {
      Get.offAllNamed(AppRoutes.home);
    }
  }
}
