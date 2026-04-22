import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Runtime prompts shown from home so later screens (flash, video PiP, gallery)
/// do not fail silently or stack multiple dialogs.
Future<void> requestPermissionsForHomeFlow() async {
  if (kIsWeb) return;
  try {
    // Gallery picks use the system picker / `image_picker` and should not be
    // blocked by `Permission.photos` / `Permission.videos` on Android (handler
    // can mis-detect manifest entries; Photo Picker needs no READ_MEDIA_*).
    await Permission.camera.request();
  } catch (_) {}
}
