import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';

import '../models/person_item.dart';

/// Lists built-in catalog + locally uploaded custom persons.
class PersonsStorageService extends GetxService {
  static const String rootPath = 'persons';
  static const String customFolder = 'custom';
  static const String _catalogAssetPath = 'assets/data/vfc_celebrities.json';
  static const String customCategoryMeta = 'category.txt';

  /// Marker file in custom person folder to keep it out of audio-only catalog.
  static const String videoCallOnlyMarker = 'video_call_only';

  /// True for locally-added custom person folders under `persons/custom/...`.
  static bool isCustomStoragePath(String path) {
    final p = path.trim();
    if (p.isEmpty) return false;
    return p.startsWith('$rootPath/$customFolder/');
  }

  final RxList<PersonItem> persons = <PersonItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxnString loadError = RxnString();

  Future<void> loadPersons() async {
    isLoading.value = true;
    loadError.value = null;
    try {
      final localPersons = await _loadPersonsFromLocalCustomFolder();
      final assetPersons = await _loadPersonsFromAssetCatalog();
      persons.assignAll(_mergePersons(assetPersons, localPersons));
    } catch (e) {
      loadError.value = e.toString();
      final assetPersons = await _loadPersonsFromAssetCatalog();
      persons.assignAll(assetPersons);
    } finally {
      isLoading.value = false;
    }
  }

  Future<Directory> localCustomRootDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$rootPath/$customFolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<PersonItem>> _loadPersonsFromLocalCustomFolder() async {
    final root = await localCustomRootDir();
    if (!await root.exists()) return const <PersonItem>[];

    final loaded = <PersonItem>[];
    final firstLevel = await root.list(followLinks: false).toList();
    for (final entry in firstLevel) {
      if (entry is! Directory) continue;
      // New structure: /persons/custom/<category>/<person>/
      final nested = await entry.list(followLinks: false).toList();
      final hasPersonDirs = nested.any((e) => e is Directory);
      if (hasPersonDirs) {
        for (final personDir in nested.whereType<Directory>()) {
          final p = await _loadPersonFromLocalDir(personDir);
          if (p != null) loaded.add(p);
        }
      } else {
        // Backward compatibility: /persons/custom/<person>/
        final p = await _loadPersonFromLocalDir(entry);
        if (p != null) loaded.add(p);
      }
    }
    loaded.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return loaded;
  }

  Future<List<PersonItem>> _loadPersonsFromAssetCatalog() async {
    try {
      final raw = await rootBundle.loadString(_catalogAssetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const <PersonItem>[];
      final celebrities = decoded['celebrities'];
      if (celebrities is! List) return const <PersonItem>[];

      final items = <PersonItem>[];
      for (final entry in celebrities) {
        if (entry is! Map) continue;
        final name = (entry['name'] ?? '').toString().trim();
        final folder = (entry['folder'] ?? '').toString().trim();
        if (name.isEmpty || folder.isEmpty) continue;
        items.add(
          PersonItem(
            name: name,
            storageFolderPath: '$rootPath/$folder',
            imageUrl: _asNullableString(entry['image']),
            audioUrl: _asNullableString(entry['audio']),
            videoUrl: _asNullableString(entry['video']),
            videoCallOnly: false,
          ),
        );
      }
      return items;
    } catch (_) {
      return const <PersonItem>[];
    }
  }

  String? _asNullableString(Object? value) {
    final s = value?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  List<PersonItem> _mergePersons(
    List<PersonItem> assetPersons,
    List<PersonItem> localPersons,
  ) {
    final byFolder = <String, PersonItem>{};
    for (final p in assetPersons) {
      byFolder[p.storageFolderPath] = p;
    }
    for (final p in localPersons) {
      byFolder[p.storageFolderPath] = p;
    }
    final merged = byFolder.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return merged;
  }

  Future<PersonItem?> _loadPersonFromLocalDir(Directory folder) async {
    try {
      final displayName = Uri.decodeComponent(
        folder.path.split(Platform.pathSeparator).last,
      );
      final files = await folder.list(followLinks: false).toList();
      final names = files.whereType<File>().map((e) => e.path.split(Platform.pathSeparator).last).toList();
      final imageRef = _pickImagePath(names);
      final audioRef = _pickAudioPath(names);
      final videoRef = _pickVideoPath(names);
      final category = await _readCategory(folder);
      final relPath = category == null || category.isEmpty
          ? '$rootPath/$customFolder/$displayName'
          : '$rootPath/$customFolder/$category/$displayName';

      return PersonItem(
        name: displayName,
        storageFolderPath: relPath,
        imageUrl: imageRef == null ? null : 'file://${folder.path}/$imageRef',
        audioUrl: audioRef == null ? null : 'file://${folder.path}/$audioRef',
        videoUrl: videoRef == null ? null : 'file://${folder.path}/$videoRef',
        videoCallOnly: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readCategory(Directory folder) async {
    try {
      final file = File('${folder.path}/$customCategoryMeta');
      if (!await file.exists()) return null;
      final id = (await file.readAsString()).trim();
      return id.isEmpty ? null : id;
    } catch (_) {
      return null;
    }
  }

  String? _pickImagePath(List<String> items) {
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      final lower = item.toLowerCase();
      if (lower.startsWith('image')) {
        return item;
      }
    }
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      if (_isImageFileName(item)) {
        return item;
      }
    }
    return null;
  }

  bool _isImageFileName(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot >= filename.length - 1) return false;
    final ext = filename.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'gif'}.contains(ext);
  }

  String? _pickAudioPath(List<String> items) {
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      final lower = item.toLowerCase();
      if (lower.startsWith('audio')) {
        return item;
      }
    }
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      if (_isAudioFileName(item)) {
        return item;
      }
    }
    return null;
  }

  bool _isAudioFileName(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot >= filename.length - 1) return false;
    final ext = filename.substring(dot + 1).toLowerCase();
    return const {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'}.contains(ext);
  }

  String? _pickVideoPath(List<String> items) {
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      final lower = item.toLowerCase();
      if (lower.startsWith('video')) {
        return item;
      }
    }
    for (final item in items) {
      if (item == videoCallOnlyMarker || item == customCategoryMeta) continue;
      if (_isVideoFileName(item)) {
        return item;
      }
    }
    return null;
  }

  bool _isVideoFileName(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot >= filename.length - 1) return false;
    final ext = filename.substring(dot + 1).toLowerCase();
    return const {'mp4', 'mov', 'webm', 'mkv', 'm4v', '3gp'}.contains(ext);
  }
}
