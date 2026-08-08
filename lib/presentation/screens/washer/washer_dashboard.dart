import 'dart:async';
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
import 'incoming_job_dialog.dart';
import '../../../services/app_notification_service.dart';

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
  StreamSubscription<QuerySnapshot>? _jobsSubscription;
  
  Map<String, dynamic> _washerData = {};
  List<Map<String, dynamic>> _selectedServices = [];
  
  Map<String, dynamic> _washerStats = {
    'todayEarnings': 0,
    'totalJobs': 0,
    'rating': 4.8,
    'totalEarnings': 0,
    'pendingJobs': 0,
  };

  final Map<String, Map<String, dynamic>> _serviceDetails = {
    'Car Wash': {
      'icon': Icons.local_car_wash,
      'color': const Color(0xFF0CAF60),
      'bgColor': const Color(0xFF0CAF60).withOpacity(0.1),
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
    'Ride Service': {
      'icon': Icons.directions_car,
      'color': Colors.orange,
      'bgColor': Colors.orange.withOpacity(0.1),
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
      
      if (userId == null || userId.isEmpty) {
        print('❌ No user ID found in AuthService');
        setState(() {
          _isLoading = false;
          _hasApplied = false;
        });
        return;
      }

      print('✅ Loading washer data for user ID: $userId');

      // 1. Query washers by userId field
      final washerQuery = await FirebaseFirestore.instance
          .collection('washers')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      DocumentSnapshot<Map<String, dynamic>>? targetDoc;

      if (washerQuery.docs.isNotEmpty) {
        targetDoc = washerQuery.docs.first;
      } else {
        // 2. Direct document ID lookup
        final directDoc = await FirebaseFirestore.instance
            .collection('washers')
            .doc(userId)
            .get();
        if (directDoc.exists) {
          targetDoc = directDoc;
        } else {
          // 3. Fallback: check users collection for washer role
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final uData = userDoc.data()!;
            final role = (uData['userRole'] ?? uData['role'] ?? '').toString().toLowerCase();
            if (role == 'washer' || role == 'provider' || uData['serviceCategory'] != null) {
              // Auto-initialize washer doc
              await FirebaseFirestore.instance.collection('washers').doc(userId).set({
                'userId': userId,
                'name': uData['fullName'] ?? uData['userName'] ?? 'Service Provider',
                'email': uData['email'] ?? '',
                'phone': uData['phone'] ?? uData['phoneNumber'] ?? '',
                'approved': true,
                'isOnline': true,
                'rating': 4.8,
                'totalJobs': 0,
                'totalEarnings': 0,
                'todayEarnings': 0,
                'serviceCategory': uData['serviceCategory'] ?? 'Car Wash',
                'serviceCategories': [uData['serviceCategory'] ?? 'Car Wash'],
                'createdAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              targetDoc = await FirebaseFirestore.instance.collection('washers').doc(userId).get();
            }
          }
        }
      }

      if (targetDoc == null || !targetDoc.exists) {
        print('❌ No washer profile found for user ID: $userId');
        setState(() {
          _isLoading = false;
          _hasApplied = false;
        });
        return;
      }

      final doc = targetDoc;
      final data = doc.data()!;
      _washerId = doc.id;
      _washerData = data;
      
      List<String> serviceCategories = List<String>.from(
        data['serviceCategories'] ?? (data['serviceCategory'] != null ? [data['serviceCategory']] : ['Car Wash']),
      );
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
        _isApproved = data['approved'] ?? true; // Default to true if record exists
        _washerStatus = _isApproved ? 'approved' : 'pending';
        _isOnline = data['isOnline'] ?? true;
        _selectedServices = services.isNotEmpty ? services : [
          {
            'name': 'Car Wash',
            'icon': Icons.local_car_wash,
            'color': const Color(0xFF0CAF60),
            'bgColor': const Color(0xFF0CAF60).withOpacity(0.1),
          }
        ];
        _washerStats = {
          'todayEarnings': data['todayEarnings'] ?? 0,
          'totalJobs': data['totalJobs'] ?? 0,
          'rating': data['rating'] ?? 4.8,
          'totalEarnings': data['totalEarnings'] ?? 0,
          'pendingJobs': data['pendingJobs'] ?? 0,
        };
        _isLoading = false;
      });

      print('✅ Washer data loaded: $_washerId');

      // Listen to real-time washer doc updates
      FirebaseFirestore.instance
          .collection('washers')
          .doc(_washerId)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          final newData = snapshot.data()!;
          _washerData = newData;
          
          List<String> newCategories = List<String>.from(
            newData['serviceCategories'] ?? (newData['serviceCategory'] != null ? [newData['serviceCategory']] : ['Car Wash']),
          );
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
            _isApproved = newData['approved'] ?? true;
            _selectedServices = newServices;
          });
        }
      });

      // Save FCM Token for instant Push Notifications
      AppNotificationService().updateUserFCMToken(_washerId, isWasher: true);

      // Listen to real-time jobs for dynamic stats calculation & incoming popups
      _listenToRealtimeJobs(_washerId);

    } catch (e) {
      print('❌ Error loading washer data: $e');
      setState(() => _isLoading = false);
    }
  }

  String? _activePromptJobId;

  void _listenToRealtimeJobs(String washerId) {
    _jobsSubscription?.cancel();
    _jobsSubscription = FirebaseFirestore.instance
        .collection('jobs')
        .where('washerId', isEqualTo: washerId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      int todayEarnings = 0;
      int totalEarnings = 0;
      int totalJobs = 0;
      int pendingJobs = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      Map<String, dynamic>? pendingJobToPrompt;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final paymentStatus = (data['paymentStatus'] ?? '').toString().toLowerCase();
        final price = (data['price'] ?? 0) as num;
        final washerShare = (data['providerShare'] != null && data['providerShare'] is num)
            ? (data['providerShare'] as num).round()
            : (price * 0.95).round(); // 95% washer share

        // Check for incoming pending job request to prompt washer in real-time
        if ((status == 'pending_acceptance' || (status == 'assigned' && data['acceptedAt'] == null)) && _isOnline) {
          pendingJobToPrompt = {'id': doc.id, ...data};
        }

        // STRICT CHECK: Money only counts if paymentStatus is 'paid'
        if ((status == 'completed' || status == 'paid') && paymentStatus == 'paid') {
          totalJobs++;
          totalEarnings += washerShare;

          DateTime? jobDate;
          if (data['completedAt'] != null && data['completedAt'] is Timestamp) {
            jobDate = (data['completedAt'] as Timestamp).toDate();
          } else if (data['paidAt'] != null && data['paidAt'] is Timestamp) {
            jobDate = (data['paidAt'] as Timestamp).toDate();
          } else if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
            jobDate = (data['createdAt'] as Timestamp).toDate();
          }

          if (jobDate != null && jobDate.isAfter(todayStart)) {
            todayEarnings += washerShare;
          }
        } else if (status == 'assigned' || status == 'pending' || status == 'in_progress' || status == 'accepted' || status == 'pending_acceptance') {
          pendingJobs++;
        }
      }

      final dynamic rawBalance = _washerData['availableBalance'] ?? _washerData['balance'];
      final int availableBalance = rawBalance != null && rawBalance is num ? rawBalance.toInt() : 0;

      setState(() {
        _washerStats = {
          'todayEarnings': todayEarnings,
          'totalJobs': totalJobs,
          'rating': _washerData['rating'] ?? 4.8,
          'totalEarnings': totalEarnings,
          'pendingJobs': pendingJobs,
          'availableBalance': availableBalance,
        };
      });

      // ⚡ POP INSTANT INCOMING JOB DIALOG OVERLAY (Duolingo/Uber style)
      if (pendingJobToPrompt != null && _activePromptJobId != pendingJobToPrompt['id']) {
        _activePromptJobId = pendingJobToPrompt['id'];
        _showIncomingJobOverlay(pendingJobToPrompt);
      }
    });
  }

  void _showIncomingJobOverlay(Map<String, dynamic> job) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IncomingJobDialog(
        job: job,
        washerId: _washerId,
        onAccepted: () {
          _activePromptJobId = null;
        },
        onDeclined: () {
          _activePromptJobId = null;
        },
      ),
    ).then((_) {
      _activePromptJobId = null;
    });
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }

  void _showWithdrawDialog() {
    final double availableBalance = ((_washerStats['availableBalance'] ?? _washerStats['totalEarnings'] ?? 0) as num).toDouble();
    final String washerName = _washerData['name'] ?? 'Service Provider';

    final TextEditingController amountCtrl = TextEditingController(text: availableBalance > 0 ? availableBalance.toInt().toString() : '0');
    final TextEditingController accountNumCtrl = TextEditingController(text: (_washerData['accountNumber'] ?? '').toString());
    final TextEditingController accountNameCtrl = TextEditingController(text: (_washerData['accountName'] ?? washerName).toString());
    String selectedBank = (_washerData['bankName'] ?? 'GTBank').toString();

    final List<String> banks = [
      'GTBank', 'Access Bank', 'Zenith Bank', 'First Bank', 'UBA', 'Kuda Bank', 'OPay', 'PalmPay', 'Moniepoint', 'Stanbic IBTC', 'Wema Bank'
    ];

    if (!banks.contains(selectedBank)) {
      selectedBank = 'GTBank';
    }

    bool isSubmitting = false;
    String? withdrawError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Withdraw Earnings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Available: ₦${NumberFormat('#,###').format(availableBalance)}', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Withdrawal Amount (₦)',
                    prefixText: '₦ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedBank,
                  decoration: const InputDecoration(labelText: 'Select Bank', border: OutlineInputBorder()),
                  items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedBank = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNumCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Account Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (withdrawError != null) ...[
                  const SizedBox(height: 8),
                  Text(withdrawError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final int? amount = int.tryParse(amountCtrl.text.trim());
                            final String accNum = accountNumCtrl.text.trim();
                            final String accName = accountNameCtrl.text.trim();

                            if (amount == null || amount < 1000) {
                              setModalState(() => withdrawError = 'Minimum withdrawal amount is ₦1,000');
                              return;
                            }
                            if (amount > availableBalance && availableBalance > 0) {
                              setModalState(() => withdrawError = 'Amount exceeds available balance');
                              return;
                            }
                            if (accNum.length < 10) {
                              setModalState(() => withdrawError = 'Please enter valid 10-digit account number');
                              return;
                            }

                            setModalState(() {
                              isSubmitting = true;
                              withdrawError = null;
                            });

                            try {
                              // Save withdrawal request in Firestore
                              await FirebaseFirestore.instance.collection('withdrawals').add({
                                'washerId': _washerId,
                                'washerName': washerName,
                                'amount': amount,
                                'bankName': selectedBank,
                                'accountNumber': accNum,
                                'accountName': accName,
                                'status': 'processing',
                                'reference': 'GWASH-WD-${DateTime.now().millisecondsSinceEpoch}',
                                'createdAt': FieldValue.serverTimestamp(),
                              });

                              // Deduct from available balance in washers collection
                              await FirebaseFirestore.instance.collection('washers').doc(_washerId).set({
                                'availableBalance': FieldValue.increment(-amount),
                                'bankName': selectedBank,
                                'accountNumber': accNum,
                                'accountName': accName,
                              }, SetOptions(merge: true));

                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Withdrawal of ₦${NumberFormat('#,###').format(amount)} initiated to $selectedBank!'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              setModalState(() {
                                isSubmitting = false;
                                withdrawError = 'Error processing withdrawal: $e';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Withdraw Funds via Paystack Payout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleOnlineStatus(bool value) async {
    setState(() => _isOnline = value);

    try {
      if (_washerId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('washers')
            .doc(_washerId)
            .set({
          'isOnline': value,
          'lastOnlineUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

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
    final washerName = authService.userName ?? _washerData['name'] ?? 'Washer';

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
            onPressed: () => setState(() => _currentIndex = 3),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(washerName),
          const JobRequestScreen(),
          const EarningsScreen(),
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
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Earnings'),
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
                    'Withdraw Funds',
                    Icons.account_balance_wallet,
                    AppColors.primary,
                    _showWithdrawDialog,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'View Earnings',
                    Icons.payments,
                    Colors.green,
                    () => setState(() => _currentIndex = 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'My Profile',
                    Icons.person,
                    Colors.blue,
                    () => setState(() => _currentIndex = 2),
                  ),
                ),
                const SizedBox(width: 12),
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