// lib/core/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ============================================================
  // DASHBOARD STATS
  // ============================================================
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final users = await _firestore.collection('users').get();
      final washers = await _firestore.collection('washers').get();
      final jobs = await _firestore.collection('jobs').get();
      
      int revenue = 0;
      int completedJobs = 0;
      int activeJobs = 0;
      
      for (var doc in jobs.docs) {
        final status = doc['status'] ?? '';
        final price = doc['price'] ?? 0;
        final paymentStatus = doc['paymentStatus'] ?? '';
        
        if (status == 'completed' && paymentStatus == 'paid') {
          revenue += price as int;
          completedJobs++;
        }
        if (status == 'assigned' || status == 'enRoute') {
          activeJobs++;
        }
      }
      
      double totalPlatformRevenue = 0.0;
      double totalWasherPayouts = 0.0;
      
      try {
        final platformDoc = await _firestore.collection('platform_financials').doc('stats').get();
        if (platformDoc.exists) {
          final pData = platformDoc.data()!;
          totalPlatformRevenue = (pData['totalPlatformRevenue'] ?? 0.0).toDouble();
          totalWasherPayouts = (pData['totalWasherPayouts'] ?? 0.0).toDouble();
        } else {
          totalPlatformRevenue = revenue * 0.05;
          totalWasherPayouts = revenue * 0.95;
        }
      } catch (e) {
        totalPlatformRevenue = revenue * 0.05;
        totalWasherPayouts = revenue * 0.95;
      }
      
      return {
        'totalUsers': users.size,
        'totalWashers': washers.size,
        'totalJobs': jobs.size,
        'totalRevenue': revenue,
        'totalPlatformRevenue': totalPlatformRevenue,
        'totalWasherPayouts': totalWasherPayouts,
        'pendingWashers': washers.docs.where((w) => w['approved'] != true).length,
        'activeJobs': activeJobs,
        'completedJobs': completedJobs,
      };
    } catch (e) {
      print('Error getting dashboard stats: $e');
      return {
        'totalUsers': 0,
        'totalWashers': 0,
        'totalJobs': 0,
        'totalRevenue': 0,
        'pendingWashers': 0,
        'activeJobs': 0,
        'completedJobs': 0,
      };
    }
  }

  // ============================================================
  // USERS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  Future<void> toggleBlockUser(String userId, bool isBlocked) async {
    await _firestore.collection('users').doc(userId).update({
      'isBlocked': isBlocked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // DELETE USER - FIXED
  // ============================================================
  Future<void> deleteUser(String userId) async {
    try {
      // 1. Delete user document from Firestore
      await _firestore.collection('users').doc(userId).delete();
      
      // 2. Delete any related jobs
      final jobs = await _firestore
          .collection('jobs')
          .where('customerId', isEqualTo: userId)
          .get();
      
      for (var job in jobs.docs) {
        await job.reference.delete();
      }
      
      // 3. Delete user from Firebase Auth (if exists)
      try {
        final user = _auth.currentUser;
        if (user != null && user.uid == userId) {
          await user.delete();
        }
      } catch (e) {
        print('⚠️ Could not delete user from Auth: $e');
      }
      
      print('✅ User $userId deleted successfully');
    } catch (e) {
      print('❌ Error deleting user: $e');
      rethrow;
    }
  }

  // ============================================================
  // WASHERS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllWashers() async {
    try {
      final snapshot = await _firestore.collection('washers').get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting washers: $e');
      return [];
    }
  }

  Future<void> approveWasher(String washerId) async {
    await _firestore.collection('washers').doc(washerId).update({
      'approved': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });
    
    // Also update user role
    final washerDoc = await _firestore.collection('washers').doc(washerId).get();
    if (washerDoc.exists) {
      final userId = washerDoc.data()?['userId'];
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'role': 'washer',
          'approved': true,
        });
      }
    }
  }

  Future<void> rejectWasher(String washerId) async {
    // Get washer data first
    final washerDoc = await _firestore.collection('washers').doc(washerId).get();
    if (washerDoc.exists) {
      final userId = washerDoc.data()?['userId'];
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'role': 'customer',
          'approved': false,
        });
      }
    }
    await _firestore.collection('washers').doc(washerId).delete();
  }

  // ============================================================
  // DELETE WASHER - FIXED
  // ============================================================
  Future<void> deleteWasher(String washerId) async {
    try {
      // Get washer data first to get userId
      final washerDoc = await _firestore.collection('washers').doc(washerId).get();
      if (washerDoc.exists) {
        final userId = washerDoc.data()?['userId'];
        
        // Delete washer document
        await _firestore.collection('washers').doc(washerId).delete();
        
        // Update user role back to customer
        if (userId != null) {
          await _firestore.collection('users').doc(userId).update({
            'role': 'customer',
            'washerId': null,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
        
        // Update any assigned jobs
        final jobs = await _firestore
            .collection('jobs')
            .where('washerId', isEqualTo: washerId)
            .get();
        
        for (var job in jobs.docs) {
          await job.reference.update({
            'washerId': null,
            'washerName': null,
            'status': 'searching',
          });
        }
      } else {
        // Just delete if document exists
        await _firestore.collection('washers').doc(washerId).delete();
      }
      
      print('✅ Washer $washerId deleted successfully');
    } catch (e) {
      print('❌ Error deleting washer: $e');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE WASHER - FIXED
  // ============================================================
  Future<void> updateWasher(String washerId, Map<String, dynamic> data) async {
    try {
      // Remove null values
      final cleanedData = {};
      data.forEach((key, value) {
        if (value != null) {
          cleanedData[key] = value;
        }
      });
      
      await _firestore.collection('washers').doc(washerId).update({
        ...cleanedData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Also update user's display name if name changed
      if (data.containsKey('name')) {
        final washerDoc = await _firestore.collection('washers').doc(washerId).get();
        if (washerDoc.exists) {
          final userId = washerDoc.data()?['userId'];
          if (userId != null) {
            await _firestore.collection('users').doc(userId).update({
              'name': data['name'],
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      
      print('✅ Washer $washerId updated successfully');
    } catch (e) {
      print('❌ Error updating washer: $e');
      rethrow;
    }
  }

  // ============================================================
  // JOBS
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllJobs() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('Error getting jobs: $e');
      return [];
    }
  }

  // ============================================================
  // DELETE JOB
  // ============================================================
  Future<void> deleteJob(String jobId) async {
    try {
      // Get job data first
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (jobDoc.exists) {
        final data = jobDoc.data()!;
        final washerId = data['washerId'];
        
        // If job was assigned, update washer stats
        if (washerId != null && washerId.isNotEmpty) {
          await _firestore.collection('washers').doc(washerId).update({
            'pendingJobs': FieldValue.increment(-1),
          });
        }
      }
      
      await _firestore.collection('jobs').doc(jobId).delete();
      print('✅ Job $jobId deleted successfully');
    } catch (e) {
      print('❌ Error deleting job: $e');
      rethrow;
    }
  }

  // ============================================================
  // UPDATE JOB
  // ============================================================
  Future<void> updateJobStatus(String jobId, String status) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Job $jobId status updated to $status');
    } catch (e) {
      print('❌ Error updating job: $e');
      rethrow;
    }
  }

  // ============================================================
  // BULK ACTIONS
  // ============================================================
  Future<void> deleteAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ All users deleted');
    } catch (e) {
      print('❌ Error deleting all users: $e');
      rethrow;
    }
  }

  Future<void> deleteAllWashers() async {
    try {
      final snapshot = await _firestore.collection('washers').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ All washers deleted');
    } catch (e) {
      print('❌ Error deleting all washers: $e');
      rethrow;
    }
  }

  Future<void> deleteAllJobs() async {
    try {
      final snapshot = await _firestore.collection('jobs').get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ All jobs deleted');
    } catch (e) {
      print('❌ Error deleting all jobs: $e');
      rethrow;
    }
  }

  // ============================================================
  // SETTINGS
  // ============================================================
  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('system').get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting settings: $e');
      return null;
    }
  }

  Future<void> updateSettings(Map<String, dynamic> settings) async {
    await _firestore.collection('settings').doc('system').set(
      settings,
      SetOptions(merge: true),
    );
  }

  // ============================================================
  // GET WASHER EARNINGS
  // ============================================================
  Future<Map<String, dynamic>> getWasherEarnings(String washerId) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('washerId', isEqualTo: washerId)
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      int totalEarnings = 0;
      int totalJobs = 0;
      int todayEarnings = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final price = (data['price'] ?? 0) as int;
        totalEarnings += price;
        totalJobs++;

        final paidAt = data['paidAt'] as Timestamp?;
        if (paidAt != null) {
          final paidDate = paidAt.toDate();
          if (paidDate.isAfter(today)) {
            todayEarnings += price;
          }
        }
      }

      return {
        'totalEarnings': totalEarnings,
        'totalJobs': totalJobs,
        'todayEarnings': todayEarnings,
        'averageEarning': totalJobs > 0 ? totalEarnings / totalJobs : 0,
      };
    } catch (e) {
      print('❌ Error getting washer earnings: $e');
      return {
        'totalEarnings': 0,
        'totalJobs': 0,
        'todayEarnings': 0,
        'averageEarning': 0,
      };
    }
  }

  // ============================================================
  // ADDITIONAL ADMIN METHODS
  // ============================================================
  
  /// Get total revenue - FIXED: Type casting
  Future<int> getTotalRevenue() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('paymentStatus', isEqualTo: 'paid')
          .get();
      
      int total = 0;
      for (var doc in snapshot.docs) {
        final price = doc['price'] ?? 0;
        total += price as int;  // ← FIXED: Cast to int
      }
      return total;
    } catch (e) {
      print('Error getting total revenue: $e');
      return 0;
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Get washer by ID
  Future<Map<String, dynamic>?> getWasherById(String washerId) async {
    try {
      final doc = await _firestore.collection('washers').doc(washerId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('Error getting washer: $e');
      return null;
    }
  }

  /// Get job by ID
  Future<Map<String, dynamic>?> getJobById(String jobId) async {
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
      print('Error getting job: $e');
      return null;
    }
  }

  /// Get total number of users
  Future<int> getTotalUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.size;
    } catch (e) {
      print('Error getting total users: $e');
      return 0;
    }
  }

  /// Get total number of washers
  Future<int> getTotalWashers() async {
    try {
      final snapshot = await _firestore.collection('washers').get();
      return snapshot.size;
    } catch (e) {
      print('Error getting total washers: $e');
      return 0;
    }
  }

  /// Get active jobs count
  Future<int> getActiveJobs() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', whereIn: ['assigned', 'enRoute'])
          .get();
      return snapshot.size;
    } catch (e) {
      print('Error getting active jobs: $e');
      return 0;
    }
  }

  /// Get completed jobs count
  Future<int> getCompletedJobs() async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('status', isEqualTo: 'completed')
          .get();
      return snapshot.size;
    } catch (e) {
      print('Error getting completed jobs: $e');
      return 0;
    }
  }
}