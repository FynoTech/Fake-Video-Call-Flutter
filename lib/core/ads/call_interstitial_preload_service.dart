import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_remote_config_service.dart';

/// Preloads call accept / reject / end interstitials so taps can show ads sooner.
class CallInterstitialPreloadService extends GetxService {
  static const Duration loadTimeout = Duration(seconds: 3);
  static const Duration dismissWaitCap = Duration(minutes: 2);

  AdsRemoteConfigService get _ads => Get.find<AdsRemoteConfigService>();

  final Map<String, InterstitialAd> _ready = {};
  final Map<String, Completer<void>> _inflightLoad = {};

  Iterable<String> _distinctCallAdUnitIds() sync* {
    final seen = <String>{};
    for (final raw in <String?>[
      if (_ads.callAcceptInterstitialOn) _ads.callAcceptInterstitialId,
      if (_ads.callRejectInterstitialOn) _ads.callRejectInterstitialId,
      if (_ads.callEndInterstitialOn) _ads.callEndInterstitialId,
      if (_ads.counterInterstitialOn) _ads.counterInterstitialId,
    ]) {
      final id = (raw ?? '').trim();
      if (id.isEmpty || !seen.add(id)) continue;
      yield id;
    }
  }

  /// Call when entering video / audio call (incoming).
  void warmForCallFlow() {
    for (final id in _distinctCallAdUnitIds()) {
      _startBackgroundLoad(id);
    }
  }

  void _startBackgroundLoad(String adUnitId) {
    final id = adUnitId.trim();
    if (id.isEmpty) return;
    if (_ready.containsKey(id)) return;
    if (_inflightLoad.containsKey(id)) return;

    debugPrint('[Ads][call_preload] start id=$id');
    final done = Completer<void>();
    _inflightLoad[id] = done;

    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _inflightLoad.remove(id);
          _ready[id]?.dispose();
          _ready[id] = ad;
          debugPrint('[Ads][call_preload] ready id=$id');
          if (!done.isCompleted) done.complete();
        },
        onAdFailedToLoad: (err) {
          _inflightLoad.remove(id);
          debugPrint(
            '[Ads][call_preload] fail id=$id (${err.code}) ${err.message}',
          );
          if (!done.isCompleted) done.complete();
        },
      ),
    );
  }

  InterstitialAd? _takeReady(String adUnitId) {
    final id = adUnitId.trim();
    if (id.isEmpty) return null;
    return _ready.remove(id);
  }

  Future<void> _waitForInflightLoad(
    String adUnitId, {
    Duration timeout = loadTimeout,
  }) async {
    final id = adUnitId.trim();
    if (id.isEmpty) return;
    if (_ready.containsKey(id)) return;
    final wait = _inflightLoad[id];
    if (wait != null) {
      await wait.future.timeout(timeout, onTimeout: () {});
    }
  }

  /// One [loadTimeout] budget from entry: if an interstitial is not shown in time,
  /// completes immediately (navigation continues) and any late load is disposed — never shown later.
  ///
  /// If an ad is shown, waits until dismiss (capped by [dismissWaitCap]).
  Future<void> presentCallInterstitial(
    String rawUnitId, {
    required String logTag,
  }) async {
    final id = rawUnitId.trim();
    if (id.isEmpty) {
      debugPrint('$logTag skip empty id');
      return;
    }
    debugPrint('$logTag present start id=$id');

    final sw = Stopwatch()..start();
    const budget = loadTimeout;

    bool canStillShow() => sw.elapsed <= budget;
    Duration remaining() {
      final ms = budget.inMilliseconds - sw.elapsedMilliseconds;
      if (ms <= 0) return Duration.zero;
      return Duration(milliseconds: ms);
    }

    final dismissed = Completer<void>();
    void wire(InterstitialAd ad) {
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          debugPrint('$logTag dismissed');
          a.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
        onAdFailedToShowFullScreenContent: (a, _) {
          debugPrint('$logTag failed to show');
          a.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
      );
      ad.show().catchError((Object _) {
        debugPrint('$logTag show threw');
        ad.dispose();
        if (!dismissed.isCompleted) dismissed.complete();
      });
    }

    InterstitialAd? ad = _takeReady(id);

    if (ad == null && canStillShow() && remaining() > Duration.zero) {
      await _waitForInflightLoad(id, timeout: remaining());
      if (canStillShow()) {
        ad = _takeReady(id);
      }
    }

    if (ad == null && canStillShow() && remaining() > Duration.zero) {
      debugPrint('$logTag fallback load id=$id rem=${remaining().inMilliseconds}ms');
      var abandonFallback = false;
      final loaded = Completer<InterstitialAd?>();
      InterstitialAd.load(
        adUnitId: id,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (a) {
            if (abandonFallback) {
              debugPrint('$logTag abandoned late load dispose id=$id');
              a.dispose();
              return;
            }
            if (!loaded.isCompleted) {
              loaded.complete(a);
            } else {
              debugPrint('$logTag late load dispose id=$id');
              a.dispose();
            }
          },
          onAdFailedToLoad: (err) {
            debugPrint('$logTag load fail (${err.code}) ${err.message}');
            if (!loaded.isCompleted) {
              loaded.complete(null);
            }
          },
        ),
      );

      ad = await loaded.future.timeout(
        remaining(),
        onTimeout: () {
          debugPrint('$logTag load budget exceeded id=$id');
          abandonFallback = true;
          return null;
        },
      );
    }

    if (ad != null && canStillShow()) {
      debugPrint(
        '$logTag showing id=$id elapsed=${sw.elapsedMilliseconds}ms',
      );
      wire(ad);
      await dismissed.future.timeout(dismissWaitCap, onTimeout: () {});
    } else {
      if (ad != null) {
        debugPrint(
          '$logTag discard (over budget or no slot) id=$id elapsed=${sw.elapsedMilliseconds}ms',
        );
        ad.dispose();
      } else {
        debugPrint(
          '$logTag skip show (no ad in budget) id=$id elapsed=${sw.elapsedMilliseconds}ms',
        );
      }
      if (!dismissed.isCompleted) dismissed.complete();
    }

    debugPrint('$logTag present done id=$id');
  }

  @override
  void onClose() {
    for (final ad in _ready.values) {
      ad.dispose();
    }
    _ready.clear();
    _inflightLoad.clear();
    super.onClose();
  }
}
