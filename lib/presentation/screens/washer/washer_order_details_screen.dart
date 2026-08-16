// FILE: lib/presentation/screens/washer/washer_order_details_screen.dart
// PURPOSE: Detailed view of a specific order for washer with Firebase integration

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/app_notification_service.dart';
import '../../../services/communication_service.dart';



class WasherOrderDetailsScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic>? order;

  const WasherOrderDetailsScreen({
    super.key,
    required this.jobId,
    this.order,
  });

  @override
  State<WasherOrderDetailsScreen> createState() => _WasherOrderDetailsScreenState();
}

class _WasherOrderDetailsScreenState extends State<WasherOrderDetailsScreen> {
  Map<String, dynamic>? _orderData;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (widget.order != null) {
      _orderData = widget.order;
      _isLoading = false;
    } else {
      _loadOrderData();
    }
  }

  Future<void> _loadOrderData() async {
    setState(() => _isLoading = true);
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _orderData = doc.data()!;
          _orderData!['id'] = doc.id;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order not found'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading order: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading order: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isProcessing = true);

    try {
      // 🔒 SECURITY CHECK: Washer cannot complete job unless payment is confirmed!
      if (newStatus == 'completed') {
        final jobDoc = await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).get();
        final data = jobDoc.data() ?? {};
        final paymentStatus = (data['paymentStatus'] ?? '').toString().toLowerCase();
        final isPaid = data['isPaid'] == true;
        final statusStr = (data['status'] ?? '').toString().toLowerCase();

        final bool paymentIsConfirmed = isPaid || paymentStatus == 'paid' || statusStr == 'paid' || paymentStatus == 'completed' || paymentStatus == 'escrow';

        if (!paymentIsConfirmed) {
          setState(() => _isProcessing = false);
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Row(
                  children: [
                    Icon(Icons.lock_clock, color: Colors.orange, size: 28),
                    SizedBox(width: 8),
                    Text('Payment Pending 🔒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The customer has not completed payment for this service yet.',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please instruct the customer to tap "Complete Order & Pay" on their app so funds are secured in escrow before completing.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    child: const Text('OK, I will notify customer'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local data
      setState(() {
        _orderData!['status'] = newStatus;
        _isProcessing = false;
      });

      // Trigger local in-app top popup & offline notification
      String notifTitle = 'Order Updated';
      String notifMsg = 'Order is now ${_getStatusDisplay(newStatus)}';
      IconData notifIcon = Icons.info_outline;
      Color notifColor = AppColors.primary;

      switch (newStatus) {
        case 'accepted':
          notifTitle = '✅ Request Accepted';
          notifMsg = 'You have accepted this service request.';
          notifIcon = Icons.thumb_up_alt_outlined;
          notifColor = Colors.blue;
          break;
        case 'enRoute':
          notifTitle = '🚚 En Route';
          notifMsg = 'You are now heading to the customer location.';
          notifIcon = Icons.directions_car_outlined;
          notifColor = Colors.orange;
          break;
        case 'arrived':
          notifTitle = '📍 Arrived at Location';
          notifMsg = 'Customer has been notified that you arrived!';
          notifIcon = Icons.location_on_outlined;
          notifColor = Colors.blue;
          break;
        case 'in_progress':
          notifTitle = '🚿 Service Started';
          notifMsg = 'Service is now in progress.';
          notifIcon = Icons.cleaning_services;
          notifColor = Colors.purple;
          break;
        case 'completed':
          notifTitle = '🎉 Job Completed!';
          notifMsg = 'The job has been completed successfully and funds released!';
          notifIcon = Icons.check_circle_outline;
          notifColor = Colors.green;
          break;
        case 'cancelled':
          notifTitle = '🚨 Job Cancelled';
          notifMsg = 'The job has been cancelled.';
          notifIcon = Icons.cancel_outlined;
          notifColor = Colors.red;
          break;
      }


      AppNotificationService().notify(
        context: context,
        title: notifTitle,
        message: notifMsg,
        type: 'booking',
        icon: notifIcon,
        backgroundColor: notifColor,
      );

      final customerEmail = (_orderData?['customerEmail'] ?? '').toString();
      final customerPhone = (_orderData?['customerPhone'] ?? '').toString();
      final customerName = (_orderData?['customerName'] ?? 'Customer').toString();
      final providerName = (_orderData?['washerName'] ?? 'Service Provider').toString();
      final serviceName = (_orderData?['serviceName'] ?? 'Service').toString();

      await CommunicationService().sendStatusUpdateNotification(
        jobId: widget.jobId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        providerName: providerName,
        serviceName: serviceName,
        status: newStatus,
        message: '$notifTitle: $notifMsg',
      );


      // Navigate back after completion
      if (newStatus == 'completed') {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case 'accepted':
        return 'accepted';
      case 'enRoute':
        return 'en route';
      case 'completed':
        return 'completed successfully! 🎉';
      case 'cancelled':
        return 'cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'searching':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return Colors.blue;
      case 'enRoute':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusIcon(String status) {
    switch (status) {
      case 'searching':
        return '🔍';
      case 'assigned':
        return '📋';
      case 'accepted':
        return '✅';
      case 'enRoute':
        return '🚗';
      case 'completed':
        return '🎉';
      case 'cancelled':
        return '❌';
      default:
        return '📌';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_orderData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Order not found'),
        ),
      );
    }

    final order = _orderData!;
    final status = order['status'] ?? 'searching';
    final isActive = status != 'completed' && status != 'cancelled';
    final isCompleted = status == 'completed';
    final isCancelled = status == 'cancelled';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (isActive)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrderData,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _getStatusIcon(status),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${order['id']?.substring(0, 8) ?? 'N/A'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (order['createdAt'] != null)
                            Text(
                              'Placed: ${DateFormat('MMM dd, yyyy • hh:mm a').format((order['createdAt'] as Timestamp).toDate())}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Service Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Service Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Service', order['serviceName'] ?? 'N/A'),
                    _buildDetailRow('Category', order['serviceCategory'] ?? 'N/A'),
                    _buildDetailRow('Amount', '₦${NumberFormat('#,###').format(order['price'] ?? 0)}'),
                    _buildDetailRow('Location', order['location'] ?? 'N/A'),
                    if (order['date'] != null)
                      _buildDetailRow('Date', order['date']),
                    if (order['time'] != null)
                      _buildDetailRow('Time', order['time']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Name', order['customerName'] ?? 'Unknown'),
                    _buildDetailRow('Phone', order['customerPhone'] ?? 'N/A'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Status'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: (order['paymentStatus'] == 'paid')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            (order['paymentStatus'] ?? 'pending').toUpperCase(),
                            style: TextStyle(
                              color: (order['paymentStatus'] == 'paid')
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Amount'),
                        Text(
                          '₦${NumberFormat('#,###').format(order['price'] ?? 0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            if (!isCompleted && !isCancelled) ...[
              if (status == 'assigned' || status == 'accepted')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('cancelled'),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('arrived'),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.location_on),
                        label: Text(_isProcessing ? 'Processing...' : '📍 I Have Arrived'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

              if (status == 'arrived' || status == 'enRoute')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('cancelled'),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('in_progress'),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isProcessing ? 'Processing...' : '🚿 Start Service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),

              if (status == 'in_progress' || status == 'paid')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _updateOrderStatus('completed'),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isProcessing ? 'Processing...' : '✅ Complete Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),


              if (status == 'searching')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('cancelled'),
                        icon: const Icon(Icons.close),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          foregroundColor: AppColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () => _updateOrderStatus('accepted'),
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isProcessing ? 'Processing...' : 'Accept Job'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],

            if (isCompleted)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Text(
                      'This job has been completed',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            if (isCancelled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red),
                    SizedBox(width: 12),
                    Text(
                      'This job has been cancelled',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.grey600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}