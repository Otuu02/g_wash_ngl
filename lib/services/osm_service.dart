// FILE: lib/services/osm_service.dart
// PURPOSE: FREE OpenStreetMap Nominatim API for location search across Nigeria
// No API key required! Works as a fallback when Google Maps quota is exceeded.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class OSMService {
  static const String NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';
  static const String REVERSE_URL = 'https://nominatim.openstreetmap.org/reverse';
  static const String DETAILS_URL = 'https://nominatim.openstreetmap.org/details';
  
  /// Search for addresses in Nigeria (FREE fallback when Google Maps quota exceeded)
  static Future<List<Map<String, dynamic>>> searchInNigeria(String query) async {
    if (query.length < 3) return [];
    
    try {
      final response = await http.get(
        Uri.parse(
          '$NOMINATIM_URL?q=${Uri.encodeComponent(query)}&countrycodes=ng&format=json&limit=20&addressdetails=1&namedetails=1'
        ),
        headers: {
          'User-Agent': 'GwashNG/1.0 (contact@gwashng.com)', // Updated email
          'Accept-Language': 'en-NG,en',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((place) => _formatPlaceResult(place)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('OSM search error: $e');
      return [];
    }
  }
  
  /// Search for Nigerian cities and towns by name
  static Future<List<Map<String, dynamic>>> searchCity(String cityName) async {
    if (cityName.isEmpty) return [];
    
    try {
      final response = await http.get(
        Uri.parse(
          '$NOMINATIM_URL?q=${Uri.encodeComponent(cityName)}&countrycodes=ng&format=json&limit=10&featuretype=city&addressdetails=1'
        ),
        headers: {'User-Agent': 'GwashNG/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((place) => _formatPlaceResult(place)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('OSM city search error: $e');
      return [];
    }
  }
  
  /// Search for streets and landmarks in Nigeria
  static Future<List<Map<String, dynamic>>> searchStreet(String streetName, {String? city}) async {
    if (streetName.length < 3) return [];
    
    String query = streetName;
    if (city != null && city.isNotEmpty) {
      query = '$streetName, $city';
    }
    
    try {
      final response = await http.get(
        Uri.parse(
          '$NOMINATIM_URL?q=${Uri.encodeComponent(query)}&countrycodes=ng&format=json&limit=15&addressdetails=1'
        ),
        headers: {'User-Agent': 'GwashNG/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((place) => _formatPlaceResult(place)).toList();
      }
      return [];
    } catch (e) {
      print('OSM street search error: $e');
      return [];
    }
  }
  
  /// Search for businesses and services in Nigeria
  static Future<List<Map<String, dynamic>>> searchNearby({
    required double lat,
    required double lon,
    String query = '',
    int radius = 5000, // meters
  }) async {
    try {
      String url = '$NOMINATIM_URL?q=${Uri.encodeComponent(query)}&format=json&limit=20&bounded=1&viewbox=${lon - (radius/111320)},${lat - (radius/111320)},${lon + (radius/111320)},${lat + (radius/111320)}';
      if (query.isEmpty) {
        url = '$NOMINATIM_URL?format=json&limit=20&bounded=1&viewbox=${lon - (radius/111320)},${lat - (radius/111320)},${lon + (radius/111320)},${lat + (radius/111320)}';
      }
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'GwashNG/1.0'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((place) => _formatPlaceResult(place)).toList();
      }
      return [];
    } catch (e) {
      print('OSM nearby search error: $e');
      return [];
    }
  }
  
  /// Get address from coordinates (Reverse Geocoding)
  static Future<Map<String, dynamic>?> getAddressFromCoordinates(double lat, double lon) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$REVERSE_URL?lat=$lat&lon=$lon&format=json&addressdetails=1'
        ),
        headers: {'User-Agent': 'GwashNG/1.0'},
      );
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return _formatReverseResult(data);
      }
      return null;
    } catch (e) {
      print('OSM reverse geocoding error: $e');
      return null;
    }
  }
  
  /// Get details for a specific location by OSM ID
  static Future<Map<String, dynamic>?> getPlaceDetails(String osmType, int osmId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$DETAILS_URL?osmtype=$osmType&osmid=$osmId&format=json'
        ),
        headers: {'User-Agent': 'GwashNG/1.0'},
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('OSM place details error: $e');
      return null;
    }
  }
  
  /// Get all major Nigerian cities and states
  static Future<List<Map<String, dynamic>>> getAllNigerianStates() async {
    final List<Map<String, dynamic>> states = [];
    
    final List<String> nigerianStates = [
      'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue',
      'Borno', 'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT',
      'Gombe', 'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi',
      'Kwara', 'Lagos', 'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo',
      'Plateau', 'Rivers', 'Sokoto', 'Taraba', 'Yobe', 'Zamfara'
    ];
    
    for (String state in nigerianStates) {
      final results = await searchCity(state);
      if (results.isNotEmpty) {
        states.add({
          'name': state,
          'display_name': '$state State, Nigeria',
          'lat': results.first['lat'],
          'lon': results.first['lon'],
        });
      }
    }
    
    return states;
  }
  
  /// Format place result for consistent output
  static Map<String, dynamic> _formatPlaceResult(dynamic place) {
    final address = place['address'] ?? {};
    final name = place['name'] ?? '';
    final displayName = place['display_name'] ?? '';
    
    // Extract Nigerian address components
    String city = address['city'] ?? address['town'] ?? address['village'] ?? '';
    String state = address['state'] ?? '';
    String country = address['country'] ?? 'Nigeria';
    String postcode = address['postcode'] ?? '';
    String road = address['road'] ?? '';
    String suburb = address['suburb'] ?? '';
    String neighbourhood = address['neighbourhood'] ?? '';
    
    // Build short address
    String shortAddress = name.isNotEmpty ? name : road;
    if (city.isNotEmpty && !shortAddress.contains(city)) {
      shortAddress = shortAddress.isNotEmpty ? '$shortAddress, $city' : city;
    }
    if (state.isNotEmpty && !shortAddress.contains(state)) {
      shortAddress = '$shortAddress, $state';
    }
    
    return {
      'description': displayName,
      'shortAddress': shortAddress,
      'fullAddress': displayName,
      'lat': double.parse(place['lat'].toString()),
      'lon': double.parse(place['lon'].toString()),
      'place_id': place['place_id'],
      'osm_id': place['osm_id'],
      'osm_type': place['osm_type'],
      'type': place['type'],
      'category': place['category'],
      'city': city,
      'state': state,
      'country': country,
      'postcode': postcode,
      'road': road,
      'suburb': suburb,
      'neighbourhood': neighbourhood,
    };
  }
  
  /// Format reverse geocoding result
  static Map<String, dynamic> _formatReverseResult(Map<String, dynamic> data) {
    final address = data['address'] ?? {};
    
    return {
      'display_name': data['display_name'] ?? '',
      'lat': double.parse(data['lat'].toString()),
      'lon': double.parse(data['lon'].toString()),
      'city': address['city'] ?? address['town'] ?? address['village'] ?? '',
      'state': address['state'] ?? '',
      'country': address['country'] ?? 'Nigeria',
      'postcode': address['postcode'] ?? '',
      'road': address['road'] ?? '',
      'suburb': address['suburb'] ?? '',
      'neighbourhood': address['neighbourhood'] ?? '',
    };
  }
}

