import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/app_notification_service.dart';
import '../washer/matching_screen.dart';
import 'tracking_screen.dart';

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
  String _selectedService = 'Standard Cleaning';
  int _selectedServicePrice = 15000;
  String _selectedLocation = 'Lekki Phase 1, Lagos';
  DateTime _selectedDate = DateTime.now();
  String _selectedTime = '9:00 AM';
  bool _isBooking = false;

  // ✅ Added Ride Service to categories
  final List<String> _categories = ['Car Wash', 'House Cleaning', 'Laundry', 'Ride Service'];

  // Service Data - ✅ Added Ride Service
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
    // ✅ NEW: Ride Service
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

  String get _actionButtonText {
    switch (_selectedCategory) {
      case 'Car Wash':
        return 'Book Car Wash';
      case 'House Cleaning':
        return 'Book House Cleaning';
      case 'Laundry':
        return 'Book Laundry';
      case 'Ride Service':
        return 'Book Ride';
      default:
        return 'Book Now';
    }
  }

  // ... rest of the methods remain the same as your existing code
  // (The booking logic remains unchanged)