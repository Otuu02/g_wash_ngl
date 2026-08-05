// lib/core/services/payment_service.dart
// PURPOSE: Handle payment processing with Paystack/Flutterwave integration

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // PROCESS PAYMENT
  // ============================================================
  Future<PaymentResult> processPayment({
    required String jobId,
    required int amount,
    required String paymentMethod,
    String? customerEmail,
    String? customerPhone,
  }) async {
    try {
      // In production, integrate with Paystack or Flutterwave webhooks / Cloud Functions.
      
      // Validate payment parameters
      if (amount <= 0 || jobId.trim().isEmpty) {
        return PaymentResult(
          success: false,
          message: 'Invalid payment parameters (amount must be > 0 and jobId must be valid)',
        );
      }

      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate reference safely
      final jobSegment = jobId.length >= 6 ? jobId.substring(0, 6) : jobId;
      final reference = 'GWSH_${DateTime.now().millisecondsSinceEpoch}_$jobSegment';

      // Update payment status in Firestore
      await _firestore.collection('jobs').doc(jobId).update({
        'paymentStatus': 'paid',
        'paymentMethod': paymentMethod,
        'paymentReference': reference,
        'paidAt': FieldValue.serverTimestamp(),
      });

      // Add to transactions collection
      await _firestore.collection('transactions').add({
        'jobId': jobId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'reference': reference,
        'status': 'success',
        'customerEmail': customerEmail ?? '',
        'customerPhone': customerPhone ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return PaymentResult(
        success: true,
        message: 'Payment successful',
        reference: reference,
      );
    } catch (e) {
      debugPrint('❌ Payment failed: $e');
      return PaymentResult(
        success: false,
        message: 'Payment failed: $e',
      );
    }
  }

  // ============================================================
  // PROCESS REFUND
  // ============================================================
  Future<PaymentResult> refundPayment({
    required String jobId,
    required String reason,
  }) async {
    try {
      // Get job details
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      if (!jobDoc.exists) {
        return PaymentResult(
          success: false,
          message: 'Job not found',
        );
      }

      final data = jobDoc.data()!;
      if (data['paymentStatus'] != 'paid') {
        return PaymentResult(
          success: false,
          message: 'Payment not found or already refunded',
        );
      }

      // Simulate refund processing
      await Future.delayed(const Duration(seconds: 2));

      // Update payment status
      await _firestore.collection('jobs').doc(jobId).update({
        'paymentStatus': 'refunded',
        'refundReason': reason,
        'refundedAt': FieldValue.serverTimestamp(),
      });

      // Add to transactions
      await _firestore.collection('transactions').add({
        'jobId': jobId,
        'amount': data['price'] ?? 0,
        'type': 'refund',
        'reason': reason,
        'status': 'success',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return PaymentResult(
        success: true,
        message: 'Refund processed successfully',
      );
    } catch (e) {
      print('❌ Refund failed: $e');
      return PaymentResult(
        success: false,
        message: 'Refund failed: $e',
      );
    }
  }

  // ============================================================
  // GET PAYMENT STATUS
  // ============================================================
  Future<PaymentStatus?> getPaymentStatus(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();
      if (!doc.exists) {
        return null;
      }

      final data = doc.data()!;
      return PaymentStatus(
        status: data['paymentStatus'] ?? 'pending',
        amount: data['price'] ?? 0,
        method: data['paymentMethod'],
        reference: data['paymentReference'],
        paidAt: data['paidAt'] != null 
            ? (data['paidAt'] as Timestamp).toDate() 
            : null,
      );
    } catch (e) {
      print('❌ Error getting payment status: $e');
      return null;
    }
  }

  // ============================================================
  // GET TRANSACTION HISTORY
  // ============================================================
  Future<List<Map<String, dynamic>>> getTransactionHistory({
    String? jobId,
    String? customerId,
    String? washerId,
    int limit = 50,
  }) async {
    try {
      var query = _firestore
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }
      if (customerId != null) {
        query = query.where('customerId', isEqualTo: customerId);
      }
      if (washerId != null) {
        query = query.where('washerId', isEqualTo: washerId);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting transaction history: $e');
      return [];
    }
  }

  // ============================================================
  // GET EARNINGS FOR WASHER (FIXED: Type casting)
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
  // VERIFY PAYMENT (For webhook integration)
  // ============================================================
  Future<bool> verifyPayment(String reference) async {
    try {
      // In production, verify with Paystack/Flutterwave API
      // For now, check if transaction exists
      final snapshot = await _firestore
          .collection('transactions')
          .where('reference', isEqualTo: reference)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }

  // ============================================================
  // PROCESS WEBHOOK (For Paystack/Flutterwave)
  // ============================================================
  Future<void> processWebhook(Map<String, dynamic> payload) async {
    try {
      final event = payload['event'] ?? '';
      final data = payload['data'] ?? {};

      if (event == 'charge.success') {
        final reference = data['reference'] ?? '';

        // Find job by reference
        final snapshot = await _firestore
            .collection('jobs')
            .where('paymentReference', isEqualTo: reference)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final jobId = snapshot.docs.first.id;
          await _firestore.collection('jobs').doc(jobId).update({
            'paymentStatus': 'paid',
            'paidAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('❌ Error processing webhook: $e');
      throw Exception('Webhook processing failed');
    }
  }
}

// ============================================================
// PAYMENT RESULT MODEL
// ============================================================
class PaymentResult {
  final bool success;
  final String message;
  final String? reference;

  PaymentResult({
    required this.success,
    required this.message,
    this.reference,
  });
}

// ============================================================
// PAYMENT STATUS MODEL
// ============================================================
class PaymentStatus {
  final String status; // pending, paid, refunded, failed
  final int amount;
  final String? method;
  final String? reference;
  final DateTime? paidAt;

  PaymentStatus({
    required this.status,
    required this.amount,
    this.method,
    this.reference,
    this.paidAt,
  });

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isRefunded => status == 'refunded';
  bool get isFailed => status == 'failed';
}