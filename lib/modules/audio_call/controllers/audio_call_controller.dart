import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/ads/call_interstitial_preload_service.dart';
import '../../../core/ads/interstitial_click_counter_service.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/incoming_call_feedback.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ad_loading_dialog.dart';

enum AudioCallPhase { incoming, playing, ended }

class AudioCallController extends GetxController {
  final callerName = ''.obs;

  final networkImageUrl = RxnString();
  final localImagePath = RxnString();
  static const String placeholderAsset = 'assets/1.png';

  final phase = AudioCallPhase.incoming.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final acceptInProgress = false.obs;
  final rejectInProgress = false.obs;
  final callAgainInProgress = false.obs;

  String? _audioUrl;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<Duration>? _posSub;

  late final IncomingCallFeedback _incomingFeedback;
  bool _incomingAlertsStarted = false;

  bool _openedWithPersonItem = false;
  String? _customSubtitleFromArgs;
  bool _fullscreenAdInFlight = false;
  late final AdsRemoteConfigService _adsRc;
  late final InterstitialClickCounterService _interstitialCounter;

  /// Incoming row under caller name (localized unless [Get.arguments]['subtitle'] is set).
  String get incomingStatusText {
    if (_customSubtitleFromArgs != null) return _customSubtitleFromArgs!;
    return _openedWithPersonItem
        ? 'audio_call_incoming_calling'.tr
        : 'audio_call_incoming_title'.tr;
  }

  void _beginIncomingAlerts() {
    if (_incomingAlertsStarted) return;
    if (phase.value != AudioCallPhase.incoming) return;
    _incomingAlertsStarted = true;
    unawaited(_incomingFeedback.start());
  }

