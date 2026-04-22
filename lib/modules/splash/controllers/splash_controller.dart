import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/storage_service.dart';

class SplashController extends GetxController {
  // Progress bar fills over this duration before “Get started” enables.
  static const Duration loadPhaseDuration = Duration(seconds: 10);

  final StorageService _storage = Get.find<StorageService>();
  final AdsRemoteConfigService _adsRc = Get.find<AdsRemoteConfigService>();

  final progress = 0.0.obs;
  final readyForContinue = false.obs;
  final continueInProgress = false.obs;

  Timer? _progressTimer;
  InterstitialAd? _interstitial;
  AppOpenAd? _appOpen;
  bool _navigated = false;

  @override
  void onReady() {
    super.onReady();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (isClosed) return;
      await _maybeShowPermissionRationale();
      if (isClosed) return;
      _startLoadPhase();
    });
  }

  /// Explains notification usage before system permission sheets (first launch).
  Future<void> _maybeShowPermissionRationale() async {}

  void _preloadFullscreenAds() {
    final interstitialId = _adsRc.splashInterstitialId;
    if (interstitialId.isNotEmpty) {
      debugPrint('[Ads][splash_interstitial] preload start id=$interstitialId');
      InterstitialAd.load(
        adUnitId: interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (isClosed) {
              ad.dispose();
              return;
            }
            _interstitial = ad;
            debugPrint('[Ads][splash_interstitial] preload loaded');
          },
          onAdFailedToLoad: (err) {
            if (kDebugMode) {
              debugPrint(
                'SplashController: interstitial failed (${err.code}) ${err.message}',
              );
            }
            _interstitial = null;
          },
        ),
      );
    }

  }

  void _startLoadPhase() {
    progress.value = 0;
    readyForContinue.value = false;
    _preloadFullscreenAds();
    final totalMs = loadPhaseDuration.inMilliseconds;
    const tickMs = 40;
    var elapsed = 0;
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (isClosed) {
        t.cancel();
        return;
      }
      elapsed += tickMs;
      if (elapsed >= totalMs) {
        progress.value = 1.0;
        t.cancel();
        readyForContinue.value = true;
      } else {
        progress.value = (elapsed / totalMs).clamp(0.0, 1.0);
      }
    });
  }

  Future<void> onGetStartedTap() async {
    if (continueInProgress.value || !readyForContinue.value) return;
    continueInProgress.value = true;
    try {
      await _showSplashAdsAndNavigate();
    } finally {
      continueInProgress.value = false;
    }
  }

  /// If the SDK never signals a presentation, don’t block navigation for long.
  static const Duration _splashNoPresentationGrace = Duration(milliseconds: 1600);
  static const Duration _splashShowCallTimeout = Duration(seconds: 3);

  Future<void> _showSplashAdsAndNavigate() async {
    if (_navigated || isClosed) return;

    // Fullscreen priority: App Open (if enabled). If it fails to show, try interstitial
    // even if its switch is OFF (requested fallback behavior). Never show both.
    var appOpenShown = false;
    var appOpenAttempted = false;
    if (_adsRc.splashAppOpenOn) {
      final open = _appOpen ?? await _loadSplashAppOpenRuntime();
      _appOpen = null;
      if (open != null) {
        debugPrint('[Ads][splash_app_open] show start');
        appOpenAttempted = true;
        final c = Completer<void>();
        var presentationConfirmed = false;
        open.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (a) {
            presentationConfirmed = true;
            appOpenShown = true;
            debugPrint('[Ads][splash_app_open] showed');
          },
          onAdDismissedFullScreenContent: (a) {
            debugPrint('[Ads][splash_app_open] dismissed');
            a.dispose();
            if (!c.isCompleted) c.complete();
          },
          onAdFailedToShowFullScreenContent: (a, _) {
            debugPrint('[Ads][splash_app_open] failed to show');
            a.dispose();
            if (!c.isCompleted) c.complete();
          },
        );
        try {
          await open
              .show()
              .timeout(_splashShowCallTimeout, onTimeout: () {});
        } catch (_) {
          try {
            open.dispose();
          } catch (_) {}
          if (!c.isCompleted) c.complete();
        }
        if (!c.isCompleted) {
          Timer? bail;
          bail = Timer(_splashNoPresentationGrace, () {
            if (!presentationConfirmed && !c.isCompleted) {
              debugPrint(
                '[Ads][splash_app_open] no presentation in grace period, navigate',
              );
              try {
                open.dispose();
              } catch (_) {}
              c.complete();
            }
            bail?.cancel();
          });
          try {
            await c.future.timeout(
              const Duration(seconds: 120),
              onTimeout: () {
                if (!c.isCompleted) c.complete();
              },
            );
          } finally {
            bail.cancel();
          }
        }
      }
    }

    if (_navigated || isClosed) return;

    // Show interstitial ONLY if:
    // - app-open is OFF and interstitial switch is ON
    // - OR app-open was attempted but didn't show (fallback; allowed even if interstitial switch is OFF)
    final shouldTryInterstitial = (!appOpenAttempted && _adsRc.splashInterstitialOn) ||
        (appOpenAttempted && !appOpenShown);
    if (shouldTryInterstitial) {
      final ad = _interstitial;
      _interstitial = null;
      if (ad != null) {
        debugPrint('[Ads][splash_interstitial] show start');
        final c = Completer<void>();
        var presentationConfirmed = false;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (a) {
            presentationConfirmed = true;
          },
          onAdDismissedFullScreenContent: (a) {
            debugPrint('[Ads][splash_interstitial] dismissed');
            a.dispose();
            if (!c.isCompleted) c.complete();
          },
          onAdFailedToShowFullScreenContent: (a, _) {
            debugPrint('[Ads][splash_interstitial] failed to show');
            a.dispose();
            if (!c.isCompleted) c.complete();
          },
        );
        try {
          ad.show().catchError((Object _) {
            if (!c.isCompleted) c.complete();
          });
        } catch (_) {
          ad.dispose();
          if (!c.isCompleted) c.complete();
        }
        if (!c.isCompleted) {
          Timer? bail;
          bail = Timer(_splashNoPresentationGrace, () {
            if (!presentationConfirmed && !c.isCompleted) {
              debugPrint(
                '[Ads][splash_interstitial] no presentation in grace period, navigate',
              );
              try {
                ad.dispose();
              } catch (_) {}
              c.complete();
            }
            bail?.cancel();
          });
          try {
            await c.future.timeout(
              const Duration(seconds: 120),
              onTimeout: () {
                if (!c.isCompleted) c.complete();
              },
            );
          } finally {
            bail.cancel();
          }
        }
      }
    }

    _navigateNext();
  }

  Future<AppOpenAd?> _loadSplashAppOpenRuntime() async {
    final appOpenId = _adsRc.splashAppOpenId;
    if (appOpenId.isEmpty) return null;
    debugPrint('[Ads][splash_app_open] runtime load start id=$appOpenId');
    final c = Completer<AppOpenAd?>();
    AppOpenAd.load(
      adUnitId: appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (isClosed) {
            ad.dispose();
            if (!c.isCompleted) c.complete(null);
            return;
          }
          debugPrint('[Ads][splash_app_open] runtime loaded');
          if (!c.isCompleted) c.complete(ad);
        },
        onAdFailedToLoad: (err) {
          if (kDebugMode) {
            debugPrint(
              '[Ads][splash_app_open] runtime load failed (${err.code}) ${err.message}',
            );
          }
          if (!c.isCompleted) c.complete(null);
        },
      ),
    );
    return c.future.timeout(const Duration(seconds: 4), onTimeout: () => null);
  }

  void _navigateNext() {
    if (_navigated || isClosed) return;
    _navigated = true;

    final shouldShowLanguage = _adsRc.languageScreenOn;
    final languageMissing =
        _storage.languageCode == null || _storage.languageCode!.isEmpty;
    if (shouldShowLanguage && languageMissing) {
      Get.offAllNamed(AppRoutes.language);
      return;
    }

    if (!_storage.onboardingComplete) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    Get.offAllNamed(AppRoutes.home);
  }

  @override
  void onClose() {
    _progressTimer?.cancel();
    _interstitial?.dispose();
    _appOpen?.dispose();
    super.onClose();
  }
}
