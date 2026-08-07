// lib/presentation/screens/customer/matching_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/job_service.dart';
import '../../../services/auth_service.dart';
import 'tracking_screen.dart';

class MatchingScreen extends StatefulWidget {
  final String? jobId;
  final String serviceCategory;
  final String serviceName;
  final int? price;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime? scheduledDate;
  final String? scheduledTime;

  const MatchingScreen({
    super.key,
    this.jobId,
    required this.serviceCategory,
    required this.serviceName,
    this.price,
    required this.location,
    this.latitude,
    this.longitude,
    this.scheduledDate,
    this.scheduledTime,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  List<Map<String, dynamic>> _nearbyWashers = [];
  bool _isLoading = true;
  bool _isSearching = true;
  Timer? _searchTimer;
  int _searchCount = 0;
  String? _selectedWasherId;
  bool _isAssigning = false;

  // Cache for provider images
  final Map<String, String> _providerImages = {};

  @override
  void initState() {
    super.initState();
    _searchForWashers();
    _startPeriodicSearch();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicSearch() {
    _searchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_searchCount < 20) {
        _searchForWashers();
        _searchCount++;
      } else {
        timer.cancel();
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _searchForWashers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('washers')
          .where('isOnline', isEqualTo: true)
          .where('approved', isEqualTo: true)
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> washers = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] ?? doc.id;
          
          // Get user name
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          String userName = 'Service Provider';
          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? 'Service Provider';
          }

          // Get profile image
          String? profileImage = data['profileImage'];
          if (profileImage == null || profileImage.isEmpty) {
            // Try to get from users collection
            if (userDoc.exists) {
              profileImage = userDoc.data()?['profileImage'];
            }
          }

          // Cache the image
          if (profileImage != null && profileImage.isNotEmpty) {
            _providerImages[doc.id] = profileImage;
          }

          washers.add({
            'id': doc.id,
            'userId': userId,
            'name': userName,
            'phone': data['phone'] ?? '',
            'vehicleType': data['vehicleType'] ?? 'Car',
            'workingRadius': data['workingRadius'] ?? 10,
            'rating': data['rating'] ?? 4.5,
            'totalJobs': data['totalJobs'] ?? 0,
            'totalEarnings': data['totalEarnings'] ?? 0,
            'isOnline': data['isOnline'] ?? true,
            'profileImage': profileImage,
            'distance': _calculateDistance(data),
            'eta': _calculateETA(data['workingRadius'] ?? 10),
            'serviceCategories': data['serviceCategories'] ?? [],
            'bio': data['bio'] ?? 'Professional service provider',
          });
        }

        // Sort by distance
        washers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        setState(() {
          _nearbyWashers = washers;
          _isLoading = false;
          _isSearching = false;
        });

        print('✅ Found ${washers.length} nearby providers');
      } else {
        // Demo providers if none in Firestore
        setState(() {
          _nearbyWashers = _getDemoProviders();
          _isLoading = false;
          _isSearching = false;
        });
        print('⚠️ No providers found in Firestore, using demo data');
      }
    } catch (e) {
      print('❌ Error searching for providers: $e');
      setState(() {
        _nearbyWashers = _getDemoProviders();
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  double _calculateDistance(Map<String, dynamic> data) {
    // Simulate distance based on working radius
    final radius = (data['workingRadius'] ?? 10) as int;
    // Random distance between 0.3 and radius/2
    return (0.3 + (radius / 2) * (DateTime.now().millisecondsSinceEpoch % 100) / 100);
  }

  String _calculateETA(int workingRadius) {
    if (workingRadius < 5) return '3 mins';
    if (workingRadius < 10) return '5 mins';
    if (workingRadius < 15) return '8 mins';
    return '10 mins';
  }

  List<Map<String, dynamic>> _getDemoProviders() {
    return [
      {
        'id': 'demo1',
        'name': 'John Adebayo',
        'rating': 4.8,
        'vehicleType': 'Car',
        'distance': 0.5,
        'eta': '3 mins',
        'isOnline': true,
        'totalJobs': 150,
        'totalEarnings': 450000,
        'profileImage': null,
        'bio': 'Professional car wash specialist with 5 years experience',
        'serviceCategories': ['Car Wash', 'Detailing'],
      },
      {
        'id': 'demo2',
        'name': 'Mary Okonkwo',
        'rating': 4.9,
        'vehicleType': 'SUV',
        'distance': 1.2,
        'eta': '5 mins',
        'isOnline': true,
        'totalJobs': 200,
        'totalEarnings': 600000,
        'profileImage': null,
        'bio': 'Expert in house cleaning and laundry services',
        'serviceCategories': ['House Cleaning', 'Laundry'],
      },
      {
        'id': 'demo3',
        'name': 'Peter Eze',
        'rating': 4.7,
        'vehicleType': 'Van',
        'distance': 2.0,
        'eta': '8 mins',
        'isOnline': true,
        'totalJobs': 120,
        'totalEarnings': 360000,
        'profileImage': null,
        'bio': 'Reliable ride service and car wash provider',
        'serviceCategories': ['Ride Service', 'Car Wash'],
      },
      {
        'id': 'demo4',
        'name': 'Grace Daniel',
        'rating': 4.6,
        'vehicleType': 'Car',
        'distance': 2.5,
        'eta': '10 mins',
        'isOnline': true,
        'totalJobs': 80,
        'totalEarnings': 240000,
        'profileImage': null,
        'bio': 'Specialized in laundry and dry cleaning',
        'serviceCategories': ['Laundry', 'Dry Cleaning'],
      },
    ];
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  int _getProviderPrice(Map<String, dynamic> provider) {
    if (provider['price'] != null && provider['price'] is num && (provider['price'] as num) > 0) {
      return (provider['price'] as num).toInt();
    }
    // Rate per service type
    switch (widget.serviceName) {
      case 'Standard Ride': return 2500;
      case 'SUV Ride': return 4000;
      case 'Luxury Ride': return 7000;
      case 'Van Ride': return 5500;
      case 'Exterior Wash': return 3500;
      case 'Interior Cleaning': return 5500;
      case 'Full Detailing': return 12000;
      case 'Engine Wash': return 8000;
      case 'Standard Cleaning': return 15000;
      case 'Deep Cleaning': return 25000;
      case 'Move In/Out': return 35000;
      case 'Office Cleaning': return 20000;
      case 'Wash & Fold': return 2500;
      case 'Wash & Iron': return 4000;
      case 'Dry Cleaning': return 5500;
      case 'Ironing Only': return 1800;
      default: return widget.price ?? 3000;
    }
  }

  void _selectProvider(Map<String, dynamic> provider) async {
    setState(() {
      _selectedWasherId = provider['id'];
      _isAssigning = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? authService.userId ?? '';

      final customerName = authService.userName ?? 'Customer';
      final customerPhone = authService.userPhone ?? (user?.phoneNumber ?? '');
      final customerEmail = authService.userEmail ?? (user?.email ?? '');

      final int finalPrice = _getProviderPrice(provider);
      String createdJobId = widget.jobId ?? '';

      if (createdJobId.isEmpty) {
        // Create job in Firestore assigned directly to selected provider!
        final result = await JobService().createJob(
          customerId: uid,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: customerEmail,
          serviceCategory: widget.serviceCategory,
          serviceName: widget.serviceName,
          price: finalPrice,
          location: widget.location,
          latitude: widget.latitude ?? 6.5244,
          longitude: widget.longitude ?? 3.3792,
          scheduledDate: widget.scheduledDate ?? DateTime.now(),
          scheduledTime: widget.scheduledTime ?? '9:00 AM',
          assignedWasherId: provider['id'],
          assignedWasherName: provider['name'],
          providerPhone: provider['phone'] ?? '',
        );
        createdJobId = result['id'];
      } else {
        // Update existing job document
        await FirebaseFirestore.instance
            .collection('jobs')
            .doc(createdJobId)
            .update({
          'washerId': provider['id'],
          'washerName': provider['name'],
          'washerRating': provider['rating'],
          'washerPhone': provider['phone'] ?? '',
          'price': finalPrice,
          'status': 'assigned',
          'assignedAt': FieldValue.serverTimestamp(),
          'washerImage': provider['profileImage'] ?? '',
        });
      }

      // Update provider stats
      try {
        await FirebaseFirestore.instance
            .collection('washers')
            .doc(provider['id'])
            .update({
          'pendingJobs': FieldValue.increment(1),
          'lastJobAssigned': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('ℹ️ Provider stat update info: $e');
      }

      setState(() {
        _isAssigning = false;
      });

      if (mounted) {
        _showBookingSuccessDialog(
          jobId: createdJobId,
          providerName: provider['name'],
          providerImage: provider['profileImage'],
          price: finalPrice,
          providerId: provider['id'],
        );
      }
    } catch (e) {
      print('❌ Error assigning provider: $e');
      setState(() {
        _isAssigning = false;
        _selectedWasherId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking service: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBookingSuccessDialog({
    required String jobId,
    required String providerName,
    String? providerImage,
    required int price,
    required String providerId,
  }) {
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
            Center(
              child: Text(
                'Your service order has been placed with $providerName!',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Booking request dispatched to $providerName.',
                      style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
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
                  _buildSuccessSummaryRow('Service', widget.serviceName),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Category', widget.serviceCategory),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Amount', '₦${NumberFormat('#,###').format(price)}'),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Location', widget.location),
                  const Divider(height: 12),
                  _buildSuccessSummaryRow('Provider', providerName),
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrackingScreen(
                      jobId: jobId,
                      washerName: providerName,
                      pickupAddress: widget.location,
                      pickupLocation: LatLng(widget.latitude ?? 6.5244, widget.longitude ?? 3.3792),
                      serviceName: widget.serviceName,
                      price: price,
                      washerId: providerId,
                      washerImage: providerImage,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Proceed to Track & Pay →', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Finding Service Provider',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isSearching && _nearbyWashers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    color: AppColors.primary,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_nearbyWashers.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Status
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              children: [
                _isSearching
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSearching 
                            ? 'Searching for providers...' 
                            : '${_nearbyWashers.length} providers found nearby',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _isSearching 
                            ? 'Please wait while we find the best match' 
                            : 'Select a provider to continue',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSearching)
                  Text(
                    '${_searchCount}/20',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Provider List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Finding nearby providers...'),
                      ],
                    ),
                  )
                : _nearbyWashers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No providers available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please try again later',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _isSearching = true;
                                  _searchCount = 0;
                                });
                                _searchForWashers();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _nearbyWashers.length,
                        itemBuilder: (context, index) {
                          final provider = _nearbyWashers[index];
                          final isSelected = _selectedWasherId == provider['id'];
                          final imageUrl = _providerImages[provider['id']];
                          final initials = _getInitials(provider['name']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            elevation: isSelected ? 4 : 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Provider Profile Image
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: AppColors.primary.withOpacity(0.1),
                                                child: Center(
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: AppColors.primary.withOpacity(0.1),
                                                child: Center(
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: AppColors.primary.withOpacity(0.1),
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Provider Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          provider['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.amber,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              provider['rating'].toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.work,
                                              color: Colors.grey.shade500,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${provider['totalJobs']} jobs',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: AppColors.primary,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              provider['distance'].toStringAsFixed(1),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Text(' km away'),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.timer,
                                              color: Colors.orange,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              provider['eta'],
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (provider['bio'] != null)
                                          Text(
                                            provider['bio'],
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 11,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Price & Select Button
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₦${NumberFormat('#,###').format(_getProviderPrice(provider))}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ElevatedButton(
                                        onPressed: _isAssigning && isSelected
                                            ? null
                                            : () => _selectProvider(provider),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSelected ? AppColors.primary : AppColors.primary.withOpacity(0.1),
                                          foregroundColor: isSelected ? Colors.white : AppColors.primary,
                                          minimumSize: const Size(70, 34),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: _isAssigning && isSelected
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : Text(
                                                isSelected ? 'Selected' : 'Select',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}