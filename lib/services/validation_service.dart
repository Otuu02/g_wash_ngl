// FILE: lib/services/validation_service.dart
// PURPOSE: Validation service for email & phone authenticity (blocking disposable emails and dummy phone numbers)

class ValidationService {
  static final ValidationService _instance = ValidationService._internal();
  factory ValidationService() => _instance;
  ValidationService._internal();

  /// Set of popular disposable / temporary email domains to block
  static const Set<String> _disposableDomains = {
    'mailinator.com',
    'tempmail.com',
    'yopmail.com',
    'guerrillamail.com',
    '10minutemail.com',
    'trashmail.com',
    'dispostable.com',
    'sharklasers.com',
    'getnada.com',
    'throwawaymail.com',
    'maildrop.cc',
    'crazymailing.com',
    'fakemailgenerator.com',
    'mohmal.com',
    'temp-mail.org',
    'generator.email',
    'tempmailo.com',
    'emailondeck.com',
    'boun.cr',
    'inboxalias.com',
    'tempmail.net',
    'disposablemail.com',
    'mytrashmail.com',
    'mytemp.email',
    'burnermail.io',
    'spamgourmet.com',
    'mailcatch.com',
    'trashmail.net',
    'tempmail.de',
    'mailnesia.com',
    'guerrillamailblock.com',
    'pokemail.net',
    'grr.la',
    'guerrillamail.biz',
    'guerrillamail.org',
    'spam4.me',
    '0815.ru',
    'armyspy.com',
    'cuvox.de',
    'dayrep.com',
    'einrot.com',
    'fleckens.hu',
    'gustr.com',
    'jourrapide.com',
    'rhyta.com',
    'superrito.com',
    'teleworm.us',
    'twcmail.com',
    'tmpmail.net',
    'tmpmail.org',
    'trashmail.io',
    'disposable.com',
    'dropmail.me',
    'moakt.com',
  };

  /// Set of known fake / dummy phone numbers to reject
  static const Set<String> _blacklistedFakeNumbers = {
    '08000000000',
    '08012345678',
    '09012345678',
    '07012345678',
    '08123456789',
    '01234567890',
    '08011111111',
    '08022222222',
    '08033333333',
    '08044444444',
    '08055555555',
    '08066666666',
    '08077777777',
    '08088888888',
    '08099999999',
    '07000000000',
    '08100000000',
    '09000000000',
    '09100000000',
    '+2348000000000',
    '+2348012345678',
    '+2349012345678',
  };

  /// Valid Nigerian Mobile Network Operator prefixes (MTN, Airtel, Glo, 9mobile)
  static const Set<String> _validNigerianPrefixes = {
    // MTN
    '0803', '0806', '0813', '0816', '0810', '0814', '0703', '0706', '0903', '0906', '0913', '0916',
    // Airtel
    '0802', '0808', '0812', '0708', '0701', '0902', '0901', '0904', '0907', '0912',
    // Glo
    '0805', '0807', '0811', '0815', '0705', '0905', '0915',
    // 9mobile
    '0809', '0817', '0818', '0909', '0908',
  };

  /// Check if an email uses a disposable / temporary domain
  bool isDisposableEmail(String email) {
    if (email.isEmpty || !email.contains('@')) return false;
    final parts = email.trim().toLowerCase().split('@');
    if (parts.length != 2) return false;
    final domain = parts[1].trim();
    return _disposableDomains.contains(domain);
  }

  /// Validate if an email address is valid and non-disposable
  ValidationResult validateEmail(String email) {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) {
      return ValidationResult(isValid: false, errorMessage: 'Email address is required');
    }

    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    );

    if (!emailRegex.hasMatch(cleanEmail) || cleanEmail.contains('..')) {
      return ValidationResult(isValid: false, errorMessage: 'Please enter a valid email address');
    }

    final parts = cleanEmail.split('@');
    if (parts.length != 2) {
      return ValidationResult(isValid: false, errorMessage: 'Invalid email format');
    }

    final domain = parts[1];
    if (!domain.contains('.') || domain.split('.').last.length < 2) {
      return ValidationResult(isValid: false, errorMessage: 'Email domain is invalid');
    }

    if (_disposableDomains.contains(domain)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Disposable/temporary email addresses are not allowed. Please use a real email.',
      );
    }

    return ValidationResult(isValid: true);
  }

  /// Validate if a phone number is authentic (valid telco prefix & non-dummy)
  ValidationResult validatePhone(String phone, {bool allowAdminBypass = false}) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleaned.isEmpty) {
      return ValidationResult(isValid: false, errorMessage: 'Phone number is required');
    }

    // Admin bypass check for admin number
    if (allowAdminBypass && (phone == '+2348679267153' || cleaned == '2348679267153')) {
      return ValidationResult(isValid: true);
    }

    // Check blacklist
    final localPhone = cleaned.startsWith('234') && cleaned.length == 13
        ? '0${cleaned.substring(3)}'
        : (cleaned.length == 10 ? '0$cleaned' : cleaned);

    if (_blacklistedFakeNumbers.contains(localPhone) || _blacklistedFakeNumbers.contains(phone)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Please enter your real phone number. Dummy/sequential numbers are rejected.',
      );
    }

    // Check repeating digit sequence (e.g. 08011111111)
    if (localPhone.length >= 10 && RegExp(r'(\d)\1{7,}').hasMatch(localPhone)) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Invalid phone number pattern. Please enter a real phone number.',
      );
    }

    // Check full sequential digit pattern (e.g. 0123456789 or 9876543210)
    if (localPhone.contains('012345678') || localPhone.contains('123456789') || localPhone.contains('987654321')) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Sequential test numbers are not allowed. Please enter your real phone number.',
      );
    }

    // Nigerian phone validation (11 digits local or 13 digits international)
    if (cleaned.startsWith('234')) {
      if (cleaned.length != 13) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Nigerian phone numbers with country code must be 13 digits (e.g. +2348031234567)',
        );
      }
      final prefix = '0${cleaned.substring(3, 6)}';
      if (!_validNigerianPrefixes.contains(prefix)) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Invalid network operator prefix. Please enter a valid Nigerian mobile number.',
        );
      }
      return ValidationResult(isValid: true);
    }

    if (localPhone.startsWith('0') && localPhone.length == 11) {
      final prefix = localPhone.substring(0, 4);
      if (!_validNigerianPrefixes.contains(prefix)) {
        return ValidationResult(
          isValid: false,
          errorMessage: 'Invalid network operator prefix ($prefix). Please enter a valid Nigerian mobile number.',
        );
      }
      return ValidationResult(isValid: true);
    }

    // International number fallback (10 to 15 digits)
    if (cleaned.length >= 10 && cleaned.length <= 15) {
      return ValidationResult(isValid: true);
    }

    return ValidationResult(
      isValid: false,
      errorMessage: 'Invalid phone number. Expected an 11-digit mobile number (e.g. 08031234567).',
    );
  }

  /// Validate password strength (minimum 8 characters, at least one letter and one number or special character)
  ValidationResult validatePassword(String password) {
    if (password.isEmpty) {
      return ValidationResult(isValid: false, errorMessage: 'Password is required');
    }
    if (password.length < 8) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must be at least 8 characters long',
      );
    }
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasDigitOrSpecial = RegExp(r'[0-9!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    if (!hasLetter || !hasDigitOrSpecial) {
      return ValidationResult(
        isValid: false,
        errorMessage: 'Password must contain at least one letter and one number or special character',
      );
    }

    return ValidationResult(isValid: true);
  }
}

class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  ValidationResult({required this.isValid, this.errorMessage});
}
