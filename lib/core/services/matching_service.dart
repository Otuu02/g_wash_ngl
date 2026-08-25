// lib/core/services/matching_service.dart
// PURPOSE: Find and assign nearby washers to jobs using Firebase

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

class MatchingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // FIND NEARBY WASHERS
  // ============================================================
  Future<List<Map<String, dynamic>>> findNearbyWashers({
    required String serviceCategory,
    required double lat,
    required double lng,
    double radiusKm = 9999.0,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('washers')
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final List<Map<String, dynamic>> nearbyWashers = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        if (!_isCategoryMatch(data, serviceCategory)) {
          continue;
        }

        final washerLat = (data['currentLat'] ?? data['latitude'] ?? 0.0) as double;
        final washerLng = (data['currentLng'] ?? data['longitude'] ?? 0.0) as double;
        
        final distance = _calculateDistance(lat, lng, washerLat, washerLng);
        
        nearbyWashers.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'phone': data['phone'] ?? 'No phone',
          'city': data['city'] ?? 'No city',
          'state': data['state'] ?? 'No state',
          'rating': data['rating'] ?? 4.8,
          'distance': distance,
          'distanceDisplay': '${distance.toStringAsFixed(1)} km',
          'eta': _calculateEta(distance),
          'isOnline': data['isOnline'] ?? true,
          'approved': data['approved'] ?? true,
          'totalJobs': data['totalJobs'] ?? 0,
          'workingRadius': data['workingRadius'] ?? 999,
        });
      }

      // Fallback: if category filter returns empty, return all washers
      if (nearbyWashers.isEmpty) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final washerLat = (data['currentLat'] ?? data['latitude'] ?? 0.0) as double;
          final washerLng = (data['currentLng'] ?? data['longitude'] ?? 0.0) as double;
          final distance = _calculateDistance(lat, lng, washerLat, washerLng);
          nearbyWashers.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'phone': data['phone'] ?? 'No phone',
            'city': data['city'] ?? 'No city',
            'state': data['state'] ?? 'No state',
            'rating': data['rating'] ?? 4.8,
            'distance': distance,
            'distanceDisplay': '${distance.toStringAsFixed(1)} km',
            'eta': _calculateEta(distance),
            'isOnline': data['isOnline'] ?? true,
            'approved': data['approved'] ?? true,
            'totalJobs': data['totalJobs'] ?? 0,
            'workingRadius': data['workingRadius'] ?? 999,
          });
        }
      }

      nearbyWashers.sort((a, b) => a['distance'].compareTo(b['distance']));

      return nearbyWashers;
    } catch (e) {
      debugPrint('❌ Error finding nearby washers: $e');
      return [];
    }
  }

  // ============================================================
  // ASSIGN WASHER TO JOB
  // ============================================================
  Future<void> assignWasherToJob({
    required String jobId,
    required String washerId,
  }) async {
    try {
      // Get washer details
      final washerDoc = await _firestore.collection('washers').doc(washerId).get();
      if (!washerDoc.exists) {
        throw Exception('Washer not found');
      }
      
      final washerData = washerDoc.data()!;
      
      // Update job
      await _firestore.collection('jobs').doc(jobId).update({
        'washerId': washerId,
        'washerName': washerData['name'] ?? 'Unknown',
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });
      
      // Update washer stats
      await _firestore.collection('washers').doc(washerId).update({
        'pendingJobs': FieldValue.increment(1),
        'lastJobAssigned': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ Washer $washerId assigned to job $jobId');
    } catch (e) {
      debugPrint('❌ Error assigning washer: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET JOB DETAILS
  // ============================================================
  Future<Map<String, dynamic>?> getJobDetails(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting job details: $e');
      return null;
    }
  }

  // ============================================================
  // UPDATE JOB STATUS
  // ============================================================
  Future<void> updateJobStatus({
    required String jobId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add additional data if provided
      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _firestore.collection('jobs').doc(jobId).update(updateData);
      debugPrint('✅ Job $jobId status updated to $status');
    } catch (e) {
      debugPrint('❌ Error updating job status: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET WASHER CURRENT JOBS
  // ============================================================
  Future<List<Map<String, dynamic>>> getWasherActiveJobs(String washerId) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('washerId', isEqualTo: washerId)
          .where('status', whereIn: ['assigned', 'accepted', 'enRoute'])
          .orderBy('assignedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting washer jobs: $e');
      return [];
    }
  }

  // ============================================================
  // GET CUSTOMER ACTIVE JOB
  // ============================================================
  Future<Map<String, dynamic>?> getCustomerActiveJob(String customerId) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('customerId', isEqualTo: customerId)
          .where('status', whereIn: ['searching', 'assigned', 'accepted', 'enRoute'])
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'id': snapshot.docs.first.id,
          ...snapshot.docs.first.data(),
        };
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting customer active job: $e');
      return null;
    }
  }

  // ============================================================
  // GET WASHER PENDING JOBS (For Job Request Screen)
  // ============================================================
  Future<List<Map<String, dynamic>>> getPendingJobs({
    required String serviceCategory,
    double radiusKm = 10.0,
  }) async {
    try {
      // Get all searching jobs
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'searching')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Filter by category
      final List<Map<String, dynamic>> pendingJobs = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final jobCategory = data['serviceCategory'] ?? '';
        
        if (jobCategory == serviceCategory || serviceCategory == 'All') {
          pendingJobs.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      return pendingJobs;
    } catch (e) {
      debugPrint('❌ Error getting pending jobs: $e');
      return [];
    }
  }

  // ============================================================
  // CANCEL JOB
  // ============================================================
  Future<void> cancelJob({
    required String jobId,
    required String cancelledBy,
  }) async {
    try {
      // Get job details to update washer stats
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (jobDoc.exists) {
        final washerId = jobDoc.data()?['washerId'];
        if (washerId != null && washerId.isNotEmpty) {
          // Update washer pending jobs count
          await _firestore.collection('washers').doc(washerId).update({
            'pendingJobs': FieldValue.increment(-1),
          });
        }
      }

      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'cancelled',
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Job $jobId cancelled by $cancelledBy');
    } catch (e) {
      debugPrint('❌ Error cancelling job: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET WASHER STATS
  // ============================================================
  Future<Map<String, dynamic>> getWasherStats(String washerId) async {
    try {
      final doc = await _firestore.collection('washers').doc(washerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'totalJobs': data['totalJobs'] ?? 0,
          'totalEarnings': data['totalEarnings'] ?? 0,
          'rating': data['rating'] ?? 0.0,
          'pendingJobs': data['pendingJobs'] ?? 0,
          'todayEarnings': data['todayEarnings'] ?? 0,
        };
      }
      return {
        'totalJobs': 0,
        'totalEarnings': 0,
        'rating': 0.0,
        'pendingJobs': 0,
        'todayEarnings': 0,
      };
    } catch (e) {
      debugPrint('❌ Error getting washer stats: $e');
      return {
        'totalJobs': 0,
        'totalEarnings': 0,
        'rating': 0.0,
        'pendingJobs': 0,
        'todayEarnings': 0,
      };
    }
  }

  // ============================================================
  // UPDATE WASHER STATS ON JOB COMPLETION
  // ============================================================
  Future<void> updateWasherStatsOnCompletion({
    required String washerId,
    required int amount,
  }) async {
    try {
      await _firestore.collection('washers').doc(washerId).update({
        'totalJobs': FieldValue.increment(1),
        'totalEarnings': FieldValue.increment(amount),
        'pendingJobs': FieldValue.increment(-1),
        'todayEarnings': FieldValue.increment(amount),
      });
      debugPrint('✅ Washer $washerId stats updated');
    } catch (e) {
      debugPrint('❌ Error updating washer stats: $e');
      rethrow;
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = 
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * 3.141592653589793 / 180;
  }

  // Calculate ETA based on distance (average speed: 20 km/h)
  String _calculateEta(double distance) {
    if (distance <= 0) return '5 mins';
    final double speed = 20; // km/h
    final double timeHours = distance / speed;
    final int timeMinutes = (timeHours * 60).round();
    return '${timeMinutes.clamp(5, 60)} mins';
  }

  bool _isCategoryMatch(Map<String, dynamic> data, String selectedCategory) {
    if (selectedCategory.trim().isEmpty ||
        selectedCategory.toLowerCase().trim() == 'all' ||
        selectedCategory.toLowerCase().trim() == 'any' ||
        selectedCategory.toLowerCase().trim() == 'general') {
      return true;
    }

    final target = selectedCategory.toLowerCase().trim();

    bool checkString(String str) {
      if (str.isEmpty) return false;
      final s = str.toLowerCase().trim();
      if (s == target) return true;
      if (target.contains(s) || s.contains(target)) return true;

      if ((target.contains('car') || target.contains('wash') || target.contains('auto') || target.contains('detail')) &&
          (s.contains('car') || s.contains('wash') || s.contains('auto') || s.contains('detail'))) {
        return true;
      }
      if ((target.contains('clean') || target.contains('house') || target.contains('home') || target.contains('maid') || target.contains('fumig') || target.contains('sofa')) &&
          (s.contains('clean') || s.contains('house') || s.contains('home') || s.contains('maid') || s.contains('fumig') || s.contains('sofa'))) {
        return true;
      }
      if ((target.contains('laundry') || target.contains('dry') || target.contains('cloth') || target.contains('iron')) &&
          (s.contains('laundry') || s.contains('dry') || s.contains('cloth') || s.contains('iron'))) {
        return true;
      }
      if ((target.contains('ride') || target.contains('drive') || target.contains('cab') || target.contains('taxi') || target.contains('transport')) &&
          (s.contains('ride') || s.contains('drive') || s.contains('cab') || s.contains('taxi') || s.contains('transport') || s.contains('driver'))) {
        return true;
      }
      return false;
    }

    final singleFields = ['serviceCategory', 'category', 'service_category', 'serviceType', 'mainCategory', 'workCategory', 'role', 'userType'];
    for (final field in singleFields) {
      if (data[field] != null && checkString(data[field].toString())) return true;
    }

    final listFields = ['mainCategoryNames', 'selectedMainCategories', 'mainCategories', 'serviceCategories', 'selectedServices', 'categories', 'services'];
    bool foundCategoryField = false;

    for (final field in listFields) {
      final list = data[field];
      if (list != null) {
        if (list is List && list.isNotEmpty) {
          foundCategoryField = true;
          for (var item in list) {
            if (item != null && checkString(item.toString())) return true;
          }
        } else if (list is String && list.trim().isNotEmpty) {
          foundCategoryField = true;
          if (checkString(list)) return true;
        }
      }
    }

    final subServices = data['subServices'] ?? data['selectedSubServices'] ?? data['subServicePrices'];
    if (subServices is Map && subServices.isNotEmpty) {
      foundCategoryField = true;
      for (var key in subServices.keys) {
        if (checkString(key.toString())) return true;
      }
    } else if (subServices is List && subServices.isNotEmpty) {
      foundCategoryField = true;
      for (var item in subServices) {
        if (item != null && checkString(item.toString())) return true;
      }
    }

    if (!foundCategoryField && (data['serviceCategory'] == null || data['serviceCategory'].toString().trim().isEmpty)) {
      return true;
    }

    return false;
  }

  // Update washer location
  Future<void> updateWasherLocation({
    required String washerId,
    required double lat,
    required double lng,
  }) async {
    try {
      await _firestore.collection('washers').doc(washerId).update({
        'currentLat': lat,
        'currentLng': lng,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error updating washer location: $e');
    }
  }
}