// ==================== LOCATION CACHE FOR OFFLINE USE ====================

class LocationCache {
  static final Map<String, Map<String, dynamic>> _cache = {};
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static void cacheLocation(String query, List<Map<String, dynamic>> results) {
    _cache[query.toLowerCase()] = {
      'results': results,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  static List<Map<String, dynamic>>? getCachedLocation(String query) {
    final cached = _cache[query.toLowerCase()];
    if (cached != null) {
      final age = DateTime.now().millisecondsSinceEpoch - cached['timestamp'];
      // Cache valid for 24 hours
      if (age < 24 * 60 * 60 * 1000) {
        return List<Map<String, dynamic>>.from(cached['results']);
      }
    }
    return null;
  }
  
  static void clearCache() {
    _cache.clear();
  }
  
  // Save to Firestore cache (for persistence across sessions)
  static Future<void> saveToFirestore(String query, List<Map<String, dynamic>> results) async {
    try {
      await _firestore.collection('location_cache').doc(query.toLowerCase()).set({
        'query': query.toLowerCase(),
        'results': results,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error saving to Firestore cache: $e');
    }
  }
  
  static Future<List<Map<String, dynamic>>?> getFromFirestore(String query) async {
    try {
      final doc = await _firestore.collection('location_cache').doc(query.toLowerCase()).get();
      if (doc.exists) {
        final data = doc.data()!;
        final age = DateTime.now().millisecondsSinceEpoch - 
            (data['timestamp'] as Timestamp).millisecondsSinceEpoch;
        if (age < 24 * 60 * 60 * 1000) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting from Firestore cache: $e');
      return null;
    }
  }
}

// ==================== NIGERIAN LOCATIONS DATABASE ====================

class NigerianLocations {
  // Major Nigerian cities with coordinates
  static final List<Map<String, dynamic>> majorCities = [
    {'name': 'Lagos', 'state': 'Lagos', 'lat': 6.5244, 'lon': 3.3792},
    {'name': 'Abuja', 'state': 'FCT', 'lat': 9.0765, 'lon': 7.3986},
    {'name': 'Kano', 'state': 'Kano', 'lat': 12.0000, 'lon': 8.5167},
    {'name': 'Port Harcourt', 'state': 'Rivers', 'lat': 4.8156, 'lon': 7.0498},
    {'name': 'Ibadan', 'state': 'Oyo', 'lat': 7.3775, 'lon': 3.9470},
    {'name': 'Kaduna', 'state': 'Kaduna', 'lat': 10.5167, 'lon': 7.4333},
    {'name': 'Benin City', 'state': 'Edo', 'lat': 6.3176, 'lon': 5.6145},
    {'name': 'Enugu', 'state': 'Enugu', 'lat': 6.4500, 'lon': 7.5000},
    {'name': 'Aba', 'state': 'Abia', 'lat': 5.1167, 'lon': 7.3667},
    {'name': 'Jos', 'state': 'Plateau', 'lat': 9.8965, 'lon': 8.8583},
    {'name': 'Maiduguri', 'state': 'Borno', 'lat': 11.8333, 'lon': 13.1500},
    {'name': 'Sokoto', 'state': 'Sokoto', 'lat': 13.0167, 'lon': 5.2500},
    {'name': 'Calabar', 'state': 'Cross River', 'lat': 4.9583, 'lon': 8.3250},
    {'name': 'Warri', 'state': 'Delta', 'lat': 5.5167, 'lon': 5.7500},
    {'name': 'Uyo', 'state': 'Akwa Ibom', 'lat': 5.0333, 'lon': 7.9167},
    {'name': 'Abeokuta', 'state': 'Ogun', 'lat': 7.1500, 'lon': 3.3500},
    {'name': 'Owerri', 'state': 'Imo', 'lat': 5.4833, 'lon': 7.0333},
    {'name': 'Akure', 'state': 'Ondo', 'lat': 7.2500, 'lon': 5.1950},
    {'name': 'Minna', 'state': 'Niger', 'lat': 9.6139, 'lon': 6.5569},
    {'name': 'Makurdi', 'state': 'Benue', 'lat': 7.7337, 'lon': 8.5412},
  ];
  
  // Lagos specific areas
  static final List<Map<String, dynamic>> lagosAreas = [
    {'name': 'Lekki Phase 1', 'lat': 6.4531, 'lon': 3.8991},
    {'name': 'Lekki Phase 2', 'lat': 6.4700, 'lon': 3.8800},
    {'name': 'Victoria Island', 'lat': 6.4281, 'lon': 3.4219},
    {'name': 'Ikoyi', 'lat': 6.4600, 'lon': 3.4360},
    {'name': 'Surulere', 'lat': 6.5017, 'lon': 3.3581},
    {'name': 'Ikeja', 'lat': 6.6018, 'lon': 3.3515},
    {'name': 'GRA', 'lat': 6.6050, 'lon': 3.3500},
    {'name': 'Ajah', 'lat': 6.4700, 'lon': 3.6800},
    {'name': 'Maryland', 'lat': 6.5840, 'lon': 3.3630},
    {'name': 'Yaba', 'lat': 6.4980, 'lon': 3.3730},
    {'name': 'Magodo', 'lat': 6.5980, 'lon': 3.4000},
    {'name': 'Ogudu', 'lat': 6.5900, 'lon': 3.3900},
    {'name': 'Ketu', 'lat': 6.5800, 'lon': 3.3800},
    {'name': 'Mile 12', 'lat': 6.5500, 'lon': 3.3500},
    {'name': 'Oshodi', 'lat': 6.5400, 'lon': 3.3400},
    {'name': 'Apapa', 'lat': 6.4500, 'lon': 3.3500},
    {'name': 'Mushin', 'lat': 6.5200, 'lon': 3.3300},
    {'name': 'Agege', 'lat': 6.6200, 'lon': 3.3100},
    {'name': 'Badagry', 'lat': 6.4100, 'lon': 2.8800},
    {'name': 'Epe', 'lat': 6.5800, 'lon': 3.9800},
  ];
  
  static List<Map<String, dynamic>> searchInDatabase(String query) {
    final lowerQuery = query.toLowerCase();
    final results = <Map<String, dynamic>>[];
    
    // Search in major cities
    for (var city in majorCities) {
      if (city['name'].toLowerCase().contains(lowerQuery)) {
        results.add({
          'description': '${city['name']}, ${city['state']} State, Nigeria',
          'shortAddress': city['name'],
          'lat': city['lat'],
          'lon': city['lon'],
          'type': 'city',
          'state': city['state'],
        });
      }
    }
    
    // Search in Lagos areas
    for (var area in lagosAreas) {
      if (area['name'].toLowerCase().contains(lowerQuery)) {
        results.add({
          'description': '${area['name']}, Lagos, Nigeria',
          'shortAddress': area['name'],
          'lat': area['lat'],
          'lon': area['lon'],
          'type': 'area',
          'state': 'Lagos',
        });
      }
    }
    
    return results;
  }
  
  // Get city suggestions
  static List<String> getCitySuggestions(String query) {
    final lowerQuery = query.toLowerCase();
    final results = <String>[];
    
    for (var city in majorCities) {
      if (city['name'].toLowerCase().contains(lowerQuery)) {
        results.add(city['name']);
      }
    }
    
    for (var area in lagosAreas) {
      if (area['name'].toLowerCase().contains(lowerQuery)) {
        results.add(area['name']);
      }
    }
    
    return results;
  }
  
  // Get state for a city
  static String? getStateForCity(String cityName) {
    for (var city in majorCities) {
      if (city['name'].toLowerCase() == cityName.toLowerCase()) {
        return city['state'];
      }
    }
    for (var area in lagosAreas) {
      if (area['name'].toLowerCase() == cityName.toLowerCase()) {
        return 'Lagos';
      }
    }
    return null;
  }
}