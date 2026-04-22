import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/gradient_app_bar.dart';

class ExitAppView extends StatelessWidget {
  const ExitAppView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final topNativeFactory = _pickNativeFactoryIdForExitTop(ads);
    final bottomNativeFactory = _pickNativeFactoryIdForExitBottom(ads);
    final topHasAny = ads.exitTopBannerOn || topNativeFactory != null;
    final bottomHasAny = ads.exitBottomBannerOn || bottomNativeFactory != null;
    final showBottom = bottomHasAny;
    final showTop = !bottomHasAny && topHasAny;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: GradientAppBar(title: 'exit_app_title'.tr, centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            if (showTop) ...[
              RaceBannerNativeSlot(
                bannerEnabled: ads.exitTopBannerOn,
                nativeEnabled: topNativeFactory != null,
                bannerUnitId: ads.exitBannerId,
                nativeUnitId: ads.exitNativeId,
                debugLabel: 'exit_top_slot',
                nativeFactoryId: topNativeFactory,
                nativeHeight: _nativeHeightForFactory(topNativeFactory),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/exit/exit_icon.png',
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 25),
                        Text(
                          'exit_app_message'.tr,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            Expanded(
                              child: Material(
                                color: AppColors.transparent,
                                borderRadius: BorderRadius.circular(28),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => Get.back(),
                                  child: Ink(
                                    decoration: const BoxDecoration(
                                      gradient: AppColors.appBarGradient,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    child: Center(
                                      child: Text(
                                        'cancel'.tr,
                                        style: Theme.of(context).textTheme.labelLarge
                                            ?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  await SystemNavigator.pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textMuted72,
                                  side: const BorderSide(
                                    color: AppColors.languageCardBorderUnselected,
                                    width: 1.2,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                child: Text(
                                  'exit'.tr,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (showBottom) ...[
              const SizedBox(height: 8),
              RaceBannerNativeSlot(
                bannerEnabled: ads.exitBottomBannerOn,
                nativeEnabled: bottomNativeFactory != null,
                bannerUnitId: ads.exitBannerId,
                nativeUnitId: ads.exitNativeId,
                debugLabel: 'exit_bottom_slot',
                nativeFactoryId: bottomNativeFactory,
                nativeHeight: _nativeHeightForFactory(bottomNativeFactory),
              ),
            ],
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
