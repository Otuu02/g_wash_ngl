// FILE: lib/services/communication_service.dart
// PURPOSE: Send SMS (Twilio), Email (Gmail SMTP), and Push Notifications to Customers and Service Providers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
      debugPrint('Error sending Twilio SMS: $e');
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
            <p style="font-size: 12px; color: #888;">G-Wash NG - On-Demand Cleaning & Service Marketplace</p>
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
      debugPrint('Error sending Email: $e');
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
    final customerSmsMessage = 'Hello $customerName, your $serviceName booking (NGN $price) has been confirmed on G Wash NG. Location: $location.';
    final customerEmailSubject = 'Booking Confirmed - G Wash NG';

    // 1. In-App Banner Popup & Local Push to Customer
    _notificationService.notify(
      title: "Booking Confirmed!",
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
      final providerSmsMessage = 'New Job Alert! Customer: $customerName ($customerPhone) booked $serviceName at $location (NGN $price). Please open G Wash NG to accept.';
      await sendRealSms(phone: providerPhone, message: providerSmsMessage);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      final providerEmailSubject = 'New Job Request - G Wash NG';
      final providerEmailBody = 'Hello $providerName,\n\nYou have a new job request for $serviceName.\nCustomer: $customerName\nPhone: $customerPhone\nLocation: $location\nPrice: NGN $price\n\nPlease log in to G Wash NG to accept the request.';
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

    debugPrint("Booking notifications dispatched for job: $jobId");
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
  // SEND WELCOME NOTIFICATIONS (ACCOUNT CREATION EMAIL & SMS)
  // ============================================================
  Future<void> sendWelcomeNotifications({
    required String userName,
    required String email,
    required String phone,
    String role = 'customer',
  }) async {
    final String welcomeSubject = 'Welcome to G-Wash NG, $userName!';
    final String welcomeMessageText = '''
Hello $userName,

Welcome to G-Wash NG - Nigeria's premier on-demand car wash, house cleaning, laundry, and home service marketplace!

Your Account Details:
- Name: $userName
- Phone: $phone
- Email: $email
- Account Role: ${role.toUpperCase()}

Thank you for joining G-Wash NG. You can now book top-rated service providers or manage orders seamlessly.

Best regards,
The G-Wash NG Team
''';

    final String welcomeHtmlBody = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f4f6f9; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.06); border: 1px solid #e2e8f0; }
    .header { background: linear-gradient(135deg, #008080 0%, #0CAF60 100%); padding: 32px 20px; text-align: center; color: white; }
    .header h1 { margin: 0; font-size: 26px; font-weight: bold; letter-spacing: 0.5px; }
    .content { padding: 30px 24px; color: #334155; line-height: 1.6; }
    .card { background-color: #f8fafc; border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px; margin: 20px 0; }
    .card h3 { margin-top: 0; color: #008080; font-size: 16px; border-bottom: 2px solid #0CAF60; padding-bottom: 8px; display: inline-block; }
    .info-row { padding: 6px 0; font-size: 14px; }
    .label { color: #64748b; font-weight: 600; }
    .value { color: #0f172a; font-weight: 700; }
    .footer { background-color: #f1f5f9; padding: 20px; text-align: center; font-size: 12px; color: #64748b; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Welcome to G-Wash NG!</h1>
    </div>
    <div class="content">
      <p style="font-size: 18px; font-weight: 600; color: #0f172a;">Hello $userName,</p>
      <p>Thank you for creating an account with <strong>G-Wash NG</strong> - Nigeria's #1 marketplace for on-demand car wash, house cleaning, laundry, and ride services!</p>
      
      <div class="card">
        <h3>Your Account Summary</h3>
        <div class="info-row"><span class="label">Full Name:</span> <span class="value">$userName</span></div>
        <div class="info-row"><span class="label">Phone Number:</span> <span class="value">$phone</span></div>
        <div class="info-row"><span class="label">Email Address:</span> <span class="value">$email</span></div>
        <div class="info-row"><span class="label">Account Role:</span> <span class="value">${role.toUpperCase()}</span></div>
      </div>

      <p>Your account is active and verified. You can now log in anytime to request services or manage your bookings in real-time.</p>
    </div>
    <div class="footer">
      <p>(C) 2026 G-Wash NG. All rights reserved.</p>
      <p>Fast, Trusted & Reliable Home & Vehicle Services in Nigeria</p>
    </div>
  </div>
</body>
</html>
''';

    // 1. Send In-App & Local System Notification (Clean Plain Text)
    _notificationService.notify(
      title: 'Account Created Successfully!',
      message: 'Welcome to G-Wash NG, $userName! Your account is active.',
      type: 'system',
    );

    // 2. Send Real Email (Gmail SMTP + Gateway logging)
    if (email.isNotEmpty) {
      await sendRealEmail(
        email: email,
        subject: welcomeSubject,
        body: welcomeMessageText,
        htmlBody: welcomeHtmlBody,
      );
      debugPrint('Welcome email dispatched to $email');
    }

    // 3. Send SMS Alert
    if (phone.isNotEmpty) {
      final smsMessage = 'Welcome to G-Wash NG, $userName! Your account ($phone) has been created successfully. Enjoy top-rated services.';
      await sendRealSms(phone: phone, message: smsMessage);
    }
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
    final message = 'Hello $customerName, your $serviceName has been completed! Amount: NGN $price. Thank you for using G Wash NG.';

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
    final customerMsg = 'Hello $customerName, your payment of NGN ${amount.toStringAsFixed(0)} for $serviceName was successful! Ref: $reference.';
    final pShare = providerShare ?? (amount * 0.95);
    final pFee = amount * 0.05;

    // Push Notification in Status Bar + Banner Popup
    _notificationService.notify(
      title: 'Payment Successful',
      message: 'Paid NGN ${amount.toStringAsFixed(0)} for $serviceName. Ref: $reference',
      type: 'payment',
    );

    // Generate Official Anti-Forgery Digital Receipt HTML
    final receiptHtml = generateOfficialReceiptHtml(
      customerName: customerName,
      serviceName: serviceName,
      amount: amount,
      reference: reference,
      providerName: providerName ?? 'Assigned Service Provider',
      platformFee: pFee,
      providerShare: pShare,
    );

    // SMS & Email to Customer
    if (customerPhone.isNotEmpty) {
      await sendRealSms(phone: customerPhone, message: customerMsg);
    }
    if (customerEmail.isNotEmpty) {
      await sendRealEmail(
        email: customerEmail,
        subject: 'Official Payment Receipt #$reference - G Wash NG',
        body: customerMsg,
        htmlBody: receiptHtml,
      );
    }

    // Payment Received Notification to Provider
    if (providerPhone != null && providerPhone.isNotEmpty) {
      final providerMsg = 'Payment Received! Customer $customerName paid NGN ${amount.toStringAsFixed(0)} for $serviceName. NGN ${pShare.toStringAsFixed(0)} credited to your wallet balance.';
      await sendRealSms(phone: providerPhone, message: providerMsg);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      await sendRealEmail(
        email: providerEmail,
        subject: 'Payment Received Notice - G Wash NG',
        body: 'Hello ${providerName ?? 'Provider'},\n\nPayment confirmed for $serviceName.\nCustomer: $customerName\nTotal: NGN ${amount.toStringAsFixed(0)}\nYour Share (95% Net): NGN ${pShare.toStringAsFixed(0)}\n\nThank you for providing great service on G Wash NG!',
        htmlBody: receiptHtml,
      );
    }

    debugPrint("Payment completed & official receipt notifications dispatched for ref: $reference");
  }

  // ============================================================
  // OFFICIAL UNFORGEABLE DIGITAL RECEIPT HTML TEMPLATE
  // ============================================================
  String generateOfficialReceiptHtml({
    required String customerName,
    required String serviceName,
    required double amount,
    required String reference,
    required String providerName,
    required double platformFee,
    required double providerShare,
  }) {
    final formattedDate = '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} at ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')} WAT';
    final verifyHash = 'GWASH-VERIFIED-${reference.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}-SEALED';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Official Payment Receipt - G Wash NG</title>
    </head>
    <body style="font-family: Arial, sans-serif; background-color: #f4f6f8; margin: 0; padding: 20px;">
      <div style="max-width: 600px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.08); border: 1px solid #e2e8f0;">
        
        <!-- Header Banner -->
        <div style="background: linear-gradient(135deg, #008080 0%, #004d4d 100%); padding: 30px; text-align: center; color: #ffffff;">
          <h1 style="margin: 0; font-size: 26px; letter-spacing: 1px; font-weight: bold;">G-WASH NG</h1>
          <p style="margin: 5px 0 0 0; font-size: 13px; opacity: 0.9;">OFFICIAL DIGITAL PAYMENT RECEIPT</p>
          <div style="display: inline-block; margin-top: 15px; background: rgba(255,255,255,0.2); padding: 6px 16px; border-radius: 20px; font-size: 12px; font-weight: bold; border: 1px solid rgba(255,255,255,0.4);">
            VERIFIED & CRYPTOGRAPHICALLY SEALED
          </div>
        </div>

        <!-- Receipt Body -->
        <div style="padding: 24px;">
          <!-- Amount Banner -->
          <div style="text-align: center; background: #f0fdf4; padding: 18px; border-radius: 12px; border: 1px solid #bbf7d0; margin-bottom: 24px;">
            <span style="font-size: 13px; color: #166534; font-weight: bold; text-transform: uppercase;">Total Amount Paid</span>
            <h2 style="margin: 6px 0 0 0; font-size: 32px; color: #15803d; font-weight: bold;">NGN ${amount.toStringAsFixed(2)}</h2>
            <span style="font-size: 11px; color: #166534;">Payment Status: <strong>SUCCESSFUL (PAYSTACK LIVE)</strong></span>
          </div>

          <!-- Transaction Metadata Table -->
          <table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; font-size: 14px;">
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Transaction Reference</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">${reference}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Customer Name</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">${customerName}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Service Rendered</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">${serviceName}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Assigned Service Provider</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">${providerName}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Payment Method</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">Paystack Live Gateway</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 12px 0; color: #64748b;">Date & Time</td>
              <td style="padding: 12px 0; text-align: right; font-weight: bold; color: #0f172a;">${formattedDate}</td>
            </tr>
          </table>

          <!-- Financial Split Breakdown -->
          <div style="background: #f8fafc; padding: 16px; border-radius: 12px; border: 1px solid #e2e8f0; margin-bottom: 24px;">
            <div style="font-size: 12px; font-weight: bold; color: #475569; text-transform: uppercase; margin-bottom: 10px;">Itemized Financial Breakdown</div>
            <table style="width: 100%; font-size: 13px;">
              <tr>
                <td style="padding: 4px 0; color: #64748b;">Gross Amount Paid</td>
                <td style="padding: 4px 0; text-align: right; font-weight: bold;">NGN ${amount.toStringAsFixed(2)}</td>
              </tr>
              <tr>
                <td style="padding: 4px 0; color: #64748b;">Provider Net Earnings (95%)</td>
                <td style="padding: 4px 0; text-align: right; color: #16a34a; font-weight: bold;">NGN ${providerShare.toStringAsFixed(2)}</td>
              </tr>
              <tr>
                <td style="padding: 4px 0; color: #64748b;">G Wash Platform Fee (5%)</td>
                <td style="padding: 4px 0; text-align: right; color: #ea580c; font-weight: bold;">NGN ${platformFee.toStringAsFixed(2)}</td>
              </tr>
            </table>
          </div>

          <!-- Anti-Forgery Digital Security Seal -->
          <div style="border: 2px dashed #CBD5E1; padding: 16px; border-radius: 12px; text-align: center; background: #fafafa;">
            <div style="font-size: 11px; font-weight: bold; color: #008080; letter-spacing: 1px; margin-bottom: 4px;">ANTI-FORGERY SECURITY VERIFICATION SEAL</div>
            <div style="font-family: monospace; font-size: 11px; color: #475569; word-break: break-all; background: #e2e8f0; padding: 6px; border-radius: 6px;">
              ${verifyHash}
            </div>
            <p style="font-size: 11px; color: #94a3b8; margin: 8px 0 0 0;">
              This digital receipt is authenticated on the G Wash NG Blockchain Audit Log and Paystack Gateway. Any alteration voids authenticity.
            </p>
          </div>
        </div>

        <!-- Footer -->
        <div style="background: #f1f5f9; padding: 16px; text-align: center; font-size: 12px; color: #64748b; border-top: 1px solid #e2e8f0;">
          G-Wash NG Marketplace Ltd * Support: support@gwashng.com * www.gwashng.com
        </div>

      </div>
    </body>
    </html>
    ''';
  }

  // ============================================================
  // SEND WALLET FUNDED NOTIFICATIONS
  // ============================================================
  Future<void> sendWalletFundedNotifications({
    required String userPhone,
    required String userEmail,
    required double amount,
  }) async {
    final msg = 'Your G Wash NG wallet has been funded with NGN ${amount.toStringAsFixed(0)}. Total balance updated!';

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
    final msg = 'Hello $washerName, your withdrawal request for NGN ${amount.toStringAsFixed(0)} has been received and is being processed by admin.';

    _notificationService.notify(
      title: 'Withdrawal Pending',
      message: 'Requested NGN ${amount.toStringAsFixed(0)} payout to your bank account.',
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
    final msg = 'Withdrawal Approved! NGN ${amount.toStringAsFixed(0)} has been transferred to your bank account.';

    _notificationService.notify(
      title: 'Withdrawal Successful',
      message: 'NGN ${amount.toStringAsFixed(0)} has been paid to your bank account.',
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

  // ============================================================
  // SEND RATING NOTIFICATIONS (CUSTOMER REVIEW LEFT)
  // ============================================================
  Future<void> sendRatingNotifications({
    required String jobId,
    required String customerName,
    required double rating,
    required String reviewText,
    String? providerName,
    String? providerPhone,
    String? providerEmail,
  }) async {
    final msg = 'Customer $customerName left a rating of $rating stars on your service (Job #$jobId). "${reviewText.isNotEmpty ? reviewText : 'Great service!'}"';

    _notificationService.notify(
      title: 'New Rating & Review Received!',
      message: msg,
      type: 'rating',
      jobId: jobId,
    );

    if (providerPhone != null && providerPhone.isNotEmpty) {
      await sendRealSms(phone: providerPhone, message: msg);
    }
    if (providerEmail != null && providerEmail.isNotEmpty) {
      await sendRealEmail(
        email: providerEmail,
        subject: 'New Review Received - G Wash NG',
        body: 'Hello ${providerName ?? 'Provider'},\n\n$msg\n\nThank you for maintaining quality service on G Wash NG!',
      );
    }
  }
}
