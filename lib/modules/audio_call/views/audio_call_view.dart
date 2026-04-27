import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/scalloped_avatar_frame.dart';
import '../controllers/audio_call_controller.dart';

const double _kFixedCallNativeAdHeight = 100;

double _callBottomNativeReserve(BuildContext _) => _kFixedCallNativeAdHeight;

class AudioCallView extends GetView<AudioCallController> {
  const AudioCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        unawaited(controller.onNavigateBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Obx(
                () => Stack(
                  fit: StackFit.expand,
                  children: [
                    _BlurredBackdrop(
                      networkUrl: controller.networkImageUrl.value,
                      filePath: controller.localImagePath.value,
                      assetFallback: AudioCallController.placeholderAsset,
                    ),
                    Container(color: AppColors.black.withValues(alpha: 0.35)),
                    SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(height: 40),
                          _CallerHeader(controller: controller),
                          const Spacer(),
                          Obx(() {
                            final p = controller.phase.value;
                            if (p == AudioCallPhase.incoming) {
                              return _BottomCallActions(
                                onReject: controller.onReject,
                                onAccept: controller.onAccept,
                                acceptEnabled:
                                    p == AudioCallPhase.incoming &&
                                    !controller.acceptInProgress.value,
                              );
                            }
                            if (p == AudioCallPhase.playing) {
                              return _AudioActiveControlsPanel(
                                onEnd: controller.onReject,
                              );
                            }
                            if (p == AudioCallPhase.ended) {
                              return _CallAgainBottomBar(
                                onCallAgain: controller.onCallAgain,
                              );
                            }
                            return const SizedBox(height: 120);
                          }),
                          SizedBox(
                            height: showFixedBottomAd
                                ? _callBottomNativeReserve(context)
                                : 32,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (showFixedBottomAd)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _CallBottomNativeAd(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallBottomNativeAd extends StatelessWidget {
  const _CallBottomNativeAd();

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    if (!ads.callBottomNativeSmallInlineOn) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      left: false,
      right: false,
      bottom: false,
      minimum: EdgeInsets.zero,
      child: SizedBox(
        height: _kFixedCallNativeAdHeight,
        width: double.infinity,
        child: RaceBannerNativeSlot(
          bannerEnabled: false,
          nativeEnabled: true,
          bannerUnitId: '',
          nativeUnitId: ads.callNativeId,
          debugLabel: 'audio_call_fixed_bottom',
          nativeFactoryId: 'native_small_inline',
          nativeHeight: _kFixedCallNativeAdHeight,
          fullWidth: true,
        ),
      ),
    );
  }
}

class _BlurredBackdrop extends StatelessWidget {
  const _BlurredBackdrop({
    required this.networkUrl,
    required this.filePath,
    required this.assetFallback,
  });

  final String? networkUrl;
  final String? filePath;
  final String assetFallback;

  Widget _image() {
    if (networkUrl != null && networkUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorWidget: (_, __, ___) => Image.asset(
          assetFallback,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }
    if (!kIsWeb &&
        filePath != null &&
        filePath!.isNotEmpty &&
        File(filePath!).existsSync()) {
      return Image.file(
        File(filePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Image.asset(
          assetFallback,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }
    return Image.asset(
      assetFallback,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: _image(),
    );
  }
}

class _CallerHeader extends StatelessWidget {
  const _CallerHeader({required this.controller});

  final AudioCallController controller;

  static const double _r = 58;

  static const double _faceDiameter = _r * 2;

  /// Square image; [ScallopedAvatarFrame] applies the circular clip.
  Widget _avatarFace(
    String? networkUrl,
    String? filePath,
    String assetFallback,
  ) {
    final d = _faceDiameter;
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: networkUrl,
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorWidget: (_, __, ___) =>
            Image.asset(assetFallback, fit: BoxFit.cover, width: d, height: d),
      );
    }
    if (!kIsWeb &&
        filePath != null &&
        filePath.isNotEmpty &&
        File(filePath).existsSync()) {
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        width: d,
        height: d,
        errorBuilder: (_, __, ___) =>
            Image.asset(assetFallback, fit: BoxFit.cover, width: d, height: d),
      );
    }
    return Image.asset(assetFallback, fit: BoxFit.cover, width: d, height: d);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final phase = controller.phase.value;
      final name = controller.callerName.value;
      final networkUrl = controller.networkImageUrl.value;
      final filePath = controller.localImagePath.value;
      const assetFb = AudioCallController.placeholderAsset;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScallopedAvatarFrame(
            innerDiameter: _faceDiameter,
            ringColor: AppColors.white.withValues(alpha: 0.96),
            ringBaseWidth: 5.6,
            scallopDepth: 2.85,
            lobes: 14,
            child: _avatarFace(networkUrl, filePath, assetFb),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
              fontSize: 26,
            ),
          ),
          if (phase == AudioCallPhase.incoming) ...[
            const SizedBox(height: 10),
            Text(
              controller.incomingStatusText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.white.withValues(alpha: 0.88),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (phase == AudioCallPhase.playing) ...[
            const SizedBox(height: 8),
            Text(
              AudioCallController.formatCallElapsed(controller.position.value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w400,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
          ],
          if (phase == AudioCallPhase.ended) ...[
            const SizedBox(height: 14),
            Text(
              'call_ended_message'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w400,
                fontSize: 22,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AudioCallController.formatCallElapsed(controller.position.value),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w500,
                fontSize: 18,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _AudioActiveControlsPanel extends StatelessWidget {
  const _AudioActiveControlsPanel({required this.onEnd});

  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0x66464646),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.78),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.mic_off_rounded,
                  label: 'call_control_mute'.tr,
                ),
              ),
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.dialpad_rounded,
                  label: 'call_control_keypad'.tr,
                ),
              ),
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.volume_up_rounded,
                  label: 'call_control_speaker'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.add_rounded,
                  label: 'call_control_add_call'.tr,
                ),
              ),
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.videocam_rounded,
                  label: 'call_control_facetime'.tr,
                ),
              ),
              Expanded(
                child: _AudioControlItem(
                  icon: Icons.person_rounded,
                  label: 'call_control_contacts'.tr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EndAudioCallButton(onTap: () => onEnd()),
        ],
      ),
    );
  }
}

class _AudioControlItem extends StatelessWidget {
  const _AudioControlItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.26),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _EndAudioCallButton extends StatelessWidget {
  const _EndAudioCallButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0290E),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 75,
          height: 75,
          child: Center(
            child: Image.asset(
              'assets/home/ic_call_decline_custom.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _CallAgainBottomBar extends StatelessWidget {
  const _CallAgainBottomBar({required this.onCallAgain});

  final Future<void> Function() onCallAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onCallAgain(),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                border: Border.all(color: AppColors.black, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'call_again'.tr,
                      style: const TextStyle(
                        fontFamily: AppColors.fontFamily,
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Image.asset(
                      'assets/home/ic_call_again_ad.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomCallActions extends StatelessWidget {
  const _BottomCallActions({
    required this.onReject,
    required this.onAccept,
    required this.acceptEnabled,
  });

  final Future<void> Function() onReject;
  final Future<void> Function() onAccept;
  final bool acceptEnabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CallButton(
            color: AppColors.audioCallDecline,
            assetIcon: 'assets/home/ic_call_decline_custom.png',
            icon: Icons.call_end_rounded,
            label: 'call_reject'.tr,
            enabled: true,
            onTap: () => onReject(),
          ),
          _CallButton(
            color: AppColors.audioCallAccept,
            assetIcon: 'assets/home/ic_call_accept_custom.png',
            icon: Icons.call_rounded,
            label: 'call_accept'.tr,
            enabled: acceptEnabled,
            onTap: () => onAccept(),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  const _CallButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.assetIcon,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final String? assetIcon;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(40),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: assetIcon == null
                      ? Icon(icon, color: Colors.white, size: 32)
                      : Image.asset(
                          assetIcon!,
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: enabled ? 1 : 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
