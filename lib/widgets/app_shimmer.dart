import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app/theme/app_colors.dart';

// Native-ad shimmer palette aligned with splash button theme.
const Color _kAdShimmerCardBg = Color(0xFFF4EBFF);
const Color _kAdShimmerBlock = Color(0xFFB267FF);
const Color _kAdShimmerHighlight = Color(0xFFD8A9FF);

/// App-wide shimmer using the same cool blue-gray palette as feature cards.
class AppShimmer extends StatelessWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.shimmerBase,
      highlightColor: AppColors.shimmerHighlight,
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

/// Horizontal row of circle + label stubs (home “Live Video Call” strip).
class ShimmerLiveVideoRow extends StatelessWidget {
  const ShimmerLiveVideoRow({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: AppShimmer(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, __) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.shimmerBase,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 52,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerBase,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Grid of avatar + name stubs (persons catalog).
class ShimmerPersonGrid extends StatelessWidget {
  const ShimmerPersonGrid({super.key, this.itemCount = 9});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 1,
          crossAxisSpacing: 30,
          childAspectRatio: 0.80,
        ),
        itemCount: itemCount,
        itemBuilder: (_, __) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.shimmerBase,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 64,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 48,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.shimmerBase,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Rounded “card” rows for ringtone / list loading (same corner radius as home feature cards).
class ShimmerRingtoneList extends StatelessWidget {
  const ShimmerRingtoneList({super.key, this.itemCount = 10});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) {
          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.shimmerBase,
              borderRadius: BorderRadius.circular(11),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.shimmerHighlight.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: 180,
                        decoration: BoxDecoration(
                          color: AppColors.shimmerHighlight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 11,
                        width: 110,
                        decoration: BoxDecoration(
                          color: AppColors.shimmerHighlight.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Circular placeholder while a network avatar loads.
class ShimmerAvatarCircle extends StatelessWidget {
  const ShimmerAvatarCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.shimmerBase,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// Native-style loading skeleton: light grey card, purple border, static “Ad” + “Install”,
/// grey shimmer on the body so users see an ad is loading.
///
/// [nativeFactoryId] should match Android [NativeAd.factoryId] so the placeholder
/// matches `native_small_inline`, `native_small_button_bottom`, or `native_advance_button_bottom`.
class ShimmerAdLayout extends StatelessWidget {
  const ShimmerAdLayout({
    super.key,
    this.height = 170,
    this.nativeFactoryId,
  });

  final double height;
  final String? nativeFactoryId;

  @override
  Widget build(BuildContext context) {
    final id = nativeFactoryId ?? '';
    if (id == 'native_small_inline') {
      return _ShimmerNativeInlineCard(height: height);
    }
    if (id == 'native_small_button_bottom') {
      return _ShimmerNativeBottomCtaCard(height: height, showMedia: false);
    }
    return _ShimmerNativeBottomCtaCard(
      height: height,
      showMedia: id == 'native_advance_button_bottom',
      tallMedia: id == 'native_advance_button_bottom',
    );
  }
}

/// Horizontal native: Ad + icon + text (left) | Install CTA (right), like [native_small_inline].
class _ShimmerNativeInlineCard extends StatelessWidget {
  const _ShimmerNativeInlineCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    const pad = 8.0;
    const radius = 12.0;
    final h = height.clamp(96.0, 220.0);
    final innerH = (h - pad * 2).clamp(56.0, 200.0);
    final ctaW = innerH.clamp(52.0, 72.0);

    return SizedBox(
      width: double.infinity,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kAdShimmerCardBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.gradientAppBarEnd.withValues(alpha: 0.55),
            width: 1.25,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(pad),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 14,
                child: SizedBox(
                  height: innerH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const _ShimmerAdBadge(compact: true),
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _kAdShimmerBlock,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Shimmer.fromColors(
                          baseColor: _kAdShimmerBlock,
                          highlightColor: _kAdShimmerHighlight,
                          period: const Duration(milliseconds: 1100),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 13,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: _kAdShimmerBlock,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 11,
                                width: 120,
                                decoration: BoxDecoration(
                                  color: _kAdShimmerBlock,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 10,
                                width: 90,
                                decoration: BoxDecoration(
                                  color: _kAdShimmerBlock,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: ctaW,
                height: (innerH - 4).clamp(34.0, 48.0),
                child: const _ShimmerInstallCta(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical native: top row (Ad + icon + headline) + optional [MediaView] block + full-width CTA.
class _ShimmerNativeBottomCtaCard extends StatelessWidget {
  const _ShimmerNativeBottomCtaCard({
    required this.height,
    required this.showMedia,
    this.tallMedia = false,
  });

  final double height;
  final bool showMedia;
  final bool tallMedia;

  @override
  Widget build(BuildContext context) {
    final h = height;
    final pad = h <= 150 ? 8.0 : 10.0;
    var gap = h <= 150 ? 6.0 : 8.0;
    final radius = h <= 150 ? 10.0 : 12.0;
    var ctaH = tallMedia ? 44.0 : 36.0;
    var headerH = (showMedia ? 56.0 : 52.0).clamp(44.0, 64.0);
    final innerAvail = h - pad * 2;

    double mediaH = 0;
    if (showMedia) {
      final cap = innerAvail - headerH - gap - ctaH - gap;
      mediaH = cap.clamp(0.0, 160.0);
    }

    // Tight [h] (e.g. small native slots): scale gaps / header / CTA so Column never overflows.
    var minColumn = headerH + ctaH + (showMedia ? mediaH + 2 * gap : gap);
    if (minColumn > innerAvail) {
      final f = innerAvail / minColumn;
      headerH = (headerH * f).clamp(30.0, 64.0);
      ctaH = (ctaH * f).clamp(22.0, 44.0);
      gap = (gap * f).clamp(2.0, 8.0);
      if (showMedia) {
        mediaH = (innerAvail - headerH - 2 * gap - ctaH).clamp(0.0, 160.0);
      }
    }

    return SizedBox(
      width: double.infinity,
      height: h,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _kAdShimmerCardBg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.gradientAppBarEnd.withValues(alpha: 0.55),
            width: 1.25,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: headerH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerAdBadge(compact: h <= 170),
                    SizedBox(width: h <= 170 ? 8 : 10),
                    Expanded(
                      child: Shimmer.fromColors(
                        baseColor: _kAdShimmerBlock,
                        highlightColor: _kAdShimmerHighlight,
                        period: const Duration(milliseconds: 1100),
                        child: _ShimmerNativeHeaderRow(compact: h <= 170),
                      ),
                    ),
                  ],
                ),
              ),
              if (showMedia) ...[
                SizedBox(height: gap),
                SizedBox(
                  height: mediaH,
                  child: Shimmer.fromColors(
                    baseColor: _kAdShimmerBlock,
                    highlightColor: _kAdShimmerHighlight,
                    period: const Duration(milliseconds: 1100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kAdShimmerBlock,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              SizedBox(height: gap),
              SizedBox(
                height: ctaH,
                child: const _ShimmerInstallCta(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerNativeHeaderRow extends StatelessWidget {
  const _ShimmerNativeHeaderRow({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final icon = compact ? 36.0 : 40.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: icon,
          height: icon,
          decoration: BoxDecoration(
            color: _kAdShimmerBlock,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: compact ? 11 : 13,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _kAdShimmerBlock,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: compact ? 6 : 8),
              Container(
                height: compact ? 9 : 11,
                width: compact ? 140 : 180,
                decoration: BoxDecoration(
                  color: _kAdShimmerBlock,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShimmerAdBadge extends StatelessWidget {
  const _ShimmerAdBadge({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'Ad',
        style: TextStyle(
          color: AppColors.white,
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _ShimmerInstallCta extends StatelessWidget {
  const _ShimmerInstallCta();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primaryColor,
        border: Border.all(color: AppColors.black, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          'Install',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
