import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key, this.embeddedInShell = false});

  /// When true (home bottom nav), no [Scaffold] / app bar — parent provides chrome.
  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width <= 360;
    final sidePad = isCompact ? 14.0 : 18.0;
    final ads = Get.find<AdsRemoteConfigService>();
    final homeController = Get.find<HomeController>();
    final bottomNativeFactory = _pickNativeFactoryIdForSettingsBottom(ads);
    final showBottomAd =
        ads.settingsBottomBannerOn || bottomNativeFactory != null;
    final list = ListView(
      padding: EdgeInsets.fromLTRB(sidePad, 16, sidePad, 24),
      children: [
        Obx(() {
          final isPremium =
              Get.isRegistered<SubscriptionService>() &&
              Get.find<SubscriptionService>().isPremium.value;
          if (isPremium) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: _PremiumCard(
              onTap: controller.openPremium,
              compact: isCompact,
            ),
          );
        }),
        if (ads.languageScreenOn) ...[
          Text(
            'settings_general_section'.tr,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Color(0xffA7A7A7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            child: _SettingsTile(
              iconAsset: 'assets/setting/ic_lang_custom.png',
              fallbackIcon: Icons.translate_rounded,
              label: 'settings_language'.tr,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFD5D5D8),
              ),
              onTap: controller.openLanguage,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _SettingsCard(
              child: _SettingsTile(
                iconAsset: 'assets/setting/ic_flash_custom.png',
                fallbackIcon: Icons.flash_on_rounded,
                label: 'settings_flash'.tr,
                trailing: Switch(
                  value: controller.flashEnabled.value,
                  onChanged: controller.toggleFlash,
                  activeColor: AppColors.primaryColor,
                  inactiveThumbColor: const Color(0xFFD9D9D9),
                  activeTrackColor: const Color(0xFFF2E5FF),
                  inactiveTrackColor: const Color(0xFFF0F0F0),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  trackOutlineWidth: WidgetStateProperty.all(0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _SettingsCard(
              child: _SettingsTile(
                iconAsset: 'assets/setting/ic_vibrate_custom.png',
                fallbackIcon: Icons.vibration_rounded,
                label: 'settings_vibrate'.tr,
                trailing: Switch(
                  value: controller.vibrateEnabled.value,
                  onChanged: controller.toggleVibrate,
                  activeColor: AppColors.primaryColor,
                  inactiveThumbColor: const Color(0xFFD9D9D9),
                  activeTrackColor: const Color(0xFFF2E5FF),
                  inactiveTrackColor: const Color(0xFFF0F0F0),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  trackOutlineWidth: WidgetStateProperty.all(0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => _SettingsCard(
              child: _SettingsTile(
                iconAsset: 'assets/setting/ic_sound.png',
                fallbackIcon: Icons.surround_sound_outlined,
                label: 'settings_sound'.tr,
                trailing: Switch(
                  value: controller.soundEnabled.value,
                  onChanged: controller.toggleSound,
                  activeColor: AppColors.primaryColor,
                  inactiveThumbColor: const Color(0xFFD9D9D9),
                  activeTrackColor: const Color(0xFFF2E5FF),
                  inactiveTrackColor: const Color(0xFFF0F0F0),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                  trackOutlineWidth: WidgetStateProperty.all(0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'settings_support_section'.tr,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Color(0xffA7A7A7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        _SettingsCard(
          child: _SettingsTile(
            iconAsset: 'assets/setting/ic_more_apps_custom.png',
            fallbackIcon: Icons.star_rounded,
            label: 'settings_rate_us'.tr,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD5D5D8),
            ),
            onTap: controller.openRateUs,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: _SettingsTile(
            iconAsset: 'assets/setting/ic_share_custom.png',
            fallbackIcon: Icons.share_rounded,
            label: 'settings_share_app'.tr,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD5D5D8),
            ),
            onTap: controller.openRateUs,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: _SettingsTile(
            iconAsset: 'assets/setting/ic_privacy_custom.png',
            fallbackIcon: Icons.privacy_tip_outlined,
            label: 'settings_privacy_policy'.tr,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD5D5D8),
            ),
            onTap: controller.openPrivacyPolicy,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsCard(
          child: _SettingsTile(
            iconAsset: 'assets/setting/ic_rate_custom.png',
            fallbackIcon: Icons.apps_rounded,
            label: 'settings_more_apps'.tr,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFD5D5D8),
            ),
            onTap: controller.openMoreApps,
          ),
        ),
      ],
    );

    if (embeddedInShell) {
      return ColoredBox(
        color: AppColors.white,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
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
                  const SizedBox(height: 8),
                  Obx(
                    () => _SettingsVersionFooter(
                      label: controller.appVersionLabel.value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 84,
        titleSpacing: 20,
        leadingWidth: 44,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            matchTextDirection: true,
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              AppColors.black,
              BlendMode.srcIn,
            ),
          ),
        ),
        title: Text(
          'settings_title'.tr,
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
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                const SizedBox(height: 8),
                Obx(
                  () => _SettingsVersionFooter(
                    label: controller.appVersionLabel.value,
                  ),
                ),
              ],
            ),
          ),
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

class _SettingsVersionFooter extends StatelessWidget {
  const _SettingsVersionFooter({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF9F9FA6),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

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
                  'assets/premium/ic_pro_card_bg.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.appBarGradient,
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 14 : 18,
                  compact ? 12 : 16,
                  compact ? 12 : 16,
                  compact ? 12 : 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'settings_upgrade_to'.tr,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'settings_pro'.tr,
                            style: textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF2D80C9),
                              fontWeight: FontWeight.w800,
                              fontSize: compact ? 20 : 24,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'settings_get_unlimited_access'.tr,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.95),
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.w500,
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
          SvgPicture.asset(
            'assets/setting/ic_schedule.svg',
            width: 44,
            height: 44,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryColor,
              BlendMode.srcIn,
            ),
            placeholderBuilder: (_) => const SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                Icons.schedule_rounded,
                color: AppColors.primaryColor,
                size: 24,
              ),
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: child,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.iconAsset,
    required this.label,
    required this.fallbackIcon,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String iconAsset;
  final String label;
  final IconData fallbackIcon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            _SettingsLeadingIcon(
              iconAsset: iconAsset,
              fallbackIcon: fallbackIcon,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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

class _SettingsLeadingIcon extends StatelessWidget {
  const _SettingsLeadingIcon({
    required this.iconAsset,
    required this.fallbackIcon,
  });

  final String iconAsset;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    if (iconAsset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        iconAsset,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          AppColors.primaryColor,
          BlendMode.srcIn,
        ),
        placeholderBuilder: (_) =>
            Icon(fallbackIcon, color: AppColors.primaryColor, size: 24),
      );
    }

    return Image.asset(
      iconAsset,
      width: 24,
      height: 24,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(fallbackIcon, color: AppColors.primaryColor, size: 24),
    );
  }
}
