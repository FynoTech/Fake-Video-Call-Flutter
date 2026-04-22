import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/ads/call_interstitial_preload_service.dart';
import '../../../core/ads/interstitial_click_counter_service.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/incoming_call_feedback.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ad_loading_dialog.dart';

enum VideoCallPhase { incoming, playing, ended }

/// Fake video call: incoming alerts → [VideoPlayer] (HTTPS or local file) + optional [Camera] PiP.
///
/// Tuned for remote URLs and device-stored videos, `mixWithOthers`, and audio session before play.
class VideoCallController extends GetxController {
  final callerName = ''.obs;

  final networkImageUrl = RxnString();
  final localImagePath = RxnString();
  static const String placeholderAsset = 'assets/1.png';

  final phase = VideoCallPhase.incoming.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;

  final videoReady = false.obs;
  final cameraReady = false.obs;
  final acceptInProgress = false.obs;
  /// When false, PiP shows the caller’s photo instead of hiding the tile.
  final pipLiveCameraOn = true.obs;
  final micMuted = false.obs;
  /// Loudspeaker-style routing + full volume vs quieter.
  final speakerLoud = true.obs;
  final rejectInProgress = false.obs;
  final callAgainInProgress = false.obs;

  String? _videoUrl;
  VideoPlayerController? _videoPlayer;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;
  bool _videoErrorReported = false;
  bool _autoAcceptOnOpen = false;
  bool _fullscreenAdInFlight = false;
  bool _preparingPlayback = false;
  VideoPlayerController? _preparedVideoPlayer;
  Uri? _preparedNetworkUri;
  File? _preparedLocalFile;
  late final AdsRemoteConfigService _adsRc;
  late final InterstitialClickCounterService _interstitialCounter;

  late final IncomingCallFeedback _incomingFeedback;
  bool _incomingAlertsStarted = false;

  VideoPlayerController? get videoPlayer => _videoPlayer;
  CameraController? get cameraController => _cameraController;

