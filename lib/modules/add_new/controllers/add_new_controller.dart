import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/ads/resume_app_open_ad_service.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../add_video_person/controllers/add_video_person_controller.dart';
import '../models/add_new_call_type.dart';

class AddNewController extends GetxController {
  static const _quickAddCategory = '_quick_add';
  static const _placeholderImageAsset = 'assets/1.png';

  final callType = AddNewCallType.video.obs;
  final callerNameController = TextEditingController();

  final isVideoPicked = false.obs;
  final pickedFile = Rxn<File>();
  final saving = false.obs;

  final picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();

    final args = Get.arguments as Map<String, dynamic>?; // optional
    callType.value =
        AddNewCallTypeX.fromString(args?['call_type'] as String?);
    final person = args?['person'];
    if (person is PersonItem) {
      callerNameController.text = person.firstName;
    }
  }

  Future<void> pickFromGallery({required bool wantVideo}) async {
    final resumeAd = Get.find<ResumeAppOpenAdService>();
    resumeAd.beginExternalFlowSuppression();
    XFile? xfile;
    try {
      xfile = wantVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery);
    } finally {
      resumeAd.endExternalFlowSuppression();
    }

    if (xfile == null) return;

    pickedFile.value = File(xfile.path);
    isVideoPicked.value = wantVideo;
  }

  void resetPicked() {
    pickedFile.value = null;
    isVideoPicked.value = false;
  }

  String _ext(File f) {
    final i = f.path.lastIndexOf('.');
    if (i < 0 || i >= f.path.length - 1) return 'mp4';
    return f.path.substring(i + 1).toLowerCase();
  }

  Future<void> save() async {
    final name = callerNameController.text.trim().isEmpty
        ? 'Alisa'
        : callerNameController.text.trim();

    if (callType.value == AddNewCallType.audio) {
      final online = await hasInternetConnection();
      if (!online) {
        Get.snackbar(
          'Internet required',
          'Custom fake calls are available only when internet is ON.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
      Get.offAllNamed(AppRoutes.audioCall, arguments: {
        'name': name,
        'avatar': pickedFile.value?.path,
        'subtitle': 'Incoming Audio Call',
      });
      return;
    }

    final v = pickedFile.value;
    if (v == null || !v.existsSync()) {
      Get.snackbar(
        'Video required',
        'Pick a video from your gallery.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!isVideoPicked.value) {
      Get.snackbar(
        'Video required',
        'Choose a video file (not only a photo).',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final folder = AddVideoPersonController.sanitizeFolderName(name);
    if (folder.isEmpty) {
      Get.snackbar(
        'Name required',
        'Enter a valid caller name.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final online = await hasInternetConnection();
    if (!online) {
      Get.snackbar(
        'Internet required',
        'Custom fake calls are available only when internet is ON.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    saving.value = true;
    try {
      final persons = Get.find<PersonsStorageService>();
      final root = await persons.localCustomRootDir();
      final base = Directory('${root.path}/$_quickAddCategory/$folder');
      if (await base.exists()) {
        await base.delete(recursive: true);
      }
      await base.create(recursive: true);

      final vidExt = _ext(v);
      await v.copy('${base.path}/video.$vidExt');

      final imgBytes = await rootBundle.load(_placeholderImageAsset);
      final buf = imgBytes.buffer;
      await File('${base.path}/image.png').writeAsBytes(
        buf.asUint8List(imgBytes.offsetInBytes, imgBytes.lengthInBytes),
      );

      await File('${base.path}/${PersonsStorageService.videoCallOnlyMarker}')
          .writeAsBytes(const []);
      await File('${base.path}/${PersonsStorageService.customCategoryMeta}')
          .writeAsString(_quickAddCategory);

      await persons.loadPersons();
      final wantedPath =
          '${PersonsStorageService.rootPath}/${PersonsStorageService.customFolder}/$_quickAddCategory/$folder';

      PersonItem? created;
      for (final p in persons.persons) {
        if (p.storageFolderPath == wantedPath) {
          created = p;
          break;
        }
      }

      created ??= PersonItem(
        name: name,
        storageFolderPath: wantedPath,
        imageUrl: 'file://${base.path}/image.png',
        videoUrl: 'file://${base.path}/video.$vidExt',
        videoCallOnly: true,
      );

      Get.offAllNamed(AppRoutes.videoCall, arguments: {'person': created});
    } catch (e, st) {
      debugPrint('AddNew save failed: $e\n$st');
      Get.snackbar(
        'Save failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (!isClosed) saving.value = false;
    }
  }

  @override
  void onClose() {
    callerNameController.dispose();
    super.onClose();
  }
}

