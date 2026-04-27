import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show
        TargetPlatform,
        debugPrint,
        defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../widgets/foreground_incoming_call_banner.dart';
import '../call_schedule_config.dart';
import '../incoming_call_notif_ids.dart';
import '../models/person_item.dart';
import 'incoming_call_feedback.dart';
import 'network_reachability.dart';
import 'persons_storage_service.dart';
import 'storage_service.dart';

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse response) {}

/// Schedules fake video calls **only while the app is in the foreground** (in-app banner +
/// optional heads-up notification). No exact alarms or background delivery when the app is
/// closed or in the background.
class CallSchedulerService extends GetxService with WidgetsBindingObserver {
  static const MethodChannel _nativeAlarmChannel =
      MethodChannel('prank_call/native_alarm');
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  Timer? _timer;
  Timer? _foregroundTimer;
  Timer? _autoIncomingTimer;
  Timer? _fallbackIncomingStopTimer;
  Duration _autoIncomingInterval = Duration.zero;
  final Random _rng = Random();
  bool _isForeground = true;
  IncomingCallFeedback? _fallbackIncomingFeedback;

  /// Wall-clock target for the in-app banner (re-arm after resume if user left the app).
  PersonItem? _pendingBannerPerson;
  DateTime? _pendingBannerAt;

  static const int _notifId = kScheduledCallNotifId;
  static const int _foregroundDisplayNotifId = kForegroundIncomingDisplayNotifId;
  static const String _payloadPrefix = 'video:';
  static const String _actionReject = 'reject_call';

  static const Duration _splashDeferIncomingDelay = Duration(milliseconds: 500);
  static const Duration _incomingUiAutoDismissAfter = Duration(seconds: 10);
  static const Duration _rejectCooldown = Duration(seconds: 12);

  String? _lastRejectedStoragePath;
  DateTime? _lastRejectedAt;

  /// True when the app was opened by tapping a scheduled-call notification.
  bool openedFromNotification = false;

  bool _bootstrapComplete = false;

  bool _shouldSuppressForegroundIncoming() {
    final r = Get.currentRoute;
    return r == AppRoutes.splash ||
        r == AppRoutes.videoCall ||
        r == AppRoutes.audioCall;
  }

  bool _isCallScreenActive() {
    final r = Get.currentRoute;
    return r == AppRoutes.videoCall || r == AppRoutes.audioCall;
  }

  bool _requiresInternetForIncoming(PersonItem person) {
    return isRemoteMediaUrl(person.videoUrl) ||
        PersonsStorageService.isCustomStoragePath(person.storageFolderPath);
  }

  bool _isInRejectCooldown(PersonItem person) {
    final path = _lastRejectedStoragePath;
    final at = _lastRejectedAt;
    if (path == null || at == null) return false;
    if (person.storageFolderPath != path) return false;
    return DateTime.now().difference(at) < _rejectCooldown;
  }

  void _markRejectedByPath(String storageFolderPath) {
    if (storageFolderPath.trim().isEmpty) return;
    _lastRejectedStoragePath = storageFolderPath;
    _lastRejectedAt = DateTime.now();
  }

  void _markRejected(PersonItem person) {
    _markRejectedByPath(person.storageFolderPath);
  }

  Future<void> _configureLocalTimeZone() async {
    try {
      tz.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('CallScheduler: timezone setup failed: $e');
      tz.initializeTimeZones();
    }
  }

