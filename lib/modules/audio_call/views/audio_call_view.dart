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
import '../controllers/audio_call_controller.dart';

const double _kFixedCallNativeAdHeight = 100;

double _callBottomNativeReserve(BuildContext _) => _kFixedCallNativeAdHeight;

class AudioCallView extends GetView<AudioCallController> {
  const AudioCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    return Obx(() {
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
                      Container(
                        color: AppColors.black.withValues(alpha: 0.35),
                      ),
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(height: 40),
                            _CallerHeader(controller: controller),
                            const Spacer(),
                            Obx(() {
                              final p = controller.phase.value;
                              if (p == AudioCallPhase.incoming ||
                                  p == AudioCallPhase.playing) {
                                return _BottomCallActions(
                                  onReject: controller.onReject,
                                  onAccept: controller.onAccept,
                                  acceptEnabled: p == AudioCallPhase.incoming &&
                                      !controller.acceptInProgress.value,
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
    });
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
      return Image(
        image: CachedNetworkImageProvider(networkUrl!),
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

  Widget _avatar(String? networkUrl, String? filePath, String assetFallback) {
    if (networkUrl != null && networkUrl.isNotEmpty) {
      return ClipOval(
        child: SizedBox(
          width: _r * 2,
          height: _r * 2,
          child: Image(
            image: CachedNetworkImageProvider(networkUrl),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              assetFallback,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    if (!kIsWeb &&
        filePath != null &&
        filePath.isNotEmpty &&
        File(filePath).existsSync()) {
      return ClipOval(
        child: SizedBox(
          width: _r * 2,
          height: _r * 2,
          child: Image.file(
            File(filePath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Image.asset(
              assetFallback,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: _r * 2,
        height: _r * 2,
        child: Image.asset(assetFallback, fit: BoxFit.cover),
      ),
    );
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
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.95),
                width: 2,
              ),
            ),
            child: _avatar(networkUrl, filePath, assetFb),
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
          if (phase == AudioCallPhase.playing ||
              phase == AudioCallPhase.ended) ...[
            const SizedBox(height: 14),
            Container(
              width: 140,
              height: 1,
              color: AppColors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              phase == AudioCallPhase.ended
                  ? 'call_ended_message'.tr
                  : AudioCallController.formatCallElapsed(
                      controller.position.value,
                    ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w400,
                    fontSize: 22,
                    letterSpacing: 0.5,
                  ),
            ),
          ],
        ],
      );
    });
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
        child: FilledButton(
          onPressed: () => onCallAgain(),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.callAgainPillBlue,
            foregroundColor: AppColors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.white,
                ),
          ),
          child: Text('call_again'.tr),
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
            color: const Color(0xFFE02424),
            icon: Icons.call_end_rounded,
            label: 'call_reject'.tr,
            enabled: true,
            onTap: () => onReject(),
          ),
          _CallButton(
            color: const Color(0xFF16A34A),
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
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

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
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white.withValues(
                      alpha: enabled ? 1 : 0.45,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
