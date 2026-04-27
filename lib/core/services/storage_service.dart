import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageService extends GetxService {
  static const _boxName = 'prank_call_app';

  late final GetStorage _box;

  Future<StorageService> init() async {
    await GetStorage.init(_boxName);
    _box = GetStorage(_boxName);
    return this;
  }

  static const keyLanguageCode = 'language_code';
  static const keyOnboardingComplete = 'onboarding_complete';
  static const keyIncomingFlash = 'incoming_flash';
  static const keyIncomingSound = 'incoming_sound';
  static const keyIncomingVibrate = 'incoming_vibrate';
  static const keyIncomingRingtoneUri = 'incoming_ringtone_uri';
  static const keyIncomingRingtoneTitle = 'incoming_ringtone_title';
  static const keyAutoIncomingEverySeconds = 'auto_incoming_every_seconds';
  static const keyPermissionRationaleCompleted = 'permission_rationale_completed';
  static const keyStartupPermissionsRequested = 'startup_permissions_requested';
  static const keyPremiumUnlocked = 'premium_unlocked';
  static const keyCallReviews = 'call_reviews';

  String? get languageCode => _box.read<String>(keyLanguageCode);

  Future<void> setLanguageCode(String code) async {
    await _box.write(keyLanguageCode, code);
  }

  bool get onboardingComplete =>
      _box.read<bool>(keyOnboardingComplete) ?? false;

  Future<void> setOnboardingComplete(bool value) async {
    await _box.write(keyOnboardingComplete, value);
  }

  /// After the user sees the pre-permission explanation once (Continue or Not now).
  bool get permissionRationaleCompleted =>
      _box.read<bool>(keyPermissionRationaleCompleted) ?? false;

  Future<void> setPermissionRationaleCompleted(bool value) async {
    await _box.write(keyPermissionRationaleCompleted, value);
  }

  /// Used to avoid repeatedly spamming system permission prompts.
  bool get startupPermissionsRequested =>
      _box.read<bool>(keyStartupPermissionsRequested) ?? false;

  Future<void> setStartupPermissionsRequested(bool value) async {
    await _box.write(keyStartupPermissionsRequested, value);
  }

  bool _readBoolPref(String key, {bool defaultValue = true}) {
    final v = _box.read(key);
    if (v == null) return defaultValue;
    if (v is bool) return v;
    if (v is int) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return defaultValue;
  }

  bool get incomingFlashEnabled =>
      _readBoolPref(keyIncomingFlash, defaultValue: true);

  Future<void> setIncomingFlashEnabled(bool value) async {
    await _box.write(keyIncomingFlash, value);
  }

  bool get incomingSoundEnabled =>
      _readBoolPref(keyIncomingSound, defaultValue: true);

  Future<void> setIncomingSoundEnabled(bool value) async {
    await _box.write(keyIncomingSound, value);
  }

  bool get incomingVibrateEnabled =>
      _readBoolPref(keyIncomingVibrate, defaultValue: true);

  Future<void> setIncomingVibrateEnabled(bool value) async {
    await _box.write(keyIncomingVibrate, value);
  }

  String? get incomingRingtoneUri =>
      _box.read<String>(keyIncomingRingtoneUri);

  String? get incomingRingtoneTitle =>
      _box.read<String>(keyIncomingRingtoneTitle);

  /// Clears stored ringtone when [uri] is null or empty.
  Future<void> setIncomingRingtone(String? uri, {String? title}) async {
    if (uri == null || uri.isEmpty) {
      await _box.remove(keyIncomingRingtoneUri);
      await _box.remove(keyIncomingRingtoneTitle);
      return;
    }
    await _box.write(keyIncomingRingtoneUri, uri);
    if (title != null && title.isNotEmpty) {
      await _box.write(keyIncomingRingtoneTitle, title);
    } else {
      await _box.remove(keyIncomingRingtoneTitle);
    }
  }

  /// Foreground auto-incoming interval. 0 means disabled.
  int get autoIncomingEverySeconds {
    final v = _box.read(keyAutoIncomingEverySeconds);
    if (v is int) return v < 0 ? 0 : v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> setAutoIncomingEverySeconds(int seconds) async {
    await _box.write(keyAutoIncomingEverySeconds, seconds < 0 ? 0 : seconds);
  }

  bool get isPremiumUnlocked => _readBoolPref(keyPremiumUnlocked, defaultValue: false);

  Future<void> setPremiumUnlocked(bool value) async {
    await _box.write(keyPremiumUnlocked, value);
  }

  List<Map<String, dynamic>> get callReviews {
    final raw = _box.read<List<dynamic>>(keyCallReviews) ?? const <dynamic>[];
    return raw
        .whereType<Map>()
        .map(
          (e) => e.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        )
        .toList();
  }

  Future<void> addCallReview(Map<String, dynamic> review) async {
    final current = callReviews;
    current.add(review);
    await _box.write(keyCallReviews, current);
  }
}