  Future<void> _ensureAndroidChannel() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    final channel = AndroidNotificationChannel(
      'scheduled_calls',
      'Scheduled Calls',
      description: 'Scheduled fake incoming calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      vibrationPattern: Int64List.fromList([0, 600, 300, 600, 300, 600]),
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
    );
    await android.createNotificationChannel(channel);
  }

  // Image download helper removed (kept notifications reliable on all devices).

  Future<bool> _ensureNotificationPermission() async {
    try {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      final aEnabled = await android?.areNotificationsEnabled();
      if (aEnabled == false) {
        final granted = await android?.requestNotificationsPermission();
        if (granted == false) return false;
      }

      if (ios != null) {
        final granted =
            await ios.requestPermissions(alert: true, badge: true, sound: true);
        if (granted == false) return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Shows the in-app explanation on splash first; then call this for system prompts.
  Future<void> requestStartupPermissions() async {
    // Intentionally disabled: do not show startup permission dialogs.
  }

  /// True when notification permission is missing (needed for optional heads-up row during
  /// foreground fake calls).
  Future<bool> shouldShowPermissionRationale() async {
    return false;
  }

  /// Registers notification callbacks — call from [main] **before** [runApp] so the first
  /// notification tap is not dropped while Mobile Ads / other async work runs.
  Future<CallSchedulerService> init() async {
    await _configureLocalTimeZone();
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(
      settings: init,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );
    await _ensureAndroidChannel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeAlarmChannel.invokeMethod('cancelExactCall');
      } catch (_) {}
    }
    return this;
  }

  /// Run after the first frame so [GetMaterialApp] has a navigator for cold-start taps.
  Future<void> completeBootstrapAfterFirstFrame() async {
    if (_bootstrapComplete) return;
    try {
      await _migrateInvalidAutoIncomingIfNeeded();
      _restoreForegroundAutoIncomingFromStorage();
      WidgetsBinding.instance.addObserver(this);

      final launchDetails =
          await _notifications.getNotificationAppLaunchDetails();
      final response = launchDetails?.notificationResponse;
      if ((launchDetails?.didNotificationLaunchApp ?? false) &&
          response?.payload != null) {
        openedFromNotification = true;
        _onNotificationResponse(response!);
      }

      await _consumeNativeLaunchPayloadIfAny();
    } finally {
      _bootstrapComplete = true;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_handleNotificationTap(response));
    });
  }

  Future<void> _migrateInvalidAutoIncomingIfNeeded() async {
    try {
      final storage = Get.find<StorageService>();
      final raw = storage.autoIncomingEverySeconds;
      final fixed = normalizeForegroundCallScheduleSeconds(raw);
      if (fixed != raw) {
        await storage.setAutoIncomingEverySeconds(fixed);
      }
    } catch (_) {}
  }

  void _restoreForegroundAutoIncomingFromStorage() {
    try {
      final storage = Get.find<StorageService>();
      final secs = normalizeForegroundCallScheduleSeconds(
        storage.autoIncomingEverySeconds,
      );
      _autoIncomingInterval =
          secs <= 0 ? Duration.zero : Duration(seconds: secs);
      if (_isForeground) {
        _armAutoIncomingTimer();
      }
    } catch (_) {
      _autoIncomingInterval = Duration.zero;
    }
  }

  Future<void> configureForegroundAutoIncoming(Duration interval) async {
    _autoIncomingInterval = interval <= Duration.zero ? Duration.zero : interval;
    try {
      final storage = Get.find<StorageService>();
      await storage.setAutoIncomingEverySeconds(
        _autoIncomingInterval.inSeconds,
      );
    } catch (_) {}
    _armAutoIncomingTimer();
  }

  void _armAutoIncomingTimer() {
    _autoIncomingTimer?.cancel();
    if (!_isForeground || _autoIncomingInterval <= Duration.zero) return;
    // Product behavior: fire only once per app-open/resume window (not periodic).
    _autoIncomingTimer = Timer(_autoIncomingInterval, () {
      unawaited(_fireAutoIncomingTick());
    });
  }

  Future<void> _fireAutoIncomingTick() async {
    if (!_isForeground || _autoIncomingInterval <= Duration.zero) return;
    if (_shouldSuppressForegroundIncoming()) return;
    try {
      final persons = Get.find<PersonsStorageService>();
      if (persons.persons.isEmpty && !persons.isLoading.value) {
        await persons.loadPersons();
      }
      final candidates = persons.persons
          .where((p) => p.videoUrl != null && p.videoUrl!.isNotEmpty)
          .toList();
      if (candidates.isEmpty) return;
      final online = await hasInternetConnection();
      final filtered = candidates
          .where(
            (p) =>
                (online || !_requiresInternetForIncoming(p)) &&
                !_isInRejectCooldown(p),
          )
          .toList();
      if (filtered.isEmpty) return;
      final person = filtered[_rng.nextInt(filtered.length)];
      await _deliverForegroundIncoming(person);
    } catch (e) {
      debugPrint('CallScheduler: auto incoming failed: $e');
    }
  }

  Future<void> _consumeNativeLaunchPayloadIfAny() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final payload = await _nativeAlarmChannel
          .invokeMapMethod<String, dynamic>('consumeScheduledLaunchPayload');
      final folderPath = payload?['storageFolderPath']?.toString();
      if (folderPath == null || folderPath.isEmpty) return;
      final persons = Get.find<PersonsStorageService>();
      if (persons.persons.isEmpty && !persons.isLoading.value) {
        await persons.loadPersons();
      }
      PersonItem? target;
      for (final p in persons.persons) {
        if (p.storageFolderPath == folderPath) {
          target = p;
          break;
        }
      }
      if (target != null) {
        final t = target;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future<void>.delayed(const Duration(milliseconds: 120), () async {
            if (_requiresInternetForIncoming(t) &&
                !await hasInternetConnection()) {
              Get.offAllNamed(AppRoutes.home);
              return;
            }
            Get.offAllNamed(
              AppRoutes.videoCall,
              arguments: {'person': t, 'autoAccept': true},
            );
          });
        });
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _isForeground = false;
      unawaited(_stopFallbackIncomingFeedback());
      ForegroundIncomingCallBanner.dismiss();
      _timer?.cancel();
      _timer = null;
      _foregroundTimer?.cancel();
      _foregroundTimer = null;
      _autoIncomingTimer?.cancel();
      _autoIncomingTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      _isForeground = true;
      _resumeForegroundBannerIfNeeded();
      _armAutoIncomingTimer();
    }
  }

  @override
  void onClose() {
    unawaited(_stopFallbackIncomingFeedback());
    ForegroundIncomingCallBanner.dismiss();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _autoIncomingTimer?.cancel();
    super.onClose();
  }

  void _clearPendingSchedule() {
    _timer?.cancel();
    _timer = null;
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    _pendingBannerPerson = null;
    _pendingBannerAt = null;
  }

  void _resumeForegroundBannerIfNeeded() {
    final person = _pendingBannerPerson;
    final at = _pendingBannerAt;
    if (person == null || at == null) return;
    final now = DateTime.now();
    final remaining = at.difference(now);
    if (remaining <= Duration.zero) {
      final lateBy = now.difference(at);
      // Fired while we were paused (e.g. permission dialog, quick app switch).
      if (lateBy <= const Duration(minutes: 2)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_deliverPendingAfterResumeIfAllowed(person));
        });
      } else {
        _pendingBannerPerson = null;
        _pendingBannerAt = null;
      }
      return;
    }
    _armForegroundTrigger(delay: remaining, person: person);
  }

  /// Late delivery after resume; keeps pending if still on splash / in-call.
  Future<void> _deliverPendingAfterResumeIfAllowed(PersonItem person) async {
    if (!_isForeground) return;
    if (_shouldSuppressForegroundIncoming()) {
      _pendingBannerAt = DateTime.now().add(_splashDeferIncomingDelay);
      _armForegroundTrigger(delay: _splashDeferIncomingDelay, person: person);
      return;
    }
    _pendingBannerPerson = null;
    _pendingBannerAt = null;
    await _deliverForegroundIncoming(person);
  }

  Future<void> _deliverForegroundIncoming(PersonItem person) async {
    if (!_isForeground) return;
    if (_shouldSuppressForegroundIncoming()) return;
    if (_isInRejectCooldown(person)) return;
    if (_requiresInternetForIncoming(person)) {
      final online = await hasInternetConnection();
      if (!online) {
        _pendingBannerPerson = null;
        _pendingBannerAt = null;
        return;
      }
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeAlarmChannel.invokeMethod('cancelExactCall');
      } catch (_) {}
    }
    try {
      await _notifications.cancel(id: _notifId);
    } catch (_) {}
    await _stopFallbackIncomingFeedback();
    await _showOnScreenIncomingNotification(person);
    _showIncomingCallBanner(person);
  }

  Future<void> cancel() async {
    _clearPendingSchedule();
    await _stopFallbackIncomingFeedback();
    ForegroundIncomingCallBanner.dismiss();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _nativeAlarmChannel.invokeMethod('cancelExactCall');
      } catch (_) {}
    }
    try {
      await _notifications.cancel(id: _notifId);
    } catch (_) {}
    try {
      await _notifications.cancel(id: _foregroundDisplayNotifId);
    } catch (_) {}
  }

  /// Called when user declines an incoming fake call.
  Future<void> rejectIncoming({PersonItem? person}) async {
    if (person != null) {
      _markRejected(person);
    }
    await cancel();
  }

  String _callerLabel(PersonItem person) =>
      person.firstName.isEmpty ? person.name : person.firstName;

  void _armForegroundTrigger({
    required Duration delay,
    required PersonItem person,
  }) {
    if (!_isForeground || delay <= Duration.zero) return;
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer(delay, () async {
      if (!_isForeground) return;
      if (_shouldSuppressForegroundIncoming()) {
        _pendingBannerAt = DateTime.now().add(_splashDeferIncomingDelay);
        _armForegroundTrigger(delay: _splashDeferIncomingDelay, person: person);
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _nativeAlarmChannel.invokeMethod('cancelExactCall');
        } catch (_) {}
      }
      try {
        await _notifications.cancel(id: _notifId);
      } catch (_) {}
      await _stopFallbackIncomingFeedback();
      _pendingBannerPerson = null;
      _pendingBannerAt = null;
      await _showOnScreenIncomingNotification(person);
      _showIncomingCallBanner(person);
    });
  }

  /// System heads-up + shade row (sound/vibration come from [ForegroundIncomingCallBanner] feedback).
  Future<void> _showOnScreenIncomingNotification(PersonItem person) async {
    if (_isCallScreenActive()) return;
    try {
      await _notifications.show(
        id: _foregroundDisplayNotifId,
        title: 'incoming_call_notification_title'.tr,
        body: 'incoming_call_body'.trArgs([_callerLabel(person)]),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'scheduled_calls',
            'Scheduled Calls',
            channelDescription: 'Scheduled fake incoming calls',
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.call,
            color: AppColors.primaryColor,
            playSound: false,
            enableVibration: false,
            ongoing: true,
            autoCancel: false,
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentList: true,
            presentSound: false,
            presentBadge: true,
          ),
        ),
        payload: '$_payloadPrefix${person.storageFolderPath}',
      );
      unawaited(
        Future<void>.delayed(_incomingUiAutoDismissAfter, () async {
          try {
            await _notifications.cancel(id: _foregroundDisplayNotifId);
          } catch (_) {}
          await _stopFallbackIncomingFeedback();
        }),
      );
    } catch (e) {
      debugPrint('CallScheduler: foreground display notification failed: $e');
    }
  }

  /// Overlay context is not always ready on the first frame after a [Timer] fires.
  void _showIncomingCallBanner(PersonItem person) {
    void attempt(int frame) {
      final ctx = ForegroundIncomingCallBanner.pickOverlayContext();
      if (ctx != null && ctx.mounted) {
        ForegroundIncomingCallBanner.show(ctx, person: person);
        return;
      }
      if (frame >= 24) {
        debugPrint('CallScheduler: banner skipped — no overlay context');
        unawaited(_startFallbackIncomingFeedback());
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => attempt(frame + 1));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt(0));
  }

  Future<bool> scheduleVideoCall({
    required Duration delay,
    required PersonItem person,
  }) async {
    await cancel();

    if (delay <= Duration.zero) {
      debugPrint('CallScheduler: zero delay — no schedule.');
      return false;
    }

    if (!_isForeground) {
      debugPrint('CallScheduler: app not in foreground — not scheduling.');
      return false;
    }

    final scheduled = tz.TZDateTime.now(tz.local).add(delay);
    debugPrint(
      'CallScheduler: now=${tz.TZDateTime.now(tz.local)} scheduled=$scheduled in=${scheduled.difference(tz.TZDateTime.now(tz.local)).inMilliseconds}ms',
    );

    try {
      await _ensureAndroidChannel();
    } catch (e) {
      debugPrint('CallScheduler: channel ensure failed: $e');
    }

    _pendingBannerPerson = person;
    _pendingBannerAt = DateTime.now().add(delay);
    _armForegroundTrigger(delay: delay, person: person);

    unawaited(_warmSchedulerPermissions());

    return true;
  }

  /// Soft notification permission prompt (optional for heads-up row during foreground calls).
  Future<void> _warmSchedulerPermissions() async {
    try {
      await _ensureNotificationPermission();
    } catch (e) {
      debugPrint('CallScheduler: permission warm failed: $e');
    }
  }

  Future<void> _handleNotificationTap(NotificationResponse response) async {
    // Notification interaction should always clear any in-app incoming banner.
    ForegroundIncomingCallBanner.dismiss();

    final action = response.actionId;
    if (action == _actionReject) {
      final payload = response.payload;
      if (payload != null && payload.startsWith(_payloadPrefix)) {
        _markRejectedByPath(payload.substring(_payloadPrefix.length));
      }
      await rejectIncoming();
      return;
    }

    final payload = response.payload;
    if (payload == null || !payload.startsWith(_payloadPrefix)) return;

    // Ignore secondary incoming-tap while a call UI is already active.
    if (_isCallScreenActive()) {
      await cancel();
      return;
    }

    _clearPendingSchedule();
    await _stopFallbackIncomingFeedback();
    try {
      await _notifications.cancel(id: _notifId);
    } catch (_) {}
    try {
      await _notifications.cancel(id: _foregroundDisplayNotifId);
    } catch (_) {}

    final folderPath = payload.substring(_payloadPrefix.length);
    try {
      final persons = Get.find<PersonsStorageService>();
      if (persons.persons.isEmpty && !persons.isLoading.value) {
        await persons.loadPersons();
      }
      PersonItem? target;
      for (final p in persons.persons) {
        if (p.storageFolderPath == folderPath) {
          target = p;
          break;
        }
      }
      if (target == null) {
        Get.offAllNamed(AppRoutes.home);
        return;
      }
      if (_requiresInternetForIncoming(target) &&
          !await hasInternetConnection()) {
        Get.offAllNamed(AppRoutes.home);
        return;
      }
      Get.offAllNamed(
        AppRoutes.videoCall,
        arguments: {'person': target, 'autoAccept': true},
      );
    } catch (e) {
      debugPrint('Notification tap open failed: $e');
      Get.offAllNamed(AppRoutes.home);
    }
  }

  Future<void> _startFallbackIncomingFeedback() async {
    await _stopFallbackIncomingFeedback();
    try {
      final storage = Get.find<StorageService>();
      final feedback = IncomingCallFeedback(storage);
      _fallbackIncomingFeedback = feedback;
      await feedback.start();
      _fallbackIncomingStopTimer = Timer(
        _incomingUiAutoDismissAfter,
        () => unawaited(_stopFallbackIncomingFeedback()),
      );
    } catch (e) {
      debugPrint('CallScheduler: fallback feedback start failed: $e');
    }
  }

  Future<void> _stopFallbackIncomingFeedback() async {
    _fallbackIncomingStopTimer?.cancel();
    _fallbackIncomingStopTimer = null;
    try {
      await _fallbackIncomingFeedback?.stop();
    } catch (_) {}
    _fallbackIncomingFeedback = null;
  }
}
