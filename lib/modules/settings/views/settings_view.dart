import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../../../widgets/settings_gradient_switch.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key, this.embeddedInShell = false});

  /// When true (home bottom nav), no [Scaffold] / app bar — parent provides chrome.
  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final homeController = Get.find<HomeController>();
    final bottomNativeFactory = _pickNativeFactoryIdForSettingsBottom(ads);
    final showBottomAd =
        ads.settingsBottomBannerOn || bottomNativeFactory != null;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Obx(() {
          final isPremium = Get.isRegistered<SubscriptionService>() &&
              Get.find<SubscriptionService>().isPremium.value;
          if (isPremium) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _PremiumCard(onTap: controller.openPremium),
          );
        }),
        if (ads.languageScreenOn) ...[
          Obx(
            () => _SettingsTile(
              iconAsset: 'assets/setting/ic_lang.svg',
              label: 'settings_language'.tr,
              subtitle: controller.languageSubtitle.value,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: controller.openLanguage,
            ),
          ),
        ],
        _SettingsTile(
          iconAsset: 'assets/setting/ic_help.svg',
          label: 'settings_how_to_use'.tr,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: controller.openHowToUse,
        ),
        Obx(
          () => _CallScheduleRow(
            value: controller.selectedCallSchedule.value,
            options: controller.callScheduleOptions,
            onChanged: controller.setCallSchedule,
          ),
        ),
        Obx(
          () => _SettingsTile(
            iconAsset: 'assets/setting/ic_flash.svg',
            label: 'settings_flash'.tr,
            trailing: SettingsGradientSwitch(
              value: controller.flashEnabled.value,
              onChanged: controller.toggleFlash,
            ),
          ),
        ),
        Obx(
          () => _SettingsTile(
            iconAsset: 'assets/setting/ic_sound.svg',
            label: 'settings_sound'.tr,
            subtitle: 'settings_ringtone_system'.tr,
            trailing: SettingsGradientSwitch(
              value: controller.soundEnabled.value,
              onChanged: controller.toggleSound,
            ),
          ),
        ),
        Obx(
          () => _SettingsTile(
            iconAsset: 'assets/setting/ic_vibrate.svg',
            label: 'settings_vibrate'.tr,
            trailing: SettingsGradientSwitch(
              value: controller.vibrateEnabled.value,
              onChanged: controller.toggleVibrate,
            ),
          ),
        ),
        if (ads.shouldShowPrivacyPolicyInSettings) ...[
          _SettingsTile(
            iconAsset: 'assets/setting/ic_privachy.svg',
            label: 'settings_privacy_policy'.tr,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: controller.openPrivacyPolicy,
          ),
        ],
        _SettingsTile(
          iconAsset: 'assets/setting/ic_rate.svg',
          label: 'settings_rate_us'.tr,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: controller.openRateUs,
        ),
      ],
    );

    if (embeddedInShell) {
      return ColoredBox(
        color: AppColors.white,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Column(
            children: [
              Expanded(child: list),
              if (showBottomAd)
                Obx(() {
                  if (homeController.bottomNavIndex.value != 2) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      RaceBannerNativeSlot(
                        bannerEnabled: ads.settingsBottomBannerOn,
                        nativeEnabled: bottomNativeFactory != null,
                        bannerUnitId: ads.settingsBannerId,
                        nativeUnitId: ads.settingsNativeId,
                        debugLabel: 'settings_bottom_embedded',
                        nativeFactoryId: bottomNativeFactory,
                        nativeHeight: _nativeHeightForFactory(
                          bottomNativeFactory,
                        ),
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: GradientAppBar(
        title: 'settings_title'.tr,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            width: 22,
            height: 22,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: list),
            if (showBottomAd) ...[
              const SizedBox(height: 8),
              RaceBannerNativeSlot(
                bannerEnabled: ads.settingsBottomBannerOn,
                nativeEnabled: bottomNativeFactory != null,
                bannerUnitId: ads.settingsBannerId,
                nativeUnitId: ads.settingsNativeId,
                debugLabel: 'settings_bottom_standalone',
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

String? _pickNativeFactoryIdForSettingsBottom(AdsRemoteConfigService ads) {
  if (ads.settingsBottomNativeAdvancedButtonBottomOn) {
    return 'native_advance_button_bottom';
  }
  if (ads.settingsBottomNativeSmallButtonBottomOn) {
    return 'native_small_button_bottom';
  }
  if (ads.settingsBottomNativeSmallInlineOn) return 'native_small_inline';
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

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/premium/premium_card.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.appBarGradient,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'settings_premium_title'.tr,
                      style: textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'settings_premium_subtitle'.tr,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(28),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Ink(
                            height: 35,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Center(
                              child: Text(
                                'settings_premium_cta'.tr,
                                style: textTheme.titleMedium?.copyWith(
                                  color: AppColors.gradientAppBarEnd,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallScheduleRow extends StatelessWidget {
  const _CallScheduleRow({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              gradient: AppColors.appBarGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.call_rounded,
              color: AppColors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'settings_call_schedule'.tr,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: false,
              alignment: AlignmentDirectional.centerEnd,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted55,
                fontWeight: FontWeight.w500,
              ),
              selectedItemBuilder: (_) => options
                  .map(
                    (e) => Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        e,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              items: options
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Row(
                        children: [
                          Icon(
                            value == e
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                            color: value == e
                                ? AppColors.gradientAppBarMid
                                : AppColors.textMuted45,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            e,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textMuted55),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                onChanged(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.iconAsset,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 44,
              height: 44,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted55,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
