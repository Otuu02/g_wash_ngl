// lib/presentation/screens/washer/washer_registration_screen.dart
// PURPOSE: Complete washer registration form with Firebase integration

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/cloudinary_service.dart';
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
  
  // ============================================================
  // File Uploads - Profile Picture & ID (Cloudinary)
  // ============================================================
  File? _profileImage;
  File? _idImage;
  String _profileImageUrl = '';
  String _idImageUrl = '';
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _uploadError = '';
  double _uploadProgress = 0.0;
  
  // Track if images are uploaded successfully
  bool _profileUploaded = false;
  bool _idUploaded = false;

  // ============================================================
  // Service Price Controllers
  // ============================================================
  final Map<String, TextEditingController> _servicePriceControllers = {};
  
  // ============================================================
  // MAIN SERVICE CATEGORIES (4 Categories)
  // ============================================================
  final List<Map<String, dynamic>> _mainCategories = [
    {'id': 'car_wash', 'name': 'Car Wash', 'icon': Icons.local_car_wash, 'color': AppColors.primary},
    {'id': 'house_cleaning', 'name': 'House Cleaning', 'icon': Icons.cleaning_services, 'color': AppColors.primary},
    {'id': 'laundry', 'name': 'Laundry', 'icon': Icons.local_laundry_service, 'color': AppColors.primary},
    {'id': 'ride_service', 'name': 'Ride Service', 'icon': Icons.car_rental, 'color': AppColors.primary},
  ];
  
  // ============================================================
  // SUB-SERVICES FOR EACH MAIN CATEGORY
  // ============================================================
  final List<Map<String, dynamic>> _carWashSubServices = [
    {'id': 'exterior_wash', 'name': 'Exterior Wash', 'duration': '30 mins', 'icon': Icons.cleaning_services},
    {'id': 'interior_cleaning', 'name': 'Interior Cleaning', 'duration': '45 mins', 'icon': Icons.event_seat},
    {'id': 'full_detailing', 'name': 'Full Detailing', 'duration': '90 mins', 'icon': Icons.star},
    {'id': 'engine_wash', 'name': 'Engine Wash', 'duration': '60 mins', 'icon': Icons.settings},
  ];

  final List<Map<String, dynamic>> _houseCleaningSubServices = [
    {'id': 'standard_cleaning', 'name': 'Standard Cleaning', 'duration': '3 hours', 'icon': Icons.cleaning_services, 'bedrooms': '2-3 beds'},
    {'id': 'deep_cleaning', 'name': 'Deep Cleaning', 'duration': '5 hours', 'icon': Icons.brush, 'bedrooms': '3-4 beds'},
    {'id': 'move_in_out', 'name': 'Move In/Out', 'duration': '6 hours', 'icon': Icons.move_to_inbox, 'bedrooms': '4-5 beds'},
    {'id': 'office_cleaning', 'name': 'Office Cleaning', 'duration': '4 hours', 'icon': Icons.business, 'size': 'Small office'},
    {'id': 'carpet_cleaning', 'name': 'Carpet Cleaning', 'duration': '2 hours', 'icon': Icons.carpenter, 'rooms': 'Per room'},
    {'id': 'window_cleaning', 'name': 'Window Cleaning', 'duration': '1.5 hours', 'icon': Icons.window, 'floors': 'Per floor'},
  ];

  final List<Map<String, dynamic>> _laundrySubServices = [
    {'id': 'wash_fold', 'name': 'Wash & Fold', 'duration': '24 hours', 'icon': Icons.local_laundry_service, 'weight': 'Up to 5kg'},
    {'id': 'wash_iron', 'name': 'Wash & Iron', 'duration': '24 hours', 'icon': Icons.iron, 'weight': 'Up to 5kg'},
    {'id': 'dry_cleaning', 'name': 'Dry Cleaning', 'duration': '48 hours', 'icon': Icons.dry, 'items': 'Up to 3 items'},
    {'id': 'ironing_only', 'name': 'Ironing Only', 'duration': '12 hours', 'icon': Icons.iron, 'weight': 'Up to 3kg'},
    {'id': 'bulk_laundry', 'name': 'Bulk Laundry', 'duration': '48 hours', 'icon': Icons.local_laundry_service, 'weight': '15-20kg'},
    {'id': 'curtain_cleaning', 'name': 'Curtain Cleaning', 'duration': '72 hours', 'icon': Icons.curtains, 'items': 'Per set'},
  ];

  final List<Map<String, dynamic>> _rideSubServices = [
    {'id': 'standard_ride', 'name': 'Standard Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Comfortable sedan'},
    {'id': 'suv_ride', 'name': 'SUV Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Spacious SUV'},
    {'id': 'luxury_ride', 'name': 'Luxury Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Premium luxury car'},
    {'id': 'van_ride', 'name': 'Van Ride', 'duration': 'On-demand', 'icon': Icons.car_rental, 'description': 'Group/team travel'},
  ];

  // ============================================================
  // SELECTED DATA
  // ============================================================
  List<String> _selectedMainCategories = [];
  Map<String, List<String>> _selectedSubServices = {};
  Map<String, String> _subServicePrices = {};
  
  String _selectedVehicleType = 'Motorcycle';
  double _workingRadius = 10;
  String _selectedBank = 'Access Bank';
  String _bankSearchQuery = '';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  
  // ============================================================
  // All Nigerian Banks
  // ============================================================
  final List<String> _allBanks = [
    'Access Bank', 'GTBank', 'First Bank', 'UBA', 'Zenith Bank',
    'Union Bank', 'Fidelity Bank', 'Ecobank', 'Stanbic IBTC', 'Polaris Bank',
    'Sterling Bank', 'Wema Bank', 'Heritage Bank', 'Keystone Bank',
    'Providus Bank', 'Titan Trust Bank', 'Globus Bank', 'Parallex Bank',
    'Premium Trust Bank', 'Signature Bank',
    'Accion Microfinance Bank', 'AB Microfinance Bank', 'Afemai Microfinance Bank',
    'Allianz Microfinance Bank', 'Alvana Microfinance Bank', 'Aso Savings & Loans',
    'Baobab Microfinance Bank', 'BIPC Microfinance Bank', 'Bosak Microfinance Bank',
    'Cedar Microfinance Bank', 'Covenant Microfinance Bank', 'Crown Microfinance Bank',
    'DBN Microfinance Bank', 'E-Block Microfinance Bank', 'Ehiama Microfinance Bank',
    'Empower Microfinance Bank', 'ESOP Microfinance Bank', 'FairMoney Microfinance Bank',
    'Fina Microfinance Bank', 'Forte Microfinance Bank', 'Girei Microfinance Bank',
    'Gombe Microfinance Bank', 'GreenBank Microfinance Bank', 'Haggai Microfinance Bank',
    'Hasal Microfinance Bank', 'Infinity Microfinance Bank', 'Innovate Microfinance Bank',
    'Kadpoly Microfinance Bank', 'Kano Microfinance Bank', 'Kasuwa Microfinance Bank',
    'Kuda Microfinance Bank', 'Lasaco Microfinance Bank', 'Mainstreet Microfinance Bank',
    'Mint Microfinance Bank', 'Mkobo Microfinance Bank', 'Mutual Microfinance Bank',
    'New Prudent Microfinance Bank', 'NIRSAL Microfinance Bank', 'Noble Microfinance Bank',
    'Nurture Microfinance Bank', 'Ojokoro Microfinance Bank', 'Omiye Microfinance Bank',
    'Paga Microfinance Bank', 'Palmcoast Microfinance Bank', 'Partnership Microfinance Bank',
    'Pepper Microfinance Bank', 'Personal Trust Microfinance Bank', 'Progressive Microfinance Bank',
    'Rabobank Microfinance Bank', 'Rigo Microfinance Bank', 'Sabru Microfinance Bank',
    'Sagamu Microfinance Bank', 'Seedvest Microfinance Bank', 'Smart Microfinance Bank',
    'Sparkle Microfinance Bank', 'Splendid Microfinance Bank', 'Startup Microfinance Bank',
    'Sunshine Microfinance Bank', 'Tangerine Microfinance Bank', 'TCF Microfinance Bank',
    'Top Capital Microfinance Bank', 'Trustfund Microfinance Bank', 'Unibright Microfinance Bank',
    'Victory Microfinance Bank', 'Vision Microfinance Bank', 'VFD Microfinance Bank',
    'Vivid Microfinance Bank', 'Waya Microfinance Bank', 'Yobe Microfinance Bank',
    'Kuda Bank', 'OPay', 'PalmPay', 'FairMoney', 'Carbon Bank',
    'VBank', 'Sparkle Bank', 'ALAT by Wema', 'Rubies Bank', 'Eyowo',
    'Zenith Bank (Eazy)', 'GTBank (GTWorld)', 'Access Bank (AccessMore)',
    'Sterling Bank (OneBank)', 'UBA (UBAMobile)', 'Fidelity Bank (Fidelity Online)',
    'Union Bank (UnionMobile)', 'Ecobank (Ecobank Mobile)', 'Stanbic IBTC (Stanbic Mobile)',
    'Polaris Bank (Polaris Mobile)', 'Wema Bank (ALAT)', 'First Bank (FirstMobile)',
    'Heritage Bank (Heritage Mobile)', 'Keystone Bank (Keystone Mobile)',
    '9Mobile (9PSB)', 'MTN MoMo', 'Airtel SmartCash', 'Glo G-Wallet',
    'eTranzact', 'Paga', 'Interswitch', 'Flutterwave (Barter)',
    'Paystack (Paystack Business)', 'Moniepoint', 'Opay (Opay Business)',
    'PalmPay (PalmPay Business)', 'Kuda (Kuda Business)',
  ];
  
  List<String> get _filteredBanks {
    if (_bankSearchQuery.isEmpty) return _allBanks;
    return _allBanks.where((bank) =>
        bank.toLowerCase().contains(_bankSearchQuery.toLowerCase())).toList();
  }

  final List<String> _vehicleTypes = ['Motorcycle', 'Car', 'Van', 'Truck', 'SUV', 'Bicycle', 'Keke (Tricycle)'];

  // ============================================================
  // GET SUB-SERVICES FOR A MAIN CATEGORY
  // ============================================================
  List<Map<String, dynamic>> _getSubServices(String mainCategoryId) {
    switch (mainCategoryId) {
      case 'car_wash':
        return _carWashSubServices;
      case 'house_cleaning':
        return _houseCleaningSubServices;
      case 'laundry':
        return _laundrySubServices;
      case 'ride_service':
        return _rideSubServices;
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    for (var category in _mainCategories) {
      final subServices = _getSubServices(category['id']);
      for (var sub in subServices) {
        final key = '${category['id']}_${sub['id']}';
        _servicePriceControllers[key] = TextEditingController(text: '');
        _subServicePrices[key] = '';
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _servicePriceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ============================================================
  // TOGGLE MAIN CATEGORY
  // ============================================================
  void _toggleMainCategory(String categoryId) {
    setState(() {
      if (_selectedMainCategories.contains(categoryId)) {
        _selectedMainCategories.remove(categoryId);
        _selectedSubServices.remove(categoryId);
      } else {
        _selectedMainCategories.add(categoryId);
        _selectedSubServices[categoryId] = [];
      }
    });
  }

  // ============================================================
  // TOGGLE SUB-SERVICE
  // ============================================================
  void _toggleSubService(String mainCategoryId, String subServiceId) {
    setState(() {
      if (!_selectedSubServices.containsKey(mainCategoryId)) {
        _selectedSubServices[mainCategoryId] = [];
      }
      
      final list = _selectedSubServices[mainCategoryId]!;
      if (list.contains(subServiceId)) {
        list.remove(subServiceId);
      } else {
        list.add(subServiceId);
        final key = '${mainCategoryId}_$subServiceId';
        if (!_servicePriceControllers.containsKey(key)) {
          _servicePriceControllers[key] = TextEditingController(text: '');
        }
      }
    });
  }

  // ============================================================
  // IMAGE PICKER - UPLOAD IMMEDIATELY
  // ============================================================
  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 70,
      );
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _profileImage = file;
          _isUploading = true;
          _uploadError = '';
          _uploadProgress = 0.0;
        });
        
        print('📤 Uploading profile image...');
        
        // ✅ UPLOAD IMMEDIATELY
        final url = await CloudinaryService.uploadImage(
          image: file,
          folder: 'washers',
        );
        
        if (url != null) {
          setState(() {
            _profileImageUrl = url;
            _profileUploaded = true;
            _isUploading = false;
            _uploadProgress = 1.0;
          });
          print('✅ Profile image uploaded: $url');
        } else {
          setState(() {
            _uploadError = 'Failed to upload profile image. Please try again.';
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error picking profile image: $e');
      setState(() {
        _uploadError = 'Failed to pick image: $e';
        _isUploading = false;
      });
    }
  }

  Future<void> _pickIdImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (image != null) {
        final file = File(image.path);
        setState(() {
          _idImage = file;
          _isUploading = true;
          _uploadError = '';
          _uploadProgress = 0.0;
        });
        
        print('📤 Uploading ID image...');
        
        // ✅ UPLOAD IMMEDIATELY
        final url = await CloudinaryService.uploadImage(
          image: file,
          folder: 'washers',
        );
        
        if (url != null) {
          setState(() {
            _idImageUrl = url;
            _idUploaded = true;
            _isUploading = false;
            _uploadProgress = 1.0;
          });
          print('✅ ID image uploaded: $url');
        } else {
          setState(() {
            _uploadError = 'Failed to upload ID image. Please try again.';
            _isUploading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error picking ID image: $e');
      setState(() {
        _uploadError = 'Failed to pick image: $e';
        _isUploading = false;
      });
    }
  }

  // ============================================================
  // Register Washer
  // ============================================================
  Future<void> _registerWasher() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }
    
    if (_selectedMainCategories.isEmpty) {
      _showError('Please select at least one service category');
      return;
    }
    
    bool hasSubService = false;
    for (var entry in _selectedSubServices.entries) {
      if (entry.value.isNotEmpty) {
        hasSubService = true;
        break;
      }
    }
    if (!hasSubService) {
      _showError('Please select at least one sub-service');
      return;
    }
    
    for (var entry in _selectedSubServices.entries) {
      final mainCategoryId = entry.key;
      for (var subId in entry.value) {
        final key = '${mainCategoryId}_$subId';
        final price = _servicePriceControllers[key]?.text.trim() ?? '';
        if (price.isEmpty) {
          _showError('Please set prices for all selected sub-services');
          return;
        }
        if (int.tryParse(price) == null) {
          _showError('Please enter valid numbers for prices');
          return;
        }
      }
    }
    
    if (!_profileUploaded) {
      _showError('Please wait for profile picture to upload');
      return;
    }
    
    if (!_idUploaded) {
      _showError('Please wait for ID image to upload');
      return;
    }
    
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }

    if (_accountNameController.text.trim().isEmpty) {
      _showError('Please enter your account name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
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
      
      final userId = authService.getCurrentUserId();
      if (userId == null) {
        _showError('User not found. Please try again.');
        setState(() => _isLoading = false);
        return;
      }

      // Build selected services data
      List<String> selectedMainCategories = _selectedMainCategories;
      Map<String, List<String>> selectedSubServices = _selectedSubServices;
      Map<String, String> subServicePrices = {};
      
      for (var entry in selectedSubServices.entries) {
        final mainCategoryId = entry.key;
        for (var subId in entry.value) {
          final key = '${mainCategoryId}_$subId';
          final price = _servicePriceControllers[key]?.text.trim() ?? '0';
          subServicePrices[key] = price;
        }
      }

      // Get main category names
      List<String> mainCategoryNames = [];
      for (var id in selectedMainCategories) {
        final category = _mainCategories.firstWhere((c) => c['id'] == id);
        mainCategoryNames.add(category['name']);
      }

      final washerData = {
        'userId': userId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'selectedMainCategories': selectedMainCategories,
        'mainCategoryNames': mainCategoryNames,
        'selectedSubServices': selectedSubServices,
        'subServicePrices': subServicePrices,
        'vehicleType': _selectedVehicleType,
        'workingRadius': _workingRadius.toInt(),
        'bankName': _selectedBank,
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'profileImage': _profileImageUrl,
        'idImage': _idImageUrl,
        'isVerified': false,
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

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'role': 'washer',
        'washerId': washerRef.id,
        'mainCategories': selectedMainCategories,
        'subServices': selectedSubServices,
        'profileImage': _profileImageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await authService.reloadUserData();
      await authService.refreshUserData();
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Washer account created! You are now online.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const WasherDashboard()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('❌ Registration error: $e');
      _showError('Registration failed: ${e.toString().substring(0, 100)}...');
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
      body: _isLoading || _isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isUploading 
                        ? 'Uploading images... ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                        : 'Processing...',
                    style: TextStyle(color: AppColors.grey600),
                  ),
                  if (_isUploading)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 200,
                      child: LinearProgressIndicator(
                        value: _uploadProgress,
                        color: AppColors.primary,
                        backgroundColor: Colors.grey.shade200,
                      ),
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
                    
                    // "Already a Service Provider? Login"
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Already a Service Provider?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Login to your washer dashboard',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            ),
                            child: const Text(
                              'Login',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ============================================================
                    // Profile Picture Upload - IMMEDIATE UPLOAD
                    // ============================================================
                    const Text(
                      'Profile Picture',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(60),
                          border: Border.all(
                            color: _profileUploaded ? AppColors.primary : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: _profileImage != null && _profileImageUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  _profileImageUrl,
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    );
                                  },
                                ),
                              )
                            : _profileImage != null
                                ? ClipOval(
                                    child: Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 120,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 30, color: Colors.grey.shade400),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Upload Photo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _profileUploaded 
                            ? '✅ Photo uploaded successfully!' 
                            : _profileImage != null
                                ? '⏳ Uploading photo...' 
                                : 'Tap to upload profile picture',
                        style: TextStyle(
                          fontSize: 12,
                          color: _profileUploaded 
                              ? Colors.green 
                              : _profileImage != null
                                  ? Colors.orange 
                                  : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // ============================================================
                    // Means of Identification Upload - IMMEDIATE UPLOAD
                    // ============================================================
                    const Text(
                      'Means of Identification',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload a valid ID (National ID, Driver\'s License, Voter\'s Card, or International Passport)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _pickIdImage,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _idUploaded ? AppColors.primary : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: _idImage != null && _idImageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _idImageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 160,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Image.file(
                                      _idImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 160,
                                    );
                                  },
                                ),
                              )
                            : _idImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _idImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 160,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.assignment, size: 40, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload ID',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade400,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'National ID / Driver\'s License / Passport',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _idUploaded 
                            ? '✅ ID uploaded successfully!' 
                            : _idImage != null
                                ? '⏳ Uploading ID...' 
                                : 'Tap to upload means of identification',
                        style: TextStyle(
                          fontSize: 12,
                          color: _idUploaded 
                              ? Colors.green 
                              : _idImage != null
                                  ? Colors.orange 
                                  : Colors.grey.shade500,
                        ),
                      ),
                    ),
                    
                    // Upload Error Display
                    if (_uploadError.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _uploadError,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _uploadError = ''),
                              child: const Icon(Icons.close, color: Colors.red, size: 16),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // ============================================================
                    // SELECT SERVICES & SET PRICES
                    // ============================================================
                    const Text(
                      'Select Services & Set Prices',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose service categories, select sub-services, and set your own prices',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    ..._mainCategories.map((mainCategory) {
                      final mainId = mainCategory['id'];
                      final isMainSelected = _selectedMainCategories.contains(mainId);
                      final subServices = _getSubServices(mainId);
                      final selectedSubs = _selectedSubServices[mainId] ?? [];
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Category Tile
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isMainSelected ? AppColors.primary : Colors.grey.shade300,
                                width: isMainSelected ? 2 : 1,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _toggleMainCategory(mainId),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Icon(
                                      isMainSelected ? Icons.check_circle : Icons.circle_outlined,
                                      color: isMainSelected ? AppColors.primary : Colors.grey.shade400,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(mainCategory['icon'], color: isMainSelected ? AppColors.primary : Colors.grey.shade600),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        mainCategory['name'],
                                        style: TextStyle(
                                          fontWeight: isMainSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isMainSelected ? AppColors.primary : Colors.black87,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isMainSelected)
                                      Text(
                                        '${selectedSubs.length} selected',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Sub-services (visible only if main category is selected)
                          if (isMainSelected) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sub-services for ${mainCategory['name']}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...subServices.map((subService) {
                                      final subId = subService['id'];
                                      final isSelected = selectedSubs.contains(subId);
                                      final key = '${mainId}_$subId';
                                      final priceController = _servicePriceControllers[key];
                                      
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(8),
                                          border: isSelected 
                                              ? Border.all(color: AppColors.primary.withOpacity(0.3))
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            GestureDetector(
                                              onTap: () => _toggleSubService(mainId, subId),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                                    color: isSelected ? AppColors.primary : Colors.grey.shade400,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    subService['icon'],
                                                    color: isSelected ? AppColors.primary : Colors.grey.shade500,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        subService['name'],
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                                          color: isSelected ? AppColors.primary : Colors.black87,
                                                        ),
                                                      ),
                                                      Text(
                                                        subService['duration'] ?? '',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey.shade500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Spacer(),
                                            if (isSelected)
                                              SizedBox(
                                                width: 80,
                                                child: TextFormField(
                                                  controller: priceController,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    prefixText: '₦',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                    isDense: true,
                                                    hintText: 'Price',
                                                    hintStyle: TextStyle(fontSize: 10),
                                                  ),
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }).toList(),
                    
                    const SizedBox(height: 24),
                    
                    // ============================================================
                    // Personal Information
                    // ============================================================
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
                    
                    // ============================================================
                    // Vehicle Information
                    // ============================================================
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
                    
                    // ============================================================
                    // Bank Information - MANUAL ENTRY ONLY
                    // ============================================================
                    const Text(
                      'Bank Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your bank details manually (no automatic verification)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _bankSearchQuery = value;
                            });
                          },
                          decoration: const InputDecoration(
                            labelText: 'Search Bank *',
                            prefixIcon: Icon(Icons.search, color: AppColors.primary),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: AppColors.primary, width: 2),
                            ),
                            suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_bankSearchQuery.isNotEmpty)
                          Container(
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredBanks.length > 20 ? 20 : _filteredBanks.length,
                              itemBuilder: (context, index) {
                                final bank = _filteredBanks[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(bank, style: const TextStyle(fontSize: 13)),
                                  onTap: () {
                                    setState(() {
                                      _selectedBank = bank;
                                      _bankSearchQuery = '';
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        if (_bankSearchQuery.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedBank,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(selected)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    TextFormField(
                      controller: _accountNumberController,
                      keyboardType: TextInputType.number,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Account Number *',
                        prefixIcon: Icon(Icons.numbers, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        counterText: '',
                        hintText: 'Enter your 10-digit account number',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter account number';
                        }
                        if (value.length < 10) {
                          return 'Enter 10-digit account number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    
                    TextFormField(
                      controller: _accountNameController,
                      decoration: InputDecoration(
                        labelText: 'Account Name *',
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        hintText: 'Enter the account holder\'s full name',
                        helperText: 'Enter the name exactly as it appears on the bank account',
                        helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Enter account name';
                        }
                        if (value.length < 3) {
                          return 'Enter a valid account name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Please ensure the account name matches the bank records. '
                              'This will be used for payments.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                          _selectedMainCategories.isEmpty 
                              ? 'Select a Service First'
                              : 'Create Account',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
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
                              _selectedMainCategories.isEmpty
                                  ? 'Please select at least one service category to get started'
                                  : 'Your account will be activated immediately',
                              style: TextStyle(
                                color: _selectedMainCategories.isEmpty ? Colors.orange.shade700 : Colors.green.shade700,
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
                '4. 20% commission on each job\n'
                '5. You must maintain 4.0+ rating\n'
                '6. Cancellation policy applies\n'
                '7. You can withdraw your earnings at any time\n'
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
