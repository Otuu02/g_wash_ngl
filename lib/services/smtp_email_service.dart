import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../config/env.dart';

class SmtpEmailService {
  static final SmtpEmailService _instance = SmtpEmailService._internal();
  factory SmtpEmailService() => _instance;
  SmtpEmailService._internal();

  /// Send an email via SMTP or HTTP API fallback
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    if (recipient.isEmpty) return false;

    // 1. Web Platform or HTTP Fallback
    if (kIsWeb) {
      return await _sendViaHttpApi(
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }

    // 2. Mobile Native SMTP
    if (username.isEmpty || appPassword.isEmpty) {
      debugPrint('📧 [Email Service Log] To: $recipient | Subject: $subject');
      return true;
    }

    final smtpServer = gmail(username, appPassword);

    final message = Message()
      ..from = Address(username, 'G-Wash NG')
      ..recipients.add(recipient)
      ..subject = subject
      ..html = bodyHtml
      ..text = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('âœ… [Gmail SMTP Email Sent]: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('â„¹ï¸ [SMTP Native Exception - Trying HTTP Fallback]: $e');
      return await _sendViaHttpApi(
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }
  }

  /// HTTP REST Email Sender
  Future<bool> _sendViaHttpApi({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    try {
      final senderEmail = Env.gmailUser.isNotEmpty ? Env.gmailUser : 'gwashngservice@gmail.com';
      final cleanText = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');
      final apiKey = Env.brevoApiKey;

      // Primary: Send via Brevo / Sendinblue HTTPS REST Email API
      final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'sender': {'name': 'G-Wash NG', 'email': senderEmail},
          'to': [{'email': recipient}],
          'subject': subject,
          'htmlContent': bodyHtml,
          'textContent': cleanText,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        debugPrint('✅ [REST API Email Sent Successfully] To: $recipient | Subject: $subject');
        return true;
      } else {
        debugPrint('❌ [Email REST API Failed] (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ [Email Service Exception] To: $recipient | Subject: $subject | Error: $e');
      return false;
    }
  }
}

