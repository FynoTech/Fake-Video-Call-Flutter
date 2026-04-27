import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart'
    show
        debugPrint,
        defaultTargetPlatform,
        kDebugMode,
        kIsWeb,
        kReleaseMode,
        TargetPlatform;

/// Remote Config-backed ads config:
/// - `ad_ids`: JSON string containing all unit IDs.
/// - `ads_control`: JSON string containing 0/1 toggles per placement.
class AdsRemoteConfigService {
  static const String paramAdIds = 'ad_ids';
  static const String paramAdsControl = 'ads_control';
  static const String paramPrivacyPolicyUrl = 'privacy_policy_url';
  static const String paramPrivacyPolicyOnOff = 'privacy_policy_onoff';
  static const String paramLanguageScreenOnOff = 'language_screen_onoff';
  static const String paramOnboardingGetStartedOnOff =
      'onboarding_get_started_onoff';
  static const String paramIntroLargeNativeBtnColor =
      'intro_large_native_btn_color';
  static const String paramIntroAdBgColor = 'intro_ad_bg_color';
  static const String _defaultPrivacyPolicyUrl =
      'https://fynotech.blogspot.com/p/privacy-policy-fake-video-call-prank-app.html';
  static const String _defaultIntroLargeNativeBtnColor = '#B267FF';
  static const String _defaultIntroAdBgColor = '#2BB267FF';

  /// Not a field: [FirebaseRemoteConfig.instance] requires [Firebase.initializeApp] first.
  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  Map<String, dynamic> _adIds = const {};
  Map<String, dynamic> _adsControl = const {};

  Map<String, dynamic> get adIds => _adIds;
  Map<String, dynamic> get adsControl => _adsControl;

  /// Bumps every time Remote Config values are refreshed (defaults applied,
  /// activate, or fetch-and-activate). Widgets that depend on ad flags can
  /// watch this inside an `Obx` to rebuild when flags become available.
  final RxInt configVersion = 0.obs;

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  // Google sample units (work reliably for debug/testing).
  static const String _testBanner =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _testNative =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testAppOpen =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewarded =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedInterstitial =
      'ca-app-pub-3940256099942544/5354046379';
  static const bool _forceTestAds =
      bool.fromEnvironment('FORCE_TEST_ADS', defaultValue: false);

  static bool get _useTestUnits => _supported && (!kReleaseMode || _forceTestAds);

