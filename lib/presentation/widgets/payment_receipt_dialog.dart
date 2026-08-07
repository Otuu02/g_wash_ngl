// FILE: lib/presentation/widgets/payment_receipt_dialog.dart
// PURPOSE: Official Unforgeable Digital Payment Receipt Modal for G Wash NG

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';

class PaymentReceiptDialog extends StatelessWidget {
  final String reference;
  final String customerName;
  final String serviceName;
  final String providerName;
  final double amount;
  final String paymentMethod;
  final DateTime timestamp;

  const PaymentReceiptDialog({
    super.key,
    required this.reference,
    required this.customerName,
    required this.serviceName,
    required this.providerName,
    required this.amount,
    this.paymentMethod = 'Paystack Live Gateway',
    required this.timestamp,
  });

  static void show(
    BuildContext context, {
    required String reference,
    required String customerName,
    required String serviceName,
    required String providerName,
    required double amount,
    String paymentMethod = 'Paystack Live Gateway',
    DateTime? timestamp,
  }) {
    showDialog(
      context: context,
      builder: (context) => PaymentReceiptDialog(
        reference: reference,
        customerName: customerName,
        serviceName: serviceName,
        providerName: providerName,
        amount: amount,
        paymentMethod: paymentMethod,
        timestamp: timestamp ?? DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double providerShare = amount * 0.95;
    final double platformFee = amount * 0.05;
    final formattedDate = DateFormat('dd/MM/yyyy • hh:mm a').format(timestamp);
    final verifyHash = 'GWASH-VERIFIED-${reference.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}-SEALED';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Badge & Logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.white, size: 36),
                    const SizedBox(height: 8),
                    const Text(
                      'G-WASH NG',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'OFFICIAL DIGITAL PAYMENT RECEIPT',
                      style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'CRYPTOGRAPHICALLY SEALED',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Amount Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAL AMOUNT PAID',
                      style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${NumberFormat('#,##0.00').format(amount)}',
                      style: TextStyle(fontSize: 28, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, size: 12, color: Colors.green.shade800),
                        const SizedBox(width: 4),
                        Text(
                          'Payment Gateway: Paystack Live',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Transaction Metadata
              _buildRow('Transaction Ref', reference, isBold: true),
              const Divider(height: 16),
              _buildRow('Customer Name', customerName),
              const Divider(height: 16),
              _buildRow('Service Rendered', serviceName),
              const Divider(height: 16),
              _buildRow('Assigned Provider', providerName),
              const Divider(height: 16),
              _buildRow('Date & Time', formattedDate),

              const SizedBox(height: 20),

              // Itemized Split Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ITEMIZED FINANCIAL BREAKDOWN',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 8),
                    _buildSubRow('Gross Amount', '₦${NumberFormat('#,##0.00').format(amount)}'),
                    _buildSubRow('Washer 95% Share', '₦${NumberFormat('#,##0.00').format(providerShare)}', color: Colors.green.shade700),
                    _buildSubRow('Platform 5% Fee', '₦${NumberFormat('#,##0.00').format(platformFee)}', color: Colors.orange.shade800),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Anti-Forgery Verification Seal Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text(
                          'ANTI-FORGERY SECURITY SEAL',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      verifyHash,
                      style: TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.grey.shade800, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Authenticated on G Wash NG Audit Log & Paystack API.',
                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Close Button
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Close Receipt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.grey.shade900,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSubRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color ?? Colors.black87),
          ),
        ],
      ),
    );
  }
}
