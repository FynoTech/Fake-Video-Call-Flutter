import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_assets.dart';
import '../../../app/theme/app_colors.dart';

/// "Main Features" collage on the home screen: one tall card on the
/// left (Fake Video Call) and two stacked small cards on the right
/// (Fake Audio Call, Fake Messages).
class HomeMainFeaturesSection extends StatelessWidget {
  const HomeMainFeaturesSection({
    super.key,
    this.onVideoTap,
    this.onAudioTap,
    this.onMessagesTap,
  });

  final VoidCallback? onVideoTap;
  final VoidCallback? onAudioTap;
  final VoidCallback? onMessagesTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'home_section_main_features'.tr),
        const SizedBox(height: 14),
        SizedBox(
          height: 240,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FeatureCard(
                  gradient: AppColors.featureVideoGradient,
                  iconAsset: AppAssets.icHomeVideo,
                  title: 'feature_video_title'.tr,
                  subtitle: 'feature_video_subtitle'.tr,
                  large: true,
                  onTap: onVideoTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _FeatureCard(
                        gradient: AppColors.featureAudioGradient,
                        iconAsset: AppAssets.icHomeAudio,
                        title: 'feature_audio_title'.tr,
                        subtitle: 'feature_audio_subtitle'.tr,
                        onTap: onAudioTap,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _FeatureCard(
                        gradient: AppColors.featureMessageGradient,
                        iconAsset: AppAssets.icHomeMsg,
                        title: 'feature_messages_title'.tr,
                        subtitle: 'feature_messages_subtitle'.tr,
                        onTap: onMessagesTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 22,
          decoration: BoxDecoration(
            gradient: AppColors.featureVideoGradient,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.gradient,
    required this.iconAsset,
    required this.title,
    required this.subtitle,
    this.large = false,
    this.onTap,
  });

  final LinearGradient gradient;
  final String iconAsset;
  final String title;
  final String subtitle;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(17);
    return Material(
      color: AppColors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: gradient.colors.last.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(
              left: large ? 12 : 12,
              right: large ? 16 : 40,
              top: large ? 12 : 10,
              bottom: large ? 12 : 12,
            ),
            child: large
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconTile(asset: iconAsset, size: 90, iconSize: 44),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _IconTile(asset: iconAsset, size: 46, iconSize: 30),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
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

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.asset,
    required this.size,
    required this.iconSize,
  });

  final String asset;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
