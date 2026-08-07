// FILE: lib/services/communication_service.dart
// PURPOSE: Send SMS (Twilio), Email (Gmail SMTP), and Push Notifications to Customers and Service Providers

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import 'app_notification_service.dart';
import 'twilio_service.dart';
import 'smtp_email_service.dart';

class CommunicationService {
  static final CommunicationService _instance = CommunicationService._internal();
  factory CommunicationService() => _instance;
  CommunicationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();
  final TwilioService _twilioService = TwilioService();
  final SmtpEmailService _smtpEmailService = SmtpEmailService();

  // ============================================================
  // SEND REAL SMS (Twilio Exclusively)
  // ============================================================
  Future<bool> sendRealSms({
    required String phone,
    required String message,
  }) async {
    try {
      if (phone.isEmpty) return false;

      // Send via Twilio SMS API
      bool twilioSuccess = await _twilioService.sendSms(to: phone, message: message);

      // Log SMS in Firestore
      await _firestore.collection('sms_logs').add({
        'phone': phone,
        'message': message,
        'provider': 'Twilio',
        'status': twilioSuccess ? 'sent' : 'logged',
        'sentAt': FieldValue.serverTimestamp(),
      });

      return twilioSuccess;
    } catch (e) {
      debugPrint('❌ Error sending Twilio SMS: $e');
      return false;
    }
  }

  // ============================================================
  // SEND REAL EMAIL (Gmail SMTP Exclusively)
  // ============================================================
  Future<bool> sendRealEmail({
    required String email,
    required String subject,
    required String body,
    String? htmlBody,
  }) async {
    try {
      if (email.isEmpty) return false;

      final formattedHtml = htmlBody ??
          '''
          <div style="font-family: Arial, sans-serif; padding: 20px; color: #333; max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 10px;">
            <h2 style="color: #008080;">G-Wash NG</h2>
            <p style="font-size: 16px; line-height: 1.5;">${body.replaceAll('\n', '<br>')}</p>
            <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
            <p style="font-size: 12px; color: #888;">G-Wash NG — On-Demand Cleaning & Service Marketplace</p>
          </div>
          ''';

      // Send via Gmail SMTP
      bool smtpSuccess = await _smtpEmailService.sendEmail(
        recipient: email,
        subject: subject,
        bodyHtml: formattedHtml,
        bodyText: body,
      );

      // Log Email in Firestore
      await _firestore.collection('email_logs').add({
        'email': email,
        'subject': subject,
        'body': body,
        'provider': 'Gmail SMTP',
        'status': smtpSuccess ? 'sent' : 'logged',
        'sentAt': FieldValue.serverTimestamp(),
      });

      return smtpSuccess;
    } catch (e) {
      debugPrint('❌ Error sending Gmail SMTP Email: $e');
      return false;
    }
  }

