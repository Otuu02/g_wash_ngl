// FILE: lib/presentation/screens/customer/booking_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/location_service.dart';
import 'matching_screen.dart';

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
  String _selectedService = 'Exterior Wash';
  int _selectedServicePrice = 3000;
  String _selectedLocation = 'Lekki Phase 1, Lagos';
  double _latitude = 6.5244;
  double _longitude = 3.3792;
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '9:00 AM';
  bool _isBooking = false;
  String? _bookingError;

  final List<String> _categories = ['Car Wash', 'House Cleaning', 'Laundry', 'Ride Service'];

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
    'Ride Service': [
      {'name': 'Standard Ride', 'price': 2000, 'duration': 'On-demand', 'description': 'Comfortable sedan for up to 4 passengers'},
      {'name': 'SUV Ride', 'price': 3500, 'duration': 'On-demand', 'description': 'Spacious SUV for up to 6 passengers'},
      {'name': 'Luxury Ride', 'price': 5000, 'duration': 'On-demand', 'description': 'Premium luxury car for special occasions'},
      {'name': 'Van Ride', 'price': 4000, 'duration': 'On-demand', 'description': 'Group/team travel for up to 10 passengers'},
    ],
  };

  final List<String> _timeSlots = [
    '9:00 AM', '10:30 AM', '12:00 PM', '1:30 PM', '3:00 PM', '4:30 PM', '6:00 PM'
  ];

  @override
  void initState() {
    super.initState();
    _initializeSelections();
    _fetchGPSLocation();
  }

  Future<void> _fetchGPSLocation() async {
    try {
      final locService = LocationService();
      final pos = await locService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          if (locService.currentAddress != null && locService.currentAddress!.isNotEmpty) {
            _selectedLocation = locService.currentAddress!;
          }
        });
      }
    } catch (e) {
      debugPrint('ℹ️ Location fetch info: $e');
    }
  }

  void _initializeSelections() {
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
      final services = _services[_selectedCategory] ?? _services['Car Wash']!;
      if (services.isNotEmpty) {
        _selectedService = services[0]['name'];
        _selectedServicePrice = services[0]['price'];
      }
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

  String get _actionButtonText => 'Proceed to Find Providers →';

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
                      subtitle: Text('${service['duration']} · ${service['description']}'),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildLocationOption('Lekki Phase 1, Lagos', Icons.location_on),
              _buildLocationOption('Victoria Island, Lagos', Icons.location_on),
              _buildLocationOption('Ikeja, Lagos', Icons.location_on),
              _buildLocationOption('Surulere, Lagos', Icons.location_on),
              _buildLocationOption('Use Current Location', Icons.my_location),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationOption(String location, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(location),
      onTap: () {
        setState(() => _selectedLocation = location);
        Navigator.pop(context);
      },
    );
  }

  // ============================================================
  // BOOK SERVICE - WITH REAL-TIME NOTIFICATIONS
  // ============================================================
  Future<void> _bookService() async {
    setState(() {
      _isBooking = true;
      _bookingError = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (!authService.isLoggedIn) {
        throw Exception('Please login to book a service');
      }

      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? authService.userId ?? '';
      
      if (uid.isEmpty) {
        throw Exception('User ID not found. Please login again.');
      }

      final customerName = authService.userName ?? 'Customer';
      final customerPhone = authService.userPhone ?? (user?.phoneNumber ?? '');
      final customerEmail = authService.userEmail ?? (user?.email ?? '');

      print('📝 Creating job for: $customerName ($uid)');
      print('📝 Service: $_selectedService - ₦$_selectedServicePrice');
      print('📝 Location: $_selectedLocation');

      // Create job with dynamic GPS coordinates & trigger Twilio SMS + Gmail SMTP notifications
      final result = await JobService().createJob(
        customerId: uid,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        serviceCategory: _selectedCategory,
        serviceName: _selectedService,
        price: _selectedServicePrice,
        location: _selectedLocation,
        latitude: _latitude,
        longitude: _longitude,
        scheduledDate: _selectedDate,
        scheduledTime: _selectedTime,
      );

      final jobId = result['id'];
      
      print('✅ Job created with ID: $jobId');

      // Show prominent success modal popup
      if (mounted) {
        _showBookingSuccessDialog(jobId, providerName: result['washerName']);
      }
      
    } catch (e) {
      print('❌ Error creating job: $e');
      setState(() {
        _bookingError = e.toString();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBooking = false);
      }
    }
  }

  void _showBookingSuccessDialog(String jobId, {String? providerName}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 12),
            Text(
              'Booking Confirmed! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Your service order has been placed successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mark_email_read, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SMS & Email notifications dispatched via Twilio & Gmail SMTP to ${providerName ?? 'assigned provider'}.',
                      style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Column(
                children: [
                  _buildSuccessSummaryRow('Service', _selectedService),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Category', _selectedCategory),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Amount', '₦${NumberFormat('#,###').format(_selectedServicePrice)}'),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Location', _selectedLocation),
                  if (providerName != null && providerName.isNotEmpty) ...[
                    const Divider(height: 12),
                    _buildSuccessSummaryRow('Provider', providerName),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Proceed to Find Provider ➔',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _selectedCategory == 'Laundry' ? 'Book Laundry' :
          'Book Ride',
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
          // Category Tabs
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
                        final services = _services[category]!;
                        if (services.isNotEmpty) {
                          _selectedService = services[0]['name'];
                          _selectedServicePrice = services[0]['price'];
                        }
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

          // Login Warning
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

          // Error message if any
          if (_bookingError != null)
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
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _bookingError!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
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
                                '$serviceDuration · On-demand provider rates',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
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

                  _buildSectionTitle('Preferred Date & Time'),

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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: List.generate(7, (index) {
                              final date = DateTime.now().add(Duration(days: index));
                              final isSelected = _selectedDate.day == date.day &&
                                  _selectedDate.month == date.month &&
                                  _selectedDate.year == date.year;

                              String dayName;
                              if (index == 0) {
                                dayName = 'Today';
                              } else if (index == 1) {
                                dayName = 'Tomorrow';
                              } else {
                                dayName = DateFormat('EEE').format(date);
                              }

                              return GestureDetector(
                                onTap: () => setState(() => _selectedDate = date),
                                child: Container(
                                  width: 70,
                                  height: 80,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary : AppColors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dayName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white70 : Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${date.day}',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.black87,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        const Divider(height: 16),
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
                            '💳 Select provider and view exact rates on next step',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Book / Find Providers Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login to find service providers'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          Navigator.pushNamed(context, '/login');
                          return;
                        }

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MatchingScreen(
                              serviceCategory: _selectedCategory,
                              serviceName: _selectedService,
                              location: _selectedLocation,
                              latitude: _latitude,
                              longitude: _longitude,
                              scheduledDate: _selectedDate,
                              scheduledTime: _selectedTime,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLoggedIn ? AppColors.primary : Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        !isLoggedIn ? 'Please Login to Book' : 'Proceed to Find Providers →',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

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
