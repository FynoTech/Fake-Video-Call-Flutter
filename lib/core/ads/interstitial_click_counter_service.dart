import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';

import 'ads_remote_config_service.dart';

/// Global counter-based interstitial scheduler.
///
/// Priority per eligible click:
/// 1) Screen-specific interstitial (if enabled for this click)
/// 2) Counter interstitial (if click threshold hits)
/// 3) No interstitial
class InterstitialClickCounterService extends GetxService {
  late final AdsRemoteConfigService _adsRc;
  int _remainingCounterShots = 0;
  int _lastConfiguredQuota = 0;
  bool _quotaInitialized = false;
  int _windowClicks = 0;
  DateTime? _windowStartedAt;
  bool _pendingCounterDue = false;
  static const Set<String> _counterExcludedPlacements = {
    'subscription',
    'language',
    'splash',
    'onboarding',
  };

  @override
  void onInit() {
    super.onInit();
    _adsRc = Get.find<AdsRemoteConfigService>();
  }

  void _resetWindow(DateTime now) {
    _windowClicks = 0;
    _windowStartedAt = now;
  }

  void _refreshQuotaIfNeeded() {
    final configured = _adsRc.counterTotalQuota;
    if (!_quotaInitialized || configured != _lastConfiguredQuota) {
      _quotaInitialized = true;
      _lastConfiguredQuota = configured;
      _remainingCounterShots = configured;
    }
    if (configured <= 0 || _remainingCounterShots <= 0) {
      _remainingCounterShots = 0;
    }
  }

  String? pickAdIdForClick({
    required String placement,
    required bool screenInterstitialEnabled,
    required String screenInterstitialId,
  }) {
    final placementKey = placement.trim().toLowerCase();
    final screenId = screenInterstitialId.trim();
    final screenCanShow = screenInterstitialEnabled && screenId.isNotEmpty;

    final excluded = _counterExcludedPlacements.any(
      (k) => placementKey.contains(k),
    );
    if (excluded) {
      debugPrint(
        '[Ads][counter] excluded placement=$placement '
        'selected=${screenCanShow ? "screen" : "none"}',
      );
      return screenCanShow ? screenId : null;
    }

    final counterId = _adsRc.counterInterstitialId.trim();
    var clicksThreshold = _adsRc.counterWindowClicks;
    if (clicksThreshold <= 0) {
      clicksThreshold = _adsRc.counterInterstitialEveryClicks;
    }
    final windowSec = _adsRc.counterWindowDurationSeconds;
    _refreshQuotaIfNeeded();
    final now = DateTime.now();
    final counterEnabled = _adsRc.counterInterstitialOn &&
        counterId.isNotEmpty &&
        clicksThreshold > 0 &&
        windowSec > 0 &&
        _remainingCounterShots > 0;

    if (counterEnabled) {
      final started = _windowStartedAt;
      if (started == null ||
          (!_pendingCounterDue &&
              now.difference(started).inSeconds >= windowSec)) {
        _resetWindow(now);
      }
      _windowClicks += 1;
      if (!_pendingCounterDue && _windowClicks > clicksThreshold) {
        _pendingCounterDue = true;
      }
    } else {
      _pendingCounterDue = false;
      _resetWindow(now);
    }

    final counterDue = counterEnabled && _pendingCounterDue;
    debugPrint(
      '[Ads][counter] placement=$placement windowClicks=$_windowClicks '
      'threshold=$clicksThreshold windowSec=$windowSec pendingDue=$_pendingCounterDue '
      'remaining=$_remainingCounterShots counterEnabled=$counterEnabled '
      'counterDue=$counterDue screenCanShow=$screenCanShow',
    );

    if (screenCanShow) {
      if (counterDue) {
        // Screen-specific takes priority. Keep counter pending for next eligible click.
        debugPrint('[Ads][counter] deferred (screen priority) placement=$placement');
      }
      debugPrint('[Ads][counter] selected=screen placement=$placement id=$screenId');
      return screenId;
    }

    if (counterDue) {
      _remainingCounterShots = (_remainingCounterShots - 1).clamp(0, 1 << 30);
      _pendingCounterDue = false;
      _resetWindow(now);
      debugPrint(
        '[Ads][counter] selected=counter placement=$placement id=$counterId '
        'remainingAfter=$_remainingCounterShots',
      );
      return counterId;
    }

    debugPrint('[Ads][counter] selected=none placement=$placement');
    return null;
  }
}
