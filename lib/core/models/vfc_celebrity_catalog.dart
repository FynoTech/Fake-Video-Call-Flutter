import 'person_item.dart';

class VfcCelebrityCatalog {
  const VfcCelebrityCatalog({
    required this.baseUrl,
    required this.categories,
    this.suppressReadyCelebrityTaps = false,
  });

  final String baseUrl;
  final List<VfcCategory> categories;

  /// When true, celebrities that already have image + at least one video in JSON
  /// show as "Coming Soon" (tap opens snackbar only). Per-entry [VfcCelebrity.comingSoonExplicit]
  /// can override: `true` forces soon, `false` forces playable when media is ready.
  final bool suppressReadyCelebrityTaps;

  factory VfcCelebrityCatalog.fromJson(Map<String, dynamic> json) {
    final base = json['base_url']?.toString() ?? '';
    final raw = json['categories'];
    final list = <VfcCategory>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final cat = VfcCategory.fromJson(e);
          // Hide categories that have no playable items after filtering.
          if (cat.celebrities.isNotEmpty) {
            list.add(cat);
          }
        }
      }
    }
    return VfcCelebrityCatalog(
      baseUrl: base,
      categories: list,
      suppressReadyCelebrityTaps: json['suppress_ready_celebrity_taps'] == true,
    );
  }

  static String joinMediaUrl(String baseUrl, String relativePath) {
    final raw = relativePath.trim();
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      final s = uri.scheme.toLowerCase();
      if (s == 'http' || s == 'https') return raw;
    }
    final b = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final p = raw.replaceAll(RegExp(r'^/+'), '');
    if (b.isEmpty) return p;
    return '$b/$p';
  }
}

class VfcCategory {
  const VfcCategory({
    required this.id,
    required this.name,
    required this.celebrities,
  });

  final String id;
  final String name;
  final List<VfcCelebrity> celebrities;

  factory VfcCategory.fromJson(Map<String, dynamic> json) {
    final raw = json['celebrities'];
    final list = <VfcCelebrity>[];
    if (raw is List) {
      for (final e in raw) {
        if (e is Map<String, dynamic>) {
          final c = VfcCelebrity.fromJson(e);
          if (c.firstNonEmptyVideoPath != null) {
            list.add(c);
          }
        }
      }
    }
    return VfcCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? 'Category',
      celebrities: list,
    );
  }
}

class VfcCelebrity {
  const VfcCelebrity({
    required this.id,
    required this.name,
    required this.image,
    required this.videos,
    this.isPremium = false,
    this.comingSoonExplicit,
  });

  final String id;
  final String name;
  final String image;
  final List<String> videos;
  final bool isPremium;

  /// Set in JSON as `coming_soon`. `null` = follow [VfcCelebrityCatalog.suppressReadyCelebrityTaps]
  /// for entries that already have image + video. `true` / `false` override that rule.
  final bool? comingSoonExplicit;

  factory VfcCelebrity.fromJson(Map<String, dynamic> json) {
    final vids = <String>[];
    final raw = json['videos'];
    if (raw is List) {
      for (final e in raw) {
        vids.add(e.toString());
      }
    }
    bool? comingSoonExplicit;
    if (json.containsKey('coming_soon')) {
      final v = json['coming_soon'];
      if (v == true) {
        comingSoonExplicit = true;
      } else if (v == false) {
        comingSoonExplicit = false;
      }
    }
    return VfcCelebrity(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      videos: vids,
      isPremium: json['is_premium'] == true,
      comingSoonExplicit: comingSoonExplicit,
    );
  }

  String? get firstNonEmptyVideoPath {
    for (final v in videos) {
      final t = v.trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  /// Maps JSON entry to [PersonItem] for existing video-call flow (Firebase-style URLs).
  PersonItem toPersonItem({required String baseUrl, required String categoryId}) {
    final imageUrl =
        image.isEmpty ? null : VfcCelebrityCatalog.joinMediaUrl(baseUrl, image);
    final firstVideo = firstNonEmptyVideoPath;
    final videoUrl = firstVideo == null
        ? null
        : VfcCelebrityCatalog.joinMediaUrl(baseUrl, firstVideo);
    return PersonItem(
      name: name,
      storageFolderPath: 'vfc_v2/$categoryId/$id',
      imageUrl: imageUrl,
      videoUrl: videoUrl,
      videoCallOnly: true,
    );
  }
}
