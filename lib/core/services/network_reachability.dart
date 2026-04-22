import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../models/person_item.dart';
import 'persons_storage_service.dart';
import '../../widgets/no_internet_dialog.dart';

/// True when [url] is loaded over the network (HTTP/HTTPS).
bool isRemoteMediaUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final u = url.trim();
  return u.startsWith('http://') || u.startsWith('https://');
}

/// Whether the device can reach the public internet (not only a local Wi‑Fi link).
Future<bool> hasInternetConnection() {
  return InternetConnectionChecker.instance.hasConnection;
}

/// If [mediaUrl] is remote and there is no internet, shows [showNoInternetDialog]
/// and returns `false`. Otherwise returns `true` (safe to open the call screen).
Future<bool> ensureInternetForRemoteMedia(
  BuildContext? context, {
  required String? mediaUrl,
}) async {
  if (!isRemoteMediaUrl(mediaUrl)) return true;
  if (await hasInternetConnection()) return true;

  final ctx = context;
  if (ctx != null && ctx.mounted) {
    await showNoInternetDialog(ctx);
  } else {
    final g = Get.context;
    if (g != null && g.mounted) {
      await showNoInternetDialog(g);
    }
  }
  return false;
}

/// For call flows: requires internet for remote media OR any custom person call.
Future<bool> ensureInternetForPersonCall(
  BuildContext? context, {
  required PersonItem person,
  required String? mediaUrl,
}) async {
  final isCustom = PersonsStorageService.isCustomStoragePath(
    person.storageFolderPath,
  );
  if (!isCustom && !isRemoteMediaUrl(mediaUrl)) return true;
  if (await hasInternetConnection()) return true;

  final ctx = context;
  if (ctx != null && ctx.mounted) {
    await showNoInternetDialog(ctx);
  } else {
    final g = Get.context;
    if (g != null && g.mounted) {
      await showNoInternetDialog(g);
    }
  }
  return false;
}
