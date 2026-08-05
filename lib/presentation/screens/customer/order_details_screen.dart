// FILE: order_details_screen.dart
// PURPOSE: Show detailed information about a specific order with clickable actions

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/helpers.dart';
import '../customer/tracking_screen.dart';
import '../customer/rating_screen.dart';
import '../customer/payment_screen.dart';
import '../washer/washer_profile_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final String? jobId;

  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.jobId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _updatedOrder;
  String? _washerId;
  String? _washerImage;
  String? _jobId;

  @override
  void initState() {
    super.initState();
    _jobId = widget.jobId ?? widget.order['id'] ?? widget.order['jobId'];
    _washerId = widget.order['washerId'];
    _washerImage = widget.order['washerImage'];
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    if (_jobId == null || _jobId!.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(_jobId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _updatedOrder = {
            'id': doc.id,
            ...data,
          };
          _washerId = data['washerId'] ?? _washerId;
          _washerImage = data['washerImage'] ?? _washerImage;
        });
      }
    } catch (e) {
      print('❌ Error loading order details: $e');
    }
  }

  // ============================================================
  // CLICKABLE ACTIONS
  // ============================================================

  Future<void> _callWasher(String? phoneNumber) async {
    final phone = phoneNumber ?? widget.order['washerPhone'] ?? '+2348012345678';
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = 'tel:$cleanPhone';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        Helpers.showSnackBar(
          context,
          message: 'Cannot make call at this time',
          isError: true,
        );
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        message: 'Error: $e',
        isError: true,
      );
    }
  }

  Future<void> _viewOnMap() async {
    final lat = widget.order['latitude'] ?? 6.5244;
    final lng = widget.order['longitude'] ?? 3.3792;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        Helpers.showSnackBar(
          context,
          message: 'Cannot open maps',
          isError: true,
        );
      }
    } catch (e) {
      Helpers.showSnackBar(
        context,
        message: 'Error: $e',
        isError: true,
      );
    }
  }

  Future<void> _viewWasherProfile() async {
    if (_washerId != null && _washerId!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WasherProfileScreen(
            washerId: _washerId!,
          ),
        ),
      );
    } else {
      Helpers.showSnackBar(
        context,
        message: 'Washer information not available',
        isError: true,
      );
    }
  }

  Future<void> _trackOrder() async {
    final orderData = _updatedOrder ?? widget.order;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreen(
          jobId: _jobId ?? orderData['id'],
          washerName: orderData['washerName'] ?? 'Washer',
          pickupAddress: orderData['location'] ?? 'Lekki, Lagos',
          pickupLocation: LatLng(
            orderData['latitude'] ?? 6.5244,
            orderData['longitude'] ?? 3.3792,
          ),
          serviceName: orderData['serviceName'] ?? orderData['title'] ?? 'Service',
          price: orderData['price'] ?? 0,
          washerId: _washerId,
          washerImage: _washerImage,
        ),
      ),
    );
  }

  Future<void> _rateOrder() async {
    if (_jobId != null && _washerId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingScreen(
            jobId: _jobId!,
            washerId: _washerId!,
          ),
        ),
      );
    } else {
      Helpers.showSnackBar(
        context,
        message: 'Cannot rate this order at this time',
        isError: true,
      );
    }
  }

  Future<void> _payOrder() async {
    final orderData = _updatedOrder ?? widget.order;
    
    if (_jobId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            jobId: _jobId!,
            amount: orderData['price'] ?? 0,
            serviceName: orderData['serviceName'] ?? orderData['title'] ?? 'Service',
            washerName: orderData['washerName'] ?? 'Washer',
            location: orderData['location'] ?? 'Lekki, Lagos',
            washerId: _washerId,
          ),
        ),
      );
    } else {
      Helpers.showSnackBar(
        context,
        message: 'Payment not available for this order',
        isError: true,
      );
    }
  }

  Future<void> _cancelOrder() async {
    if (_jobId == null) {
      Helpers.showSnackBar(
        context,
        message: 'Cannot cancel this order',
        isError: true,
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              
              try {
                await FirebaseFirestore.instance
                    .collection('jobs')
                    .doc(_jobId)
                    .update({
                  'status': 'cancelled',
                  'cancelledAt': FieldValue.serverTimestamp(),
                  'cancelledBy': 'customer',
                });
                
                if (mounted) {
                  Helpers.showSnackBar(
                    context,
                    message: 'Order cancelled successfully',
                    isSuccess: true,
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                setState(() => _isLoading = false);
                Helpers.showSnackBar(
                  context,
                  message: 'Error cancelling order: $e',
                  isError: true,
                );
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _shareOrder() {
    final orderData = _updatedOrder ?? widget.order;
    final shareText = '''
📍 Order #${orderData['id']}
Service: ${orderData['serviceName'] ?? orderData['title']}
Status: ${orderData['status']}
Amount: ₦${NumberFormat('#,###').format(orderData['price'] ?? 0)}
Date: ${orderData['date'] ?? orderData['createdAt']}

Thank you for using G Wash NG! 🚗
    ''';
    
    Clipboard.setData(ClipboardData(text: shareText));
    Helpers.showSnackBar(
      context,
      message: 'Order details copied to clipboard',
      isSuccess: true,
    );
  }

  // ============================================================
  // BUILD METHODS
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final orderData = _updatedOrder ?? widget.order;
    final status = orderData['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed' || status == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Order Details',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareOrder,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(orderData),
                  const SizedBox(height: 16),

                  // Action Buttons
                  _buildActionButtons(orderData),
                  const SizedBox(height: 16),

                  // Service Details
                  _buildServiceDetails(orderData),
                  const SizedBox(height: 16),

                  // Location Details
                  _buildLocationDetails(orderData),
                  const SizedBox(height: 16),

                  // Washer Details
                  _buildWasherDetails(orderData),
                  const SizedBox(height: 16),

                  // Rating Section (if completed)
                  if (isCompleted) _buildRatingSection(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // STATUS CARD
  // ============================================================
  Widget _buildStatusCard(Map<String, dynamic> orderData) {
    final status = orderData['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed' || status == 'paid';
    final isCancelled = status == 'cancelled';
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isCompleted) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completed';
    } else if (isCancelled) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'Cancelled';
    } else if (status == 'enroute' || status == 'arrived' || status == 'accepted') {
      statusColor = Colors.orange;
      statusIcon = Icons.directions_car;
      statusText = 'In Progress';
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.pending;
      statusText = 'Pending';
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                statusIcon,
                color: statusColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${orderData['id']?.toString().substring(0, 8) ?? 'N/A'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (orderData['date'] != null)
                    Text(
                      'Date: ${orderData['date']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (orderData['price'] != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₦${NumberFormat('#,###').format(orderData['price'])}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ACTION BUTTONS
  // ============================================================
  Widget _buildActionButtons(Map<String, dynamic> orderData) {
    final status = orderData['status']?.toString().toLowerCase() ?? 'pending';
    final isCompleted = status == 'completed' || status == 'paid';
    final isCancelled = status == 'cancelled';
    final isPending = status == 'pending' || status == 'searching' || status == 'assigned' || status == 'accepted';

    List<Widget> buttons = [];

    // Track Button
    if (!isCancelled) {
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.location_on,
            label: 'Track',
            color: AppColors.primary,
            onPressed: _trackOrder,
          ),
        ),
      );
    }

    // Call Washer Button
    if (!isCancelled && !isCompleted) {
      buttons.add(
        const SizedBox(width: 8),
      );
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone,
            label: 'Call Washer',
            color: Colors.green,
            onPressed: () => _callWasher(orderData['washerPhone']),
          ),
        ),
      );
    }

    // Pay Button (if not cancelled)
    if (!isCancelled) {
      if (buttons.isNotEmpty) {
        buttons.add(const SizedBox(width: 8));
      }
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.payment,
            label: isCompleted ? 'Pay Now' : 'Pay',
            color: Colors.blue,
            onPressed: _payOrder,
          ),
        ),
      );
    }

    // Cancel Button (if pending)
    if (isPending) {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.cancel,
            label: 'Cancel',
            color: Colors.red,
            onPressed: _cancelOrder,
          ),
        ),
      );
    }

    // Rate Button (if completed)
    if (isCompleted) {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: _buildActionButton(
            icon: Icons.star,
            label: 'Rate',
            color: Colors.amber,
            onPressed: _rateOrder,
          ),
        ),
      );
    }

    return Row(
      children: buttons,
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(0, 44),
      ),
    );
  }

  // ============================================================
  // SERVICE DETAILS
  // ============================================================
  Widget _buildServiceDetails(Map<String, dynamic> orderData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Service', orderData['serviceName'] ?? orderData['title'] ?? 'N/A', isClickable: false),
            _buildDetailRow('Category', orderData['serviceCategory'] ?? 'General', isClickable: false),
            _buildDetailRow('Amount', '₦${NumberFormat('#,###').format(orderData['price'] ?? 0)}', isClickable: false),
            _buildDetailRow('Date', orderData['date'] ?? orderData['createdAt']?.toString() ?? 'N/A', isClickable: false),
            _buildDetailRow('Time', orderData['time'] ?? '10:30 AM', isClickable: false),
            _buildDetailRow('Duration', orderData['duration'] ?? '30 mins', isClickable: false),
            _buildDetailRow('Payment Status', orderData['paymentStatus'] ?? 'Pending', isClickable: false),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION DETAILS
  // ============================================================
  Widget _buildLocationDetails(Map<String, dynamic> orderData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Location Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _viewOnMap,
                  icon: const Icon(Icons.map, size: 16),
                  label: const Text('View on Map'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Address',
              orderData['location'] ?? 'Lekki, Lagos',
              isClickable: true,
              onTap: _viewOnMap,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WASHER DETAILS
  // ============================================================
  Widget _buildWasherDetails(Map<String, dynamic> orderData) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Washer Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_washerId != null)
                  TextButton.icon(
                    onPressed: _viewWasherProfile,
                    icon: const Icon(Icons.person, size: 16),
                    label: const Text('View Profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              'Name',
              orderData['washerName'] ?? 'Not assigned',
              isClickable: _washerId != null,
              onTap: _viewWasherProfile,
            ),
            _buildDetailRow(
              'Phone',
              orderData['washerPhone'] ?? '+234 801 234 5678',
              isClickable: true,
              onTap: () => _callWasher(orderData['washerPhone']),
              icon: Icons.phone,
            ),
            if (orderData['washerRating'] != null)
              _buildDetailRow(
                'Rating',
                '⭐ ${orderData['washerRating']?.toStringAsFixed(1) ?? '4.8'}',
                isClickable: false,
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // RATING SECTION
  // ============================================================
  Widget _buildRatingSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rate Your Experience',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap a star to rate this service',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  onPressed: _rateOrder,
                  icon: Icon(
                    index < 4 ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 40,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                );
              }),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _rateOrder,
                child: const Text('Write a Review'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DETAIL ROW WIDGET
  // ============================================================
  Widget _buildDetailRow(
    String label,
    String value, {
    bool isClickable = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isClickable ? onTap : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.grey600,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontWeight: isClickable ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 14,
                        color: isClickable ? AppColors.primary : Colors.black87,
                        decoration: isClickable ? TextDecoration.underline : null,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      icon,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}