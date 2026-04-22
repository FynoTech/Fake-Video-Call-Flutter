import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import 'app_loading_indicator.dart';

class CallOpeningLoader extends StatelessWidget {
  const CallOpeningLoader({
    super.key,
    this.title = 'Connecting call',
    this.subtitle = 'Getting everything ready...',
    this.showCard = true,
    this.titleColor,
    this.subtitleColor,
    this.indicatorSize,
    this.cardWidth = 220,
    this.cardOpacity = 0.97,
  });

  final String title;
  final String subtitle;
  final bool showCard;
  /// When set (e.g. on dark call overlay), title uses this instead of [AppColors.black87].
  final Color? titleColor;
  final Color? subtitleColor;
  /// Lottie loader size; default 72, call ad overlay uses a larger value.
  final double? indicatorSize;
  final double cardWidth;
  final double cardOpacity;

  @override
  Widget build(BuildContext context) {
    final titleCol = titleColor ?? AppColors.black87;
    final subtitleCol = subtitleColor ?? AppColors.textMuted55;
    final spinSize = indicatorSize ?? 72.0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLoadingIndicator(size: spinSize),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: titleCol,
            fontWeight: FontWeight.w700,
            fontFamily: AppColors.fontFamily,
          ),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: subtitleCol,
              fontWeight: FontWeight.w500,
              fontFamily: AppColors.fontFamily,
            ),
          ),
        ],
      ],
    );

    if (!showCard) {
      return Center(child: content);
    }

    return Center(
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: cardOpacity.clamp(0.0, 1.0)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gradientAppBarEnd.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: content,
      ),
    );
  }
}
