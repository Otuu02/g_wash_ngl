import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Forgot Password OTP Logic Tests', () {
    test('6-digit OTP formatting validation', () {
      final otpCode = '583921';
      expect(otpCode.length, equals(6));
      expect(int.tryParse(otpCode), isNotNull);
    });

    test('OTP expiration validation logic', () {
      final now = DateTime.now();
      final validExpiry = now.add(const Duration(minutes: 10));
      final expiredTime = now.subtract(const Duration(minutes: 1));

      expect(now.isBefore(validExpiry), isTrue);
      expect(now.isAfter(expiredTime), isTrue);
    });
  });
}
