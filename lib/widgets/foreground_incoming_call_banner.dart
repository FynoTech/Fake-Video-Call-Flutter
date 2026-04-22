import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../app/routes/app_routes.dart';
import '../core/incoming_call_notif_ids.dart';
import '../app/theme/app_colors.dart';
import '../core/models/person_item.dart';
import '../core/services/call_scheduler_service.dart';
import '../core/services/incoming_call_feedback.dart';
import '../core/services/network_reachability.dart';
import '../core/services/storage_service.dart';

/// In-app “incoming call” strip when the user is actively using the app (foreground).
class ForegroundIncomingCallBanner {
  ForegroundIncomingCallBanner._();

  static const Duration _autoDismissAfter = Duration(seconds: 10);

  static OverlayEntry? _entry;
  static IncomingCallFeedback? _incomingFeedback;
  static Timer? _autoDismissTimer;

  static Future<void> _stopIncomingFeedback() async {
    await _incomingFeedback?.stop();
    _incomingFeedback = null;
  }

  static void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  static void _cancelAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  static void dismiss() {
    _cancelAutoDismiss();
    _removeOverlay();
    unawaited(_stopIncomingFeedback());
    unawaited(
      FlutterLocalNotificationsPlugin()
          .cancel(id: kForegroundIncomingDisplayNotifId),
    );
  }

  static Future<void> _startIncomingFeedback() async {
    await _stopIncomingFeedback();
    try {
      final storage = Get.find<StorageService>();
      _incomingFeedback = IncomingCallFeedback(storage);
      await _incomingFeedback!.start();
    } catch (_) {}
  }

  /// Context that can host an [Overlay] (GetX sometimes returns null for [Get.overlayContext]).
  static BuildContext? pickOverlayContext() {
    final candidates = <BuildContext?>[
      Get.overlayContext,
      Get.key.currentContext,
      Get.context,
    ];
    for (final c in candidates) {
      if (c == null || !c.mounted) continue;
      if (Overlay.maybeOf(c, rootOverlay: true) != null) return c;
    }
    return null;
  }

  /// Shows a top banner; [onAccept] opens video call, [onDecline] only dismisses.
  static void show(
    BuildContext context, {
    required PersonItem person,
  }) {
    _cancelAutoDismiss();
    _removeOverlay();
    unawaited(_stopIncomingFeedback());
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (ctx) {
        final top = MediaQuery.of(ctx).padding.top + 8;
        final name =
            person.firstName.isEmpty ? person.name : person.firstName;
        return Stack(
          children: [
            Positioned(
              top: top,
              left: 14,
              right: 14,
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: AppColors.appBarGradient,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _CallerAvatar(imageUrl: person.imageUrl),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'incoming_call_body'.trArgs([name]),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppColors.fontFamily,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RoundAction(
                          color: const Color(0xFFE53935),
                          icon: Icons.call_end_rounded,
                          onTap: () {
                            final scheduler = Get.isRegistered<CallSchedulerService>()
                                ? Get.find<CallSchedulerService>()
                                : null;
                            if (scheduler != null) {
                              unawaited(scheduler.rejectIncoming(person: person));
                            } else {
                              dismiss();
                            }
                          },
                        ),
                        const SizedBox(width: 10),
                        _RoundAction(
                          color: const Color(0xFF43A047),
                          icon: Icons.videocam_rounded,
                          onTap: () async {
                            final ok = await ensureInternetForPersonCall(
                              ctx,
                              person: person,
                              mediaUrl: person.videoUrl,
                            );
                            if (!ok) return;
                            dismiss();
                            Get.toNamed(
                              AppRoutes.videoCall,
                              arguments: {'person': person},
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_entry!);
    unawaited(_startIncomingFeedback());
    _autoDismissTimer = Timer(_autoDismissAfter, dismiss);
  }
}

class _CallerAvatar extends StatelessWidget {
  const _CallerAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return CircleAvatar(
      radius: 26,
      backgroundColor: Colors.white24,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: Colors.white30,
        backgroundImage: url != null &&
                (url.startsWith('http://') || url.startsWith('https://'))
            ? NetworkImage(url)
            : null,
        child: url == null ||
                !(url.startsWith('http://') || url.startsWith('https://'))
            ? const Icon(Icons.person_rounded, color: Colors.white, size: 28)
            : null,
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
