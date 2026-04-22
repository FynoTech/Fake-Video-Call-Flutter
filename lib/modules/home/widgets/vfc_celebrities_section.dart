import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/localization/vfc_category_localization.dart';
import '../../../core/models/person_item.dart';
import '../../../core/models/vfc_celebrity_catalog.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/subscription_service.dart';
import '../../../widgets/person_circle_tile.dart';

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
  final void Function(PersonItem person, {bool forceWatchAdGate}) onCelebrityTap;
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
                  : Border.all(color: Colors.black.withValues(alpha: 0.08)),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF7EC8F5),
                        Color(0xFF5FAFE0),
                        Color(0xFF4A90C2),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
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
      padding: const EdgeInsets.only(top: 14),
      shrinkWrap: !expandGrid,
      physics: expandGrid
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 9,
        crossAxisSpacing: 0,
        // Slightly taller tiles prevent bottom text overflow on smaller screens.
        childAspectRatio: 0.74,
      ),
      itemCount: deduped.length,
      itemBuilder: (context, index) {
        final person = deduped[index];
        final tapBlocked = _isTapBlocked(
          person: person,
          category: category,
        );
        return Obx(() {
          final isPremium =
              Get.isRegistered<SubscriptionService>() &&
              Get.find<SubscriptionService>().isPremium.value;
          // Hide the watch-ad video badge (and its gate) for premium users.
          final showVideoBadge = !isPremium && (index + 1) % 3 == 0;
          return PersonCircleTile(
            label: _tileLabel(person: person, category: category),
            imageUrl: person.imageUrl,
            avatarSize: avatarSize,
            showAvatarBorder: false,
            maxLabelLines: 2,
            labelColor: AppColors.black,
            avatarBadge: showVideoBadge ? const _VideoCornerBadge() : null,
            needsNetworkForMedia: isRemoteMediaUrl(person.videoUrl),
            onTap: () {
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
            },
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

class _VideoCornerBadge extends StatelessWidget {
  const _VideoCornerBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.gradientAppBarEnd,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.white, width: 1.2),
      ),
      child: const Icon(
        Icons.videocam_rounded,
        size: 12,
        color: AppColors.white,
      ),
    );
  }
}
