import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../controllers/language_controller.dart';

class LanguageView extends GetView<LanguageController> {
  const LanguageView({super.key});

  static const _cardRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final topNativeFactory = _pickNativeFactoryIdForLanguageTop(ads);
    final bottomNativeFactory = _pickNativeFactoryIdForLanguageBottom(ads);
    final topHasAny = ads.languageTopBannerOn || topNativeFactory != null;
    final bottomHasAny = ads.languageBottomBannerOn || bottomNativeFactory != null;
    // One ad at a time: bottom wins if enabled; otherwise show top (if enabled).
    final showBottom = bottomHasAny;
    final showTop = !bottomHasAny && topHasAny;
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: GradientAppBar(
        title: 'language_title'.tr,
        centerTitle: false,
        actions: [
          Obx(() {
            final hasSelection = controller.selectedCode.value != null;
            if (!hasSelection) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 18),
              child: InkWell(
                onTap: controller.confirm,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 25,
                  height: 25,
                  child: Center(
                    child: Image.asset(
                      'assets/ic_done.png',
                      width: 21,
                      height: 21,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top ads (only if enabled remotely).
            if (showTop) ...[
              RaceBannerNativeSlot(
                bannerEnabled: ads.languageTopBannerOn,
                nativeEnabled: topNativeFactory != null,
                bannerUnitId: ads.languageBannerId,
                nativeUnitId: ads.languageNativeId,
                debugLabel: 'language_top_slot',
                nativeFactoryId: topNativeFactory,
                nativeHeight: _nativeHeightForFactory(topNativeFactory),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Obx(() {
                  final selectedCode = controller.selectedCode.value;
                  return ListView.separated(
                    padding: const EdgeInsets.only(top: 15, bottom: 20),
                    itemCount: controller.options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final o = controller.options[index];
                      final selected = selectedCode == o.code;
                      return _LanguageTile(
                        flagAsset: o.flagAsset,
                        label: o.label,
                        selected: selected,
                        onTap: () => controller.select(o.code),
                      );
                    },
                  );
                }),
              ),
            ),
            // Bottom ads (independently controlled).
            if (showBottom) ...[
              const SizedBox(height: 8),
              RaceBannerNativeSlot(
                bannerEnabled: ads.languageBottomBannerOn,
                nativeEnabled: bottomNativeFactory != null,
                bannerUnitId: ads.languageBannerId,
                nativeUnitId: ads.languageNativeId,
                debugLabel: 'language_bottom_slot',
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

String? _pickNativeFactoryIdForLanguageTop(AdsRemoteConfigService ads) {
  // Priority order (first ON wins).
  if (ads.languageTopNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.languageTopNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.languageTopNativeSmallInlineOn) return 'native_small_inline';
  return null;
}

String? _pickNativeFactoryIdForLanguageBottom(AdsRemoteConfigService ads) {
  if (ads.languageBottomNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.languageBottomNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.languageBottomNativeSmallInlineOn) return 'native_small_inline';
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

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.flagAsset,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String flagAsset;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LanguageView._cardRadius),
        child: AnimatedContainer(
          height: 65,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.languageCardSelectedFill
                : AppColors.white,
            borderRadius: BorderRadius.circular(LanguageView._cardRadius),
            border: Border.all(
              color: selected
                  ? AppColors.languageSelectedAccent
                  : AppColors.languageCardBorderUnselected,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.asset(
                  flagAsset,
                  width: 25,
                  height: 20,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.black87,
                  ),
                ),
              ),
              _LanguageRadio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageRadio extends StatelessWidget {
  const _LanguageRadio({required this.selected});

  final bool selected;

  static const _outer = 22.0;
  static const _borderW = 2.0;
  static const _innerDot = 9.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: selected
          ? SizedBox(
              key: const ValueKey('on'),
              width: _outer,
              height: _outer,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                  border: Border.all(
                    color: AppColors.languageSelectedAccent,
                    width: _borderW,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: _innerDot,
                    height: _innerDot,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.languageSelectedAccent,
                    ),
                  ),
                ),
              ),
            )
          : SizedBox(
              key: const ValueKey('off'),
              width: _outer,
              height: _outer,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.transparent,
                  border: Border.all(
                    color: AppColors.languageRadioBorderUnselected,
                    width: _borderW,
                  ),
                ),
              ),
            ),
    );
  }
}
