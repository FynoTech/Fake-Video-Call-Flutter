import 'package:get/get.dart';

import '../controllers/schedule_call_controller.dart';

class ScheduleCallBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ScheduleCallController>(() => ScheduleCallController());
  }
}
