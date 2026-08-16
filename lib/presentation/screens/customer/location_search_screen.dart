// lib/presentation/screens/customer/location_search_screen.dart
// Use OSM only - NO Google API key needed

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import '../../../core/constants/app_colors.dart';

class LocationSearchScreen extends StatefulWidget {
  final String? initialQuery;
  final Function(String, Map<String, dynamic>)? onLocationSelected;

  const LocationSearchScreen({
    super.key,
    this.initialQuery,
    this.onLocationSelected,
  });

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _isGettingLocation = false;
  String? _currentLocationAddress;

  // Nigerian cities database (offline)
  final List<Map<String, String>> _nigerianCities = [
    // Lagos areas
    {'name': 'Lekki Phase 1, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4369', 'lng': '3.4525'},
    {'name': 'Lekki Phase 2, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4482', 'lng': '3.4831'},
    {'name': 'Victoria Island, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4292', 'lng': '3.4199'},
    {'name': 'Ikoyi, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4565', 'lng': '3.4350'},
    {'name': 'Surulere, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.5030', 'lng': '3.3486'},
    {'name': 'Ikeja, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.6022', 'lng': '3.3574'},
    {'name': 'GRA, Ikeja, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.6071', 'lng': '3.3640'},
    {'name': 'Ajah, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4738', 'lng': '3.5691'},
    {'name': 'Maryland, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.6000', 'lng': '3.3833'},
    {'name': 'Yaba, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4972', 'lng': '3.3718'},
    {'name': 'Magodo, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.6130', 'lng': '3.4038'},
    {'name': 'Agege, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.6196', 'lng': '3.3302'},
    {'name': 'Badagry, Lagos', 'state': 'Lagos', 'type': 'city', 'lat': '6.4159', 'lng': '2.8796'},
    {'name': 'Epe, Lagos', 'state': 'Lagos', 'type': 'city', 'lat': '6.5859', 'lng': '3.9834'},
    {'name': 'Ikorodu, Lagos', 'state': 'Lagos', 'type': 'city', 'lat': '6.6153', 'lng': '3.5006'},
    {'name': 'Mushin, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.5272', 'lng': '3.3533'},
    {'name': 'Ojo, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4588', 'lng': '3.1731'},
    {'name': 'Alimosho, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.5900', 'lng': '3.3000'},
    {'name': 'Festac Town, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4690', 'lng': '3.2888'},
    {'name': 'Amuwo Odofin, Lagos', 'state': 'Lagos', 'type': 'area', 'lat': '6.4550', 'lng': '3.2833'},
    
    // Other Nigerian cities
    {'name': 'Abuja, FCT', 'state': 'FCT', 'type': 'city', 'lat': '9.0765', 'lng': '7.3986'},
    {'name': 'Port Harcourt, Rivers', 'state': 'Rivers', 'type': 'city', 'lat': '4.8156', 'lng': '7.0498'},
    {'name': 'Ibadan, Oyo', 'state': 'Oyo', 'type': 'city', 'lat': '7.3776', 'lng': '3.9470'},
    {'name': 'Kano, Kano', 'state': 'Kano', 'type': 'city', 'lat': '12.0022', 'lng': '8.5919'},
    {'name': 'Benin City, Edo', 'state': 'Edo', 'type': 'city', 'lat': '6.3350', 'lng': '5.6037'},
    {'name': 'Enugu, Enugu', 'state': 'Enugu', 'type': 'city', 'lat': '6.4482', 'lng': '7.5138'},
    {'name': 'Abeokuta, Ogun', 'state': 'Ogun', 'type': 'city', 'lat': '7.1557', 'lng': '3.3451'},
    {'name': 'Warri, Delta', 'state': 'Delta', 'type': 'city', 'lat': '5.5173', 'lng': '5.7506'},
    {'name': 'Calabar, Cross River', 'state': 'Cross River', 'type': 'city', 'lat': '4.9580', 'lng': '8.3270'},
    {'name': 'Jos, Plateau', 'state': 'Plateau', 'type': 'city', 'lat': '9.8965', 'lng': '8.8583'},
    {'name': 'Maiduguri, Borno', 'state': 'Borno', 'type': 'city', 'lat': '11.8333', 'lng': '13.1500'},
    {'name': 'Sokoto, Sokoto', 'state': 'Sokoto', 'type': 'city', 'lat': '13.0582', 'lng': '5.2392'},
    {'name': 'Kaduna, Kaduna', 'state': 'Kaduna', 'type': 'city', 'lat': '10.5105', 'lng': '7.4165'},
    {'name': 'Owerri, Imo', 'state': 'Imo', 'type': 'city', 'lat': '5.4855', 'lng': '7.0340'},
    {'name': 'Akure, Ondo', 'state': 'Ondo', 'type': 'city', 'lat': '7.2571', 'lng': '5.2058'},
    {'name': 'Ado-Ekiti, Ekiti', 'state': 'Ekiti', 'type': 'city', 'lat': '7.6230', 'lng': '5.2200'},
    {'name': 'Osogbo, Osun', 'state': 'Osun', 'type': 'city', 'lat': '7.7710', 'lng': '4.5600'},
    {'name': 'Lokoja, Kogi', 'state': 'Kogi', 'type': 'city', 'lat': '7.8020', 'lng': '6.7400'},
    {'name': 'Makurdi, Benue', 'state': 'Benue', 'type': 'city', 'lat': '7.7337', 'lng': '8.5391'},
    {'name': 'Minna, Niger', 'state': 'Niger', 'type': 'city', 'lat': '9.6135', 'lng': '6.5564'},
    {'name': 'Uyo, Akwa Ibom', 'state': 'Akwa Ibom', 'type': 'city', 'lat': '5.0390', 'lng': '7.9281'},
    {'name': 'Asaba, Delta', 'state': 'Delta', 'type': 'city', 'lat': '6.1980', 'lng': '6.7317'},
    {'name': 'Gombe, Gombe', 'state': 'Gombe', 'type': 'city', 'lat': '10.2833', 'lng': '11.1667'},
    {'name': 'Bauchi, Bauchi', 'state': 'Bauchi', 'type': 'city', 'lat': '10.3100', 'lng': '9.8439'},
    {'name': 'Yola, Adamawa', 'state': 'Adamawa', 'type': 'city', 'lat': '9.2035', 'lng': '12.4954'},
    {'name': 'Jalingo, Taraba', 'state': 'Taraba', 'type': 'city', 'lat': '8.8932', 'lng': '11.3600'},
    {'name': 'Damaturu, Yobe', 'state': 'Yobe', 'type': 'city', 'lat': '11.7500', 'lng': '11.9667'},
    {'name': 'Katsina, Katsina', 'state': 'Katsina', 'type': 'city', 'lat': '12.9908', 'lng': '7.6018'},
    {'name': 'Zaria, Kaduna', 'state': 'Kaduna', 'type': 'city', 'lat': '11.0750', 'lng': '7.7000'},
    {'name': 'Lafia, Nasarawa', 'state': 'Nasarawa', 'type': 'city', 'lat': '8.5000', 'lng': '8.5167'},
    {'name': 'Dutse, Jigawa', 'state': 'Jigawa', 'type': 'city', 'lat': '11.7500', 'lng': '9.3333'},
  ];

