import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/storage_service.dart';

class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.label,
    required this.locale,
    required this.flagAsset,
  });

  final String code;
  final String label;
  final Locale locale;

  /// Your assets under `assets/lang/` (e.g. `ic_eng.png`, `ic_french.png`).
  final String flagAsset;

  static const List<LanguageOption> all = [
    LanguageOption(
      code: 'fr_FR',
      label: 'French',
      locale: Locale('fr', 'FR'),
      flagAsset: 'assets/lang/ic_french.png',
    ),
    LanguageOption(
      code: 'es_ES',
      label: 'Spanish',
      locale: Locale('es', 'ES'),
      flagAsset: 'assets/lang/ic_spanish.png',
    ),
    LanguageOption(
      code: 'uk_UA',
      label: 'Ukrainian',
      locale: Locale('uk', 'UA'),
      flagAsset: 'assets/lang/ic_ukr.png',
    ),
    LanguageOption(
      code: 'en_US',
      label: 'English',
      locale: Locale('en', 'US'),
      flagAsset: 'assets/lang/ic_eng.png',
    ),
    LanguageOption(
      code: 'de_DE',
      label: 'German',
      locale: Locale('de', 'DE'),
      flagAsset: 'assets/lang/ic_german.png',
    ),
    LanguageOption(
      code: 'zh_CN',
      label: 'Chinese',
      locale: Locale('zh', 'CN'),
      flagAsset: 'assets/lang/ic_chinese.png',
    ),
    LanguageOption(
      code: 'pt_BR',
      label: 'Brazil',
      locale: Locale('pt', 'BR'),
      flagAsset: 'assets/lang/ic_brazil.png',
    ),
    LanguageOption(
      code: 'tr_TR',
      label: 'Turkey',
      locale: Locale('tr', 'TR'),
      flagAsset: 'assets/lang/ic_turkey.png',
    ),
  ];

  /// Label shown in settings; matches [StorageService.languageCode] / [all] entries.
  static String labelForStoredCode(String? code) {
    if (code == null || code.isEmpty) return 'English';
    for (final o in all) {
      if (o.code == code) return o.label;
    }
    return 'English';
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
