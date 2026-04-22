import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_shimmer.dart';

class _CachedBannerAd {
  _CachedBannerAd(this.ad) : cachedAt = DateTime.now();
  final BannerAd ad;
  final DateTime cachedAt;
}

class _CachedNativeAd {
  _CachedNativeAd(this.ad) : cachedAt = DateTime.now();
  final NativeAd ad;
  final DateTime cachedAt;
}

class _RaceAdReuseCache {
  static const Duration _ttl = Duration(minutes: 5);
  static final Map<String, _CachedBannerAd> _banner = <String, _CachedBannerAd>{};
  static final Map<String, _CachedNativeAd> _native = <String, _CachedNativeAd>{};

  static String bannerKey(String unitId, AdSize size) =>
      '${unitId.trim()}::${size.width}x${size.height}';

  static String nativeKey(String unitId, String factoryId) =>
      '${unitId.trim()}::${factoryId.trim()}';

  static BannerAd? takeBanner(String key) {
    _cleanup();
    final cached = _banner.remove(key);
    return cached?.ad;
  }

  static NativeAd? takeNative(String key) {
    _cleanup();
    final cached = _native.remove(key);
    return cached?.ad;
  }

  static void stashBanner(String key, BannerAd ad) {
    _cleanup();
    final old = _banner.remove(key);
    old?.ad.dispose();
    _banner[key] = _CachedBannerAd(ad);
  }

  static void stashNative(String key, NativeAd ad) {
    _cleanup();
    final old = _native.remove(key);
    old?.ad.dispose();
    _native[key] = _CachedNativeAd(ad);
  }

  static void _cleanup() {
    final now = DateTime.now();
    final expiredBannerKeys = _banner.entries
        .where((e) => now.difference(e.value.cachedAt) > _ttl)
        .map((e) => e.key)
        .toList(growable: false);
    for (final key in expiredBannerKeys) {
      _banner.remove(key)?.ad.dispose();
    }

    final expiredNativeKeys = _native.entries
        .where((e) => now.difference(e.value.cachedAt) > _ttl)
        .map((e) => e.key)
        .toList(growable: false);
    for (final key in expiredNativeKeys) {
      _native.remove(key)?.ad.dispose();
    }
  }
}

/// Shows either a banner OR native ad (whichever loads first).
///
/// If both are enabled, both are requested and the first-loaded wins; the other is disposed.
class RaceBannerNativeSlot extends StatefulWidget {
  const RaceBannerNativeSlot({
    super.key,
    required this.bannerEnabled,
    required this.nativeEnabled,
    required this.bannerUnitId,
    required this.nativeUnitId,
    this.nativeFactoryId,
    this.nativeHeight = 150,
    this.bannerSize = AdSize.banner,
    this.timeout = const Duration(seconds: 6),
    this.fullWidth = true,
    this.debugLabel = 'race_slot',
  });

  final bool bannerEnabled;
  final bool nativeEnabled;
  final String bannerUnitId;
  final String nativeUnitId;
  final String? nativeFactoryId;
  final double nativeHeight;
  final AdSize bannerSize;
  final Duration timeout;
  final bool fullWidth;
  final String debugLabel;

  @override
  State<RaceBannerNativeSlot> createState() => _RaceBannerNativeSlotState();
}

class _RaceBannerNativeSlotState extends State<RaceBannerNativeSlot> {
  BannerAd? _banner;
  NativeAd? _native;

  String? _winner; // 'banner' | 'native'
  bool _nativeReady = false;
  bool _timedOut = false;
  bool _bannerStashed = false;
  bool _nativeStashed = false;

  void _log(String message) {
    debugPrint('[Ads][${widget.debugLabel}] $message');
  }