  // ============================================================
  // SEND BOOKING NOTIFICATIONS (Customer & Provider)
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
    String? providerEmail,
  }) async {
    final customerSmsMessage = 'Hello $customerName, your $serviceName booking (₦$price) has been confirmed on G Wash NG. Location: $location.';
    final customerEmailSubject = '✅ Booking Confirmed - G Wash NG';

    // 1. In-App Banner Popup & Local Push to Customer
    _notificationService.notify(
      title: "✅ Booking Confirmed!",
      message: "Your $serviceName booking has been placed successfully.",
      type: "booking",
      jobId: jobId,
    );

    // 2. Send SMS & Email to Customer
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: customerSmsMessage);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: customerEmailSubject,
        body: customerSmsMessage,
      );
    }

    // 3. Send SMS & Email to Service Provider (if provider info provided)
    if (providerPhone != null && providerPhone.isNotEmpty) {
      final providerSmsMessage = '🚗 New Job Alert! Customer: $customerName ($customerPhone) booked $serviceName at $location (₦$price). Please open G Wash NG to accept.';
      await sendRealSms(phone: providerPhone, message: providerSmsMessage);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      final providerEmailSubject = '🚨 New Job Request - G Wash NG';
      final providerEmailBody = 'Hello $providerName,\n\nYou have a new job request for $serviceName.\nCustomer: $customerName\nPhone: $customerPhone\nLocation: $location\nPrice: ₦$price\n\nPlease log in to G Wash NG to accept the request.';
      await sendRealEmail(
        email: providerEmail,
        subject: providerEmailSubject,
        body: providerEmailBody,
      );
    }

    // 4. Update Job Document with Communication Flag
    await _firestore.collection('jobs').doc(jobId).update({
      'communicationSent': true,
      'smsSent': true,
      'emailSent': customerEmail.isNotEmpty,
      'notificationSent': true,
    });

    debugPrint("📢 Booking notifications dispatched for job: $jobId");
  }

  // ============================================================
  // SEND PROVIDER ASSIGNED NOTIFICATIONS
  // ============================================================
  Future<void> sendProviderAssignedNotifications({
    required String jobId,
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String providerName,
    required String serviceName,
    required String eta,
    String? providerPhone,
    String? providerEmail,
  }) async {
    final message = 'Hello $customerName, $providerName has been assigned to your $serviceName. ETA: $eta.';

    // Push & Banner Popup
    _notificationService.notify(
      title: 'Provider Assigned',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS & Email to Customer
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: message);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Provider Assigned - G Wash NG',
        body: message,
      );
    }

    // Notification to Provider
    if (providerPhone != null && providerPhone.isNotEmpty) {
      await sendRealSms(
        phone: providerPhone,
        message: 'You have been assigned to job #$jobId ($serviceName) for $customerName.',
      );
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      await sendRealEmail(
        email: providerEmail,
        subject: 'Job Assignment Confirmed - G Wash NG',
        body: 'Hello $providerName,\n\nYou have been assigned to $serviceName for customer $customerName ($customerPhone). Job ID: $jobId.',
      );
    }

    debugPrint("Status update notifications dispatched for job: $jobId");
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
    String? providerPhone,
  }) async {
    // Push & Banner Popup
    _notificationService.notify(
      title: 'Order Update: $status',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS & Email to Customer
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: message);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Order Update: $status - G Wash NG',
        body: message,
      );
    }

    debugPrint("Status update notifications dispatched for job: $jobId");
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
    String? providerPhone,
  }) async {
    final message = 'Hello $customerName, your $serviceName has been completed! Amount: ₦$price. Thank you for using G Wash NG.';

    // Push & Banner Popup
    _notificationService.notify(
      title: 'Service Completed',
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // SMS & Email
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: message);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Service Completed - G Wash NG',
        body: message,
      );
    }

    if (providerPhone != null && providerPhone.isNotEmpty) {
      await sendRealSms(
        phone: providerPhone,
        message: 'Job #$jobId ($serviceName) completed successfully. Earnings credited to your wallet!',
      );
    }

    debugPrint("Completion notifications dispatched for job: $jobId");
  }

  // ============================================================
  // SEND CANCELLATION NOTIFICATIONS (FOR CLIENT & WASHER END)
  // ============================================================
  Future<void> sendCancellationNotifications({
    required String jobId,
    required String serviceName,
    required String reason,
    required String cancelledBy,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
  }) async {
    final title = 'Order Cancelled ($serviceName)';
    final message = 'Order #$jobId ($serviceName) was cancelled by $cancelledBy. Reason: $reason';

    // Status bar push notification + popup overlay
    _notificationService.notify(
      title: title,
      message: message,
      type: 'booking',
      jobId: jobId,
    );

    // Notify Customer
    if (customerPhone != null && customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: message);
    }
    if (customerEmail != null && customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Booking Cancellation - G Wash NG',
        body: 'Hello ${customerName ?? 'Customer'},\n\nYour booking for $serviceName has been cancelled.\nCancelled By: $cancelledBy\nReason: $reason\n\nIf you have any questions, please contact support in the app.',
      );
    }

    // Notify Provider
    if (providerPhone != null && providerPhone.isNotEmpty) {
      await sendRealSms(phone: providerPhone, message: message);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      await sendRealEmail(
        email: providerEmail,
        subject: 'Booking Cancellation Notice - G Wash NG',
        body: 'Hello ${providerName ?? 'Provider'},\n\nBooking #$jobId for $serviceName has been cancelled.\nCancelled By: $cancelledBy\nReason: $reason',
      );
    }

    debugPrint("Cancellation notifications dispatched for job: $jobId");
  }

  // ============================================================
  // SEND PAYMENT COMPLETED & RECEIVED NOTIFICATIONS
  // ============================================================
  Future<void> sendPaymentCompletedNotifications({
    required String customerName,
    required String customerPhone,
    required String customerEmail,
    required String serviceName,
    required double amount,
    required String reference,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
    double? providerShare,
  }) async {
    final customerMsg = 'Hello $customerName, your payment of ₦${amount.toStringAsFixed(0)} for $serviceName was successful! Ref: $reference.';

    // Push Notification in Status Bar + Banner Popup
    _notificationService.notify(
      title: 'Payment Successful',
      message: 'Paid ₦${amount.toStringAsFixed(0)} for $serviceName. Ref: $reference',
      type: 'payment',
    );

    // SMS & Email to Customer
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: customerMsg);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Payment Receipt - G Wash NG',
        body: customerMsg,
      );
    }

    // Payment Received Notification to Provider
    if (providerPhone != null && providerPhone.isNotEmpty) {
      final pShareStr = providerShare != null ? ' (₦${providerShare.toStringAsFixed(0)} credited to your balance)' : '';
      final providerMsg = 'Payment Received! Customer $customerName paid ₦${amount.toStringAsFixed(0)} for $serviceName$pShareStr.';
      await sendRealSms(phone: providerPhone, message: providerMsg);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      final providerEmailBody = 'Hello $providerName,\n\nPayment has been received for $serviceName.\nCustomer: $customerName\nTotal Amount: ₦${amount.toStringAsFixed(0)}\nYour Share (95%): ₦${(providerShare ?? amount * 0.95).toStringAsFixed(0)}\n\nThank you for providing great service on G Wash NG!';
      await sendRealEmail(
        email: providerEmail,
        subject: 'Payment Received - G Wash NG',
        body: providerEmailBody,
      );
    }

    debugPrint("Payment completed & received notifications dispatched for ref: $reference");
  }

  // ============================================================
  // SEND WALLET FUNDED NOTIFICATIONS
  // ============================================================
  Future<void> sendWalletFundedNotifications({
    required String userPhone,
    required String userEmail,
    required double amount,
  }) async {
    final msg = 'Your G Wash NG wallet has been funded with ₦${amount.toStringAsFixed(0)}. Total balance updated!';

    _notificationService.notify(
      title: 'Wallet Funded',
      message: msg,
      type: 'payment',
    );

    if (userPhone.isNotEmpty) {
      await sendRealSms(phone: userPhone, message: msg);
    }
    if (userEmail.isNotEmpty) {
      await sendRealEmail(
        email: userEmail,
        subject: 'Wallet Deposit Confirmed - G Wash NG',
        body: msg,
      );
    }
  }

  // ============================================================
  // SEND WITHDRAWAL REQUESTED NOTIFICATIONS
  // ============================================================
  Future<void> sendWithdrawalRequestedNotifications({
    required String washerName,
    required String washerPhone,
    required String washerEmail,
    required double amount,
  }) async {
    final msg = 'Hello $washerName, your withdrawal request for ₦${amount.toStringAsFixed(0)} has been received and is being processed by admin.';

    _notificationService.notify(
      title: 'Withdrawal Pending',
      message: 'Requested ₦${amount.toStringAsFixed(0)} payout to your bank account.',
      type: 'payment',
    );

    if (washerPhone.isNotEmpty) {
      await sendRealSms(phone: washerPhone, message: msg);
    }
    if (washerEmail.isNotEmpty) {
      await sendRealEmail(
        email: washerEmail,
        subject: 'Withdrawal Request Submitted - G Wash NG',
        body: msg,
      );
    }
  }

  // ============================================================
  // SEND WITHDRAWAL APPROVED & COMPLETED NOTIFICATIONS
  // ============================================================
  Future<void> sendWithdrawalApprovedNotifications({
    required String washerName,
    required String washerPhone,
    required String washerEmail,
    required double amount,
  }) async {
    final msg = 'Withdrawal Approved! ₦${amount.toStringAsFixed(0)} has been transferred to your bank account.';

    _notificationService.notify(
      title: 'Withdrawal Successful',
      message: '₦${amount.toStringAsFixed(0)} has been paid to your bank account.',
      type: 'payment',
    );

    if (washerPhone.isNotEmpty) {
      await sendRealSms(phone: washerPhone, message: msg);
    }
    if (washerEmail.isNotEmpty) {
      await sendRealEmail(
        email: washerEmail,
        subject: 'Payout Transfer Completed - G Wash NG',
        body: msg,
      );
    }
  }
}
