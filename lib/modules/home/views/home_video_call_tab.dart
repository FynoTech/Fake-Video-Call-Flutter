import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../../../widgets/app_shimmer.dart';
import '../../../widgets/person_circle_tile.dart';
import '../controllers/home_controller.dart';
import '../widgets/home_section_header.dart';
import '../widgets/vfc_celebrities_section.dart';

/// Main “Video call” home content (live row + celebrity catalog).
class HomeVideoCallTab extends GetView<HomeController> {
  const HomeVideoCallTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final subscription = Get.isRegistered<SubscriptionService>()
        ? Get.find<SubscriptionService>()
        : null;

    return Obx(() {
      final isPremium = subscription?.isPremium.value ?? false;
      final topNativeFactory =
          isPremium ? null : _pickNativeFactoryIdForHomeTop(ads);
      final showTopSlot =
          !isPremium && (ads.homeTopBannerOn || topNativeFactory != null);
      final topNativeHeight = _nativeHeightForFactory(topNativeFactory);
      final bottomNativeFactory =
          isPremium ? null : _pickNativeFactoryIdForHomeInline(ads);
      final showBottomSlot =
          !isPremium && (ads.homeBottomBannerOn || bottomNativeFactory != null);
      final bottomNativeHeight = _nativeHeightForFactory(bottomNativeFactory);
      final bottomSlotHeight = _slotHeightForHome(
        hasBanner: !isPremium && ads.homeBottomBannerOn,
        nativeFactoryId: bottomNativeFactory,
        nativeHeight: bottomNativeHeight,
      );
      final listBottomPadding = showBottomSlot ? (bottomSlotHeight + 18) : 24.0;

      return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(0, 18, 0, listBottomPadding),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HomeSectionHeader(
                title: 'home_section_live_video'.tr,
                actionText: 'see_all'.tr,
                onActionTap: controller.openVfcBrowse,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() {
                final svc = Get.find<PersonsStorageService>();
                final preview = controller.previewPersons;
                final loading = svc.isLoading.value && svc.persons.isEmpty;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 100,
                      child: loading
                          ? const ShimmerLiveVideoRow()
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.horizontal,
                              itemCount: 1 + preview.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return PersonCircleTile(
                                    label: 'nav_custom_call'.tr,
                                    isMore: true,
                                    maxLabelLines: 1,
                                    labelColor: AppColors.black,
                                    onTap: () => controller.selectBottomNav(1),
                                  );
                                }
                                final person = preview[index - 1];
                                final showVideoBadge =
                                    !isPremium && index % 2 == 0;
                                return PersonCircleTile(
                                  label: person.firstName,
                                  imageUrl: person.imageUrl,
                                  maxLabelLines: 1,
                                  labelColor: AppColors.black,
                                  avatarBadge: showVideoBadge
                                      ? const _LiveRowVideoCornerBadge()
                                      : null,
                                  needsNetworkForMedia: isRemoteMediaUrl(
                                    person.videoUrl,
                                  ),
                                  onTap: () => controller.openVideoCall(
                                    person,
                                    forceWatchAdGate: showVideoBadge,
                                  ),
                                );
                              },
                            ),
                    ),
                    if (svc.loadError.value != null && svc.persons.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        svc.loadError.value!,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.black),
                      ),
                      TextButton(
                        onPressed: svc.loadPersons,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.black,
                        ),
                        child: Text('retry'.tr),
                      ),
                    ],
                  ],
                );
              }),
            ),
            if (showTopSlot) ...[
              RaceBannerNativeSlot(
                bannerEnabled: ads.homeTopBannerOn,
                nativeEnabled: topNativeFactory != null,
                bannerUnitId: ads.homeBannerId,
                nativeUnitId: ads.homeNativeId,
                debugLabel: 'home_top_slot',
                nativeFactoryId: topNativeFactory,
                nativeHeight: topNativeHeight,
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HomeSectionHeader(
                title: 'home_section_main_features'.tr,
                actionText: 'see_all'.tr,
                onActionTap: controller.openVfcBrowse,
                pillAction: true,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Obx(() {
                final catalog = controller.vfcCatalog.value;
                final err = controller.vfcLoadError.value;
                if (catalog == null) {
                  if (err != null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          err,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted65),
                        ),
                        TextButton(
                          onPressed: controller.loadVfcCatalog,
                          child: Text('retry'.tr),
                        ),
                      ],
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: AppLoadingIndicator(size: 36)),
                  );
                }
                return VfcCelebritiesSection(
                  catalog: catalog,
                  selectedCategoryIndex:
                      controller.vfcSelectedCategoryIndex.value,
                  onCategoryChanged: controller.selectVfcCategory,
                  onCelebrityTap: (person, {forceWatchAdGate = false}) =>
                      controller.openVideoCall(
                        person,
                        forceWatchAdGate: forceWatchAdGate,
                      ),
                  extraPersonsForSelected: catalog.categories.isEmpty
                      ? const []
                      : controller.customPersonsForCategory(
                          catalog
                              .categories[controller
                                  .vfcSelectedCategoryIndex
                                  .value
                                  .clamp(0, catalog.categories.length - 1)]
                              .id,
                        ),
                );
              }),
            ),
          ],
        ),
        if (showBottomSlot)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(
              () => Visibility(
                visible: controller.bottomNavIndex.value == 0,
                maintainState: false,
                child: SizedBox(
                  height: bottomSlotHeight,
                  child: RaceBannerNativeSlot(
                    bannerEnabled: !isPremium && ads.homeBottomBannerOn,
                    nativeEnabled: bottomNativeFactory != null,
                    bannerUnitId: ads.homeBannerId,
                    nativeUnitId: ads.homeNativeId,
                    debugLabel: 'home_bottom_slot_overlay',
                    nativeFactoryId: bottomNativeFactory,
                    nativeHeight: bottomNativeHeight,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _LiveRowVideoCornerBadge extends StatelessWidget {
  const _LiveRowVideoCornerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: AppColors.gradientAppBarEnd,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.2),
      ),
      child: const Icon(
        Icons.videocam_rounded,
        size: 11,
        color: AppColors.white,
      ),
    );
  }
}

String? _pickNativeFactoryIdForHomeTop(AdsRemoteConfigService ads) {
  if (ads.homeTopNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.homeTopNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.homeTopNativeSmallInlineOn) return 'native_small_inline';
  return null;
}

String? _pickNativeFactoryIdForHomeInline(AdsRemoteConfigService ads) {
  if (ads.homeBottomNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.homeBottomNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.homeBottomNativeSmallInlineOn) return 'native_small_inline';
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

double _slotHeightForHome({
  required bool hasBanner,
  required String? nativeFactoryId,
  required double nativeHeight,
}) {
  if (nativeFactoryId != null) return nativeHeight;
  if (hasBanner) return AdSize.banner.height.toDouble();
  return 0;
}
