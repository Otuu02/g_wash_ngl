import 'package:flutter_test/flutter_test.dart';
import 'package:g_wash_ngl/config/env.dart';
import 'package:g_wash_ngl/services/smtp_email_service.dart';

void main() {
  test('Env should return configured Gmail user and app password by default', () {
    expect(Env.gmailUser, equals('gwashng@gmail.com'));
    expect(Env.gmailAppPassword, equals('xonspumasgtmnlqx'));
    expect(Env.gmailAppPassword.isNotEmpty, isTrue);
  });

  test('SmtpEmailService instance is singleton', () {
    final s1 = SmtpEmailService();
    final s2 = SmtpEmailService();
    expect(identical(s1, s2), isTrue);
  });
}
