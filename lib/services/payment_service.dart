// lib/services/payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'app_notification_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  // ============================================================
  // PROCESS PAYMENT - WITH NOTIFICATIONS & SECURITY VERIFICATION
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
      // 🔒 SECURITY GUARD: Validate inputs
      if (amount <= 0 || jobId.isEmpty || userId.isEmpty) {
        throw ArgumentError('Invalid payment parameters: amount, jobId, and userId must be valid.');
      }

      // NOTE: In production environments, actual payment status updates should be verified
      // server-side (e.g. via Paystack/Flutterwave webhook or Firebase Cloud Functions)
      // to prevent client-side payment forgery.

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
        'status': 'paid',
        'completedAt': FieldValue.serverTimestamp(),
      });

      // ✅ SEND NOTIFICATION: Payment Successful
      _notificationService.addNotification(
        title: '💰 Payment Successful!',
        message: 'You have successfully paid ₦${amount.toString()} for $serviceName.',
        type: 'payment',
        jobId: jobId,
      );

      debugPrint('✅ Payment processed for job: $jobId');
      debugPrint('📢 Payment notification sent');

      return {
        'success': true,
        'paymentId': paymentId,
        'reference': reference,
        'transactionId': transactionId,
      };
    } catch (e) {
      debugPrint('❌ Payment processing error: $e');
      
      // ✅ SEND NOTIFICATION: Payment Failed
      _notificationService.addNotification(
        title: '❌ Payment Failed',
        message: 'Payment for $serviceName failed. Please try again.',
        type: 'payment',
        jobId: jobId,
      );
      
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // PROCESS PAYMENT WITH CARD (Full details)
  // ============================================================
  Future<Map<String, dynamic>> processCardPayment({
    required String jobId,
    required String userId,
    required String userName,
    required String serviceName,
    required int amount,
    required String location,
    required String cardNumber,
    required String expiryDate,
    required String cvv,
    required String cardHolderName,
  }) async {
    try {
      // Simulate card validation
      if (cardNumber.length < 16) {
        throw Exception('Invalid card number');
      }
      if (expiryDate.length < 5) {
        throw Exception('Invalid expiry date');
      }
      if (cvv.length < 3) {
        throw Exception('Invalid CVV');
      }

      final last4 = cardNumber.substring(cardNumber.length - 4);
      
      return await processPayment(
        jobId: jobId,
        userId: userId,
        userName: userName,
        serviceName: serviceName,
        amount: amount,
        location: location,
        paymentMethod: 'card',
        cardLast4: last4,
      );
    } catch (e) {
      print('❌ Card payment error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // PROCESS BANK TRANSFER PAYMENT
  // ============================================================
  Future<Map<String, dynamic>> processBankTransfer({
    required String jobId,
    required String userId,
    required String userName,
    required String serviceName,
    required int amount,
    required String location,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      // Simulate bank transfer validation
      if (accountNumber.length < 10) {
        throw Exception('Invalid account number');
      }
      if (accountName.isEmpty) {
        throw Exception('Account name is required');
      }

      return await processPayment(
        jobId: jobId,
        userId: userId,
        userName: userName,
        serviceName: serviceName,
        amount: amount,
        location: location,
        paymentMethod: 'bank_transfer',
      );
    } catch (e) {
      print('❌ Bank transfer error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // PROCESS WALLET PAYMENT
  // ============================================================
  Future<Map<String, dynamic>> processWalletPayment({
    required String jobId,
    required String userId,
    required String userName,
    required String serviceName,
    required int amount,
    required String location,
  }) async {
    try {
      // Check wallet balance
      final walletBalance = await getWalletBalance(userId);
      if (walletBalance < amount) {
        throw Exception('Insufficient wallet balance. Please fund your wallet.');
      }

      // Deduct from wallet
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(-amount),
      });

      return await processPayment(
        jobId: jobId,
        userId: userId,
        userName: userName,
        serviceName: serviceName,
        amount: amount,
        location: location,
        paymentMethod: 'wallet',
      );
    } catch (e) {
      print('❌ Wallet payment error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // GET WALLET BALANCE
  // ============================================================
  Future<double> getWalletBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data();
        return (data?['walletBalance'] ?? 0).toDouble();
      }
      return 0;
    } catch (e) {
      print('❌ Error getting wallet balance: $e');
      return 0;
    }
  }

  // ============================================================
  // FUND WALLET
  // ============================================================
  Future<Map<String, dynamic>> fundWallet({
    required String userId,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      final reference = 'WALLET-${DateTime.now().millisecondsSinceEpoch}';
      
      // Add transaction record
      await _firestore.collection('wallet_transactions').add({
        'userId': userId,
        'amount': amount,
        'type': 'credit',
        'paymentMethod': paymentMethod,
        'reference': reference,
        'status': 'completed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update wallet balance
      await _firestore.collection('users').doc(userId).update({
        'walletBalance': FieldValue.increment(amount),
      });

      _notificationService.addNotification(
        title: '💰 Wallet Funded!',
        message: 'Your wallet has been funded with ₦${amount.toString()}.',
        type: 'payment',
      );

      return {
        'success': true,
        'reference': reference,
        'amount': amount,
      };
    } catch (e) {
      print('❌ Error funding wallet: $e');
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

  // ============================================================
  // GET PAYMENT BY REFERENCE
  // ============================================================
  Future<Map<String, dynamic>?> getPaymentByReference(String reference) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('paymentReference', isEqualTo: reference)
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
      print('❌ Error getting payment by reference: $e');
      return null;
    }
  }

  // ============================================================
  // GET ALL PAYMENTS (Admin)
  // ============================================================
  Future<List<Map<String, dynamic>>> getAllPayments() async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .orderBy('paymentDate', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting all payments: $e');
      return [];
    }
  }

  // ============================================================
  // GET DAILY EARNINGS (Washer)
  // ============================================================
  Future<Map<String, dynamic>> getDailyEarnings(String washerId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .where('paymentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('paymentDate', isLessThan: endOfDay)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] ?? 0).toDouble();
      }

      return {
        'date': date,
        'total': total,
        'count': snapshot.docs.length,
        'transactions': snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList(),
      };
    } catch (e) {
      print('❌ Error getting daily earnings: $e');
      return {
        'date': date,
        'total': 0,
        'count': 0,
        'transactions': [],
      };
    }
  }

  // ============================================================
  // GET MONTHLY EARNINGS (Washer)
  // ============================================================
  Future<Map<String, dynamic>> getMonthlyEarnings(String washerId, int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .where('paymentDate', isGreaterThanOrEqualTo: startOfMonth)
          .where('paymentDate', isLessThan: endOfMonth)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] ?? 0).toDouble();
      }

      return {
        'year': year,
        'month': month,
        'total': total,
        'count': snapshot.docs.length,
        'transactions': snapshot.docs.map((doc) {
          return {
            'id': doc.id,
            ...doc.data(),
          };
        }).toList(),
      };
    } catch (e) {
      print('❌ Error getting monthly earnings: $e');
      return {
        'year': year,
        'month': month,
        'total': 0,
        'count': 0,
        'transactions': [],
      };
    }
  }

  // ============================================================
  // GET TOTAL EARNINGS (Washer)
  // ============================================================
  Future<double> getTotalEarnings(String washerId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        total += (data['amount'] ?? 0).toDouble();
      }

      return total;
    } catch (e) {
      print('❌ Error getting total earnings: $e');
      return 0;
    }
  }

  // ============================================================
  // REFUND PAYMENT
  // ============================================================
  Future<Map<String, dynamic>> refundPayment({
    required String paymentId,
    required String reason,
  }) async {
    try {
      final paymentDoc = await _firestore.collection('payments').doc(paymentId).get();
      if (!paymentDoc.exists) {
        throw Exception('Payment not found');
      }

      final paymentData = paymentDoc.data()!;
      
      await _firestore.collection('payments').doc(paymentId).update({
        'status': 'refunded',
        'refundReason': reason,
        'refundedAt': FieldValue.serverTimestamp(),
      });

      // Update job
      final jobId = paymentData['jobId'];
      if (jobId != null) {
        await _firestore.collection('jobs').doc(jobId).update({
          'paymentStatus': 'refunded',
          'refundedAt': FieldValue.serverTimestamp(),
        });
      }

      _notificationService.addNotification(
        title: '💳 Payment Refunded',
        message: 'Your payment for ${paymentData['serviceName']} has been refunded. Reason: $reason',
        type: 'payment',
        jobId: jobId,
      );

      return {
        'success': true,
        'paymentId': paymentId,
        'refundedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Error refunding payment: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // VERIFY PAYMENT (Webhook)
  // ============================================================
  Future<bool> verifyPayment(String reference) async {
    try {
      // This would typically call a payment gateway API
      // For now, just check if payment exists in Firestore
      final payment = await getPaymentByReference(reference);
      return payment != null && payment['status'] == 'completed';
    } catch (e) {
      print('❌ Error verifying payment: $e');
      return false;
    }
  }
}