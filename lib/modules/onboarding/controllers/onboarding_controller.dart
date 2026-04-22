import 'dart:async' show Completer, unawaited, Timer;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../widgets/ad_loading_dialog.dart';
import '../views/onboarding_fullscreen_native_view.dart';

class OnboardingPage {
  const OnboardingPage({
    required this.assetPath,
    required this.titleKey,
    required this.bodyKey,
  });

  final String assetPath;
  final String titleKey;
  final String bodyKey;
}

class OnboardingController extends GetxController {
  final StorageService _storage = Get.find<StorageService>();
  final AdsRemoteConfigService _adsRc = Get.find<AdsRemoteConfigService>();
  final pageController = PageController();
  final currentPage = 0.obs;
  bool _interstitialAdInFlight = false;
  InterstitialAd? _preparedFinishInterstitial;
  bool _finishPreloadAttempted = false;
  Timer? _autoFinishTimer;
  static const Duration _autoFinishDelay = Duration(seconds: 3);

  bool get _fromSettings {
    final args = Get.arguments;
    if (args is Map) {
      return args['fromSettings'] == true;
    }
    return false;
  }

  List<OnboardingPage> get pages => const [
    OnboardingPage(
      assetPath: 'assets/1.png',
      titleKey: 'onboarding_1_title',
      bodyKey: 'onboarding_1_body',
    ),
    OnboardingPage(
      assetPath: 'assets/2.png',
      titleKey: 'onboarding_2_title',
      bodyKey: 'onboarding_2_body',
    ),
    OnboardingPage(
      assetPath: 'assets/3.png',
      titleKey: 'onboarding_3_title',
      bodyKey: 'onboarding_3_body',
    ),
  ];

  bool get showGetStartedButton => _adsRc.onboardingGetStartedOn;

