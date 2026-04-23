import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/subscription_service.dart';
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
        return 'feature_video_title'.tr;
    }
  }

  String? _subtitleForTab(int index) {
    switch (index.clamp(0, 2)) {
      case 0:
        return 'home_video_subtitle'.tr;
      default:
        return null;
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
      child: Obx(() {
        final index = controller.bottomNavIndex.value.clamp(0, 2);
        final title = _titleForTab(index);
        final subtitle = _subtitleForTab(index);
        final isPremium = subscription.isPremium.value;
        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppColors.backgroundColor,
            surfaceTintColor: AppColors.backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            automaticallyImplyLeading: false,
            toolbarHeight: 84,
            titleSpacing: 20,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Audiowide',
                    fontSize: 24,
                    color: AppColors.black,
                    letterSpacing: 0.2,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black.withValues(alpha: 0.45),
                    ),
                  ),
              ],
            ),
            actions: isPremium
                ? [
                    IconButton(
                      onPressed: () => controller.selectBottomNav(2),
                      icon: SvgPicture.asset(
                        'assets/c_settings.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: 'settings_title'.tr,
                    ),
                    const SizedBox(width: 6),
                  ]
                : [
                    IconButton(
                      onPressed: () => Get.toNamed(AppRoutes.premium),
                      icon: Image.asset(
                        'assets/premium/premium_crown.png',
                        width: 35,
                        height: 35,
                        fit: BoxFit.contain,
                      ),
                      tooltip: 'settings_premium_title'.tr,
                    ),
                    IconButton(
                      onPressed: () => controller.selectBottomNav(2),
                      icon: SvgPicture.asset(
                        'assets/c_settings.svg',
                        width: 22,
                        height: 22,
                        colorFilter: const ColorFilter.mode(
                          AppColors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                      tooltip: 'settings_title'.tr,
                    ),
                    const SizedBox(width: 6),
                  ],
          ),
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: index,
              sizing: StackFit.expand,
              children: const [
                HomeVideoCallTab(),
                HomeCustomCallTab(),
                SettingsView(embeddedInShell: true),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE1E1E1), width: 1),
                ),
              ),
              child: NavigationBar(
                height: 78,
                selectedIndex: index,
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
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
          ),
        );
      }),
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
