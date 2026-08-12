// FILE: lib/presentation/screens/washer/incoming_job_dialog.dart
// PURPOSE: Real-time pop-up modal for service providers when a client chooses them

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/job_service.dart';
import 'washer_order_details_screen.dart';




class IncomingJobDialog extends StatefulWidget {
  final Map<String, dynamic> job;
  final String washerId;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;

  const IncomingJobDialog({
    super.key,
    required this.job,
    required this.washerId,
    this.onAccepted,
    this.onDeclined,
  });

  @override
  State<IncomingJobDialog> createState() => _IncomingJobDialogState();
}

class _IncomingJobDialogState extends State<IncomingJobDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _countdownTimer;
  int _secondsRemaining = 45;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    );
    _animController.reverse(from: 1.0);
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        _handleDecline(reason: 'Response timed out (45s)');
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleAccept() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();

    try {
      final jobId = widget.job['id'] ?? widget.job['jobId'];
      await JobService().acceptJobRequest(jobId, widget.washerId);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (widget.onAccepted != null) widget.onAccepted!();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Job Accepted! Customer notified.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        final lat = widget.job['latitude'] ?? 6.5244;
        final lng = widget.job['longitude'] ?? 3.3792;
        final location = widget.job['location'] ?? 'Customer Address';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => WasherOrderDetailsScreen(
              jobId: jobId,
              order: widget.job,
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting job: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDecline({String? reason}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _countdownTimer?.cancel();

    try {
      final jobId = widget.job['id'] ?? widget.job['jobId'];
      await JobService().declineJobRequest(jobId, widget.washerId, reason: reason);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (widget.onDeclined != null) widget.onDeclined!();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerName = widget.job['customerName'] ?? 'Customer';
    final serviceName = widget.job['serviceName'] ?? 'Service';
    final serviceCategory = widget.job['serviceCategory'] ?? 'General';
    final price = widget.job['price'] ?? 0;
    final location = widget.job['location'] ?? 'Nearby location';

    return WillPopScope(
      onWillPop: () async => false, // Prevent back button dismissal without response
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 16,
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ⚡ Header Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flash_on, color: AppColors.primary, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'NEW JOB REQUEST!',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ⏱ Animated Ring Timer
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return CircularProgressIndicator(
                          value: _animController.value,
                          strokeWidth: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _secondsRemaining < 10 ? Colors.red : AppColors.primary,
                          ),
                        );
                      },
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_secondsRemaining',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _secondsRemaining < 10 ? Colors.red : Colors.black87,
                        ),
                      ),
                      const Text(
                        'sec',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 💵 Earnings Highlight Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0CAF60), Color(0xFF058245)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0CAF60).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR EARNINGS',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₦${NumberFormat('#,###').format(price)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 📋 Job Info Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.person, 'Client', customerName),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.cleaning_services, 'Service', '$serviceName ($serviceCategory)'),
                    const Divider(height: 16),
                    _buildInfoRow(Icons.location_on, 'Location', location),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 🔘 Action Buttons
              if (_isProcessing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Row(
                  children: [
                    // Decline Button
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => _handleDecline(reason: 'Declined by provider'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Accept Button
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        onPressed: _handleAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0CAF60),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Accept Job',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
