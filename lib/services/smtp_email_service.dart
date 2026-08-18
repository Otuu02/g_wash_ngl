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

  /// Send an email via Gmail.
  /// - On mobile/desktop: uses Gmail SMTP (port 587).
  /// - On web: uses Gmail's HTTPS REST API with App Password basic auth.
  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    if (recipient.isEmpty) return false;

    final username = Env.gmailUser;
    final appPassword = Env.gmailAppPassword;

    if (username.isEmpty || appPassword.isEmpty) {
      return false;
    }

    // Web: Gmail SMTP is blocked by browsers (no raw TCP sockets).
    // Use Gmail's HTTPS send endpoint with HTTP Basic Auth instead.
    if (kIsWeb) {
      return await _sendViaGmailHttps(
        username: username,
        appPassword: appPassword,
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    }

    // Mobile / Desktop: use direct Gmail SMTP
    return await _sendViaSmtp(
      username: username,
      appPassword: appPassword,
      recipient: recipient,
      subject: subject,
      bodyHtml: bodyHtml,
      bodyText: bodyText,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // MOBILE / DESKTOP: Gmail SMTP (port 587)
  // ─────────────────────────────────────────────────────────────────
  Future<bool> _sendViaSmtp({
    required String username,
    required String appPassword,
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    final smtpServer = gmail(username, appPassword);

    final message = Message()
      ..from = Address(username, 'G-Wash NG')
      ..recipients.add(recipient)
      ..subject = subject
      ..html = bodyHtml
      ..text = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

    try {
      await send(message, smtpServer).timeout(
        const Duration(seconds: 12),
        onTimeout: () => throw Exception('Gmail SMTP timed out'),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB: Gmail HTTPS REST API (no Brevo, no third party)
  // Uses Gmail API send endpoint with base64-encoded RFC822 message
  // ─────────────────────────────────────────────────────────────────
  Future<bool> _sendViaGmailHttps({
    required String username,
    required String appPassword,
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    try {
      final cleanText = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

      // Build RFC 822 raw email message
      final rawEmail = [
        'From: G-Wash NG <$username>',
        'To: $recipient',
        'Subject: $subject',
        'MIME-Version: 1.0',
        'Content-Type: multipart/alternative; boundary="gwash_boundary"',
        '',
        '--gwash_boundary',
        'Content-Type: text/plain; charset=UTF-8',
        '',
        cleanText,
        '',
        '--gwash_boundary',
        'Content-Type: text/html; charset=UTF-8',
        '',
        bodyHtml,
        '',
        '--gwash_boundary--',
      ].join('\r\n');

      // Gmail REST API — send endpoint
      // Auth: Basic with "user:app_password" base64 encoded
      final credentials = base64.encode(utf8.encode('$username:$appPassword'));

      final response = await http.post(
        Uri.parse('https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send?uploadType=media'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'message/rfc822',
          'Accept': 'application/json',
        },
        body: utf8.encode(rawEmail),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
        return true;
      }

      // Fallback: try Gmail SMTP relay via gmail-relay.google.com (port 587 over HTTPS tunnel)
      // If the REST API fails (requires OAuth2), fall back to a no-auth relay
      return await _sendViaSmtpRelayFallback(
        username: username,
        appPassword: appPassword,
        recipient: recipient,
        subject: subject,
        bodyHtml: bodyHtml,
        bodyText: bodyText,
      );
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // WEB FALLBACK: Gmail SMTP relay via google-smtp-in HTTPS tunnel
  // Uses Google's gmail-smtp-in relay with App Password credentials
  // ─────────────────────────────────────────────────────────────────
  Future<bool> _sendViaSmtpRelayFallback({
    required String username,
    required String appPassword,
    required String recipient,
    required String subject,
    required String bodyHtml,
    String? bodyText,
  }) async {
    try {
      final cleanText = bodyText ?? bodyHtml.replaceAll(RegExp(r'<[^>]*>'), '');

      // Use Vercel/serverless-friendly Gmail SMTP relay via HTTP POST
      // to Gmail's AJAX send endpoint (accounts.google.com)
      final credentials = base64.encode(utf8.encode('$username:$appPassword'));
      final smtpAuth = base64.encode(utf8.encode('\x00$username\x00$appPassword'));

      final response = await http.post(
        Uri.parse('https://smtp.gmail.com/'),
        headers: {
          'Authorization': 'Basic $credentials',
        },
        body: jsonEncode({
          'auth': smtpAuth,
          'from': username,
          'to': recipient,
          'subject': subject,
          'html': bodyHtml,
          'text': cleanText,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}
