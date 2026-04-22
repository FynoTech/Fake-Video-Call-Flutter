import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/call_schedule_config.dart';
import '../../../core/services/call_scheduler_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/store_listing_launcher.dart';
import '../../language/controllers/language_controller.dart';

class SettingsController extends GetxController {
  final flashEnabled = true.obs;
  final soundEnabled = true.obs;
  final vibrateEnabled = true.obs;
  final callScheduleOptions = const [
    'Off',
    '15s',
    '25s',
    '35s',
    '45s',
    '1 min',
  ];
  final selectedCallSchedule = 'Off'.obs;
  final languageSubtitle = 'English'.obs;

  late final StorageService _storage;
  late final AdsRemoteConfigService _adsRc;
  CallSchedulerService get _scheduler => Get.find<CallSchedulerService>();

  @override
  void onInit() {
    super.onInit();
    _storage = Get.find<StorageService>();
    _adsRc = Get.find<AdsRemoteConfigService>();
    flashEnabled.value = _storage.incomingFlashEnabled;
    soundEnabled.value = _storage.incomingSoundEnabled;
    vibrateEnabled.value = _storage.incomingVibrateEnabled;
    final rawSecs = _storage.autoIncomingEverySeconds;
    final secs = normalizeForegroundCallScheduleSeconds(rawSecs);
    if (secs != rawSecs) {
      unawaited(_storage.setAutoIncomingEverySeconds(secs));
      unawaited(_scheduler.configureForegroundAutoIncoming(
        secs <= 0 ? Duration.zero : Duration(seconds: secs),
      ));
    }
    selectedCallSchedule.value = _labelFromSeconds(secs);
    _refreshLanguageSubtitle();
  }

  void _refreshLanguageSubtitle() {
    languageSubtitle.value =
        LanguageOption.labelForStoredCode(_storage.languageCode);
  }

  void toggleFlash(bool value) {
    flashEnabled.value = value;
    _storage.setIncomingFlashEnabled(value);
  }

  void toggleSound(bool value) {
    soundEnabled.value = value;
    _storage.setIncomingSoundEnabled(value);
  }

  void toggleVibrate(bool value) {
    vibrateEnabled.value = value;
    _storage.setIncomingVibrateEnabled(value);
  }

  void setCallSchedule(String value) {
    selectedCallSchedule.value = value;
    unawaited(_scheduler.configureForegroundAutoIncoming(_durationFromLabel(value)));
  }

  Duration _durationFromLabel(String value) {
    final v = value.trim().toLowerCase();
    if (v == 'off') return Duration.zero;
    if (v.endsWith('s')) {
      final n = int.tryParse(v.substring(0, v.length - 1).trim()) ?? 0;
      return Duration(seconds: n);
    }
    if (v.endsWith('min')) {
      final n = int.tryParse(v.replaceAll('min', '').trim()) ?? 0;
      return Duration(minutes: n);
    }
    return Duration.zero;
  }

  String _labelFromSeconds(int seconds) {
    if (seconds <= 0) return 'Off';
    if (seconds % 60 == 0) {
      final m = seconds ~/ 60;
      final label = '$m min';
      if (callScheduleOptions.contains(label)) return label;
    }
    final s = '${seconds}s';
    if (callScheduleOptions.contains(s)) return s;
    return 'Off';
  }

  Future<void> openLanguage() async {
    if (!_adsRc.languageScreenOn) return;
    await Get.toNamed(AppRoutes.language, arguments: const {'fromSettings': true});
    _refreshLanguageSubtitle();
  }

  void openPremium() {
    Get.toNamed(AppRoutes.premium);
  }

  // Placeholders for navigation / actions:
  void openHowToUse() {
    Get.toNamed(AppRoutes.onboarding, arguments: const {'fromSettings': true});
  }
  void openPrivacyPolicy() {
    final url = _adsRc.privacyPolicyUrl;
    if (!_adsRc.shouldShowPrivacyPolicyInSettings) {
      Get.snackbar(
        'Link unavailable',
        'Privacy policy link is not configured.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    if (url.isEmpty) {
      return;
    }
    unawaited(launchExternalUrl(url));
  }

  void openRateUs() {
    unawaited(openStoreListing());
  }
}