  void onPageChanged(int index) {
    final prev = currentPage.value;
    currentPage.value = index;
    _syncAutoFinishForCurrentState();

    // Forward page change (swipe OR Next): one fullscreen native per transition.
    // Defer past this frame so PageView / navigator are not mid-gesture when pushing.
    if (index > prev && prev >= 0 && prev < pages.length - 1) {
      final leftPage = prev;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_maybeShowFullScreenNative(leftPage));
      });
    }
  }

  Future<void> next() async {
    final idx = currentPage.value;
    if (idx < pages.length - 1) {
      await pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      if (!showGetStartedButton) return;
      await _onGetStartedTap();
    }
  }

  Future<void> onSkipTap() async {
    if (_interstitialAdInFlight) return;
    final pageIndex = currentPage.value.clamp(0, pages.length - 1);
    if (!_adsRc.onboardingSkipInterstitialOnForIndex(pageIndex)) {
      await finish();
      return;
    }
    await _showSkipInterstitialAndFinish();
  }

  @override
  void onInit() {
    super.onInit();
    _syncAutoFinishForCurrentState();
  }

  Future<void> _onGetStartedTap() async {
    final ads = Get.find<AdsRemoteConfigService>();
    if (!ads.onboardingInterstitialOn) {
      await finish();
      return;
    }

    if (_preparedFinishInterstitial != null) {
      await _showPreparedFinishInterstitialAndFinish();
      return;
    }

    if (_finishPreloadAttempted) {
      // Preload already tried and no ad available: proceed without blocking user.
      await finish();
      return;
    }

    await showAdLoadingDialog<void>(
      task: () => _preloadFinishInterstitial(ads.onboardingInterstitialId),
      title: 'Ad Loading',
    );

    // Same tap flow: if ad isn't available after preload attempt, continue navigation.
    if (_preparedFinishInterstitial == null) {
      await finish();
      return;
    }

    await _showPreparedFinishInterstitialAndFinish();
  }

  Future<void> _maybeShowFullScreenNative(int pageIndex) async {
    // Only Android + non-web for now.
    if (!GetPlatform.isAndroid || kIsWeb) return;

    final ads = Get.find<AdsRemoteConfigService>();
    bool enabled = false;
    String adUnitId = '';

    if (pageIndex == 0 && ads.onboardingNativeFull1On) {
      enabled = true;
      adUnitId = ads.onboardingNativeFull1Id;
    } else if (pageIndex == 1 && ads.onboardingNativeFull2On) {
      enabled = true;
      adUnitId = ads.onboardingNativeFull2Id;
    }

    if (!enabled || adUnitId.trim().isEmpty) return;

    // Each visit → new page instance → new NativeAd request.
    await Get.to(
      () => OnboardingFullscreenNativeView(adUnitId: adUnitId),
      fullscreenDialog: true,
    );
  }

  Future<void> finish() async {
    _autoFinishTimer?.cancel();
    await _storage.setOnboardingComplete(true);
    if (_fromSettings) {
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back();
      } else {
        Get.offAllNamed(
          AppRoutes.home,
          arguments: const {'openSettingsTab': true},
        );
      }
      return;
    }
    Get.offAllNamed(AppRoutes.home);
  }

  void _syncAutoFinishForCurrentState() {
    _autoFinishTimer?.cancel();
    final isLastPage = currentPage.value >= pages.length - 1;
    if (!isLastPage || showGetStartedButton) return;
    _autoFinishTimer = Timer(_autoFinishDelay, () {
      if (isClosed) return;
      unawaited(finish());
    });
  }

  Future<void> _preloadFinishInterstitial(String adUnitId) async {
    if (_finishPreloadAttempted || adUnitId.trim().isEmpty) return;
    _finishPreloadAttempted = true;
    final c = Completer<void>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preparedFinishInterstitial = ad;
          if (!c.isCompleted) c.complete();
        },
        onAdFailedToLoad: (_) {
          _preparedFinishInterstitial = null;
          if (!c.isCompleted) c.complete();
        },
      ),
    );
    await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  Future<void> _showPreparedFinishInterstitialAndFinish() async {
    if (_interstitialAdInFlight) return;
    final ad = _preparedFinishInterstitial;
    _preparedFinishInterstitial = null;
    if (ad == null) {
      await finish();
      return;
    }
    _interstitialAdInFlight = true;
    try {
      final c = Completer<void>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!c.isCompleted) c.complete();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          if (!c.isCompleted) c.complete();
        },
      );
      ad.show().catchError((Object _) {
        ad.dispose();
        if (!c.isCompleted) c.complete();
      });
      await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
    } finally {
      _interstitialAdInFlight = false;
    }
    await finish();
  }

  Future<void> _showSkipInterstitialAndFinish() async {
    final adUnitId = _adsRc.splashInterstitialId.trim();
    if (adUnitId.isEmpty) {
      await finish();
      return;
    }
    _interstitialAdInFlight = true;
    try {
      final ad = await _loadInterstitial(adUnitId);
      if (ad == null) {
        await finish();
        return;
      }
      await _showInterstitialAndWait(ad);
    } finally {
      _interstitialAdInFlight = false;
    }
    await finish();
  }

  Future<InterstitialAd?> _loadInterstitial(String adUnitId) async {
    final c = Completer<InterstitialAd?>();
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!c.isCompleted) c.complete(ad);
        },
        onAdFailedToLoad: (_) {
          if (!c.isCompleted) c.complete(null);
        },
      ),
    );
    return c.future.timeout(const Duration(seconds: 6), onTimeout: () => null);
  }

  Future<void> _showInterstitialAndWait(InterstitialAd ad) async {
    final c = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        if (!c.isCompleted) c.complete();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        if (!c.isCompleted) c.complete();
      },
    );
    try {
      ad.show().catchError((Object _) {
        ad.dispose();
        if (!c.isCompleted) c.complete();
      });
    } catch (_) {
      ad.dispose();
      if (!c.isCompleted) c.complete();
    }
    await c.future.timeout(const Duration(seconds: 12), onTimeout: () {
      if (!c.isCompleted) c.complete();
    });
  }

  @override
  void onClose() {
    _autoFinishTimer?.cancel();
    _preparedFinishInterstitial?.dispose();
    _preparedFinishInterstitial = null;
    pageController.dispose();
    super.onClose();
  }
}
