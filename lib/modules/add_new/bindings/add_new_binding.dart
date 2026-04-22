import 'package:get/get.dart';

import '../controllers/add_new_controller.dart';

class AddNewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AddNewController>(() => AddNewController());
  }
}

