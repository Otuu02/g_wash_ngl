// lib/core/services/matching_service.dart
// PURPOSE: Find and assign nearby washers to jobs using Firebase

import 'package:cloud_firestore/cloud_firestore.dart';
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
      // Query washers that are approved by admin and online
      final snapshot = await _firestore
          .collection('washers')
          .where('approved', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      // Convert to list and calculate distance
      final List<Map<String, dynamic>> nearbyWashers = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Filter by requested service category
        if (!_isCategoryMatch(data, serviceCategory)) {
          continue;
        }

        final washerLat = data['currentLat'] ?? 0.0;
        final washerLng = data['currentLng'] ?? 0.0;
        
        final distance = _calculateDistance(lat, lng, washerLat, washerLng);
        
        nearbyWashers.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'phone': data['phone'] ?? 'No phone',
          'city': data['city'] ?? 'No city',
          'state': data['state'] ?? 'No state',
          'rating': data['rating'] ?? 0.0,
          'distance': distance,
          'distanceDisplay': '${distance.toStringAsFixed(1)} km',
          'eta': _calculateEta(distance),
          'isOnline': data['isOnline'] ?? false,
          'approved': data['approved'] ?? false,
          'totalJobs': data['totalJobs'] ?? 0,
          'workingRadius': data['workingRadius'] ?? 999,
        });
      }

      // Sort by distance (nearest first)
      nearbyWashers.sort((a, b) => a['distance'].compareTo(b['distance']));

      return nearbyWashers;
    } catch (e) {
      print('❌ Error finding nearby washers: $e');
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
      
      print('✅ Washer $washerId assigned to job $jobId');
    } catch (e) {
      print('❌ Error assigning washer: $e');
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
      print('❌ Error getting job details: $e');
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
      print('✅ Job $jobId status updated to $status');
    } catch (e) {
      print('❌ Error updating job status: $e');
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
      print('❌ Error getting washer jobs: $e');
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
      print('❌ Error getting customer active job: $e');
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
      print('❌ Error getting pending jobs: $e');
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

      print('✅ Job $jobId cancelled by $cancelledBy');
    } catch (e) {
      print('❌ Error cancelling job: $e');
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
      print('❌ Error getting washer stats: $e');
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
      print('✅ Washer $washerId stats updated');
    } catch (e) {
      print('❌ Error updating washer stats: $e');
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
    if (selectedCategory.isEmpty || selectedCategory.toLowerCase().trim() == 'all') return true;

    final target = selectedCategory.toLowerCase().trim();
    final serviceCat = (data['serviceCategory'] ?? '').toString().toLowerCase().trim();

    if (serviceCat.isNotEmpty) {
      if (serviceCat == target) return true;
      if (target.contains('car') && serviceCat.contains('car')) return true;
      if (target.contains('clean') && serviceCat.contains('clean')) return true;
      if (target.contains('laundry') && serviceCat.contains('laundry')) return true;
      if (target.contains('ride') && (serviceCat.contains('ride') || serviceCat.contains('driver'))) return true;
    }

    final cats = data['serviceCategories'] ?? data['selectedServices'];
    if (cats is List) {
      for (var item in cats) {
        final c = item.toString().toLowerCase().trim();
        if (c == target) return true;
        if (target.contains('car') && (c.contains('car') || c.contains('wash'))) return true;
        if (target.contains('clean') && c.contains('clean')) return true;
        if (target.contains('laundry') && c.contains('laundry')) return true;
        if (target.contains('ride') && (c.contains('ride') || c.contains('driver'))) return true;
      }
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
      print('❌ Error updating washer location: $e');
    }
  }
}