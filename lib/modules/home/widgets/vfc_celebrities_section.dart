import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/vfc_category_localization.dart';
import '../../../core/models/person_item.dart';
import '../../../core/models/vfc_celebrity_catalog.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/app_shimmer.dart';

/// Category tabs + celebrity grid driven by [VfcCelebrityCatalog].
class VfcCelebritiesSection extends StatelessWidget {
  const VfcCelebritiesSection({
    super.key,
    required this.catalog,
    required this.selectedCategoryIndex,
    required this.onCategoryChanged,
    required this.onCelebrityTap,
    this.extraPersonsForSelected = const <PersonItem>[],
    this.expandGrid = false,
    this.avatarSize = 68,
  });

  final VfcCelebrityCatalog catalog;
  final int selectedCategoryIndex;
  final ValueChanged<int> onCategoryChanged;
  final void Function(PersonItem person, {bool forceWatchAdGate})
  onCelebrityTap;
  final List<PersonItem> extraPersonsForSelected;
  final bool expandGrid;
  final double avatarSize;

  VfcCelebrity? _celebrityForPerson(PersonItem person, VfcCategory category) {
    final path = person.storageFolderPath;
    if (!path.startsWith('vfc_v2/')) return null;
    final parts = path.split('/');
    if (parts.length < 3) return null;
    final celebId = parts.last;
    for (final c in category.celebrities) {
      if (c.id == celebId) return c;
    }
    return null;
  }

  bool _hasImage(PersonItem p) =>
      p.imageUrl != null && p.imageUrl!.trim().isNotEmpty;

  bool _hasPlayableVideo(PersonItem p) =>
      p.videoUrl != null && p.videoUrl!.trim().isNotEmpty;

  /// True when tap should not open a call (missing media, JSON `coming_soon`, or catalog suppress).
  bool _isTapBlocked({
    required PersonItem person,
    required VfcCategory category,
  }) {
    if (!person.storageFolderPath.startsWith('vfc_v2/')) return false;
    final ready = _hasImage(person) && _hasPlayableVideo(person);
    if (!ready) return true;
    final celeb = _celebrityForPerson(person, category);
    final o = celeb?.comingSoonExplicit;
    if (o == true) return true;
    if (o == false) return false;
    return catalog.suppressReadyCelebrityTaps;
  }

  /// Label under avatar: real name whenever catalog has playable media; “Coming Soon” only if data is incomplete.
  /// ([catalog.suppressReadyCelebrityTaps] blocks tap only — it must not hide names; offline does not change this.)
  String _tileLabel({
    required PersonItem person,
    required VfcCategory category,
  }) {
    if (!person.storageFolderPath.startsWith('vfc_v2/')) {
      return person.name;
    }
    final ready = _hasImage(person) && _hasPlayableVideo(person);
    if (!ready) return 'Coming Soon';
    return person.name;
  }

