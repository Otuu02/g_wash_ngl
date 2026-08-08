// FILE: test/services/validation_service_test.dart
// PURPOSE: Automated unit tests for email & phone number validation (disposable email domain blocking & fake phone number inspection)

import 'package:flutter_test/flutter_test.dart';
import 'package:g_wash_ng/services/validation_service.dart';

void main() {
  final validator = ValidationService();

  group('Disposable & Real Email Validation Tests', () {
    test('Should block disposable temporary email domains', () {
      final res1 = validator.validateEmail('user@tempmail.com');
      expect(res1.isValid, isFalse);
      expect(res1.errorMessage, contains('Disposable/temporary email addresses are not allowed'));

      final res2 = validator.validateEmail('test@yopmail.com');
      expect(res2.isValid, isFalse);

      final res3 = validator.validateEmail('fake@mailinator.com');
      expect(res3.isValid, isFalse);

      final res4 = validator.validateEmail('random@guerrillamail.com');
      expect(res4.isValid, isFalse);
    });

    test('Should accept valid, real email addresses', () {
      final res1 = validator.validateEmail('john.doe@gmail.com');
      expect(res1.isValid, isTrue);

      final res2 = validator.validateEmail('contact@business.ng');
      expect(res2.isValid, isTrue);

      final res3 = validator.validateEmail('user@yahoo.co.uk');
      expect(res3.isValid, isTrue);

      final res4 = validator.validateEmail('support@company.org');
      expect(res4.isValid, isTrue);
    });

    test('Should reject invalid email syntax', () {
      final res1 = validator.validateEmail('plainaddress');
      expect(res1.isValid, isFalse);

      final res2 = validator.validateEmail('@missingusername.com');
      expect(res2.isValid, isFalse);

      final res3 = validator.validateEmail('user@domain..com');
      expect(res3.isValid, isFalse);
    });
  });

  group('Authentic & Fake Phone Number Validation Tests', () {
    test('Should block known dummy / fake sequential numbers', () {
      final res1 = validator.validatePhone('08000000000');
      expect(res1.isValid, isFalse);

      final res2 = validator.validatePhone('08012345678');
      expect(res2.isValid, isFalse);

      final res3 = validator.validatePhone('08011111111');
      expect(res3.isValid, isFalse);

      final res4 = validator.validatePhone('08099999999');
      expect(res4.isValid, isFalse);
    });

    test('Should accept valid Nigerian mobile phone numbers (MTN, Airtel, Glo, 9mobile)', () {
      final res1 = validator.validatePhone('08031234567'); // MTN
      expect(res1.isValid, isTrue);

      final res2 = validator.validatePhone('08129876543'); // Airtel
      expect(res2.isValid, isTrue);

      final res3 = validator.validatePhone('08051234567'); // Glo
      expect(res3.isValid, isTrue);

      final res4 = validator.validatePhone('08091234567'); // 9mobile
      expect(res4.isValid, isTrue);

      final res5 = validator.validatePhone('+2348031234567'); // International format
      expect(res5.isValid, isTrue);
    });

    test('Should reject invalid length or invalid telco prefix', () {
      final res1 = validator.validatePhone('01234');
      expect(res1.isValid, isFalse);

      final res2 = validator.validatePhone('06001234567'); // Invalid prefix 0600
      expect(res2.isValid, isFalse);
    });
  });
}
