import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import '../config/env.dart';

class SmtpEmailService {
  static final SmtpEmailService _instance = SmtpEmailService._internal();
  factory SmtpEmailService() => _instance;
  SmtpEmailService._internal();

  /// Send an email via Gmail SMTP
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    if (username.isEmpty || appPassword.isEmpty) {
      debugPrint('📧 [Gmail SMTP Demo Mode] To: $recipient | Subject: $subject');
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
      debugPrint('✅ [Gmail SMTP Email Sent]: ${sendReport.toString()}');
      return true;
    } on MailerException catch (e) {
      debugPrint('❌ [Gmail SMTP MailerException]: ${e.toString()}');
      for (var p in e.problems) {
        debugPrint('  Problem: ${p.code}: ${p.msg}');
      }
      return false;
    } catch (e) {
      debugPrint('❌ [Gmail SMTP Exception]: $e');
      return false;
    }
  }
}
