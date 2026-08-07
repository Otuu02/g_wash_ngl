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
    if (cleaned.startsWith('+')) {
      return cleaned;
    }
    if (cleaned.startsWith('0')) {
      return '+234${cleaned.substring(1)}';
    }
    if (cleaned.length == 10) {
      return '+234$cleaned';
    }
    return '+234$cleaned';
  }

  /// Send an SMS using Twilio REST API
  Future<bool> sendSms({
    required String to,
    required String message,
  }) async {
    final accountSid = Env.twilioAccountSid;
    final authToken = Env.twilioAuthToken;
    final fromNumber = Env.twilioPhoneNumber;

    final formattedTo = formatPhoneNumber(to);

    if (accountSid.isEmpty ||
        authToken.isEmpty ||
        accountSid == 'AC_DEMO_ACCOUNT_SID') {
      debugPrint('📱 [Twilio SMS Demo Mode] To: $formattedTo | Msg: $message');
      return true;
    }

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
          '❌ [Twilio SMS Failed] Status: ${response.statusCode} | Body: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ [Twilio SMS Exception]: $e');
      return false;
    }
  }
}
