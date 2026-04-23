import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ads_remote_config_service.dart';
import '../../../widgets/ads/race_banner_native_slot.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../controllers/video_call_controller.dart';

const double _kFixedCallNativeAdHeight = 100;

/// Space reserved so UI clears the bottom native strip; ad is pinned to the physical bottom.
double _callBottomNativeReserve(BuildContext _) => _kFixedCallNativeAdHeight;

class VideoCallView extends GetView<VideoCallController> {
  const VideoCallView({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    return Obx(() {
      final p = controller.phase.value;
      controller.networkImageUrl.value;
      controller.localImagePath.value;
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
                Positioned.fill(
                  child: p == VideoCallPhase.incoming
                      ? _IncomingCallLayer(controller: controller)
                      : _PlayingCallLayer(controller: controller),
                ),
                if (showFixedBottomAd)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: -40,
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

class _IncomingCallLayer extends StatelessWidget {
  const _IncomingCallLayer({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    return Stack(
      fit: StackFit.expand,
      children: [
        _BlurredBackdrop(
          networkUrl: controller.networkImageUrl.value,
          filePath: controller.localImagePath.value,
          assetFallback: VideoCallController.placeholderAsset,
        ),
        Container(color: AppColors.black.withValues(alpha: 0.35)),
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 40),
            _IncomingHeader(controller: controller),
            const Spacer(),
            Obx(
              () => _IncomingBottomActions(
                onReject: controller.onReject,
                onAccept: controller.onAccept,
                acceptEnabled: !controller.acceptInProgress.value,
              ),
            ),
            SizedBox(
              height: showFixedBottomAd
                  ? _callBottomNativeReserve(context)
                  : 32,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlayingCallLayer extends StatelessWidget {
  const _PlayingCallLayer({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.phase.value == VideoCallPhase.ended) {
        return _VideoCallEndedLayer(controller: controller);
      }
      return _VideoCallActiveLayer(controller: controller);
    });
  }
}

/// After hang-up: blurred caller photo, ring avatar, name, status — like incoming layout.
class _VideoCallEndedLayer extends StatelessWidget {
  const _VideoCallEndedLayer({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    return Stack(
      fit: StackFit.expand,
      children: [
        Obx(() {
          return _BlurredBackdrop(
            networkUrl: controller.networkImageUrl.value,
            filePath: controller.localImagePath.value,
            assetFallback: VideoCallController.placeholderAsset,
          );
        }),
        Container(color: AppColors.black.withValues(alpha: 0.38)),
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 36),
              _EndedCallHeader(controller: controller),
              const Spacer(),
              _CallAgainBottomBar(onCallAgain: controller.onCallAgain),
              SizedBox(
                height: showFixedBottomAd
                    ? _callBottomNativeReserve(context)
                    : 28,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EndedCallHeader extends StatelessWidget {
  const _EndedCallHeader({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = controller.callerName.value;
      final networkUrl = controller.networkImageUrl.value;
      final filePath = controller.localImagePath.value;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VideoRingAvatar(
            networkUrl: networkUrl,
            filePath: filePath,
            assetFallback: VideoCallController.placeholderAsset,
            radius: 58,
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
          const SizedBox(height: 10),
          Text(
            'call_ended_message'.tr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w400,
              fontSize: 17,
            ),
          ),
        ],
      );
    });
  }
}

class _VideoCallActiveLayer extends StatelessWidget {
  const _VideoCallActiveLayer({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    final ads = Get.find<AdsRemoteConfigService>();
    final showFixedBottomAd = ads.callBottomNativeSmallInlineOn;
    final pad = MediaQuery.paddingOf(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Obx(() {
            if (!controller.videoReady.value) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  _BlurredBackdrop(
                    networkUrl: controller.networkImageUrl.value,
                    filePath: controller.localImagePath.value,
                    assetFallback: VideoCallController.placeholderAsset,
                  ),
                  Container(color: AppColors.black.withValues(alpha: 0.35)),
                ],
              );
            }
            return ColoredBox(
              color: AppColors.black,
              child: _FullBleedVideo(controller: controller),
            );
          }),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.black.withValues(alpha: 0.55),
                  AppColors.transparent,
                  AppColors.transparent,
                  AppColors.black.withValues(alpha: 0.62),
                ],
                stops: const [0.0, 0.18, 0.62, 1.0],
              ),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: pad.top + 12),
            Obx(() {
              final name = controller.callerName.value;
              return Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              );
            }),
            const SizedBox(height: 8),
            Obx(() {
              final connecting = !controller.videoReady.value;
              return Text(
                connecting
                    ? 'video_call_connecting'.tr
                    : VideoCallController.formatCallElapsed(
                        controller.position.value,
                      ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w400,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              );
            }),
            const Spacer(),
            _VideoCallControlsBar(controller: controller),
            SizedBox(
              height: showFixedBottomAd
                  ? _callBottomNativeReserve(context)
                  : 20,
            ),
          ],
        ),
        if (!kIsWeb)
          Obx(() {
            if (!controller.videoReady.value) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: pad.top + 56,
              right: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 112,
                  height: 150,
                  color: AppColors.black87,
                  child: Obx(() {
                    final liveOn = controller.pipLiveCameraOn.value;
                    final cam = controller.cameraController;
                    final camOk = controller.cameraReady.value && cam != null;
                    if (liveOn && camOk) {
                      return CameraPreview(cam);
                    }
                    if (!liveOn) {
                      return const _PipGenericUserPlaceholder();
                    }
                    return Center(
                      child: Icon(
                        Icons.videocam_off_outlined,
                        color: AppColors.white.withValues(alpha: 0.5),
                        size: 36,
                      ),
                    );
                  }),
                ),
              ),
            );
          }),
      ],
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
          debugLabel: 'video_call_fixed_bottom',
          nativeFactoryId: 'native_small_inline',
          nativeHeight: _kFixedCallNativeAdHeight,
          fullWidth: true,
        ),
      ),
    );
  }
}

