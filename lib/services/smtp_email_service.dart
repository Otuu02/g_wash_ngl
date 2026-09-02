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
    final plainText = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');
    final payload = jsonEncode({
      'to': recipient,
      'subject': subject,
      'html': bodyHtml,
      'text': plainText,
      'fromName': 'G-Wash NG',
    });

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Attempt 1: Direct Vercel Serverless Function (/api/send-email)
    final candidateEndpoints = [
      '/api/send-email',
      'https://g-wash-ngl.vercel.app/api/send-email',
      'https://api.brevo.com/v3/smtp/email',
    ];

    for (final endpoint in candidateEndpoints) {
      try {
        if (endpoint.contains('brevo')) {
          // Brevo Fallback
          final brevoResponse = await http.post(
            Uri.parse(endpoint),
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
            debugPrint('✅ [Brevo Email Gateway Sent] To: $recipient | Subject: $subject');
            return true;
          }
        } else {
          final uri = Uri.parse(endpoint);
          final response = await http.post(
            uri,
            headers: headers,
            body: payload,
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint('✅ [Vercel API Gateway Email Sent] To: $recipient | Subject: $subject');
            return true;
          }
        }
      } catch (e) {
        debugPrint('ℹ️ [Email endpoint attempt failed for $endpoint]: $e');
      }
    }

    // Final Fallback: FormSubmit AJAX
    try {
      final formResponse = await http.post(
        Uri.parse('https://formsubmit.co/ajax/$recipient'),
        headers: headers,
        body: jsonEncode({
          '_subject': subject,
          'message': plainText,
          '_captcha': 'false',
          '_template': 'box',
        }),
      ).timeout(const Duration(seconds: 8));

      if (formResponse.statusCode == 200) {
        debugPrint('✅ [FormSubmit Email Sent] To: $recipient');
        return true;
      }
    } catch (e) {
      debugPrint('ℹ️ [FormSubmit fallback failed]: $e');
    }

    return false;
  }
}
