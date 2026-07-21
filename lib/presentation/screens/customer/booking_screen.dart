import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/app_notification_service.dart';
import '../washer/matching_screen.dart';
import 'tracking_screen.dart';

class BookingScreen extends StatefulWidget {
  final String? selectedService;
  final int? selectedPrice;
  final String? selectedAddress;
  final String? serviceCategory;

  const BookingScreen({
    super.key,
    this.selectedService,
    this.selectedPrice,
    this.selectedAddress,
    this.serviceCategory,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String _selectedCategory = 'Car Wash';
  String _selectedService = 'Standard Cleaning';
  int _selectedServicePrice = 15000;
  String _selectedLocation = 'Lekki Phase 1, Lagos';
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '9:00 AM';
  bool _isBooking = false;

  final List<String> _categories = ['Car Wash', 'House Cleaning', 'Laundry'];

  // Service Data
  final Map<String, List<Map<String, dynamic>>> _services = {
    'Car Wash': [
      {'name': 'Exterior Wash', 'price': 3000, 'duration': '30 mins', 'description': 'Wash and dry exterior'},
      {'name': 'Interior Cleaning', 'price': 5000, 'duration': '45 mins', 'description': 'Vacuum and wipe interior'},
      {'name': 'Full Detailing', 'price': 10000, 'duration': '90 mins', 'description': 'Complete wash and detailing'},
      {'name': 'Engine Wash', 'price': 7000, 'duration': '60 mins', 'description': 'Engine bay cleaning'},
    ],
    'House Cleaning': [
      {'name': 'Standard Cleaning', 'price': 15000, 'duration': '3 hours', 'description': 'Basic cleaning for 2-3 bedroom apartments'},
      {'name': 'Deep Cleaning', 'price': 25000, 'duration': '5 hours', 'description': 'Deep clean for 3-4 bedroom apartments'},
      {'name': 'Move In/Out', 'price': 35000, 'duration': '6 hours', 'description': 'Full move in/out cleaning'},
      {'name': 'Office Cleaning', 'price': 20000, 'duration': '4 hours', 'description': 'Professional office cleaning'},
    ],
    'Laundry': [
      {'name': 'Wash & Fold', 'price': 2000, 'duration': '24 hours', 'description': 'Wash, dry, and fold service'},
      {'name': 'Wash & Iron', 'price': 3500, 'duration': '24 hours', 'description': 'Wash, dry, and iron service'},
      {'name': 'Dry Cleaning', 'price': 5000, 'duration': '48 hours', 'description': 'Professional dry cleaning'},
      {'name': 'Ironing Only', 'price': 1500, 'duration': '12 hours', 'description': 'Ironing service only'},
    ],
  };

  final List<String> _timeSlots = [
    '9:00 AM', '10:30 AM', '12:00 PM', '1:30 PM', '3:00 PM', '4:30 PM', '6:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.selectedService != null) {
      _selectedService = widget.selectedService!;
    }
    if (widget.selectedPrice != null) {
      _selectedServicePrice = widget.selectedPrice!;
    }
    if (widget.selectedAddress != null) {
      _selectedLocation = widget.selectedAddress!;
    }
    if (widget.serviceCategory != null) {
      _selectedCategory = widget.serviceCategory!;
    }
  }

  List<Map<String, dynamic>> get _currentServices {
    return _services[_selectedCategory] ?? _services['Car Wash']!;
  }

  Map<String, dynamic> get _currentServiceDetails {
    return _currentServices.firstWhere(
      (service) => service['name'] == _selectedService,
      orElse: () => _currentServices[0],
    );
  }

  String get _actionButtonText {
    switch (_selectedCategory) {
      case 'Car Wash':
        return 'Book Car Wash';
      case 'House Cleaning':
        return 'Book House Cleaning';
      case 'Laundry':
        return 'Book Laundry';
      default:
        return 'Book Now';
    }
  }

  void _showServicePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Service',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentServices.length,
                  itemBuilder: (context, index) {
                    final service = _currentServices[index];
                    final isSelected = service['name'] == _selectedService;
                    return ListTile(
                      tileColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(service['name']),
                      subtitle: Text('₦${NumberFormat('#,###').format(service['price'])} · ${service['duration']}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedService = service['name'];
                          _selectedServicePrice = service['price'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Lekki Phase 1, Lagos'),
              onTap: () {
                setState(() => _selectedLocation = 'Lekki Phase 1, Lagos');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Victoria Island, Lagos'),
              onTap: () {
                setState(() => _selectedLocation = 'Victoria Island, Lagos');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Ikeja, Lagos'),
              onTap: () {
                setState(() => _selectedLocation = 'Ikeja, Lagos');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on, color: AppColors.primary),
              title: const Text('Surulere, Lagos'),
              onTap: () {
                setState(() => _selectedLocation = 'Surulere, Lagos');
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FIX 1: Check auth using AuthService provider
  // ============================================================
  void _bookService() async {
    setState(() => _isBooking = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isLoggedIn) {
        throw Exception('Please login to book a service');
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? authService.userId ?? '';
      final customerName = authService.userName ?? 'Customer';

      // Create job in Firestore
      final result = await JobService().createJob(
        customerId: uid,
        customerName: customerName,
        serviceCategory: _selectedCategory,
        serviceName: _selectedService,
        price: _selectedServicePrice,
        location: _selectedLocation,
        latitude: 6.5244,
        longitude: 3.3792,
        scheduledDate: _selectedDate,
        scheduledTime: _selectedTime,
      );

      final jobId = result['id'];

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchingScreen(
              jobId: jobId,
              serviceCategory: _selectedCategory,
              serviceName: _selectedService,
              price: _selectedServicePrice,
              location: _selectedLocation,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error creating job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking service: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _showProviderSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Service Provider',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose who should handle your $_selectedCategory in $_selectedLocation',
                style: const TextStyle(fontSize: 13, color: AppColors.grey600),
              ),
              const SizedBox(height: 16),
              // Option for Auto-Assign
              Card(
                elevation: 0,
                color: AppColors.primary.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.flash_on, color: Colors.white),
                  ),
                  title: const Text('Auto-Assign Nearest Provider', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Fastest match based on GPS location & ETA'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
                  onTap: () {
                    Navigator.pop(context);
                    _createBookingWithProvider();
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Text('Available Nearby Providers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: JobService().getProvidersByCategory(
                    category: _selectedCategory,
                    userLat: 6.5244,
                    userLng: 3.3792,
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final providers = snapshot.data ?? [];
                    if (providers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            const Text('No specific providers listed nearby right now.'),
                            const SizedBox(height: 4),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                _createBookingWithProvider();
                              },
                              icon: const Icon(Icons.flash_on),
                              label: const Text('Proceed with Auto-Assign'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: providers.length,
                      itemBuilder: (context, index) {
                        final provider = providers[index];
                        final name = provider['name'] ?? provider['fullName'] ?? 'G-Wash Provider';
                        final vehicle = provider['vehicleType'] ?? 'Motorcycle';
                        final rating = (provider['rating'] ?? 4.9).toString();
                        final distance = provider['distanceDisplay'] ?? '2.0 km';
                        final providerId = provider['id'] ?? provider['userId'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withOpacity(0.15),
                              child: const Icon(Icons.person, color: AppColors.primary),
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$vehicle • $distance away'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(rating, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('Select', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              final providerPhone = provider['phone']?.toString();
                              final providerEmail = provider['email']?.toString();
                              _createBookingWithProvider(
                                providerId: providerId,
                                providerName: name,
                                providerPhone: providerPhone,
                                providerEmail: providerEmail,
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createBookingWithProvider({
    String? providerId,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
  }) async {
    setState(() => _isBooking = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isLoggedIn) {
        throw Exception('Please login to book a service');
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? authService.userId ?? '';
      final customerName = authService.userName ?? 'Customer';

      final result = await JobService().createJob(
        customerId: uid,
        customerName: customerName,
        serviceCategory: _selectedCategory,
        serviceName: _selectedService,
        price: _selectedServicePrice,
        location: _selectedLocation,
        latitude: 6.5244,
        longitude: 3.3792,
        scheduledDate: _selectedDate,
        scheduledTime: _selectedTime,
        assignedWasherId: providerId,
        assignedWasherName: providerName,
      );

      final jobId = result['id'];

      // Trigger local in-app top popup & offline notification
      AppNotificationService().notify(
        context: context,
        title: '🎉 Booking Confirmed!',
        message: 'Your $_selectedCategory request ($_selectedService) has been placed.',
        type: 'booking',
        icon: Icons.check_circle_outline,
        backgroundColor: Colors.green.shade700,
      );

      // Send WhatsApp and Email notifications if a specific provider was selected
      if (providerName != null && providerName.isNotEmpty) {
        final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
        CommunicationService.sendBookingNotifications(
          providerPhone: providerPhone,
          providerEmail: providerEmail,
          providerName: providerName,
          customerName: customerName,
          serviceCategory: _selectedCategory,
          serviceName: _selectedService,
          price: _selectedServicePrice,
          location: _selectedLocation,
          scheduledDate: formattedDate,
          scheduledTime: _selectedTime,
          jobId: jobId,
          context: context,
        );
      }

      if (mounted) {
        if (providerId != null && providerId.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingScreen(
                jobId: jobId,
                washerName: providerName ?? 'Washer',
                pickupAddress: _selectedLocation,
                pickupLocation: const LatLng(6.5244, 3.3792),
                serviceName: _selectedService,
                price: _selectedServicePrice,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MatchingScreen(
                jobId: jobId,
                serviceCategory: _selectedCategory,
                serviceName: _selectedService,
                price: _selectedServicePrice,
                location: _selectedLocation,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error creating job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking service: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get auth state
    final authService = Provider.of<AuthService>(context);
    final isLoggedIn = authService.isLoggedIn;
    final serviceDetails = _currentServiceDetails;
    final servicePrice = serviceDetails['price'] ?? 0;
    final serviceDuration = serviceDetails['duration'] ?? '30 mins';
    final serviceDescription = serviceDetails['description'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(
          _selectedCategory == 'Car Wash' ? 'Book Car Wash' :
          _selectedCategory == 'House Cleaning' ? 'Book House Cleaning' :
          'Book Laundry',
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Show login status indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isLoggedIn ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isLoggedIn ? Icons.check_circle : Icons.warning,
                  color: isLoggedIn ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  isLoggedIn ? 'Logged In' : 'Not Logged In',
                  style: TextStyle(
                    color: isLoggedIn ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Tabs - All Green
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                        _selectedService = _services[category]![0]['name'];
                        _selectedServicePrice = _services[category]![0]['price'];
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.primary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ============================================================
          // FIX 2: Show warning banner if not logged in
          // ============================================================
          if (!isLoggedIn)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: const Text(
                      'Please login to book a service',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Service Selected - Green
                  _buildSectionTitle('Service Selected'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedService,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₦${NumberFormat('#,###').format(servicePrice)} · $serviceDuration',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (serviceDescription.isNotEmpty)
                                Text(
                                  serviceDescription,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _showServicePicker,
                          child: const Text(
                            'Change',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Delivery Location - Green
                  _buildSectionTitle('Delivery Location'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedLocation,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton(
                          onPressed: _showLocationPicker,
                          child: const Text(
                            'Change',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Preferred Date & Time - Green
                  _buildSectionTitle('Preferred Date & Time'),

                  // Date Selection
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: 7,
                            itemBuilder: (context, index) {
                              final date = DateTime.now().add(Duration(days: index));
                              final isSelected = _selectedDate.day == date.day &&
                                  _selectedDate.month == date.month;
                              final dayName = DateFormat('E').format(date);
                              final dayNumber = date.day.toString();
                              return GestureDetector(
                                onTap: () => setState(() => _selectedDate = date),
                                child: Container(
                                  width: 65,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        index == 0 ? 'Today' : index == 1 ? 'Tomorrow' : dayName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        dayNumber,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const Divider(height: 16),
                        // Time Selection
                        SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _timeSlots.length,
                            itemBuilder: (context, index) {
                              final time = _timeSlots[index];
                              final isSelected = _selectedTime == time;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedTime = time),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      time,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.black87,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Payment Info - Note: Payment After Service
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: const Text(
                            '💳 Payment will be made after service completion',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ============================================================
                  // FIX 3: BOOK BUTTON - Disabled if not logged in
                  // ============================================================
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isBooking || !isLoggedIn ? null : _bookService,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLoggedIn ? AppColors.primary : Colors.grey,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isBooking
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              !isLoggedIn ? 'Please Login to Book' : _actionButtonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  // ============================================================
                  // FIX 4: Login button shown if not logged in
                  // ============================================================
                  if (!isLoggedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Go to Login',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }
}