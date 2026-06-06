import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'sos_sender.dart';

class AndroidSmsSender implements SosSender {
  static const _channel = MethodChannel('com.adhira.mobile_flutter/sms');

  /// Returns false if no SIM is ready — caller should use fallback.
  static Future<bool> hasSim() async {
    try {
      return await _channel.invokeMethod<bool>('hasSim') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<SosSendResult> send({
    required List<String> phones,
    required String message,
  }) async {
    debugPrint('[SOS] MethodChannel invoked — sending to $phones');

    final raw = await _channel.invokeMethod<List<dynamic>>('sendSms', {
      'phones': phones,
      'message': message,
    });

    final results = (raw ?? []).map((item) {
      final m = Map<String, dynamic>.from(item as Map);
      return ContactSendResult(
        phone: m['phone'] as String,
        status: ContactSendResult.statusFromString(m['status'] as String),
      );
    }).toList();

    for (final r in results) {
      if (r.succeeded) {
        debugPrint('[SOS] SMS sent to ${r.phone}');
      } else {
        debugPrint('[SOS] SMS failed to ${r.phone} — ${r.statusLabel}');
      }
    }

    return SosSendResult(results: results);
  }
}
