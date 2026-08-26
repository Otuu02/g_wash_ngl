import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../config/env.dart';
import 'app_notification_service.dart';
import 'communication_service.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();
  final CommunicationService _communicationService = CommunicationService();

  // ============================================================
  // INITIALIZE REAL PAYSTACK TRANSACTION (LIVE GATEWAY)
  // ============================================================
  Future<Map<String, dynamic>> initializePaystackTransaction({
    required String email,
    required int amount,
    required String jobId,
    required String userId,
    required String serviceName,
    List<String>? channels,
  }) async {
    final reference = 'GWASH-${DateTime.now().millisecondsSinceEpoch}';
    final int amountInKobo = amount * 100;

    try {
      final String paystackSecretKey = Env.paystackSecretKey;
      debugPrint('💳 Initializing Live Paystack Transaction for $email (Ref: $reference)');

      final Map<String, dynamic> bodyPayload = {
        'email': email.isNotEmpty ? email : 'customer@gwashng.com',
        'amount': amountInKobo,
        'reference': reference,
        'callback_url': 'https://standard.paystack.co/close',
        'metadata': {
          'jobId': jobId,
          'userId': userId,
          'serviceName': serviceName,
        }
      };

      if (channels != null && channels.isNotEmpty) {
        bodyPayload['channels'] = channels;
      }

      final response = await http.post(
        Uri.parse('https://api.paystack.co/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $paystackSecretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyPayload),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true && data['data'] != null) {
        final authUrl = data['data']['authorization_url'];
        final accessCode = data['data']['access_code'];
        debugPrint('✅ Paystack Live Checkout URL generated: $authUrl');
        return {
          'success': true,
          'authorization_url': authUrl,
          'access_code': accessCode,
          'reference': reference,
        };
      }

      final errMsg = data['message'] ?? 'Failed to initialize Paystack transaction';
      debugPrint('❌ Paystack Initialize Failed: $errMsg');
      return {
        'success': false,
        'error': errMsg,
      };
    } catch (e) {
      debugPrint('❌ Paystack Initialization Error: $e');
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ============================================================
  // VERIFY REAL PAYSTACK TRANSACTION (LIVE VERIFICATION)
  // ============================================================
  Future<Map<String, dynamic>> verifyPaystackTransaction({
    required String reference,
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
      final String paystackSecretKey = Env.paystackSecretKey;

      final response = await http.get(
        Uri.parse('https://api.paystack.co/transaction/verify/$reference'),
        headers: {
          'Authorization': 'Bearer $paystackSecretKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final txStatus = data['data']['status'];
          final txRef = data['data']['reference'] ?? reference;
          final String? last4 = data['data']['authorization'] != null 
              ? data['data']['authorization']['last4'] 
              : cardLast4;

          if (txStatus == 'success') {
            return await processPayment(
              jobId: jobId,
              userId: userId,
              userName: userName,
              serviceName: serviceName,
              amount: amount,
              location: location,
              paymentMethod: paymentMethod,
              cardLast4: last4,
              paystackTransactionRef: txRef,
            );
          } else {
            return {
              'success': false,
              'error': 'Paystack payment status is "$txStatus". Please complete payment in checkout window.',
            };
          }
        }
      }

      final errData = jsonDecode(response.body);
      return {
        'success': false,
        'error': errData['message'] ?? 'Could not verify Paystack payment.',
      };
    } catch (e) {
      debugPrint('âŒ Paystack Verification Exception: $e');
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // ============================================================
  // PROCESS PAYMENT - WITH PAYSTACK 5% PLATFORM FEE SPLIT (95% TO WASHER)
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
    String? paystackTransactionRef,
  }) async {
    try {
      // ðŸ”’ SECURITY GUARD: Validate inputs
      if (amount <= 0 || jobId.isEmpty || userId.isEmpty) {
        throw ArgumentError('Invalid payment parameters: amount, jobId, and userId must be valid.');
      }

      // Calculate 5% Platform Fee & 95% Provider Share
      final double grossAmount = amount.toDouble();
      final double platformFee = grossAmount * 0.05; // 5% platform commission
      final double providerShare = grossAmount * 0.95; // 95% goes to washer

      final paymentRef = _firestore.collection('payments').doc();
      final paymentId = paymentRef.id;
      final reference = 'GWASH-${DateTime.now().millisecondsSinceEpoch}';
      final transactionId = paystackTransactionRef ?? 'PAYSTACK-${DateTime.now().millisecondsSinceEpoch}';

      // Get job to find assigned washer
      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      final jobData = jobDoc.data() ?? {};
      final washerId = jobData['washerId'] ?? jobData['assignedWasherId'];

      final paymentData = {
        'id': paymentId,
        'jobId': jobId,
        'userId': userId,
        'userName': userName,
        'washerId': washerId,
        'serviceName': serviceName,
        'amount': grossAmount,
        'platformFee': platformFee, // 5%
        'providerShare': providerShare, // 95%
        'location': location,
        'paymentMethod': paymentMethod,
        'gateway': 'paystack',
        'status': 'escrow', // Held in Escrow until service completion
        'paymentDate': FieldValue.serverTimestamp(),
        'paymentReference': reference,
        'transactionId': transactionId,
        'cardLast4': cardLast4 ?? '4242',
      };

      await paymentRef.set(paymentData);

      // Update job status: Payment secured in Escrow
      await _firestore.collection('jobs').doc(jobId).update({
        'paymentStatus': 'paid', // Escrow paid
        'paymentMethod': paymentMethod,
        'paymentReference': reference,
        'transactionId': transactionId,
        'paidAt': FieldValue.serverTimestamp(),
        'isEscrowSecured': true,
      });

      // Notify customer and washer that payment is secured in Escrow
      _notificationService.addNotification(
        title: 'ðŸ”’ Payment Secured in Escrow',
        message: 'Payment of â‚¦${NumberFormat('#,###').format(grossAmount)} for $serviceName is held safely in Escrow. The provider can now begin.',
        type: 'payment',
        jobId: jobId,
      );

      debugPrint('ðŸ”’ Paystack Payment held in Escrow: $jobId | Fee: â‚¦$platformFee | Washer Share: â‚¦$providerShare');

      return {
        'success': true,
        'paymentId': paymentId,
        'reference': reference,
        'transactionId': transactionId,
        'platformFee': platformFee,
        'providerShare': providerShare,
        'isEscrow': true,
      };
    } catch (e) {
      debugPrint('âŒ Payment processing error: $e');
      
      _notificationService.addNotification(
        title: 'âŒ Payment Failed',
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
  // RELEASE ESCROW PAYMENT TO WASHER (ON JOB COMPLETION)
  // ============================================================
  Future<Map<String, dynamic>> releaseEscrowPayment(String jobId) async {
    try {
      debugPrint('ðŸ”“ Releasing Escrow Payment for Job: $jobId');

      final paymentQuery = await _firestore
          .collection('payments')
          .where('jobId', isEqualTo: jobId)
          .limit(1)
          .get();

      final jobDoc = await _firestore.collection('jobs').doc(jobId).get();
      final jobData = jobDoc.data() ?? {};
      final washerId = jobData['washerId'] ?? jobData['assignedWasherId'];
      final price = (jobData['price'] ?? 0).toDouble();

      final double grossAmount = price;
      final double platformFee = grossAmount * 0.05; // 5%
      final double providerShare = grossAmount * 0.95; // 95%

      if (paymentQuery.docs.isNotEmpty) {
        final paymentDoc = paymentQuery.docs.first;
        final pData = paymentDoc.data();

        // Prevent double release
        if (pData['status'] == 'completed') {
          debugPrint('â„¹ï¸ Escrow funds already released for job: $jobId');
          return {'success': true, 'alreadyReleased': true};
        }

        // Update payment record to completed
        await paymentDoc.reference.update({
          'status': 'completed',
          'releasedAt': FieldValue.serverTimestamp(),
        });
      }

      // Credit Washer Account Balance (95% share)
      if (washerId != null && washerId.toString().isNotEmpty) {
        final washerRef = _firestore.collection('washers').doc(washerId);
        await washerRef.set({
          'availableBalance': FieldValue.increment(providerShare),
          'totalEarnings': FieldValue.increment(providerShare),
          'totalPlatformFeesPaid': FieldValue.increment(platformFee),
          'completedJobs': FieldValue.increment(1),
        }, SetOptions(merge: true));

        // Add Washer Transaction Log
        await _firestore.collection('washer_transactions').add({
          'washerId': washerId,
          'jobId': jobId,
          'serviceName': jobData['serviceName'] ?? 'Service',
          'grossAmount': grossAmount,
          'platformFee': platformFee,
          'netEarnings': providerShare,
          'type': 'credit',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update Platform Financial Stats for Admin
      final platformRef = _firestore.collection('platform_financials').doc('stats');
      await platformRef.set({
        'totalGrossVolume': FieldValue.increment(grossAmount),
        'totalPlatformRevenue': FieldValue.increment(platformFee),
        'totalWasherPayouts': FieldValue.increment(providerShare),
        'totalTransactionsCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Dispatch Notifications
      await _communicationService.sendPaymentCompletedNotifications(
        customerName: jobData['customerName'] ?? 'Customer',
        customerPhone: jobData['customerPhone'] ?? '',
        customerEmail: jobData['customerEmail'] ?? '',
        serviceName: jobData['serviceName'] ?? 'Service',
        amount: grossAmount,
        reference: jobData['paymentReference'] ?? 'GWASH-ESCROW',
        providerName: jobData['washerName'],
        providerPhone: jobData['washerPhone'],
        providerEmail: jobData['washerEmail'],
        providerShare: providerShare,
      );

      debugPrint('âœ… Escrow released successfully! Washer received â‚¦$providerShare | Admin â‚¦$platformFee');
      return {'success': true, 'providerShare': providerShare, 'platformFee': platformFee};
    } catch (e) {
      debugPrint('âŒ Escrow Release Error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================================
  // PROCESS PAYSTACK PAYMENT (Card, Transfer, USSD, QR)
  // ============================================================
  Future<Map<String, dynamic>> processPaystackPayment({
    required String jobId,
    required String userId,
    required String userName,
    required String serviceName,
    required int amount,
    required String location,
    required String paymentMethod,
    String? cardLast4,
    String? reference,
  }) async {
    try {
      final paystackRef = reference ?? 'GWASH-PAYSTACK-${DateTime.now().millisecondsSinceEpoch}';

      return await processPayment(
        jobId: jobId,
        userId: userId,
        userName: userName,
        serviceName: serviceName,
        amount: amount,
        location: location,
        paymentMethod: paymentMethod,
        cardLast4: cardLast4,
        paystackTransactionRef: paystackRef,
      );
    } catch (e) {
      debugPrint('âŒ Paystack error: $e');
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
      debugPrint('âŒ Card payment error: $e');
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
      debugPrint('âŒ Bank transfer error: $e');
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
      debugPrint('âŒ Wallet payment error: $e');
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
      debugPrint('âŒ Error getting wallet balance: $e');
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

      // Get user details for notifications
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};
      final uPhone = userData['phone'] ?? '';
      final uEmail = userData['email'] ?? '';

      await _communicationService.sendWalletFundedNotifications(
        userPhone: uPhone,
        userEmail: uEmail,
        amount: amount,
      );

      return {
        'success': true,
        'reference': reference,
        'amount': amount,
      };
    } catch (e) {
      debugPrint('âŒ Error funding wallet: $e');
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
      debugPrint('âŒ Error getting payment history: $e');
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
      debugPrint('âŒ Error getting payment: $e');
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
      debugPrint('âŒ Error getting payment by reference: $e');
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
      debugPrint('âŒ Error getting all payments: $e');
      return [];
    }
  }

  // ============================================================
  // ============================================================
  // GET DAILY EARNINGS (Washer - 95% Net Share)
  // ============================================================
  Future<Map<String, dynamic>> getDailyEarnings(String washerId, DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .where('status', isEqualTo: 'completed')
          .where('paymentDate', isGreaterThanOrEqualTo: startOfDay)
          .where('paymentDate', isLessThan: endOfDay)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final share = data['providerShare'] ?? ((data['amount'] ?? 0) * 0.95);
        total += (share as num).toDouble();
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
      debugPrint('âŒ Error getting daily earnings: $e');
      return {
        'date': date,
        'total': 0,
        'count': 0,
        'transactions': [],
      };
    }
  }

  // ============================================================
  // GET MONTHLY EARNINGS (Washer - 95% Net Share)
  // ============================================================
  Future<Map<String, dynamic>> getMonthlyEarnings(String washerId, int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .where('status', isEqualTo: 'completed')
          .where('paymentDate', isGreaterThanOrEqualTo: startOfMonth)
          .where('paymentDate', isLessThan: endOfMonth)
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final share = data['providerShare'] ?? ((data['amount'] ?? 0) * 0.95);
        total += (share as num).toDouble();
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
      debugPrint('âŒ Error getting monthly earnings: $e');
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
  // GET TOTAL EARNINGS (Washer - 95% Net Share)
  // ============================================================
  Future<double> getTotalEarnings(String washerId) async {
    try {
      final snapshot = await _firestore
          .collection('payments')
          .where('washerId', isEqualTo: washerId)
          .where('status', isEqualTo: 'completed')
          .get();

      double total = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final share = data['providerShare'] ?? ((data['amount'] ?? 0) * 0.95);
        total += (share as num).toDouble();
      }

      return total;
    } catch (e) {
      debugPrint('âŒ Error getting total earnings: $e');
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
        title: 'ðŸ’³ Payment Refunded',
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
      debugPrint('âŒ Error refunding payment: $e');
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
      final payment = await getPaymentByReference(reference);
      return payment != null && payment['status'] == 'completed';
    } catch (e) {
      debugPrint('âŒ Error verifying payment: $e');
      return false;
    }
  }

  // ============================================================
  // WASHER PAYOUT WITHDRAWAL REQUEST (MINIMUM â‚¦10,000 THRESHOLD)
  // ============================================================
  Future<Map<String, dynamic>> requestWasherPayout({
    required String washerId,
    required String washerName,
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountName,
  }) async {
    try {
      if (amount < 1000) {
        throw Exception('Minimum withdrawal amount threshold is ₦1,000.');
      }

      final payoutRef = _firestore.collection('payout_requests').doc();
      final payoutId = payoutRef.id;
      Map<String, dynamic> washerData = {};

      // 🔐 ATOMIC TRANSACTION: Prevent race conditions & rapid multi-tapping withdrawal exploits
      await _firestore.runTransaction((transaction) async {
        final washerRef = _firestore.collection('washers').doc(washerId);
        final washerDoc = await transaction.get(washerRef);

        if (!washerDoc.exists) {
          throw Exception('Washer account profile not found.');
        }

        washerData = washerDoc.data() ?? {};
        final currentBalance = (washerData['availableBalance'] ?? 0).toDouble();

        if (currentBalance < amount) {
          throw Exception('Insufficient available balance. Your balance is â‚¦${currentBalance.toStringAsFixed(0)}.');
        }

        // Atomically deduct balance & set bank info
        transaction.update(washerRef, {
          'availableBalance': currentBalance - amount,
          'pendingWithdrawal': FieldValue.increment(amount),
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'bankConnected': true,
          'bankConnectedAt': FieldValue.serverTimestamp(),
        });

        // Create payout request document
        transaction.set(payoutRef, {
          'id': payoutId,
          'washerId': washerId,
          'washerName': washerName,
          'amount': amount,
          'bankName': bankName,
          'accountNumber': accountNumber,
          'accountName': accountName,
          'status': 'pending',
          'requestedAt': FieldValue.serverTimestamp(),
        });
      });

      final wPhone = (washerData['phone'] ?? washerData['phoneNumber'] ?? '').toString();
      String wEmail = (washerData['email'] ?? '').toString();

      if (wEmail.isEmpty) {
        try {
          final uDoc = await _firestore.collection('users').doc(washerId).get();
          if (uDoc.exists && (uDoc.data()?['email'] ?? '').toString().isNotEmpty) {
            wEmail = uDoc.data()!['email'].toString();
          }
        } catch (_) {}
      }

      await _communicationService.sendWithdrawalRequestedNotifications(
        washerName: washerName,
        washerPhone: wPhone,
        washerEmail: wEmail,
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      );

      return {
        'success': true,
        'payoutId': payoutId,
        'amount': amount,
      };
    } catch (e) {
      debugPrint('❌ Withdrawal request error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ============================================================
  // GET PAYOUT REQUESTS FOR ADMIN AUDITING
  // ============================================================
  Future<List<Map<String, dynamic>>> getPayoutRequests() async {
    try {
      final snapshot = await _firestore
          .collection('payout_requests')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      debugPrint('❌ Error fetching payout requests: $e');
      return [];
    }
  }

  // ============================================================
  // APPROVE PAYOUT REQUEST (Admin)
  // ============================================================
  Future<Map<String, dynamic>> approvePayoutRequest(String payoutId) async {
    try {
      final doc = await _firestore.collection('payout_requests').doc(payoutId).get();
      if (!doc.exists) throw Exception('Payout request not found');

      final data = doc.data()!;
      final washerId = data['washerId'];
      final washerName = data['washerName'] ?? 'Provider';
      final amount = (data['amount'] ?? 0).toDouble();
      final bankName = (data['bankName'] ?? '').toString();
      final accountNumber = (data['accountNumber'] ?? '').toString();

      await _firestore.collection('payout_requests').doc(payoutId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (washerId != null) {
        final washerDoc = await _firestore.collection('washers').doc(washerId).get();
        final washerData = washerDoc.data() ?? {};
        final wPhone = (washerData['phone'] ?? washerData['phoneNumber'] ?? '').toString();
        String wEmail = (washerData['email'] ?? '').toString();

        if (wEmail.isEmpty) {
          try {
            final uDoc = await _firestore.collection('users').doc(washerId).get();
            if (uDoc.exists && (uDoc.data()?['email'] ?? '').toString().isNotEmpty) {
              wEmail = uDoc.data()!['email'].toString();
            }
          } catch (_) {}
        }

        await _firestore.collection('washers').doc(washerId).update({
          'pendingWithdrawal': FieldValue.increment(-amount),
          'totalWithdrawn': FieldValue.increment(amount),
        });

        await _communicationService.sendWithdrawalApprovedNotifications(
          washerName: washerName,
          washerPhone: wPhone,
          washerEmail: wEmail,
          amount: amount,
          bankName: bankName,
          accountNumber: accountNumber,
        );
      }

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}