import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/camera_permission_rationale_dialog.dart';

/// In-app camera rationale first, then system permission (see [showCameraPermissionRationaleDialog]).
Future<void> requestPermissionsForHomeFlow() async {
  if (kIsWeb) return;
  try {
    if ((await Permission.camera.status).isGranted) return;
    // Gallery picks do not use READ_MEDIA_*; camera still needs a prior rationale on home.
    var ctx = Get.context;
    if (ctx == null) {
      await Future<void>.delayed(Duration.zero);
      ctx = Get.context;
    }
    if (ctx == null || !ctx.mounted) return;
    await showCameraPermissionRationaleDialog(ctx);
  } catch (_) {}
}
