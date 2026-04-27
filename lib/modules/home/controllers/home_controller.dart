import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:prank_call_app/app/theme/app_assets.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/ads/interstitial_click_counter_service.dart';
import '../../../core/models/person_item.dart';
import '../../../core/models/vfc_celebrity_catalog.dart';
import '../../../core/services/app_permissions.dart';
import '../../../core/services/call_scheduler_service.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ad_loading_dialog.dart';
import '../views/fake_chat_browse_view.dart';
import '../views/vfc_browse_view.dart';

class HomeController extends GetxController {
  PersonsStorageService get _persons => Get.find<PersonsStorageService>();
  CallSchedulerService get _scheduler => Get.find<CallSchedulerService>();
  StorageService get _storage => Get.find<StorageService>();
  AdsRemoteConfigService get _adsRc => Get.find<AdsRemoteConfigService>();
  InterstitialClickCounterService get _interstitialCounter =>
      Get.find<InterstitialClickCounterService>();
  SubscriptionService get _subscription => Get.find<SubscriptionService>();

  static const String _vfcAssetPath = 'assets/data/vfc_celebrities_v2.json';

  final vfcCatalog = Rxn<VfcCelebrityCatalog>();
  final vfcLoadError = RxnString();
  final vfcSelectedCategoryIndex = 0.obs;
  final bottomNavIndex = 0.obs;
  bool _openingCall = false;
  bool _openingBrowse = false;
  bool _interstitialAdInFlight = false;
  bool _categoryAdCheckInFlight = false;
  int _callsSinceWatchAdGate = 0;
  static const int _watchAdGateThreshold = 2;

  /// First row shows “More” plus up to this many people from Storage.
  static const int _previewLimit = 12;

  List<PersonItem> get previewPersons {
    final list = _persons.persons;
    if (list.length <= _previewLimit) return list.toList();
    return list.take(_previewLimit).toList();
  }

  /// Saved video-call-only persons with media (custom prank callers).
  List<PersonItem> get customVideoPersons {
    return _persons.persons
        .where(
          (p) =>
              p.videoCallOnly &&
              p.videoUrl != null &&
              p.videoUrl!.trim().isNotEmpty,
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map &&
        (args['openSettingsTab'] == true || args['initialTab'] == 2)) {
      bottomNavIndex.value = 2;
    }
  }

