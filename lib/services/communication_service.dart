// lib/services/communication_service.dart
// PURPOSE: Handle SMS, Email, and Push notifications for the app

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_notification_service.dart';

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  // ============================================================
  // SEND SMS NOTIFICATION
  // ============================================================
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? jobId,
  }) async {
    try {
      // Clean phone number
      final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      
      print('📱 Sending SMS to: $cleanedPhone');
      print('📱 Message: $message');

      // For now, we'll store SMS in Firestore as a record
      // You can integrate with Twilio, Africa's Talking, or other SMS providers
      
      await _firestore.collection('sms_logs').add({
        'phoneNumber': cleanedPhone,
        'message': message,
        'jobId': jobId,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Add to app notifications
      if (jobId != null) {
        _notificationService.addNotification(
          title: '📧 SMS Sent',
          message: message.length > 100 ? '${message.substring(0, 100)}...' : message,
          type: 'delivery',
          jobId: jobId,
        );
      }

      print('✅ SMS logged successfully');
      return true;
      
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  // ============================================================
  // SEND EMAIL NOTIFICATION
  // ============================================================
  Future<bool> sendEmail({
    required String email,
    required String subject,
    required String body,
    String? jobId,
  }) async {
    try {
      print('📧 Sending Email to: $email');
      print('📧 Subject: $subject');
      print('📧 Body: $body');

      // Store email in Firestore
      await _firestore.collection('email_logs').add({
        'email': email,
        'subject': subject,
        'body': body,
        'jobId': jobId,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Add to app notifications
      if (jobId != null) {
        _notificationService.addNotification(
          title: '📧 Email Sent',
          message: subject,
          type: 'delivery',
          jobId: jobId,
        );
      }

      print('✅ Email logged successfully');
      return true;
      
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  // ============================================================
  // SEND ORDER CONFIRMATION
  // ============================================================
  Future<void> sendOrderConfirmation({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required String location,
    required int price,
    required DateTime scheduledDate,
    required String scheduledTime,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName booking has been confirmed! 🎉

📍 Location: $location
📅 Date: ${_formatDate(scheduledDate)}
⏰ Time: $scheduledTime
💰 Amount: ₦${price.toString()}

You will receive updates when a provider is assigned.

Thank you for using G Wash NG! 🚗
    ''';

    // Send SMS
    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    // Send Email
    await sendEmail(
      email: customerEmail,
      subject: '✅ Booking Confirmed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    // Add to app notifications
    _notificationService.addNotification(
      title: '✅ Booking Confirmed!',
      message: 'Your $serviceName booking has been confirmed.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER ASSIGNED NOTIFICATION
  // ============================================================
  Future<void> sendProviderAssigned({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
  }) async {
    final message = '''
Hello $customerName,

A provider has been assigned to your $serviceName! 🚚

👤 Provider: $providerName
⏰ ETA: $eta

You can track your provider in the app.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🚚 Provider Assigned - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🚚 Provider Assigned!',
      message: '$providerName is on the way for your $serviceName.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER EN ROUTE NOTIFICATION
  // ============================================================
  Future<void> sendProviderEnRoute({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
  }) async {
    final message = '''
Hello $customerName,

$providerName is on the way to you! 🚗

📍 Service: $serviceName
⏰ ETA: $eta

Your provider will arrive shortly.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🚗 Provider On The Way - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🚗 Provider On The Way!',
      message: '$providerName is $eta away with your $serviceName.',
      type: 'delivery',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER ARRIVED NOTIFICATION
  // ============================================================
  Future<void> sendProviderArrived({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
  }) async {
    final message = '''
Hello $customerName,

$providerName has arrived at your location! 📍

Service: $serviceName

Please check your app to confirm.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '📍 Provider Arrived - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '📍 Provider Arrived!',
      message: '$providerName has arrived for your $serviceName.',
      type: 'delivery',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND SERVICE COMPLETED NOTIFICATION
  // ============================================================
  Future<void> sendServiceCompleted({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required int price,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName has been completed! 🎉

💰 Amount: ₦${price.toString()}
💳 Please complete payment in the app.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🎉 Service Completed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🎉 Service Completed!',
      message: 'Your $serviceName has been completed. Please make payment.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PAYMENT CONFIRMATION
  // ============================================================
  Future<void> sendPaymentConfirmation({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required int amount,
    required String reference,
  }) async {
    final message = '''
Hello $customerName,

Payment confirmed! 💰

Service: $serviceName
Amount: ₦${amount.toString()}
Reference: $reference

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '💰 Payment Confirmed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '💰 Payment Successful!',
      message: 'Your payment of ₦${amount.toString()} for $serviceName was successful.',
      type: 'payment',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND ORDER CANCELLED NOTIFICATION
  // ============================================================
  Future<void> sendOrderCancelled({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required String reason,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName booking has been cancelled. ❌

Reason: $reason

If you have any questions, please contact support.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '❌ Booking Cancelled - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '❌ Booking Cancelled',
      message: 'Your $serviceName booking has been cancelled.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROMOTIONAL OFFER
  // ============================================================
  Future<void> sendPromotionalOffer({
    required String customerPhone,
    required String customerEmail,
    required String title,
    required String message,
  }) async {
    await sendSms(
      phoneNumber: customerPhone,
      message: '🎉 $title\n\n$message',
    );

    await sendEmail(
      email: customerEmail,
      subject: '🎉 $title - G Wash NG',
      body: message,
    );

    _notificationService.addNotification(
      title: '🎉 $title',
      message: message,
      type: 'promo',
    );
  }

  // ============================================================
  // GET USER CONTACT DETAILS
  // ============================================================
  Future<Map<String, String>> getUserContactDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? 'Customer',
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
        };
      }
      return {
        'name': 'Customer',
        'phone': '',
        'email': '',
      };
    } catch (e) {
      print('❌ Error getting user contact details: $e');
      return {
        'name': 'Customer',
        'phone': '',
        'email': '',
      };
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // GET SMS LOGS
  // ============================================================
  Future<List<Map<String, dynamic>>> getSmsLogs({String? jobId}) async {
    try {
      Query query = _firestore.collection('sms_logs');
      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }
      final snapshot = await query.orderBy('sentAt', descending: true).limit(50).get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting SMS logs: $e');
      return [];
    }
  }

  // ============================================================
  // GET EMAIL LOGS
  // ============================================================
  Future<List<Map<String, dynamic>>> getEmailLogs({String? jobId}) async {
    try {
      Query query = _firestore.collection('email_logs');
      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }
      final snapshot = await query.orderBy('sentAt', descending: true).limit(50).get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting email logs: $e');
      return [];
    }
  }
}
EOFcat > lib/services/communication_service.dart << 'EOF'
// lib/services/communication_service.dart
// PURPOSE: Handle SMS, Email, and Push notifications for the app

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_notification_service.dart';

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  // ============================================================
  // SEND SMS NOTIFICATION
  // ============================================================
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? jobId,
  }) async {
    try {
      // Clean phone number
      final cleanedPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      
      print('📱 Sending SMS to: $cleanedPhone');
      print('📱 Message: $message');

      // For now, we'll store SMS in Firestore as a record
      // You can integrate with Twilio, Africa's Talking, or other SMS providers
      
      await _firestore.collection('sms_logs').add({
        'phoneNumber': cleanedPhone,
        'message': message,
        'jobId': jobId,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Add to app notifications
      if (jobId != null) {
        _notificationService.addNotification(
          title: '📧 SMS Sent',
          message: message.length > 100 ? '${message.substring(0, 100)}...' : message,
          type: 'delivery',
          jobId: jobId,
        );
      }

      print('✅ SMS logged successfully');
      return true;
      
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  // ============================================================
  // SEND EMAIL NOTIFICATION
  // ============================================================
  Future<bool> sendEmail({
    required String email,
    required String subject,
    required String body,
    String? jobId,
  }) async {
    try {
      print('📧 Sending Email to: $email');
      print('📧 Subject: $subject');
      print('📧 Body: $body');

      // Store email in Firestore
      await _firestore.collection('email_logs').add({
        'email': email,
        'subject': subject,
        'body': body,
        'jobId': jobId,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });

      // Add to app notifications
      if (jobId != null) {
        _notificationService.addNotification(
          title: '📧 Email Sent',
          message: subject,
          type: 'delivery',
          jobId: jobId,
        );
      }

      print('✅ Email logged successfully');
      return true;
      
    } catch (e) {
      print('❌ Error sending email: $e');
      return false;
    }
  }

  // ============================================================
  // SEND ORDER CONFIRMATION
  // ============================================================
  Future<void> sendOrderConfirmation({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required String location,
    required int price,
    required DateTime scheduledDate,
    required String scheduledTime,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName booking has been confirmed! 🎉

📍 Location: $location
📅 Date: ${_formatDate(scheduledDate)}
⏰ Time: $scheduledTime
💰 Amount: ₦${price.toString()}

You will receive updates when a provider is assigned.

Thank you for using G Wash NG! 🚗
    ''';

    // Send SMS
    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    // Send Email
    await sendEmail(
      email: customerEmail,
      subject: '✅ Booking Confirmed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    // Add to app notifications
    _notificationService.addNotification(
      title: '✅ Booking Confirmed!',
      message: 'Your $serviceName booking has been confirmed.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER ASSIGNED NOTIFICATION
  // ============================================================
  Future<void> sendProviderAssigned({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
  }) async {
    final message = '''
Hello $customerName,

A provider has been assigned to your $serviceName! 🚚

👤 Provider: $providerName
⏰ ETA: $eta

You can track your provider in the app.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🚚 Provider Assigned - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🚚 Provider Assigned!',
      message: '$providerName is on the way for your $serviceName.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER EN ROUTE NOTIFICATION
  // ============================================================
  Future<void> sendProviderEnRoute({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
  }) async {
    final message = '''
Hello $customerName,

$providerName is on the way to you! 🚗

📍 Service: $serviceName
⏰ ETA: $eta

Your provider will arrive shortly.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🚗 Provider On The Way - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🚗 Provider On The Way!',
      message: '$providerName is $eta away with your $serviceName.',
      type: 'delivery',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROVIDER ARRIVED NOTIFICATION
  // ============================================================
  Future<void> sendProviderArrived({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
  }) async {
    final message = '''
Hello $customerName,

$providerName has arrived at your location! 📍

Service: $serviceName

Please check your app to confirm.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '📍 Provider Arrived - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '📍 Provider Arrived!',
      message: '$providerName has arrived for your $serviceName.',
      type: 'delivery',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND SERVICE COMPLETED NOTIFICATION
  // ============================================================
  Future<void> sendServiceCompleted({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required int price,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName has been completed! 🎉

💰 Amount: ₦${price.toString()}
💳 Please complete payment in the app.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '🎉 Service Completed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '🎉 Service Completed!',
      message: 'Your $serviceName has been completed. Please make payment.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PAYMENT CONFIRMATION
  // ============================================================
  Future<void> sendPaymentConfirmation({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required int amount,
    required String reference,
  }) async {
    final message = '''
Hello $customerName,

Payment confirmed! 💰

Service: $serviceName
Amount: ₦${amount.toString()}
Reference: $reference

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '💰 Payment Confirmed - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '💰 Payment Successful!',
      message: 'Your payment of ₦${amount.toString()} for $serviceName was successful.',
      type: 'payment',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND ORDER CANCELLED NOTIFICATION
  // ============================================================
  Future<void> sendOrderCancelled({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required String reason,
  }) async {
    final message = '''
Hello $customerName,

Your $serviceName booking has been cancelled. ❌

Reason: $reason

If you have any questions, please contact support.

Thank you for using G Wash NG! 🚗
    ''';

    await sendSms(
      phoneNumber: customerPhone,
      message: message,
      jobId: jobId,
    );

    await sendEmail(
      email: customerEmail,
      subject: '❌ Booking Cancelled - G Wash NG',
      body: message,
      jobId: jobId,
    );

    _notificationService.addNotification(
      title: '❌ Booking Cancelled',
      message: 'Your $serviceName booking has been cancelled.',
      type: 'booking',
      jobId: jobId,
    );
  }

  // ============================================================
  // SEND PROMOTIONAL OFFER
  // ============================================================
  Future<void> sendPromotionalOffer({
    required String customerPhone,
    required String customerEmail,
    required String title,
    required String message,
  }) async {
    await sendSms(
      phoneNumber: customerPhone,
      message: '🎉 $title\n\n$message',
    );

    await sendEmail(
      email: customerEmail,
      subject: '🎉 $title - G Wash NG',
      body: message,
    );

    _notificationService.addNotification(
      title: '🎉 $title',
      message: message,
      type: 'promo',
    );
  }

  // ============================================================
  // GET USER CONTACT DETAILS
  // ============================================================
  Future<Map<String, String>> getUserContactDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'name': data['name'] ?? 'Customer',
          'phone': data['phone'] ?? '',
          'email': data['email'] ?? '',
        };
      }
      return {
        'name': 'Customer',
        'phone': '',
        'email': '',
      };
    } catch (e) {
      print('❌ Error getting user contact details: $e');
      return {
        'name': 'Customer',
        'phone': '',
        'email': '',
      };
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================================
  // GET SMS LOGS
  // ============================================================
  Future<List<Map<String, dynamic>>> getSmsLogs({String? jobId}) async {
    try {
      Query query = _firestore.collection('sms_logs');
      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }
      final snapshot = await query.orderBy('sentAt', descending: true).limit(50).get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting SMS logs: $e');
      return [];
    }
  }

  // ============================================================
  // GET EMAIL LOGS
  // ============================================================
  Future<List<Map<String, dynamic>>> getEmailLogs({String? jobId}) async {
    try {
      Query query = _firestore.collection('email_logs');
      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }
      final snapshot = await query.orderBy('sentAt', descending: true).limit(50).get();
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      print('❌ Error getting email logs: $e');
      return [];
    }
  }
}
