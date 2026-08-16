// FILE: lib/presentation/screens/washer/washer_profile_screen.dart
// PURPOSE: Washer profile management with Firebase integration
// UPDATED: Shows real data from Firestore including services

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/cloudinary_service.dart';
import '../welcome_screen.dart';
import 'washer_job_history_screen.dart';
import '../customer/help_support_screen.dart';

class WasherProfileScreen extends StatefulWidget {
  final String? washerId;

  const WasherProfileScreen({
    super.key,
    this.washerId,
  });

  @override
  State<WasherProfileScreen> createState() => _WasherProfileScreenState();
}

class _WasherProfileScreenState extends State<WasherProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _washerData = {};
  String _washerId = '';
  String _profileImageUrl = '';

  Future<void> _pickAndUploadProfileImage() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
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
              'Change Washer Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Uploading profile photo to Cloudinary...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final cloudinaryService = CloudinaryService();
      final photoUrl = await cloudinaryService.uploadImage(imageFile: image, folder: 'washer_profiles');

      if (photoUrl != null && photoUrl.isNotEmpty) {
        await authService.updateWasherProfilePicture(photoUrl);
        setState(() {
          _profileImageUrl = photoUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile photo updated successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Service names mapping
  final Map<String, String> _serviceNames = {
    'car_wash': 'Car Washer',
    'house_cleaning': 'House Cleaner',
    'cleaning': 'House Cleaner',
    'laundry': 'Laundry Service',
    'ride_service': 'Ride Service',
    'car_wash_exterior_wash': 'Exterior Wash',
    'car_wash_interior_cleaning': 'Interior Cleaning',
    'car_wash_full_detailing': 'Full Detailing',
    'car_wash_engine_wash': 'Engine Wash',
    'house_cleaning_standard_cleaning': 'Standard Cleaning',
    'house_cleaning_deep_cleaning': 'Deep Cleaning',
    'house_cleaning_move_in_out': 'Move In/Out',
    'house_cleaning_office_cleaning': 'Office Cleaning',
    'house_cleaning_carpet_cleaning': 'Carpet Cleaning',
    'house_cleaning_window_cleaning': 'Window Cleaning',
    'laundry_wash_fold': 'Wash & Fold',
    'laundry_wash_iron': 'Wash & Iron',
    'laundry_dry_cleaning': 'Dry Cleaning',
    'laundry_ironing_only': 'Ironing Only',
    'laundry_bulk_laundry': 'Bulk Laundry',
    'laundry_curtain_cleaning': 'Curtain Cleaning',
    'ride_service_standard_ride': 'Standard Ride',
    'ride_service_suv_ride': 'SUV Ride',
    'ride_service_luxury_ride': 'Luxury Ride',
    'ride_service_van_ride': 'Van Ride',
  };

  final Map<String, IconData> _serviceIcons = {
    'car_wash': Icons.local_car_wash,
    'cleaning': Icons.cleaning_services,
    'house_cleaning': Icons.cleaning_services,
    'laundry': Icons.local_laundry_service,
    'ride_service': Icons.car_rental,
  };

  final Map<String, Color> _serviceColors = {
    'car_wash': const Color(0xFF0CAF60),
    'cleaning': Colors.blue,
    'house_cleaning': Colors.blue,
    'laundry': const Color(0xFF9C27B0),
    'ride_service': Colors.orange,
  };

  @override
  void initState() {
    super.initState();
    _loadWasherData();
  }

  Future<void> _loadWasherData() async {
    setState(() => _isLoading = true);

    try {
      String? washerId = widget.washerId;

      // If no washerId provided, get from AuthService
      if (washerId == null || washerId.isEmpty) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final userId = authService.getCurrentUserId();

        if (userId == null) {
          setState(() => _isLoading = false);
          return;
        }

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        final userData = userDoc.exists ? userDoc.data() : null;
        final authPhoto = authService.photoURL;

        final query = await FirebaseFirestore.instance
            .collection('washers')
            .where('userId', isEqualTo: userId)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          _washerId = doc.id;
          final data = doc.data();
          final imgUrl = (data['profileImage'] ?? data['photoURL'] ?? data['profilePicture'] ?? userData?['photoURL'] ?? userData?['profilePicture'] ?? userData?['profileImage'] ?? authPhoto ?? '').toString();
          setState(() {
            _washerData = data;
            _profileImageUrl = imgUrl;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        // Load by washerId
        final doc = await FirebaseFirestore.instance
            .collection('washers')
            .doc(washerId)
            .get();

        if (doc.exists) {
          _washerId = doc.id;
          final data = doc.data()!;
          final uId = (data['userId'] ?? '').toString();
          DocumentSnapshot<Map<String, dynamic>>? userDoc;
          if (uId.isNotEmpty) {
            userDoc = await FirebaseFirestore.instance.collection('users').doc(uId).get();
          }
          final userData = userDoc != null && userDoc.exists ? userDoc.data() : null;
          final imgUrl = (data['profileImage'] ?? data['photoURL'] ?? data['profilePicture'] ?? userData?['photoURL'] ?? userData?['profilePicture'] ?? userData?['profileImage'] ?? '').toString();
          setState(() {
            _washerData = data;
            _profileImageUrl = imgUrl;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading washer data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getServiceDisplayName(String serviceId) {
    return _serviceNames[serviceId] ?? serviceId.replaceAll('_', ' ').toUpperCase();
  }

  List<String> _getAllServices() {
    List<String> services = [];
    
    // Get from selectedServices
    final selectedServices = List<String>.from(_washerData['selectedServices'] ?? []);
    services.addAll(selectedServices);
    
    // Get from serviceCategories
    final serviceCategories = List<String>.from(_washerData['serviceCategories'] ?? []);
    services.addAll(serviceCategories);
    
    // Get from selectedMainCategories
    final mainCategories = List<String>.from(_washerData['selectedMainCategories'] ?? []);
    services.addAll(mainCategories);
    
    // Remove duplicates
    return services.toSet().toList();
  }

  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(content),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_washerData.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/washer-dashboard');
            }
          },
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off, size: 60, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Washer not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'This washer profile could not be loaded',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Extract data from Firestore
    final name = _washerData['name'] ?? authService.userName ?? 'Washer Name';
    final phone = _washerData['phone'] ?? authService.userPhone ?? '+234 801 234 5678';
    final email = _washerData['email'] ?? 'Not provided';
    final city = _washerData['city'] ?? 'Not set';
    final state = _washerData['state'] ?? 'Not set';
    final rating = _washerData['rating'] ?? 0.0;
    final totalJobs = _washerData['totalJobs'] ?? 0;
    final totalEarnings = _washerData['totalEarnings'] ?? 0;
    final isOnline = _washerData['isOnline'] ?? false;
    final isApproved = _washerData['approved'] ?? false;
    final vehicleType = _washerData['vehicleType'] ?? 'Not set';
    final workingRadius = _washerData['workingRadius'] ?? 10;
    final bankName = _washerData['bankName'] ?? 'Not set';
    final accountNumber = _washerData['accountNumber'] ?? 'Not set';
    final accountName = _washerData['accountName'] ?? 'Not set';
    final specialization = _washerData['specialization'] ?? 'Not set';
    final turnaroundTime = _washerData['turnaroundTime'] ?? 'Not set';
    
    // Get all services
    final allServices = _getAllServices();
    final serviceDisplayNames = allServices.map((id) => _serviceNames[id] ?? id).join(', ');

    // Format date
    String createdAt = 'Not available';
    if (_washerData['createdAt'] != null) {
      try {
        final date = (_washerData['createdAt'] as Timestamp).toDate();
        createdAt = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        createdAt = 'Not available';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/washer-dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadWasherData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWasherData,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ============================================================
              // PROFILE HEADER
              // ============================================================
              Container(
                padding: const EdgeInsets.all(24),
                color: AppColors.primaryBackground,
                child: Column(
                  children: [
                    // Profile Image
                    GestureDetector(
                      onTap: _pickAndUploadProfileImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _profileImageUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _profileImageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                            style: const TextStyle(
                                              fontSize: 40,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.grey.shade200,
                                      child: Center(
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'W',
                                          style: const TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(color: AppColors.grey600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isApproved ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isApproved ? Icons.verified : Icons.pending,
                                size: 14,
                                color: isApproved ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isApproved ? 'Verified' : 'Pending Approval',
                                style: TextStyle(
                                  color: isApproved ? Colors.green : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnline ? Icons.wifi : Icons.wifi_off,
                                size: 14,
                                color: isOnline ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  color: isOnline ? Colors.green : Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                rating > 0 ? '${rating.toStringAsFixed(1)} ★' : 'No ratings yet',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Service chips
                    if (allServices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: allServices.map((serviceId) {
                          final color = _serviceColors[serviceId] ?? AppColors.primary;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _serviceIcons[serviceId] ?? Icons.work,
                                  size: 12,
                                  color: color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _serviceNames[serviceId] ?? serviceId.replaceAll('_', ' '),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // ============================================================
              // LOCATION INFO
              // ============================================================
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            city != 'Not set' ? '$city, $state' : 'Location not set',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // STATS
              // ============================================================
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(totalJobs.toString(), 'Jobs'),
                    Container(width: 1, height: 40, color: AppColors.grey300),
                    _buildStatItem('₦${NumberFormat('#,###').format(totalEarnings)}', 'Earnings'),
                    Container(width: 1, height: 40, color: AppColors.grey300),
                    _buildStatItem('${totalJobs > 0 ? ((totalJobs - 0) / totalJobs * 100).toStringAsFixed(0) : 0}%', 'Completion'),
                  ],
                ),
              ),

              // ============================================================
              // MENU ITEMS
              // ============================================================

              // Personal Information
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'Personal Information',
                subtitle: '$name · $email',
                onTap: () {
                  _showInfoDialog(
                    'Personal Information',
                    'Name: $name\nPhone: $phone\nEmail: $email\nLocation: $city, $state\nJoined: $createdAt',
                  );
                },
              ),

              // Services & Pricing
              _buildMenuItem(
                icon: Icons.sell,
                title: 'Services & Custom Pricing',
                subtitle: serviceDisplayNames.isNotEmpty ? '$serviceDisplayNames · Tap to set custom prices' : 'Tap to manage services & custom pricing',
                onTap: () => _showEditServicesAndPricesDialog(),
              ),


              // Vehicle Details
              _buildMenuItem(
                icon: Icons.directions_car,
                title: 'Vehicle Details',
                subtitle: 'Vehicle: $vehicleType',
                onTap: () {
                  _showInfoDialog(
                    'Vehicle Details',
                    'Vehicle Type: $vehicleType\nWorking Radius: $workingRadius km',
                  );
                },
              ),

              // Bank Account
              _buildMenuItem(
                icon: Icons.credit_card,
                title: 'Bank Account',
                subtitle: bankName != 'Not set' ? '$bankName · $accountName' : 'No bank account set',
                onTap: () {
                  _showInfoDialog(
                    'Bank Account',
                    'Bank: $bankName\nAccount Name: $accountName\nAccount Number: $accountNumber',
                  );
                },
              ),

              // Specialization (if cleaner)
              if (_washerData['specialization'] != null) 
                _buildMenuItem(
                  icon: Icons.brush,
                  title: 'Specialization',
                  subtitle: 'Cleaning: $specialization',
                  onTap: () {
                    _showInfoDialog(
                      'Cleaning Specialization',
                      'Specialization: $specialization\nTools: ${(_washerData['cleaningTools'] as List?)?.join(', ') ?? 'Not specified'}',
                    );
                  },
                ),

              // Turnaround Time (if laundry)
              if (_washerData['turnaroundTime'] != null)
                _buildMenuItem(
                  icon: Icons.timer,
                  title: 'Turnaround Time',
                  subtitle: 'Laundry: $turnaroundTime',
                  onTap: () {
                    _showInfoDialog(
                      'Laundry Turnaround',
                      'Turnaround Time: $turnaroundTime',
                    );
                  },
                ),

              // Working Radius
              _buildMenuItem(
                icon: Icons.speed,
                title: 'Working Radius',
                subtitle: 'Current radius: $workingRadius km',
                onTap: () {
                  _showInfoDialog(
                    'Working Radius',
                    'You serve customers within $workingRadius km radius.',
                  );
                },
              ),

              const Divider(),

              // Job History
              _buildMenuItem(
                icon: Icons.history,
                title: 'Job History',
                subtitle: 'View all completed jobs',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WasherJobHistoryScreen(washerId: _washerId),
                    ),
                  );
                },
              ),

              // Help & Support
              _buildMenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help or contact support',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HelpSupportScreen(),
                    ),
                  );
                },
              ),

              const Divider(),

              // Logout
              _buildMenuItem(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                isDestructive: true,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
      ],
    );
  }

  void _showEditServicesAndPricesDialog() {
    final Map<String, dynamic> currentPrices = Map<String, dynamic>.from(_washerData['servicePrices'] ?? {});
    final priceControllers = <String, TextEditingController>{};

    final allServices = _getAllServices();
    if (allServices.isEmpty) {
      allServices.addAll(['Exterior Wash', 'Interior Cleaning', 'Full Detailing', 'Standard Cleaning', 'Deep Cleaning', 'Wash & Fold', 'Standard Ride']);
    }

    for (var s in allServices) {
      final displayName = _getServiceDisplayName(s);
      final existingVal = currentPrices[displayName] ?? currentPrices[s] ?? '';
      priceControllers[displayName] = TextEditingController(text: existingVal.toString());
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.sell, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Custom Service Pricing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set your custom price for each service offered. Customers will see your custom prices when booking!',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...priceControllers.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: entry.value,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        prefixText: '₦ ',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedPrices = <String, int>{};
              priceControllers.forEach((name, ctrl) {
                final val = int.tryParse(ctrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                if (val != null && val > 0) {
                  updatedPrices[name] = val;
                }
              });

              if (_washerId != null && _washerId!.isNotEmpty) {
                await FirebaseFirestore.instance.collection('washers').doc(_washerId).set({
                  'servicePrices': updatedPrices,
                  'price': updatedPrices.values.isNotEmpty ? updatedPrices.values.first : null,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                setState(() {
                  _washerData['servicePrices'] = updatedPrices;
                  if (updatedPrices.values.isNotEmpty) {
                    _washerData['price'] = updatedPrices.values.first;
                  }
                });

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Custom service prices updated successfully! 🎉'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save Pricing'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({

    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppColors.grey600,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20, color: AppColors.grey400),
      onTap: onTap,
    );
  }
}