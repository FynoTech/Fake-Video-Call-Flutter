import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/theme/app_colors.dart';

/// In-app camera explanation; call [Permission.camera.request] only after the user taps allow.
/// Returns whether camera access is granted after the flow.
Future<bool> showCameraPermissionRationaleDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.20),
    builder: (dialogContext) {
      final screen = MediaQuery.sizeOf(dialogContext);
      final compact = screen.height <= 780 || screen.width <= 360;
      return Dialog(
        backgroundColor: AppColors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: compact ? 16 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: screen.height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Container(
              width: 360,
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 22,
                compact ? 20 : 28,
                compact ? 18 : 22,
                compact ? 14 : 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/home/ic_camera.png',
                    width: compact ? 82 : 100,
                    height: compact ? 82 : 100,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  Text(
                    'camera_permission_title'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF1A1A33),
                      fontSize: compact ? 17 : 38 / 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  Text(
                    'camera_permission_body'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF212133),
                      fontSize: compact ? 14.5 : 16,
                      height: 1.35,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: compact ? 14 : 22),
                  SizedBox(
                    width: double.infinity,
                    height: compact ? 56 : 62,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [Color(0xFFB566FF), Color(0xFF9C5CFF)],
                        ),
                      ),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        onPressed: () async {
                          final requested = await Permission.camera.request();
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop(requested.isGranted);
                          }
                          if (requested.isPermanentlyDenied) {
                            await openAppSettings();
                          }
                        },
                        child: Text(
                          'camera_permission_allow'.tr,
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: compact ? 18 : 40 / 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
