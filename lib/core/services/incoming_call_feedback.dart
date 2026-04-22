import 'dart:async';

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, kDebugMode, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:vibration/vibration_presets.dart';

import 'storage_service.dart';

/// Flash / ringtone / vibration while the fake call is in “incoming” state.
class IncomingCallFeedback {
  IncomingCallFeedback(this._storage);

  final StorageService _storage;

  final _ringtone = FlutterRingtonePlayer();
  final AudioPlayer _customRingtonePlayer = AudioPlayer();
  Timer? _flashTimer;
  Timer? _vibrateTimer;
  Timer? _iosSoundTimer;
  int _sessionId = 0;
  bool _flashLit = false;
  static const MethodChannel _torchChannel = MethodChannel('prank_call/torch');

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  void _log(String msg, [Object? e]) {
    if (kDebugMode) {
      debugPrint('IncomingCallFeedback: $msg${e != null ? ': $e' : ''}');
    }
  }

  /// Ringtone must go through an active [AudioSession] or many devices stay silent.
  Future<void> _activateIncomingRingtoneSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.notificationRingtone,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ),
    );
    await session.setActive(true);
  }

  Future<void> start() async {
    await stop();
    final sid = ++_sessionId;
    if (kIsWeb) return;

    // Start flash first (sync order before sound). On some OEMs, configuring the
    // incoming ringtone audio session while the device ringer is silent/DND can
    // briefly interfere with CameraManager torch until flash runs after sound.
    await Future.wait<void>([
      if (_storage.incomingFlashEnabled && (_isAndroid || _isIos)) _startFlash(sid),
      if (_storage.incomingSoundEnabled) _startSound(sid),
      if (_storage.incomingVibrateEnabled) _startVibrate(sid),
    ]);
  }

  Future<void> _startSound(int sid) async {
    try {
      await _activateIncomingRingtoneSession();
      if (sid != _sessionId) return;

      final customUri = _storage.incomingRingtoneUri;
      if (_isAndroid &&
          customUri != null &&
          customUri.isNotEmpty) {
        try {
          await _customRingtonePlayer.setAudioSource(
            AudioSource.uri(Uri.parse(customUri)),
          );
          if (sid != _sessionId) return;
          await _customRingtonePlayer.setLoopMode(LoopMode.one);
          if (sid != _sessionId) return;
          await _customRingtonePlayer.setVolume(1.0);
          if (sid != _sessionId) return;
          await _customRingtonePlayer.play();
        } catch (e) {
          _log('custom ringtone failed, using default', e);
          await _ringtone.playRingtone(
            volume: 1.0,
            looping: true,
            asAlarm: false,
          );
        }
      } else if (_isAndroid) {
        await _ringtone.playRingtone(
          volume: 1.0,
          looping: true,
          asAlarm: false,
        );
      } else if (_isIos) {
        Future<void> playOnce() => _ringtone.playRingtone(
              volume: 1.0,
              looping: false,
              asAlarm: false,
            );
        await playOnce();
        if (sid != _sessionId) return;
        _iosSoundTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          if (sid != _sessionId) return;
          playOnce();
        });
      }
    } catch (e, st) {
      _log('sound failed', e);
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  }

  Future<void> _startVibrate(int sid) async {
    try {
      Future<void> pulse() async {
        if (sid != _sessionId) return;
        try {
          final has = await Vibration.hasVibrator();
          if (has || _isIos) {
            try {
              await Vibration.vibrate(preset: VibrationPreset.doubleBuzz);
            } catch (_) {
              await Vibration.vibrate(duration: 600);
            }
          }
          if (!has || _isIos) {
            await HapticFeedback.heavyImpact();
            await Future<void>.delayed(const Duration(milliseconds: 40));
            await HapticFeedback.mediumImpact();
          }
        } catch (e) {
          _log('vibrate pulse failed', e);
          try {
            await HapticFeedback.heavyImpact();
          } catch (_) {}
        }
      }

      await pulse();
      if (sid != _sessionId) return;
      _vibrateTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
        if (sid != _sessionId) return;
        unawaited(pulse());
      });
    } catch (e) {
      _log('vibrate start failed', e);
    }
  }

  Future<void> _startFlash(int sid) async {
    if (!_isAndroid && !_isIos) return;
    try {
      final available =
          await _torchChannel.invokeMethod<bool>('isTorchAvailable') ?? false;
      if (!available) {
        _log('torch unavailable on this device');
        return;
      }
      Future<void> toggle(bool on) async {
        if (sid != _sessionId) return;
        try {
          final ok = await _torchChannel.invokeMethod<bool>(
                'setTorch',
                <String, dynamic>{'enabled': on},
              ) ??
              false;
          _flashLit = on && ok;
        } catch (e) {
          _log('flash toggle failed', e);
        }
      }

      // Quick pulse pattern while incoming call is ringing.
      await toggle(true);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await toggle(false);
      if (sid != _sessionId) return;

      _flashTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
        if (sid != _sessionId) return;
        await toggle(!_flashLit);
      });
    } catch (e) {
      _log('flash start failed', e);
    }
  }

  Future<void> stop() async {
    _sessionId++;
    _iosSoundTimer?.cancel();
    _iosSoundTimer = null;
    _flashTimer?.cancel();
    _flashTimer = null;
    _vibrateTimer?.cancel();
    _vibrateTimer = null;

    try {
      await _torchChannel.invokeMethod<bool>(
        'setTorch',
        <String, dynamic>{'enabled': false},
      );
    } catch (_) {}
    _flashLit = false;

    try {
      await Vibration.cancel();
    } catch (_) {}

    try {
      await _customRingtonePlayer.stop();
    } catch (_) {}

    try {
      await _ringtone.stop();
    } catch (_) {}
  }
}
