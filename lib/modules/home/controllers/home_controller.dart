import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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
  bool _openingExit = false;
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
        title: 'Ad Loading',
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
    if (_openingExit) return;
    _openingExit = true;
    try {
      final adId = _interstitialCounter.pickAdIdForClick(
        placement: 'home_back_exit',
        screenInterstitialEnabled: _adsRc.homeExitInterstitialOn,
        screenInterstitialId: _adsRc.homeExitInterstitialId,
      );
      if (adId != null) {
        await showAdLoadingDialog<void>(
          task: () => _showInterstitialAd(adId),
          title: 'Ad Loading',
        );
      }
      Get.toNamed(AppRoutes.exitApp);
    } finally {
      _openingExit = false;
    }
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
        title: 'Ad Loading',
      );
      Get.to(() => const VfcBrowseView());
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
      final shouldGate = forceWatchAdGate ||
          _callsSinceWatchAdGate >= _watchAdGateThreshold;
      if (shouldGate && !_subscription.isPremium.value) {
        final proceed = await _runWatchAdGateFlow();
        if (!proceed) return;
        _callsSinceWatchAdGate = 0;
      }

      final ctx = Get.context;
      if (ctx != null && ctx.mounted) {
        await _warmCallerImageCache(ctx, person);
      }
      // Keep tap-to-open instant. Media/connectivity validation continues in call screen flow.
      Get.toNamed(AppRoutes.videoCall, arguments: {'person': person});
      _callsSinceWatchAdGate += 1;
    } finally {
      _openingCall = false;
    }
  }

  Future<bool> _runWatchAdGateFlow() async {
    final shouldContinue = await _showWatchAdDialog();
    if (!shouldContinue) return false;
    var adCompleted = false;
    await showAdLoadingDialog<void>(
      task: () async {
        adCompleted = await _showWatchAdRace();
      },
      title: 'Ad Loading',
      subtitle: 'Please watch an ad to continue',
    );
    if (!adCompleted) {
      Get.snackbar(
        'watch_ad_title'.tr,
        'watch_ad_message'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
    return adCompleted;
  }

  Future<bool> _showWatchAdDialog() async {
    final result = await Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Get.back(result: false),
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'watch_ad_title'.tr,
                textAlign: TextAlign.center,
                style: Get.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.gradientAppBarEnd,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'watch_ad_premium_message'.tr,
                textAlign: TextAlign.center,
                style: Get.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textMuted65,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _WatchAdDialogButton(
                      label: 'watch_ad_premium_action'.tr,
                      onTap: () {
                        Get.back(result: false);
                        Get.toNamed(AppRoutes.premium);
                      },
                      customGradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFFFF990B), Color(0xFFFDE277)],
                      ),
                      textColor: AppColors.black,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _WatchAdDialogButton(
                      label: 'watch_ad_action'.tr,
                      onTap: () => Get.back(result: true),
                    ),
                  ),
                ],
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
      ad.show(onUserEarnedReward: (_, __) {
        userEarnedReward = true;
      });
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
      ad.show(onUserEarnedReward: (_, __) {
        userEarnedReward = true;
      });
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
      provider = CachedNetworkImageProvider(raw);
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

class _WatchAdDialogButton extends StatelessWidget {
  const _WatchAdDialogButton({
    required this.label,
    required this.onTap,
    this.useGradient = true,
    this.solidColor,
    this.textColor,
    this.customGradient,
  });

  final String label;
  final VoidCallback onTap;
  final bool useGradient;
  final Color? solidColor;
  final Color? textColor;
  final LinearGradient? customGradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Material(
        color: AppColors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: customGradient ?? (useGradient ? AppColors.appBarGradient : null),
              color: useGradient
                  ? null
                  : (solidColor ?? const Color(0xFFE2E2E2)),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ??
                      (useGradient ? AppColors.white : AppColors.black),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
