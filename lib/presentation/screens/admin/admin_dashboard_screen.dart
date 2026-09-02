// lib/presentation/screens/admin/admin_dashboard_screen.dart
// PURPOSE: Complete Admin Dashboard for G Wash NG - Full control over users, washers, jobs, and system settings

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/admin_service.dart';
import 'admin_transactions_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  
  // Statistics
  int _totalUsers = 0;
  int _totalWashers = 0;
  int _totalJobs = 0;
  int _totalRevenue = 0;
  double _totalPlatformRevenue = 0.0;
  double _totalWasherPayouts = 0.0;
  int _pendingWashers = 0;
  int _activeJobs = 0;
  int _completedJobs = 0;

  final AdminService _adminService = AdminService();
  
  // Settings Controllers
  final TextEditingController _commissionController = TextEditingController(text: '5');
  final TextEditingController _radiusController = TextEditingController(text: '15');
  final TextEditingController _subscriptionPriceController = TextEditingController(text: '5000');
  final TextEditingController _minWithdrawalController = TextEditingController(text: '10000');
  final TextEditingController _maxDistanceController = TextEditingController(text: '20');
  final TextEditingController _bookingFeeController = TextEditingController(text: '100');
  final TextEditingController _cancellationFeeController = TextEditingController(text: '500');
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadSettings();
  }
  
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    try {
      final stats = await _adminService.getDashboardStats();
      setState(() {
        _totalUsers = stats['totalUsers'] ?? 0;
        _totalWashers = stats['totalWashers'] ?? 0;
        _totalJobs = stats['totalJobs'] ?? 0;
        _totalRevenue = stats['totalRevenue'] ?? 0;
        _totalPlatformRevenue = (stats['totalPlatformRevenue'] ?? 0.0).toDouble();
        _totalWasherPayouts = (stats['totalWasherPayouts'] ?? 0.0).toDouble();
        _pendingWashers = stats['pendingWashers'] ?? 0;
        _activeJobs = stats['activeJobs'] ?? 0;
        _completedJobs = stats['completedJobs'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load dashboard data: $e');
    }
  }
  
  Future<void> _loadSettings() async {
    try {
      final settings = await _adminService.getSettings();
      if (settings != null) {
        _commissionController.text = settings['commissionRate']?.toString() ?? '10';
        _radiusController.text = settings['radiusLimit']?.toString() ?? '15';
        _subscriptionPriceController.text = settings['subscriptionPrice']?.toString() ?? '5000';
        _minWithdrawalController.text = settings['minWithdrawal']?.toString() ?? '10000';
        _maxDistanceController.text = settings['maxDistance']?.toString() ?? '20';
        _bookingFeeController.text = settings['bookingFee']?.toString() ?? '100';
        _cancellationFeeController.text = settings['cancellationFee']?.toString() ?? '500';
      }
    } catch (e) {
      // Silently fail - settings will use defaults
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  void _navigateToUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminUsersScreen()),
    );
  }
  
  void _navigateToWashers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminWashersScreen()),
    );
  }
  
  void _navigateToJobs() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminJobsScreen()),
    );
  }
  
  void _showFullSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'System Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== GENERAL SETTINGS ====================
                      const Text(
                        'General Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _commissionController,
                        label: 'Commission Rate (%)',
                        icon: Icons.percent,
                        helperText: 'Percentage taken from each job',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _radiusController,
                        label: 'Service Radius Limit (km)',
                        icon: Icons.radar,
                        helperText: 'Maximum distance for service matching',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _maxDistanceController,
                        label: 'Max Distance (km)',
                        icon: Icons.straighten,
                        helperText: 'Maximum distance a washer can travel',
                      ),
                      const SizedBox(height: 20),
                      
                      // ==================== PAYMENT SETTINGS ====================
                      const Text(
                        'Payment Settings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _subscriptionPriceController,
                        label: 'Subscription Price (₦)',
                        icon: Icons.subscriptions,
                        helperText: 'Monthly subscription fee for washers',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _minWithdrawalController,
                        label: 'Minimum Withdrawal (₦)',
                        icon: Icons.money_off,
                        helperText: 'Minimum amount a washer can withdraw',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _bookingFeeController,
                        label: 'Booking Fee (₦)',
                        icon: Icons.receipt,
                        helperText: 'Fee charged per booking',
                      ),
                      const SizedBox(height: 12),
                      _buildSettingsTextField(
                        controller: _cancellationFeeController,
                        label: 'Cancellation Fee (₦)',
                        icon: Icons.cancel,
                        helperText: 'Fee charged for cancellation',
                      ),
                      const SizedBox(height: 20),
                      
                      // ==================== PRICING ARCHITECTURE ====================
                      const Text(
                        'Service Pricing Architecture',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Provider Custom Pricing Model',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Service providers set their own custom prices directly during onboarding and within their profile dashboard. The exact prices set by each provider are displayed live to clients when selecting a nearby professional.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // ==================== SAVE BUTTONS ====================
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
                              onPressed: _saveAllSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Save All Settings'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: const OutlineInputBorder(),
        helperText: helperText,
        helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      keyboardType: TextInputType.number,
    );
  }
  
  Future<void> _saveAllSettings() async {
    try {
      await _adminService.updateSettings({
        'commissionRate': double.tryParse(_commissionController.text) ?? 10.0,
        'radiusLimit': double.tryParse(_radiusController.text) ?? 15.0,
        'subscriptionPrice': int.tryParse(_subscriptionPriceController.text) ?? 5000,
        'minWithdrawal': int.tryParse(_minWithdrawalController.text) ?? 10000,
        'maxDistance': double.tryParse(_maxDistanceController.text) ?? 20.0,
        'bookingFee': int.tryParse(_bookingFeeController.text) ?? 100,
        'cancellationFee': int.tryParse(_cancellationFeeController.text) ?? 500,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      Navigator.pop(context);
      _showSuccessSnackBar('All settings saved successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save settings: $e');
    }
  }
  
  Future<void> _resetTestRevenueData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purge All Test Data & Reset Database'),
        content: const Text(
          'This will delete all test jobs, test payments, test transactions, and test accounts from the database, leaving only the Master Admin account and resetting all revenue counters to ₦0. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Purge All & Reset to ₦0'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _adminService.clearTestRevenueData();
        await _loadDashboardData();
        _showSuccessSnackBar('✅ Test revenue cleared! Counters reset to ₦0.');
      } catch (e) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error resetting test data: $e');
      }
    }
  }

  void _signOut() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text(
          'G Wash Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _loadDashboardData();
              _showSuccessSnackBar('Fetching latest real-time data...');
            },
            tooltip: 'Refresh Real Data',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showFullSettingsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                _buildDashboardTab(),
                const AdminUsersScreen(),
                const AdminWashersScreen(),
                const AdminJobsScreen(),
                const AdminTransactionsScreen(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) _loadDashboardData();
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey600,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_transportation), label: 'Washers'),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Financials'),
        ],
      ),
    );
  }
  
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, Admin!',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Here\'s what\'s happening on G Wash NG today',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildQuickStat('Active Jobs', _activeJobs.toString(), Icons.work),
                    const SizedBox(width: 12),
                    _buildQuickStat('Pending', _pendingWashers.toString(), Icons.pending),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Stats Grid
          const Text(
            'Overview',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard('Admin 5% Revenue', '₦${NumberFormat('#,###').format(_totalPlatformRevenue)}', Icons.pie_chart, Colors.purple),
              _buildStatCard('Washer 95% Share', '₦${NumberFormat('#,###').format(_totalWasherPayouts)}', Icons.savings, Colors.teal),
              _buildStatCard('Gross Volume', '₦${NumberFormat('#,###').format(_totalRevenue)}', Icons.payments, Colors.indigo),
              _buildStatCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
              _buildStatCard('Total Washers', _totalWashers.toString(), Icons.emoji_transportation, Colors.green),
              _buildStatCard('Total Jobs', _totalJobs.toString(), Icons.bookmark, Colors.orange),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Manage Users',
                  Icons.people,
                  'View and manage all users',
                  Colors.blue,
                  _navigateToUsers,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Manage Washers',
                  Icons.emoji_transportation,
                  'Approve or reject washers',
                  Colors.green,
                  _navigateToWashers,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'View Jobs',
                  Icons.bookmark,
                  'Monitor all service jobs',
                  Colors.orange,
                  _navigateToJobs,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'System Settings',
                  Icons.settings,
                  'Configure all system settings',
                  Colors.purple,
                  _showFullSettingsDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
  
  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(label, style: TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
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
          BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: AppColors.grey600, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    String description,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text(description, style: TextStyle(color: AppColors.grey600, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN USERS SCREEN - WITH DELETE FUNCTIONALITY
// ============================================================
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _adminService.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleBlockUser(String userId, bool isBlocked) async {
    try {
      await _adminService.toggleBlockUser(userId, !isBlocked);
      setState(() {
        final index = _users.indexWhere((u) => u['id'] == userId);
        if (index != -1) {
          _users[index]['isBlocked'] = !isBlocked;
        }
      });
      _showSnackBar(isBlocked ? 'User unblocked' : 'User blocked');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  bool _isAdminUser(Map<String, dynamic> user) {
    final role = (user['role'] ?? '').toString().toLowerCase();
    final email = (user['email'] ?? '').toString().toLowerCase();
    return role == 'admin' || email.contains('gwashng@gmail.com');
  }

  Future<void> _deleteUser(String userId, Map<String, dynamic> user) async {
    // 🔒 Protect the admin account — cannot be deleted
    if (_isAdminUser(user)) {
      _showSnackBar('The G Wash Admin account cannot be deleted.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure you want to delete this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _adminService.deleteUser(userId);
        setState(() {
          _users.removeWhere((u) => u['id'] == userId);
        });
        _showSnackBar('User deleted successfully');
      } catch (e) {
        _showSnackBar('Error deleting user: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    return _users.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
      final phone = (user['phone'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredUsers.isEmpty
              ? _buildEmptyState('No users found', Icons.people)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    return _buildUserCard(user);
                  },
                ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            (user['name'] ?? 'U')[0].toUpperCase(),
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
        title: Text(user['name'] ?? 'Unknown'),
        subtitle: Text(user['phone'] ?? 'No phone'),
        trailing: _isAdminUser(user)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Protected', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user['isBlocked'] ?? false ? Colors.red : Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user['isBlocked'] ?? false ? 'Blocked' : 'Active',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                user['isBlocked'] ?? false ? Icons.block : Icons.block_flipped,
                color: user['isBlocked'] ?? false ? Colors.red : Colors.green,
                size: 20,
              ),
              onPressed: () => _toggleBlockUser(user['id'], user['isBlocked'] ?? false),
              tooltip: user['isBlocked'] ?? false ? 'Unblock' : 'Block',
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () => _deleteUser(user['id'], user),
              tooltip: 'Delete User',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN WASHERS SCREEN - WITH DELETE AND EDIT
// ============================================================
class AdminWashersScreen extends StatefulWidget {
  const AdminWashersScreen({super.key});

  @override
  State<AdminWashersScreen> createState() => _AdminWashersScreenState();
}

class _AdminWashersScreenState extends State<AdminWashersScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _washers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWashers();
  }

  Future<void> _loadWashers() async {
    setState(() => _isLoading = true);
    try {
      final washers = await _adminService.getAllWashers();
      setState(() {
        _washers = washers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _approveWasher(String washerId) async {
    try {
      await _adminService.approveWasher(washerId);
      setState(() {
        final index = _washers.indexWhere((w) => w['id'] == washerId);
        if (index != -1) {
          _washers[index]['approved'] = true;
        }
      });
      _showSnackBar('Washer approved successfully!');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _rejectWasher(String washerId) async {
    try {
      await _adminService.rejectWasher(washerId);
      setState(() {
        _washers.removeWhere((w) => w['id'] == washerId);
      });
      _showSnackBar('Washer rejected');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _deleteWasher(String washerId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Washer'),
        content: const Text('Are you sure you want to delete this washer? This will remove all their data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        await _adminService.deleteWasher(washerId);
        setState(() {
          _washers.removeWhere((w) => w['id'] == washerId);
        });
        _showSnackBar('Washer deleted successfully');
      } catch (e) {
        _showSnackBar('Error deleting washer: $e', isError: true);
      }
    }
  }

  Future<void> _editWasher(Map<String, dynamic> washer) async {
    // Show edit dialog
    final nameController = TextEditingController(text: washer['name'] ?? '');
    final phoneController = TextEditingController(text: washer['phone'] ?? '');
    final cityController = TextEditingController(text: washer['city'] ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Washer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _adminService.updateWasher(washer['id'], {
                'name': nameController.text,
                'phone': phoneController.text,
                'city': cityController.text,
              });
              Navigator.pop(context);
              _loadWashers();
              _showSnackBar('Washer updated successfully');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredWashers {
    if (_searchQuery.isEmpty) return _washers;
    return _washers.where((washer) {
      final name = (washer['name'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Manage Washers'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search washers...',
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredWashers.isEmpty
              ? _buildEmptyState('No washers found', Icons.emoji_transportation)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredWashers.length,
                  itemBuilder: (context, index) {
                    final washer = _filteredWashers[index];
                    return _buildWasherCard(washer);
                  },
                ),
    );
  }

  Widget _buildWasherCard(Map<String, dynamic> washer) {
    final isApproved = washer['approved'] ?? false;
    final isOnline = washer['isOnline'] ?? false;
    final profileImage = washer['profileImage'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ✅ PROFILE IMAGE - DISPLAY FROM CLOUDINARY
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: ClipOval(
                    child: profileImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: profileImage,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                          )
                        : Container(
                            color: AppColors.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        washer['name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        washer['city'] ?? 'No location',
                        style: TextStyle(color: AppColors.grey600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOnline ? 'Online' : 'Offline',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                  onPressed: () => _editWasher(washer),
                  tooltip: 'Edit Washer',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _deleteWasher(washer['id']),
                  tooltip: 'Delete Washer',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (!isApproved) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _approveWasher(washer['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _rejectWasher(washer['id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                ] else ...[
                  Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Approved',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${washer['totalJobs'] ?? 0} jobs',
                    style: TextStyle(color: AppColors.grey600, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₦${NumberFormat('#,###').format(washer['totalEarnings'] ?? 0)}',
                    style: TextStyle(color: AppColors.grey600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ============================================================
// ADMIN JOBS SCREEN
// ============================================================
class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  final AdminService _adminService = AdminService();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Searching', 'Assigned', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    setState(() => _isLoading = true);
    try {
      final jobs = await _adminService.getAllJobs();
      setState(() {
        _jobs = jobs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredJobs {
    if (_selectedFilter == 'All') return _jobs;
    return _jobs.where((job) => job['status'] == _selectedFilter).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Searching': return Colors.orange;
      case 'Assigned': return Colors.blue;
      case 'Completed': return Colors.green;
      case 'Cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grey50,
      appBar: AppBar(
        title: const Text('Manage Jobs'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) => setState(() => _selectedFilter = filter),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredJobs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No jobs found'),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = _filteredJobs[index];
                    final jobId = job['id'] ?? '';
                    final displayId = jobId.length > 8 ? jobId.substring(0, 8) : jobId;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#$displayId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(job['status'] ?? 'Unknown'),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    job['status'] ?? 'Unknown',
                                    style: const TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(job['serviceName'] ?? 'Service', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '₦${NumberFormat('#,###').format(job['price'] ?? 0)}',
                              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(job['customerName'] ?? 'Customer', style: TextStyle(color: AppColors.grey600, fontSize: 12)),
                            Text(job['location'] ?? 'Location', style: TextStyle(color: AppColors.grey600, fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
