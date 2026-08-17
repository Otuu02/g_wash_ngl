import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Customer Screens
import 'presentation/screens/customer/home_screen.dart';
import 'presentation/screens/customer/booking_screen.dart';
import 'presentation/screens/customer/my_bookings_screen.dart';
import 'presentation/screens/customer/profile_screen.dart';
import 'presentation/screens/customer/location_search_screen.dart';
import 'presentation/screens/customer/saved_addresses_screen.dart';
import 'presentation/screens/customer/payment_methods_screen.dart';
import 'presentation/screens/customer/notifications_screen.dart';
import 'presentation/screens/customer/privacy_security_screen.dart';
import 'presentation/screens/customer/help_support_screen.dart';
import 'presentation/screens/customer/order_details_screen.dart';
import 'presentation/screens/customer/tracking_screen.dart';
import 'presentation/screens/customer/rating_screen.dart';

// Washer Screens
import 'presentation/screens/washer/washer_dashboard.dart';
import 'presentation/screens/washer/washer_registration_screen.dart';
import 'presentation/screens/washer/job_request_screen.dart';
import 'presentation/screens/washer/earnings_screen.dart';
import 'presentation/screens/washer/washer_profile_screen.dart';
import 'presentation/screens/washer/subscription_screen.dart';

// Admin Screens
import 'presentation/screens/admin/admin_dashboard_screen.dart';

// Auth & Welcome
import 'presentation/screens/welcome_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/otp_screen.dart';

// Services
import 'services/auth_service.dart';
import 'services/app_notification_service.dart';
import 'services/security_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: FirebaseConfig.web);
  if (kDebugMode) debugPrint("Handling background FCM message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🔇 SILENCE ALL CONSOLE LOGS ACROSS THE ENTIRE APP
  debugPrint = (String? message, {int? wrapWidth}) {};

  await Firebase.initializeApp(
    options: FirebaseConfig.web,
  );
  
  final authService = AuthService();
  final notificationService = AppNotificationService();

  // ✅ Initialize Firebase Push Messaging
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        notificationService.notify(
          title: message.notification!.title ?? 'Notification',
          message: message.notification!.body ?? '',
          type: message.data['type'] ?? 'system',
          jobId: message.data['jobId'],
        );
      }
    });

    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null && kDebugMode) {
        debugPrint('📲 FCM Push Token: $token');
      }
    }).catchError((e) {
      if (kDebugMode) debugPrint('ℹ️ FCM Token notice: $e');
    });
  } catch (e) {
    if (kDebugMode) debugPrint('ℹ️ FCM Messaging skipped (platform/headless mode): $e');
  }
  
  try {
    await authService.migrateLocalUsersToFirestore();
    if (kDebugMode) debugPrint('✅ User migration completed successfully');
  } catch (e) {
    if (kDebugMode) debugPrint('❌ User migration failed: $e');
  }
  
  // ✅ Load saved notifications on startup
  await notificationService.loadSavedNotifications();
  if (kDebugMode) debugPrint('✅ Notification service initialized with ${notificationService.notifications.length} notifications');
  
  runApp(
    provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(create: (_) => authService),
        provider.ChangeNotifierProvider(create: (_) => notificationService),
      ],
      child: const ProviderScope(
        child: GWashApp(),
      ),
    ),
  );
}

class GWashApp extends StatelessWidget {
  const GWashApp({super.key});

