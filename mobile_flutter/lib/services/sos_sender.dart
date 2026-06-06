// Abstract SOS sending contract.
// UI layer only depends on this — never on Android-specific code.

enum ContactSendStatus {
  success,
  noService,
  radioOff,
  nullPdu,
  failed,
  timeout,
  unknown,
}

class ContactSendResult {
  const ContactSendResult({required this.phone, required this.status});

  final String phone;
  final ContactSendStatus status;

  bool get succeeded => status == ContactSendStatus.success;

  String get statusLabel {
    switch (status) {
      case ContactSendStatus.success:    return 'sent';
      case ContactSendStatus.noService:  return 'no service';
      case ContactSendStatus.radioOff:   return 'radio off';
      case ContactSendStatus.nullPdu:    return 'modem error';
      case ContactSendStatus.failed:     return 'failed';
      case ContactSendStatus.timeout:    return 'timed out';
      case ContactSendStatus.unknown:    return 'unknown';
    }
  }

  static ContactSendStatus statusFromString(String s) {
    switch (s) {
      case 'success':   return ContactSendStatus.success;
      case 'no_service': return ContactSendStatus.noService;
      case 'radio_off': return ContactSendStatus.radioOff;
      case 'null_pdu':  return ContactSendStatus.nullPdu;
      case 'timeout':   return ContactSendStatus.timeout;
      default:          return ContactSendStatus.failed;
    }
  }
}

class SosSendResult {
  const SosSendResult({required this.results, this.usedFallback = false});

  final List<ContactSendResult> results;
  final bool usedFallback;

  int get totalContacts  => results.length;
  int get successCount   => results.where((r) => r.succeeded).length;
  int get failureCount   => totalContacts - successCount;
}

abstract class SosSender {
  Future<SosSendResult> send({
    required List<String> phones,
    required String message,
  });
}
