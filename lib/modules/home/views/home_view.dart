import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../../settings/views/settings_view.dart';
import '../controllers/home_controller.dart';
import 'home_custom_call_tab.dart';
import 'home_video_call_tab.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  String _titleForTab(int index) {
    switch (index.clamp(0, 2)) {
      case 1:
        return 'nav_custom_call'.tr;
      case 2:
        return 'settings_title'.tr;
      case 0:
      default:
        return 'app_name'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscription = Get.find<SubscriptionService>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        unawaited(controller.handleHomeBackPressed());
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Obx(
            () => GradientAppBar(
              title: _titleForTab(controller.bottomNavIndex.value),
              centerTitle: false,
              automaticallyImplyLeading: false,
              leading: const SizedBox.shrink(),
              leadingWidth: 0,
              actions: subscription.isPremium.value
                  ? const []
                  : [
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: IconButton(
                          onPressed: () => Get.toNamed(AppRoutes.premium),
                          icon: Image.asset(
                            'assets/premium/premium_crown.png',
                            width: 35,
                            height: 35,
                            fit: BoxFit.contain,
                          ),
                          tooltip: 'settings_premium_title'.tr,
                        ),
                      ),
                    ],
            ),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Obx(
            () => IndexedStack(
              index: controller.bottomNavIndex.value.clamp(0, 2),
              sizing: StackFit.expand,
              children: const [
                HomeVideoCallTab(),
                HomeCustomCallTab(),
                SettingsView(embeddedInShell: true),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFFE1E1E1), width: 1),
                    ),
                  ),
                  child: NavigationBar(
                    height: 78,
                    selectedIndex: controller.bottomNavIndex.value.clamp(0, 2),
                    onDestinationSelected: controller.selectBottomNav,
                    backgroundColor: AppColors.white,
                    surfaceTintColor: AppColors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    indicatorColor: Colors.transparent,
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: selected
                            ? const Color(0xFF58A8DB)
                            : const Color(0xFFB3B3B3),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      );
                    }),
                    destinations: [
                      NavigationDestination(
                        icon: _BottomNavSvgIcon(
                          assetPath: 'assets/ic_videocall.svg',
                          selected: false,
                        ),
                        selectedIcon: _BottomNavSvgIcon(
                          assetPath: 'assets/ic_videocall.svg',
                          selected: true,
                        ),
                        label: 'nav_video_call'.tr,
                      ),
                      NavigationDestination(
                        icon: _BottomNavSvgIcon(
                          assetPath: 'assets/ic_call.svg',
                          selected: false,
                        ),
                        selectedIcon: _BottomNavSvgIcon(
                          assetPath: 'assets/ic_call.svg',
                          selected: true,
                        ),
                        label: 'nav_custom_call'.tr,
                      ),
                      NavigationDestination(
                        icon: _BottomNavSvgIcon(
                          assetPath: 'assets/c_settings.svg',
                          selected: false,
                        ),
                        selectedIcon: _BottomNavSvgIcon(
                          assetPath: 'assets/c_settings.svg',
                          selected: true,
                        ),
                        label: 'nav_settings'.tr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavSvgIcon extends StatelessWidget {
  const _BottomNavSvgIcon({required this.assetPath, required this.selected});

  final String assetPath;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF58A8DB) : const Color(0xFFB3B3B3);
    return SvgPicture.asset(
      assetPath,
      width: 26,
      height: 20,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
