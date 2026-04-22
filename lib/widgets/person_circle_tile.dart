import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart';

import '../app/theme/app_colors.dart';
import '../core/services/network_status_service.dart';
import 'app_shimmer.dart';

/// Circular avatar + label; [isMore] shows the “+” placeholder instead of a photo.
class PersonCircleTile extends StatelessWidget {
  const PersonCircleTile({
    super.key,
    required this.label,
    this.imageUrl,
    this.isMore = false,
    required this.onTap,
    this.avatarSize = 56,
    this.borderWidth = 2,
    this.maxLabelLines = 2,
    this.labelColor,
    this.showAvatarBorder = true,
    this.avatarBadge,

    /// When true, tile reacts to connectivity for remote media (no red offline ring).
    this.needsNetworkForMedia = false,
  });

  final String label;
  final String? imageUrl;
  final bool isMore;
  final VoidCallback onTap;
  final double avatarSize;
  final double borderWidth;
  final int maxLabelLines;
  final Color? labelColor;
  final bool showAvatarBorder;
  final Widget? avatarBadge;
  final bool needsNetworkForMedia;

  static const Color _ringBlue = AppColors.gradientAppBarMid;

  static bool _httpUrl(String? u) {
    if (u == null || u.isEmpty) return false;
    final t = u.trim();
    return t.startsWith('http://') || t.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final reactiveNetwork = !isMore &&
        Get.isRegistered<NetworkStatusService>() &&
        (needsNetworkForMedia || _httpUrl(imageUrl));
    if (!reactiveNetwork) {
      return _buildTile(context, online: true);
    }
    return Obx(() {
      final online = Get.find<NetworkStatusService>().isConnected.value;
      return _buildTile(context, online: online);
    });
  }

  Widget _buildTile(BuildContext context, {required bool online}) {
    final showRing = showAvatarBorder || (needsNetworkForMedia && !online);
    final ringColor = _ringBlue;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              showRing
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: borderWidth),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: SizedBox(
                          width: avatarSize,
                          height: avatarSize,
                          child: ClipOval(
                            child: _buildInner(context, online: online),
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: ClipOval(child: _buildInner(context, online: online)),
                    ),
              if (avatarBadge != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: avatarBadge!,
                ),
            ],
          ),
          SizedBox(height: avatarSize * 0.1),
          SizedBox(
            width: avatarSize + 20,
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: maxLabelLines,
              overflow: TextOverflow.ellipsis,
              style: () {
                final base = Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                );
                if (labelColor == null) return base;
                return base?.copyWith(color: labelColor);
              }(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInner(BuildContext context, {required bool online}) {
    if (isMore) {
      return ColoredBox(
        color: AppColors.white,
        child: Center(
          child: Text(
            '+',
            style: TextStyle(
              fontSize: avatarSize * 0.5,
              fontWeight: FontWeight.w600,
              color: _ringBlue,
            ),
          ),
        ),
      );
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final raw = imageUrl!;
      if (!kIsWeb && (raw.startsWith('/') || raw.startsWith('file://'))) {
        final filePath = raw.startsWith('file://')
            ? raw.substring('file://'.length)
            : raw;
        return Image.file(
          File(filePath),
          fit: BoxFit.cover,
          width: avatarSize,
          height: avatarSize,
          errorBuilder: (_, __, ___) => _fallbackLetter(),
        );
      }
      if (_httpUrl(raw)) {
        return _OfflineAwareNetworkAvatar(
          imageUrl: raw.trim(),
          avatarSize: avatarSize,
          online: online,
          fallback: _fallbackLetter(),
        );
      }
      return CachedNetworkImage(
        imageUrl: raw,
        fit: BoxFit.cover,
        width: avatarSize,
        height: avatarSize,
        placeholder: (_, __) => ShimmerAvatarCircle(size: avatarSize),
        errorWidget: (_, __, ___) => _fallbackLetter(),
      );
    }
    return _fallbackLetter();
  }

  Widget _fallbackLetter() {
    final ch = label.isNotEmpty ? label[0].toUpperCase() : '?';
    return ColoredBox(
      color: AppColors.white,
      child: Center(
        child: Text(
          ch,
          style: TextStyle(
            fontSize: (avatarSize * 0.32).clamp(14.0, 22.0),
            fontWeight: FontWeight.w700,
            color: AppColors.gradientAppBarEnd,
          ),
        ),
      ),
    );
  }
}

/// Remote avatars: shimmer only while online and loading. Offline → disk cache if any, else static fallback (no endless shimmer).
class _OfflineAwareNetworkAvatar extends StatelessWidget {
  const _OfflineAwareNetworkAvatar({
    required this.imageUrl,
    required this.avatarSize,
    required this.online,
    required this.fallback,
  });

  final String imageUrl;
  final double avatarSize;
  final bool online;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (online) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: avatarSize,
        height: avatarSize,
        placeholder: (_, __) => ShimmerAvatarCircle(size: avatarSize),
        errorWidget: (_, __, ___) => fallback,
      );
    }
    return FutureBuilder<FileInfo?>(
      future: DefaultCacheManager().getFileFromCache(imageUrl),
      builder: (context, snapshot) {
        final file = snapshot.data?.file;
        if (file != null && file.path.isNotEmpty) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            width: avatarSize,
            height: avatarSize,
            errorBuilder: (_, __, ___) => fallback,
          );
        }
        return fallback;
      },
    );
  }
}
