import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Must match `applicationId` in `android/app/build.gradle.kts`.
const String kPlayStorePackageId = 'com.fynotech.prankcall';

/// Must match iOS `PRODUCT_BUNDLE_IDENTIFIER` for iTunes lookup.
const String kIosBundleIdForLookup = 'com.fynotech.prankcall';

/// Optional: set your numeric Apple ID from App Store Connect to skip lookup.
/// Example: `'6738123456'`. Leave empty to use iTunes API by bundle id.
const String kIosAppStoreNumericId = '';

/// Opens the Play Store (Android) or App Store (iOS) listing for this app.
Future<void> openStoreListing() async {
  if (kIsWeb) return;

  try {
    if (Platform.isAndroid) {
      final marketUri = Uri.parse('market://details?id=$kPlayStorePackageId');
      final webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$kPlayStorePackageId',
      );
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open Play Store');
      }
      return;
    }

    if (Platform.isIOS) {
      var id = kIosAppStoreNumericId.trim();
      if (id.isEmpty) {
        id = await _lookupAppleTrackId(kIosBundleIdForLookup) ?? '';
      }
      if (id.isEmpty) {
        _snack(
          'App Store',
          'Listing not found yet. Publish the app or set kIosAppStoreNumericId in store_listing_launcher.dart.',
        );
        return;
      }
      final appUri = Uri.parse('itms-apps://itunes.apple.com/app/id$id');
      final webUri = Uri.parse('https://apps.apple.com/app/id$id');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open App Store');
      }
    }
  } catch (e) {
    _snack('Could not open store', e.toString());
  }
}

Future<String?> _lookupAppleTrackId(String bundleId) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse(
      'https://itunes.apple.com/lookup?bundleId=${Uri.encodeComponent(bundleId)}',
    );
    final req = await client.getUrl(uri);
    final res = await req.close().timeout(const Duration(seconds: 8));
    if (res.statusCode != HttpStatus.ok) return null;
    final body = await utf8.decoder.bind(res).join();
    final map = jsonDecode(body) as Map<String, dynamic>?;
    if (map == null) return null;
    final count = map['resultCount'];
    if (count is! int || count < 1) return null;
    final results = map['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    if (first is! Map<String, dynamic>) return null;
    return first['trackId']?.toString();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

Future<void> launchExternalUrl(String rawUrl) async {
  if (kIsWeb) return;
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) {
    _snack('Could not open link');
    return;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !(uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https'))) {
    _snack('Invalid link');
    return;
  }
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open link');
    }
  } catch (e) {
    _snack('Could not open link', e.toString());
  }
}

void _snack(String title, [String? message]) {
  Get.snackbar(
    title,
    message ?? '',
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
  );
}
