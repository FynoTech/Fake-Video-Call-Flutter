import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
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
    final bottomHasAny =
        ads.languageBottomBannerOn || bottomNativeFactory != null;
    // One ad at a time: bottom wins if enabled; otherwise show top (if enabled).
    final showBottom = bottomHasAny;
    final showTop = !bottomHasAny && topHasAny;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 14,
        title: Text(
          'language_title'.tr,
          style: const TextStyle(
            fontFamily: 'Audiowide',
            fontSize: 18,
            color: AppColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: IconButton(
            onPressed: () => Get.back(),
            splashRadius: 20,
            icon: SvgPicture.asset(
              'assets/setting/ic_back.svg',
              matchTextDirection: true,
              width: 35,
              height: 35,
            ),
          ),
        ),
        actions: [
          Obx(() {
            if (controller.selectedCode.value == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: controller.confirm,
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.primaryColor,
                  ),
                  child: Text(
                    'language_done'.tr,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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
                  return Column(
                    children: [
                      const SizedBox(height: 4),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 8, bottom: 18),
                          itemCount: controller.options.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final o = controller.options[index];
                            final selected = selectedCode == o.code;
                            return _LanguageTile(
                              flagAssetPath: o.flagAssetPath,
                              label: o.label,
                              selected: selected,
                              onTap: () => controller.select(o.code),
                            );
                          },
                        ),
                      ),
                    ],
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

/// Flat flag icon in a circular frame.
class _CircularFlagIcon extends StatelessWidget {
  const _CircularFlagIcon({required this.assetPath});

  final String assetPath;

  static const double _size = 50;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: ClipOval(
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          assetPath,
          width: _size,
          height: _size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.flagAssetPath,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String flagAssetPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                _CircularFlagIcon(assetPath: flagAssetPath),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: AppColors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                _LanguageRadio(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageRadio extends StatelessWidget {
  const _LanguageRadio({required this.selected});

  final bool selected;

  static const _outer = 32.0;
  static const _borderW = 2.0;

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
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primaryColor,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            )
          : SizedBox(
              key: const ValueKey('off'),
              width: _outer,
              height: _outer,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
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
