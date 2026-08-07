// lib/presentation/screens/customer/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/payment_service.dart';
import 'rating_screen.dart';
import 'tracking_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String jobId;
  final String serviceName;
  final int amount;
  final String location;
  final DateTime? date;
  final String? time;
  final String? washerName;
  final String? washerId;

  const PaymentScreen({
    super.key,
    required this.jobId,
    required this.serviceName,
    required this.amount,
    required this.location,
    this.date,
    this.time,
    this.washerName,
    this.washerId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _isPaymentSuccessful = false;
  String _selectedPaymentMethod = 'card';
  String _paymentStatus = 'pending';
  
  final List<Map<String, dynamic>> _paymentMethods = [
    {'id': 'card', 'name': 'Debit / Credit Card', 'icon': Icons.credit_card, 'color': Colors.indigo},
    {'id': 'bank_transfer', 'name': 'Bank Transfer', 'icon': Icons.account_balance, 'color': Colors.green},
    {'id': 'wallet', 'name': 'G Wash Wallet', 'icon': Icons.account_balance_wallet, 'color': Colors.purple},
    {'id': 'ussd', 'name': 'USSD', 'icon': Icons.phone_android, 'color': Colors.orange},
    {'id': 'qr', 'name': 'QR Code', 'icon': Icons.qr_code, 'color': Colors.teal},
  ];

  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
      _paymentStatus = 'processing';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.userId ?? '';
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'customer@gwashng.com';
      final userName = authService.userName ?? 'Customer';

      final paymentService = PaymentService();

      if (_selectedPaymentMethod == 'wallet') {
        final result = await paymentService.processWalletPayment(
          jobId: widget.jobId,
          userId: userId,
          userName: userName,
          serviceName: widget.serviceName,
          amount: widget.amount,
          location: widget.location,
        );

        if (result['success'] == true) {
          setState(() {
            _isProcessing = false;
            _isPaymentSuccessful = true;
            _paymentStatus = 'completed';
          });
          _showPaymentSuccessDialog();
        } else {
          setState(() {
            _isProcessing = false;
            _paymentStatus = 'failed';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Wallet Payment Failed: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 💳 REAL PAYSTACK GATEWAY (Card, Bank Transfer, USSD, QR Code)
      final initResult = await paymentService.initializePaystackTransaction(
        email: userEmail,
        amount: widget.amount,
        jobId: widget.jobId,
        userId: userId,
        serviceName: widget.serviceName,
      );

      if (initResult['success'] == true && initResult['authorization_url'] != null) {
        final authUrl = initResult['authorization_url'] as String;
        final reference = initResult['reference'] as String;

        setState(() {
          _isProcessing = false;
        });

        // Launch Real Paystack Gateway Checkout URL
        final Uri url = Uri.parse(authUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }

        // Show Paystack Verification Modal Dialog
        if (mounted) {
          _showPaystackVerificationDialog(
            reference: reference,
            authUrl: authUrl,
            userId: userId,
            userName: userName,
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _paymentStatus = 'failed';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Paystack Gateway Error: ${initResult['error'] ?? 'Could not initialize payment'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('❌ Payment failed: $e');
      setState(() {
        _isProcessing = false;
        _paymentStatus = 'failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showPaystackVerificationDialog({
    required String reference,
    required String authUrl,
    required String userId,
    required String userName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          bool isVerifying = false;
          String? verifyError;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.lock, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Paystack Checkout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Paystack secure checkout has launched for ₦${NumberFormat('#,###').format(widget.amount)}.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ref: $reference', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                      const SizedBox(height: 4),
                      const Text(
                        'Complete your card/transfer payment on Paystack, then tap "Verify Payment" below.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                if (verifyError != null) ...[
                  const SizedBox(height: 10),
                  Text(verifyError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              OutlinedButton(
                onPressed: () async {
                  final Uri url = Uri.parse(authUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('Re-open Checkout'),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        setModalState(() {
                          isVerifying = true;
                          verifyError = null;
                        });

                        final paymentService = PaymentService();
                        final result = await paymentService.verifyPaystackTransaction(
                          reference: reference,
                          jobId: widget.jobId,
                          userId: userId,
                          userName: userName,
                          serviceName: widget.serviceName,
                          amount: widget.amount,
                          location: widget.location,
                          paymentMethod: _selectedPaymentMethod,
                        );

                        if (result['success'] == true) {
                          Navigator.pop(context);
                          setState(() {
                            _isProcessing = false;
                            _isPaymentSuccessful = true;
                            _paymentStatus = 'completed';
                          });
                          _showPaymentSuccessDialog();
                        } else {
                          setModalState(() {
                            isVerifying = false;
                            verifyError = result['error'] ?? 'Payment verification failed.';
                          });
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isVerifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Verify Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _validateCardDetails() {
    final cardNumber = _cardNumberController.text.replaceAll(' ', '');
    if (cardNumber.length < 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 16-digit card number'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    final expiry = _expiryController.text;
    if (expiry.length < 5 || !expiry.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid expiry date (MM/YY)'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_cvvController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid CVV'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    if (_cardHolderController.text.isEmpty || _cardHolderController.text.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter card holder name'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return true;
  }

  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Payment Successful! 🎉',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 60,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '₦${NumberFormat('#,###').format(widget.amount)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paid for ${widget.serviceName}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reference: GWASH-${DateTime.now().millisecondsSinceEpoch}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToRating();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text('Rate Service'),
                ),
              ),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToTracking();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Track Order'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToRating() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          jobId: widget.jobId,
          washerId: widget.washerId ?? 'unknown',
        ),
      ),
      (route) => route.isFirst,
    );
  }

  void _navigateToTracking() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreen(
          jobId: widget.jobId,
          washerName: widget.washerName ?? 'Washer',
          pickupAddress: widget.location,
          pickupLocation: const LatLng(6.5244, 3.3792),
          serviceName: widget.serviceName,
          price: widget.amount,
          washerId: widget.washerId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Service', widget.serviceName),
                  _buildSummaryRow('Location', widget.location),
                  if (widget.date != null)
                    _buildSummaryRow('Date', DateFormat('MMM dd, yyyy').format(widget.date!)),
                  if (widget.time != null)
                    _buildSummaryRow('Time', widget.time!),
                  const Divider(height: 24),
                  _buildSummaryRow(
                    'Total Amount',
                    '₦${NumberFormat('#,###').format(widget.amount)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Methods
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedPaymentMethod = method['id']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          method['icon'],
                          color: isSelected ? AppColors.primary : Colors.grey.shade600,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          method['name'],
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : Colors.grey.shade700,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.primary,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Card Details
            if (_selectedPaymentMethod == 'card') ...[
              const Text(
                'Card Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                maxLength: 19,
                decoration: InputDecoration(
                  labelText: 'Card Number',
                  prefixIcon: const Icon(Icons.credit_card, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  counterText: '',
                  hintText: '1234 5678 9012 3456',
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _cardHolderController,
                decoration: InputDecoration(
                  labelText: 'Card Holder Name',
                  prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                  hintText: 'John Doe',
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        counterText: '',
                        hintText: 'MM/YY',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryDateFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        prefixIcon: const Icon(Icons.security, color: AppColors.primary),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary, width: 2),
                        ),
                        counterText: '',
                        hintText: '123',
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Pay Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Pay ₦${NumberFormat('#,###').format(widget.amount)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Security Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is secure and encrypted',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.black : Colors.grey.shade600,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isTotal ? AppColors.primary : Colors.black87,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}