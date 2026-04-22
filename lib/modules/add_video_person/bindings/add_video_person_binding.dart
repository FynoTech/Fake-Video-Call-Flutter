import 'package:get/get.dart';

import '../../../core/services/call_scheduler_service.dart';
import '../controllers/add_video_person_controller.dart';

class AddVideoPersonBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CallSchedulerService>()) {
      final svc = Get.put<CallSchedulerService>(
        CallSchedulerService(),
        permanent: true,
      );
      svc.init();
    }
    Get.lazyPut<AddVideoPersonController>(() => AddVideoPersonController());
  }
}
