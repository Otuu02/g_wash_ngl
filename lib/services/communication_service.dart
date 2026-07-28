// lib/services/communication_service.dart
import "package:cloud_firestore/cloud_firestore.dart";
import "app_notification_service.dart";

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

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
    _notificationService.addNotification(
      title: "✅ Booking Confirmed!",
      message: "Your $serviceName booking has been confirmed.",
      type: "booking",
      jobId: jobId,
    );
    print("📢 Booking notification sent for job: $jobId");
  }
}