  Future<AdsRemoteConfigService> init() async {
    // Keep timeouts conservative so splash doesn't hang forever.
    await _rc.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 6),
        minimumFetchInterval: kDebugMode ? Duration.zero : const Duration(hours: 4),
      ),
    );
    await _rc.setDefaults(<String, dynamic>{
      paramAdIds: '{}',
      paramAdsControl: '{}',
      paramPrivacyPolicyUrl: _defaultPrivacyPolicyUrl,
      paramPrivacyPolicyOnOff: '0',
      paramLanguageScreenOnOff: true,
      paramOnboardingGetStartedOnOff: true,
      paramIntroLargeNativeBtnColor: _defaultIntroLargeNativeBtnColor,
      paramIntroAdBgColor: _defaultIntroAdBgColor,
    });
    // Defaults are enough for first paint; [activate] can take hundreds of ms on cold start.
    _refreshFromRc();

    unawaited(() async {
      try {
        await _rc.activate();
      } catch (_) {}
      _refreshFromRc();
      try {
        await _rc.fetchAndActivate();
      } catch (e) {
        if (kDebugMode) debugPrint('RemoteConfig fetch failed: $e');
      }
      _refreshFromRc();
    }());
    return this;
  }

  void _refreshFromRc() {
    _adIds = _decodeJsonObject(_rc.getString(paramAdIds));
    _adsControl = _decodeJsonObject(_rc.getString(paramAdsControl));
    configVersion.value = configVersion.value + 1;
  }

  static Map<String, dynamic> _decodeJsonObject(String raw) {
    try {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  bool flag(String path, {bool defaultValue = false}) {
    final v = _readPath(_adsControl, path);
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == '1' || t == 'true' || t == 'yes' || t == 'on') return true;
      if (t == '0' || t == 'false' || t == 'no' || t == 'off') return false;
    }
    return defaultValue;
  }

  String id(String path) {
    final v = _readPath(_adIds, path);
    return v?.toString().trim() ?? '';
  }

  String _idOrTest(String path, String testUnitId) {
    if (_useTestUnits) return testUnitId;
    return id(path);
  }

  static dynamic _readPath(Map<String, dynamic> root, String path) {
    dynamic cur = root;
    for (final part in path.split('.')) {
      if (cur is Map) {
        cur = cur[part];
      } else {
        return null;
      }
    }
    return cur;
  }

  int _intPath(String path, {int defaultValue = 0}) {
    final v = _readPath(_adsControl, path);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? defaultValue;
    return defaultValue;
  }

  // ---- Typed helpers (keep call sites clean) ----

  /// Global master switch (forced OFF for local testing).
  bool get adsEnabled => true;

  // Splash placements
  bool get splashBannerOn => adsEnabled && flag('splash.banner');
  bool get splashNativeSmallInlineOn => adsEnabled && flag('splash.native_small_inline');
  bool get splashNativeSmallButtonBottomOn =>
      adsEnabled && flag('splash.native_small_button_bottom');
  bool get splashNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('splash.native_advance_button_bottom');
  bool get splashAppOpenOn => adsEnabled && flag('splash.app_open');
  bool get splashInterstitialOn => adsEnabled && flag('splash.interstitial');

  String get splashBannerId => _idOrTest('ads_config.splash.banner', _testBanner);
  String get splashNativeId => _idOrTest('ads_config.splash.native', _testNative);
  String get splashAppOpenId => _idOrTest('ads_config.splash.app_open', _testAppOpen);
  String get splashInterstitialId =>
      _idOrTest('ads_config.splash.interstitial', _testInterstitial);

  // Global app-open (outside splash)
  bool get appOpenOn => adsEnabled && flag('app_open.enabled');
  String get appOpenId => _idOrTest('ads_config.app_open', _testAppOpen);

  // Language screen
  bool get languageInterstitialOn => adsEnabled && flag('language.interstitial');
  bool get languageScreenOn =>
      flag(paramLanguageScreenOnOff, defaultValue: _rcBoolParam(paramLanguageScreenOnOff, defaultValue: true));

  /// AI chat key used by Fake Messaging chatbot (kept in Firebase Remote Config).
  String get chatBotApiKey => _rc.getString('chat_bot_api').trim();

  // Separate placements (top/bottom) so you can control them independently.
  bool get languageTopBannerOn => adsEnabled && flag('language.top.banner');
  bool get languageTopNativeSmallInlineOn =>
      adsEnabled && flag('language.top.native_small_inline');
  bool get languageTopNativeSmallButtonBottomOn =>
      adsEnabled && flag('language.top.native_small_button_bottom');
  bool get languageTopNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('language.top.native_advance_button_bottom');
  bool get languageBottomBannerOn => adsEnabled && flag('language.bottom.banner');
  bool get languageBottomNativeSmallInlineOn =>
      adsEnabled && flag('language.bottom.native_small_inline');
  bool get languageBottomNativeSmallButtonBottomOn =>
      adsEnabled && flag('language.bottom.native_small_button_bottom');
  bool get languageBottomNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('language.bottom.native_advance_button_bottom');
  String get languageBannerId =>
      _idOrTest('ads_config.language.banner', _testBanner);
  String get languageNativeId => _idOrTest('ads_config.language.native', _testNative);
  String get languageInterstitialId =>
      _idOrTest('ads_config.language.interstitial', _testInterstitial);

  // Settings bottom slot
  bool get settingsBottomBannerOn => adsEnabled && flag('settings.bottom.banner');
  bool get settingsBottomNativeSmallInlineOn =>
      adsEnabled && flag('settings.bottom.native_small_inline');
  bool get settingsBottomNativeSmallButtonBottomOn =>
      adsEnabled && flag('settings.bottom.native_small_button_bottom');
  bool get settingsBottomNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('settings.bottom.native_advance_button_bottom');

  String get settingsBannerId {
    final v = id('ads_config.settings.banner');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testBanner;
    return splashBannerId;
  }

  String get settingsNativeId {
    final v = id('ads_config.settings.native');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testNative;
    return splashNativeId;
  }

  // Home screen bottom slot.
  bool get homeTopBannerOn => adsEnabled && flag('home.top.banner');
  bool get homeTopNativeSmallInlineOn =>
      adsEnabled && flag('home.top.native_small_inline');
  bool get homeTopNativeSmallButtonBottomOn =>
      adsEnabled && flag('home.top.native_small_button_bottom');
  bool get homeTopNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('home.top.native_advance_button_bottom');

  bool get homeBottomBannerOn => adsEnabled && flag('home.bottom.banner');
  bool get homeBottomNativeSmallInlineOn =>
      adsEnabled && flag('home.bottom.native_small_inline');
  bool get homeBottomNativeSmallButtonBottomOn =>
      adsEnabled && flag('home.bottom.native_small_button_bottom');
  bool get homeBottomNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('home.bottom.native_advance_button_bottom');

  // Home "See All" (VFC browse) bottom slot: separate switches, same IDs as home by default.
  bool get homeSeeAllBottomBannerOn => adsEnabled && flag('home_see_all.bottom.banner');
  bool get homeSeeAllBottomNativeSmallInlineOn =>
      adsEnabled && flag('home_see_all.bottom.native_small_inline');
  bool get homeSeeAllBottomNativeSmallButtonBottomOn =>
      adsEnabled && flag('home_see_all.bottom.native_small_button_bottom');
  bool get homeSeeAllBottomNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('home_see_all.bottom.native_advance_button_bottom');
  bool get homeSeeAllInterstitialOn => adsEnabled && flag('home_see_all.interstitial');

  // Prefer dedicated home IDs if present; fallback to splash (also used by See All bottom slot).
  String get homeBannerId {
    final home = id('ads_config.home.banner');
    if (home.isNotEmpty && !_useTestUnits) return home;
    if (_useTestUnits) return _testBanner;
    return splashBannerId;
  }

  String get homeNativeId {
    final home = id('ads_config.home.native');
    if (home.isNotEmpty && !_useTestUnits) return home;
    if (_useTestUnits) return _testNative;
    return splashNativeId;
  }

  String get homeSeeAllInterstitialId {
    final v = id('ads_config.home.see_all_interstitial');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testInterstitial;
    final home = id('ads_config.home.interstitial');
    if (home.isNotEmpty) return home;
    return splashInterstitialId;
  }

  // Onboarding
  bool get onboardingInterstitialOn => adsEnabled && flag('onboarding.interstitial');
  bool get onboardingNativeFull1On => adsEnabled && flag('onboarding.native_full_1');
  bool get onboardingNativeFull2On => adsEnabled && flag('onboarding.native_full_2');
  bool get onboardingGetStartedOn => flag(
    paramOnboardingGetStartedOnOff,
    defaultValue: _rcBoolParam(paramOnboardingGetStartedOnOff, defaultValue: true),
  );
  String get introLargeNativeBtnColor => _hexColorFromAdsControlOrRc(
    paramIntroLargeNativeBtnColor,
    _defaultIntroLargeNativeBtnColor,
  );
  String get introAdBgColor =>
      _hexColorFromAdsControlOrRc(paramIntroAdBgColor, _defaultIntroAdBgColor);

  bool onboardingSkipInterstitialOnForIndex(int pageIndex) {
    final onboardingKey = onboardingKeyForIndex(pageIndex);
    return adsEnabled && flag('onboarding.$onboardingKey.skip_interstitial');
  }

  // Onboarding per-screen top/bottom slots.
  //
  // Path format:
  // - onboarding.onboarding1.top.banner
  // - onboarding.onboarding2.bottom.native_small_inline
  // - onboarding.onboarding3.bottom.native_advance_button_bottom
  static String onboardingKeyForIndex(int pageIndex) {
    switch (pageIndex) {
      case 0:
        return 'onboarding1';
      case 1:
        return 'onboarding2';
      default:
        return 'onboarding3';
    }
  }

  bool onboardingTopBannerOn(String onboardingKey) =>
      adsEnabled && flag('onboarding.$onboardingKey.top.banner');
  bool onboardingTopNativeSmallInlineOn(String onboardingKey) =>
      adsEnabled && flag('onboarding.$onboardingKey.top.native_small_inline');
  bool onboardingTopNativeSmallButtonBottomOn(String onboardingKey) =>
      adsEnabled &&
      flag('onboarding.$onboardingKey.top.native_small_button_bottom');
  bool onboardingTopNativeAdvancedButtonBottomOn(String onboardingKey) =>
      adsEnabled &&
      flag('onboarding.$onboardingKey.top.native_advance_button_bottom');

  bool onboardingBottomBannerOn(String onboardingKey) =>
      adsEnabled && flag('onboarding.$onboardingKey.bottom.banner');
  bool onboardingBottomNativeSmallInlineOn(String onboardingKey) =>
      adsEnabled && flag('onboarding.$onboardingKey.bottom.native_small_inline');
  bool onboardingBottomNativeSmallButtonBottomOn(String onboardingKey) =>
      adsEnabled &&
      flag('onboarding.$onboardingKey.bottom.native_small_button_bottom');
  bool onboardingBottomNativeAdvancedButtonBottomOn(String onboardingKey) =>
      adsEnabled &&
      flag('onboarding.$onboardingKey.bottom.native_advance_button_bottom');

  String get onboardingBannerId =>
      _idOrTest('ads_config.onboarding.banner', _testBanner);
  String get onboardingNativeId =>
      _idOrTest('ads_config.onboarding.native', _testNative);
  String get onboardingInterstitialId =>
      _idOrTest('ads_config.onboarding.interstitial', _testInterstitial);
  String get onboardingNativeFull1Id =>
      _idOrTest('ads_config.onboarding.native_full_1', _testNative);
  String get onboardingNativeFull2Id =>
      _idOrTest('ads_config.onboarding.native_full_2', _testNative);

  // Rewarded / rewarded interstitial
  bool get rewardedOn =>
      adsEnabled &&
      (flag('watch_rewarded.rewarded') || flag('rewarded.rewarded'));
  bool get rewardedInterstitialOn =>
      adsEnabled &&
      (flag('watch_rewarded.interstitial') || flag('rewarded.interstitial'));
  String get rewardedId {
    final watch = id('watch_rewarded.rewarded');
    if (watch.isNotEmpty && !_useTestUnits) return watch;
    final watchLegacy = id('ads_config.watch_rewarded.rewarded');
    if (watchLegacy.isNotEmpty && !_useTestUnits) return watchLegacy;
    return _idOrTest('ads_config.rewarded.rewarded', _testRewarded);
  }
  String get rewardedInterstitialId {
    final watch = id('watch_rewarded.interstitial');
    if (watch.isNotEmpty && !_useTestUnits) return watch;
    final watchLegacy = id('ads_config.watch_rewarded.interstitial');
    if (watchLegacy.isNotEmpty && !_useTestUnits) return watchLegacy;
    return _idOrTest('ads_config.rewarded.interstitial', _testRewardedInterstitial);
  }

  // Call again rewarded flow (separate remote controls).
  bool get callAgainRewardedOn =>
      adsEnabled &&
      (flag('call_again_rewarded.rewarded') || rewardedOn);
  bool get callAgainRewardedInterstitialOn =>
      adsEnabled &&
      (flag('call_again_rewarded.interstitial') || rewardedInterstitialOn);

  String get callAgainRewardedId {
    final topLevel = id('call_again_rewarded.rewarded');
    if (topLevel.isNotEmpty && !_useTestUnits) return topLevel;
    final nested = id('ads_config.call_again_rewarded.rewarded');
    if (nested.isNotEmpty && !_useTestUnits) return nested;
    return rewardedId;
  }

  String get callAgainRewardedInterstitialId {
    final topLevel = id('call_again_rewarded.interstitial');
    if (topLevel.isNotEmpty && !_useTestUnits) return topLevel;
    final nested = id('ads_config.call_again_rewarded.interstitial');
    if (nested.isNotEmpty && !_useTestUnits) return nested;
    return rewardedInterstitialId;
  }

  // Call ads
  bool get callAcceptInterstitialOn => adsEnabled && flag('call_ads.accept_interstitial');
  bool get callRejectInterstitialOn => adsEnabled && flag('call_ads.reject_interstitial');
  bool get callEndInterstitialOn => adsEnabled && flag('call_ads.end_interstitial');
  bool get callAgainInterstitialOn => adsEnabled && flag('call_ads.again_interstitial');
  bool get callBottomNativeSmallInlineOn =>
      adsEnabled && flag('call_ads.bottom.native_small_inline');
  String get callAcceptInterstitialId =>
      _idOrTest('ads_config.call_ads.accept_interstitial', _testInterstitial);
  String get callRejectInterstitialId {
    final v = id('ads_config.call_ads.reject_interstitial');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testInterstitial;
    return callAcceptInterstitialId;
  }

  String get callEndInterstitialId {
    final v = id('ads_config.call_ads.end_interstitial');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testInterstitial;
    return callAcceptInterstitialId;
  }

  String get callAgainInterstitialId =>
      _idOrTest('ads_config.call_ads.again_interstitial', _testInterstitial);
  String get callNativeId {
    final v = id('ads_config.call_ads.native');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testNative;
    return splashNativeId;
  }

  // Exit flow / exit screen
  bool get homeExitInterstitialOn =>
      adsEnabled &&
      (flag('home_exit_interstitial_onoff') ||
          flag('home_exit.interstitial') ||
          flag('exit.interstitial') ||
          flag('exit.bottom.home_exit_interstitial_onoff'));
  bool get exitTopBannerOn => adsEnabled && flag('exit.top.banner');
  bool get exitTopNativeSmallInlineOn =>
      adsEnabled && flag('exit.top.native_small_inline');
  bool get exitTopNativeSmallButtonBottomOn =>
      adsEnabled && flag('exit.top.native_small_button_bottom');
  bool get exitTopNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('exit.top.native_advance_button_bottom');
  bool get exitBottomBannerOn => adsEnabled && flag('exit.bottom.banner');
  bool get exitBottomNativeSmallInlineOn =>
      adsEnabled && flag('exit.bottom.native_small_inline');
  bool get exitBottomNativeSmallButtonBottomOn =>
      adsEnabled && flag('exit.bottom.native_small_button_bottom');
  bool get exitBottomNativeAdvancedButtonBottomOn =>
      adsEnabled && flag('exit.bottom.native_advance_button_bottom');

  String get homeExitInterstitialId {
    final id1 = id('ads_config.home_exit.interstitial');
    if (id1.isNotEmpty && !_useTestUnits) return id1;
    if (_useTestUnits) return _testInterstitial;
    final id2 = id('ads_config.exit.interstitial');
    if (id2.isNotEmpty) return id2;
    final accept = id('ads_config.call_ads.accept_interstitial');
    if (accept.isNotEmpty) return accept;
    return splashInterstitialId;
  }

  String get exitBannerId {
    final v = id('ads_config.exit.banner');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testBanner;
    return splashBannerId;
  }

  String get exitNativeId {
    final v = id('ads_config.exit.native');
    if (v.isNotEmpty && !_useTestUnits) return v;
    if (_useTestUnits) return _testNative;
    return splashNativeId;
  }

  // Counter
  bool get counterInterstitialOn => adsEnabled && flag('counter.interstitial');
  int get counterTotalQuota {
    final v1 = _intPath('counter.totalCounter', defaultValue: 0);
    if (v1 > 0) return v1;
    final v2 = _intPath('counter.totalcounter', defaultValue: 0);
    if (v2 > 0) return v2;
    final v3 = _intPath('counter.total_counter', defaultValue: 0);
    if (v3 > 0) return v3;
    final v4 = _intPath('counter.quota', defaultValue: 0);
    if (v4 > 0) return v4;
    return 0;
  }

  int get counterWindowClicks {
    final v1 = _intPath('counter.totalClicks', defaultValue: 0);
    if (v1 > 0) return v1;
    final v2 = _intPath('counter.total_clicks', defaultValue: 0);
    if (v2 > 0) return v2;
    final v3 = _intPath('counter.clicks', defaultValue: 0);
    if (v3 > 0) return v3;
    return 0;
  }

  int get counterWindowDurationSeconds {
    final v1 = _intPath('counter.totalDuration', defaultValue: 0);
    if (v1 > 0) return v1;
    final v2 = _intPath('counter.total_duration', defaultValue: 0);
    if (v2 > 0) return v2;
    final v3 = _intPath('counter.duration_sec', defaultValue: 0);
    if (v3 > 0) return v3;
    final v4 = _intPath('counter.duration', defaultValue: 0);
    if (v4 > 0) return v4;
    return 0;
  }

  // Legacy fallback.
  int get counterInterstitialEveryClicks {
    final v = _intPath('counter.every_clicks', defaultValue: 0);
    if (v > 0) return v;
    final v2 = _intPath('counter.count', defaultValue: 0);
    if (v2 > 0) return v2;
    return 0;
  }
  String get counterInterstitialId =>
      _idOrTest('ads_config.counter.interstitial', _testInterstitial);

  // Privacy policy (remote controlled via scalar RC params)
  bool get privacyPolicyOn => flag(
    paramPrivacyPolicyOnOff,
    defaultValue: _rcBoolParam(paramPrivacyPolicyOnOff, defaultValue: false),
  );
  String get privacyPolicyUrl {
    final v = _readPath(_adsControl, paramPrivacyPolicyUrl)?.toString().trim() ?? '';
    if (v.isNotEmpty) return v;
    return _rc.getString(paramPrivacyPolicyUrl).trim();
  }
  bool get shouldShowPrivacyPolicyInSettings =>
      privacyPolicyOn && _isValidWebUrl(privacyPolicyUrl);

  bool _rcBoolParam(String key, {bool defaultValue = false}) {
    final asString = _rc.getString(key).trim().toLowerCase();
    if (asString == '1' ||
        asString == 'true' ||
        asString == 'yes' ||
        asString == 'on') {
      return true;
    }
    if (asString == '0' ||
        asString == 'false' ||
        asString == 'no' ||
        asString == 'off') {
      return false;
    }
    return _rc.getBool(key);
  }

  bool _isValidWebUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    if (!uri.hasScheme) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _hexColorParam(String key, String fallback) {
    final raw = _rc.getString(key).trim();
    if (raw.isEmpty) return fallback;
    final normalized = raw.startsWith('#') ? raw.toUpperCase() : '#${raw.toUpperCase()}';
    final body = normalized.substring(1);
    final validLen = body.length == 6 || body.length == 8;
    if (!validLen) return fallback;
    final isHex = RegExp(r'^[0-9A-F]+$').hasMatch(body);
    return isHex ? normalized : fallback;
  }

  String _hexColorFromAdsControlOrRc(String key, String fallback) {
    final controlValue = _readPath(_adsControl, key)?.toString().trim() ?? '';
    if (controlValue.isNotEmpty) {
      final normalized = controlValue.startsWith('#')
          ? controlValue.toUpperCase()
          : '#${controlValue.toUpperCase()}';
      final body = normalized.substring(1);
      final validLen = body.length == 6 || body.length == 8;
      final isHex = RegExp(r'^[0-9A-F]+$').hasMatch(body);
      if (validLen && isHex) return normalized;
    }
    return _hexColorParam(key, fallback);
  }
}

