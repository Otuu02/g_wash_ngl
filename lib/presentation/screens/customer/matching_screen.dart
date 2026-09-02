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
import '../../widgets/payment_safety_dialog.dart';

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

  bool _isCategoryMatch(Map<String, dynamic> data, String selectedCategory) {
    if (selectedCategory.trim().isEmpty ||
        selectedCategory.toLowerCase().trim() == 'all' ||
        selectedCategory.toLowerCase().trim() == 'any' ||
        selectedCategory.toLowerCase().trim() == 'general') {
      return true;
    }

    final target = selectedCategory.toLowerCase().trim();

    bool checkString(String str) {
      if (str.isEmpty) return false;
      final s = str.toLowerCase().trim();
      if (s == target) return true;
      if (target.contains(s) || s.contains(target)) return true;

      if ((target.contains('car') || target.contains('wash') || target.contains('auto') || target.contains('detail')) &&
          (s.contains('car') || s.contains('wash') || s.contains('auto') || s.contains('detail'))) {
        return true;
      }
      if ((target.contains('clean') || target.contains('house') || target.contains('home') || target.contains('maid') || target.contains('fumig') || target.contains('sofa')) &&
          (s.contains('clean') || s.contains('house') || s.contains('home') || s.contains('maid') || s.contains('fumig') || s.contains('sofa'))) {
        return true;
      }
      if ((target.contains('laundry') || target.contains('dry') || target.contains('cloth') || target.contains('iron')) &&
          (s.contains('laundry') || s.contains('dry') || s.contains('cloth') || s.contains('iron'))) {
        return true;
      }
      if ((target.contains('ride') || target.contains('drive') || target.contains('cab') || target.contains('taxi') || target.contains('transport')) &&
          (s.contains('ride') || s.contains('drive') || s.contains('cab') || s.contains('taxi') || s.contains('transport') || s.contains('driver'))) {
        return true;
      }
      return false;
    }

    final singleFields = [
      'serviceCategory',
      'category',
      'service_category',
      'serviceType',
      'mainCategory',
      'workCategory',
      'role',
      'userType',
    ];

    for (final field in singleFields) {
      if (data[field] != null) {
        if (checkString(data[field].toString())) return true;
      }
    }

    final listFields = [
      'mainCategoryNames',
      'selectedMainCategories',
      'mainCategories',
      'serviceCategories',
      'selectedServices',
      'categories',
      'services',
    ];

    bool foundCategoryField = false;

    for (final field in listFields) {
      final list = data[field];
      if (list != null) {
        if (list is List && list.isNotEmpty) {
          foundCategoryField = true;
          for (var item in list) {
            if (item != null && checkString(item.toString())) return true;
          }
        } else if (list is String && list.trim().isNotEmpty) {
          foundCategoryField = true;
          if (checkString(list)) return true;
        }
      }
    }

    final subServices = data['subServices'] ?? data['selectedSubServices'] ?? data['subServicePrices'];
    if (subServices is Map && subServices.isNotEmpty) {
      foundCategoryField = true;
      for (var key in subServices.keys) {
        if (checkString(key.toString())) return true;
      }
    } else if (subServices is List && subServices.isNotEmpty) {
      foundCategoryField = true;
      for (var item in subServices) {
        if (item != null && checkString(item.toString())) return true;
      }
    }

    if (!foundCategoryField && (data['serviceCategory'] == null || data['serviceCategory'].toString().trim().isEmpty)) {
      return true;
    }

    return false;
  }

  Future<void> _searchForWashers() async {
    try {
      List<Map<String, dynamic>> washers = [];
      Set<String> processedIds = {};

      // 1. Query washers collection
      final washersSnapshot = await FirebaseFirestore.instance
          .collection('washers')
          .get();

      for (var doc in washersSnapshot.docs) {
        final data = doc.data();

        if (!_isCategoryMatch(data, widget.serviceCategory)) {
          continue;
        }

        final userId = data['userId'] ?? data['uid'] ?? doc.id;
        processedIds.add(userId);
        processedIds.add(doc.id);

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        String userName = 'Service Provider';
        if (userDoc.exists) {
          userName = userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? 'Service Provider';
        } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
          userName = data['name'].toString();
        }

        String? profileImage = (data['profileImage'] ?? data['photoURL'] ?? data['profilePicture'] ?? data['avatar'] ?? data['washerPhotoURL'])?.toString();
        if ((profileImage == null || profileImage.isEmpty) && userDoc.exists) {
          final uData = userDoc.data();
          profileImage = (uData?['profileImage'] ?? uData?['photoURL'] ?? uData?['profilePicture'] ?? uData?['avatar'] ?? uData?['washerPhotoURL'])?.toString();
        }

        if (profileImage != null && profileImage.isNotEmpty) {
          _providerImages[doc.id] = profileImage;
          if (userId.isNotEmpty) _providerImages[userId] = profileImage;
        }

        final washerPrice = _extractWasherPrice(data, widget.serviceName);
        final washerEmail = data['email'] ?? (userDoc.exists ? (userDoc.data()?['email'] ?? '') : '');

        washers.add({
          'id': doc.id,
          'userId': userId,
          'name': userName,
          'phone': data['phone'] ?? (userDoc.exists ? (userDoc.data()?['phone'] ?? '') : ''),
          'email': washerEmail,
          'price': washerPrice,
          'vehicleType': data['vehicleType'] ?? 'Car',
          'workingRadius': data['workingRadius'] ?? 10,
          'rating': data['rating'] ?? 4.8,
          'totalJobs': data['totalJobs'] ?? 0,
          'totalEarnings': data['totalEarnings'] ?? 0,
          'isOnline': data['isOnline'] ?? true,
          'profileImage': profileImage,
          'distance': _calculateDistance(data),
          'eta': _calculateETA(data['workingRadius'] ?? 10),
          'serviceCategories': data['mainCategoryNames'] ?? data['serviceCategories'] ?? [widget.serviceCategory],
          'bio': data['bio'] ?? 'Professional ${widget.serviceCategory} provider',
        });
      }

      // 2. Query users collection for registered provider users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (var doc in usersSnapshot.docs) {
        if (processedIds.contains(doc.id)) continue;
        final data = doc.data();

        final role = (data['role'] ?? '').toString().toLowerCase();
        final isWasherFlag = data['isWasher'] == true || data['isProvider'] == true || data['userType'] == 'provider';
        final isProviderRole = role.contains('washer') ||
            role.contains('provider') ||
            role.contains('cleaner') ||
            role.contains('driver') ||
            role.contains('vendor') ||
            role.contains('agent');

        if (!isProviderRole && !isWasherFlag && data['washerId'] == null) {
          continue;
        }

        if (!_isCategoryMatch(data, widget.serviceCategory)) {
          continue;
        }

        processedIds.add(doc.id);

        final userName = data['name'] ?? data['fullName'] ?? 'Service Provider';
        String? profileImage = (data['profileImage'] ?? data['photoURL'] ?? data['profilePicture'] ?? data['avatar'] ?? data['washerPhotoURL'])?.toString();

        if (profileImage != null && profileImage.isNotEmpty) {
          _providerImages[doc.id] = profileImage;
        }

        final washerPrice = _extractWasherPrice(data, widget.serviceName);

        washers.add({
          'id': doc.id,
          'userId': doc.id,
          'name': userName,
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
          'price': washerPrice,
          'vehicleType': data['vehicleType'] ?? 'Car',
          'workingRadius': data['workingRadius'] ?? 10,
          'rating': data['rating'] ?? 4.8,
          'totalJobs': data['totalJobs'] ?? 0,
          'totalEarnings': data['totalEarnings'] ?? 0,
          'isOnline': data['isOnline'] ?? true,
          'profileImage': profileImage,
          'distance': _calculateDistance(data),
          'eta': _calculateETA(data['workingRadius'] ?? 10),
          'serviceCategories': data['mainCategoryNames'] ?? data['serviceCategories'] ?? data['mainCategories'] ?? [widget.serviceCategory],
          'bio': data['bio'] ?? 'Professional ${widget.serviceCategory} provider',
        });
      }

      // 3. Fallback: If washers list is empty, fetch ALL docs from washers collection without strict category filter
      if (washers.isEmpty && washersSnapshot.docs.isNotEmpty) {
        for (var doc in washersSnapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] ?? data['uid'] ?? doc.id;
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          String userName = 'Service Provider';
          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? 'Service Provider';
          } else if (data['name'] != null && data['name'].toString().isNotEmpty) {
            userName = data['name'].toString();
          }

          String? profileImage = (data['profileImage'] ?? data['photoURL'] ?? data['profilePicture'] ?? data['avatar'] ?? data['washerPhotoURL'])?.toString();

          washers.add({
            'id': doc.id,
            'userId': userId,
            'name': userName,
            'phone': data['phone'] ?? (userDoc.exists ? (userDoc.data()?['phone'] ?? '') : ''),
            'email': data['email'] ?? '',
            'price': _extractWasherPrice(data, widget.serviceName),
            'vehicleType': data['vehicleType'] ?? 'Car',
            'workingRadius': data['workingRadius'] ?? 10,
            'rating': data['rating'] ?? 4.8,
            'totalJobs': data['totalJobs'] ?? 0,
            'totalEarnings': data['totalEarnings'] ?? 0,
            'isOnline': data['isOnline'] ?? true,
            'profileImage': profileImage,
            'distance': _calculateDistance(data),
            'eta': _calculateETA(data['workingRadius'] ?? 10),
            'serviceCategories': data['mainCategoryNames'] ?? [widget.serviceCategory],
            'bio': data['bio'] ?? 'Professional ${widget.serviceCategory} provider',
          });
        }
      }

      // Sort by distance
      washers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _nearbyWashers = washers;
        _isLoading = false;
        _isSearching = false;
      });

      debugPrint('✅ Found ${washers.length} real Firestore providers for "${widget.serviceCategory}"');
    } catch (e) {
      debugPrint('❌ Error searching for real providers: $e');
      setState(() {
        _nearbyWashers = [];
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  int? _extractWasherPrice(Map<String, dynamic> data, String serviceName) {
    final Map<dynamic, dynamic>? subPrices = data['subServicePrices'] ?? data['servicePrices'] ?? data['prices'];
    if (subPrices != null && subPrices.isNotEmpty) {
      if (subPrices[serviceName] != null) {
        final valStr = subPrices[serviceName].toString().replaceAll(RegExp(r'[^0-9]'), '');
        final parsed = int.tryParse(valStr);
        if (parsed != null && parsed > 0) return parsed;
      }
      final sNameLower = serviceName.trim().toLowerCase().replaceAll(' ', '_');
      for (var entry in subPrices.entries) {
        final keyLower = entry.key.toString().trim().toLowerCase();
        if (keyLower == sNameLower || keyLower.endsWith(sNameLower) || keyLower.contains(sNameLower) || sNameLower.contains(keyLower)) {
          final valStr = entry.value.toString().replaceAll(RegExp(r'[^0-9]'), '');
          final parsed = int.tryParse(valStr);
          if (parsed != null && parsed > 0) return parsed;
        }
      }
    }
    if (data['customPrice'] != null && data['customPrice'] is num && (data['customPrice'] as num) > 0) {
      return (data['customPrice'] as num).toInt();
    }
    if (data['price'] != null && data['price'] is num && (data['price'] as num) > 0) {
      return (data['price'] as num).toInt();
    }
    if (data['servicePrice'] != null && data['servicePrice'] is num && (data['servicePrice'] as num) > 0) {
      return (data['servicePrice'] as num).toInt();
    }
    return null;
  }


  double _calculateDistance(Map<String, dynamic> data) {
    final radius = (data['workingRadius'] ?? 10) as int;
    return (0.3 + (radius / 2) * (DateTime.now().millisecondsSinceEpoch % 100) / 100);
  }

  String _calculateETA(int workingRadius) {
    if (workingRadius < 5) return '3 mins';
    if (workingRadius < 10) return '5 mins';
    if (workingRadius < 15) return '8 mins';
    return '10 mins';
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
    if (widget.price != null && widget.price! > 0) {
      return widget.price!;
    }
    // Rate per service type fallback
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
        // Create job in Firestore assigned directly to selected provider with status pending_acceptance
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
          assignedWasherId: provider['userId'] ?? provider['id'],
          assignedWasherName: provider['name'],
          providerPhone: provider['phone'] ?? '',
          providerEmail: provider['email'] ?? '',
        );
        createdJobId = result['id'];
      }

      // Explicitly set status to pending_acceptance for instant provider alert overlay
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(createdJobId)
          .update({
        'status': 'pending_acceptance',
        'washerId': provider['userId'] ?? provider['id'],
        'washerDocId': provider['id'],
        'assignedWasherId': provider['userId'] ?? provider['id'],
        'washerName': provider['name'],
        'washerPhone': provider['phone'] ?? '',
        'washerEmail': provider['email'] ?? '',
        'price': finalPrice,
      });

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

      if (mounted) {
        _waitForProviderResponse(createdJobId, provider, finalPrice);
      }
    } catch (e) {
      debugPrint('❌ Error assigning provider: $e');
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

  void _waitForProviderResponse(String jobId, Map<String, dynamic> provider, int finalPrice) {
    StreamSubscription<DocumentSnapshot>? subscription;
    Timer? timeoutTimer;
    bool dialogOpen = true;

    // ⏳ 30-SECOND ACCEPTANCE TIMEOUT FALLBACK
    timeoutTimer = Timer(const Duration(seconds: 30), () async {
      if (dialogOpen && mounted) {
        subscription?.cancel();
        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        try {
          await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
            'status': 'expired',
            'expiredAt': FieldValue.serverTimestamp(),
            'expireReason': 'Provider did not respond within 30 seconds',
          });
        } catch (e) {
          debugPrint('⚠️ Error expiring job: $e');
        }

        setState(() {
          _isAssigning = false;
          _selectedWasherId = null;
        });

        _showProviderUnavailableDialog(provider['name']);
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 4),
                const SizedBox(height: 20),
                Text(
                  'Contacting ${provider['name']}...',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for service provider to accept your request. (30s timeout)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.flash_on, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.serviceName} • ₦${NumberFormat('#,###').format(finalPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      dialogOpen = false;
      timeoutTimer?.cancel();
      subscription?.cancel();
    });

    subscription = FirebaseFirestore.instance
        .collection('jobs')
        .doc(jobId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      final status = (data?['status'] ?? '').toString().toLowerCase();

      if (status == 'accepted' || status == 'assigned') {
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        setState(() {
          _isAssigning = false;
        });
        _showBookingSuccessDialog(
          jobId: jobId,
          providerName: provider['name'],
          providerImage: provider['profileImage'],
          price: finalPrice,
          providerId: provider['id'],
        );
      } else if (status == 'declined') {
        timeoutTimer?.cancel();
        subscription?.cancel();
        if (dialogOpen && mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        setState(() {
          _isAssigning = false;
          _selectedWasherId = null;
        });
        _showProviderUnavailableDialog(provider['name']);
      }
    });
  }

  void _showProviderUnavailableDialog(String providerName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.timer_off, color: Colors.orange, size: 50),
            SizedBox(height: 10),
            Text(
              'Provider Unavailable ⏳',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          '$providerName is currently unavailable or did not respond within 30 seconds.\n\nPlease select another service provider nearby!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Choose Another Provider', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
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
              onPressed: () async {
                Navigator.pop(context);
                // 🔒 Mandatory Payment & Safety Notice
                final agreed = await PaymentSafetyDialog.show(
                  context,
                  providerName: providerName,
                );

                if (agreed == true && mounted) {
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
                }
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