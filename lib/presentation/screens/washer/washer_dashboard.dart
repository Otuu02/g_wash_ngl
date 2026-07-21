// FILE: lib/presentation/screens/washer/washer_dashboard.dart
// PURPOSE: Main dashboard for washers - shows services, earnings, and job requests
// UPDATED: All features working with real data from Firestore

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import 'job_request_screen.dart';
import 'earnings_screen.dart';
import 'washer_profile_screen.dart';
import 'washer_registration_screen.dart';

class WasherDashboard extends StatefulWidget {
  const WasherDashboard({super.key});

  @override
  State<WasherDashboard> createState() => _WasherDashboardState();
}

class _WasherDashboardState extends State<WasherDashboard> {
  int _currentIndex = 0;
  bool _isOnline = false;
  bool _isApproved = false;
  bool _isLoading = true;
  bool _hasApplied = false;
  String _washerStatus = 'pending';
  String _washerId = '';
  
  // ============================================================
  // ADDED: _washerData to store all washer data
  // ============================================================
  Map<String, dynamic> _washerData = {};
  
  // Selected services
  List<Map<String, dynamic>> _selectedServices = [];
  
  // Real data from Firestore
  Map<String, dynamic> _washerStats = {
    'todayEarnings': 0,
    'totalJobs': 0,
    'rating': 0.0,
    'totalEarnings': 0,
    'pendingJobs': 0,
  };

  // Service icons and colors mapping
  final Map<String, Map<String, dynamic>> _serviceDetails = {
    'Car Wash': {
      'icon': Icons.local_car_wash,
      'color': const Color(0xFF0CAF60),
      'bgColor': Color(0xFF0CAF60).withOpacity(0.1),
    },
    'House Cleaning': {
      'icon': Icons.cleaning_services,
      'color': Colors.blue,
      'bgColor': Colors.blue.withOpacity(0.1),
    },
    'Laundry': {
      'icon': Icons.local_laundry_service,
      'color': const Color(0xFF9C27B0),
      'bgColor': const Color(0xFF9C27B0).withOpacity(0.1),
    },
  };

  @override
  void initState() {
    super.initState();
    _loadWasherData();
  }

  Future<void> _loadWasherData() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.getCurrentUserId();
      
      if (userId == null) {
        print('❌ No user ID found in AuthService');
        setState(() {
          _isLoading = false;
          _hasApplied = false;
        });
        return;
      }

      print('✅ Loading washer data for user ID: $userId');

      final washerQuery = await FirebaseFirestore.instance
          .collection('washers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (washerQuery.docs.isEmpty) {
        print('❌ No washer found for user ID: $userId');
        setState(() {
          _isLoading = false;
          _hasApplied = false;
        });
        return;
      }

      final doc = washerQuery.docs.first;
      final data = doc.data();
      _washerId = doc.id;
      
      // ============================================================
      // STORE ALL WASHER DATA
      // ============================================================
      _washerData = data;
      
      // Build selected services list
      List<String> serviceCategories = List<String>.from(data['serviceCategories'] ?? []);
      List<Map<String, dynamic>> services = [];
      for (var category in serviceCategories) {
        if (_serviceDetails.containsKey(category)) {
          services.add({
            'name': category,
            'icon': _serviceDetails[category]!['icon'],
            'color': _serviceDetails[category]!['color'],
            'bgColor': _serviceDetails[category]!['bgColor'],
          });
        }
      }
      
      setState(() {
        _hasApplied = true;
        _isApproved = data['approved'] ?? false;
        _washerStatus = _isApproved ? 'approved' : 'pending';
        _isOnline = data['isOnline'] ?? false;
        _selectedServices = services;
        _washerStats = {
          'todayEarnings': data['todayEarnings'] ?? 0,
          'totalJobs': data['totalJobs'] ?? 0,
          'rating': data['rating'] ?? 0.0,
          'totalEarnings': data['totalEarnings'] ?? 0,
          'pendingJobs': data['pendingJobs'] ?? 0,
        };
        _isLoading = false;
      });

      print('✅ Washer data loaded: $_washerId');

