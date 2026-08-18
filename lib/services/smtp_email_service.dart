import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../config/env.dart';

class SmtpEmailService {
  static final SmtpEmailService _instance = SmtpEmailService._internal();
  factory SmtpEmailService() => _instance;
  SmtpEmailService._internal();

  /// Send email exclusively using Gmail SMTP credentials (gwashng@gmail.com).
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    if (recipient.isEmpty) return false;

    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

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
        debugPrint('⚠️ [Gmail SMTP Exception]: $e');
      }
    }
    return false;
  }
}
