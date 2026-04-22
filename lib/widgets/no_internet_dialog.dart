import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';

/// Brand-styled alert when remote media needs the internet (matches [showExitAppDialog]).
Future<void> showNoInternetDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: AppColors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: AppColors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.appBarGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gradientAppBarEnd.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Turn on Wi‑Fi or mobile data to start this call. This content streams from the internet.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted55,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: AppColors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Ink(
                      decoration: const BoxDecoration(
                        gradient: AppColors.onboardingNextButtonGradient,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: Text(
                          'OK',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
