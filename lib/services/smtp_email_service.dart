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

  /// Send an email via Gmail SMTP on mobile, or via HTTPS REST on Web.
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    if (recipient.isEmpty) return false;

    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    // 1. Mobile / Desktop Native — Gmail SMTP
    if (!kIsWeb) {
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
          debugPrint('✅ [Gmail SMTP Email Sent] To: $recipient');
          return true;
        } catch (e) {
          debugPrint('⚠️ [SMTP Mobile Exception]: $e');
        }
      }
    }

    // 2. Web / Fallback — Send via HTTPS REST API endpoint
    return await _sendViaHttpApi(
      recipient: recipient,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), ''),
    );
  }

  Future<bool> _sendViaHttpApi({
    required String recipient,
    required String subject,
    required String bodyHtml,
    required String bodyText,
  }) async {
    try {
      final url = Uri.parse('https://formsubmit.co/ajax/$recipient');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          '_subject': subject,
          '_captcha': 'false',
          'message': bodyText,
          'sender': 'G-Wash NG (gwashng@gmail.com)',
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ [HTTPS REST Email Sent] To: $recipient');
        return true;
      } else {
        debugPrint('⚠️ [HTTPS REST Email Status]: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [HTTPS REST Email Exception]: $e');
    }
    return false;
  }
}
