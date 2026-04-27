import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/app_shimmer.dart';

/// Fullscreen native ad used between onboarding pages.
///
/// Android: prefers [native_full_screen] (`full_screen_native.xml`), then falls back
/// to [native_advance_button_bottom], then the plugin medium template (no custom factory).
///
/// **Important:** If the native side rejects the load request (e.g. missing factory),
/// `NativeAd.load()` throws [PlatformException] *before* [NativeAdListener.onAdFailedToLoad]
/// runs. We catch that and advance the fallback chain.
class OnboardingFullscreenNativeView extends StatefulWidget {
  const OnboardingFullscreenNativeView({super.key, required this.adUnitId});

  final String adUnitId;

  @override
  State<OnboardingFullscreenNativeView> createState() =>
      _OnboardingFullscreenNativeViewState();
}

class _OnboardingFullscreenNativeViewState
    extends State<OnboardingFullscreenNativeView> {
  final AdsRemoteConfigService _adsRc = Get.find<AdsRemoteConfigService>();
  NativeAd? _native;
  bool _ready = false;
  bool _failed = false;
  bool _autoClosing = false;
  int _loadChainToken = 0;

  Timer? _loadTimer;

  static const Duration _loadTimeout = Duration(seconds: 12);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startLoadChain());
    });
  }

  void _armTimeout() {
    _loadTimer?.cancel();
    _loadTimer = Timer(_loadTimeout, () {
      if (!mounted || _ready) return;
      if (kDebugMode) {
        debugPrint('Onboarding fullscreen native: load timeout');
      }
      unawaited(_disposeNativeAsync());
      if (!mounted) return;
      setState(() {
        _ready = false;
        _failed = true;
      });
      _autoCloseSoon();
    });
  }

  void _cancelTimeout() {
    _loadTimer?.cancel();
    _loadTimer = null;
  }

  /// Android [AdWidget] (surface platform view) sometimes composites only after
  /// a later frame or a tiny layout nudge — users see shimmer until they scroll.
  void _kickAdSurfaceLayout(Ad ad) {
    void bump() {
      if (!mounted || !identical(_native, ad)) return;
      setState(() {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => bump());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => bump());
    });
    Future<void>.delayed(const Duration(milliseconds: 64), bump);
  }

  Future<void> _startLoadChain() async {
    final id = widget.adUnitId.trim();
    if (id.isEmpty) {
      if (mounted) setState(() => _failed = true);
      _autoCloseSoon();
      return;
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      if (kDebugMode) {
        debugPrint('Onboarding fullscreen native: Android-only custom layouts; closing.');
      }
      if (mounted) setState(() => _failed = true);
      _autoCloseSoon();
      return;
    }
    final token = ++_loadChainToken;
    await _tryLoadStage(id, 0, token);
  }

  /// 0 = full-screen XML factory, 1 = advanced XML factory, 2 = plugin template (no factory).
  Future<void> _tryLoadStage(String adUnitId, int stage, int token) async {
    if (!mounted || token != _loadChainToken) return;
    await _disposeNativeAsync();
    if (!mounted || token != _loadChainToken) return;
    setState(() {
      _ready = false;
      _failed = false;
    });
    _armTimeout();
    var advanced = false;

    Future<void> advanceToNextOrFail() async {
      if (advanced || !mounted || token != _loadChainToken) return;
      advanced = true;
      _cancelTimeout();
      if (stage < 2) {
        await _tryLoadStage(adUnitId, stage + 1, token);
      } else {
        _finalizeFailed();
      }
    }

    final NativeAd ad;
    if (stage >= 2) {
      ad = NativeAd(
        adUnitId: adUnitId,
        request: const AdRequest(),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.medium,
          mainBackgroundColor: AppColors.white,
        ),
        listener: NativeAdListener(
          onAdLoaded: (loaded) {
            if (!mounted || token != _loadChainToken || advanced) return;
            _cancelTimeout();
            setState(() {
              _ready = true;
              _failed = false;
            });
            _kickAdSurfaceLayout(loaded);
          },
          onAdFailedToLoad: (d, err) {
            if (identical(_native, d)) {
              _native = null;
            }
            unawaited(d.dispose());
            if (!mounted || token != _loadChainToken) return;
            if (kDebugMode) {
              debugPrint('Onboarding fullscreen native template failed: $err');
            }
            unawaited(advanceToNextOrFail());
          },
        ),
      );
    } else {
      final factoryId =
          stage == 0 ? 'native_full_screen' : 'native_advance_button_bottom';
      ad = NativeAd(
        adUnitId: adUnitId,
        factoryId: factoryId,
        request: const AdRequest(),
        customOptions: <String, Object>{
          AdsRemoteConfigService.paramIntroLargeNativeBtnColor:
              _adsRc.introLargeNativeBtnColor,
          AdsRemoteConfigService.paramIntroAdBgColor: _adsRc.introAdBgColor,
        },
        listener: NativeAdListener(
          onAdLoaded: (loaded) {
            if (!mounted || token != _loadChainToken || advanced) return;
            _cancelTimeout();
            setState(() {
              _ready = true;
              _failed = false;
            });
            _kickAdSurfaceLayout(loaded);
          },
          onAdFailedToLoad: (d, err) {
            if (identical(_native, d)) {
              _native = null;
            }
            unawaited(d.dispose());
            if (!mounted || token != _loadChainToken) return;
            if (kDebugMode) {
              debugPrint(
                'Onboarding fullscreen native factory=$factoryId failed: $err',
              );
            }
            unawaited(advanceToNextOrFail());
          },
        ),
      );
    }

    _native = ad;

    try {
      await ad.load();
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Onboarding fullscreen native load() threw at stage $stage: $e');
      }
      await _disposeNativeAsync();
      await advanceToNextOrFail();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Onboarding fullscreen native load() threw (non-platform): $e');
      }
      await _disposeNativeAsync();
      await advanceToNextOrFail();
    }
  }

  void _finalizeFailed() {
    _cancelTimeout();
    if (!mounted) return;
    unawaited(_disposeNativeAsync());
    setState(() {
      _ready = false;
      _failed = true;
    });
    _autoCloseSoon();
  }

  Future<void> _disposeNativeAsync() async {
    final n = _native;
    _native = null;
    _ready = false;
    if (n == null) return;
    try {
      await n.dispose();
    } catch (_) {}
  }

  void _autoCloseSoon() {
    if (_autoClosing) return;
    _autoClosing = true;
    _cancelTimeout();
    unawaited(_disposeNativeAsync());
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      Navigator.of(context).maybePop();
    });
  }

  void _popScreen() {
    _cancelTimeout();
    unawaited(_popScreenAsync());
  }

  Future<void> _popScreenAsync() async {
    await _disposeNativeAsync();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _cancelTimeout();
    final n = _native;
    _native = null;
    if (n != null) {
      unawaited(n.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.black87),
          onPressed: _popScreen,
        ),
        centerTitle: true,
        title: Text(
          'Sponsored',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.textMuted72,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: _buildAdBody(),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: Material(
                  color: AppColors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _popScreen,
                    child: Ink(
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        border: Border.all(
                          color: AppColors.black,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          'Continue',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontFamily: AppColors.fontFamily,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBody() {
    final native = _native;
    if (_ready && native != null) {
      return ClipRect(
        child: AdWidget(
          key: ValueKey<Object>(native.hashCode),
          ad: native,
        ),
      );
    }
    if (_failed) return const SizedBox.shrink();
    return AppShimmer(
      child: Container(
        color: AppColors.shimmerBase,
      ),
    );
  }
}