  @override
  void onInit() {
    super.onInit();
    _adsRc = Get.find<AdsRemoteConfigService>();
    _interstitialCounter = Get.find<InterstitialClickCounterService>();
    _incomingFeedback = IncomingCallFeedback(Get.find<StorageService>());
    final args = Get.arguments as Map<String, dynamic>?;
    final person = args?['person'];
    if (person is PersonItem) {
      _openedWithPersonItem = true;
      _customSubtitleFromArgs = null;
      callerName.value =
          person.firstName.isNotEmpty ? person.firstName : person.name;
      networkImageUrl.value = person.imageUrl;
      _audioUrl = person.audioUrl;
    } else {
      _openedWithPersonItem = false;
      final name = args?['name'] as String?;
      callerName.value =
          (name != null && name.trim().isNotEmpty) ? name.trim() : 'Alisa';
      final sub = args?['subtitle'] as String?;
      _customSubtitleFromArgs =
          (sub != null && sub.trim().isNotEmpty) ? sub.trim() : null;
      final av = args?['avatar'] as String?;
      if (av != null && av.isNotEmpty) {
        if (av.startsWith('http://') || av.startsWith('https://')) {
          networkImageUrl.value = av;
        } else {
          localImagePath.value = av;
        }
      }
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (isClosed) return;
      try {
        Get.find<CallInterstitialPreloadService>().warmForCallFlow();
      } catch (_) {}
      _beginIncomingAlerts();
    });
  }

  Future<void> _showInterstitialAd(String adUnitId) async {
    if (_fullscreenAdInFlight || adUnitId.trim().isEmpty) {
      debugPrint('[Ads][audio_interstitial] skip inFlight=$_fullscreenAdInFlight id=$adUnitId');
      return;
    }
    _fullscreenAdInFlight = true;
    try {
      await Get.find<CallInterstitialPreloadService>().presentCallInterstitial(
        adUnitId,
        logTag: '[Ads][audio_interstitial]',
      );
    } catch (_) {
    } finally {
      debugPrint('[Ads][audio_interstitial] flow complete');
      _fullscreenAdInFlight = false;
    }
  }

  Future<void> _showInterstitialWithLoader(String adUnitId) async {
    await showAdLoadingDialog<void>(
      task: () => _showInterstitialAd(adUnitId),
      title: 'Ad Loading',
      indicatorSize: 72,
    );
  }

  Future<void> _showRewardedAd(String adUnitId) async {
    if (_fullscreenAdInFlight || adUnitId.trim().isEmpty) {
      debugPrint('[Ads][audio_rewarded] skip inFlight=$_fullscreenAdInFlight id=$adUnitId');
      return;
    }
    debugPrint('[Ads][audio_rewarded] load start id=$adUnitId');
    _fullscreenAdInFlight = true;
    try {
      final c = Completer<void>();
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[Ads][audio_rewarded] loaded, showing');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (a) {
                debugPrint('[Ads][audio_rewarded] dismissed');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
              onAdFailedToShowFullScreenContent: (a, _) {
                debugPrint('[Ads][audio_rewarded] failed to show');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
            );
            ad.show(onUserEarnedReward: (_, __) {});
          },
          onAdFailedToLoad: (err) {
            debugPrint('[Ads][audio_rewarded] failed load (${err.code}) ${err.message}');
            if (!c.isCompleted) c.complete();
          },
        ),
      );
      await c.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    } catch (_) {
    } finally {
      debugPrint('[Ads][audio_rewarded] flow complete');
      _fullscreenAdInFlight = false;
    }
  }

  @override
  void onReady() {
    super.onReady();
    _beginIncomingAlerts();
  }

  /// Elapsed time like a phone call: `02:40` (mm:ss, minutes grow past 59 if needed).
  static String formatCallElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${two(s)}';
  }

  Future<void> onAccept() async {
    if (acceptInProgress.value) return;
    acceptInProgress.value = true;
    try {
      final acceptAdId = _interstitialCounter.pickAdIdForClick(
        placement: 'audio_call_accept',
        screenInterstitialEnabled: _adsRc.callAcceptInterstitialOn,
        screenInterstitialId: _adsRc.callAcceptInterstitialId,
      );
      final url = _audioUrl;
      if (url == null || url.isEmpty) {
        Get.snackbar(
          'Audio missing',
          'No audio file for this person in Storage.',
          snackPosition: SnackPosition.BOTTOM,
        );
        phase.value = AudioCallPhase.incoming;
        _incomingAlertsStarted = false;
        await _incomingFeedback.start();
        _incomingAlertsStarted = true;
        return;
      }

      await _incomingFeedback.stop();
      _incomingAlertsStarted = false;

      if (acceptAdId != null && !_fullscreenAdInFlight) {
        await _showInterstitialWithLoader(acceptAdId);
      }

      phase.value = AudioCallPhase.playing;

      await _disposePlayer();
      try {
        final player = AudioPlayer();
        _player = player;
        await player.setUrl(url);

        duration.value = player.duration ?? Duration.zero;
        _durSub = player.durationStream.listen((dur) {
          if (dur != null) duration.value = dur;
        });
        _posSub = player.positionStream.listen((p) => position.value = p);
        _stateSub = player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            _onPlaybackFinished();
          }
        });

        phase.value = AudioCallPhase.playing;
        await player.play();
        try {
          Get.find<CallInterstitialPreloadService>().warmForCallFlow();
        } catch (_) {}
      } catch (e) {
        Get.snackbar(
          'Playback error',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
        await _disposePlayer();
        phase.value = AudioCallPhase.incoming;
        _incomingAlertsStarted = false;
        await _incomingFeedback.start();
        _incomingAlertsStarted = true;
      }
    } finally {
      acceptInProgress.value = false;
    }
  }

  void _onPlaybackFinished() {
    phase.value = AudioCallPhase.ended;
  }

  Future<void> onCallAgain() async {
    if (callAgainInProgress.value) return;
    callAgainInProgress.value = true;
    try {
      final isPremium = Get.isRegistered<SubscriptionService>() &&
          Get.find<SubscriptionService>().isPremium.value;
      if (isPremium) {
        // Premium users skip the rewarded ad + loader entirely.
        await _incomingFeedback.stop();
        await _disposePlayer();
      } else {
        await showAdLoadingDialog<void>(
          task: () async {
            if (_adsRc.rewardedOn) {
              await _showRewardedAd(_adsRc.rewardedId);
            }
            await _incomingFeedback.stop();
            await _disposePlayer();
          },
          title: 'Ad Loading',
          indicatorSize: 72,
        );
      }
      final nav = Get.key.currentState;
      if (nav != null && nav.canPop()) {
        Get.back();
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    } finally {
      callAgainInProgress.value = false;
    }
  }

  /// Android/iOS system back: same as reject/end while ringing or in-call; on ended screen,
  /// exits without the rewarded "Call again" flow.
  Future<void> onNavigateBack() async {
    if (rejectInProgress.value ||
        acceptInProgress.value ||
        callAgainInProgress.value) {
      return;
    }
    final p = phase.value;
    if (p == AudioCallPhase.incoming || p == AudioCallPhase.playing) {
      await onReject();
      return;
    }
    if (p == AudioCallPhase.ended) {
      await _incomingFeedback.stop();
      await _disposePlayer();
      final canPop = Get.key.currentState?.canPop() ?? false;
      if (canPop) {
        Get.back();
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    }
  }

  /// Incoming: close screen. During playback: stop and show Call Again (stay on screen).
  Future<void> onReject() async {
    if (rejectInProgress.value) return;
    rejectInProgress.value = true;
    try {
      if (phase.value == AudioCallPhase.incoming) {
        final rejectAdId = _interstitialCounter.pickAdIdForClick(
          placement: 'audio_call_reject_incoming',
          screenInterstitialEnabled: _adsRc.callRejectInterstitialOn,
          screenInterstitialId: _adsRc.callRejectInterstitialId,
        );
        if (rejectAdId != null) {
          await _showInterstitialWithLoader(rejectAdId);
        }
        await _incomingFeedback.stop();
        await _disposePlayer();
        final canPop = Get.key.currentState?.canPop() ?? false;
        if (canPop) {
          Get.back();
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
        return;
      }
      if (phase.value == AudioCallPhase.playing) {
        // End should feel instant: stop call audio/state before any ad delay.
        await _hangUpDuringCall();
        final endAdId = _interstitialCounter.pickAdIdForClick(
          placement: 'audio_call_end',
          screenInterstitialEnabled: _adsRc.callEndInterstitialOn,
          screenInterstitialId: _adsRc.callEndInterstitialId,
        );
        if (endAdId != null) {
          await _showInterstitialWithLoader(endAdId);
        }
      }
    } finally {
      rejectInProgress.value = false;
    }
  }

  Future<void> _hangUpDuringCall() async {
    try {
      await _player?.pause();
      await _player?.seek(Duration.zero);
    } catch (_) {}
    position.value = Duration.zero;
    phase.value = AudioCallPhase.ended;
  }

  Future<void> _disposePlayer() async {
    await _stateSub?.cancel();
    await _durSub?.cancel();
    await _posSub?.cancel();
    _stateSub = null;
    _durSub = null;
    _posSub = null;
    await _player?.dispose();
    _player = null;
  }

  @override
  void onClose() {
    unawaited(_incomingFeedback.stop());
    unawaited(_disposePlayer());
    super.onClose();
  }
}
