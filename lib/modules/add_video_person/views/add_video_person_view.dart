import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/vfc_category_localization.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../controllers/add_video_person_controller.dart';

class AddVideoPersonView extends GetView<AddVideoPersonController> {
  const AddVideoPersonView({super.key});

  static const Color _fieldBorder = Color(0xFFD9D1D1);
  static const Color _avatarBg = Color(0xFFEDEDED);
  static const Color _uploadCircleBg = Color(0xFFE6E4E4);
  static const Color _uploadRed = Color(0xFFE20018);

  static const String _kEditFabSvg = 'assets/add_new/edit_fab.svg';
  static const String _kPersonSvg = 'assets/add_new/person_silhouette.svg';
  static const String _kUploadArrowSvg = 'assets/add_new/upload_arrow.svg';

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.black,
      fontSize: 16,
      fontFamily: "Roboto",
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: GradientAppBar(
        title: 'add_new_title'.tr,
        centerTitle: true,
        automaticallyImplyLeading: false,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  hintStyle: TextStyle(color: AppColors.textMuted45),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: SvgPicture.asset(
                        _kPersonSvg,
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
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _fieldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _fieldBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.gradientAppBarMid,
                      width: 1.5,
                    ),
                  ),
                  filled: false,
                  fillColor: const Color(0xFFF5F5F5),
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
                    color: AppColors.white,
                    border: Border.all(color: _fieldBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        color: AppColors.black,
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
                                        ? AppColors.gradientAppBarMid
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
                );
              }),
              const SizedBox(height: 22),
              Text('video_call_short'.tr, style: titleStyle),
              const SizedBox(height: 18),
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
                          gradient: busy
                              ? null
                              : AppColors.onboardingNextButtonGradient,
                          color: busy ? AppColors.textMuted45 : null,
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
        width: 124,
        height: 124,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Material(
              // color: avatarBg,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPickPhoto,
                customBorder: const CircleBorder(),
                child: Ink(
                  width: 112,
                  height: 112,
                  child: photo == null
                      ? Center(
                          child: SvgPicture.asset(
                            personSvgAsset,
                            // height: 56,
                            // width: 56 * (109 / 97),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Image.file(
                          photo!,
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            Positioned(
              right: -4,
              bottom: -4,
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
  });

  final File? video;
  final VoidCallback onTap;
  final Color circleBg;
  final Color uploadRed;
  final String uploadArrowAsset;

  static const double _diameter = 120;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: circleBg,
        shape: const CircleBorder(),
        elevation: 0,
        shadowColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: _diameter,
            height: _diameter,
            child: video == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        uploadArrowAsset,
                        width: 24,
                        height: 24,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: uploadRed,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: uploadRed.withValues(alpha: 0.28),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'UPLOAD',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,

                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 40,
                        color: AppColors.black87,
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: uploadRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'UPLOAD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: AppColors.white,
                          ),
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
