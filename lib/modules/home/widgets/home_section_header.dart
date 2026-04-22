import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    this.onActionTap,
    this.pillAction = false,
  });

  final String title;
  final String actionText;
  final VoidCallback? onActionTap;

  /// Pill gradient + white label (e.g. Main Features → See All).
  final bool pillAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
            fontFamily: AppColors.fontFamily,
          ),
        ),
        if (actionText.isNotEmpty)
          pillAction
              ? _PillSeeAllButton(
                  label: actionText,
                  onTap: onActionTap,
                )
              : GestureDetector(
                  onTap: onActionTap,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    actionText,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                  ),
                ),
      ],
    );
  }
}

class _PillSeeAllButton extends StatelessWidget {
  const _PillSeeAllButton({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.gradientAppBarStart,
                AppColors.gradientAppBarMid,
                AppColors.gradientAppBarEnd,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
