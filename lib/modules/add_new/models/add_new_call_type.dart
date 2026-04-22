enum AddNewCallType { video, audio }

extension AddNewCallTypeX on AddNewCallType {
  static AddNewCallType fromString(String? value) {
    switch (value) {
      case 'audio':
        return AddNewCallType.audio;
      case 'video':
      default:
        return AddNewCallType.video;
    }
  }

  String get asParam => name;
}

