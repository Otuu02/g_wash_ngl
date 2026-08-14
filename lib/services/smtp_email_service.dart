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

    // 1. Web Platform — use Brevo REST API
    if (kIsWeb) {
      return await _sendViaHttpApi(
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }

    // 2. Mobile Native SMTP — skip gracefully if credentials not set
    if (username.isEmpty || appPassword.isEmpty) {
      debugPrint('📧 [Email Service] Credentials not configured — email logged only. To: $recipient | Subject: $subject');
      return true; // Don't crash the app — just skip
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
      debugPrint('✅ [Gmail SMTP Email Sent]: ${sendReport.toString()}');
      return true;
    } catch (e) {
      debugPrint('ℹ️ [SMTP Native Exception — Trying HTTP Fallback]: $e');
      return await _sendViaHttpApi(
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }
  }

  /// HTTP REST Email Sender via Brevo API
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

      // 🔒 Guard: skip silently if Brevo API key not configured
      if (apiKey.isEmpty) {
        debugPrint('ℹ️ [Email Service] Brevo API key not set — email skipped. To: $recipient | Subject: $subject');
        return true; // Return true so app flow is not interrupted
      }

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