  Widget _getHomeScreen(AuthService authService) {
    if (kDebugMode) {
      debugPrint('🔍 Determining home screen:');
      debugPrint('   isLoggedIn: ${authService.isLoggedIn}');
      debugPrint('   userRole: ${authService.userRole}');
      debugPrint('   isWasher: ${authService.isWasher}');
      debugPrint('   isServiceProvider: ${authService.isServiceProvider}');
    }
    
    if (!authService.isLoggedIn) {
      if (kDebugMode) debugPrint('❌ User not logged in - showing Welcome Screen');
      return const WelcomeScreen();
    }
    
    if (authService.isWasher) {
      if (kDebugMode) debugPrint('✅ User is a WASHER - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    if (authService.isServiceProvider) {
      if (kDebugMode) debugPrint('✅ User is a SERVICE PROVIDER - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    if (authService.userRole == 'washer' || 
        authService.userRole == 'cleaner' || 
        authService.userRole == 'laundry_provider') {
      if (kDebugMode) debugPrint('✅ User role is ${authService.userRole} - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    if (kDebugMode) debugPrint('✅ User is a CUSTOMER - showing Home Screen');
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<AuthService>(
      builder: (context, authService, child) {
        return MaterialApp(
          title: 'G Wash NG',
          debugShowCheckedModeBanner: false,
          debugShowMaterialGrid: false,
          showSemanticsDebugger: false,
          
          theme: ThemeData(
            primaryColor: const Color(0xFF0CAF60),
            scaffoldBackgroundColor: Colors.white,
            
            textTheme: const TextTheme(
              displayLarge: TextStyle(
                fontSize: 32, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              displayMedium: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              displaySmall: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              headlineLarge: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              headlineMedium: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              headlineSmall: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              bodyLarge: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              bodyMedium: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              bodySmall: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w400,
                color: Colors.black54,
              ),
              labelLarge: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              labelMedium: TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              labelSmall: TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0CAF60),
              secondary: Color(0xFF0A8E4F),
              surface: Colors.white,
              error: Colors.red,
            ),
            
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0CAF60),
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0CAF60),
              ),
            ),
            
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0CAF60),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            listTileTheme: const ListTileThemeData(
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              subtitleTextStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            
            inputDecorationTheme: const InputDecorationTheme(
              labelStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
              hintStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
            
            useMaterial3: true,
          ),
          
          builder: (context, child) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 720;
                if (!isDesktop) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      padding: MediaQuery.of(context).padding,
                    ),
                    child: child!,
                  );
                }

                // Sleek Desktop / Laptop Web View Container
                return Container(
                  color: const Color(0xFFF1F5F9),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 30,
                              spreadRadius: 4,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRect(
                          child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              padding: MediaQuery.of(context).padding,
                            ),
                            child: child!,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
          
          home: _getHomeScreen(authService),
          
          onGenerateRoute: (settings) {
            // 🛡️ RouteGuard: Enforce authentication & RBAC for direct link/URL entry
            final routeGuard = SecurityService().validateRouteAccess(
              routeName: settings.name,
              isLoggedIn: authService.isLoggedIn,
              userRole: authService.userRole,
            );

            if (!routeGuard.isAllowed) {
              debugPrint('🛡️ [Route Guard Intercepted Direct URL]: ${settings.name} -> ${routeGuard.reason}');
              return MaterialPageRoute(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(routeGuard.reason ?? 'Access restricted. Please log in.'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  });
                  return authService.isLoggedIn ? _getHomeScreen(authService) : const LoginScreen();
                },
              );
            }

            switch (settings.name) {
              case '/welcome':
                return MaterialPageRoute(builder: (context) => const WelcomeScreen());
              case '/login':
                return MaterialPageRoute(builder: (context) => const LoginScreen());
              case '/home':
                return MaterialPageRoute(builder: (context) => const HomeScreen());
              case '/booking':
                return MaterialPageRoute(builder: (context) => const BookingScreen());
              case '/my-bookings':
                return MaterialPageRoute(builder: (context) => const MyBookingsScreen());
              case '/profile':
                return MaterialPageRoute(builder: (context) => const ProfileScreen());
              case '/location-search':
                return MaterialPageRoute(builder: (context) => const LocationSearchScreen());
              case '/saved-addresses':
                return MaterialPageRoute(builder: (context) => const SavedAddressesScreen());
              case '/payment-methods':
                return MaterialPageRoute(builder: (context) => const PaymentMethodsScreen());
              case '/notifications':
                return MaterialPageRoute(builder: (context) => const NotificationsScreen());
              case '/privacy-security':
                return MaterialPageRoute(builder: (context) => const PrivacySecurityScreen());
              case '/help-support':
                return MaterialPageRoute(builder: (context) => const HelpSupportScreen());

              case '/washer-registration':
                return MaterialPageRoute(builder: (context) => const WasherRegistrationScreen());
              case '/washer-dashboard':
                return MaterialPageRoute(builder: (context) => const WasherDashboard());
              case '/washer-jobs':
                return MaterialPageRoute(builder: (context) => const JobRequestScreen());
              case '/washer-earnings':
                return MaterialPageRoute(builder: (context) => const EarningsScreen());
              case '/washer-profile':
                return MaterialPageRoute(builder: (context) => const WasherProfileScreen());
              case '/washer-subscription':
                return MaterialPageRoute(builder: (context) => const SubscriptionScreen());

              case '/admin':
              case '/admin-dashboard':
                return MaterialPageRoute(builder: (context) => const AdminDashboardScreen());

              case '/order-details':
                final order = settings.arguments as Map<String, dynamic>? ?? {};
                return MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order));

              case '/booking-with-params':
                final args = settings.arguments as Map<String, dynamic>? ?? {};
                return MaterialPageRoute(
                  builder: (context) => BookingScreen(
                    selectedService: args['service'],
                    selectedPrice: args['price'],
                    selectedAddress: args['address'],
                  ),
                );

              case '/tracking':
                final args = settings.arguments as Map<String, dynamic>? ?? {};
                return MaterialPageRoute(
                  builder: (context) => TrackingScreen(
                    jobId: args['jobId'] ?? '',
                    washerName: args['washerName'] ?? 'Professional Washer',
                    pickupAddress: args['pickupAddress'] ?? 'Your Location',
                    pickupLocation: args['pickupLocation'] ?? const LatLng(6.5244, 3.3792),
                    serviceName: args['serviceName'] ?? 'Service',
                    price: args['price'] ?? 0,
                  ),
                );

              case '/rating':
                final args = settings.arguments as Map<String, String>? ?? {};
                return MaterialPageRoute(
                  builder: (context) => RatingScreen(
                    jobId: args['jobId'] ?? '',
                    washerId: args['washerId'] ?? '',
                  ),
                );

              case '/otp':
                final args = settings.arguments as Map<String, String>? ?? {};
                return MaterialPageRoute(
                  builder: (context) => OTPScreen(
                    phoneNumber: args['phoneNumber'] ?? '',
                    verificationId: args['verificationId'] ?? '',
                  ),
                );

              default:
                return MaterialPageRoute(
                  builder: (context) => _getHomeScreen(authService),
                );
            }
          },
        );
      },
    );
  }
}

// ==================== RIVERPOD PROVIDERS ====================

final selectedServiceProvider = StateProvider<String>((ref) => 'Basic Wash');
final selectedLocationProvider = StateProvider<String>((ref) => 'Lekki Phase 1, Lagos');

final servicesProvider = Provider<Map<String, Map<String, dynamic>>>((ref) => {
  'Exterior Wash': {'price': 3000, 'priceDisplay': '₦3,000', 'icon': Icons.cleaning_services, 'duration': '30 mins'},
  'Interior Cleaning': {'price': 5000, 'priceDisplay': '₦5,000', 'icon': Icons.event_seat, 'duration': '45 mins'},
  'Full Detailing': {'price': 10000, 'priceDisplay': '₦10,000', 'icon': Icons.star, 'duration': '90 mins'},
});