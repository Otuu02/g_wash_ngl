// FILE: lib/config/env.dart
// PURPOSE: Environment variables for different deployment environments
// IMPORTANT: Never commit this file with real API keys to GitHub!

class Env {
  // Private constructor
  Env._();
  
  // Current environment (development, staging, production)
  static Environment currentEnvironment = Environment.development;
  
  // Environment-specific configurations
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
    'paystackPublicKey': 'pk_test_xxxxxxxxxxxxxxxxxxxx',
    'googleMapsApiKey': 'AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw',
    'enableLogging': true,
    'enableCrashReporting': false,
    'enableAnalytics': false,
  };
  
  // Staging configuration (for testing before production)
  static const Map<String, dynamic> _stagingConfig = {
    'apiUrl': 'https://staging-api.gwashng.com/v1',
    'paystackPublicKey': 'pk_test_xxxxxxxxxxxxxxxxxxxx',
    'googleMapsApiKey': 'AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw',
    'enableLogging': true,
    'enableCrashReporting': true,
    'enableAnalytics': true,
  };
  
  // Production configuration (live app)
  static const Map<String, dynamic> _productionConfig = {
    'apiUrl': 'https://api.gwashng.com/v1',
    'paystackPublicKey': 'pk_live_xxxxxxxxxxxxxxxxxxxx',
    'googleMapsApiKey': 'AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw',
    'enableLogging': false,
    'enableCrashReporting': true,
    'enableAnalytics': true,
  };
  
  // Helper getters
  static String get apiUrl => config['apiUrl'];
  static String get paystackPublicKey => const String.fromEnvironment(
        'PAYSTACK_PUBLIC_KEY',
        defaultValue: 'pk_live_09b608a9dbb55dc306523bb8cc157fa03efaf8e4',
      );
  static String get paystackSecretKey => const String.fromEnvironment(
        'PAYSTACK_SECRET_KEY',
        defaultValue: 'sk_live_env_configured',
      );
  static String get googleMapsApiKey => const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw',
      );
  static String get cloudinaryCloudName => const String.fromEnvironment(
        'CLOUDINARY_CLOUD_NAME',
        defaultValue: 'dijqk2arj',
      );
  static String get cloudinaryApiKey => const String.fromEnvironment(
        'CLOUDINARY_API_KEY',
        defaultValue: '862473269516361',
      );
  static String get cloudinaryApiSecret => const String.fromEnvironment(
        'CLOUDINARY_API_SECRET',
        defaultValue: '4JpMPFJbMlHE3qulwj0_oe_8lJI',
      );
  static String get twilioAccountSid => const String.fromEnvironment(
        'TWILIO_ACCOUNT_SID',
        defaultValue: 'AC_DEMO_ACCOUNT_SID',
      );
  static String get twilioAuthToken => const String.fromEnvironment(
        'TWILIO_AUTH_TOKEN',
        defaultValue: 'DEMO_AUTH_TOKEN',
      );
  static String get twilioPhoneNumber => const String.fromEnvironment(
        'TWILIO_PHONE_NUMBER',
        defaultValue: '+15005550006',
      );
  static String get gmailUser => const String.fromEnvironment(
        'GMAIL_USER',
        defaultValue: 'gwashng@gmail.com',
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