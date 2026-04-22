import 'dart:async';
import 'dart:ui';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app/routes/app_pages.dart';
import 'app/theme/app_colors.dart';
import 'app/theme/app_theme.dart';
import 'app/translations/app_translations.dart';
import 'core/services/callkit_service.dart';
import 'core/services/call_scheduler_service.dart';
import 'core/services/network_status_service.dart';
import 'core/services/persons_storage_service.dart';
import 'core/services/storage_service.dart';
import 'core/services/subscription_service.dart';
import 'core/ads/ads_remote_config_service.dart';
import 'core/ads/call_interstitial_preload_service.dart';
import 'core/ads/interstitial_click_counter_service.dart';
import 'core/ads/resume_app_open_ad_service.dart';
import 'firebase_options.dart';

bool _firebaseReadyForCrashlytics = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Crashlytics: capture Flutter + platform errors early.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (_firebaseReadyForCrashlytics) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('PlatformDispatcher.onError: $error\n$stack');
    if (_firebaseReadyForCrashlytics) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return false;
  };

  final mobileAdsInit = MobileAds.instance.initialize();

  runApp(const _StartupShell());
  // Heavy init runs after first frame inside [_StartupShell]; keeps launch ~1–2s tighter.
  unawaited(_bootstrapAppCore(mobileAdsInit));
}

Future<void> _bootstrapAppCore(Future<InitializationStatus> mobileAdsInit) async {
  final callScheduler =
      Get.put<CallSchedulerService>(CallSchedulerService(), permanent: true);

  await Future.wait<void>([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]),
    Get.putAsync<StorageService>(() => StorageService().init(),
        permanent: true),
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).then((_) {
      _firebaseReadyForCrashlytics = true;
    }),
  ]);

  await Get.putAsync<SubscriptionService>(
    () => SubscriptionService().init(),
    permanent: true,
  );

  Get.put<AdsRemoteConfigService>(AdsRemoteConfigService(), permanent: true);
  final adsRc = Get.find<AdsRemoteConfigService>();
  await adsRc.init();
  await Get.putAsync<ResumeAppOpenAdService>(
    () => ResumeAppOpenAdService(adsRc).init(),
    permanent: true,
  );

  Get.put<InterstitialClickCounterService>(
    InterstitialClickCounterService(),
    permanent: true,
  );
  Get.put<CallInterstitialPreloadService>(
    CallInterstitialPreloadService(),
    permanent: true,
  );
  Get.put<PersonsStorageService>(PersonsStorageService(), permanent: true);
  Get.put<NetworkStatusService>(NetworkStatusService(), permanent: true);

  final storage = Get.find<StorageService>();
  final initialLocale = _localeFromCode(storage.languageCode);

  _startupAppReady.value = PrankCallApp(initialLocale: initialLocale);

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await callScheduler.init();
    unawaited(callScheduler.completeBootstrapAfterFirstFrame());
  });

  unawaited(
    () async {
      await mobileAdsInit;

      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

      await Get.putAsync<CallkitService>(
        () => CallkitService().init(),
        permanent: true,
      );
    }(),
  );
}

/// Drives [runApp] from placeholder → real [GetMaterialApp] when [_bootstrapAppCore] finishes.
final ValueNotifier<Widget?> _startupAppReady = ValueNotifier<Widget?>(null);

class _StartupShell extends StatefulWidget {
  const _StartupShell();

  @override
  State<_StartupShell> createState() => _StartupShellState();
}

class _StartupShellState extends State<_StartupShell> {
  @override
  void initState() {
    super.initState();
    _startupAppReady.addListener(_onReady);
  }

  void _onReady() {
    final app = _startupAppReady.value;
    if (app != null && mounted) setState(() {});
  }

  @override
  void dispose() {
    _startupAppReady.removeListener(_onReady);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = _startupAppReady.value;
    if (app != null) return app;

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.white,
        body: SizedBox.expand(),
      ),
    );
  }
}

Locale? _localeFromCode(String? code) {
  if (code == null || code.isEmpty) return const Locale('en', 'US');
  final parts = code.split('_');
  if (parts.length >= 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0]);
}

class PrankCallApp extends StatelessWidget {
  const PrankCallApp({super.key, this.initialLocale});

  final Locale? initialLocale;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Fake Video Call',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US'),
      initialRoute: AppPages.initial,
      getPages: AppPages.routes,
    );
  }
}
