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
              PageView.builder(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                itemCount: controller.pages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        controller.pages[index].assetPath,
                        fit: BoxFit.fill,
                        alignment: Alignment.topCenter,
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00FFFFFF),
                              Color(0xBFFFFFFF),
                              Color(0xFFFFFFFF),
                            ],
                            stops: [0.45, 0.78, 1.0],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              Obx(() {
                ads.configVersion.value;
                final keyName = _onboardingKeyForCurrentPage(controller);
                final bottomReserve = _bottomAdReserve(ads, keyName);
                final safeBottom = MediaQuery.paddingOf(context).bottom;
                final controlsBottom =
                    bottomReserve + (safeBottom > 0 ? 6 : 16);
                final noAdExtraLift = bottomReserve == 0 ? 8.0 : 0.0;
                const controlsHeightEstimate = 60.0;
                final bottomPadForText = controlsBottom +
                    noAdExtraLift +
                    controlsHeightEstimate;
                final current =
                    controller.pages[controller.currentPage.value.clamp(
                      0,
                      controller.pages.length - 1,
                    )];
                final isLastPage =
                    controller.currentPage.value >= controller.pages.length - 1;
                // Keep a larger visual gap on the last page where the full-width button is shown.
                final contentToControlsGap = isLastPage ? 106.0 : 84.0;
                final hasOnboardingAd =
                    _showTopAd(ads, keyName) || _showBottomAd(ads, keyName);
                final h = MediaQuery.sizeOf(context).height;

                final titleBlock = [
                  _PageDots(
                    count: controller.pages.length,
                    activeIndex: controller.currentPage.value,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    current.titleKey.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                ];

                // No ads: vertically center the title in the free band (below artwork, above buttons).
                if (!hasOnboardingAd) {
                  return Positioned(
                    left: 28,
                    right: 28,
                    top: h * 0.42,
                    bottom: bottomPadForText,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: titleBlock,
                      ),
                    ),
                  );
                }

                return Positioned(
                  left: 28,
                  right: 28,
                  bottom: controlsBottom + contentToControlsGap,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: titleBlock,
                  ),
                );
              }),
              Obx(() {
                ads.configVersion.value;
                final keyName = _onboardingKeyForCurrentPage(controller);
                final bottomReserve = _bottomAdReserve(ads, keyName);
                final safeBottom = MediaQuery.paddingOf(context).bottom;
                // When ads are hidden (premium / remote off), keep controls comfortably above edge.
                final noAdExtraLift = bottomReserve == 0 ? 8.0 : 0.0;
                return Positioned(
                  left: 24,
                  right: 24,
                  bottom:
                      bottomReserve +
                      (safeBottom > 0 ? 6 : 16) +
                      noAdExtraLift,
                  child: _OnboardingControls(
                    activeIndex: controller.currentPage.value,
                    showGetStartedButton: controller.showGetStartedButton,
                    onNext: controller.next,
                    onPrevious: controller.previous,
                  ),
                );
              }),
              // Keep ads behavior unchanged.
              Align(
                alignment: Alignment.topCenter,
                child: Obx(() {
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
                      RaceBannerNativeSlot(
                        key: ValueKey('onboarding_top_slot_$keyName'),
                        bannerEnabled: ads.onboardingTopBannerOn(keyName),
                        nativeEnabled: topFactoryId != null,
                        bannerUnitId: ads.onboardingBannerId,
                        nativeUnitId: ads.onboardingNativeId,
                        debugLabel: 'onboarding_top_slot_$keyName',
                        nativeFactoryId: topFactoryId,
                        nativeHeight: _nativeHeightForFactory(topFactoryId),
                      ),
                    ],
                  );
                }),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Obx(() {
                  ads.configVersion.value;
                  final keyName = _onboardingKeyForCurrentPage(controller);
                  if (!_showBottomAd(ads, keyName)) {
                    return const SizedBox.shrink();
                  }
                  final bottomFactoryId =
                      _pickNativeFactoryIdForOnboardingBottom(ads, keyName);
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
  return ads.onboardingBottomBannerOn(onboardingKey) ||
      bottomNativeFactory != null;
}

double _bottomAdReserve(AdsRemoteConfigService ads, String onboardingKey) {
  if (!_showBottomAd(ads, onboardingKey)) return 0;
  final bottomNativeFactory = _pickNativeFactoryIdForOnboardingBottom(
    ads,
    onboardingKey,
  );
  if (bottomNativeFactory != null)
    return _nativeHeightForFactory(bottomNativeFactory) + 8;
  // Banner-only slot fallback.
  return 58;
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
  final index = controller.currentPage.value.clamp(
    0,
    controller.pages.length - 1,
  );
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

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.activeIndex,
    required this.showGetStartedButton,
    required this.onNext,
    required this.onPrevious,
  });

  final int activeIndex;
  final bool showGetStartedButton;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Widget build(BuildContext context) {
    final last = activeIndex == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: last
          ? (showGetStartedButton
                ? SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: _GradientButton(
                      onPressed: onNext,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Spacer(),
                          Text(
                            'continue_btn'.tr,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          Spacer(),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.white,
                            size: 30,
                          ),
                          const SizedBox(width: 20),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink())
          : Row(
              mainAxisAlignment: activeIndex > 0
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (activeIndex > 0)
                  _OutlinedArrowButton(onPressed: onPrevious),
                _GradientArrowButton(onPressed: onNext),
              ],
            ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.onPressed, required this.child});

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _GradientArrowButton extends StatelessWidget {
  const _GradientArrowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: _GradientButton(
        onPressed: onPressed,
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _OutlinedArrowButton extends StatelessWidget {
  const _OutlinedArrowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.black.withValues(alpha: 0.12),
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textMuted55,
                size: 22,
              ),
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
