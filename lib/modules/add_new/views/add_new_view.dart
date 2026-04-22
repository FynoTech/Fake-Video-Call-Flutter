import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../widgets/app_loading_indicator.dart';
import '../../../widgets/gradient_app_bar.dart';
import '../controllers/add_new_controller.dart';
import '../models/add_new_call_type.dart';

class AddNewView extends GetView<AddNewController> {
  const AddNewView({super.key});

  @override
  Widget build(BuildContext context) {
    final isVideo = controller.callType.value == AddNewCallType.video;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: GradientAppBar(
        title: 'add_new_title'.tr,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white10),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ListView(
            padding: const EdgeInsets.only(top: 20, bottom: 24),
            children: [
              Obx(
                () => _AvatarPickerHeader(
                  pickedFile: controller.pickedFile.value,
                  isVideo: isVideo,
                  onPick: () {
                    _showPickSheet(context, isVideo);
                  },
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'caller_name'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller.callerNameController,
                decoration: InputDecoration(
                  hintText: 'caller_name'.tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),
              const SizedBox(height: 22),
              _CallTypeRow(
                callType: isVideo ? 'video_call_short'.tr : 'audio_call_short'.tr,
              ),
              const SizedBox(height: 18),
              Obx(
                () => _UploadCircle(
                  isVideo: isVideo,
                  pickedFile: controller.pickedFile.value,
                  onTap: () => _showPickSheet(context, isVideo),
                ),
              ),
              const SizedBox(height: 22),
              Obx(
                () => SizedBox(
                  height: 52,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: controller.saving.value ? null : () => controller.save(),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: AppColors.onboardingNextButtonGradient,
                          borderRadius: BorderRadius.circular(14),
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFFEDEDED),
            child: pickedFile == null
                ? const Icon(Icons.person_outline_rounded, size: 56)
                : isVideo
                ? const Icon(Icons.videocam, size: 56)
                : ClipOval(
                    child: Image.file(
                      pickedFile!,
                      width: 112,
                      height: 112,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 72,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onPick,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0C2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallTypeRow extends StatelessWidget {
  const _CallTypeRow({required this.callType});

  final String callType;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          callType,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          'See All',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _UploadCircle extends StatelessWidget {
  const _UploadCircle({
    required this.isVideo,
    required this.pickedFile,
    required this.onTap,
  });

  final bool isVideo;
  final File? pickedFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Center(
        child: SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE7E7E7),
                ),
                child: pickedFile == null
                    ? const Icon(Icons.upload_file_rounded, size: 44)
                    : isVideo
                    ? const Icon(Icons.videocam, size: 44)
                    : ClipOval(
                        child: Image.file(
                          pickedFile!,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              Positioned(
                bottom: 8,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'UPLOAD',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
