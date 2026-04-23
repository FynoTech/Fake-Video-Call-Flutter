import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../controllers/home_controller.dart';
import '../widgets/vfc_celebrities_section.dart';

/// Full-screen browse for all VFC JSON categories (from home “See All”).
class VfcBrowseView extends StatefulWidget {
  const VfcBrowseView({super.key});

  @override
  State<VfcBrowseView> createState() => _VfcBrowseViewState();
}

class _VfcBrowseViewState extends State<VfcBrowseView> {
  late int _index;

  @override
  void initState() {
    super.initState();
    final c = Get.find<HomeController>();
    final len = c.vfcCatalog.value?.categories.length ?? 0;
    _index = len <= 0 ? 0 : c.vfcSelectedCategoryIndex.value.clamp(0, len - 1);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    final ads = Get.find<AdsRemoteConfigService>();
    final bottomNativeFactory = _pickNativeFactoryIdForBrowseBottom(ads);
    final showBottomAd = ads.homeSeeAllBottomBannerOn || bottomNativeFactory != null;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: Row(
          children: [
            _BrowseBackButton(onTap: () => Get.back()),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'home_section_trending_calls'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Audiowide',
                  fontSize: 24,
                  color: AppColors.black,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Obx(() {
                final catalog = controller.vfcCatalog.value;
                if (catalog == null) {
                  return const Center(child: AppLoadingIndicator(size: 40));
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: VfcCelebritiesSection(
                    catalog: catalog,
                    selectedCategoryIndex: _index,
                    onCategoryChanged: (i) {
                      setState(() => _index = i);
                      controller.selectVfcCategory(i);
                    },
                    onCelebrityTap: (person, {forceWatchAdGate = false}) =>
                        controller.openVideoCall(
                          person,
                          forceWatchAdGate: forceWatchAdGate,
                        ),
                    extraPersonsForSelected: catalog.categories.isEmpty
                        ? const []
                        : controller.customPersonsForCategory(
                            catalog.categories[
                                    _index.clamp(0, catalog.categories.length - 1)]
                                .id,
                          ),
                    expandGrid: true,
                    avatarSize: 72,
                  ),
                );
              }),
            ),
            Obx(() {
              final isPremium = Get.isRegistered<SubscriptionService>() &&
                  Get.find<SubscriptionService>().isPremium.value;
              if (isPremium || !showBottomAd) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: RaceBannerNativeSlot(
                  bannerEnabled: ads.homeSeeAllBottomBannerOn,
                  nativeEnabled: bottomNativeFactory != null,
                  bannerUnitId: ads.homeBannerId,
                  nativeUnitId: ads.homeNativeId,
                  debugLabel: 'home_see_all_bottom',
                  nativeFactoryId: bottomNativeFactory,
                  nativeHeight: _nativeHeightForFactory(bottomNativeFactory),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

String? _pickNativeFactoryIdForBrowseBottom(AdsRemoteConfigService ads) {
  if (ads.homeSeeAllBottomNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.homeSeeAllBottomNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.homeSeeAllBottomNativeSmallInlineOn) return 'native_small_inline';
  return null;
}

class _BrowseBackButton extends StatelessWidget {
  const _BrowseBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 20,
      icon: SvgPicture.asset(
        'assets/setting/ic_back.svg',
        width: 24,
        height: 24,
      ),
    );
  }
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
