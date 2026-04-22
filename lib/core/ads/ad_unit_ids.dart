import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart' show TargetPlatform;

/// AdMob unit IDs.
///
/// **Debug / profile:** Google’s official sample units → always “Test Ad”
/// (works with your Android `APPLICATION_ID`; iOS uses sample `GADApplicationIdentifier`).
///
/// **Release + Android:** Your production units. **Release + iOS:** sample units
/// until you add an iOS app in AdMob and replace the iOS branch below.
abstract final class AdUnitIds {
  /// Google sample publisher — reliable test ads (banner + interstitial).
  static const String _googleBanner =
      'ca-app-pub-3940256099942544/2934735716';
  static const String _googleInterstitial =
      'ca-app-pub-3940256099942544/4411468910';

  // —— Android production (release only) ——
  static const String _androidBannerProd =
      'ca-app-pub-1031204555702774/2233215628';
  static const String _androidInterstitialProd =
      'ca-app-pub-1031204555702774/4803538641';

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Production Android units only in release builds.
  static bool get _useAndroidProduction =>
      kReleaseMode && _isAndroid;

  static String get bannerTop {
    if (!_supported) return '';
    if (_useAndroidProduction) return _androidBannerProd;
    return _googleBanner;
  }

  static String get interstitial {
    if (!_supported) return '';
    if (_useAndroidProduction) return _androidInterstitialProd;
    return _googleInterstitial;
  }
}
