import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../widgets/camera_permission_rationale_dialog.dart';
import '../controllers/schedule_call_controller.dart';

class ScheduleCallView extends GetView<ScheduleCallController> {
  const ScheduleCallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        surfaceTintColor: AppColors.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 8,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            matchTextDirection: true,
            width: 22,
            height: 22,
          ),
        ),
        title: Text(
          'schedule_set_video_call'.tr,
          style: TextStyle(
            fontFamily: 'Audiowide',
            fontSize: 24,
            color: AppColors.black,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: _PersonAvatar(personImage: controller.person.imageUrl),
            ),
            const SizedBox(height: 20),
            _InputCard(
              icon: Icons.call_received_rounded,
              title: 'schedule_incoming_call'.tr,
              centered: true,
              onTap: null,
            ),
            const SizedBox(height: 18),
            _InputCard(
              icon: Icons.person_2_outlined,
              title: controller.person.name,
              onTap: null,
            ),
            const SizedBox(height: 12),
            _InputCard(
              icon: Icons.access_time_rounded,
              title: 'schedule_set_time'.tr,
              onTap: () => _showDelayPicker(context),
            ),
            const SizedBox(height: 12),
            _InputCard(
              icon: Icons.call_outlined,
              title: 'schedule_call_setting'.tr,
              onTap: null,
            ),
            const SizedBox(height: 20),
            Obx(
              () => SizedBox(
                height: 61,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: FilledButton.icon(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () => _handlePrimaryTap(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: Icon(
                      controller.hasAudio
                          ? Icons.call_rounded
                          : Icons.videocam_rounded,
                      size: 34,
                      color: AppColors.white,
                    ),
                    label: Text(
                      controller.hasAudio
                          ? 'audio_call_short'.tr
                          : 'video_call_short'.tr,
                      style: const TextStyle(
                        fontSize: 38 / 2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDelayPicker(BuildContext context) async {
    final values = <Duration>[
      Duration.zero,
      const Duration(seconds: 15),
      const Duration(seconds: 30),
      const Duration(minutes: 1),
      const Duration(minutes: 5),
      const Duration(minutes: 10),
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: values.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = values[i];
              final label = d == Duration.zero
                  ? 'schedule_now'.tr
                  : d.inSeconds < 60
                  ? '${d.inSeconds} ${'schedule_seconds'.tr}'
                  : '${d.inMinutes} ${'schedule_minutes'.tr}';
              return ListTile(
                title: Text(label),
                onTap: () {
                  controller.chooseDelay(d);
                  Get.back();
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _handlePrimaryTap(BuildContext context) async {
    // Camera permission is only required for video flow.
    if (controller.hasAudio || kIsWeb) {
      await controller.submit();
      return;
    }

    final status = await Permission.camera.status;
    if (status.isGranted) {
      await controller.submit();
      return;
    }

    final granted = await showCameraPermissionRationaleDialog(context);
    if (!granted) return;
    await controller.submit();
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.centered = false,
  });
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: centered
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 34),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 20 / 1.1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(icon, color: AppColors.primaryColor, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.personImage});
  final String? personImage;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _PersonScallopClipper(),
      child: SizedBox(
        width: 150,
        height: 150,
        child: ColoredBox(
          color: const Color(0xFFD7DADF),
          child: Transform.scale(scale: 1.0, child: _buildImage()),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final raw = personImage?.trim();
    if (raw != null && raw.isNotEmpty) {
      if (raw.startsWith('http://') || raw.startsWith('https://')) {
        return Image(
          image: CachedNetworkImageProvider(raw),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) =>
              Image.asset('assets/1.png', fit: BoxFit.cover),
        );
      }
      if (!kIsWeb) {
        String path = raw;
        if (raw.startsWith('file://')) {
          try {
            path = Uri.parse(raw).toFilePath();
          } catch (_) {}
        }
        if (path.isNotEmpty && File(path).existsSync()) {
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          );
        }
      }
    }
    return Image.asset(
      'assets/1.png',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}

class _PersonScallopClipper extends CustomClipper<Path> {
  const _PersonScallopClipper();

  @override
  Path getClip(Size size) {
    const petals = 18;
    const innerFactor = 0.80;
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.shortestSide / 2;
    final innerRadius = outerRadius * innerFactor;
    final bumpRadius = outerRadius - innerRadius + outerRadius * 0.05;
    final ringRadius = outerRadius - bumpRadius;

    path.addOval(Rect.fromCircle(center: center, radius: innerRadius));
    for (int i = 0; i < petals; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / petals);
      final c = Offset(
        center.dx + math.cos(angle) * ringRadius,
        center.dy + math.sin(angle) * ringRadius,
      );
      path.addOval(Rect.fromCircle(center: c, radius: bumpRadius));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _PersonScallopClipper oldClipper) => false;
}
