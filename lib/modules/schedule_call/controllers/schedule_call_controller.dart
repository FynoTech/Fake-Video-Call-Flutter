import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/call_scheduler_service.dart';
import '../../../core/services/network_reachability.dart';

enum ScheduledCallType { audio, video }

class ScheduleCallController extends GetxController {
  late final PersonItem person;

  final selectedType = ScheduledCallType.video.obs;
  final selectedDelay = Duration.zero.obs;
  final isIncoming = true.obs;

  final isSubmitting = false.obs;

  bool get hasAudio => (person.audioUrl?.trim().isNotEmpty ?? false);
  bool get hasVideo => (person.videoUrl?.trim().isNotEmpty ?? false);

  List<ScheduledCallType> get availableTypes {
    final out = <ScheduledCallType>[];
    if (hasAudio) out.add(ScheduledCallType.audio);
    if (hasVideo) out.add(ScheduledCallType.video);
    return out;
  }

  String get delayLabel {
    final d = selectedDelay.value;
    if (d == Duration.zero) return 'schedule_now'.tr;
    if (d.inSeconds < 60) return '${d.inSeconds} ${'schedule_seconds'.tr}';
    if (d.inMinutes < 60) return '${d.inMinutes} ${'schedule_minutes'.tr}';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (m == 0) return '$h ${'schedule_hours'.tr}';
    return '$h ${'schedule_hours'.tr} $m ${'schedule_minutes'.tr}';
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    final p = args is Map ? args['person'] : null;
    if (p is PersonItem) {
      person = p;
    } else {
      throw Exception('ScheduleCall requires a person argument');
    }
    selectedType.value = hasAudio ? ScheduledCallType.audio : ScheduledCallType.video;
  }

  void chooseType(ScheduledCallType type) {
    selectedType.value = type;
  }

  void chooseDelay(Duration d) {
    selectedDelay.value = d;
  }

  void chooseIncoming(bool incoming) {
    isIncoming.value = incoming;
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;
    isSubmitting.value = true;
    try {
      final type = hasAudio ? ScheduledCallType.audio : ScheduledCallType.video;
      final delay = selectedDelay.value;

      if (type == ScheduledCallType.audio) {
        final ok = await ensureInternetForPersonCall(
          Get.context,
          person: person,
          mediaUrl: person.audioUrl,
        );
        if (!ok) return;
        if (delay > Duration.zero) {
          Future<void>.delayed(delay, () {
            Get.toNamed(AppRoutes.audioCall, arguments: {'person': person});
          });
          Get.back();
          Get.snackbar(
            'schedule_snackbar_title'.tr,
            'schedule_audio_scheduled_after'.trParams({'delay': delayLabel}),
          );
          return;
        }
        Get.toNamed(AppRoutes.audioCall, arguments: {'person': person});
        return;
      }

      final ok = await ensureInternetForPersonCall(
        Get.context,
        person: person,
        mediaUrl: person.videoUrl,
      );
      if (!ok) return;

      if (delay > Duration.zero) {
        final scheduler = Get.find<CallSchedulerService>();
        final done = await scheduler.scheduleVideoCall(delay: delay, person: person);
        if (done) {
          Get.back();
          Get.snackbar(
            'schedule_snackbar_title'.tr,
            'schedule_video_scheduled_after'.trParams({'delay': delayLabel}),
          );
        }
        return;
      }

      Get.toNamed(AppRoutes.videoCall, arguments: {'person': person});
    } finally {
      isSubmitting.value = false;
    }
  }
}
