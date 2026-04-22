import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/theme/app_colors.dart';
import 'ads_remote_config_service.dart';

/// Shows app-open ad whenever app returns from background.
///
/// While ad is being prepared/shown, a full-screen "Welcome Back" overlay
/// is displayed with the same splash icon asset.
class ResumeAppOpenAdService with WidgetsBindingObserver {
  static const String _iconAsset = 'assets/ic_splash.png';
  static const Duration _showCallTimeout = Duration(seconds: 3);
  static const Duration _noPresentationGrace = Duration(milliseconds: 1600);
  static const Duration _adLoadWait = Duration(seconds: 4);
  static const Duration _minBackgroundForResumeAd = Duration(seconds: 2);

  final AdsRemoteConfigService _adsRc;

  ResumeAppOpenAdService(this._adsRc);

  AppOpenAd? _appOpen;
  bool _isLoading = false;
  bool _isShowingFlow = false;
  bool _wasPaused = false;
  bool _suppressNextResume = false;
  int _externalResumeSuppressions = 0;
  DateTime? _pausedAt;
  DateTime? _lastShownAt;

  Future<ResumeAppOpenAdService> init() async {
    WidgetsBinding.instance.addObserver(this);
    return this;
  }

  /// Temporarily suppress resume app-open ads while an external flow
  /// (for example gallery picker) is in progress.
  void beginExternalFlowSuppression() {
    _externalResumeSuppressions += 1;
  }

  void endExternalFlowSuppression() {
    if (_externalResumeSuppressions > 0) {
      _externalResumeSuppressions -= 1;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      _pausedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_onResumed());
    }
  }

  Future<void> _onResumed() async {
    if (_externalResumeSuppressions > 0) {
      _wasPaused = false;
      _pausedAt = null;
      return;
    }
    if (_suppressNextResume) {
      _suppressNextResume = false;
      _wasPaused = false;
      _pausedAt = null;
      return;
    }
    if (!_wasPaused) return;
    final pausedAt = _pausedAt;
    if (pausedAt != null &&
        DateTime.now().difference(pausedAt) < _minBackgroundForResumeAd) {
      _wasPaused = false;
      _pausedAt = null;
      return;
    }
    _wasPaused = false;
    _pausedAt = null;
    if (_isShowingFlow) return;
    if (!_adsRc.appOpenOn) return;

    // Avoid excessive re-shows for quick app-switching.
    final now = DateTime.now();
    final last = _lastShownAt;
    if (last != null && now.difference(last).inSeconds < 20) return;

    _isShowingFlow = true;
    _lastShownAt = now;

    BuildContext? dialogContext;
    try {
      await _showWelcomeOverlay(onBuilt: (ctx) => dialogContext = ctx);
      await _ensureAdLoaded();

      if (_appOpen == null) {
        await _waitForAd();
      }

      final ad = _appOpen;
      _appOpen = null;

      if (ad != null) {
        await _showAd(ad);
      }
    } catch (e) {
      debugPrint('[Ads][resume_app_open] flow error: $e');
    } finally {
      _closeOverlay(dialogContext);
      _isShowingFlow = false;
    }
  }

  Future<void> _ensureAdLoaded() async {
    if (_isLoading || _appOpen != null) return;
    final adUnitId = _adsRc.appOpenId;
    if (adUnitId.isEmpty) return;

    _isLoading = true;
    try {
      await AppOpenAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpen = ad;
            debugPrint('[Ads][resume_app_open] runtime loaded');
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              '[Ads][resume_app_open] runtime load failed (${error.code}) ${error.message}',
            );
            _appOpen = null;
            _isLoading = false;
          },
        ),
      );
    } catch (_) {
      _isLoading = false;
    }
  }

  Future<void> _waitForAd() async {
    final deadline = DateTime.now().add(_adLoadWait);
    while (_appOpen == null && _isLoading && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _showAd(AppOpenAd ad) async {
    _suppressNextResume = true;
    final completer = Completer<void>();
    var presentationConfirmed = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (shownAd) {
        presentationConfirmed = true;
      },
      onAdDismissedFullScreenContent: (dismissedAd) {
        dismissedAd.dispose();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (failedAd, error) {
        debugPrint(
          '[Ads][resume_app_open] failed to show (${error.code}) ${error.message}',
        );
        failedAd.dispose();
        if (!completer.isCompleted) completer.complete();
      },
    );

    try {
      await ad.show().timeout(_showCallTimeout, onTimeout: () {});
    } catch (_) {
      try {
        ad.dispose();
      } catch (_) {}
      if (!completer.isCompleted) completer.complete();
    }

    if (!completer.isCompleted) {
      Timer? bail;
      bail = Timer(_noPresentationGrace, () {
        if (!presentationConfirmed && !completer.isCompleted) {
          try {
            ad.dispose();
          } catch (_) {}
          completer.complete();
        }
        bail?.cancel();
      });
      try {
        await completer.future.timeout(
          const Duration(seconds: 120),
          onTimeout: () {
            if (!completer.isCompleted) completer.complete();
          },
        );
      } finally {
        bail.cancel();
      }
    }
  }

  Future<void> _showWelcomeOverlay({
    required void Function(BuildContext context) onBuilt,
  }) async {
    final context = Get.overlayContext ?? Get.context;
    if (context == null || !context.mounted) return;

    unawaited(
      showGeneralDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        barrierColor: AppColors.transparent,
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, _, __) {
          onBuilt(dialogContext);
          return const _WelcomeBackOverlay();
        },
        transitionBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _closeOverlay(BuildContext? dialogContext) {
    if (dialogContext == null) return;
    final navigator = Navigator.of(dialogContext, rootNavigator: true);
    if (navigator.mounted && navigator.canPop()) {
      navigator.pop();
    }
  }
}

class _WelcomeBackOverlay extends StatelessWidget {
  const _WelcomeBackOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE5E5E5),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                ResumeAppOpenAdService._iconAsset,
                width: 122,
                height: 122,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome Back',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppColors.fontFamily,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
