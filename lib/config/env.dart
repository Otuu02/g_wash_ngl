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
  static String get paystackPublicKey => config['paystackPublicKey'];
  static String get googleMapsApiKey => const String.fromEnvironment(
        'GOOGLE_MAPS_API_KEY',
        defaultValue: 'AIzaSyCXzpvcdGJARb7WcDzXtcwzLEUMwt5bRjw',
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