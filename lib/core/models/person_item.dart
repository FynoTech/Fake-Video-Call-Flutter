class PersonItem {
  const PersonItem({
    required this.name,
    required this.storageFolderPath,
    this.imageUrl,
    this.audioUrl,
    this.videoUrl,
    this.videoCallOnly = false,
  });

  final String name;
  /// Full Storage path to the person's folder (e.g. `persons/Santa`).
  final String storageFolderPath;
  final String? imageUrl;
  final String? audioUrl;
  final String? videoUrl;

  /// When true (marker file in Storage), person appears only in video-call flows.
  final bool videoCallOnly;

  /// Text before the first `_`; if there is no `_`, uses [name] (first space-separated word only).
  /// e.g. `Ali_Khan` → `Ali`, `Selena_Gomez` → `Selena`, `Ronaldo` → `Ronaldo`.
  String get firstName {
    final t = name.trim();
    if (t.isEmpty) return '';
    final underscore = t.indexOf('_');
    final segment =
        underscore < 0 ? t : t.substring(0, underscore).trim();
    if (segment.isEmpty) return '';
    return segment.split(RegExp(r'\s+')).first;
  }
}
