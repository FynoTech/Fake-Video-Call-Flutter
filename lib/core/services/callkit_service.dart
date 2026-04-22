import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../models/person_item.dart';
import 'persons_storage_service.dart';

class CallkitService extends GetxService {
  final _pendingById = <String, PersonItem>{};
  StreamSubscription<CallEvent?>? _sub;

  Future<CallkitService> init() async {
    _sub = FlutterCallkitIncoming.onEvent.listen(_onEvent);
    return this;
  }

  Future<void> showIncoming(PersonItem person) async {
    final callId = DateTime.now().microsecondsSinceEpoch.toString();
    _pendingById[callId] = person;

    final params = CallKitParams(
      id: callId,
      nameCaller: person.firstName.isEmpty ? person.name : person.firstName,
      appName: 'Fake Video Call',
      avatar: person.imageUrl,
      handle: 'Video call',
      type: 1,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Reject',
      extra: <String, dynamic>{
        'storageFolderPath': person.storageFolderPath,
      },
      android: const AndroidParams(
        isCustomNotification: false,
        isShowLogo: true,
        isShowCallID: true,
        isShowFullLockedScreen: true,
        isImportant: true,
        incomingCallNotificationChannelName: 'Scheduled Calls',
        missedCallNotificationChannelName: 'Scheduled Calls',
      ),
      ios: const IOSParams(
        handleType: 'generic',
        supportsVideo: true,
        audioSessionActive: true,
        supportsDTMF: false,
        supportsHolding: false,
        supportsGrouping: false,
        supportsUngrouping: false,
      ),
    );
    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> _onEvent(CallEvent? e) async {
    if (e == null) return;
    final body = e.body is Map ? Map<String, dynamic>.from(e.body as Map) : <String, dynamic>{};
    final id = body['id']?.toString();
    final extra = body['extra'] is Map
        ? Map<String, dynamic>.from(body['extra'] as Map)
        : <String, dynamic>{};
    final folder = extra['storageFolderPath']?.toString();

    if (e.event == Event.actionCallAccept) {
      final person = await _resolvePerson(id: id, folderPath: folder);
      if (person != null) {
        Get.offAllNamed(
          AppRoutes.videoCall,
          arguments: {'person': person, 'autoAccept': true},
        );
      }
      if (id != null) {
        try {
          await FlutterCallkitIncoming.endCall(id);
        } catch (_) {}
      }
      return;
    }

    if (e.event == Event.actionCallDecline ||
        e.event == Event.actionCallEnded ||
        e.event == Event.actionCallTimeout) {
      if (id != null) _pendingById.remove(id);
    }
  }

  Future<PersonItem?> _resolvePerson({
    required String? id,
    required String? folderPath,
  }) async {
    if (id != null) {
      final p = _pendingById.remove(id);
      if (p != null) return p;
    }
    if (folderPath == null || folderPath.isEmpty) return null;
    try {
      final persons = Get.find<PersonsStorageService>();
      if (persons.persons.isEmpty && !persons.isLoading.value) {
        await persons.loadPersons();
      }
      for (final p in persons.persons) {
        if (p.storageFolderPath == folderPath) return p;
      }
    } catch (e) {
      debugPrint('Callkit resolve person failed: $e');
    }
    return null;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}