  @override
  void initState() {
    super.initState();
    _log(
      'init banner=${widget.bannerEnabled} native=${widget.nativeEnabled} '
      'bannerId=${widget.bannerUnitId} nativeId=${widget.nativeUnitId} '
      'factory=${widget.nativeFactoryId ?? "-"}',
    );

    final reusedNative = _reuseNativeIfAvailable();
    final reusedBanner = _reuseBannerIfAvailable();

    if (reusedNative && reusedBanner) {
      // Both instantly available: keep first visual winner as native.
      _winner = 'native';
      _nativeReady = true;
      _stashCurrentBannerIfPossible();
      return;
    }
    if (reusedNative) {
      _winner = 'native';
      _nativeReady = true;
      return;
    }
    if (reusedBanner) {
      _winner = 'banner';
      return;
    }

    final requestedNative = _requestNativeIfNeeded();
    final requestedBanner = _requestBannerIfNeeded();

    if (!requestedNative && !requestedBanner) {
      _winner = 'none';
      return;
    }

    Future<void>.delayed(widget.timeout, () {
      if (!mounted) return;
      if (_winner != null) return;
      _timedOut = true;
      _log('timeout reached, no winner');
      _disposeNative();
      _disposeBanner();
      setState(() {});
    });
  }

  bool _requestNativeIfNeeded() {
    if (!widget.nativeEnabled) return false;
    if (widget.nativeUnitId.trim().isEmpty) return false;
    if (widget.nativeFactoryId == null || widget.nativeFactoryId!.trim().isEmpty) {
      return false;
    }
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;

    final cacheKey = _nativeCacheKey();
    final ad = NativeAd(
      adUnitId: widget.nativeUnitId,
      factoryId: widget.nativeFactoryId!,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (loaded) {
          if (loaded is! NativeAd) {
            loaded.dispose();
            return;
          }
          if (!mounted) {
            loaded.dispose();
            return;
          }
          if (_native == null || !identical(loaded, _native)) {
            loaded.dispose();
            return;
          }
          if (_winner == null) {
            _winner = 'native';
            _log('winner=native');
            _disposeBanner();
          } else if (_winner != 'native') {
            // Another ad already won in this slot; reuse native in a later slot.
            if (cacheKey.isNotEmpty) {
              _nativeStashed = true;
              _RaceAdReuseCache.stashNative(cacheKey, loaded);
              _native = null;
              _log('stash native for reuse key=$cacheKey');
            } else {
              loaded.dispose();
              _native = null;
            }
            return;
          }
          if (_winner == 'native') {
            setState(() => _nativeReady = true);
          }
        },
        onAdFailedToLoad: (ad, err) {
          _log('native failed (${err.code}) ${err.message}');
          if (!mounted) {
            ad.dispose();
            return;
          }
          final isCurrent = _native != null && identical(ad, _native);
          ad.dispose();
          if (isCurrent) {
            setState(() {
              _native = null;
              _nativeReady = false;
            });
          }
        },
      ),
    );
    _native = ad;
    _log('request native');
    ad.load();
    return true;
  }

  bool _requestBannerIfNeeded() {
    if (!widget.bannerEnabled) return false;
    final id = widget.bannerUnitId.trim();
    if (id.isEmpty) return false;
    if (kIsWeb) return false;

    final cacheKey = _bannerCacheKey();
    final ad = BannerAd(
      adUnitId: id,
      size: widget.bannerSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (loaded) {
          if (loaded is! BannerAd) {
            loaded.dispose();
            return;
          }
          if (!mounted) {
            loaded.dispose();
            return;
          }
          if (_banner == null || !identical(loaded, _banner)) {
            loaded.dispose();
            return;
          }
          if (_winner == null) {
            _winner = 'banner';
            _log('winner=banner');
            _disposeNative();
          } else if (_winner != 'banner') {
            // Another ad already won in this slot; reuse banner in a later slot.
            if (cacheKey.isNotEmpty) {
              _bannerStashed = true;
              _RaceAdReuseCache.stashBanner(cacheKey, loaded);
              _banner = null;
              _log('stash banner for reuse key=$cacheKey');
            } else {
              loaded.dispose();
              _banner = null;
            }
            return;
          }
          setState(() {});
        },
        onAdFailedToLoad: (ad, err) {
          _log('banner failed (${err.code}) ${err.message}');
          if (!mounted) {
            ad.dispose();
            return;
          }
          final isCurrent = _banner != null && identical(ad, _banner);
          ad.dispose();
          if (isCurrent) {
            setState(() {
              _banner = null;
            });
          }
        },
      ),
    );
    _banner = ad;
    _log('request banner');
    ad.load();
    return true;
  }

  @override
  void dispose() {
    _disposeBanner();
    _disposeNative();
    super.dispose();
  }

  void _disposeBanner() {
    final b = _banner;
    _banner = null;
    try {
      if (!_bannerStashed) {
        b?.dispose();
      }
      if (b != null) _log('dispose banner');
    } catch (_) {}
    _bannerStashed = false;
  }

  void _disposeNative() {
    final n = _native;
    _native = null;
    try {
      if (!_nativeStashed) {
        n?.dispose();
      }
      if (n != null) _log('dispose native');
    } catch (_) {}
    _nativeReady = false;
    _nativeStashed = false;
  }

  String _bannerCacheKey() {
    final unitId = widget.bannerUnitId.trim();
    if (unitId.isEmpty) return '';
    return _RaceAdReuseCache.bannerKey(unitId, widget.bannerSize);
  }

  String _nativeCacheKey() {
    final unitId = widget.nativeUnitId.trim();
    final factoryId = widget.nativeFactoryId?.trim() ?? '';
    if (unitId.isEmpty || factoryId.isEmpty) return '';
    return _RaceAdReuseCache.nativeKey(unitId, factoryId);
  }

  bool _reuseBannerIfAvailable() {
    final key = _bannerCacheKey();
    if (key.isEmpty) return false;
    final cached = _RaceAdReuseCache.takeBanner(key);
    if (cached == null) return false;
    _banner = cached;
    _log('reuse banner from cache key=$key');
    return true;
  }

  bool _reuseNativeIfAvailable() {
    final key = _nativeCacheKey();
    if (key.isEmpty) return false;
    final cached = _RaceAdReuseCache.takeNative(key);
    if (cached == null) return false;
    _native = cached;
    _log('reuse native from cache key=$key');
    return true;
  }

  void _stashCurrentBannerIfPossible() {
    final banner = _banner;
    final key = _bannerCacheKey();
    if (banner == null || key.isEmpty) return;
    _bannerStashed = true;
    _RaceAdReuseCache.stashBanner(key, banner);
    _banner = null;
    _log('stash banner (both-reused path) key=$key');
  }

  @override
  Widget build(BuildContext context) {
    if (_winner == 'none') return const SizedBox.shrink();
    if (_timedOut) return const SizedBox.shrink();

    final native = _native;
    if (_winner == 'native' && native != null) {
      return SizedBox(
        height: widget.nativeHeight,
        width: widget.fullWidth ? double.infinity : null,
        child: KeyedSubtree(
          key: ValueKey<bool>(_nativeReady),
          child: _nativeReady
              ? Align(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1,
                  child: AdWidget(ad: native),
                )
              : Align(
                  alignment: Alignment.bottomCenter,
                  widthFactor: 1,
                  child: ShimmerAdLayout(
                    height: widget.nativeHeight,
                    nativeFactoryId: widget.nativeFactoryId,
                  ),
                ),
        ),
      );
    }

    final banner = _banner;
    if (_winner == 'banner' && banner != null) {
      final w = banner.size.width.toDouble();
      final h = banner.size.height.toDouble();
      return SizedBox(
        height: h,
        width: double.infinity,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: w,
            height: h,
            child: AdWidget(ad: banner),
          ),
        ),
      );
    }

    final reservedHeight = widget.nativeEnabled
        ? widget.nativeHeight
        : widget.bannerSize.height.toDouble();

    // Banner-only: show simple reserved grey card.
    if (!widget.nativeEnabled && widget.bannerEnabled) {
      return SizedBox(
        height: reservedHeight,
        width: double.infinity,
        child: Container(
          width: double.infinity,
          height: reservedHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFE6E8EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              'Ad',
              style: TextStyle(
                color: Color(0xFF6D7786),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      );
    }

    // Native (or banner+native race): keep shimmer placeholder.
    return SizedBox(
      height: reservedHeight,
      width: double.infinity,
      child: Align(
        alignment: Alignment.bottomCenter,
        widthFactor: 1,
        child: ShimmerAdLayout(
          height: widget.nativeEnabled
              ? widget.nativeHeight
              : (widget.bannerSize.height.toDouble() + 28),
          nativeFactoryId: widget.nativeFactoryId,
        ),
      ),
    );
  }
}

