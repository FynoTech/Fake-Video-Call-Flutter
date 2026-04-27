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
                          'app_name'.tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.black,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),

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
                            child: Text(
                              'exit_try_now'.tr,
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
                      bannerEnabled:
                          ads.exitBottomBannerOn || ads.exitTopBannerOn,
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
                color: const Color(0xB2E6E7E7),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/exit/ic_close_app_custom.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'exit_close_app_action'.tr,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Color(0xff9F9F9F),
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
