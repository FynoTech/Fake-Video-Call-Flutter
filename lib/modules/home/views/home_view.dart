import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/services/subscription_service.dart';
import '../controllers/home_controller.dart';
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
        final title = _titleForTab(0);
        final subtitle = _subtitleForTab(0);
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
                      onPressed: () => Get.toNamed(AppRoutes.settings),
                      icon: Image.asset(
                        'assets/home/ic_settings_home_custom.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
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
                      onPressed: () => Get.toNamed(AppRoutes.settings),
                      icon: Image.asset(
                        'assets/home/ic_settings_home_custom.png',
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      tooltip: 'settings_title'.tr,
                    ),
                    const SizedBox(width: 6),
                  ],
          ),
          body: SafeArea(
            bottom: false,
            child: const HomeVideoCallTab(),
          ),
        );
      }),
    );
  }
}
