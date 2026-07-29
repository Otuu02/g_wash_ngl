// lib/services/communication_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_notification_service.dart';

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  // ============================================================
  // SEND BOOKING NOTIFICATIONS (SMS, Email, Push)
  // ============================================================
  Future<void> sendBookingNotifications({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required String location,
    required int price,
    String? providerName,
    String? providerPhone,
  }) async {
    // 1. Send push notification
    _notificationService.addNotification(
      title: "✅ Booking Confirmed!",
      message: "Your $serviceName booking has been confirmed. We are finding a provider for you.",
      type: "booking",
      jobId: jobId,
    );

    // 2. Store SMS record
    if (customerPhone.isNotEmpty) {
      await _firestore.collection('sms_logs').add({
        'jobId': jobId,
        'phone': customerPhone,
        'message': 'Hello $customerName, your $serviceName booking has been confirmed. We are finding a provider for you.',
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Store Email record
    if (customerEmail.isNotEmpty) {
      await _firestore.collection('email_logs').add({
        'jobId': jobId,
        'email': customerEmail,
        'subject': '✅ Booking Confirmed - G Wash NG',
        'message': 'Hello $customerName, your $serviceName booking has been confirmed.',
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    // 4. Update job with communication status
    await _firestore.collection('jobs').doc(jobId).update({
      'communicationSent': true,
      'smsSent': true,
      'emailSent': customerEmail.isNotEmpty,
      'notificationSent': true,
    });

    print("📢 Booking notifications sent for job: $jobId");
  }

  // ============================================================
  // SEND PROVIDER ASSIGNED NOTIFICATION
  // ============================================================
  Future<void> sendProviderAssignedNotifications({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
  }) async {
    final message = 'Hello $customerName, $providerName has been assigned to your $serviceName. ETA: $eta.';

    // Push notification
    _notificationService.addNotification(
      title: '🚚 Provider Assigned!',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS
    if (customerPhone.isNotEmpty) {
      await _firestore.collection('sms_logs').add({
        'jobId': jobId,
        'phone': customerPhone,
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    // Email
    if (customerEmail.isNotEmpty) {
      await _firestore.collection('email_logs').add({
        'jobId': jobId,
        'email': customerEmail,
        'subject': '🚚 Provider Assigned - G Wash NG',
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    print("📢 Provider assigned notifications sent for job: $jobId");
  }

  // ============================================================
  // SEND STATUS UPDATE NOTIFICATIONS
  // ============================================================
  Future<void> sendStatusUpdateNotification({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String status,
    required String message,
  }) async {
    // Push notification
    _notificationService.addNotification(
      title: '📢 Order Update: $status',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS
    if (customerPhone.isNotEmpty) {
      await _firestore.collection('sms_logs').add({
        'jobId': jobId,
        'phone': customerPhone,
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    // Email
    if (customerEmail.isNotEmpty) {
      await _firestore.collection('email_logs').add({
        'jobId': jobId,
        'email': customerEmail,
        'subject': '📢 Order Update: $status - G Wash NG',
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    print("📢 Status update notifications sent for job: $jobId");
  }

  // ============================================================
  // SEND COMPLETION NOTIFICATION
  // ============================================================
  Future<void> sendCompletionNotification({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required int price,
  }) async {
    final message = 'Hello $customerName, your $serviceName has been completed! Please make payment of ₦$price.';

    // Push notification
    _notificationService.addNotification(
      title: '🎉 Service Completed!',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS
    if (customerPhone.isNotEmpty) {
      await _firestore.collection('sms_logs').add({
        'jobId': jobId,
        'phone': customerPhone,
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    // Email
    if (customerEmail.isNotEmpty) {
      await _firestore.collection('email_logs').add({
        'jobId': jobId,
        'email': customerEmail,
        'subject': '🎉 Service Completed - G Wash NG',
        'message': message,
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    }

    print("📢 Completion notifications sent for job: $jobId");
  }
}
