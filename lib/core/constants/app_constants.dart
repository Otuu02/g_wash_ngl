// FILE: lib/core/constants/app_constants.dart
// PURPOSE: App-wide constants and configuration values

class AppConstants {
  AppConstants._();
  
  // ==================== API ENDPOINTS ====================
  static const String baseUrl = 'https://api.gwashng.com/v1';
  static const String stagingBaseUrl = 'https://staging-api.gwashng.com/v1';
  
  // ==================== API PATHS ====================
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String verifyOtpEndpoint = '/auth/verify-otp';
  static const String resendOtpEndpoint = '/auth/resend-otp';
  static const String jobsEndpoint = '/jobs';
  static const String washersEndpoint = '/washers';
  static const String paymentsEndpoint = '/payments';
  static const String ratingsEndpoint = '/ratings';
  
  // ==================== TIME CONSTANTS ====================
  static const int splashDelay = 2;           // Seconds
  static const int otpExpiryTime = 60;        // Seconds
  static const int otpResendDelay = 30;       // Seconds
  static const int connectionTimeout = 30;    // Seconds
  static const int receiveTimeout = 30;       // Seconds
  static const int sendTimeout = 30;          // Seconds
  
  // ==================== PAGINATION ====================
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // ==================== CACHE KEYS ====================
  static const String cacheUserKey = 'cached_user';
  static const String cacheTokenKey = 'auth_token';
  static const String cacheSettingsKey = 'app_settings';
  
  // ==================== LOCATION CONSTANTS ====================
  static const double defaultLatitude = 6.5244;    // Lagos latitude
  static const double defaultLongitude = 3.3792;   // Lagos longitude
  static const int defaultZoomLevel = 14;
  static const int minWasherRadius = 5;            // Kilometers
  static const int maxWasherRadius = 15;           // Kilometers
  static const int defaultSearchRadius = 10;       // Kilometers
  
  // ==================== PRICING ====================
  static const int basicWashPrice = 3000;
  static const int interiorCleaningPrice = 5000;
  static const int fullDetailingPrice = 10000;
  static const double platformCommission = 0.10;    // 10%
  static const int washerSubscriptionFee = 5000;    // Monthly fee
  
  // ==================== VALIDATION ====================
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 13;
  static const int otpLength = 6;
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 20;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  
  // ==================== REGEX PATTERNS ====================
  static const String phoneRegex = r'^(\+234|0)[7-9][0-1][0-9]{8}$';
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String passwordRegex = r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{6,}$';
  
  // ==================== SUPPORT ====================
  static const String supportEmail = 'support@gwashng.com';
  static const String supportPhone = '+2348012345678';
  static const String websiteUrl = 'https://www.gwashng.com';
  static const String privacyPolicyUrl = 'https://www.gwashng.com/privacy';
  static const String termsUrl = 'https://www.gwashng.com/terms';
  
  // ==================== FEATURE FLAGS ====================
  static const bool enableFirebase = false;
  static const bool enableMaps = false;
  static const bool enablePayments = false;
  static const bool enableAds = false;
  static const bool enablePushNotifications = false;
}