  PersonItem _withRandomVfcVideo({
    required PersonItem person,
    required VfcCategory category,
    required String baseUrl,
  }) {
    final celeb = _celebrityForPerson(person, category);
    if (celeb == null) return person;
    final playable = celeb.videos.where((v) => v.trim().isNotEmpty).toList();
    if (playable.isEmpty) return person;
    final idx = Random().nextInt(playable.length);
    final randomVideo = VfcCelebrityCatalog.joinMediaUrl(
      baseUrl,
      playable[idx],
    );
    return PersonItem(
      name: person.name,
      storageFolderPath: person.storageFolderPath,
      imageUrl: person.imageUrl,
      audioUrl: person.audioUrl,
      videoUrl: randomVideo,
      videoCallOnly: person.videoCallOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (catalog.categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = selectedCategoryIndex.clamp(
      0,
      catalog.categories.length - 1,
    );
    final category = catalog.categories[safeIndex];
    final celebrities = category.celebrities
        .where((c) => c.firstNonEmptyVideoPath != null)
        .toList();
    final mergedPersons = <PersonItem>[
      ...extraPersonsForSelected,
      ...celebrities.map(
        (cel) =>
            cel.toPersonItem(baseUrl: catalog.baseUrl, categoryId: category.id),
      ),
    ];
    final seen = <String>{};
    final deduped = <PersonItem>[];
    for (final p in mergedPersons) {
      final key = '${p.name.trim().toLowerCase()}|${p.videoUrl ?? ''}';
      if (seen.add(key)) deduped.add(p);
    }

    final tabRow = SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: catalog.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = catalog.categories[i];
          final selected = i == safeIndex;
          final radius = BorderRadius.circular(22);
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: selected
                  ? null
                  : Border.all(color: const Color(0xFF4A4A4A)),
              color: selected
                  ? AppColors.primaryColor
                  : AppColors.backgroundColor,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: () => onCategoryChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  child: Center(
                    child: Text(
                      localizedVfcCategoryName(c.id, c.name),
                      style: TextStyle(
                        fontFamily: AppColors.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? AppColors.white
                            : AppColors.textMuted65,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    final grid = GridView.builder(
      padding: EdgeInsets.only(top: expandGrid ? 14 : 14),
      shrinkWrap: !expandGrid,
      physics: expandGrid
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: expandGrid ? 3 : 4,
        mainAxisSpacing: expandGrid ? 16 : 9,
        crossAxisSpacing: expandGrid ? 8 : 0,
        childAspectRatio: expandGrid ? 0.72 : 0.74,
      ),
      itemCount: deduped.length,
      itemBuilder: (context, index) {
        final person = deduped[index];
        final tapBlocked = _isTapBlocked(person: person, category: category);
        return Obx(() {
          final isPremium =
              Get.isRegistered<SubscriptionService>() &&
              Get.find<SubscriptionService>().isPremium.value;
          final showVideoBadge = !isPremium && (index + 1) % 3 == 0;
          void handleTap() {
            if (tapBlocked) {
              Get.snackbar(
                'vfc_coming_soon_title'.tr,
                'vfc_coming_soon_body'.tr,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(12),
              );
              return;
            }
            onCelebrityTap(
              _withRandomVfcVideo(
                person: person,
                category: category,
                baseUrl: catalog.baseUrl,
              ),
              forceWatchAdGate: showVideoBadge,
            );
          }

          if (expandGrid) {
            return TrendingCelebrityCard(
              name: _tileLabel(person: person, category: category),
              imageUrl: person.imageUrl,
              gradient: kTrendingGradients[index % kTrendingGradients.length],
              showOnlineDot: false,
              showVideoBadge: showVideoBadge,
              onTap: handleTap,
            );
          }

          return TrendingCelebrityCard(
            name: _tileLabel(person: person, category: category),
            imageUrl: person.imageUrl,
            gradient: kTrendingGradients[index % kTrendingGradients.length],
            showOnlineDot: true,
            showVideoBadge: showVideoBadge,
            onTap: handleTap,
          );
        });
      },
    );

    if (expandGrid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          tabRow,
          Expanded(child: grid),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [tabRow, grid],
    );
  }
}

// ---------------------------------------------------------------------------
// Trending celebrity card (used on See All screen + home "Trending Calls").
// ---------------------------------------------------------------------------

// Very soft pastel gradients – light card surface, subtle tint, premium feel.
const List<List<Color>> kTrendingGradients = <List<Color>>[
  [Color(0xFFF2E9FF), Color(0xFFE4F0FF)], // lilac → sky
  [Color(0xFFEAF2FF), Color(0xFFF6ECFF)], // sky → lilac
  [Color(0xFFFFEFF2), Color(0xFFFDE4EF)], // rose
  [Color(0xFFEBF7EE), Color(0xFFE1F1FF)], // mint → sky
  [Color(0xFFFFF3E1), Color(0xFFFFE9EC)], // peach → rose
  [Color(0xFFEFF1FB), Color(0xFFE6ECFA)], // steel lavender
];

class TrendingCelebrityCard extends StatelessWidget {
  const TrendingCelebrityCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.gradient,
    required this.showOnlineDot,
    required this.showVideoBadge,
    required this.onTap,
  });

  final String name;
  final String? imageUrl;
  final List<Color> gradient;
  final bool showOnlineDot;
  final bool showVideoBadge;
  final VoidCallback onTap;

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
                        child: _ScallopAvatar(
                          imageUrl: imageUrl,
                          showOnlineDot: showOnlineDot,
                          showVideoBadge: false,
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
              if (showVideoBadge)
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

class _ScallopAvatar extends StatelessWidget {
  const _ScallopAvatar({
    required this.imageUrl,
    required this.showOnlineDot,
    required this.showVideoBadge,
  });

  final String? imageUrl;
  final bool showOnlineDot;
  final bool showVideoBadge;

  bool get _hasRemoteUrl {
    final u = imageUrl?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Outer scallop – acts as the thick white border.
              ClipPath(
                clipper: const _ScallopClipper(petals: 12, innerFactor: 0.86),
                child: Container(
                  width: size,
                  height: size,
                  color: AppColors.white,
                ),
              ),
              // Inner scallop – same flower shape, slightly smaller,
              // so the white ring shows uniformly around the image.
              ClipPath(
                clipper: const _ScallopClipper(petals: 12, innerFactor: 0.86),
                child: SizedBox(
                  width: size * 0.93,
                  height: size * 0.93,
                  child: _hasRemoteUrl
                      ? CachedNetworkImage(
                          imageUrl: imageUrl!.trim(),
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 200),
                          placeholder: (_, __) => const AppShimmer(
                            child: ColoredBox(
                              color: AppColors.shimmerBase,
                              child: SizedBox.expand(),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const _AvatarFallback(),
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

/// Flower-petal (scalloped) clip path.
///
/// Built as the union of an inner disc + [petals] evenly-spaced circular
/// bumps around its rim. Flutter's default non-zero winding rule merges the
/// overlapping ovals into a single filled flower silhouette.
class _ScallopClipper extends CustomClipper<Path> {
  const _ScallopClipper({this.petals = 12, this.innerFactor = 0.88});

  /// Number of outer petals.
  final int petals;

  /// How much of the outer radius is taken by the inner disc (0..1).
  /// Larger = softer scallop, smaller = more pronounced petals.
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
