// FILE: lib/core/utils/helpers.dart
// PURPOSE: Helper functions for the entire app

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class Helpers {
  Helpers._();

  // ==================== SNACKBAR ====================
  static void showSnackBar(
    BuildContext context, {
    required String message,
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    Color backgroundColor;
    if (isError) {
      backgroundColor = AppColors.error;
    } else if (isSuccess) {
      backgroundColor = AppColors.success;
    } else {
      backgroundColor = AppColors.primary;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ==================== LOADING INDICATOR ====================
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                message ?? 'Please wait...',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ==================== CONFIRMATION DIALOG ====================
  static void showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = true,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ==================== CONFIRMATION WITH TEXT INPUT ====================
  static void showConfirmationWithInputDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String expectedInput,
    required VoidCallback onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Type "$expectedInput" to confirm',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.pop(context);
            },
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim() == expectedInput) {
                controller.dispose();
                Navigator.pop(context);
                onConfirm();
              } else {
                showSnackBar(
                  context,
                  message: 'Input does not match. Operation cancelled.',
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // ==================== DATE FORMATTING ====================
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatDateLong(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  static String formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  // ==================== CURRENCY FORMATTING ====================
  static String formatCurrency(int amount) {
    return '₦${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  static String formatCurrencyDouble(double amount) {
    return '₦${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  static String formatCurrencyWithDecimal(double amount) {
    return '₦${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
  }

  // ==================== PHONE FORMATTING ====================
  static String formatPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.length == 10) {
      return '+234$cleaned';
    }
    return phone;
  }

  static String formatPhoneNumberDisplay(String phone) {
    if (phone.length == 13 && phone.startsWith('+234')) {
      final local = phone.substring(4);
      return '0${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    return phone;
  }

  // ==================== VALIDATION ====================
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 10 && cleaned.length <= 13;
  }

  static bool isValidCardNumber(String cardNumber) {
    final cleaned = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 15 && cleaned.length <= 16;
  }

  static bool isValidExpiry(String expiry) {
    if (expiry.length != 5) return false;
    if (!expiry.contains('/')) return false;
    final parts = expiry.split('/');
    if (parts.length != 2) return false;
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);
    if (month == null || year == null) return false;
    if (month < 1 || month > 12) return false;
    final currentYear = DateTime.now().year % 100;
    final currentMonth = DateTime.now().month;
    if (year < currentYear) return false;
    if (year == currentYear && month < currentMonth) return false;
    return true;
  }

  static bool isValidCVV(String cvv) {
    final cleaned = cvv.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= 3 && cleaned.length <= 4;
  }

  // ==================== SCREEN UTILITIES ====================
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  // ==================== DEBOUNCE ====================
  static final Map<String, Timer?> _debounceTimers = {};

  static void debounce(Duration duration, VoidCallback callback, {String? id}) {
    _debounceTimers[id ?? 'default']?.cancel();
    _debounceTimers[id ?? 'default'] = Timer(duration, callback);
  }

  // ==================== RATING ====================
  static void showRatingDialog(BuildContext context, {Function(double)? onRated}) {
    double rating = 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rate Your Experience'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate G Wash NG?'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() => rating = index + 1.0);
                    },
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 40,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                rating > 0 ? 'You rated: ${rating.toInt()} stars' : 'Tap a star to rate',
                style: TextStyle(color: AppColors.grey600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              if (rating > 0) {
                Navigator.pop(context);
                if (onRated != null) onRated(rating);
                showSnackBar(context, message: 'Thank you for your rating!', isSuccess: true);
              } else {
                showSnackBar(context, message: 'Please select a rating', isError: true);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // ==================== SHARE DIALOG ====================
  static void showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share G Wash NG'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.share, size: 50, color: AppColors.primary),
            SizedBox(height: 16),
            Text('Share this app with your friends and family!'),
            SizedBox(height: 8),
            Text(
              'Get ₦500 credit for each friend who books a wash',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Clipboard.setData(const ClipboardData(text: 'Use my code GWASH500 to sign up on G-Wash NG and get ₦500 off your first service! Download app now.'));
              showSnackBar(context, message: '✅ Referral link & code copied to clipboard!', isSuccess: true);
            },
            child: const Text('Share Now'),
          ),
        ],
      ),
    );
  }
}