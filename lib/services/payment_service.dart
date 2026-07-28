// lib/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PROCESS PAYMENT
  // ============================================================
  Future<Map<String, dynamic>> processPayment({
    required String jobId,
    required String userId,
    required String userName,
    required String serviceName,
    required int amount,
    required String location,
    required String paymentMethod,
    String? cardLast4,
  }) async {
    try {
      final paymentRef = _firestore.collection('payments').doc();
      final paymentId = paymentRef.id;
      final reference = 'GWASH-${DateTime.now().millisecondsSinceEpoch}';
      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';

      final paymentData = {
        'id': paymentId,
        'jobId': jobId,
        'userId': userId,
        'userName': userName,
        'serviceName': serviceName,
        'amount': amount,
        'location': location,
        'paymentMethod': paymentMethod,
        'status': 'completed',
        'paymentDate': FieldValue.serverTimestamp(),
        'paymentReference': reference,
        'transactionId': transactionId,
        'cardLast4': cardLast4,
      };

      await paymentRef.set(paymentData);

      // Update job
      await _firestore.collection('jobs').doc(jobId).update({
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentReference': reference,
        'transactionId': transactionId,
        'paidAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'paymentId': paymentId,
        'reference': reference,
        'transactionId': transactionId,
      };
    } catch (e) {
      print('❌ Payment processing error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // GET PAYMENT HISTORY
  // ============================================================
  Future<List<Map<String, dynamic>>> getPaymentHistory(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .orderBy('paymentDate', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting payment history: $e');
      return [];
    }
  }

  // ============================================================
  // GET PAYMENT BY JOB ID
  // ============================================================
  Future<Map<String, dynamic>?> getPaymentByJobId(String jobId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('jobId', isEqualTo: jobId)
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
      print('❌ Error getting payment: $e');
      return null;
    }
  }
}