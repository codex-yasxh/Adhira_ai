import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sos_sender.dart';

class SmsIntentFallbackSender implements SosSender {
  @override
  Future<SosSendResult> send({
    required List<String> phones,
    required String message,
  }) async {
    debugPrint('[SOS] Fallback SMS compose opened');

    // sms: URI with ; separated recipients — works across Android SMS apps
    final uri = Uri(
      scheme: 'sms',
      path: phones.join(';'),
      queryParameters: {'body': message},
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      debugPrint('[SOS] Fallback launch failed');
    }

    // Fallback always returns a single synthetic result — user must tap Send manually
    return SosSendResult(
      usedFallback: true,
      results: phones
          .map((p) => ContactSendResult(
                phone: p,
                status: launched
                    ? ContactSendStatus.unknown  // user still needs to tap Send
                    : ContactSendStatus.failed,
              ))
          .toList(),
    );
  }
}
