import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobService extends ChangeNotifier {
  static final JobService _instance = JobService._internal();
  factory JobService() => _instance;
  JobService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // FIND NEAREST PROVIDER (Washer/Cleaner/Laundry)
  // ============================================================
  Future<Map<String, dynamic>?> findNearestProvider({
    required double userLat,
    required double userLng,
    required String category,
    double radiusKm = 10.0,
  }) async {
    try {
      // Query Firestore for approved and online providers
      final snapshot = await _firestore
          .collection('washers')
          .where('approved', isEqualTo: true)
          .where('isOnline', isEqualTo: true)
          .where('serviceCategory', isEqualTo: category)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      // Calculate distances and sort
      List<Map<String, dynamic>> providers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['currentLat'] ?? data['latitude'] ?? 6.5244;
        final lng = data['currentLng'] ?? data['longitude'] ?? 3.3792;
        
        final distance = _calculateDistance(userLat, userLng, lat, lng);
        
        if (distance <= radiusKm) {
          providers.add({
            'id': doc.id,
            ...data,
            'distance': distance,
            'distanceDisplay': '${distance.toStringAsFixed(1)} km',
            'eta': _calculateETA(distance, data['vehicleType'] ?? 'Motorcycle'),
          });
        }
      }

      if (providers.isEmpty) return null;

      providers.sort((a, b) => a['distance'].compareTo(b['distance']));
      return providers.first;
    } catch (e) {
      print('❌ Error finding nearest provider: $e');
      return null;
    }
  }

  // ============================================================
  // GET PROVIDERS BY CATEGORY
  // ============================================================
  Future<List<Map<String, dynamic>>> getProvidersByCategory({
    required String category,
    double? userLat,
    double? userLng,
  }) async {
    try {
      final snapshot = await _firestore.collection('washers').get();

      List<Map<String, dynamic>> providers = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final rawCategories = data['serviceCategories'] ?? data['selectedServices'] ?? [];
        final serviceCat = data['serviceCategory']?.toString();

        bool isMatch = false;
        final cleanCategory = category.toLowerCase().trim();

        if (serviceCat != null && serviceCat.toLowerCase().trim() == cleanCategory) {
          isMatch = true;
        } else if (rawCategories is List) {
          isMatch = rawCategories.any((cat) {
            final c = cat.toString().toLowerCase().trim();
            if (c == cleanCategory) return true;
            if (cleanCategory == 'car wash' && (c == 'car_wash' || c.contains('wash'))) return true;
            if (cleanCategory == 'house cleaning' && (c == 'house_cleaning' || c.contains('cleaning'))) return true;
            if (cleanCategory == 'laundry' && (c == 'laundry' || c.contains('laundry'))) return true;
            return false;
          });
        }

        if (isMatch) {
          final rawName = data['name'] ?? data['fullName'] ?? data['userName'] ?? 'Service Provider';
          final name = (rawName is String && rawName.trim().isNotEmpty) ? rawName.trim() : 'Service Provider';

          providers.add({
            'id': doc.id,
            'name': name,
            'phone': data['phone'] ?? '+2348012345678',
            'email': data['email'] ?? '${name.toLowerCase().replaceAll(' ', '.')}@gwashng.com',
            'rating': data['rating'] ?? 4.8,
            'vehicleType': data['vehicleType'] ?? 'Motorcycle',
            'serviceCategory': serviceCat ?? category,
            ...data,
          });
        }
      }

      // If no providers found in DB, provide realistic category-specific fallback demo providers
      if (providers.isEmpty) {
        if (category == 'House Cleaning') {
          providers = [
            {
              'id': 'provider_house_1',
              'name': 'Grace Danjuma',
              'phone': '+2348012345678',
              'email': 'grace.danjuma@gwashng.com',
              'rating': 4.9,
              'vehicleType': 'Home Care Van',
              'serviceCategory': 'House Cleaning',
              'currentLat': (userLat ?? 6.5244) + 0.004,
              'currentLng': (userLng ?? 3.3792) + 0.003,
            },
            {
              'id': 'provider_house_2',
              'name': 'Emmanuel Egbe',
              'phone': '+2348023456789',
              'email': 'emmanuel.egbe@gwashng.com',
              'rating': 4.8,
              'vehicleType': 'Cleaning Express',
              'serviceCategory': 'House Cleaning',
              'currentLat': (userLat ?? 6.5244) + 0.007,
              'currentLng': (userLng ?? 3.3792) - 0.005,
            },
          ];
        } else if (category == 'Laundry') {
          providers = [
            {
              'id': 'provider_laundry_1',
              'name': 'Fatima Bello',
              'phone': '+2348034567890',
              'email': 'fatima.bello@gwashng.com',
              'rating': 4.9,
              'vehicleType': 'Laundry Van',
              'serviceCategory': 'Laundry',
              'currentLat': (userLat ?? 6.5244) + 0.005,
              'currentLng': (userLng ?? 3.3792) + 0.006,
            },
            {
              'id': 'provider_laundry_2',
              'name': 'Kenneth Obi',
              'phone': '+2348045678901',
              'email': 'kenneth.obi@gwashng.com',
              'rating': 4.7,
              'vehicleType': 'Motorcycle Express',
              'serviceCategory': 'Laundry',
              'currentLat': (userLat ?? 6.5244) - 0.006,
              'currentLng': (userLng ?? 3.3792) + 0.004,
            },
          ];
        } else {
          // Default: Car Wash
          providers = [
            {
              'id': 'provider_car_1',
              'name': 'Samuel Okon',
              'phone': '+2348012345678',
              'email': 'samuel.okon@gwashng.com',
              'rating': 4.9,
              'vehicleType': 'Mobile Wash Rig',
              'serviceCategory': 'Car Wash',
              'currentLat': (userLat ?? 6.5244) + 0.005,
              'currentLng': (userLng ?? 3.3792) + 0.005,
            },
            {
              'id': 'provider_car_2',
              'name': 'Blessing Adebayo',
              'phone': '+2348023456789',
              'email': 'blessing.adebayo@gwashng.com',
              'rating': 4.8,
              'vehicleType': 'Car Detailing Van',
              'serviceCategory': 'Car Wash',
              'currentLat': (userLat ?? 6.5244) + 0.008,
              'currentLng': (userLng ?? 3.3792) - 0.006,
            },
          ];
        }
      }

      // Calculate distances & ETA
      final uLat = userLat ?? 6.5244;
      final uLng = userLng ?? 3.3792;
      for (var provider in providers) {
        final lat = (provider['currentLat'] ?? provider['latitude'] ?? (uLat + 0.005)) as double;
        final lng = (provider['currentLng'] ?? provider['longitude'] ?? (uLng + 0.005)) as double;
        final distance = _calculateDistance(uLat, uLng, lat, lng);
        provider['distance'] = distance;
        provider['distanceDisplay'] = '${distance.toStringAsFixed(1)} km';
        provider['eta'] = '${(distance * 4).round().clamp(5, 45)} mins';
      }

      providers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      return providers;
    } catch (e) {
      print('❌ Error getting providers: $e');
      return [
        {
          'id': 'provider_fallback_1',
          'name': 'Samuel Okon',
          'phone': '+2348012345678',
          'rating': 4.9,
          'vehicleType': 'Motorcycle',
          'distance': 1.2,
          'distanceDisplay': '1.2 km',
          'eta': '8 mins',
        },
      ];
    }
  }

  // ============================================================
  // CREATE JOB IN FIRESTORE
  // ============================================================
  Future<Map<String, dynamic>> createJob({
    required String customerId,
    required String customerName,
    required String serviceCategory,
    required String serviceName,
    required int price,
    required String location,
    required double latitude,
    required double longitude,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? assignedWasherId,
    String? assignedWasherName,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final isDirectAssign = assignedWasherId != null && assignedWasherId.isNotEmpty;
      final jobData = {
        'customerId': customerId,
        'customerName': customerName,
        'serviceCategory': serviceCategory,
        'serviceName': serviceName,
        'price': price,
        'location': location,
        'latitude': latitude,
        'longitude': longitude,
        'scheduledDate': scheduledDate?.toIso8601String(),
        'scheduledTime': scheduledTime,
        'status': isDirectAssign ? 'assigned' : 'searching',
        'washerId': assignedWasherId ?? '',
        'washerName': assignedWasherName ?? 'Assigned Provider',
        'paymentStatus': 'pending',
        'additionalInfo': additionalInfo ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        if (isDirectAssign) 'assignedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore.collection('jobs').add(jobData);
      print('✅ Job created with ID: ${docRef.id}');

      return {
        'id': docRef.id,
        ...jobData,
      };
    } catch (e) {
      print('❌ Error creating job: $e');
      rethrow;
    }
  }

  // ============================================================
  // ASSIGN PROVIDER TO JOB
  // ============================================================
  Future<Map<String, dynamic>> assignProviderToJob({
    required String jobId,
    required String providerId,
  }) async {
    try {
      // Get provider details
      final providerDoc = await _firestore.collection('washers').doc(providerId).get();
      if (!providerDoc.exists) {
        throw Exception('Provider not found');
      }

      final providerData = providerDoc.data()!;

      // Update job
      await _firestore.collection('jobs').doc(jobId).update({
        'washerId': providerId,
        'washerName': providerData['name'] ?? 'Unknown',
        'washerPhone': providerData['phone'] ?? '',
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      // Update provider stats
      await _firestore.collection('washers').doc(providerId).update({
        'pendingJobs': FieldValue.increment(1),
        'lastJobAssigned': FieldValue.serverTimestamp(),
      });

      return {
        'jobId': jobId,
        'washerId': providerId,
        'washerName': providerData['name'] ?? 'Unknown',
        'washerPhone': providerData['phone'] ?? '',
        'status': 'assigned',
        'assignedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error assigning provider: $e');
      rethrow;
    }
  }

  // ============================================================
  // COMPLETE JOB
  // ============================================================
  Future<Map<String, dynamic>> completeJob(String jobId) async {
    try {
      // Get job details to update provider stats
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data()!;
      final washerId = jobData['washerId'];
      final price = jobData['price'] ?? 0;

      // Update job
      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Update provider stats
      if (washerId != null) {
        await _firestore.collection('washers').doc(washerId).update({
          'totalJobs': FieldValue.increment(1),
          'totalEarnings': FieldValue.increment(price),
          'pendingJobs': FieldValue.increment(-1),
          'todayEarnings': FieldValue.increment(price),
        });
      }

      return {
        'success': true,
        'jobId': jobId,
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error completing job: $e');
      rethrow;
    }
  }

  // ============================================================
  // CANCEL JOB
  // ============================================================
  Future<Map<String, dynamic>> cancelJob({
    required String jobId,
    required String reason,
  }) async {
    try {
      // Get job details
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job not found');
      }

      final jobData = jobDoc.data()!;
      final washerId = jobData['washerId'];

      // Update job
      await _firestore.collection('jobs').doc(jobId).update({
        'status': 'cancelled',
        'cancelledReason': reason,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // Update provider stats if assigned
      if (washerId != null) {
        await _firestore.collection('washers').doc(washerId).update({
          'pendingJobs': FieldValue.increment(-1),
        });
      }

      return {
        'success': true,
        'jobId': jobId,
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error cancelling job: $e');
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
  // GET USER JOBS (Customer)
  // ============================================================
  Future<List<Map<String, dynamic>>> getUserJobs(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('customerId', isEqualTo: userId)
          .get();

      final list = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      list.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      print('❌ Error getting user jobs: $e');
      return [];
    }
  }

  // ============================================================
  // GET WASHER JOBS (Provider)
  // ============================================================
  Future<List<Map<String, dynamic>>> getWasherJobs(String washerId) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('washerId', isEqualTo: washerId)
          .get();

      final list = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      list.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      print('❌ Error getting washer jobs: $e');
      return [];
    }
  }

  // ============================================================
  // GET PENDING JOBS (For Washers)
  // ============================================================
  Future<List<Map<String, dynamic>>> getPendingJobs({
    String? category,
    double? userLat,
    double? userLng,
    double radiusKm = 10.0,
  }) async {
    try {
      Query query = _firestore.collection('jobs');

      if (category != null && category != 'All') {
        query = query.where('serviceCategory', isEqualTo: category);
      } else {
        query = query.where('status', isEqualTo: 'searching');
      }

      final snapshot = await query.get();
      final list = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      list.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      return list;
    } catch (e) {
      print('❌ Error getting pending jobs: $e');
      return [];
    }
  }

  // ============================================================
  // GET PROVIDER STATS
  // ============================================================
  Future<Map<String, dynamic>> getProviderStats(String providerId) async {
    try {
      final doc = await _firestore.collection('washers').doc(providerId).get();
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
      print('❌ Error getting provider stats: $e');
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
  // UPDATE PROVIDER STATUS (Online/Offline)
  // ============================================================
  Future<void> updateProviderStatus({
    required String providerId,
    required bool isOnline,
  }) async {
    try {
      await _firestore.collection('washers').doc(providerId).update({
        'isOnline': isOnline,
        'lastStatusUpdate': FieldValue.serverTimestamp(),
      });
      notifyListeners();
    } catch (e) {
      print('❌ Error updating provider status: $e');
      rethrow;
    }
  }

  // ============================================================
  // GET PROVIDER DETAILS
  // ============================================================
  Future<Map<String, dynamic>?> getProviderDetails(String providerId) async {
    try {
      final doc = await _firestore.collection('washers').doc(providerId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting provider details: $e');
      return null;
    }
  }

  // ============================================================
  // UPDATE PROVIDER LOCATION (Real-time)
  // ============================================================
  Future<void> updateProviderLocation({
    required String providerId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _firestore.collection('washers').doc(providerId).update({
        'currentLat': latitude,
        'currentLng': longitude,
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating provider location: $e');
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  // Calculate distance between two coordinates (in km)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Calculate ETA based on distance and vehicle type
  String _calculateETA(double distanceKm, String vehicleType) {
    int minutes;
    if (vehicleType == 'Motorcycle' || vehicleType == 'Bicycle') {
      minutes = (distanceKm * 2).round();
    } else if (vehicleType == 'Van' || vehicleType == 'Truck') {
      minutes = (distanceKm * 3).round();
    } else {
      minutes = (distanceKm * 2.5).round();
    }
    minutes = minutes.clamp(5, 60);
    return '$minutes min';
  }
}