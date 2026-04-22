import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/network_reachability.dart';
import '../../../core/services/persons_storage_service.dart';
import '../../../widgets/ad_loading_dialog.dart';

class PersonsCatalogController extends GetxController {
  PersonsStorageService get storage => Get.find<PersonsStorageService>();
  late final bool forVideoCall;
  bool _openingCall = false;

  /// Audio catalog hides [PersonItem.videoCallOnly]; video catalog shows everyone.
  List<PersonItem> get visiblePersons {
    final list = storage.persons;
    if (forVideoCall) return list.toList();
    return list.where((p) => !p.videoCallOnly).toList();
  }

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    forVideoCall = args is Map && args['forVideoCall'] == true;
  }

  Future<void> onPersonTap(PersonItem person) async {
    if (_openingCall) return;
    _openingCall = true;
    try {
      var openAudio = false;
      var openVideo = false;
      await showAdLoadingDialog<void>(
        task: () async {
          if (!forVideoCall) {
            final ok = await ensureInternetForPersonCall(
              Get.context,
              person: person,
              mediaUrl: person.audioUrl,
            );
            if (!ok) return;
            openAudio = true;
            return;
          }

          final ok = await ensureInternetForPersonCall(
            Get.context,
            person: person,
            mediaUrl: person.videoUrl,
          );
          if (!ok) return;
          openVideo = true;
        },
        title: 'Ad Loading',
      );
      if (openAudio) {
        Get.toNamed(AppRoutes.audioCall, arguments: {'person': person});
      } else if (openVideo) {
        Get.toNamed(AppRoutes.videoCall, arguments: {'person': person});
      }
    } finally {
      _openingCall = false;
    }
  }

  @override
  void onReady() {
    super.onReady();
    if (storage.persons.isEmpty && !storage.isLoading.value) {
      storage.loadPersons();
    }
  }
}