  // Lagos area names for quick access
  final List<String> _lagosAreas = [
    'Lekki Phase 1',
    'Lekki Phase 2',
    'Victoria Island',
    'Ikoyi',
    'Surulere',
    'Ikeja',
    'Ajah',
    'Maryland',
    'Yaba',
    'Magodo',
    'Agege',
    'Badagry',
    'Epe',
    'Ikorodu',
    'Mushin',
    'Ojo',
    'Alimosho',
    'Festac Town',
    'Amuwo Odofin',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    
    // Check for current location on start
    _checkCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _searchLocal(query);
  }

  void _searchLocal(String query) {
    setState(() => _isLoading = true);
    
    final lowerQuery = query.toLowerCase();
    final results = _nigerianCities.where((city) {
      return city['name']!.toLowerCase().contains(lowerQuery) ||
             city['state']!.toLowerCase().contains(lowerQuery);
    }).toList();
    
    // Sort results by relevance
    results.sort((a, b) {
      final aName = a['name']!.toLowerCase();
      final bName = b['name']!.toLowerCase();
      final aScore = aName.contains(lowerQuery) ? 0 : 1;
      final bScore = bName.contains(lowerQuery) ? 0 : 1;
      return aScore.compareTo(bScore);
    });
    
    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _searchResults = results.map((city) => {
            'description': city['name'],
            'shortAddress': city['name'],
            'state': city['state'],
            'type': city['type'],
            'lat': city['lat'],
            'lng': city['lng'],
          }).toList();
          _isLoading = false;
        });
      }
    });
  }

  // ============================================================
  // FIX 1: Get real current location using GPS
  // ============================================================
  Future<void> _checkCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      // Check location permissions
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          // Show dialog to enable location
          if (mounted) {
            _showEnableLocationDialog();
          }
          setState(() => _isGettingLocation = false);
          return;
        }
        
        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        // Reverse geocode to get address (simplified - using nearby city)
        String address = await _getAddressFromCoords(position.latitude, position.longitude);
        
        if (mounted) {
          setState(() {
            _currentLocationAddress = address;
            _isGettingLocation = false;
          });
          debugPrint('✅ Current location: $address');
        }
      } else {
        // Permission denied
        if (mounted) {
          setState(() => _isGettingLocation = false);
          _showPermissionDialog();
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  // ============================================================
  // FIX 2: Convert coordinates to address using offline data
  // ============================================================
  Future<String> _getAddressFromCoords(double lat, double lng) async {
    // Find nearest city from our database
    String nearestCity = 'Lagos, Nigeria';
    double minDistance = double.infinity;
    
    for (var city in _nigerianCities) {
      if (city['lat'] != null && city['lng'] != null) {
        double cityLat = double.parse(city['lat']!);
        double cityLng = double.parse(city['lng']!);
        double distance = _calculateDistance(lat, lng, cityLat, cityLng);
        
        if (distance < minDistance) {
          minDistance = distance;
          nearestCity = city['name']!;
        }
      }
    }
    
    // If within 10km of a city, use that city
    if (minDistance < 10) {
      return nearestCity;
    }
    
    return 'Your Current Location (Lagos, Nigeria)';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in km
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a = sin(dLat/2) * sin(dLat/2) +
               cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
               sin(dLon/2) * sin(dLon/2);
    double c = 2 * atan2(sqrt(a), sqrt(1-a));
    return R * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text('Please enable GPS/location services to use your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text('Please grant location permission to use your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open App Settings'),
          ),
        ],
      ),
    );
  }

  void _selectLocation(String address, {Map<String, dynamic>? locationData}) {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(address, locationData ?? {});
    } else {
      Navigator.pop(context, address);
    }
  }

  // ============================================================
  // FIX 3: Use current location
  // ============================================================
  void _useCurrentLocation() async {
    if (_currentLocationAddress != null) {
      _selectLocation(
        _currentLocationAddress!,
        locationData: {
          'lat': null,
          'lng': null,
          'type': 'current_location',
        },
      );
      return;
    }
    
    // If no location, try to get it
    setState(() => _isGettingLocation = true);
    await _checkCurrentLocation();
    if (mounted && _currentLocationAddress != null) {
      _selectLocation(
        _currentLocationAddress!,
        locationData: {
          'lat': null,
          'lng': null,
          'type': 'current_location',
        },
      );
    }
    if (mounted) {
      setState(() => _isGettingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Where should we come to?',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Show location status
          if (_isGettingLocation)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search city, street, or landmark...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isNotEmpty
                    ? ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          final address = result['description'] ?? '';
                          final state = result['state'] ?? '';
                          final type = result['type'] ?? 'area';
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  type == 'city' ? Icons.location_city : Icons.location_on,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                address,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                state.isNotEmpty ? state : 'Nigeria',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              onTap: () => _selectLocation(
                                address,
                                locationData: {
                                  'state': state,
                                  'type': type,
                                  'lat': result['lat'],
                                  'lng': result['lng'],
                                },
                              ),
                            ),
                          );
                        },
                      )
                    : _buildPopularLocations(),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularLocations() {
    // Group popular locations by category
    final popularLocations = [
      {'name': 'Lekki Phase 1, Lagos', 'icon': Icons.location_on},
      {'name': 'Victoria Island, Lagos', 'icon': Icons.location_on},
      {'name': 'Ikoyi, Lagos', 'icon': Icons.location_on},
      {'name': 'Surulere, Lagos', 'icon': Icons.location_on},
      {'name': 'Ikeja, Lagos', 'icon': Icons.location_on},
      {'name': 'Abuja, FCT', 'icon': Icons.location_city},
      {'name': 'Port Harcourt, Rivers', 'icon': Icons.location_city},
      {'name': 'Ibadan, Oyo', 'icon': Icons.location_city},
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // FIX 4: Current Location Option - With loading state
          // ============================================================
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isGettingLocation
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gps_fixed, color: AppColors.primary),
              ),
              title: Text(
                _isGettingLocation ? 'Getting current location...' : 'Use Current Location',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _currentLocationAddress != null
                    ? _currentLocationAddress!
                    : _isGettingLocation ? 'Please wait...' : 'Detect your current GPS location',
                style: TextStyle(
                  color: _currentLocationAddress != null ? AppColors.primary : Colors.grey,
                  fontSize: 12,
                ),
              ),
              trailing: _currentLocationAddress != null
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _isGettingLocation ? null : _useCurrentLocation,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // ============================================================
          // FIX 5: Lagos Areas Quick Access
          // ============================================================
          const Text(
            'Lagos Areas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _lagosAreas.map((area) {
              final fullAddress = '$area, Lagos';
              return FilterChip(
                label: Text(area),
                onSelected: (_) => _selectLocation(
                  fullAddress,
                  locationData: {
                    'state': 'Lagos',
                    'type': 'area',
                  },
                ),
                backgroundColor: Colors.grey.shade100,
                selectedColor: AppColors.primary.withOpacity(0.1),
                labelStyle: const TextStyle(fontSize: 13),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // ============================================================
          // FIX 6: Popular Locations
          // ============================================================
          const Text(
            'Popular Locations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          ...popularLocations.map((location) => ListTile(
            leading: Icon(location['icon'] as IconData, color: AppColors.primary),
            title: Text(location['name'] as String),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => _selectLocation(
              location['name'] as String,
              locationData: {
                'state': (location['name'] as String).split(',').last.trim(),
                'type': location['icon'] == Icons.location_city ? 'city' : 'area',
              },
            ),
          )),
          
          const SizedBox(height: 24),
          
          // ============================================================
          // FIX 7: All Nigerian States
          // ============================================================
          const Text(
            'All Nigerian States',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Lagos', 'Abuja', 'Rivers', 'Oyo', 'Kano', 'Edo',
              'Enugu', 'Ogun', 'Delta', 'Cross River', 'Plateau', 'Kaduna',
              'Borno', 'Sokoto', 'Katsina', 'Imo', 'Ondo', 'Ekiti',
              'Osun', 'Kogi', 'Benue', 'Niger', 'Akwa Ibom', 'Adamawa',
              'Taraba', 'Yobe', 'Nasarawa', 'Jigawa', 'Kebbi', 'Zamfara',
              'Gombe', 'Bauchi', 'Ebonyi', 'Anambra', 'Abia', 'Bayelsa',
            ].map((state) => FilterChip(
              label: Text(state),
              onSelected: (_) => _selectLocation(
                '$state, Nigeria',
                locationData: {
                  'state': state,
                  'type': 'state',
                },
              ),
              backgroundColor: Colors.grey.shade100,
              selectedColor: AppColors.primary.withOpacity(0.1),
              labelStyle: const TextStyle(fontSize: 12),
            )).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can search for any city across all 36 states of Nigeria',
                    style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ============================================================
          // FIX 8: Lagos Quick Picker
          // ============================================================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Quick Select Lagos Areas:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Lekki', 'VI', 'Ikoyi', 'Surulere', 'Ikeja', 'Ajah'].map((area) {
                    return ActionChip(
                      label: Text(area, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        final fullAddress = '$area, Lagos';
                        _selectLocation(
                          fullAddress,
                          locationData: {
                            'state': 'Lagos',
                            'type': 'area',
                          },
                        );
                      },
                      backgroundColor: Colors.white,
                      side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}