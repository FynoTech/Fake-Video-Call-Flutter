import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../controllers/add_new_controller.dart';
import '../models/add_new_call_type.dart';

class AddNewView extends GetView<AddNewController> {
  const AddNewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            matchTextDirection: true,
            width: 22,
            height: 22,
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'add_new_title'.tr,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              Obx(
                () => _AvatarPickerHeader(
                  pickedFile: controller.pickedFile.value,
                  isVideo: controller.callType.value == AddNewCallType.video,
                  onPick: () {
                    _showPickSheet(
                      context,
                      controller.callType.value == AddNewCallType.video,
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'caller_name'.tr,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                  color: AppColors.black,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.callerNameController,
                decoration: InputDecoration(
                  hintText: 'caller_name'.tr,
                  hintStyle: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_2_outlined,
                    color: Color(0xFFA968E9),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: true,
                  fillColor: const Color(0xFFE9E4F5),
                ),
              ),
              const SizedBox(height: 22),
              Obx(
                () => _CategoryField(
                  current: controller.callType.value,
                  onChanged: (next) => controller.callType.value = next,
                ),
              ),
              const SizedBox(height: 22),
              Obx(
                () => _UploadCard(
                  isVideo: controller.callType.value == AddNewCallType.video,
                  pickedFile: controller.pickedFile.value,
                  onTap: () => _showPickSheet(
                    context,
                    controller.callType.value == AddNewCallType.video,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Obx(
                () => SizedBox(
                  height: 52,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: controller.saving.value
                          ? null
                          : () => controller.save(),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppColors.onboardingNextButtonGradient,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: controller.saving.value
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const AppLoadingIndicator(size: 26),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        'saving_title'.tr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: AppColors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  'save'.tr,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
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
      ),
    );
  }

  Future<void> _showPickSheet(BuildContext context, bool allowVideo) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  allowVideo
                      ? 'upload_photo_or_video'.tr
                      : 'upload_photo_only'.tr,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: Text('pick_photo'.tr),
                  onTap: () {
                    Get.back();
                    controller.pickFromGallery(wantVideo: false);
                  },
                ),
                if (allowVideo)
                  ListTile(
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text('pick_video'.tr),
                    onTap: () {
                      Get.back();
                      controller.pickFromGallery(wantVideo: true);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AvatarPickerHeader extends StatelessWidget {
  const _AvatarPickerHeader({
    required this.pickedFile,
    required this.isVideo,
    required this.onPick,
  });

  final File? pickedFile;
  final bool isVideo;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 150,
        height: 150,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ClipPath(
              clipper: _ScallopClipper(),
              child: Container(
                width: 132,
                height: 132,
                color: const Color(0xFFDDE0E5),
                child: pickedFile == null
                    ? Icon(
                        isVideo ? Icons.videocam_rounded : Icons.person_rounded,
                        size: 60,
                        color: AppColors.black.withValues(alpha: 0.6),
                      )
                    : Image.file(pickedFile!, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 14,
              child: Material(
                color: AppColors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onPick,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.onboardingNextButtonGradient,
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.white,
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
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.current, required this.onChanged});

  final AddNewCallType current;
  final ValueChanged<AddNewCallType> onChanged;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.black,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('choose_category'.tr, style: textStyle),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE9E4F5),
            borderRadius: BorderRadius.circular(22),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AddNewCallType>(
              value: current,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.black54,
                size: 30,
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w500,
              ),
              items: [
                DropdownMenuItem(
                  value: AddNewCallType.video,
                  child: Text('video_call_short'.tr),
                ),
                DropdownMenuItem(
                  value: AddNewCallType.audio,
                  child: Text('audio_call_short'.tr),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                onChanged(value);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.isVideo,
    required this.pickedFile,
    required this.onTap,
  });

  final bool isVideo;
  final File? pickedFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: _DashedRRectPainter(
            color: AppColors.primaryColor.withValues(alpha: 0.45),
            radius: 22,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 200,
            child: pickedFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isVideo
                              ? Icons.video_library_outlined
                              : Icons.add_photo_alternate_outlined,
                          color: AppColors.black.withValues(alpha: 0.28),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isVideo
                            ? 'add_new_upload_video_hint'.tr
                            : 'add_new_upload_image_hint'.tr,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.black.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: isVideo
                        ? Container(
                            color: AppColors.black.withValues(alpha: 0.08),
                            child: Center(
                              child: Icon(
                                Icons.videocam_rounded,
                                size: 58,
                                color: AppColors.black.withValues(alpha: 0.6),
                              ),
                            ),
                          )
                        : Image.file(pickedFile!, fit: BoxFit.cover),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ScallopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final radius = size.shortestSide / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final petals = 14;
    final inner = radius * 0.9;
    final outer = radius;
    final path = Path();

    for (int i = 0; i <= petals * 2; i++) {
      final angle = (math.pi * i) / petals;
      final r = i.isEven ? outer : inner;
      final point = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final dashed = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + 11.0).clamp(0.0, metric.length).toDouble();
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance += 20.0;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}
