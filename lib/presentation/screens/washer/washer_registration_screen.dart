// lib/presentation/screens/washer/washer_registration_screen.dart
// PURPOSE: Complete washer registration form with Firebase integration

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/cloudinary_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/validation_service.dart';
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
  final _ninController = TextEditingController();
  final _idNumberController = TextEditingController();

  // Profile Photo & Means of Identification state
  File? _profileImageFile;
  File? _idDocumentFile;
  String _selectedIdType = "National Identity Number (NIN)";
  final List<String> _idTypes = [
    "National Identity Number (NIN)",
    "Driver's License",
    "International Passport",
    "Voter's Card (VNC / PVC)",
  ];

  Future<void> _pickImage(ImageSource source, bool isProfilePhoto) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 80);
      if (picked != null) {
        setState(() {
          if (isProfilePhoto) {
            _profileImageFile = File(picked.path);
          } else {
            _idDocumentFile = File(picked.path);
          }
        });
      }
    } catch (e) {
      _showError('Failed to select image: $e');
    }
  }

  void _showImagePickerModal(bool isProfilePhoto) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isProfilePhoto ? 'Select Profile Picture' : 'Select ID Document Image',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo with Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isProfilePhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isProfilePhoto);
              },
            ),
          ],
        ),
      ),
    );
  }
  
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
    {'id': 'wash_fold', 'name': 'Wash & Fold', 'duration': '24 hours', 'icon': Icons.local_laundry_service, 'clothes': '1-10 clothes (Up to 5kg)'},
    {'id': 'wash_iron', 'name': 'Wash & Iron', 'duration': '24 hours', 'icon': Icons.iron, 'clothes': '1-10 clothes (Up to 5kg)'},
    {'id': 'dry_cleaning', 'name': 'Dry Cleaning', 'duration': '48 hours', 'icon': Icons.dry, 'clothes': 'Per piece / 1-3 items'},
    {'id': 'ironing_only', 'name': 'Ironing Only', 'duration': '12 hours', 'icon': Icons.iron, 'clothes': '1-10 clothes (Up to 3kg)'},
    {'id': 'bulk_laundry', 'name': 'Bulk Laundry', 'duration': '48 hours', 'icon': Icons.local_laundry_service, 'clothes': '20-50+ clothes (15-20kg)'},
    {'id': 'curtain_cleaning', 'name': 'Curtain Cleaning', 'duration': '72 hours', 'icon': Icons.curtains, 'clothes': 'Per set / pair'},
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
  
  String? _selectedVehicleType;
  double _workingRadius = 10;
  String? _selectedBank;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  
  // ============================================================
  // All Nigerian Banks
  // ============================================================
  final List<String> _allBanks = [
    'Access Bank',
    'GTBank (Guaranty Trust Bank)',
    'Zenith Bank',
    'First Bank of Nigeria',
    'UBA (United Bank for Africa)',
    'Kuda Bank',
    'Moniepoint Microfinance Bank',
    'OPay',
    'PalmPay',
    'FCMB (First City Monument Bank)',
    'Fidelity Bank',
    'Stanbic IBTC Bank',
    'Sterling Bank',
    'Wema Bank / ALAT',
    'Union Bank of Nigeria',
    'Ecobank Nigeria',
    'Keystone Bank',
    'Providus Bank',
    'Heritage Bank',
    'Polaris Bank',
    'FairMoney Microfinance Bank',
    'Taj Bank',
    'Parallex Bank',
    'Lotus Bank',
    'Signature Bank',
    'Titan Trust Bank',
    'Globus Bank',
    'Premium Trust Bank',
    'VBank (VFD Microfinance)',
    'Rubies Bank',
    'Eyowo',
    'Paga',
  ];

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
    
    if (!_agreeToTerms) {
      _showError('Please agree to the terms and conditions');
      return;
    }

    // 🔒 Validation Check 1: Authentic Phone Number Check
    final phoneRes = ValidationService().validatePhone(_phoneController.text.trim());
    if (!phoneRes.isValid) {
      _showError(phoneRes.errorMessage ?? 'Invalid phone number');
      return;
    }

    // 🔒 Validation Check 2: Real Email & Disposable Domain Check (if email provided)
    if (_emailController.text.trim().isNotEmpty) {
      final emailRes = ValidationService().validateEmail(_emailController.text.trim());
      if (!emailRes.isValid) {
        _showError(emailRes.errorMessage ?? 'Invalid email address');
        return;
      }
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
        email: _emailController.text.trim(),
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

      // Build selected services data & provider custom prices
      List<String> selectedMainCategories = _selectedMainCategories;
      Map<String, List<String>> selectedSubServices = _selectedSubServices;
      Map<String, String> subServicePrices = {};
      Map<String, int> servicePrices = {};
      int? primaryPrice;
      
      for (var entry in selectedSubServices.entries) {
        final mainCategoryId = entry.key;
        final subList = _getSubServices(mainCategoryId);
        for (var subId in entry.value) {
          final key = '${mainCategoryId}_$subId';
          final priceStr = _servicePriceControllers[key]?.text.trim() ?? '0';
          final priceInt = int.tryParse(priceStr) ?? 0;
          
          subServicePrices[key] = priceStr;
          subServicePrices[subId] = priceStr;
          
          final subObj = subList.firstWhere(
            (s) => s['id'] == subId,
            orElse: () => {'name': subId},
          );
          final displayName = (subObj['name'] ?? subId).toString();
          
          if (priceInt > 0) {
            primaryPrice ??= priceInt;
            servicePrices[displayName] = priceInt;
            servicePrices[subId] = priceInt;
            servicePrices[key] = priceInt;
          }
        }
      }

      // Get main category names
      List<String> mainCategoryNames = [];
      for (var id in selectedMainCategories) {
        final category = _mainCategories.firstWhere((c) => c['id'] == id);
        mainCategoryNames.add(category['name']);
      }

      // Upload Profile Image if provided
      String? profileImageUrl;
      if (_profileImageFile != null) {
        try {
          final cloudinary = CloudinaryService();
          profileImageUrl = await cloudinary.uploadImage(
            imageFile: XFile(_profileImageFile!.path),
            folder: 'washer_profiles',
          );
        } catch (e) {
          debugPrint('⚠️ Error uploading profile image: $e');
        }
      }

      // Upload ID Document Image if provided
      String? idDocumentUrl;
      if (_idDocumentFile != null) {
        try {
          final cloudinary = CloudinaryService();
          idDocumentUrl = await cloudinary.uploadImage(
            imageFile: XFile(_idDocumentFile!.path),
            folder: 'id_documents',
          );
        } catch (e) {
          debugPrint('⚠️ Error uploading ID document: $e');
        }
      }

      final washerData = {
        'userId': userId,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'ninNumber': _ninController.text.trim(),
        'idType': _selectedIdType,
        'idNumber': _idNumberController.text.trim().isNotEmpty ? _idNumberController.text.trim() : _ninController.text.trim(),
        'profileImage': profileImageUrl ?? '',
        'washerPhotoURL': profileImageUrl ?? '',
        'photoURL': profileImageUrl ?? '',
        'idDocumentUrl': idDocumentUrl ?? '',
        'selectedMainCategories': selectedMainCategories,
        'mainCategoryNames': mainCategoryNames,
        'selectedSubServices': selectedSubServices,
        'subServicePrices': subServicePrices,
        'servicePrices': servicePrices,
        'price': primaryPrice ?? 0,
        'customPrice': primaryPrice ?? 0,
        'vehicleType': _selectedVehicleType ?? 'None / Walking',
        'workingRadius': _workingRadius.toInt(),
        'bankName': _selectedBank ?? '',
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _accountNameController.text.trim(),
        'isVerified': false,
        'isOnline': true,
        'approved': true,
        'rating': 5.0,
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
        'subServicePrices': subServicePrices,
        'servicePrices': servicePrices,
        'price': primaryPrice ?? 0,
        'customPrice': primaryPrice ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      await authService.reloadUserData();
      await authService.refreshUserData();
      
      // Dispatch Provider Welcome Email & SMS
      CommunicationService().sendWelcomeNotifications(
        userName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        role: 'Service Provider',
      );

      // Dispatch Provider Registration Alert to Admin
      CommunicationService().sendProviderRegistrationAdminAlert(
        providerName: _nameController.text.trim(),
        providerPhone: _phoneController.text.trim(),
        providerEmail: _emailController.text.trim(),
        category: mainCategoryNames.join(', '),
        city: '${_cityController.text.trim()}, ${_stateController.text.trim()}',
      );

      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Washer account created! You are now online.'),
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
      debugPrint('❌ Registration error: $e');
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
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
                                                        '${subService['duration'] ?? ''}${subService['clothes'] != null ? ' • ${subService['clothes']}' : ''}',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: isSelected ? AppColors.primary : Colors.grey.shade600,
                                                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
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
                                                width: 105,
                                                child: TextFormField(
                                                  controller: priceController,
                                                  keyboardType: TextInputType.number,
                                                  decoration: const InputDecoration(
                                                    prefixText: '₦',
                                                    border: OutlineInputBorder(),
                                                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                    isDense: true,
                                                    labelText: 'Your Price',
                                                    labelStyle: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                                    hintText: 'e.g 3500',
                                                    hintStyle: TextStyle(fontSize: 10),
                                                  ),
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                    // Personal Information & Profile Photo
                    // ============================================================
                    const Text(
                      'Personal Information & Profile Photo',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 16),

                    // Profile Picture Upload Card
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.08),
                              border: Border.all(color: AppColors.primary, width: 2.5),
                              image: _profileImageFile != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImageFile!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImageFile == null
                                ? const Icon(
                                    Icons.person_add_alt_1,
                                    size: 55,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showImagePickerModal(true),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showImagePickerModal(true),
                        icon: const Icon(Icons.cloud_upload, size: 18, color: AppColors.primary),
                        label: Text(
                          _profileImageFile == null ? 'Upload Profile Picture' : 'Change Profile Picture',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                        ),
                      ),
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
                    // Means of Identification (ID Verification)
                    // ============================================================
                    const Text(
                      'Means of Identification (ID Verification)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select your document type, enter your ID number, and upload a photo of your ID.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      value: _selectedIdType,
                      decoration: const InputDecoration(
                        labelText: 'Means of Identification Type *',
                        prefixIcon: Icon(Icons.badge, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      isExpanded: true,
                      items: _idTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedIdType = val);
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _idNumberController,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        labelText: 'ID / Slip Number *',
                        prefixIcon: const Icon(Icons.confirmation_number, color: AppColors.primary),
                        border: const OutlineInputBorder(),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        hintText: 'Enter your ${_selectedIdType} number',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your ID number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Document Photo Upload Container
                    GestureDetector(
                      onTap: () => _showImagePickerModal(false),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _idDocumentFile != null
                              ? AppColors.primary.withOpacity(0.05)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _idDocumentFile != null
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            if (_idDocumentFile != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  _idDocumentFile!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  SizedBox(width: 6),
                                  Text(
                                    'ID Document Photo Attached',
                                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const Icon(Icons.cloud_upload_outlined, size: 42, color: AppColors.primary),
                              const SizedBox(height: 8),
                              const Text(
                                'Upload ID Document / Card Image',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap to take a clear photo or select from gallery',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                    
                    DropdownButtonFormField<String>(
                      value: _selectedVehicleType,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type (Optional)',
                        hintText: 'Select your vehicle type',
                        prefixIcon: Icon(Icons.directions_car, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'None / Walking', child: Text('None / Walking (No vehicle)')),
                        DropdownMenuItem(value: 'Motorcycle', child: Text('Motorcycle')),
                        DropdownMenuItem(value: 'Car', child: Text('Car')),
                        DropdownMenuItem(value: 'Van', child: Text('Van')),
                        DropdownMenuItem(value: 'Truck', child: Text('Truck')),
                        DropdownMenuItem(value: 'SUV', child: Text('SUV')),
                        DropdownMenuItem(value: 'Bicycle', child: Text('Bicycle')),
                        DropdownMenuItem(value: 'Keke (Tricycle)', child: Text('Keke (Tricycle)')),
                      ],
                      onChanged: (value) => setState(() => _selectedVehicleType = value),
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
                    // Bank Information - COMPLETE NIGERIAN BANKS DROPDOWN
                    // ============================================================
                    const Text(
                      'Bank Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select your bank for earnings payouts',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
                      value: _selectedBank,
                      decoration: const InputDecoration(
                        labelText: 'Select Bank *',
                        hintText: 'Choose your Nigerian Bank',
                        prefixIcon: Icon(Icons.account_balance, color: AppColors.primary),
                        border: OutlineInputBorder(),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                      ),
                      isExpanded: true,
                      items: _allBanks.map((bank) => DropdownMenuItem<String>(
                        value: bank,
                        child: Text(bank, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedBank = value),
                      validator: (value) => value == null || value.isEmpty ? 'Select your bank' : null,
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
