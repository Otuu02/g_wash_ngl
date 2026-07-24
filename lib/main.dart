import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: FirebaseConfig.web,
  );
  
  final authService = AuthService();
  
  try {
    await authService.migrateLocalUsersToFirestore();
    print('✅ User migration completed successfully');
  } catch (e) {
    print('❌ User migration failed: $e');
  }
  
  runApp(
    provider.MultiProvider(
      providers: [
        provider.ChangeNotifierProvider(create: (_) => authService),
      ],
      child: const ProviderScope(
        child: GWashApp(),
      ),
    ),
  );
}

class GWashApp extends StatelessWidget {
  const GWashApp({super.key});

  // ============================================================
  // FIXED: Helper method to determine correct home screen
  // ============================================================
  Widget _getHomeScreen(AuthService authService) {
    print('🔍 Determining home screen:');
    print('   isLoggedIn: ${authService.isLoggedIn}');
    print('   userRole: ${authService.userRole}');
    print('   isWasher: ${authService.isWasher}');
    print('   isServiceProvider: ${authService.isServiceProvider}');
    
    if (!authService.isLoggedIn) {
      print('❌ User not logged in - showing Welcome Screen');
      return const WelcomeScreen();
    }
    
    // ============================================================
    // FIX: Check if user is a washer FIRST
    // ============================================================
    // Check 1: Using isWasher getter
    if (authService.isWasher) {
      print('✅ User is a WASHER (isWasher=true) - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    // Check 2: Using isServiceProvider getter
    if (authService.isServiceProvider) {
      print('✅ User is a SERVICE PROVIDER - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    // Check 3: Check role string directly
    if (authService.userRole == 'washer' || 
        authService.userRole == 'cleaner' || 
        authService.userRole == 'laundry_provider') {
      print('✅ User role is ${authService.userRole} - showing Washer Dashboard');
      return const WasherDashboard();
    }
    
    // Check 4: Check if user exists in washers collection (via refresh)
    if (authService.userId != null) {
      // This will be handled by the auth listener
      print('🔄 Will check washers collection for user: ${authService.userId}');
    }
    
    print('✅ User is a CUSTOMER - showing Home Screen');
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to AuthService changes
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
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0CAF60),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            useMaterial3: true,
          ),
          
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: MediaQuery.of(context).padding,
              ),
              child: child!,
            );
          },
          
          home: _getHomeScreen(authService),
          
          routes: {
            '/welcome': (context) => const WelcomeScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
            '/booking': (context) => const BookingScreen(),
            '/my-bookings': (context) => const MyBookingsScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/location-search': (context) => const LocationSearchScreen(),
            '/saved-addresses': (context) => const SavedAddressesScreen(),
            '/payment-methods': (context) => const PaymentMethodsScreen(),
            '/notifications': (context) => const NotificationsScreen(),
            '/privacy-security': (context) => const PrivacySecurityScreen(),
            '/help-support': (context) => const HelpSupportScreen(),
            
            // Washer Routes
            '/washer-registration': (context) => const WasherRegistrationScreen(),
            '/washer-dashboard': (context) => const WasherDashboard(),
            '/washer-jobs': (context) => const JobRequestScreen(),
            '/washer-earnings': (context) => const EarningsScreen(),
            '/washer-profile': (context) => const WasherProfileScreen(),
            '/washer-subscription': (context) => const SubscriptionScreen(),
            
            // Admin Route
            '/admin': (context) => const AdminDashboardScreen(),
          },
          
          onGenerateRoute: (settings) {
            if (settings.name == '/admin') {
              if (authService.isLoggedIn && authService.isAdmin) {
                return MaterialPageRoute(
                  builder: (context) => const AdminDashboardScreen(),
                );
              }
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            }
            
            if (settings.name == '/order-details') {
              final order = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(builder: (context) => OrderDetailsScreen(order: order));
            }
            
            if (settings.name == '/booking-with-params') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => BookingScreen(
                  selectedService: args['service'],
                  selectedPrice: args['price'],
                  selectedAddress: args['address'],
                ),
              );
            }
            
            if (settings.name == '/tracking') {
              final args = settings.arguments as Map<String, dynamic>;
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
            }
            
            if (settings.name == '/rating') {
              final args = settings.arguments as Map<String, String>;
              return MaterialPageRoute(
                builder: (context) => RatingScreen(
                  jobId: args['jobId']!,
                  washerId: args['washerId']!,
                ),
              );
            }
            
            if (settings.name == '/otp') {
              final args = settings.arguments as Map<String, String>;
              return MaterialPageRoute(
                builder: (context) => OTPScreen(
                  phoneNumber: args['phoneNumber']!,
                  verificationId: args['verificationId']!,
                ),
              );
            }
            
            return null;
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