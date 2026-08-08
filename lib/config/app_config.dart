// FILE: lib/config/app_config.dart
// PURPOSE: Central configuration for the entire app
// Contains API keys, URLs, and app settings

class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();
  
  // ==================== APP VERSION ====================
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  
  // ==================== API CONFIGURATION ====================
  // Base URLs for backend services (will be updated when backend is ready)
  static const String apiBaseUrl = 'https://api.gwashng.com/v1';
  static const String stagingApiUrl = 'https://staging-api.gwashng.com/v1';
  
  // ==================== PAYSTACK CONFIGURATION ====================
  // Paystack public keys (replace with your actual keys)
  static const String paystackPublicKeyLive = 'pk_live_xxxxxxxxxxxxxxxxxxxx';
  static const String paystackPublicKeyTest = 'pk_test_xxxxxxxxxxxxxxxxxxxx';
  
  // Use test key for development
  static const String paystackPublicKey = paystackPublicKeyTest;
  
  // ==================== GOOGLE MAPS CONFIGURATION ====================
  // 🔒 API key is injected at build time via --dart-define=GOOGLE_MAPS_API_KEY=...
  // Never hardcode API keys in source files tracked by git.
  // Use Env.googleMapsApiKey at runtime instead of this constant.
  
  // ==================== ADMOB CONFIGURATION ====================
  // AdMob Ad Unit IDs (will add when ready to monetize)
  static const String admobAppIdLive = 'ca-app-pub-xxxxxxxxxxxxxxxx';
  static const String admobAppIdTest = 'ca-app-pub-3940256099942544~3347511713';
  
  static const String admobBannerAdUnitIdTest = 'ca-app-pub-3940256099942544/6300978111';
  static const String admobInterstitialAdUnitIdTest = 'ca-app-pub-3940256099942544/1033173712';
  static const String admobRewardedAdUnitIdTest = 'ca-app-pub-3940256099942544/5224354917';
  
  // ==================== FEATURE FLAGS ====================
  static const bool enableFirebase = false;      // Set to true when Firebase is configured
  static const bool enableMaps = true;            // Set to true when Google Maps API key is added
  static const bool enableAds = false;            // Set to true when ready to show ads
  static const bool enablePayments = false;       // Set to true when Paystack is integrated
  static const bool isDebugMode = true;           // Debug mode for development
  
  // ==================== APP SETTINGS ====================
  static const int splashScreenDuration = 2;       // Seconds to show splash screen
  static const int otpExpiryTime = 60;             // OTP expiry in seconds
  static const int maxRetryAttempts = 3;           // Maximum retry attempts for API calls
  static const int connectionTimeout = 30;         // Connection timeout in seconds
  
  // ==================== SUPPORT CONTACTS ====================
  static const String supportEmail = 'support@gwashng.com';
  static const String supportPhone = '+234 801 234 5678';
  static const String websiteUrl = 'https://www.gwashng.com';
  static const String privacyPolicyUrl = 'https://www.gwashng.com/privacy';
  static const String termsUrl = 'https://www.gwashng.com/terms';
  
  // ==================== PRICING CONFIGURATION ====================
  static const Map<String, Map<String, int>> pricingByState = {
    'Lagos': {
      'basic': 3500,
      'interior': 5500,
      'full': 12000,
    },
    'Abuja': {
      'basic': 4000,
      'interior': 6000,
      'full': 13000,
    },
    'Port Harcourt': {
      'basic': 3500,
      'interior': 5500,
      'full': 12000,
    },
    'Ibadan': {
      'basic': 3000,
      'interior': 5000,
      'full': 10000,
    },
  };
  
  // ==================== COMMISSION CONFIGURATION ====================
  static const double platformCommissionPercentage = 15.0;  // 15% commission
  static const int washerMonthlySubscriptionFee = 5000;      // ₦5,000 per month
  
  // ==================== WASHER REQUIREMENTS ====================
  static const int minWasherRadius = 5;    // Minimum working radius in km
  static const int maxWasherRadius = 15;   // Maximum working radius in km
  static const int maxSearchRadius = 10;   // Radius to search for washers in km
}