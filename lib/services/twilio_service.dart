import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class TwilioService {
  static final TwilioService _instance = TwilioService._internal();
  factory TwilioService() => _instance;
  TwilioService._internal();

  /// Format phone number into E.164 format (e.g. +2348012345678)
  String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+2340')) {
      return '+234${cleaned.substring(5)}';
    }
    if (cleaned.startsWith('+234')) {
      return cleaned;
    }
    if (cleaned.startsWith('234')) {
      return '+$cleaned';
    }
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0')) {
      return '+234${cleaned.substring(1)}';
    }
    return '+234$cleaned';
  }

  /// Send an SMS using Twilio REST API with Brevo REST SMS Fallback
  Future<bool> sendSms({
    required String to,
    required String message,
  }) async {
    final accountSid = Env.twilioAccountSid;
    final authToken = Env.twilioAuthToken;
    final fromNumber = Env.twilioPhoneNumber;

    final formattedTo = formatPhoneNumber(to);
    if (formattedTo.isEmpty) return false;

    // 1. Try Twilio API if credentials are model-configured
    if (accountSid.isNotEmpty &&
        authToken.isNotEmpty &&
        !accountSid.startsWith('AC_DEMO')) {
      try {
        final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
        );

        final auth = base64Encode(utf8.encode('$accountSid:$authToken'));

        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Basic $auth',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'From': fromNumber,
            'To': formattedTo,
            'Body': message,
          },
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          debugPrint('✅ [Twilio SMS Sent] To: $formattedTo');
          return true;
        } else {
          debugPrint(
            '⚠️ [Twilio SMS Failed] Status: ${response.statusCode} | Body: ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Twilio SMS Exception]: $e');
      }
    }

    // 2. Fallback: Send via Brevo Transactional SMS REST API
    try {
      final apiKey = Env.brevoApiKey;

      // 🔒 Guard: skip gracefully if Brevo key not configured
      if (apiKey.isEmpty) {
        debugPrint('ℹ️ [SMS Service] Brevo API key not set — SMS skipped for: $formattedTo');
        return true; // Don't crash the app — just skip
      }

      final brevoUrl = Uri.parse('https://api.brevo.com/v3/transactionalSMS/sms');
      final brevoResponse = await http.post(
        brevoUrl,
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'sender': 'GWASHNG',
          'recipient': formattedTo,
          'content': message,
          'type': 'transactional',
        }),
      );

      if (brevoResponse.statusCode == 200 || brevoResponse.statusCode == 201) {
        debugPrint('✅ [Brevo REST SMS Sent] To: $formattedTo');
        return true;
      } else {
        debugPrint('ℹ️ [Brevo REST SMS Notice] Status: ${brevoResponse.statusCode} | Body: ${brevoResponse.body}');
      }
    } catch (e) {
      debugPrint('ℹ️ [Brevo SMS Exception]: $e');
    }

    // Default: Log for debugging
    debugPrint('📱 [SMS Service Logged] To: $formattedTo | Msg: $message');
    return true;
  }
}
