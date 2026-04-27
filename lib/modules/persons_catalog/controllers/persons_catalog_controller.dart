import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/models/person_item.dart';
import '../../../core/services/persons_storage_service.dart';

class PersonsCatalogController extends GetxController {
  PersonsStorageService get storage => Get.find<PersonsStorageService>();
  late final bool forVideoCall;
  bool _openingCall = false;

  bool _isBlockedInAudioCatalog(PersonItem p) {
    final name = p.name.trim().toLowerCase();
    final folder = p.storageFolderPath.trim().toLowerCase();
    return name == 'minal khan' || folder.endsWith('/minal_khan');
  }

  /// Audio catalog hides [PersonItem.videoCallOnly]; video catalog shows everyone.
  List<PersonItem> get visiblePersons {
    final list = storage.persons;
    if (forVideoCall) return list.toList();
    return list
        .where(
          (p) =>
              !p.videoCallOnly &&
              !PersonsStorageService.isCustomStoragePath(p.storageFolderPath) &&
              (p.audioUrl?.trim().isNotEmpty ?? false) &&
              !_isBlockedInAudioCatalog(p),
        )
        .toList();
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
      final hasAudio = person.audioUrl?.trim().isNotEmpty ?? false;
      final hasVideo = person.videoUrl?.trim().isNotEmpty ?? false;
      final route = forVideoCall
          ? (hasVideo ? AppRoutes.videoCall : AppRoutes.audioCall)
          : (hasAudio ? AppRoutes.audioCall : AppRoutes.videoCall);
      Get.toNamed(route, arguments: {'person': person});
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
