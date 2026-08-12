// lib/presentation/screens/customer/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  String _selectedLocation = 'Locating current position...';
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
  
  // Service Categories with FontAwesome Vector Icons

  final List<Map<String, dynamic>> _defaultCategories = [
    {'name': 'Car Wash', 'icon': FontAwesomeIcons.car, 'color': AppColors.primary},
    {'name': 'House Cleaning', 'icon': FontAwesomeIcons.broom, 'color': AppColors.primary},
    {'name': 'Laundry', 'icon': FontAwesomeIcons.shirt, 'color': AppColors.primary},
    {'name': 'Ride Service', 'icon': FontAwesomeIcons.taxi, 'color': AppColors.primary},
  ];


  // ============================================================
  // CAROUSEL DATA - ALL 4 SLIDES (Added Ride Service)
  // ============================================================
  final List<Map<String, dynamic>> _carouselItems = [
    {
      'imagePath': 'assets/images/flyer_launch.jpg',
      'category': 'Car Wash',
      'title': '30% OFF Car Wash',
      'subtitle': 'Spotless exterior wash & detailing at your doorstep',
      'badge': '🔥 SPECIAL OFFER',
      'cta': 'Claim Offer →',
      'gradient': [const Color(0xFF008080), const Color(0xFF0CAF60)],
      'icon': Icons.local_car_wash,
      'emoji': '🚗',
    },
    {
      'imagePath': 'assets/images/flyer_services.jpg',
      'category': 'House Cleaning',
      'title': 'Deep House Cleaning',
      'subtitle': 'Sanitized rooms & spotless spaces by top-rated pros',
      'badge': '✨ POPULAR SERVICE',
      'cta': 'Book Cleaner →',
      'gradient': [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
      'icon': Icons.cleaning_services,
      'emoji': '🧹',
    },
    {
      'imagePath': 'assets/images/flyer_whychoose.jpg',
      'category': 'Laundry',
      'title': 'Express Laundry & Dry Clean',
      'subtitle': 'Free doorstep pickup & delivery within 24 hours',
      'badge': '⚡ 24H EXPRESS',
      'cta': 'Schedule Wash →',
      'gradient': [const Color(0xFF581C87), const Color(0xFF7C3AED)],
      'icon': Icons.local_laundry_service,
      'emoji': '👕',
    },
    {
      'imagePath': 'assets/images/flyer_rider.jpg',
      'category': 'Ride Service',
      'title': 'On-Demand Ride Service',
      'subtitle': 'Comfortable sedans, SUVs & luxury rides anytime',
      'badge': '🚘 INSTANT RIDES',
      'cta': 'Book Ride →',
      'gradient': [const Color(0xFFC2410C), const Color(0xFFEA580C)],
      'icon': Icons.directions_car,
      'emoji': '🚘',
    },
  ];


  // REMOVED PRICES - Only service names and durations
  final List<Map<String, dynamic>> _defaultCarWashServices = [
    {'name': 'Exterior Wash', 'duration': '30 mins', 'icon': Icons.cleaning_services},
    {'name': 'Interior Cleaning', 'duration': '45 mins', 'icon': Icons.event_seat},
    {'name': 'Full Detailing', 'duration': '90 mins', 'icon': Icons.star},
    {'name': 'Engine Wash', 'duration': '60 mins', 'icon': Icons.settings},
  ];

  final List<Map<String, dynamic>> _defaultHouseCleaningServices = [
    {'name': 'Standard Cleaning', 'duration': '3 hours', 'icon': Icons.cleaning_services, 'bedrooms': '2-3 beds'},
    {'name': 'Deep Cleaning', 'duration': '5 hours', 'icon': Icons.brush, 'bedrooms': '3-4 beds'},
    {'name': 'Move In/Out', 'duration': '6 hours', 'icon': Icons.move_to_inbox, 'bedrooms': '4-5 beds'},
    {'name': 'Office Cleaning', 'duration': '4 hours', 'icon': Icons.business, 'size': 'Small office'},
    {'name': 'Carpet Cleaning', 'duration': '2 hours', 'icon': Icons.carpenter, 'rooms': 'Per room'},
    {'name': 'Window Cleaning', 'duration': '1.5 hours', 'icon': Icons.window, 'floors': 'Per floor'},
  ];

  final List<Map<String, dynamic>> _defaultLaundryServices = [
    {'name': 'Wash & Fold', 'duration': '24 hours', 'icon': Icons.local_laundry_service, 'weight': 'Up to 5kg'},
    {'name': 'Wash & Iron', 'duration': '24 hours', 'icon': Icons.iron, 'weight': 'Up to 5kg'},
    {'name': 'Dry Cleaning', 'duration': '48 hours', 'icon': Icons.dry, 'items': 'Up to 3 items'},
    {'name': 'Ironing Only', 'duration': '12 hours', 'icon': Icons.iron, 'weight': 'Up to 3kg'},
    {'name': 'Bulk Laundry', 'duration': '48 hours', 'icon': Icons.local_laundry_service, 'weight': '15-20kg'},
    {'name': 'Curtain Cleaning', 'duration': '72 hours', 'icon': Icons.curtains, 'items': 'Per set'},
  ];

  // NEW: Ride Service Options
  final List<Map<String, dynamic>> _defaultRideServices = [
    {'name': 'Standard Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Comfortable sedan'},
    {'name': 'SUV Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Spacious SUV'},
    {'name': 'Luxury Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Premium luxury car'},
    {'name': 'Van Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Group/team travel'},
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
      case 3:
        return _defaultRideServices;
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

  // ============================================================
  // UPDATED: Captivating tagline for ALL services
  // ============================================================
  String _getTagline() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Clean starts here';
    if (hour < 17) return 'Fresh vibes, anytime';
    return 'Your clean, your way';
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
      final locationService = LocationService();

      // First check if user has a previously stored address
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            if (data['currentAddress'] != null && data['currentAddress'].toString().isNotEmpty) {
              if (mounted) {
                setState(() {
                  _selectedLocation = data['currentAddress'];
                });
              }
            }
            if (data['currentLat'] != null && data['currentLng'] != null) {
              if (mounted) {
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
      }

      // Automatically fetch current live GPS position on login / app launch
      debugPrint('📍 Fetching real-time device location on app launch...');
      final pos = await locationService.getCurrentLocation();
      
      if (mounted) {
        setState(() {
          _selectedCoordinates = LatLng(pos.latitude, pos.longitude);
          if (locationService.currentAddress != null && locationService.currentAddress!.isNotEmpty) {
            _selectedLocation = locationService.currentAddress!;
          }
        });

        // Show location update toast if address was detected
        if (_selectedLocation.isNotEmpty && !_selectedLocation.contains('Locating')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.my_location, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location updated: $_selectedLocation',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('ℹ️ Notice fetching live user location: $e');
      if (mounted && _selectedLocation == 'Locating current position...') {
        setState(() {
          _selectedLocation = 'Lagos, Nigeria';
        });
      }
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
          // Price loading removed
        }
      }
    } catch (e) {
      print('Error loading services: $e');
    }
  }

  void _updateServicesWithPrices(Map<String, dynamic> prices) {
    // Price display removed
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
                  Text('Duration: ${service['duration']}', style: const TextStyle(color: Colors.grey)),
                  if (service.containsKey('weight'))
                    Text('Weight: ${service['weight']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (service.containsKey('bedrooms'))
                    Text('Bedrooms: ${service['bedrooms']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  if (service.containsKey('description'))
                    Text('Description: ${service['description']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            selectedPrice: 0, // Price removed
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

  Future<void> _changeLocation() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationSearchScreen(),
      ),
    );

    if (result != null && result['address'] != null) {
      final String address = result['address'];
      final LatLng? coords = result['coordinates'];

      setState(() {
        _selectedLocation = address;
        if (coords != null) _selectedCoordinates = coords;
      });

      // Save updated location to Firestore for current user
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'currentAddress': address,
          if (coords != null) 'currentLat': coords.latitude,
          if (coords != null) 'currentLng': coords.longitude,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userName = authService.userName ?? 'Guest';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          'G Wash NG',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: AppColors.primary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
            onPressed: _goToNotifications,
          ),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/profile');
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: authService.photoURL != null && authService.photoURL!.isNotEmpty
                      ? Image.network(
                          authService.photoURL!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(Icons.person, color: AppColors.primary, size: 20),
                          ),
                        )
                      : const Center(
                          child: Icon(Icons.person, color: AppColors.primary, size: 20),
                        ),
                ),
              ),
            ),
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
  // UPDATED: _buildHomeTab with 4 slides
  // ============================================================
  Widget _buildHomeTab(String userName) {
    final authService = Provider.of<AuthService>(context);
    final isLoggedIn = authService.isLoggedIn;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 380;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomPadding + 160),
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
                          style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white70),
                        ),
                        Text(
                          userName,
                          style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getTagline(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
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
                            child: Text(
                              'Not Logged In',
                              style: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Where should we come to?',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
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
                            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Change',
                          style: theme.textTheme.labelLarge?.copyWith(color: AppColors.primary),
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
          // 4-SLIDE CAROUSEL - RICH GRAPHICAL PROMO FLYERS
          // ============================================================
          SizedBox(
            height: isSmallScreen ? 170 : 200,
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
                  child: _buildFlyerCard(item),
                );
              },
            ),
          ),


          const SizedBox(height: 8),

          // ============================================================
          // CATEGORY TABS - Responsive wrapping
          // ============================================================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 8,
              children: List.generate(_categories.length, (index) {
                final category = _categories[index];
                final isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          category['icon'],
                          size: 16,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category['name'],
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: isSelected ? Colors.white : AppColors.primary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: isSmallScreen ? 11 : 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          
          const SizedBox(height: 20),

          // ============================================================
          // SERVICES SECTION - Responsive grid
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentCategoryName == 'Ride Service' ? 'Book a Ride' : 'Our Services',
                  style: theme.textTheme.headlineSmall,
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'See all',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          
          // Service Cards - Responsive Grid with wrapping
          if (isSmallScreen)
            SizedBox(
              height: 150,
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
                  crossAxisCount: size.width > 600 ? 4 : size.width > 400 ? 3 : 2,
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
                Text(
                  'Why Choose Us',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.location_on, 'Hyper-local dispatch', 'Service providers near you, assigned fast'),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.map, 'Live Tracking & ETA', 'Track your provider in real-time'),
                const SizedBox(height: 16),
                _buildWhyUsItem(Icons.security, 'Secure & Seamless', 'Safe payments and data privacy'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // ============================================================
          // REFER & EARN
          // ============================================================
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Refer & Earn',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Invite friends & earn rewards',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showReferralDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Invite',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
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

  // ============================================================
  // SERVICE CARD - No Price Display, Better Wrapping
  // ============================================================
  Widget _buildServiceCard(Map<String, dynamic> service, bool isSmall) {
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => _selectService(service),
      child: Container(
        width: isSmall ? 130 : null,
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(service['icon'], size: isSmall ? 24 : 28, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              service['name'],
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: isSmall ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              service['duration'],
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: isSmall ? 9 : 11,
              ),
            ),
            if (service.containsKey('bedrooms'))
              Text(
                service['bedrooms'],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade400,
                  fontSize: isSmall ? 8 : 10,
                ),
              ),
            if (service.containsKey('description'))
              Text(
                service['description'],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade400,
                  fontSize: isSmall ? 8 : 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REMAINING METHODS (Unchanged)
  // ============================================================
  void _openLocationPicker() async {
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

  Widget _buildWhyUsItem(IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CLEAN FLYER CARD BUILDER
  // ============================================================
  Widget _buildFlyerCard(Map<String, dynamic> item) {
    final String path = item['imagePath'] ?? 'assets/images/flyer_launch.jpg';
    final String fileName = path.split('/').last;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookingScreen(
              serviceCategory: item['category'] ?? 'Car Wash',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                'assets/$path',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'assets/images/$fileName',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.network(
                        'assets/assets/images/$fileName',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade300,
                            child: const Center(
                              child: Icon(Icons.image, size: 50, color: AppColors.primary),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