      // Listen to real-time updates
      FirebaseFirestore.instance
          .collection('washers')
          .doc(_washerId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists) {
          final newData = snapshot.data()!;
          _washerData = newData; // Update stored data
          
          List<String> newCategories = List<String>.from(newData['serviceCategories'] ?? []);
          List<Map<String, dynamic>> newServices = [];
          for (var category in newCategories) {
            if (_serviceDetails.containsKey(category)) {
              newServices.add({
                'name': category,
                'icon': _serviceDetails[category]!['icon'],
                'color': _serviceDetails[category]!['color'],
                'bgColor': _serviceDetails[category]!['bgColor'],
              });
            }
          }
          
          setState(() {
            _isOnline = newData['isOnline'] ?? false;
            _isApproved = newData['approved'] ?? false;
            _selectedServices = newServices;
            _washerStats = {
              'todayEarnings': newData['todayEarnings'] ?? 0,
              'totalJobs': newData['totalJobs'] ?? 0,
              'rating': newData['rating'] ?? 0.0,
              'totalEarnings': newData['totalEarnings'] ?? 0,
              'pendingJobs': newData['pendingJobs'] ?? 0,
            };
          });
        }
      });

    } catch (e) {
      print('❌ Error loading washer data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);

    try {
      await FirebaseFirestore.instance
          .collection('washers')
          .doc(_washerId)
          .update({
        'isOnline': value,
        'lastOnlineUpdate': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '✅ You are now online' : 'You are now offline'),
          backgroundColor: value ? AppColors.success : AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('❌ Error updating online status: $e');
      setState(() => _isOnline = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _goToRegistration() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WasherRegistrationScreen()),
    );
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
        content: Text(content),
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
    final washerName = authService.userName ?? 'Washer';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasApplied) {
      return _buildApplyScreen();
    }

    if (!_isApproved) {
      return _buildPendingApprovalScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Washer Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWasherData,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => setState(() => _currentIndex = 2),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(washerName),
          const JobRequestScreen(),
          const WasherProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildApplyScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Service Provider',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_transportation,
                  size: 60,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Become a Service Provider',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Join our network of professional service providers and start earning.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text('💰 Earn up to ₦50,000/week'),
                    SizedBox(height: 8),
                    Text('✅ Flexible working hours'),
                    SizedBox(height: 8),
                    Text('🚗 Get matched with customers near you'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _goToRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Now',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingApprovalScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Service Provider',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pending_actions,
                  size: 60,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Application Pending Review',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your application has been submitted successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our team will review your application and notify you once approved.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Text(
                      '⏳ Estimated review time: 24-48 hours',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You will be notified via email once approved.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.home),
                label: const Text('Back to Home'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(String washerName) {
    return RefreshIndicator(
      onRefresh: _loadWasherData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hello,',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    washerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ready to work today?',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  // Online/Offline Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isOnline ? Icons.wifi : Icons.wifi_off,
                              color: _isOnline ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                color: _isOnline ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isOnline,
                          onChanged: _toggleOnlineStatus,
                          activeColor: Colors.green,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Services Section
            if (_selectedServices.isNotEmpty) ...[
              const Text(
                'Your Services',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedServices.length,
                  itemBuilder: (context, index) {
                    final service = _selectedServices[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: service['bgColor'],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: service['color'],
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            service['icon'],
                            color: service['color'],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            service['name'],
                            style: TextStyle(
                              color: service['color'],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stats Cards - REAL DATA
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today\'s Earnings',
                    '₦${NumberFormat('#,###').format(_washerStats['todayEarnings'])}',
                    Icons.money,
                    AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Jobs',
                    '${_washerStats['totalJobs']}',
                    Icons.work,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Rating',
                    '${_washerStats['rating'].toStringAsFixed(1)} ★',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending Jobs',
                    '${_washerStats['pendingJobs']}',
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Quick Actions - ALL WORKING
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'View Earnings',
                    Icons.money,
                    Colors.green,
                    () => setState(() => _currentIndex = 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'My Profile',
                    Icons.person,
                    Colors.blue,
                    () => setState(() => _currentIndex = 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Subscription Info',
                    Icons.subscriptions,
                    Colors.purple,
                    () {
                      final subValid = _washerData['subscriptionValidUntil'];
                      if (subValid != null) {
                        final date = (subValid as Timestamp).toDate();
                        _showInfoDialog(
                          'Subscription Status',
                          'Subscription valid until: ${DateFormat('MMM dd, yyyy').format(date)}',
                        );
                      } else {
                        _showInfoDialog('Subscription', 'No active subscription');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Support',
                    Icons.support_agent,
                    Colors.orange,
                    () {
                      _showInfoDialog(
                        'Support',
                        'Email: support@gwashng.com\nPhone: +234 800 000 0000\n\nAvailable 24/7',
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Recent Jobs - REAL DATA
            const Text(
              'Recent Jobs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildRecentJobs(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentJobs() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('jobs')
          .where('washerId', isEqualTo: _washerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No jobs yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final rawDocs = snapshot.data?.docs ?? [];
        final jobs = List<QueryDocumentSnapshot>.from(rawDocs);
        jobs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = aData?['createdAt'] as Timestamp?;
          final bTime = bData?['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (jobs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'No jobs yet',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            final job = jobs[index].data() as Map<String, dynamic>;
            final status = job['status'] ?? 'pending';
            final statusColor = status == 'completed' ? Colors.green :
                               status == 'assigned' ? Colors.blue :
                               status == 'enRoute' ? Colors.orange :
                               Colors.grey;
            
            return GestureDetector(
              onTap: () {
                _showInfoDialog(
                  'Job Details',
                  'Service: ${job['serviceName'] ?? 'N/A'}\n'
                  'Price: ₦${NumberFormat('#,###').format(job['price'] ?? 0)}\n'
                  'Location: ${job['location'] ?? 'N/A'}\n'
                  'Status: $status\n'
                  'Customer: ${job['customerName'] ?? 'N/A'}',
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['serviceName'] ?? 'Service',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '₦${NumberFormat('#,###').format(job['price'] ?? 0)} · ${job['location'] ?? ''}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}