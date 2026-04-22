import 'package:get/get.dart';

import '../../../core/services/persons_storage_service.dart';
import '../controllers/persons_catalog_controller.dart';

class PersonsCatalogBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<PersonsStorageService>()) {
      Get.lazyPut<PersonsStorageService>(() => PersonsStorageService());
    }
    Get.lazyPut<PersonsCatalogController>(() => PersonsCatalogController());
  }
}
