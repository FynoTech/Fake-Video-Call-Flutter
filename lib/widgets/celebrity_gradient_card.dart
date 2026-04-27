import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/theme/app_colors.dart';
import 'app_shimmer.dart';

class CelebrityGradientCard extends StatelessWidget {
  const CelebrityGradientCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.gradient,
    required this.onTap,
    this.showOnlineDot = true,
    this.showPremiumBadge = false,
  });

  final String name;
  final String? imageUrl;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool showOnlineDot;
  final bool showPremiumBadge;

  bool get _hasRemoteUrl {
    final u = imageUrl?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (_, constraints) {
                            final size = constraints.biggest.shortestSide;
                            return SizedBox(
                              width: size,
                              height: size,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  ClipPath(
                                    clipper: const _ScallopClipper(
                                      petals: 12,
                                      innerFactor: 0.86,
                                    ),
                                    child: Container(
                                      width: size,
                                      height: size,
                                      color: AppColors.white,
                                    ),
                                  ),
                                  ClipPath(
                                    clipper: const _ScallopClipper(
                                      petals: 12,
                                      innerFactor: 0.86,
                                    ),
                                    child: SizedBox(
                                      width: size * 0.93,
                                      height: size * 0.93,
                                      child: _hasRemoteUrl
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl!.trim(),
                                              fit: BoxFit.cover,
                                              fadeInDuration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              placeholder: (_, __) =>
                                                  const AppShimmer(
                                                child: ColoredBox(
                                                  color: AppColors.shimmerBase,
                                                  child: SizedBox.expand(),
                                                ),
                                              ),
                                              errorWidget: (_, __, ___) =>
                                                  const _AvatarFallback(),
                                            )
                                          : const _AvatarFallback(),
                                    ),
                                  ),
                                  if (showOnlineDot)
                                    Positioned(
                                      top: size * 0.06,
                                      right: size * 0.06,
                                      child: Container(
                                        width: size * 0.16,
                                        height: size * 0.16,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.white,
                                            width: size * 0.03,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.black,
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (showPremiumBadge)
                const Positioned(
                  top: 8,
                  left: 8,
                  child: _PremiumCrownBadge(size: 25),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumCrownBadge extends StatelessWidget {
  const _PremiumCrownBadge({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8A4BFF).withValues(alpha: 0.30),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SvgPicture.asset(
        'assets/premium/ic_premium_badge.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEDEDED),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 40,
        color: Color(0xFFBDBDBD),
      ),
    );
  }
}

class _ScallopClipper extends CustomClipper<Path> {
  const _ScallopClipper({this.petals = 12, this.innerFactor = 0.88});

  final int petals;
  final double innerFactor;

  @override
  Path getClip(Size size) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    final innerR = outerR * innerFactor;
    final bumpRadius = outerR - innerR + outerR * 0.05;
    final ringR = outerR - bumpRadius;

    path.addOval(Rect.fromCircle(center: center, radius: innerR));
    for (int i = 0; i < petals; i++) {
      final angle = -pi / 2 + i * (2 * pi / petals);
      final c = Offset(
        center.dx + cos(angle) * ringR,
        center.dy + sin(angle) * ringR,
      );
      path.addOval(Rect.fromCircle(center: c, radius: bumpRadius));
    }
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
