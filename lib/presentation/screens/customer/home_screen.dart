// lib/presentation/screens/customer/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/location_service.dart';
import 'booking_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import 'location_search_screen.dart';
import 'map_screen.dart';
import '../washer/washer_registration_screen.dart';
import 'notifications_screen.dart';
import 'help_support_screen.dart';
import 'privacy_security_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String _selectedLocation = 'Lekki Phase 1, Lagos';
  LatLng? _selectedCoordinates;
  int _selectedCategoryIndex = 0;
  
  // Carousel
  int _currentCarouselIndex = 0;
  late PageController _carouselController;
  Timer? _carouselTimer;
  
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  
  // Real data from Firestore
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoading = true;
  
  // Service Categories
  final List<Map<String, dynamic>> _defaultCategories = [
    {'name': 'Car Wash', 'icon': Icons.local_car_wash, 'color': AppColors.primary},
    {'name': 'House Cleaning', 'icon': Icons.cleaning_services, 'color': AppColors.primary},
    {'name': 'Laundry', 'icon': Icons.local_laundry_service, 'color': AppColors.primary},
  ];

  // ============================================================
  // CAROUSEL DATA - YOUR REAL IMAGES
  // ============================================================
  final List<Map<String, dynamic>> _carouselItems = [
    {
      'title': 'Professional Car Wash',
      'subtitle': 'At Your Doorstep',
      'icon': Icons.local_car_wash,
      'color': 0xFF0CAF60,
      'gradient': [Color(0xFF0CAF60), Color(0xFF087F4B)],
      'imagePath': 'assets/images/flyer_launch.jpg',
      'features': ['Premium Service', 'Expert Washers', '100% Satisfaction'],
      'emoji': '🚗',
    },
    {
      'title': 'House Cleaning',
      'subtitle': 'Expert Home Services',
      'icon': Icons.cleaning_services,
      'color': 0xFF2196F3,
      'gradient': [Color(0xFF2196F3), Color(0xFF1565C0)],
      'imagePath': 'assets/images/flyer_services.jpg',
      'features': ['Deep Cleaning', 'Eco-Friendly', 'Trusted Professionals'],
      'emoji': '🧹',
    },
    {
      'title': 'Laundry Service',
      'subtitle': 'Fresh & Clean',
      'icon': Icons.local_laundry_service,
      'color': 0xFF9C27B0,
      'gradient': [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
      'imagePath': 'assets/images/flyer_whychoose.jpg',
      'features': ['Wash & Fold', 'Premium Quality', 'Fast Delivery'],
      'emoji': '👕',
    },
  ];

  final List<Map<String, dynamic>> _defaultCarWashServices = [
    {'name': 'Exterior Wash', 'price': 3000, 'priceDisplay': '₦3,000', 'icon': Icons.cleaning_services, 'duration': '30 mins'},
    {'name': 'Interior Cleaning', 'price': 5000, 'priceDisplay': '₦5,000', 'icon': Icons.event_seat, 'duration': '45 mins'},
    {'name': 'Full Detailing', 'price': 10000, 'priceDisplay': '₦10,000', 'icon': Icons.star, 'duration': '90 mins'},
    {'name': 'Engine Wash', 'price': 7000, 'priceDisplay': '₦7,000', 'icon': Icons.settings, 'duration': '60 mins'},
  ];

  final List<Map<String, dynamic>> _defaultHouseCleaningServices = [
    {'name': 'Standard Cleaning', 'price': 15000, 'priceDisplay': '₦15,000', 'icon': Icons.cleaning_services, 'duration': '3 hours', 'bedrooms': '2-3 beds'},
    {'name': 'Deep Cleaning', 'price': 25000, 'priceDisplay': '₦25,000', 'icon': Icons.brush, 'duration': '5 hours', 'bedrooms': '3-4 beds'},
    {'name': 'Move In/Out', 'price': 35000, 'priceDisplay': '₦35,000', 'icon': Icons.move_to_inbox, 'duration': '6 hours', 'bedrooms': '4-5 beds'},
    {'name': 'Office Cleaning', 'price': 20000, 'priceDisplay': '₦20,000', 'icon': Icons.business, 'duration': '4 hours', 'size': 'Small office'},
    {'name': 'Carpet Cleaning', 'price': 8000, 'priceDisplay': '₦8,000', 'icon': Icons.carpenter, 'duration': '2 hours', 'rooms': 'Per room'},
    {'name': 'Window Cleaning', 'price': 5000, 'priceDisplay': '₦5,000', 'icon': Icons.window, 'duration': '1.5 hours', 'floors': 'Per floor'},
  ];

  final List<Map<String, dynamic>> _defaultLaundryServices = [
    {'name': 'Wash & Fold', 'price': 2000, 'priceDisplay': '₦2,000', 'icon': Icons.local_laundry_service, 'duration': '24 hours', 'weight': 'Up to 5kg'},
    {'name': 'Wash & Iron', 'price': 3500, 'priceDisplay': '₦3,500', 'icon': Icons.iron, 'duration': '24 hours', 'weight': 'Up to 5kg'},
    {'name': 'Dry Cleaning', 'price': 5000, 'priceDisplay': '₦5,000', 'icon': Icons.dry, 'duration': '48 hours', 'items': 'Up to 3 items'},
    {'name': 'Ironing Only', 'price': 1500, 'priceDisplay': '₦1,500', 'icon': Icons.iron, 'duration': '12 hours', 'weight': 'Up to 3kg'},
    {'name': 'Bulk Laundry', 'price': 10000, 'priceDisplay': '₦10,000', 'icon': Icons.local_laundry_service, 'duration': '48 hours', 'weight': '15-20kg'},
    {'name': 'Curtain Cleaning', 'price': 7000, 'priceDisplay': '₦7,000', 'icon': Icons.curtains, 'duration': '72 hours', 'items': 'Per set'},
  ];

  List<Map<String, dynamic>> get _currentServices {
    if (_services.isNotEmpty) {
      return _services.where((service) => 
        service['category'] == _categories[_selectedCategoryIndex]['name']
      ).toList();
    }
    
    switch (_selectedCategoryIndex) {
      case 1:
        return _defaultHouseCleaningServices;
      case 2:
        return _defaultLaundryServices;
      default:
        return _defaultCarWashServices;
    }
  }

  String get _currentCategoryName => _categories.isNotEmpty 
      ? _categories[_selectedCategoryIndex]['name'] 
      : 'Car Wash';
      
  Color get _currentCategoryColor => _categories.isNotEmpty 
      ? _categories[_selectedCategoryIndex]['color'] 
      : AppColors.primary;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  void initState() {
    super.initState();
    _categories = _defaultCategories;
    _loadUserLocation();
    _loadServicesFromFirestore();
    
    _carouselController = PageController(initialPage: 0);
    _startCarouselTimer();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    _carouselTimer?.cancel();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_carouselController.hasClients) {
        final nextPage = (_currentCarouselIndex + 1) % _carouselItems.length;
        _carouselController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() {
          _currentCarouselIndex = nextPage;
        });
      }
    });
  }

  Future<void> _loadUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data['currentAddress'] != null) {
              setState(() {
                _selectedLocation = data['currentAddress'];
              });
            }
            if (data['currentLat'] != null && data['currentLng'] != null) {
              setState(() {
                _selectedCoordinates = LatLng(
                  data['currentLat'],
                  data['currentLng'],
                );
              });
            }
          }
        }
      }

      // Request live GPS location from browser/device
      final locationService = LocationService();
      final pos = await locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _selectedCoordinates = LatLng(pos.latitude, pos.longitude);
          if (locationService.currentAddress != null && locationService.currentAddress!.isNotEmpty) {
            _selectedLocation = locationService.currentAddress!;
          }
        });
      }
    } catch (e) {
      print('Error loading user location: $e');
    }
  }

  Future<void> _loadServicesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system')
          .get();
      
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['servicePrices'] != null) {
          final prices = data['servicePrices'] as Map<String, dynamic>;
          _updateServicesWithPrices(prices);
        }
      }
    } catch (e) {
      print('Error loading services: $e');
    }
  }

  void _updateServicesWithPrices(Map<String, dynamic> prices) {
    for (var service in _defaultCarWashServices) {
      final name = service['name'];
      if (prices.containsKey(name)) {
        service['price'] = prices[name];
        service['priceDisplay'] = '₦${NumberFormat('#,###').format(prices[name])}';
      }
    }
    for (var service in _defaultHouseCleaningServices) {
      final name = service['name'];
      if (prices.containsKey(name)) {
        service['price'] = prices[name];
        service['priceDisplay'] = '₦${NumberFormat('#,###').format(prices[name])}';
      }
    }
    for (var service in _defaultLaundryServices) {
      final name = service['name'];
      if (prices.containsKey(name)) {
        service['price'] = prices[name];
        service['priceDisplay'] = '₦${NumberFormat('#,###').format(prices[name])}';
      }
    }
  }

  void _selectService(Map<String, dynamic> service) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    if (!authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book a service'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirm Service', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(service['icon'], color: AppColors.primary, size: 40),
              title: Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Price: ${service['priceDisplay']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.primary)),
                  Text('Duration: ${service['duration']}', style: const TextStyle(color: Colors.grey)),
                  if (service.containsKey('weight'))
                    Text('Weight: ${service['weight']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (service.containsKey('bedrooms'))
                    Text('Bedrooms: ${service['bedrooms']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Delivery to: $_selectedLocation')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BookingScreen(
                            selectedService: service['name'],
                            selectedPrice: service['price'],
                            selectedAddress: _selectedLocation,
                            serviceCategory: _currentCategoryName,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeLocation() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.primary),
              title: const Text('Search Location'),
              subtitle: const Text('Search by city or area name'),
              onTap: () async {
                Navigator.pop(context);
                final newLocation = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (context) => const LocationSearchScreen()),
                );
                _handleLocationResult(newLocation);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map, color: AppColors.primary),
              title: const Text('Select on Map'),
              subtitle: const Text('Choose location using interactive map'),
              onTap: () async {
                Navigator.pop(context);
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
                if (result != null) {
                  setState(() {
                    _selectedLocation = result['address'] ?? _selectedLocation;
                    if (result['lat'] != null && result['lng'] != null) {
                      _selectedCoordinates = LatLng(
                        result['lat'] as double,
                        result['lng'] as double,
                      );
                    }
                  });
                  _saveLocationToFirestore(_selectedLocation);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.my_location, color: AppColors.primary),
              title: const Text('Use Current Location'),
              subtitle: const Text('Detect your GPS location'),
              onTap: () {
                Navigator.pop(context);
                _useCurrentLocation();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _handleLocationResult(String? newLocation) {
    if (newLocation != null && newLocation.isNotEmpty && mounted) {
      setState(() {
        _selectedLocation = newLocation;
      });
      _saveLocationToFirestore(newLocation);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 Location changed to: $newLocation'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Getting your current location...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (context) => const MapScreen()),
      );
      
      if (result != null) {
        setState(() {
          _selectedLocation = result['address'] ?? _selectedLocation;
          if (result['lat'] != null && result['lng'] != null) {
            _selectedCoordinates = LatLng(
              result['lat'] as double,
              result['lng'] as double,
            );
          }
        });
        _saveLocationToFirestore(_selectedLocation);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Using: $_selectedLocation'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveLocationToFirestore(String location) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'currentAddress': location,
          'currentLat': _selectedCoordinates?.latitude ?? 0,
          'currentLng': _selectedCoordinates?.longitude ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  void _goToNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
  }

  void _goToHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
    );
  }

  void _goToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacySecurityScreen()),
    );
  }

  void _becomeWasher() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WasherRegistrationScreen()),
    );
  }

  void _showReferralDialog() {
    final String referralCode = 'GWASH${DateTime.now().year}';
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Refer & Earn Rewards! 🎉',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share your referral code with friends and family!',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.code, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    'Referral Code: $referralCode',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'How it works:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildReferralStep(Icons.person_add, 'Share your code with friends'),
            _buildReferralStep(Icons.emoji_events, 'Get ₦1,000 when they book'),
            _buildReferralStep(Icons.money, 'Your friend gets ₦500 off'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _shareReferralCode(referralCode),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildReferralStep(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  void _shareReferralCode(String code) {
    final String shareText = 
      '🎉 Join me on G Wash NG!\n\n'
      'Use my referral code: $code\n'
      'Get ₦500 off your first booking!\n\n'
      'Download the app now and enjoy professional car wash, house cleaning, and laundry services at your doorstep.\n'
      'https://gwashng.com/download';
    
    Navigator.pop(context);
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✅ Referral code copied!', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Share: $code', style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.userName ?? 'Guest';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text(
          'G Wash NG',
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
            onPressed: _goToNotifications,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            onSelected: (value) {
              switch (value) {
                case 'become_washer':
                  _becomeWasher();
                  break;
                case 'help':
                  _goToHelpSupport();
                  break;
                case 'settings':
                  _goToSettings();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'become_washer',
                child: Row(
                  children: [
                    Icon(Icons.emoji_transportation, color: AppColors.primary, size: 22),
                    SizedBox(width: 12),
                    Text('Become a Partner', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'help',
                child: Row(
                  children: [
                    Icon(Icons.help_outline, color: AppColors.primary, size: 22),
                    SizedBox(width: 12),
                    Text('Help & Support', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, color: AppColors.primary, size: 22),
                    SizedBox(width: 12),
                    Text('Settings', style: TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(userName),
          const MyBookingsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bookmark_border),
            activeIcon: Icon(Icons.bookmark),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UPDATED: _buildHomeTab with Overflow Fix
  // ============================================================
  Widget _buildHomeTab(String userName) {
    final authService = Provider.of<AuthService>(context);
    final isLoggedIn = authService.isLoggedIn;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 380;
    
    // ============================================================
    // FIX: Get bottom padding for safe area
    // ============================================================
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SingleChildScrollView(
      // ============================================================
      // FIX: Add bottom padding to prevent overflow
      // ============================================================
      padding: EdgeInsets.only(bottom: bottomPadding + 80),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // HEADER with Gradient
          // ============================================================
          Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, isSmallScreen ? 20 : 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGreeting(),
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          '$userName ✨',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isSmallScreen ? 18 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Let's get your car sparkling ✨",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                        if (!isLoggedIn)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Not Logged In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('notifications')
                          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                          .where('isRead', isEqualTo: false)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return count > 0
                            ? Badge(
                                label: Text('$count'),
                                child: const Icon(Icons.notifications, color: Colors.white),
                              )
                            : const Icon(Icons.notifications_outlined, color: Colors.white);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Where should we come to?',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _changeLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedLocation,
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Text(
                          'Change',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // ============================================================
          // 3-SLIDE CAROUSEL WITH YOUR REAL IMAGES
          // ============================================================
          SizedBox(
            height: isSmallScreen ? 150 : 180, // Reduced height
            child: PageView.builder(
              controller: _carouselController,
              onPageChanged: (index) {
                setState(() {
                  _currentCarouselIndex = index;
                });
              },
              itemCount: _carouselItems.length,
              itemBuilder: (context, index) {
                final item = _carouselItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: (Color(item['color']) as Color).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // ============================================================
                        // YOUR REAL IMAGE AS BACKGROUND
                        // ============================================================
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              item['imagePath'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback if image doesn't load
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(item['color']),
                                        (Color(item['color']) as Color).withOpacity(0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item['emoji'],
                                      style: const TextStyle(fontSize: 80),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Dark overlay for text readability
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.1),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content on top of image
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      item['title'],
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallScreen ? 16 : 20,
                                        fontWeight: FontWeight.bold,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 10,
                                            color: Colors.black38,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item['subtitle'],
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: isSmallScreen ? 12 : 14,
                                        shadows: const [
                                          Shadow(
                                            blurRadius: 8,
                                            color: Colors.black38,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Features
                                    if (item['features'] != null)
                                      ...(item['features'] as List<String>).map((feature) => Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              feature,
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.9),
                                                fontSize: isSmallScreen ? 10 : 12,
                                                shadows: const [
                                                  Shadow(
                                                    blurRadius: 6,
                                                    color: Colors.black38,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () {
                                        final categoryIndex = _carouselItems.indexOf(item);
                                        setState(() {
                                          _selectedCategoryIndex = categoryIndex;
                                        });
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BookingScreen(
                                              serviceCategory: _carouselItems[categoryIndex]['title'],
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Color(item['color']),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: const Text(
                                        'Book Now',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Service icon on the right
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  item['icon'],
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Carousel Indicators
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _carouselItems.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentCarouselIndex == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentCarouselIndex == index
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ============================================================
          // CATEGORY TABS
          // ============================================================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(_categories.length, (index) {
                final category = _categories[index];
                final isSelected = _selectedCategoryIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategoryIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'],
                            size: 18,
                            color: isSelected ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category['name'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.primary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: isSmallScreen ? 11 : 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 20),

          // ============================================================
          // SERVICES SECTION
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Our Services',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('See all', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Service Cards - Responsive Grid
          if (isSmallScreen)
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _currentServices.length,
                itemBuilder: (context, index) {
                  final service = _currentServices[index];
                  return _buildServiceCard(service, isSmallScreen);
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: size.width > 600 ? 4 : 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: _currentServices.length,
                itemBuilder: (context, index) {
                  final service = _currentServices[index];
                  return _buildServiceCard(service, false);
                },
              ),
            ),
          
          const SizedBox(height: 24),

          // ============================================================
          // WHY CHOOSE US
          // ============================================================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Why Choose Us',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.location_on, 'Hyper-local dispatch', 'Washers near you, assigned fast.'),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.map, 'Live Tracking & ETA', 'Track your washer in real-time.'),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.security, 'Secure & Seamless', 'Safe payments and data privacy.'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // ============================================================
          // REFER & EARN
          // ============================================================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Refer & Earn',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Invite friends and earn amazing rewards',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showReferralDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Invite',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service, bool isSmall) {
    return GestureDetector(
      onTap: () => _selectService(service),
      child: Container(
        width: isSmall ? 140 : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service['icon'], size: isSmall ? 25 : 30, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              service['name'],
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: isSmall ? 11 : 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              service['priceDisplay'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: isSmall ? 12 : 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              service['duration'],
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: isSmall ? 8 : 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhyUsItem(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}