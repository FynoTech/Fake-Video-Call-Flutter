import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../app/theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 92,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/data/loading.json',
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (_, __, ___) => const Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.gradientAppBarEnd,
            ),
          ),
        ),
      ),
    );
  }
}
