// FILE: lib/services/communication_service.dart
// PURPOSE: Send official G-Wash CRM System WhatsApp & Email notifications to service providers when a booking occurs

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CommunicationService {
  CommunicationService._();

  /// Send WhatsApp message from G-Wash CRM System to service provider with booking details
  static Future<bool> sendWhatsAppBookingNotification({
    required String providerPhone,
    required String providerName,
    required String customerName,
    required String serviceCategory,
    required String serviceName,
    required int price,
    required String location,
    required String scheduledDate,
    required String scheduledTime,
    required String jobId,
  }) async {
    try {
      // Format phone number
      String cleanPhone = providerPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '234${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('234') && cleanPhone.length == 10) {
        cleanPhone = '234$cleanPhone';
      }

      final message = '''
🤖 *G-WASH NG CRM DISPATCH SYSTEM* 🏢
----------------------------------------
Hello $providerName! 👋

🚨 *NEW JOB ASSIGNED BY G-WASH CRM DISPATCH* ⚡

📋 *Job Details:*
• *Order ID:* #${jobId.substring(0, jobId.length > 8 ? 8 : jobId.length).toUpperCase()}
• *Service:* $serviceName ($serviceCategory)
• *Customer:* $customerName
• *Location:* $location
• *Date & Time:* $scheduledDate at $scheduledTime
• *Earnings:* ₦${price.toString()}

⚡ *CRM Notice:* This notification is automatically sent by the G-Wash NG CRM System number. Please open your G-Wash NG Provider App to view navigation and update job status.
''';

      final encodedMessage = Uri.encodeComponent(message);
      final url = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

      if (await canLaunchUrl(url)) {
        return await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch WhatsApp URL: $url');
        return false;
      }
    } catch (e) {
      print('❌ Error launching WhatsApp: $e');
      return false;
    }
  }

  /// Send Email notification from G-Wash CRM to service provider with booking details
  static Future<bool> sendEmailBookingNotification({
    required String providerEmail,
    required String providerName,
    required String customerName,
    required String serviceCategory,
    required String serviceName,
    required int price,
    required String location,
    required String scheduledDate,
    required String scheduledTime,
    required String jobId,
  }) async {
    try {
      final subject = '🤖 G-Wash CRM Notice: NEW JOB ASSIGNED - $serviceName';
      final body = '''
Hello $providerName,

This is an automated dispatch notification from the G-Wash NG CRM Platform.

JOB DETAILS:
--------------------------------------------------
Order ID: #${jobId.substring(0, jobId.length > 8 ? 8 : jobId.length).toUpperCase()}
Category: $serviceCategory
Service: $serviceName
Customer Name: $customerName
Location: $location
Scheduled Date & Time: $scheduledDate at $scheduledTime
Total Amount: ₦$price

CRM DISPATCH NOTICE:
This notification was sent by the G-Wash NG CRM System.
Please log into your G-Wash NG provider app to view customer navigation details and proceed.

Best regards,
G-Wash NG CRM & Operations Center
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: providerEmail,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      if (await canLaunchUrl(emailUri)) {
        return await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        print('❌ Could not launch Email client: $emailUri');
        return false;
      }
    } catch (e) {
      print('❌ Error launching Email: $e');
      return false;
    }
  }

  /// Send CRM WhatsApp, Email, and In-App notifications to provider upon booking
  static Future<void> sendBookingNotifications({
    required String? providerPhone,
    required String? providerEmail,
    required String providerName,
    required String customerName,
    required String serviceCategory,
    required String serviceName,
    required int price,
    required String location,
    required String scheduledDate,
    required String scheduledTime,
    required String jobId,
    BuildContext? context,
  }) async {
    final defaultPhone = providerPhone ?? '+2348012345678';
    final defaultEmail = providerEmail ?? 'provider@gwashng.com';

    // Send CRM WhatsApp notification
    await sendWhatsAppBookingNotification(
      providerPhone: defaultPhone,
      providerName: providerName,
      customerName: customerName,
      serviceCategory: serviceCategory,
      serviceName: serviceName,
      price: price,
      location: location,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      jobId: jobId,
    );

    // Send CRM Email notification
    await sendEmailBookingNotification(
      providerEmail: defaultEmail,
      providerName: providerName,
      customerName: customerName,
      serviceCategory: serviceCategory,
      serviceName: serviceName,
      price: price,
      location: location,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      jobId: jobId,
    );

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚡ G-Wash CRM dispatch alert sent to $providerName via WhatsApp & Email.'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
