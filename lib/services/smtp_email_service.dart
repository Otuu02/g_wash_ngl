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

  /// Send email using Gmail SMTP on Native platforms or HTTP REST Gateway on Flutter Web (Vercel).
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    if (recipient.isEmpty) return false;

    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    // 1. On Flutter Web (Vercel deployments), raw TCP sockets (port 587) are blocked by browser security.
    // Use Web HTTP REST Gateway for Web environments.
    if (kIsWeb) {
      return await _sendViaWebHttpGateway(
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }

    // 2. On Mobile / Desktop (Android, iOS, Windows, macOS), send directly via Gmail SMTP TCP sockets.
    if (username.isNotEmpty && appPassword.isNotEmpty) {
      try {
        final smtpServer = gmail(username, appPassword);
        final message = Message()
          ..from = Address(username, 'G-Wash NG')
          ..recipients.add(recipient)
          ..subject = subject
          ..html = bodyHtml
          ..text = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

        await send(message, smtpServer).timeout(
          const Duration(seconds: 12),
        );
        debugPrint('✅ [Gmail SMTP Email Sent] To: $recipient | Subject: $subject');
        return true;
      } catch (e) {
        debugPrint('⚠️ [Gmail SMTP Native Exception, falling back to Web Gateway]: $e');
        return await _sendViaWebHttpGateway(
          recipient: recipient,
          subject: subject,
          bodyHtml: bodyHtml,
          bodyText: bodyText,
        );
      }
    }
    return false;
  }

  /// Send email via HTTP REST API for Web environments (bypassing browser TCP socket restrictions)
  Future<bool> _sendViaWebHttpGateway({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    try {
      final plainText = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

      // Attempt 1: Brevo / REST API Gateway
      final brevoResponse = await http.post(
        Uri.parse('https://api.brevo.com/v3/smtp/email'),
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'api-key': 'xkeysib-demo-gwash-ng',
        },
        body: jsonEncode({
          'sender': {'name': 'G-Wash NG', 'email': Env.gmailUser},
          'to': [{'email': recipient}],
          'subject': subject,
          'htmlContent': bodyHtml,
        }),
      ).timeout(const Duration(seconds: 8));

      if (brevoResponse.statusCode == 200 || brevoResponse.statusCode == 201) {
        debugPrint('✅ [Web HTTP REST Email Sent] To: $recipient | Subject: $subject');
        return true;
      }

      // Attempt 2: FormSubmit AJAX Gateway
      final formResponse = await http.post(
        Uri.parse('https://formsubmit.co/ajax/$recipient'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          '_subject': subject,
          'message': plainText,
          '_captcha': 'false',
          '_template': 'box',
        }),
      ).timeout(const Duration(seconds: 8));

      if (formResponse.statusCode == 200) {
        debugPrint('✅ [FormSubmit Web Email Sent] To: $recipient');
        return true;
      }
    } catch (e) {
      debugPrint('ℹ️ [Web Email Gateway Notice]: $e');
    }
    return false;
  }
}
