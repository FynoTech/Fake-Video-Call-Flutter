import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/vfc_category_localization.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../controllers/add_video_person_controller.dart';

class AddVideoPersonView extends GetView<AddVideoPersonController> {
  const AddVideoPersonView({super.key});

  static const Color _avatarBg = Color(0xFFEDEDED);
  static const Color _uploadCircleBg = Color(0xFFE6E4E4);
  static const Color _uploadRed = Color(0xFFE20018);

  static const String _kEditFabSvg = 'assets/add_new/edit_fab.svg';
  static const String _kPersonSvg = 'assets/add_new/person_silhouette.svg';
  static const String _kCallerSvg = 'assets/add_new/ic_caller.svg';
  static const String _kPhoneSvg = 'assets/add_new/phone.svg';
  static const String _kUploadArrowSvg = 'assets/add_new/upload_arrow.svg';
  static const String _kNoImageSvg = 'assets/add_new/no_image.svg';

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      color: AppColors.black,
      fontSize: 22,
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('add_new_title'.tr),
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/setting/ic_back.svg',
            matchTextDirection: true,
            width: 22,
            height: 22,
          ),
          onPressed: () => Get.back(),
        ),
        titleTextStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w700,
              fontFamily: 'Audiowide',
              fontSize: 24,
              letterSpacing: 0.2,
            ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 28),
            children: [
              Obx(
                () => _PhotoAvatarHeader(
                  photo: controller.photoFile.value,
                  onPickPhoto: controller.pickPhoto,
                  avatarBg: _avatarBg,
                  personSvgAsset: _kPersonSvg,
                  editFabSvgAsset: _kEditFabSvg,
                ),
              ),
              const SizedBox(height: 24),
              Text('caller_name'.tr, style: titleStyle),
              const SizedBox(height: 8),
              TextField(
                controller: controller.nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'caller_name'.tr,
                  hintStyle: TextStyle(
                    color: AppColors.black.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: SvgPicture.asset(
                        _kCallerSvg,
                        height: 24,
                        width: 24 * (109 / 97),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.primaryColor,
                      width: 1.2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.primaryColor,
                      width: 1.2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide(
                      color: AppColors.primaryColor,
                      width: 1.2,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0x1A615EF0),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('choose_category'.tr, style: titleStyle),
              const SizedBox(height: 8),
              Obx(() {
                final items = controller.categories;
                final selected = controller.selectedCategory.value;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x1A615EF0),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        _kPhoneSvg,
                        height: 22,
                        width: 22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<AddPersonCategory>(
                            value: selected,
                            isExpanded: true,
                            menuMaxHeight: 360,
                            hint: Text(
                              'choose_category'.tr,
                              style: TextStyle(color: AppColors.textMuted45),
                            ),
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.black54,
                              size: 32,
                            ),
                            selectedItemBuilder: (ctx) => items
                                .map(
                                  (e) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      localizedVfcCategoryName(e.id, e.name),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: AppColors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                )
                                .toList(),
                            items: items
                                .map(
                                  (e) => DropdownMenuItem<AddPersonCategory>(
                                    value: e,
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected?.id == e.id
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          color: selected?.id == e.id
                                              ? AppColors.primaryColor
                                              : AppColors.textMuted45,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          localizedVfcCategoryName(e.id, e.name),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: AppColors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (next) {
                              if (next == null) return;
                              controller.selectedCategory.value = next;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 22),
              const SizedBox(height: 4),
              Obx(() {
                final v = controller.videoFile.value;
                return Column(
                  children: [
                    _VideoUploadCircle(
                      video: v,
                      onTap: controller.pickVideo,
                      circleBg: _uploadCircleBg,
                      uploadRed: _uploadRed,
                      uploadArrowAsset: _kUploadArrowSvg,
                      noImageAsset: _kNoImageSvg,
                    ),
                    if (v != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        v.path.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted55,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                );
              }),
              const SizedBox(height: 35),
              Obx(() {
                final busy = controller.uploading.value;
                return SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(130),
                      onTap: busy ? null : () => controller.upload(),
                      child: Ink(
                        decoration: BoxDecoration(
                          color: busy
                              ? AppColors.textMuted45
                              : AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(130),
                        ),
                        child: Center(
                          child: busy
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
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoAvatarHeader extends StatelessWidget {
  const _PhotoAvatarHeader({
    required this.photo,
    required this.onPickPhoto,
    required this.avatarBg,
    required this.personSvgAsset,
    required this.editFabSvgAsset,
  });

  final File? photo;
  final VoidCallback onPickPhoto;
  final Color avatarBg;
  final String personSvgAsset;
  final String editFabSvgAsset;

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
              child: Material(
                color: avatarBg,
                child: InkWell(
                  onTap: onPickPhoto,
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: photo == null
                        ? Center(
                            child: SvgPicture.asset(
                              personSvgAsset,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.file(photo!, fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 18,
              bottom: 14,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onPickPhoto,
                    customBorder: const CircleBorder(),
                    child: SvgPicture.asset(
                      editFabSvgAsset,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
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

class _VideoUploadCircle extends StatelessWidget {
  const _VideoUploadCircle({
    required this.video,
    required this.onTap,
    required this.circleBg,
    required this.uploadRed,
    required this.uploadArrowAsset,
    required this.noImageAsset,
  });

  final File? video;
  final VoidCallback onTap;
  final Color circleBg;
  final Color uploadRed;
  final String uploadArrowAsset;
  final String noImageAsset;

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
            child: video == null
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
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: SvgPicture.asset(
                            noImageAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tap to select an image from your device and continue.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.black.withValues(alpha: 0.35),
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.videocam_rounded,
                      size: 58,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
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
    const petals = 14;
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
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
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
