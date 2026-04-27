import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/app_shimmer.dart';
import '../controllers/home_controller.dart';
import '../widgets/add_new_character_card.dart';
import '../widgets/home_main_features_section.dart';
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
      final svc = Get.find<PersonsStorageService>();
      final preview = controller.previewPersons;
      final loading = svc.isLoading.value && svc.persons.isEmpty;
      final trending = preview.take(3).toList();
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
              child: AddNewCharacterCard(
                title: 'add_new_character_title'.tr,
                subtitle: 'add_new_character_subtitle'.tr,
                onTap: () => controller.selectBottomNav(1),
              ),
            ),
            if (showTopSlot) ...[
              const SizedBox(height: 12),
              RaceBannerNativeSlot(
                bannerEnabled: ads.homeTopBannerOn,
                nativeEnabled: topNativeFactory != null,
                bannerUnitId: ads.homeBannerId,
                nativeUnitId: ads.homeNativeId,
                debugLabel: 'home_top_slot',
                nativeFactoryId: topNativeFactory,
                nativeHeight: topNativeHeight,
              ),
            ],
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HomeSectionHeader(
                title: 'home_section_trending_calls'.tr,
                actionText: 'see_all'.tr,
                onActionTap: controller.openVfcBrowse,
                pillAction: true,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (loading)
                    const ShimmerLiveVideoRow()
                  else
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: trending.length,
                      itemBuilder: (context, index) {
                        final person = trending[index];
                        final showVideoBadge =
                            !isPremium && (index + 1) % 3 == 0;
                        return TrendingCelebrityCard(
                          name: person.firstName,
                          imageUrl: person.imageUrl,
                          gradient: kTrendingGradients[
                              index % kTrendingGradients.length],
                          showOnlineDot: true,
                          showVideoBadge: showVideoBadge,
                          onTap: () => controller.openVideoCall(
                            person,
                            forceWatchAdGate: showVideoBadge,
                          ),
                        );
                      },
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
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: HomeMainFeaturesSection(
                onVideoTap: controller.openVfcBrowse,
                onAudioTap: controller.openAudioCallBrowse,
                onMessagesTap: controller.openFakeChatBrowse,
              ),
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
