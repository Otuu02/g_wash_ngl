import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';

/// 🔒 Mandatory Payment & Safety Notice Modal
/// Shown immediately after selecting a provider before navigating to TrackingScreen
class PaymentSafetyDialog extends StatefulWidget {
  final VoidCallback onContinue;
  final String? providerName;

  const PaymentSafetyDialog({
    super.key,
    required this.onContinue,
    this.providerName,
  });

  static Future<bool?> show(BuildContext context, {String? providerName}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PaymentSafetyDialog(
        providerName: providerName,
        onContinue: () {
          Navigator.of(context).pop(true);
        },
      ),
    );
  }

  @override
  State<PaymentSafetyDialog> createState() => _PaymentSafetyDialogState();
}

class _PaymentSafetyDialogState extends State<PaymentSafetyDialog> {
  bool _hasAgreed = false;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Mandatory popup, cannot dismiss without action
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        elevation: 16,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      '🔒',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'G Wash Payment & Safety Notice',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A192F),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Text(
                'For your safety, all G Wash payments must be made through the G Wash app.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),

              // Rule Points Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildRuleItem(
                      icon: Icons.money_off,
                      iconColor: Colors.red.shade600,
                      text: 'Do not pay the provider with cash.',
                    ),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildRuleItem(
                      icon: Icons.account_balance,
                      iconColor: Colors.red.shade600,
                      text: "Do not transfer money to the provider's personal account.",
                    ),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildRuleItem(
                      icon: Icons.verified_user,
                      iconColor: AppColors.primary,
                      text: 'Only use the official G Wash payment system.',
                    ),
                    const Divider(height: 16, color: Color(0xFFE2E8F0)),
                    _buildRuleItem(
                      icon: Icons.report_problem_outlined,
                      iconColor: Colors.orange.shade800,
                      text: 'If a provider asks for offline payment, report it to G Wash Support.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Agreement Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    _hasAgreed = !_hasAgreed;
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: _hasAgreed ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hasAgreed ? AppColors.primary : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _hasAgreed,
                        onChanged: (val) {
                          setState(() {
                            _hasAgreed = val ?? false;
                          });
                        },
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'I understand and agree',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _hasAgreed ? AppColors.primary : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Continue Button
              ElevatedButton(
                onPressed: _hasAgreed ? widget.onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: _hasAgreed ? 4 : 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue to Tracking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

/// 🚩 Report Offline Payment Request Modal Dialog
class ReportOfflinePaymentDialog extends StatefulWidget {
  final String jobId;
  final String? washerId;
  final String? washerName;
  final String? serviceName;

  const ReportOfflinePaymentDialog({
    super.key,
    required this.jobId,
    this.washerId,
    this.washerName,
    this.serviceName,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    String? washerId,
    String? washerName,
    String? serviceName,
  }) {
    return showDialog(
      context: context,
      builder: (context) => ReportOfflinePaymentDialog(
        jobId: jobId,
        washerId: washerId,
        washerName: washerName,
        serviceName: serviceName,
      ),
    );
  }

  @override
  State<ReportOfflinePaymentDialog> createState() => _ReportOfflinePaymentDialogState();
}

class _ReportOfflinePaymentDialogState extends State<ReportOfflinePaymentDialog> {
  final _notesController = TextEditingController();
  String _selectedReason = 'Provider asked for direct cash payment';
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Provider asked for direct cash payment',
    'Provider asked for bank transfer to personal account',
    'Provider said G Wash payment system was not working',
    'Provider offered a discount for paying offline',
    'Other offline payment request',
  ];

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      final customerId = user?.uid ?? authService.userId ?? 'anonymous';
      final customerName = authService.userName ?? 'Customer';
      final customerPhone = authService.userPhone ?? (user?.phoneNumber ?? '');

      // 1. Record report in Firestore
      await FirebaseFirestore.instance.collection('offline_payment_reports').add({
        'jobId': widget.jobId,
        'washerId': widget.washerId ?? '',
        'washerName': widget.washerName ?? 'Provider',
        'serviceName': widget.serviceName ?? 'Service',
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'reason': _selectedReason,
        'additionalNotes': _notesController.text.trim(),
        'status': 'pending_investigation',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Mark the job with report flag
      await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
        'offlinePaymentReported': true,
        'offlinePaymentReportedAt': FieldValue.serverTimestamp(),
      }).catchError((e) {});

      if (mounted) {
        Navigator.pop(context);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Column(
              children: [
                Icon(Icons.shield_rounded, color: AppColors.primary, size: 52),
                SizedBox(height: 12),
                Text(
                  'Report Submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: const Text(
              'Thank you for reporting. G Wash Compliance has flagged this booking and will take immediate action to protect your security.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.report_problem, color: Colors.red, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Report Offline Payment Request',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A192F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Help us maintain platform safety. If ${widget.washerName ?? "the provider"} asked for cash or direct bank transfer, report it here.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 18),
            const Text(
              'Incident Type *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedReason,
                  isExpanded: true,
                  items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedReason = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Additional Details (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Provider requested transfer to account: 0123456789 (Access Bank)...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
