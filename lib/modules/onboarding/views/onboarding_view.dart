import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../controllers/onboarding_controller.dart';

class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: AppColors.transparent,
      ),
      child: Scaffold(
        //backgroundColor: AppColors.white,
        body: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/ob_bg.png', fit: BoxFit.cover),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: controller.onSkipTap,
                          child: Text(
                            'skip'.tr,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textMuted72,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Obx(() {
                    // Rebuild when Remote Config flags get refreshed.
                    ads.configVersion.value;
                    final keyName = _onboardingKeyForCurrentPage(controller);
                    if (!_showTopAd(ads, keyName)) return const SizedBox.shrink();
                    final topFactoryId = _pickNativeFactoryIdForOnboardingTop(
                      ads,
                      keyName,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: RaceBannerNativeSlot(
                            key: ValueKey('onboarding_top_slot_$keyName'),
                            bannerEnabled: ads.onboardingTopBannerOn(keyName),
                            nativeEnabled: topFactoryId != null,
                            bannerUnitId: ads.onboardingBannerId,
                            nativeUnitId: ads.onboardingNativeId,
                            debugLabel: 'onboarding_top_slot_$keyName',
                            nativeFactoryId: topFactoryId,
                            nativeHeight: _nativeHeightForFactory(topFactoryId),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }),
                  Expanded(
                    child: PageView.builder(
                      controller: controller.pageController,
                      onPageChanged: controller.onPageChanged,
                      itemCount: controller.pages.length,
                      itemBuilder: (context, index) {
                        final p = controller.pages[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 35,
                                child: Center(
                                  child: Image.asset(
                                    p.assetPath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.titleKey.tr,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.black,
                                    ),
                              ),
                              const Spacer(flex: 2),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Obx(
                          () => _PageDots(
                            count: controller.pages.length,
                            activeIndex: controller.currentPage.value,
                          ),
                        ),
                        Obx(() {
                          final last =
                              controller.currentPage.value ==
                              controller.pages.length - 1;
                          if (last && !controller.showGetStartedButton) {
                            return const SizedBox.shrink();
                          }
                          return _GradientNextButton(
                            text: last ? 'get_started'.tr : 'next'.tr,
                            onPressed: controller.next,
                          );
                        }),
                      ],
                    ),
                  ),
                  // Bottom-fixed ad (screen attached). Dots + Next stay above it.
                  Obx(() {
                    // Rebuild when Remote Config flags get refreshed.
                    ads.configVersion.value;
                    final keyName = _onboardingKeyForCurrentPage(controller);
                    if (!_showBottomAd(ads, keyName)) {
                      return const SizedBox.shrink();
                    }
                    final bottomFactoryId = _pickNativeFactoryIdForOnboardingBottom(
                      ads,
                      keyName,
                    );
                    return RaceBannerNativeSlot(
                      key: ValueKey('onboarding_bottom_slot_$keyName'),
                      bannerEnabled: ads.onboardingBottomBannerOn(keyName),
                      nativeEnabled: bottomFactoryId != null,
                      bannerUnitId: ads.onboardingBannerId,
                      nativeUnitId: ads.onboardingNativeId,
                      debugLabel: 'onboarding_bottom_slot_$keyName',
                      nativeFactoryId: bottomFactoryId,
                      nativeHeight: _nativeHeightForFactory(bottomFactoryId),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _pickNativeFactoryIdForOnboardingBottom(
  AdsRemoteConfigService ads,
  String onboardingKey,
) {
  if (ads.onboardingBottomNativeAdvancedButtonBottomOn(onboardingKey)) {
    return 'native_advance_button_bottom';
  }
  if (ads.onboardingBottomNativeSmallButtonBottomOn(onboardingKey)) {
    return 'native_small_button_bottom';
  }
  if (ads.onboardingBottomNativeSmallInlineOn(onboardingKey)) {
    return 'native_small_inline';
  }
  return null;
}

String? _pickNativeFactoryIdForOnboardingTop(
  AdsRemoteConfigService ads,
  String onboardingKey,
) {
  if (ads.onboardingTopNativeAdvancedButtonBottomOn(onboardingKey)) {
    return 'native_advance_button_bottom';
  }
  if (ads.onboardingTopNativeSmallButtonBottomOn(onboardingKey)) {
    return 'native_small_button_bottom';
  }
  if (ads.onboardingTopNativeSmallInlineOn(onboardingKey)) {
    return 'native_small_inline';
  }
  return null;
}

bool _showBottomAd(AdsRemoteConfigService ads, String onboardingKey) {
  final bottomNativeFactory = _pickNativeFactoryIdForOnboardingBottom(
    ads,
    onboardingKey,
  );
  return ads.onboardingBottomBannerOn(onboardingKey) || bottomNativeFactory != null;
}

bool _showTopAd(AdsRemoteConfigService ads, String onboardingKey) {
  if (_showBottomAd(ads, onboardingKey)) return false;
  final topNativeFactory = _pickNativeFactoryIdForOnboardingTop(
    ads,
    onboardingKey,
  );
  return ads.onboardingTopBannerOn(onboardingKey) || topNativeFactory != null;
}

String _onboardingKeyForCurrentPage(OnboardingController controller) {
  final index = controller.currentPage.value.clamp(0, controller.pages.length - 1);
  return AdsRemoteConfigService.onboardingKeyForIndex(index);
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

class _GradientNextButton extends StatelessWidget {
  const _GradientNextButton({required this.text, required this.onPressed});

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.onboardingNextButtonGradient,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: active ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.onboardingDotActive
                  : AppColors.onboardingDotInactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
