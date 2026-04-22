import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/app_shimmer.dart';
import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  static const _bgAsset = 'assets/splash_bg.png';
  static const _iconAsset = 'assets/ic_splash.png';
  static const _splashSvgAsset = 'assets/splash.svg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _bgAsset,
            fit: BoxFit.cover,
            width: MediaQuery.sizeOf(context).width,
            height: MediaQuery.sizeOf(context).height,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Nudge icon + title down from status bar; most flex keeps ad above button.
              const Spacer(flex: 1),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        _iconAsset,
                        width: 132,
                        height: 132,
                        fit: BoxFit.contain,
                      ),
                      //const SizedBox(height: 12),
                      // SvgPicture.asset(
                      //   _splashSvgAsset,
                      //   height: 34,
                      //   fit: BoxFit.contain,
                      // ),
                      //const SizedBox(height: 20),
                      _TitleRow(title: 'splash_title'.tr),
                      const SizedBox(height: 12),
                      Text(
                        'splash_tagline'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 1),
              const _SplashAdSlot(),
              const SizedBox(height: 10),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Obx(() {
                        if (controller.readyForContinue.value) {
                          final busy = controller.continueInProgress.value;
                          return Opacity(
                            opacity: busy ? 0.58 : 1,
                            child: SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Material(
                                color: AppColors.transparent,
                                borderRadius: BorderRadius.circular(28),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: busy
                                      ? null
                                      : controller.onGetStartedTap,
                                  child: Ink(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.appBarGradient,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'get_started'.tr,
                                        style: TextStyle(
                                          fontFamily: AppColors.fontFamily,
                                          color: AppColors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: controller.progress.value,
                            minHeight: 6,
                            backgroundColor: AppColors.splashProgressTrack,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.gradientAppBarEnd,
                            ),
                          ),
                        );
                      }),
                      Obx(() {
                        final isPremium =
                            Get.isRegistered<SubscriptionService>() &&
                            Get.find<SubscriptionService>().isPremium.value;
                        if (isPremium) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'splash_ads_note'.tr,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: AppColors.textMuted45,
                                  fontSize: 11,
                                ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SplashAdSlot extends StatefulWidget {
  const _SplashAdSlot();

  @override
  State<_SplashAdSlot> createState() => _SplashAdSlotState();
}

enum _BottomBannerState { idle, loading, ready, failed }

class _SplashAdSlotState extends State<_SplashAdSlot> {
  BannerAd? _banner;
  _BottomBannerState _state = _BottomBannerState.idle;
  NativeAd? _native;
  bool _nativeReady = false;
  String? _winner; // 'native' | 'banner'
  bool _anyRequested = false;
  bool _timedOut = false;
  static const Duration _raceTimeout = Duration(seconds: 6);
  String? _nativeFactoryId;

  /// Resolved width for anchored adaptive banner (full-bleed slot).
  AdSize _bannerSlotSize = AdSize.banner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_beginSplashAdRace());
    });
  }

  Future<void> _beginSplashAdRace() async {
    final rc = Get.find<AdsRemoteConfigService>();

    // Race mode: if multiple are ON, show whichever loads first.
    // Native (splash) — start immediately (no wait on adaptive banner size).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final nativeUnitId = rc.splashNativeId;
      final factoryId = _pickNativeFactoryId(rc);
      if (nativeUnitId.isNotEmpty && factoryId != null) {
        _anyRequested = true;
        _nativeFactoryId = factoryId;
        // Failsafe: don't show shimmer forever if native never loads.
        Future<void>.delayed(_raceTimeout, () {
          if (!mounted) return;
          if (_winner != null) return;
          _timedOut = true;
          if (kDebugMode) {
            debugPrint('Splash native ad timeout ($factoryId)');
          }
          // If banner exists, let it win; else hide the ad slot.
          if (_banner != null) {
            _winner = 'banner';
            _disposeNative();
            setState(() {});
          } else {
            _disposeNative();
            setState(() {});
          }
        });
        final ad = NativeAd(
          adUnitId: nativeUnitId,
          factoryId: factoryId,
          request: const AdRequest(),
          listener: NativeAdListener(
            onAdLoaded: (_) {
              if (!mounted) return;
              if (_winner == null) {
                _winner = 'native';
                _disposeBanner();
              }
              setState(() => _nativeReady = true);
            },
            onAdFailedToLoad: (ad, err) {
              if (kDebugMode) {
                debugPrint(
                  'Splash native failed (${err.code}) ${err.message} [$factoryId]',
                );
              }
              ad.dispose();
              if (!mounted) return;
              setState(() {
                _native = null;
                _nativeReady = false;
                if (_winner == null) {
                  // If native failed and banner didn't win, we may still be waiting for banner.
                  _finalizeIfNothingLeft();
                }
              });
            },
          ),
        );
        _native = ad;
        ad.load();
      }
    }

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      final w = MediaQuery.sizeOf(context).width.truncate();
      final adaptive =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(w);
      if (adaptive != null && mounted) {
        setState(() => _bannerSlotSize = adaptive);
      }
    }

    if (!mounted) return;

    // Banner (splash bottom) — anchored adaptive so the strip spans screen width.
    if (!rc.splashBannerOn) {
      if (!_anyRequested) {
        setState(() => _state = _BottomBannerState.failed);
      }
      return;
    }
    final unitId = rc.splashBannerId;
    if (unitId.isEmpty) {
      _finalizeIfNothingLeft();
      return;
    }
    _anyRequested = true;
    setState(() => _state = _BottomBannerState.loading);
    final ad = BannerAd(
      adUnitId: unitId,
      size: _bannerSlotSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          if (_winner == null) {
            _winner = 'banner';
            _disposeNative();
          }
          setState(() => _state = _BottomBannerState.ready);
        },
        onAdFailedToLoad: (ad, err) {
          if (kDebugMode) {
            debugPrint('Splash banner failed (${err.code}) ${err.message}');
          }
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _state = _BottomBannerState.failed;
            if (_winner == null) {
              // If banner failed and native didn't win, we may still be waiting for native.
              _finalizeIfNothingLeft();
            }
          });
        },
      ),
    );
    _banner = ad;
    ad.load();
  }

  @override
  void dispose() {
    _disposeBanner();
    _disposeNative();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasBanner = _banner != null && _state != _BottomBannerState.failed;
    final hasNative = _native != null;
    if (!hasBanner && !hasNative) return const SizedBox.shrink();

    final native = _native;
    final nativeBoxH = _nativeHeightForFactory(_nativeFactoryId);
    final slotH = _splashAdSlotHeight(nativeBoxH);

    // Winner-only rendering — slot height matches shimmer (banner vs native).
    if (_winner == 'native' && native != null) {
      return SizedBox(
        height: slotH,
        width: double.infinity,
        child: ClipRect(
          child: _nativeReady
              ? AdWidget(ad: native)
              : ShimmerAdLayout(
                  height: nativeBoxH,
                  nativeFactoryId: _nativeFactoryId,
                ),
        ),
      );
    }

    if (_winner == 'banner' && hasBanner) {
      if (_state == _BottomBannerState.loading) {
        return SizedBox(
          height: slotH,
          width: double.infinity,
          child: _splashRaceShimmer(nativeBoxH),
        );
      }
      final ad = _banner;
      if (_state == _BottomBannerState.ready && ad != null) {
        return SizedBox(
          width: double.infinity,
          height: slotH,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    // No winner yet: show shimmer placeholder while race is ongoing.
    if (_timedOut) return const SizedBox.shrink();
    return SizedBox(
      height: slotH,
      width: double.infinity,
      child: _splashRaceShimmer(nativeBoxH),
    );
  }

  /// Splash requested a native template (Android) — reserve its height even if banner wins.
  bool get _nativeWanted => _nativeFactoryId != null;

  double _splashAdSlotHeight(double nativeBoxH) {
    if (_nativeWanted) return nativeBoxH;
    return _bannerSlotSize.height.toDouble();
  }

  /// While racing: native-style card shimmer if native is in play; else banner-sized strip.
  Widget _splashRaceShimmer(double nativeBoxH) {
    if (_nativeWanted) {
      return ShimmerAdLayout(
        height: nativeBoxH,
        nativeFactoryId: _nativeFactoryId,
      );
    }
    return _SplashBannerShimmer(height: _bannerSlotSize.height.toDouble());
  }

  String? _pickNativeFactoryId(AdsRemoteConfigService rc) {
    // Priority order (first ON wins). You can change without code by toggles.
    if (rc.splashNativeAdvancedButtonBottomOn) {
      return 'native_advance_button_bottom';
    }
    if (rc.splashNativeSmallButtonBottomOn) {
      return 'native_small_button_bottom';
    }
    if (rc.splashNativeSmallInlineOn) {
      return 'native_small_inline';
    }
    return null;
  }

  void _disposeBanner() {
    final b = _banner;
    _banner = null;
    try {
      b?.dispose();
    } catch (_) {}
  }

  void _disposeNative() {
    final n = _native;
    _native = null;
    try {
      n?.dispose();
    } catch (_) {}
    _nativeReady = false;
  }

  void _finalizeIfNothingLeft() {
    if (_winner != null) return;
    final nothingNative = _native == null;
    final nothingBanner =
        _banner == null || _state == _BottomBannerState.failed;
    if (nothingNative && nothingBanner && mounted) {
      setState(() {
        // No ads available.
      });
    }
  }

  double _nativeHeightForFactory(String? factoryId) {
    // Needs to be tall enough so CTA isn't clipped (esp. advanced template).
    switch (factoryId) {
      case 'native_advance_button_bottom':
        return 260;
      case 'native_small_button_bottom':
        return 190;
      case 'native_small_inline':
      default:
        return 170;
    }
  }
}

/// Full-width shimmer while the anchored adaptive banner loads.
class _SplashBannerShimmer extends StatelessWidget {
  const _SplashBannerShimmer({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: Alignment.topCenter,
      child: AppShimmer(
        child: Container(
          width: w,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.gradientAppBarEnd.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    const fontSize = 26.0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('😎', style: TextStyle(fontSize: fontSize * 0.85)),
        const SizedBox(width: 10),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _OutlinedHeadline(text: title, fontSize: fontSize),
          ),
        ),
        const SizedBox(width: 10),
        const Text('😆', style: TextStyle(fontSize: fontSize * 0.85)),
      ],
    );
  }
}

class _OutlinedHeadline extends StatelessWidget {
  const _OutlinedHeadline({required this.text, required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = AppColors.white,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.gradientAppBarEnd,
            shadows: const [
              Shadow(
                offset: Offset(0, 2),
                blurRadius: 5,
                color: AppColors.splashTitleShadow,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
