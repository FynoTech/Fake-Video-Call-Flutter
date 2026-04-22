import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/ads/ad_unit_ids.dart';
import '../../../widgets/app_shimmer.dart';

/// Single banner ad at the top of the splash screen.
/// Shows shimmer until load completes or fails.
class SplashTopBanners extends StatefulWidget {
  const SplashTopBanners({super.key});

  @override
  State<SplashTopBanners> createState() => _SplashTopBannersState();
}

enum _BannerSlot { idle, loading, ready, failed }

class _SplashTopBannersState extends State<SplashTopBanners> {
  BannerAd? _banner;
  _BannerSlot _slot = _BannerSlot.idle;

  @override
  void initState() {
    super.initState();
    final unitId = AdUnitIds.bannerTop;
    if (unitId.isEmpty) return;
    _slot = _BannerSlot.loading;
    final ad = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _slot = _BannerSlot.ready);
        },
        onAdFailedToLoad: (ad, err) {
          if (kDebugMode) {
            debugPrint(
              'SplashTopBanners: banner failed (${err.code}) ${err.message}',
            );
          }
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _slot = _BannerSlot.failed;
          });
        },
      ),
    );
    _banner = ad;
    ad.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  bool get _visible =>
      _slot == _BannerSlot.loading || _slot == _BannerSlot.ready;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final maxW = MediaQuery.sizeOf(context).width;
    final boxW = math.min(AdSize.banner.width.toDouble(), maxW);
    final boxH = AdSize.banner.height.toDouble();

    if (_slot == _BannerSlot.loading) {
      return SizedBox(
        height: boxH,
        width: double.infinity,
        child: Center(
          child: SizedBox(
            width: boxW,
            height: boxH,
            child: AppShimmer(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final ad = _banner;
    if (_slot == _BannerSlot.ready && ad != null) {
      return Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
