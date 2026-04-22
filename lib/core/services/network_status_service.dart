import 'dart:async';

import 'package:get/get.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

/// Live internet state for UI (e.g. offline border on remote-media contacts).
class NetworkStatusService extends GetxService {
  final isConnected = true.obs;
  StreamSubscription<InternetConnectionStatus>? _sub;

  @override
  void onInit() {
    super.onInit();
    _prime();
    _sub = InternetConnectionChecker.instance.onStatusChange.listen((status) {
      isConnected.value = status != InternetConnectionStatus.disconnected;
    });
  }

  Future<void> _prime() async {
    try {
      isConnected.value =
          await InternetConnectionChecker.instance.hasConnection;
    } catch (_) {}
  }

  @override
  void onClose() {
    _sub?.cancel();
    _sub = null;
    super.onClose();
  }
}
