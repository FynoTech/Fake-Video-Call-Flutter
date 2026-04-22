import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/person_item.dart';
import '../../../core/models/vfc_celebrity_catalog.dart';
import '../../../core/ads/resume_app_open_ad_service.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/persons_storage_service.dart';

class AddVideoPersonController extends GetxController {
  final nameController = TextEditingController();
  final photoFile = Rxn<File>();
  final videoFile = Rxn<File>();
  final uploading = false.obs;
  final categories = <AddPersonCategory>[].obs;
  final selectedCategory = Rxn<AddPersonCategory>();

  final _picker = ImagePicker();
  PersonsStorageService get _persons => Get.find<PersonsStorageService>();

  static const String _vfcAssetPath = 'assets/data/vfc_celebrities_v2.json';

  static String sanitizeFolderName(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';
    s = s.replaceAll(RegExp(r'[/\\#?\[\]]+'), '_');
    s = s.replaceAll(RegExp(r'[^\w\-\s.]'), '');
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'_+'), '_').trim();
    if (s.isEmpty || s == '.' || s == '..') return '';
    return s.length > 96 ? s.substring(0, 96) : s;
  }

  static String _ext(File f) {
    final i = f.path.lastIndexOf('.');
    if (i < 0 || i >= f.path.length - 1) return 'bin';
    return f.path.substring(i + 1).toLowerCase();
  }

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final raw = await rootBundle.loadString(_vfcAssetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final catalog = VfcCelebrityCatalog.fromJson(map);
      final list = catalog.categories
          .map(
            (c) => AddPersonCategory(
              id: _effectiveCategoryId(c.id, c.name),
              name: c.name.trim(),
            ),
          )
          .toList();
      categories.assignAll(list);
      if (list.isNotEmpty) selectedCategory.value = list.first;
    } catch (_) {
      const fallback = AddPersonCategory(id: 'bollywood', name: 'Bollywood');
      categories.assignAll([fallback]);
      selectedCategory.value = fallback;
    }
  }

  String _effectiveCategoryId(String rawId, String rawName) {
    final byId = sanitizeFolderName(rawId);
    if (byId.isNotEmpty) return byId.toLowerCase();
    final byName = sanitizeFolderName(rawName);
    if (byName.isNotEmpty) return byName.toLowerCase();
    return 'category';
  }

  Future<void> pickPhoto() async {
    final resumeAd = Get.find<ResumeAppOpenAdService>();
    resumeAd.beginExternalFlowSuppression();
    XFile? x;
    try {
      x = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
    } finally {
      resumeAd.endExternalFlowSuppression();
    }
    if (x == null) return;
    photoFile.value = File(x.path);
  }

  Future<void> pickVideo() async {
    final resumeAd = Get.find<ResumeAppOpenAdService>();
    resumeAd.beginExternalFlowSuppression();
    XFile? x;
    try {
      x = await _picker.pickVideo(source: ImageSource.gallery);
    } finally {
      resumeAd.endExternalFlowSuppression();
    }
    if (x == null) return;
    videoFile.value = File(x.path);
  }

  Future<bool> _folderOccupied(String folder) async {
    final selected = selectedCategory.value;
    if (selected == null) return true;
    final root = await _persons.localCustomRootDir();
    final dir = Directory('${root.path}/${selected.id}/$folder');
    return dir.exists();
  }

  Future<void> upload() async {
    // Local validation first — avoids waiting on [hasInternetConnection] (often multi‑second).
    final folder = sanitizeFolderName(nameController.text);
    if (folder.isEmpty) {
      Get.snackbar(
        'Name required',
        'Enter a folder name (letters, numbers, spaces).',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final selected = selectedCategory.value;
    if (selected == null) {
      Get.snackbar(
        'Category required',
        'Please choose a category.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final p = photoFile.value;
    final v = videoFile.value;
    if (p == null) {
      Get.snackbar(
        'Photo required',
        'Pick a profile photo from the top.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (v == null) {
      Get.snackbar(
        'Video required',
        'Pick a video from the bottom.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!p.existsSync()) {
      Get.snackbar(
        'Photo required',
        'Pick a profile photo from the top.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!v.existsSync()) {
      Get.snackbar(
        'Video required',
        'Pick a video from the bottom.',
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

    try {
      if (await _folderOccupied(folder)) {
        Get.snackbar(
          'Already exists',
          'A person named "$folder" already exists in ${selected.name}.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }
    } catch (e) {
      Get.snackbar(
        'Storage check failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    uploading.value = true;
    try {
      final root = await _persons.localCustomRootDir();
      final base = Directory('${root.path}/${selected.id}/$folder');
      await base.create(recursive: true);

      final imgExt = _ext(p);
      final vidExt = _ext(v);
      await p.copy('${base.path}/image.$imgExt');
      await v.copy('${base.path}/video.$vidExt');
      await File('${base.path}/${PersonsStorageService.videoCallOnlyMarker}')
          .writeAsBytes(const []);
      await File('${base.path}/${PersonsStorageService.customCategoryMeta}')
          .writeAsString(selected.id);

      await _persons.loadPersons();
      final wantedPath =
          '${PersonsStorageService.rootPath}/${PersonsStorageService.customFolder}/${selected.id}/$folder';
      PersonItem? created;
      for (final person in _persons.persons) {
        if (person.storageFolderPath == wantedPath ||
            person.name == folder ||
            sanitizeFolderName(person.name) == folder) {
          created = person;
          break;
        }
      }

      if (created == null) {
        Get.back();
        Get.snackbar(
          'Saved',
          '$folder is available in ${selected.name}.',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      Get.offAllNamed(AppRoutes.home);
      Get.snackbar(
        'Saved',
        '${created.name} added in ${selected.name}.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e, st) {
      debugPrint('AddVideoPerson save failed: $e');
      debugPrint('$st');
      Get.snackbar(
        'Save failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      uploading.value = false;
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    super.onClose();
  }
}

class AddPersonCategory {
  const AddPersonCategory({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}