/// Same idea as [PersonCircleTile] without image: white fill + brand-blue glyph.
class _PipGenericUserPlaceholder extends StatelessWidget {
  const _PipGenericUserPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.white,
      child: Center(
        child: Icon(
          Icons.person_rounded,
          size: 64,
          color: AppColors.gradientAppBarEnd,
        ),
      ),
    );
  }
}

class _FullBleedVideo extends StatelessWidget {
  const _FullBleedVideo({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    final vp = controller.videoPlayer;
    if (vp == null) {
      return const ColoredBox(color: AppColors.black);
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: vp,
      builder: (context, value, _) {
        if (value.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                value.errorDescription ?? 'Video failed',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          );
        }
        if (!value.isInitialized) {
          return const Center(child: AppLoadingIndicator(size: 40));
        }

        final s = value.size;
        final ar = value.aspectRatio;
        double boxW = s.width;
        double boxH = s.height;
        if (boxW <= 0 || boxH <= 0) {
          if (ar <= 0) {
            return const ColoredBox(color: AppColors.black);
          }
          boxW = 1920;
          boxH = boxW / ar;
        }

        final videoChild = SizedBox(
          width: boxW,
          height: boxH,
          child: VideoPlayer(vp),
        );

        final Widget core = value.isBuffering
            ? Stack(
                alignment: Alignment.center,
                children: [
                  videoChild,
                  Positioned.fill(
                    child: ColoredBox(
                      color: AppColors.black.withValues(alpha: 0.25),
                      child: const Center(child: AppLoadingIndicator(size: 36)),
                    ),
                  ),
                ],
              )
            : videoChild;

        return ClipRect(
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              child: core,
            ),
          ),
        );
      },
    );
  }
}

class _VideoCallControlsBar extends StatelessWidget {
  const _VideoCallControlsBar({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Obx(
            () => _RoundToolButton(
              icon: controller.pipLiveCameraOn.value
                  ? Icons.videocam_rounded
                  : Icons.videocam_off_rounded,
              onTap: controller.togglePipLiveCamera,
            ),
          ),
          Obx(
            () => _RoundToolButton(
              icon: controller.micMuted.value
                  ? Icons.mic_off_rounded
                  : Icons.mic_rounded,
              onTap: controller.toggleMicMuted,
            ),
          ),
          _EndCallCenterButton(onTap: () => controller.onReject()),
          _RoundToolButton(
            icon: Icons.cameraswitch_rounded,
            onTap: () => controller.switchCamera(),
          ),
          Obx(
            () => _RoundToolButton(
              icon: controller.speakerLoud.value
                  ? Icons.volume_up_rounded
                  : Icons.volume_down_rounded,
              onTap: () => controller.toggleSpeaker(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundToolButton extends StatelessWidget {
  const _RoundToolButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: AppColors.white, size: 24),
        ),
      ),
    );
  }
}

class _EndCallCenterButton extends StatelessWidget {
  const _EndCallCenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE02424),
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: AppColors.black.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 64,
          height: 64,
          child: Icon(Icons.call_end_rounded, color: AppColors.white, size: 30),
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

class _VideoRingAvatar extends StatelessWidget {
  const _VideoRingAvatar({
    required this.networkUrl,
    required this.filePath,
    required this.assetFallback,
    this.radius = 58,
  });