  @override
  void onReady() {
    super.onReady();
    _persons.loadPersons();
    unawaited(loadVfcCatalog());
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(requestPermissionsForHomeFlow());
      unawaited(_requestStartupSchedulerPermissionsOnce());
    });
  }

  Future<void> loadVfcCatalog() async {
    vfcLoadError.value = null;
    try {
      final raw = await rootBundle.loadString(_vfcAssetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      vfcCatalog.value = VfcCelebrityCatalog.fromJson(map);
      final n = vfcCatalog.value?.categories.length ?? 0;
      if (n > 0) {
        vfcSelectedCategoryIndex.value = vfcSelectedCategoryIndex.value.clamp(
          0,
          n - 1,
        );
      }
    } catch (e) {
      vfcLoadError.value = e.toString();
      vfcCatalog.value = null;
    }
  }

  void selectVfcCategory(int index) {
    final n = vfcCatalog.value?.categories.length ?? 0;
    if (n <= 0) return;
    vfcSelectedCategoryIndex.value = index.clamp(0, n - 1);
    unawaited(_maybeShowCategoryCounterInterstitial());
  }

  Future<void> _maybeShowCategoryCounterInterstitial() async {
    if (_categoryAdCheckInFlight) return;
    _categoryAdCheckInFlight = true;
    try {
      final adId = _interstitialCounter.pickAdIdForClick(
        placement: 'home_category_tab',
        screenInterstitialEnabled: false,
        screenInterstitialId: '',
      );
      if (adId == null) return;
      await showAdLoadingDialog<void>(
        task: () => _showInterstitialAd(adId),
        title: 'ad_loading_title'.tr,
      );
    } finally {
      _categoryAdCheckInFlight = false;
    }
  }

  void openVfcBrowse() {
    if (_openingBrowse) return;
    _openingBrowse = true;
    unawaited(_openVfcBrowseAsync());
  }

  void openFakeChatBrowse() {
    Get.to(() => const FakeChatBrowseView());
  }

  Future<void> _showInterstitialAd(String adUnitId) async {
    if (_interstitialAdInFlight || adUnitId.trim().isEmpty) {
      debugPrint(
        '[Ads][home_interstitial] skip inFlight=$_interstitialAdInFlight id=$adUnitId',
      );
      return;
    }
    debugPrint('[Ads][home_interstitial] load start id=$adUnitId');
    _interstitialAdInFlight = true;
    try {
      final c = Completer<void>();
      InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[Ads][home_interstitial] loaded, showing');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (a) {
                debugPrint('[Ads][home_interstitial] dismissed');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
              onAdFailedToShowFullScreenContent: (a, _) {
                debugPrint('[Ads][home_interstitial] failed to show');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
            );
            ad.show().catchError((Object _) {
              debugPrint('[Ads][home_interstitial] show threw');
              ad.dispose();
              if (!c.isCompleted) c.complete();
            });
          },
          onAdFailedToLoad: (err) {
            debugPrint(
              '[Ads][home_interstitial] failed load (${err.code}) ${err.message}',
            );
            if (!c.isCompleted) c.complete();
          },
        ),
      );
      await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      debugPrint('[Ads][home_interstitial] flow complete');
    } finally {
      _interstitialAdInFlight = false;
    }
  }

  Future<void> handleHomeBackPressed() async {
    // While opening a call from home, ignore back to avoid accidental exits.
    if (_openingCall) return;
    if (Get.currentRoute == AppRoutes.home) {
      await Get.toNamed(AppRoutes.exitApp);
      return;
    }
    // If any other route somehow delegates back handling here, restore Home.
    if (Get.currentRoute != AppRoutes.home) {
      Get.offAllNamed(AppRoutes.home);
      return;
    }
    bottomNavIndex.value = 0;
  }

  Future<void> _openVfcBrowseAsync() async {
    try {
      final adId = _interstitialCounter.pickAdIdForClick(
        placement: 'home_see_all',
        screenInterstitialEnabled: _adsRc.homeSeeAllInterstitialOn,
        screenInterstitialId: _adsRc.homeSeeAllInterstitialId,
      );
      await showAdLoadingDialog<void>(
        task: () async {
          if (adId != null) {
            await _showInterstitialAd(adId);
          }
        },
        title: 'ad_loading_title'.tr,
      );
      Get.to(() => const VfcBrowseView());
    } finally {
      _openingBrowse = false;
    }
  }

  void openAudioCallBrowse() {
    if (_openingBrowse) return;
    _openingBrowse = true;
    unawaited(_openAudioCallBrowseAsync());
  }

  Future<void> _openAudioCallBrowseAsync() async {
    try {
      final adId = _interstitialCounter.pickAdIdForClick(
        placement: 'home_see_all',
        screenInterstitialEnabled: _adsRc.homeSeeAllInterstitialOn,
        screenInterstitialId: _adsRc.homeSeeAllInterstitialId,
      );
      await showAdLoadingDialog<void>(
        task: () async {
          if (adId != null) {
            await _showInterstitialAd(adId);
          }
        },
        title: 'ad_loading_title'.tr,
      );
      Get.toNamed(
        AppRoutes.personsCatalog,
        arguments: <String, dynamic>{'forVideoCall': false},
      );
    } finally {
      _openingBrowse = false;
    }
  }

  List<PersonItem> customPersonsForCategory(String categoryId) {
    final key = '/${PersonsStorageService.customFolder}/$categoryId/';
    return _persons.persons
        .where(
          (p) =>
              p.videoCallOnly &&
              p.storageFolderPath.contains(key) &&
              p.videoUrl != null &&
              p.videoUrl!.isNotEmpty,
        )
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<void> _requestStartupSchedulerPermissionsOnce() async {
    if (_storage.startupPermissionsRequested) return;
    await _storage.setStartupPermissionsRequested(true);
    try {
      await _scheduler.requestStartupPermissions();
    } catch (_) {}
  }

  Future<void> openVideoCall(
    PersonItem person, {
    bool forceWatchAdGate = false,
  }) async {
    if (_openingCall) return;
    _openingCall = true;
    try {
      final shouldGate =
          forceWatchAdGate || _callsSinceWatchAdGate >= _watchAdGateThreshold;
      if (shouldGate && !_subscription.isPremium.value) {
        final proceed = await _runWatchAdGateFlow();
        if (!proceed) return;
        _callsSinceWatchAdGate = 0;
      }

      final hasVideo = person.videoUrl?.trim().isNotEmpty ?? false;
      final route = hasVideo ? AppRoutes.videoCall : AppRoutes.audioCall;
      Get.toNamed(route, arguments: {'person': person});
      _callsSinceWatchAdGate += 1;
    } finally {
      _openingCall = false;
    }
  }

  Future<bool> _runWatchAdGateFlow() async {
    // TESTING: bypass watch-ad gate and allow direct flow.
    return true;
  }

  Future<bool> _showWatchAdDialog() async {
    final result = await Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Get.back(result: false),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECECEC),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF6B6B6B),
                    ),
                  ),
                ),
              ),

              Image.asset(
                AppAssets.icWatchAD,
                height: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 3),
              Text(
                'watch_ad_title'.tr,
                textAlign: TextAlign.center,
                style: Get.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppColors.black,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              _WatchAdPillButton(
                label: 'watch_ad_action'.tr,
                backgroundColor: AppColors.primaryColor,
                textColor: AppColors.white,
                trailing: _AdPill(),
                onTap: () => Get.back(result: true),
              ),
              const SizedBox(height: 12),
              _WatchAdPillButton(
                label: 'watch_ad_premium_action'.tr,
                backgroundColor: AppColors.premiumColor,
                textColor: AppColors.white,
                onTap: () {
                  Get.back(result: false);
                  Get.toNamed(AppRoutes.premium);
                },
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
    return result ?? false;
  }

  Future<bool> _showWatchAdRace() async {
    final rewardedOn = _adsRc.rewardedOn;
    final rewardedInterstitialOn = _adsRc.rewardedInterstitialOn;
    final rewardedId = _adsRc.rewardedId.trim();
    final rewardedInterstitialId = _adsRc.rewardedInterstitialId.trim();

    final canLoadRewarded = rewardedOn && rewardedId.isNotEmpty;
    final canLoadRewardedInterstitial =
        rewardedInterstitialOn && rewardedInterstitialId.isNotEmpty;
    if (!canLoadRewarded && !canLoadRewardedInterstitial) return false;

    final done = Completer<void>();
    var winnerPicked = false;
    var pendingLoads = 0;
    var userEarnedReward = false;

    void completeFlow() {
      if (!done.isCompleted) done.complete();
    }

    void onLoadFailed() {
      pendingLoads -= 1;
      if (!winnerPicked && pendingLoads <= 0) {
        completeFlow();
      }
    }

    void showRewarded(RewardedAd ad) {
      if (winnerPicked) {
        ad.dispose();
        return;
      }
      winnerPicked = true;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          completeFlow();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          completeFlow();
        },
      );
      ad.show(
        onUserEarnedReward: (_, __) {
          userEarnedReward = true;
        },
      );
    }

    void showRewardedInterstitial(RewardedInterstitialAd ad) {
      if (winnerPicked) {
        ad.dispose();
        return;
      }
      winnerPicked = true;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          completeFlow();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          a.dispose();
          completeFlow();
        },
      );
      ad.show(
        onUserEarnedReward: (_, __) {
          userEarnedReward = true;
        },
      );
    }

    if (canLoadRewarded) {
      pendingLoads += 1;
      RewardedAd.load(
        adUnitId: rewardedId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            pendingLoads -= 1;
            showRewarded(ad);
          },
          onAdFailedToLoad: (_) => onLoadFailed(),
        ),
      );
    }

    if (canLoadRewardedInterstitial) {
      pendingLoads += 1;
      RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            pendingLoads -= 1;
            showRewardedInterstitial(ad);
          },
          onAdFailedToLoad: (_) => onLoadFailed(),
        ),
      );
    }

    await done.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        completeFlow();
      },
    );
    return userEarnedReward;
  }

  Future<void> _warmCallerImageCache(
    BuildContext context,
    PersonItem person,
  ) async {
    final raw = person.imageUrl?.trim();
    if (raw == null || raw.isEmpty) return;

    ImageProvider? provider;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      // Avoid noisy codec exceptions for expired/forbidden remote avatars.
      return;
    } else {
      String path = raw;
      if (raw.startsWith('file://')) {
        try {
          path = Uri.parse(raw).toFilePath();
        } catch (_) {}
      }
      if (!kIsWeb && path.isNotEmpty && File(path).existsSync()) {
        provider = FileImage(File(path));
      }
    }
    if (provider == null) return;

    try {
      await precacheImage(
        provider,
        context,
      ).timeout(const Duration(milliseconds: 450), onTimeout: () {});
    } catch (_) {
      // Best-effort warmup; never block opening the call.
    }
  }

  void openAddVideoPerson() {
    Get.toNamed(AppRoutes.addVideoPerson);
  }

  void selectBottomNav(int index) {
    // Custom Call tab: open the original Add Video Person flow.
    if (index == 1) {
      Get.toNamed(AppRoutes.addVideoPerson);
      return;
    }
    bottomNavIndex.value = index.clamp(0, 2);
  }
}

class _WatchAdPillButton extends StatelessWidget {
  const _WatchAdPillButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(color: backgroundColor),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'AD',
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
