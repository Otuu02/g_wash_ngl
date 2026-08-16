// FILE: lib/presentation/screens/customer/map_screen.dart
// PURPOSE: Map screen for selecting location using Google Maps

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';

class MapScreen extends StatefulWidget {
  final Function(String, LatLng)? onLocationSelected;

  const MapScreen({super.key, this.onLocationSelected});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(6.5244, 3.3792); // Default: Lagos
  LatLng _selectedPosition = const LatLng(6.5244, 3.3792);
  String _selectedAddress = 'Lekki Phase 1, Lagos';
  bool _isLoading = true;
  bool _isDragging = false;

  // Map style - Custom style (optional)
  final Set<Marker> _markers = {};
  
  // Nigerian cities with coordinates for quick selection
  final List<Map<String, dynamic>> _quickLocations = [
    {'name': 'Lekki Phase 1', 'lat': 6.4369, 'lng': 3.4525},
    {'name': 'Victoria Island', 'lat': 6.4292, 'lng': 3.4199},
    {'name': 'Ikoyi', 'lat': 6.4565, 'lng': 3.4350},
    {'name': 'Surulere', 'lat': 6.5030, 'lng': 3.3486},
    {'name': 'Ikeja', 'lat': 6.6022, 'lng': 3.3574},
    {'name': 'Ajah', 'lat': 6.4738, 'lng': 3.5691},
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ============================================================
  // FIX 1: Get real current location using GPS
  // ============================================================
  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // Check permissions
      final permission = await Permission.location.request();
      if (permission.isGranted) {
        // Check if location services are enabled
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showEnableLocationDialog();
          setState(() => _isLoading = false);
          return;
        }

        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _selectedPosition = _currentPosition;
          _isLoading = false;
        });

        // Get address from coordinates
        String address = await _getAddressFromCoords(
          position.latitude,
          position.longitude,
        );
        setState(() {
          _selectedAddress = address;
        });

        // Add marker at current position
        _addMarker(_currentPosition, 'Your Location');

        // Move camera to current position
        _moveCamera(_currentPosition, 15);

        debugPrint('✅ Current location: $_selectedAddress');
      } else {
        // Permission denied - use default Lagos
        setState(() => _isLoading = false);
        _showPermissionDialog();
      }
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      setState(() => _isLoading = false);
      // Use default location
      _addMarker(_currentPosition, 'Lekki Phase 1, Lagos');
    }
  }

  // ============================================================
  // FIX 2: Get address from coordinates using offline data
  // ============================================================
  Future<String> _getAddressFromCoords(double lat, double lng) async {
    // Find nearest city from our database
    String nearestCity = 'Lagos, Nigeria';
    double minDistance = double.infinity;

    // Lagos coordinates for reference
    final List<Map<String, dynamic>> cities = [
      {'name': 'Lekki Phase 1, Lagos', 'lat': 6.4369, 'lng': 3.4525},
      {'name': 'Victoria Island, Lagos', 'lat': 6.4292, 'lng': 3.4199},
      {'name': 'Ikoyi, Lagos', 'lat': 6.4565, 'lng': 3.4350},
      {'name': 'Surulere, Lagos', 'lat': 6.5030, 'lng': 3.3486},
      {'name': 'Ikeja, Lagos', 'lat': 6.6022, 'lng': 3.3574},
      {'name': 'Ajah, Lagos', 'lat': 6.4738, 'lng': 3.5691},
      {'name': 'Abuja, FCT', 'lat': 9.0765, 'lng': 7.3986},
      {'name': 'Port Harcourt, Rivers', 'lat': 4.8156, 'lng': 7.0498},
      {'name': 'Ibadan, Oyo', 'lat': 7.3776, 'lng': 3.9470},
    ];

    for (var city in cities) {
      double cityLat = city['lat'] as double;
      double cityLng = city['lng'] as double;
      double distance = _calculateDistance(lat, lng, cityLat, cityLng);

      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = city['name'] as String;
      }
    }

    // If within 10km of a city, use that city
    if (minDistance < 10) {
      return nearestCity;
    }

    return 'Your Location, Lagos';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in km
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    double a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_degreesToRadians(lat1)) * _cos(_degreesToRadians(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);
    double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return R * c;
  }

  double _degreesToRadians(double degrees) => degrees * 3.141592653589793 / 180;
  double _sin(double x) => x - x * x * x / 6 + x * x * x * x * x / 120;
  double _cos(double x) => 1 - x * x / 2 + x * x * x * x / 24;
  double _sqrt(double x) => x > 0 ? x / (1 + x) : 0;
  double _atan2(double y, double x) => y / x; // Simplified

  void _addMarker(LatLng position, String title) {
    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          infoWindow: InfoWindow(title: title),
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _selectedPosition = newPosition;
              _isDragging = false;
              _getAddressFromCoords(newPosition.latitude, newPosition.longitude)
                  .then((address) {
                setState(() {
                  _selectedAddress = address;
                });
              });
            });
          },
        ),
      );
    });
  }

  void _moveCamera(LatLng position, double zoom) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
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
        content: const Text('Please grant location permission to use the map.'),
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
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _moveCamera(_currentPosition, 14);
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _selectedPosition = position.target;
    });
  }

  void _onCameraIdle() {
    // When camera stops moving, update the address
    if (_selectedPosition != _currentPosition) {
      _getAddressFromCoords(_selectedPosition.latitude, _selectedPosition.longitude)
          .then((address) {
        setState(() {
          _selectedAddress = address;
          _addMarker(_selectedPosition, address);
        });
      });
    }
  }

  void _confirmLocation() {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(_selectedAddress, _selectedPosition);
    }
    Navigator.pop(context, {
      'address': _selectedAddress,
      'lat': _selectedPosition.latitude,
      'lng': _selectedPosition.longitude,
    });
  }

  void _moveToQuickLocation(String name, double lat, double lng) {
    final position = LatLng(lat, lng);
    setState(() {
      _selectedPosition = position;
      _selectedAddress = '$name, Lagos';
      _addMarker(position, '$name, Lagos');
    });
    _moveCamera(position, 15);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Location',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: const Text(
              'Confirm',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            )
          : Column(
              children: [
                // ============================================================
                // FIX 3: Address display
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              _selectedAddress,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _getCurrentLocation,
                        icon: const Icon(Icons.my_location, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // FIX 4: Google Map
                // ============================================================
                Expanded(
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    markers: _markers,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    mapType: MapType.normal,
                  ),
                ),

                // ============================================================
                // FIX 5: Quick location chips
                // ============================================================
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: const Text(
                          'Quick Select',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: _quickLocations.map((location) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(location['name'] as String),
                                onSelected: (_) => _moveToQuickLocation(
                                  location['name'] as String,
                                  location['lat'] as double,
                                  location['lng'] as double,
                                ),
                                backgroundColor: Colors.grey.shade100,
                                selectedColor: AppColors.primary.withOpacity(0.1),
                                labelStyle: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // FIX 6: Confirm button
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _confirmLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}