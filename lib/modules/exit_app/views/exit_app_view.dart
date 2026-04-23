import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';

class ExitAppView extends StatelessWidget {
  const ExitAppView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final topNativeFactory = _pickNativeFactoryIdForExitTop(ads);
    final bottomNativeFactory = _pickNativeFactoryIdForExitBottom(ads);
    final topHasAny = ads.exitTopBannerOn || topNativeFactory != null;
    final bottomHasAny = ads.exitBottomBannerOn || bottomNativeFactory != null;
    final adFactory = bottomNativeFactory ?? topNativeFactory;
    final showAd = topHasAny || bottomHasAny;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          'Exit Screen',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: AppColors.black),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => Get.back(),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2F4FA),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: Color(0xFF667085),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Image.asset(
                          AppAssets.icHomeExit,
                          width: 190,
                          height: 190,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Prank Fake Video Call',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppColors.black,
                            fontSize: 40,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Realistic fake video calls-prank your friends and capture priceless reactions! 😂📱',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.black.withValues(alpha: 0.32),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Get.back(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(40),
                              ),
                            ),
                            child: const Text(
                              'Try Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (showAd)
                    RaceBannerNativeSlot(
                      bannerEnabled: ads.exitBottomBannerOn || ads.exitTopBannerOn,
                      nativeEnabled: adFactory != null,
                      bannerUnitId: ads.exitBannerId,
                      nativeUnitId: ads.exitNativeId,
                      debugLabel: 'exit_middle_slot',
                      nativeFactoryId: adFactory,
                      nativeHeight: _nativeHeightForFactory(adFactory),
                    ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async => SystemNavigator.pop(),
              child: Container(
                color: const Color(0xFFE2CCF3),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sentiment_very_dissatisfied_rounded, size: 34),
                      const SizedBox(width: 10),
                      Text(
                        'Close the App',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _pickNativeFactoryIdForExitTop(AdsRemoteConfigService ads) {
  if (ads.exitTopNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.exitTopNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.exitTopNativeSmallInlineOn) return 'native_small_inline';
  return null;
}

String? _pickNativeFactoryIdForExitBottom(AdsRemoteConfigService ads) {
  if (ads.exitBottomNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.exitBottomNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.exitBottomNativeSmallInlineOn) return 'native_small_inline';
  return null;
}

double _nativeHeightForFactory(String? factoryId) {
  switch (factoryId) {
    case 'native_advance_button_bottom':
      return 260;
    case 'native_small_button_bottom':
      return 170;
    case 'native_small_inline':
    default:
      return 150;
  }
}
