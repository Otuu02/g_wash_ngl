import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/env.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _currentAddress;
  String? _currentCity;
  String? _currentState;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Dynamic Google Maps API Key supporting --dart-define GOOGLE_MAPS_API_KEY=...
  static String get GOOGLE_MAPS_API_KEY => Env.googleMapsApiKey;
  
  // API URLs
  static const String GEOCODE_API_URL = 'https://maps.googleapis.com/maps/api/geocode/json';
  static const String PLACES_API_URL = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
  static const String PLACE_DETAILS_URL = 'https://maps.googleapis.com/maps/api/place/details/json';
  static const String DISTANCE_MATRIX_URL = 'https://maps.googleapis.com/maps/api/distancematrix/json';
  static const String DIRECTIONS_API_URL = 'https://maps.googleapis.com/maps/api/directions/json';

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get currentAddress => _currentAddress;
  String? get currentCity => _currentCity;
  String? get currentState => _currentState;

  // ==================== LOCATION PERMISSIONS & GPS ====================
  
  Future<Position> getCurrentLocation() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      
      // Get address and update location in Firestore
      await getAddressFromLatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
      
      // Update user's location in Firestore if logged in
      await _updateUserLocationInFirestore();
      
      _isLoading = false;
      notifyListeners();
      return _currentPosition!;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Update user location in Firestore
  Future<void> _updateUserLocationInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentPosition != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'currentLat': _currentPosition!.latitude,
          'currentLng': _currentPosition!.longitude,
          'currentAddress': _currentAddress,
          'currentCity': _currentCity,
          'currentState': _currentState,
          'lastLocationUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('âŒ Error updating location in Firestore: $e');
    }
  }

  // Update washer location in Firestore (for real-time tracking)
  Future<void> updateWasherLocation({
    required String washerId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _firestore.collection('washers').doc(washerId).update({
        'currentLat': latitude,
        'currentLng': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('âŒ Error updating washer location: $e');
    }
  }

  // Start continuous location tracking (for live tracking)
  Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  // Stream washer position from Firestore for live map updates
  Stream<DocumentSnapshot<Map<String, dynamic>>> getWasherLocationStream(String washerId) {
    return _firestore.collection('washers').doc(washerId).snapshots();
  }

  // ==================== GOOGLE MAPS GEOCODING ====================
  
  Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      final encodedAddress = Uri.encodeComponent(address);
      final response = await http.get(
        Uri.parse('$GEOCODE_API_URL?address=$encodedAddress&key=$GOOGLE_MAPS_API_KEY'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return LatLng(location['lat'], location['lng']);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
  }
  
  // Convert coordinates to address (Reverse Geocoding)
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      final response = await http.get(
        Uri.parse('$GEOCODE_API_URL?latlng=$lat,$lng&key=$GOOGLE_MAPS_API_KEY'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          _currentAddress = result['formatted_address'];
          
          // Extract city and state from address components
          _currentCity = _extractAddressComponent(result, ['locality', 'administrative_area_level_2']);
          _currentState = _extractAddressComponent(result, ['administrative_area_level_1']);
          
          notifyListeners();
          return _currentAddress!;
        }
      }
      
      // Fallback to OpenStreetMap / BigDataCloud free reverse geocoding
      final osmResponse = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng'),
        headers: {'User-Agent': 'GWashNG/1.0'},
      );
      if (osmResponse.statusCode == 200) {
        final osmData = jsonDecode(osmResponse.body);
        final displayName = osmData['display_name'];
        if (displayName != null && displayName.toString().isNotEmpty) {
          _currentAddress = displayName.toString();
          notifyListeners();
          return _currentAddress!;
        }
      }

      return 'Lagos, Nigeria';
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      return 'Lagos, Nigeria';
    }
  }
  
  String? _extractAddressComponent(Map<String, dynamic> result, List<String> types) {
    final components = result['address_components'] as List?;
    if (components == null) return null;
    
    for (var component in components) {
      final componentTypes = component['types'] as List?;
      if (componentTypes != null) {
        for (var type in types) {
          if (componentTypes.contains(type)) {
            return component['long_name'];
          }
        }
      }
    }
    return null;
  }

  // ==================== PLACES AUTOCOMPLETE ====================
  
  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.length < 2) return [];
    
    try {
      final response = await http.get(
        Uri.parse('$PLACES_API_URL?input=$query&key=$GOOGLE_MAPS_API_KEY&components=country:ng'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Places search error: $e');
      return [];
    }
  }
  
  Future<Map<String, dynamic>?> getPlaceDetails(String placeId) async {
    try {
      final response = await http.get(
        Uri.parse('$PLACE_DETAILS_URL?place_id=$placeId&key=$GOOGLE_MAPS_API_KEY'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK') {
          return data['result'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Place details error: $e');
      return null;
    }
  }

  // ==================== DISTANCE & ETA CALCULATIONS ====================
  
  Future<Map<String, dynamic>?> getDistanceAndDuration(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$DISTANCE_MATRIX_URL?origins=${origin.latitude},${origin.longitude}&destinations=${destination.latitude},${destination.longitude}&key=$GOOGLE_MAPS_API_KEY'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['rows'].isNotEmpty) {
          final element = data['rows'][0]['elements'][0];
          if (element['status'] == 'OK') {
            return {
              'distance': element['distance']['text'],
              'distanceValue': element['distance']['value'], // in meters
              'duration': element['duration']['text'],
              'durationValue': element['duration']['value'], // in seconds
            };
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Distance matrix error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$DIRECTIONS_API_URL?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$GOOGLE_MAPS_API_KEY'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          return data['routes'][0];
        }
      }
      return null;
    } catch (e) {
      debugPrint('Directions error: $e');
      return null;
    }
  }
  
  // Decode polyline points for drawing route
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  // ==================== STATIC HELPER METHODS ====================
  
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
  
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
  
  static String formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
  
  static String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    }
    final minutes = seconds ~/ 60;
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $remainingMinutes min';
  }
  
  static Map<String, dynamic>? findNearestProvider(
    Position userLocation,
    List<Map<String, dynamic>> providers,
  ) {
    if (providers.isEmpty) return null;
    
    Map<String, dynamic>? nearestProvider;
    double minDistance = double.infinity;

    for (var provider in providers) {
      final distance = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        provider['latitude'] ?? provider['geometry']?['location']?['lat'] ?? 0,
        provider['longitude'] ?? provider['geometry']?['location']?['lng'] ?? 0,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestProvider = {...provider, 'distance': distance, 'distanceFormatted': formatDistance(distance)};
      }
    }
    
    return nearestProvider;
  }

  // ==================== AUTOCOMPLETE SUGGESTIONS ====================
  
  Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(String input) async {
    if (input.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse('$PLACES_API_URL?input=$input&key=$GOOGLE_MAPS_API_KEY&components=country:ng'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['predictions'] != null) {
          return List<Map<String, dynamic>>.from(data['predictions']);
        }
      }
      return [];
    } catch (e) {
      debugPrint('Autocomplete error: $e');
      return [];
    }
  }

  // ==================== FIREBASE LOCATION HELPERS ====================
  
  // Save location to Firestore
  Future<void> saveLocationToFirestore({
    required String userId,
    required double lat,
    required double lng,
    String? address,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'savedLocation': {
          'lat': lat,
          'lng': lng,
          'address': address ?? _currentAddress,
          'city': _currentCity,
          'state': _currentState,
          'savedAt': FieldValue.serverTimestamp(),
        }
      });
    } catch (e) {
      debugPrint('âŒ Error saving location to Firestore: $e');
    }
  }
  
  // Get saved location from Firestore
  Future<Map<String, dynamic>?> getSavedLocation(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['savedLocation'];
      }
      return null;
    } catch (e) {
      debugPrint('âŒ Error getting saved location: $e');
      return null;
    }
  }
}