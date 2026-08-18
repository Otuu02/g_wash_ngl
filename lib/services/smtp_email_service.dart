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

  /// Send email using Gmail credentials (gwashng@gmail.com).
  /// - On Mobile / Desktop: Sends via Gmail SMTP.
  /// - On Web: Sends via direct Brevo REST API gateway (From: gwashng@gmail.com).
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    if (recipient.isEmpty) return false;

    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    // 1. Try Gmail SMTP first (native mobile & desktop)
    if (!kIsWeb && username.isNotEmpty && appPassword.isNotEmpty) {
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
        debugPrint('⚠️ [Gmail SMTP Exception]: $e');
      }
    }

    // 2. Web REST Gateway (Direct delivery from gwashng@gmail.com, zero activation required)
    return await _sendViaDirectRestApi(
      recipient: recipient,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), ''),
      senderEmail: username.isNotEmpty ? username : 'gwashng@gmail.com',
    );
  }

  /// Direct REST Email Gateway — sends instantly from gwashng@gmail.com with NO form activation required
  Future<bool> _sendViaDirectRestApi({
    required String recipient,
    required String subject,
    required String bodyHtml,
    required String bodyText,
    required String senderEmail,
  }) async {
    try {
      final brevoApiKey = Env.brevoApiKey;

      final url = Uri.parse('https://api.brevo.com/v3/smtp/email');
      final response = await http.post(
        url,
        headers: {
          'accept': 'application/json',
          'content-type': 'application/json',
          'api-key': brevoApiKey,
        },
        body: jsonEncode({
          'sender': {'name': 'G-Wash NG', 'email': senderEmail},
          'to': [{'email': recipient}],
          'subject': subject,
          'htmlContent': bodyHtml,
          'textContent': bodyText,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        debugPrint('✅ [Direct Web Email Sent] To: $recipient | Subject: $subject');
        return true;
      } else {
        debugPrint('⚠️ [Direct Web Email Response ${response.statusCode}]: ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ [Direct Web Email Exception]: $e');
    }
    return false;
  }
}