  void _beginIncomingAlerts() {
    if (_incomingAlertsStarted) return;
    if (phase.value != VideoCallPhase.incoming) return;
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
    _autoAcceptOnOpen = args?['autoAccept'] == true;
    final person = args?['person'];
    if (person is PersonItem) {
      callerName.value =
          person.firstName.isNotEmpty ? person.firstName : person.name;
      _applyCallerImageUrl(person.imageUrl);
      _videoUrl = person.videoUrl;
    } else {
      final name = args?['name'] as String?;
      callerName.value =
          (name != null && name.trim().isNotEmpty) ? name.trim() : 'Alisa';
      final av = args?['avatar'] as String?;
      if (av != null && av.isNotEmpty) {
        _applyCallerImageUrl(av);
      }
      _videoUrl = args?['videoUrl'] as String?;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (isClosed) return;
      try {
        Get.find<CallInterstitialPreloadService>().warmForCallFlow();
      } catch (_) {}
      if (_autoAcceptOnOpen) {
        // Notification / CallKit accept: show active-call UI (“Connecting…”) immediately,
        // then warm video before running the same accept path as the in-call button.
        phase.value = VideoCallPhase.playing;
        await _preparePlaybackIfPossible();
        if (isClosed) return;
        await onAccept();
        return;
      }
      unawaited(_preparePlaybackIfPossible());
      _beginIncomingAlerts();
    });
  }

  Future<void> _showInterstitialAd(String adUnitId) async {
    if (_fullscreenAdInFlight || adUnitId.trim().isEmpty) {
      debugPrint('[Ads][video_interstitial] skip inFlight=$_fullscreenAdInFlight id=$adUnitId');
      return;
    }
    _fullscreenAdInFlight = true;
    try {
      await Get.find<CallInterstitialPreloadService>().presentCallInterstitial(
        adUnitId,
        logTag: '[Ads][video_interstitial]',
      );
    } catch (_) {
    } finally {
      debugPrint('[Ads][video_interstitial] flow complete');
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
      debugPrint('[Ads][video_rewarded] skip inFlight=$_fullscreenAdInFlight id=$adUnitId');
      return;
    }
    debugPrint('[Ads][video_rewarded] load start id=$adUnitId');
    _fullscreenAdInFlight = true;
    try {
      final c = Completer<void>();
      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('[Ads][video_rewarded] loaded, showing');
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (a) {
                debugPrint('[Ads][video_rewarded] dismissed');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
              onAdFailedToShowFullScreenContent: (a, _) {
                debugPrint('[Ads][video_rewarded] failed to show');
                a.dispose();
                if (!c.isCompleted) c.complete();
              },
            );
            ad.show(onUserEarnedReward: (_, __) {});
          },
          onAdFailedToLoad: (err) {
            debugPrint('[Ads][video_rewarded] failed load (${err.code}) ${err.message}');
            if (!c.isCompleted) c.complete();
          },
        ),
      );
      await c.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    } catch (_) {
    } finally {
      debugPrint('[Ads][video_rewarded] flow complete');
      _fullscreenAdInFlight = false;
    }
  }

  Future<void> _showRewardedRace({
    required bool rewardedOn,
    required String rewardedId,
    required bool rewardedInterstitialOn,
    required String rewardedInterstitialId,
    required String logTag,
  }) async {
    final canLoadRewarded = rewardedOn && rewardedId.trim().isNotEmpty;
    final canLoadRewardedInterstitial =
        rewardedInterstitialOn && rewardedInterstitialId.trim().isNotEmpty;
    if (!canLoadRewarded && !canLoadRewardedInterstitial) return;
    if (_fullscreenAdInFlight) {
      debugPrint('$logTag skip inFlight=true');
      return;
    }

    _fullscreenAdInFlight = true;
    final done = Completer<void>();
    var winnerPicked = false;
    var pendingLoads = 0;

    void completeFlow() {
      if (!done.isCompleted) done.complete();
    }

    void onLoadFailed(String type) {
      debugPrint('$logTag load failed type=$type');
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
      debugPrint('$logTag winner=rewarded');
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
      ad.show(onUserEarnedReward: (_, __) {});
    }

    void showRewardedInterstitial(RewardedInterstitialAd ad) {
      if (winnerPicked) {
        ad.dispose();
        return;
      }
      winnerPicked = true;
      debugPrint('$logTag winner=rewarded_interstitial');
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
      ad.show(onUserEarnedReward: (_, __) {});
    }

    if (canLoadRewarded) {
      pendingLoads += 1;
      RewardedAd.load(
        adUnitId: rewardedId.trim(),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            pendingLoads -= 1;
            showRewarded(ad);
          },
          onAdFailedToLoad: (_) => onLoadFailed('rewarded'),
        ),
      );
    }

    if (canLoadRewardedInterstitial) {
      pendingLoads += 1;
      RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialId.trim(),
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            pendingLoads -= 1;
            showRewardedInterstitial(ad);
          },
          onAdFailedToLoad: (_) => onLoadFailed('rewarded_interstitial'),
        ),
      );
    }

    try {
      await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    } finally {
      _fullscreenAdInFlight = false;
      debugPrint('$logTag flow complete');
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (_autoAcceptOnOpen) return;
    _beginIncomingAlerts();
  }

  static String formatCallElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${two(s)}';
  }

  void _onVideoTick() {
    final c = _videoPlayer;
    if (c == null) return;
    final v = c.value;

    if (v.hasError) {
      if (phase.value == VideoCallPhase.playing && !_videoErrorReported) {
        _videoErrorReported = true;
        Get.snackbar(
          'Video error',
          v.errorDescription ?? 'Playback failed',
          snackPosition: SnackPosition.BOTTOM,
        );
        unawaited(_hangUpDuringCall());
      }
      return;
    }

    if (!v.isInitialized) return;

    position.value = v.position;
    duration.value = v.duration;

    if (phase.value != VideoCallPhase.playing) return;
    if (v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 200)) {
      phase.value = VideoCallPhase.ended;
    }
  }

  void _applyCallerImageUrl(String? raw) {
    networkImageUrl.value = null;
    localImagePath.value = null;
    final img = raw?.trim();
    if (img == null || img.isEmpty) return;
    if (img.startsWith('http://') || img.startsWith('https://')) {
      networkImageUrl.value = img;
      return;
    }
    if (kIsWeb) return;
    if (img.startsWith('file://')) {
      try {
        localImagePath.value = Uri.parse(img).toFilePath();
      } catch (_) {}
      return;
    }
    if (!img.contains('://')) {
      localImagePath.value = img;
    }
  }

  Uri? _parseNetworkVideoUri(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  Future<File?> _localVideoFileIfAny(String? raw) async {
    if (kIsWeb || raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'file') {
      final f = File.fromUri(uri);
      if (await f.exists()) return f;
      return null;
    }
    if (!trimmed.contains('://')) {
      final f = File(trimmed);
      if (await f.exists()) return f;
    }
    return null;
  }

  Future<void> _preparePlaybackIfPossible() async {
    if (_preparingPlayback || _preparedVideoPlayer != null || isClosed) return;
    _preparingPlayback = true;
    try {
      final networkUri = _parseNetworkVideoUri(_videoUrl ?? '');
      final localFile =
          networkUri == null ? await _localVideoFileIfAny(_videoUrl) : null;
      if (networkUri == null && localFile == null) return;

      final VideoPlayerController vp;
      if (networkUri != null) {
        vp = VideoPlayerController.networkUrl(
          networkUri,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      } else {
        vp = VideoPlayerController.file(
          localFile!,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
      }

      await vp.initialize();
      if (!vp.value.isInitialized || vp.value.hasError || isClosed) {
        await vp.dispose();
        return;
      }
      _preparedVideoPlayer = vp;
      _preparedNetworkUri = networkUri;
      _preparedLocalFile = localFile;
      debugPrint('[Call][video] prewarm ready');
    } catch (_) {
      final p = _preparedVideoPlayer;
      _preparedVideoPlayer = null;
      _preparedNetworkUri = null;
      _preparedLocalFile = null;
      try {
        await p?.dispose();
      } catch (_) {}
    } finally {
      _preparingPlayback = false;
    }
  }

  Future<void> onAccept() async {
    if (acceptInProgress.value) return;
    acceptInProgress.value = true;
    try {
      final acceptAdId = _interstitialCounter.pickAdIdForClick(
        placement: 'video_call_accept',
        screenInterstitialEnabled: _adsRc.callAcceptInterstitialOn,
        screenInterstitialId: _adsRc.callAcceptInterstitialId,
      );

      final networkUri =
          _preparedNetworkUri ?? _parseNetworkVideoUri(_videoUrl ?? '');
      final localFile = networkUri == null
          ? (_preparedLocalFile ?? await _localVideoFileIfAny(_videoUrl))
          : null;

      if (networkUri == null && localFile == null) {
        Get.snackbar(
          'Video missing',
          'No playable video for this caller. Pick a video when adding, or use an https:// link.',
          snackPosition: SnackPosition.BOTTOM,
        );
        if (_autoAcceptOnOpen) {
          Get.offAllNamed(AppRoutes.home);
        } else {
          phase.value = VideoCallPhase.incoming;
          _beginIncomingAlerts();
        }
        return;
      }

      await _incomingFeedback.stop();
      _incomingAlertsStarted = false;

      if (acceptAdId != null && !_fullscreenAdInFlight) {
        await _showInterstitialWithLoader(acceptAdId);
      }

      phase.value = VideoCallPhase.playing;

      if (networkUri != null) {
        debugPrint('Video call URL: $networkUri');
      } else {
        debugPrint('Video call file: ${localFile!.path}');
      }

      await _disposeVideo();
      _videoErrorReported = false;

      // Active-call UI while `initialize()` runs (phase already playing).
      try {
        // Session before player so iOS/Android route mix correctly with camera preview.
        await _configurePlaybackAudioSession();

        final VideoPlayerController vp = _preparedVideoPlayer ??
            (networkUri != null
                ? VideoPlayerController.networkUrl(
                    networkUri,
                    videoPlayerOptions: VideoPlayerOptions(
                      mixWithOthers: true,
                      allowBackgroundPlayback: false,
                    ),
                  )
                : VideoPlayerController.file(
                    localFile!,
                    videoPlayerOptions: VideoPlayerOptions(
                      mixWithOthers: true,
                      allowBackgroundPlayback: false,
                    ),
                  ));
        _preparedVideoPlayer = null;
        _preparedNetworkUri = null;
        _preparedLocalFile = null;
        _videoPlayer = vp;
        vp.addListener(_onVideoTick);

        if (!vp.value.isInitialized) {
          await vp.initialize();
        }

        if (phase.value != VideoCallPhase.playing) {
          vp.removeListener(_onVideoTick);
          await vp.dispose();
          _videoPlayer = null;
          return;
        }

        if (!vp.value.isInitialized || vp.value.hasError) {
          throw Exception(
            vp.value.errorDescription ?? 'Could not open video stream',
          );
        }

        videoReady.value = true;
        duration.value = vp.value.duration;

        await vp.setVolume(speakerLoud.value ? 1.0 : 0.38);
        await vp.play();
        await _applySpeakerAudio();

        if (!kIsWeb) {
          unawaited(_initCamera());
        }
        try {
          Get.find<CallInterstitialPreloadService>().warmForCallFlow();
        } catch (_) {}
      } catch (e, st) {
        debugPrint('VideoCall onAccept: $e\n$st');
        Get.snackbar(
          'Playback error',
          e.toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
        await _disposeVideo();
        videoReady.value = false;
        if (_autoAcceptOnOpen) {
          // Notification accept should not bounce back to incoming ringing UI.
          phase.value = VideoCallPhase.ended;
          return;
        }
        phase.value = VideoCallPhase.incoming;
        _incomingAlertsStarted = false;
        await _incomingFeedback.start();
        _incomingAlertsStarted = true;
      }
    } finally {
      acceptInProgress.value = false;
    }
  }

  Future<void> _configurePlaybackAudioSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      final iosOptions = speakerLoud.value
          ? AVAudioSessionCategoryOptions.defaultToSpeaker |
              AVAudioSessionCategoryOptions.mixWithOthers
          : AVAudioSessionCategoryOptions.mixWithOthers;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.moviePlayback,
          avAudioSessionCategoryOptions: iosOptions,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.movie,
            usage: speakerLoud.value
                ? AndroidAudioUsage.media
                : AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        ),
      );
      await session.setActive(true);
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    if (kIsWeb) return;
    try {
      debugPrint('[Call][video_camera] init start');
      final cam = await Permission.camera.request();
      if (!cam.isGranted) {
        cameraReady.value = false;
        debugPrint('[Call][video_camera] permission denied status=$cam');
        if (cam.isPermanentlyDenied) {
          Get.snackbar(
            'Camera permission required',
            'Enable camera permission from app settings.',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('[Call][video_camera] no cameras available');
        return;
      }

      _cameraIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_cameraIndex < 0) _cameraIndex = 0;

      await _openCameraAt(_cameraIndex);
    } catch (e, st) {
      debugPrint('[Call][video_camera] init failed: $e\n$st');
      cameraReady.value = false;
    }
  }

  Future<void> _openCameraAt(int index) async {
    if (kIsWeb || _cameras.isEmpty) return;
    final i = index.clamp(0, _cameras.length - 1);
    final previous = _cameraController;
    _cameraController = null;
    cameraReady.value = false;
    if (previous != null) {
      await previous.dispose();
    }

    // Try preferred config first, then retry with a simpler config for picky devices.
    CameraController? next;
    try {
      next = CameraController(
        _cameras[i],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await next.initialize();
      _cameraController = next;
      _cameraIndex = i;
      cameraReady.value = true;
      debugPrint('[Call][video_camera] opened preset=medium format=yuv420 index=$i');
      return;
    } catch (e1) {
      debugPrint('[Call][video_camera] open primary failed: $e1');
      try {
        await next?.dispose();
      } catch (_) {}
    }

    try {
      next = CameraController(
        _cameras[i],
        ResolutionPreset.low,
        enableAudio: false,
      );
      await next.initialize();
      _cameraController = next;
      _cameraIndex = i;
      cameraReady.value = true;
      debugPrint('[Call][video_camera] opened fallback preset=low index=$i');
    } catch (e2, st2) {
      debugPrint('[Call][video_camera] open fallback failed: $e2\n$st2');
      try {
        await next?.dispose();
      } catch (_) {}
      cameraReady.value = false;
    }
  }

  Future<void> switchCamera() async {
    if (kIsWeb || _cameras.length < 2) return;
    final next = (_cameraIndex + 1) % _cameras.length;
    try {
      await _openCameraAt(next);
    } catch (_) {}
  }

  void togglePipLiveCamera() {
    pipLiveCameraOn.toggle();
  }

  void toggleMicMuted() {
    micMuted.toggle();
  }

  Future<void> toggleSpeaker() async {
    speakerLoud.toggle();
    await _applySpeakerAudio();
  }

  Future<void> _applySpeakerAudio() async {
    final vp = _videoPlayer;
    if (vp != null) {
      try {
        await vp.setVolume(speakerLoud.value ? 1.0 : 0.38);
      } catch (_) {}
    }
    await _configurePlaybackAudioSession();
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
        await _disposeAll();
      } else {
        await showAdLoadingDialog<void>(
          task: () async {
            await _showRewardedRace(
              rewardedOn: _adsRc.callAgainRewardedOn,
              rewardedId: _adsRc.callAgainRewardedId,
              rewardedInterstitialOn: _adsRc.callAgainRewardedInterstitialOn,
              rewardedInterstitialId: _adsRc.callAgainRewardedInterstitialId,
              logTag: '[Ads][video_call_again_rewarded]',
            );
            await _incomingFeedback.stop();
            await _disposeAll();
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
    if (p == VideoCallPhase.incoming || p == VideoCallPhase.playing) {
      await onReject();
      return;
    }
    if (p == VideoCallPhase.ended) {
      await _incomingFeedback.stop();
      await _disposeAll();
      final canPop = Get.key.currentState?.canPop() ?? false;
      if (canPop) {
        Get.back();
      } else {
        Get.offAllNamed(AppRoutes.home);
      }
    }
  }

  Future<void> onReject() async {
    if (rejectInProgress.value) return;
    rejectInProgress.value = true;
    try {
      if (phase.value == VideoCallPhase.incoming) {
        final rejectAdId = _interstitialCounter.pickAdIdForClick(
          placement: 'video_call_reject_incoming',
          screenInterstitialEnabled: _adsRc.callRejectInterstitialOn,
          screenInterstitialId: _adsRc.callRejectInterstitialId,
        );
        if (rejectAdId != null) {
          await _showInterstitialWithLoader(rejectAdId);
        }
        await _incomingFeedback.stop();
        await _disposeAll();
        final canPop = Get.key.currentState?.canPop() ?? false;
        if (canPop) {
          Get.back();
        } else {
          Get.offAllNamed(AppRoutes.home);
        }
        return;
      }
      if (phase.value == VideoCallPhase.playing) {
        // End should feel instant: stop call UI/audio before any ad delay.
        await _hangUpDuringCall();
        final endAdId = _interstitialCounter.pickAdIdForClick(
          placement: 'video_call_end',
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
      await _videoPlayer?.pause();
      await _videoPlayer?.seekTo(Duration.zero);
    } catch (_) {}
    position.value = Duration.zero;
    phase.value = VideoCallPhase.ended;
  }

  Future<void> _disposeVideo() async {
    // Flip UI out of video mode first so widgets stop reading old controller.
    videoReady.value = false;
    final v = _videoPlayer;
    _videoPlayer = null;
    if (v != null) {
      v.removeListener(_onVideoTick);
      await v.dispose();
    }
    _videoErrorReported = false;
  }

  Future<void> _disposeCamera() async {
    final cam = _cameraController;
    _cameraController = null;
    cameraReady.value = false;
    if (cam != null) {
      await cam.dispose();
    }
  }

  Future<void> _disposeAll() async {
    await _disposeVideo();
    await _disposeCamera();
    final prepared = _preparedVideoPlayer;
    _preparedVideoPlayer = null;
    _preparedNetworkUri = null;
    _preparedLocalFile = null;
    try {
      await prepared?.dispose();
    } catch (_) {}
  }

  @override
  void onClose() {
    unawaited(_incomingFeedback.stop());
    unawaited(_disposeAll());
    super.onClose();
  }
}
