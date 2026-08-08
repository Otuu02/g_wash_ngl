

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
  static String get paystackPublicKey => const String.fromEnvironment(
        'PAYSTACK_PUBLIC_KEY',
        defaultValue: '',
      );
  static String get paystackSecretKey {
    // 🔒 Secret key MUST come from --dart-define=PAYSTACK_SECRET_KEY=sk_live_...
    // It is never stored in source code.
    const fromEnv = String.fromEnvironment('PAYSTACK_SECRET_KEY');
    return fromEnv;
  }

  // Google Maps
  static String get googleMapsApiKey => const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: '',
      );

  // Cloudinary
  static String get cloudinaryCloudName => const String.fromEnvironment(
        'CLOUDINARY_CLOUD_NAME',
        defaultValue: '',
      );
  static String get cloudinaryApiKey => const String.fromEnvironment(
        'CLOUDINARY_API_KEY',
        defaultValue: '',
      );
  static String get cloudinaryApiSecret => const String.fromEnvironment(
        'CLOUDINARY_API_SECRET',
        defaultValue: '',
      );

  // Twilio SMS
  static String get twilioAccountSid => const String.fromEnvironment(
        'TWILIO_ACCOUNT_SID',
        defaultValue: '',
      );
  static String get twilioAuthToken => const String.fromEnvironment(
        'TWILIO_AUTH_TOKEN',
        defaultValue: '',
      );
  static String get twilioPhoneNumber => const String.fromEnvironment(
        'TWILIO_PHONE_NUMBER',
        defaultValue: '',
      );

  // Gmail SMTP
  static String get gmailUser => const String.fromEnvironment(
        'GMAIL_USER',
        defaultValue: '',
      );
  static String get gmailAppPassword => const String.fromEnvironment(
        'GMAIL_APP_PASSWORD',
        defaultValue: '',
      );
  static String get smtpHost => const String.fromEnvironment(
        'SMTP_HOST',
        defaultValue: 'smtp.gmail.com',
      );
  static int get smtpPort => const int.fromEnvironment(
        'SMTP_PORT',
        defaultValue: 587,
      );

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