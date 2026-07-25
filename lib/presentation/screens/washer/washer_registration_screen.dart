// lib/presentation/screens/washer/washer_registration_screen.dart
// PURPOSE: Complete washer registration form with Firebase integration
// FIXED: Uses AuthService userId instead of FirebaseAuth.currentUser
// FIXED: Navigation clears stack and goes to Washer Dashboard

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import 'washer_dashboard.dart';
import '../auth/login_screen.dart';

class WasherRegistrationScreen extends StatefulWidget {
  const WasherRegistrationScreen({super.key});

  @override
  State<WasherRegistrationScreen> createState() => _WasherRegistrationScreenState();
}

class _WasherRegistrationScreenState extends State<WasherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  
  // Service Type Selection
  final List<Map<String, dynamic>> _availableServices = [
    {'id': 'car_wash', 'name': 'Car Washer', 'icon': Icons.local_car_wash, 'category': 'Car Wash'},
    {'id': 'cleaning', 'name': 'Cleaner', 'icon': Icons.cleaning_services, 'category': 'House Cleaning'},
    {'id': 'laundry', 'name': 'Laundry', 'icon': Icons.local_laundry_service, 'category': 'Laundry'},
  ];
  
  List<String> _selectedServices = [];
  String _selectedVehicleType = 'Motorcycle';
  double _workingRadius = 10;
  String _selectedBank = 'Access Bank';
  
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  
  final List<String> _vehicleTypes = ['Motorcycle', 'Car', 'Van', 'Truck', 'SUV', 'Bicycle'];
  final List<String> _banks = [
    'Access Bank', 'GTBank', 'First Bank', 'UBA', 'Zenith Bank',
    'Union Bank', 'Fidelity Bank', 'Ecobank', 'Stanbic IBTC', 'Polaris Bank',
    'Sterling Bank', 'Wema Bank', 'Heritage Bank', 'Keystone Bank'
  ];

  void _toggleService(String serviceId) {
    setState(() {
      if (_selectedServices.contains(serviceId)) {
        _selectedServices.remove(serviceId);
      } else {
        _selectedServices.add(serviceId);
      }
    });
  }

  Future<void> _registerWasher() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }
    
    if (_selectedServices.isEmpty) {
      _showError('Please select at least one service type');
      return;
    }
    
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Step 1: Create account (signup)
      final signupSuccess = await authService.signup(
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _passwordController.text.trim(),
        role: 'washer',
      );

      if (!signupSuccess) {
        _showError('Account creation failed. Phone number may already exist.');
        setState(() => _isLoading = false);
        return;
      }
      
      // Step 2: Get userId from AuthService (NOT FirebaseAuth)
      final userId = authService.getCurrentUserId();
      if (userId == null) {
        _showError('User not found. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      print('✅ User ID from AuthService: $userId');

      // Build service categories list
      List<String> serviceCategories = [];
      for (var service in _availableServices) {
        if (_selectedServices.contains(service['id'])) {
          serviceCategories.add(service['category']);
        }
      }

      // Save washer data to WASHERS collection
      final washerData = {
        'userId': userId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'selectedServices': _selectedServices,
        'serviceCategories': serviceCategories,
        'vehicleType': _selectedVehicleType,
        'workingRadius': _workingRadius.toInt(),
        'bankName': _selectedBank,
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'isOnline': true,
        'approved': true,
        'rating': 0.0,
        'totalJobs': 0,
        'totalEarnings': 0,
        'pendingJobs': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final washerRef = await FirebaseFirestore.instance
          .collection('washers')
          .add(washerData);

      print('✅ Washer saved to Firestore with ID: ${washerRef.id}');
      
      // Update user role in users collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'role': 'washer',
        'washerId': washerRef.id,
        'serviceCategories': serviceCategories,
        'selectedServices': _selectedServices,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User role updated to "washer" in users collection');
      
      // Reload AuthService and refresh from Firestore
      await authService.reloadUserData();
      await authService.refreshUserData();
      
      // Small delay to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Washer account created! You are now online.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        
        // ============================================================
        // FIXED: Clear the entire navigation stack and go to Washer Dashboard
        // ============================================================
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WasherDashboard()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');
      _showError(e.toString());
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Become a Service Provider',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Creating your account...',
                    style: TextStyle(color: AppColors.grey600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.emoji_transportation, size: 60, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text(
                            'Join Our Network',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Start earning by providing services',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // ============================================================
                    // NEW: "Already a Washer?" Login Section
                    // ============================================================
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Already a Service Provider?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Login to your washer account',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            ),
                            child: const Text('Login'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Service Type Selection
                    const Text(
                      'Select Services (Choose one or more)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You will receive jobs for all selected services',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: _availableServices.map((service) {
                        final isSelected = _selectedServices.contains(service['id']);
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => _toggleService(service['id']),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(service['icon'], 
                                      color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                      size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    service['name'],
                                    style: TextStyle(
                                      color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    
                    // Personal Information
                    const Text(
                      'Personal Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: Icon(Icons.person, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number *',
                        prefixText: '+234 ',
                        prefixIcon: Icon(Icons.phone, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter phone number' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: Icon(Icons.email, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter email' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'City *',
                              prefixIcon: Icon(Icons.location_city, color: AppColors.primary),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Enter city' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'State *',
                              prefixIcon: Icon(Icons.map, color: AppColors.primary),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: AppColors.primary, width: 2),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty ? 'Enter state' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Enter password';
                        if (value.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: Icon(Icons.lock_outline, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Vehicle Information
                    const Text(
                      'Vehicle Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField(
                      value: _selectedVehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type *',
                        prefixIcon: Icon(Icons.directions_car, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      items: _vehicleTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedVehicleType = value!),
                      validator: (value) => value == null ? 'Select vehicle type' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    const Text('Working Radius (km)'),
                    Slider(
                      value: _workingRadius,
                      min: 5,
                      max: 20,
                      divisions: 15,
                      label: '${_workingRadius.toInt()} km',
                      onChanged: (value) => setState(() => _workingRadius = value),
                      activeColor: AppColors.primary,
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'You will serve customers within ${_workingRadius.toInt()} km radius',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Bank Information
                    const Text(
                      'Bank Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField(
                      value: _selectedBank,
                      decoration: const InputDecoration(
                        labelText: 'Select Bank *',
                        prefixIcon: Icon(Icons.account_balance, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      items: _banks.map((bank) => DropdownMenuItem(
                        value: bank,
                        child: Text(bank),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedBank = value!),
                      validator: (value) => value == null ? 'Select bank' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Account Number *',
                        prefixIcon: Icon(Icons.numbers, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter account number' : null,
                    ),
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _accountNameController,
                      decoration: const InputDecoration(
                        labelText: 'Account Name *',
                        prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Enter account name' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    // Terms
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) => setState(() => _agreeToTerms = value!),
                          activeColor: AppColors.primary,
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: const Text(
                              'I agree to the Terms of Service and Privacy Policy',
                              style: TextStyle(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _registerWasher,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _selectedServices.isEmpty 
                              ? 'Select a Service First'
                              : 'Create Account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Info Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedServices.isEmpty
                                  ? 'Please select at least one service to get started'
                                  : 'Your account will be activated immediately',
                              style: TextStyle(
                                color: _selectedServices.isEmpty ? Colors.orange.shade700 : Colors.green.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Terms of Service',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'G Wash NG Terms\n\n',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                '1. You must be at least 18 years old\n'
                '2. You must have a valid means of transport\n'
                '3. You agree to a background check\n'
                '4. 15% commission on each job\n'
                '5. You must maintain 4.0+ rating\n'
                '6. Cancellation policy applies\n'
                '7. Payments are processed weekly\n'
                '8. You are an independent contractor\n'
                '9. G Wash NG reserves the right to suspend accounts\n\n'
                'By registering, you agree to all terms.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
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
}