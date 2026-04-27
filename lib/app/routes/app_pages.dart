import 'package:get/get.dart';

import '../../modules/home/bindings/home_binding.dart';
import '../../modules/home/views/home_view.dart';
import '../../modules/persons_catalog/bindings/persons_catalog_binding.dart';
import '../../modules/persons_catalog/views/persons_catalog_view.dart';
import '../../modules/add_new/bindings/add_new_binding.dart';
import '../../modules/add_new/views/add_new_view.dart';
import '../../modules/add_video_person/bindings/add_video_person_binding.dart';
import '../../modules/add_video_person/views/add_video_person_view.dart';
import '../../modules/audio_call/bindings/audio_call_binding.dart';
import '../../modules/audio_call/views/audio_call_view.dart';
import '../../modules/video_call/bindings/video_call_binding.dart';
import '../../modules/video_call/views/video_call_view.dart';
import '../../modules/schedule_call/bindings/schedule_call_binding.dart';
import '../../modules/schedule_call/views/schedule_call_view.dart';
import '../../modules/premium/bindings/premium_binding.dart';
import '../../modules/premium/views/premium_view.dart';
import '../../modules/settings/bindings/settings_binding.dart';
import '../../modules/settings/views/settings_view.dart';
import '../../modules/exit_app/views/exit_app_view.dart';
import '../../modules/language/bindings/language_binding.dart';
import '../../modules/language/views/language_view.dart';
import '../../modules/onboarding/bindings/onboarding_binding.dart';
import '../../modules/onboarding/views/onboarding_view.dart';
import '../../modules/splash/bindings/splash_binding.dart';
import '../../modules/splash/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = AppRoutes.splash;

  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashView(),
      binding: SplashBinding(),
    ),
    GetPage(
      name: AppRoutes.language,
      page: () => const LanguageView(),
      binding: LanguageBinding(),
    ),
    GetPage(
      name: AppRoutes.onboarding,
      page: () => const OnboardingView(),
      binding: OnboardingBinding(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.personsCatalog,
      page: () => const PersonsCatalogView(),
      binding: PersonsCatalogBinding(),
    ),
    GetPage(
      name: AppRoutes.addNew,
      page: () => const AddNewView(),
      binding: AddNewBinding(),
    ),
    GetPage(
      name: AppRoutes.addVideoPerson,
      page: () => const AddVideoPersonView(),
      binding: AddVideoPersonBinding(),
    ),
    GetPage(
      name: AppRoutes.audioCall,
      page: () => const AudioCallView(),
      binding: AudioCallBinding(),
    ),
    GetPage(
      name: AppRoutes.videoCall,
      page: () => const VideoCallView(),
      binding: VideoCallBinding(),
    ),
    GetPage(
      name: AppRoutes.scheduleCall,
      page: () => const ScheduleCallView(),
      binding: ScheduleCallBinding(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.exitApp,
      page: () => const ExitAppView(),
    ),
    GetPage(
      name: AppRoutes.premium,
      page: () => const PremiumView(),
      binding: PremiumBinding(),
    ),
  ];
}
