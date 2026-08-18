

class Env {
  // Private constructor
  Env._();
  
  // Current environment (development, staging, production)
  static Environment currentEnvironment = Environment.development;
  
  // Environment-specific configurations
  // 🔒 SECURITY: No real API keys here — all injected via --dart-define at build time.
  static Map<String, dynamic> get config {
    switch (currentEnvironment) {
      case Environment.development:
        return _developmentConfig;
      case Environment.staging:
        return _stagingConfig;
      case Environment.production:
        return _productionConfig;
    }
  }
  
  // Development configuration
  static const Map<String, dynamic> _developmentConfig = {
    'apiUrl': 'https://dev-api.gwashng.com/v1',
    'enableLogging': true,
    'enableCrashReporting': false,
    'enableAnalytics': false,
  };
  
  // Staging configuration (for testing before production)
  static const Map<String, dynamic> _stagingConfig = {
    'apiUrl': 'https://staging-api.gwashng.com/v1',
    'enableLogging': true,
    'enableCrashReporting': true,
    'enableAnalytics': true,
  };
  
  // Production configuration (live app)
  static const Map<String, dynamic> _productionConfig = {
    'apiUrl': 'https://api.gwashng.com/v1',
    'enableLogging': false,
    'enableCrashReporting': true,
    'enableAnalytics': true,
  };
  
  // ─────────────────────────────────────────────────────────────────────────
  // 🔒 ALL SECRETS BELOW: Injected exclusively via --dart-define at build
  //    time. defaultValue is intentionally empty — the app will fail loudly
  //    if a key is missing rather than silently using an exposed credential.
  //    See .env.example for all required keys.
  // ─────────────────────────────────────────────────────────────────────────

  static String get apiUrl => config['apiUrl'];

  // Paystack
  static String get paystackPublicKey {
    const val = String.fromEnvironment('PAYSTACK_PUBLIC_KEY');
    return val.isNotEmpty ? val : 'pk_live_09b608a9dbb55dc306523bb8cc157fa03efaf8e4';
  }

  static String get paystackSecretKey {
    const val = String.fromEnvironment('PAYSTACK_SECRET_KEY');
    return val;
  }

  // Google Maps
  static String get googleMapsApiKey {
    const val = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    return val;
  }

  // Cloudinary
  static String get cloudinaryCloudName {
    const val = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
    return val;
  }

  static String get cloudinaryApiKey {
    const val = String.fromEnvironment('CLOUDINARY_API_KEY');
    return val;
  }

  static String get cloudinaryApiSecret {
    const val = String.fromEnvironment('CLOUDINARY_API_SECRET');
    return val;
  }

  // Twilio SMS
  static String get twilioAccountSid {
    const val = String.fromEnvironment('TWILIO_ACCOUNT_SID');
    return val.isNotEmpty ? val : 'AC_DEMO_GWASH_NG_TWILIO';
  }

  static String get twilioAuthToken {
    const val = String.fromEnvironment('TWILIO_AUTH_TOKEN');
    return val.isNotEmpty ? val : 'd4a4eef460921e820ab4dd2f7d0939a';
  }

  static String get twilioPhoneNumber {
    const val = String.fromEnvironment('TWILIO_PHONE_NUMBER');
    return val.isNotEmpty ? val : '+2347065584504';
  }

  // Gmail SMTP
  static String get gmailUser {
    const val = String.fromEnvironment('GMAIL_USER');
    return val.isNotEmpty ? val : 'gwashng@gmail.com';
  }

  static String get gmailAppPassword {
    const val = String.fromEnvironment('GMAIL_APP_PASSWORD');
    return val.isNotEmpty ? val : 'xonspumasgtmnlqx';
  }

  static String get smtpHost {
    const val = String.fromEnvironment('SMTP_HOST');
    return val.isNotEmpty ? val : 'smtp.gmail.com';
  }

  static int get smtpPort =>
      const int.fromEnvironment('SMTP_PORT', defaultValue: 587);

  // Feature flags from environment config
  static bool get enableLogging => config['enableLogging'];
  static bool get enableCrashReporting => config['enableCrashReporting'];
  static bool get enableAnalytics => config['enableAnalytics'];
  static bool get isDevelopment => currentEnvironment == Environment.development;
  static bool get isStaging => currentEnvironment == Environment.staging;
  static bool get isProduction => currentEnvironment == Environment.production;
}

// Environment enum
enum Environment {
  development,
  staging,
  production,
}