  final String? networkUrl;
  final String? filePath;
  final String assetFallback;
  final double radius;

  Widget _photo() {
    final r = radius * 2;
    if (networkUrl != null && networkUrl!.isNotEmpty) {
      return Image(
        image: CachedNetworkImageProvider(networkUrl!),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: r,
        height: r,
        errorBuilder: (_, __, ___) =>
            Image.asset(
              assetFallback,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              width: r,
              height: r,
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
        alignment: Alignment.topCenter,
        width: r,
        height: r,
        errorBuilder: (_, __, ___) =>
            Image.asset(
              assetFallback,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              width: r,
              height: r,
            ),
      );
    }
    return Image.asset(
      assetFallback,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      width: r,
      height: r,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final outerSize = size + 6;
    final innerSize = size - 2;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: const _AvatarScallopClipper(petals: 12, innerFactor: 0.90),
            child: Container(
              width: outerSize,
              height: outerSize,
              color: AppColors.white.withValues(alpha: 0.96),
            ),
          ),
          ClipPath(
            clipper: const _AvatarScallopClipper(petals: 12, innerFactor: 0.90),
            child: SizedBox(width: innerSize, height: innerSize, child: _photo()),
          ),
        ],
      ),
    );
  }
}

class _AvatarScallopClipper extends CustomClipper<Path> {
  const _AvatarScallopClipper({
    required this.petals,
    required this.innerFactor,
  });

  final int petals;
  final double innerFactor;

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * innerFactor;
    final bumpRadius = outerRadius - innerRadius + outerRadius * 0.05;
    final ringRadius = outerRadius - bumpRadius;

    path.addOval(Rect.fromCircle(center: center, radius: innerRadius));
    for (int i = 0; i < petals; i++) {
      final angle = -pi / 2 + i * (2 * pi / petals);
      final c = Offset(
        center.dx + cos(angle) * ringRadius,
        center.dy + sin(angle) * ringRadius,
      );
      path.addOval(Rect.fromCircle(center: c, radius: bumpRadius));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _AvatarScallopClipper oldClipper) =>
      oldClipper.petals != petals || oldClipper.innerFactor != innerFactor;
}

class _IncomingHeader extends StatelessWidget {
  const _IncomingHeader({required this.controller});

  final VideoCallController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final name = controller.callerName.value;
      final networkUrl = controller.networkImageUrl.value;
      final filePath = controller.localImagePath.value;
      const assetFb = VideoCallController.placeholderAsset;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VideoRingAvatar(
            networkUrl: networkUrl,
            filePath: filePath,
            assetFallback: assetFb,
            radius: 58,
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_rounded,
                color: AppColors.white.withValues(alpha: 0.9),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'incoming_call_notification_title'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _IncomingBottomActions extends StatelessWidget {
  const _IncomingBottomActions({
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
          _CallCircleButton(
            color: const Color(0xFFE02424),
            icon: Icons.call_end_rounded,
            label: 'call_reject'.tr,
            onTap: () => onReject(),
          ),
          _CallCircleButton(
            color: const Color(0xFF16A34A),
            icon: Icons.videocam_rounded,
            label: 'call_accept'.tr,
            enabled: acceptEnabled,
            onTap: () => onAccept(),
          ),
        ],
      ),
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({
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
                child: Icon(icon, color: Colors.white, size: 32),
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
            backgroundColor: AppColors.primaryColor,
            foregroundColor: AppColors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          child: Text('call_again'.tr),
        ),
      ),
    );
  }
}
