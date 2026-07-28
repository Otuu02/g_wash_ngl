import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/location_service.dart';
import '../../../services/app_notification_service.dart';
import '../customer/rating_screen.dart';
import 'payment_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String jobId;
  final String washerName;
  final String pickupAddress;
  final LatLng pickupLocation;
  final String serviceName;
  final int price;
  final String? washerId;
  final String? washerImage;

  const TrackingScreen({
    super.key,
    required this.jobId,
    required this.washerName,
    required this.pickupAddress,
    required this.pickupLocation,
    this.serviceName = 'Car Wash',
    this.price = 0,
    this.washerId,
    this.washerImage,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isLoading = true;
  bool _isServiceCompleted = false;
  bool _isPaid = false;
  int _currentStep = 1;
  String _jobStatus = 'assigned';
  String? _washerId;
  String? _washerImageUrl;
  String? _lastStatus;
  String _currentLocation = 'En route to your location';
  int _etaMinutes = 15;
  double _distanceKm = 1.5;
  bool _isProcessing = false;

  GoogleMapController? _mapController;
  late LatLng _clientLocation;
  late LatLng _providerLocation;
  StreamSubscription? _jobSubscription;
  StreamSubscription? _washerSubscription;

  @override
  void initState() {
    super.initState();
    _clientLocation = widget.pickupLocation;
    _providerLocation = LatLng(
      widget.pickupLocation.latitude + 0.008,
      widget.pickupLocation.longitude + 0.008,
    );
    _washerId = widget.washerId;
    _washerImageUrl = widget.washerImage;
    _listenToJobUpdates();
    _fetchWasherDetails();
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _washerSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _fetchWasherDetails() async {
    if (_washerId != null && _washerId!.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('washers')
            .doc(_washerId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null && data['profileImage'] != null) {
            setState(() {
              _washerImageUrl = data['profileImage'];
            });
          }
        }
      } catch (e) {
        print('❌ Error fetching washer details: $e');
      }
    }
  }

  void _listenToJobUpdates() {
    _jobSubscription = FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final status = data['status'] ?? 'assigned';
        final paymentStatus = data['paymentStatus'] ?? 'pending';
        
        _washerId = data['washerId'] ?? data['assignedWasherId'] ?? widget.washerId;
        
        if (_washerId != null && _washerId!.isNotEmpty && _washerSubscription == null) {
          _listenToWasherLocation(_washerId!);
          _fetchWasherDetails();
        }

        // Trigger local notification/popup on status changes
        if (_lastStatus != null && _lastStatus != status) {
          _showStatusNotification(status);
        }
        _lastStatus = status;
        
        setState(() {
          _jobStatus = status;
          _isLoading = false;
          _isPaid = paymentStatus == 'paid';
          
          switch (status) {
            case 'assigned':
              _currentStep = 1;
              _currentLocation = 'Washer assigned & on the way';
              break;
            case 'accepted':
              _currentStep = 1;
              _currentLocation = 'Washer accepted your request';
              break;
            case 'enRoute':
              _currentStep = 1;
              _currentLocation = 'Washer is en route to your location';
              break;
            case 'arrived':
              _currentStep = 2;
              _currentLocation = 'Washer has arrived at your location';
              _etaMinutes = 0;
              break;
            case 'completed':
              _currentStep = 3;
              _currentLocation = 'Service completed! Please confirm and pay.';
              _isServiceCompleted = true;
              break;
            case 'paid':
              _currentStep = 4;
              _currentLocation = 'Payment successful! Thank you.';
              _isServiceCompleted = true;
              _isPaid = true;
              break;
            case 'cancelled':
              _currentLocation = 'This job has been cancelled';
              break;
          }
        });
      }
    });
  }

  void _showStatusNotification(String status) {
    String notifTitle = 'Order Updated';
    String notifMsg = 'Your booking status is now: $status.';
    IconData notifIcon = Icons.info_outline;
    Color notifColor = AppColors.primary;

    switch (status) {
      case 'accepted':
        notifTitle = '✅ Request Accepted';
        notifMsg = 'Your service request has been accepted by the provider.';
        notifIcon = Icons.thumb_up_alt_outlined;
        notifColor = Colors.blue;
        break;
      case 'enRoute':
        notifTitle = '🚚 Provider En Route';
        notifMsg = 'The service provider is now heading to your location.';
        notifIcon = Icons.directions_car_outlined;
        notifColor = Colors.orange;
        break;
      case 'arrived':
        notifTitle = '📍 Provider Arrived';
        notifMsg = 'The service provider has arrived at your location!';
        notifIcon = Icons.location_on_outlined;
        notifColor = Colors.green;
        break;
      case 'completed':
        notifTitle = '🎉 Service Completed!';
        notifMsg = 'Your service has been completed. Please confirm and pay.';
        notifIcon = Icons.check_circle_outline;
        notifColor = Colors.green;
        break;
      case 'cancelled':
        notifTitle = '🚨 Service Cancelled';
        notifMsg = 'Your booking has been cancelled.';
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
  }

  void _listenToWasherLocation(String washerId) {
    _washerSubscription = LocationService().getWasherLocationStream(washerId).listen((doc) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final lat = (data['currentLat'] ?? data['latitude'] ?? (_clientLocation.latitude + 0.005)) as double;
        final lng = (data['currentLng'] ?? data['longitude'] ?? (_clientLocation.longitude + 0.005)) as double;
        final newProviderLoc = LatLng(lat, lng);
        
        final dist = _calculateDistance(_clientLocation.latitude, _clientLocation.longitude, lat, lng);
        final eta = (dist * 4).round().clamp(1, 45);

        setState(() {
          _providerLocation = newProviderLoc;
          _distanceKm = dist;
          if (_currentStep < 2) {
            _etaMinutes = eta;
          }
        });
      }
    });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) *
            (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // ============================================================
  // FIX: Customer confirms completion
  // ============================================================
  Future<void> _customerConfirmCompletion() async {
    setState(() => _isProcessing = true);

    try {
      // Update job status to completed (customer confirms)
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'completedBy': 'customer',
      });

      setState(() {
        _isServiceCompleted = true;
        _currentStep = 3;
        _isProcessing = false;
      });

      // Show payment dialog
      _showPaymentDialog();
      
    } catch (e) {
      print('❌ Error confirming completion: $e');
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================================
  // FIX: Payment dialog
  // ============================================================
  void _showPaymentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Complete Payment',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Service completed successfully!'),
            const SizedBox(height: 8),
            Text(
              'Service: ${widget.serviceName}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    '₦${NumberFormat('#,###').format(widget.price)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to bookings if they skip payment
              _goToBookings();
            },
            child: const Text('Skip', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: _processPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FIX: Process payment
  // ============================================================
  Future<void> _processPayment() async {
    Navigator.pop(context); // Close payment dialog
    
    try {
      setState(() => _isProcessing = true);

      // Navigate to Payment Screen for full payment processing
      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentScreen(
              jobId: widget.jobId,
              amount: widget.price,
              serviceName: widget.serviceName,
              washerName: widget.washerName,
              location: widget.pickupAddress,
              washerId: _washerId,
            ),
          ),
        );

        setState(() => _isProcessing = false);

        if (result == true) {
          // Payment successful
          setState(() {
            _isPaid = true;
            _currentStep = 4;
          });
          
          // Update job status to paid
          await FirebaseFirestore.instance
              .collection('jobs')
              .doc(widget.jobId)
              .update({
            'paymentStatus': 'paid',
            'paidAt': FieldValue.serverTimestamp(),
            'status': 'paid',
          });

          _showSuccessDialog();
        }
      }
    } catch (e) {
      print('❌ Payment error: $e');
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ============================================================
  // FIX: Success dialog - Navigate to rating
  // ============================================================
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Payment Successful! 🎉',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppColors.primary, size: 60),
            SizedBox(height: 16),
            Text('Your service has been completed successfully.'),
            Text(
              'Thank you for using G Wash NG!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Navigate to rating screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => RatingScreen(
                    jobId: widget.jobId,
                    washerId: _washerId ?? 'unknown',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Rate Service'),
          ),
        ],
      ),
    );
  }

  void _goToBookings() {
    Navigator.pushNamedAndRemoveUntil(context, '/my-bookings', (route) => false);
  }

  Future<void> _cancelOrder() async {
    setState(() => _isProcessing = true);

    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'customer',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order cancelled successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error cancelling order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling order: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _callWasher() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling washer... (Feature coming soon)'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isCancelled = _jobStatus == 'cancelled';
    final isCompleted = _jobStatus == 'completed' || _jobStatus == 'paid';
    final isPaid = _jobStatus == 'paid';

    if (isCancelled) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Track Your Wash',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Order Cancelled',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This order has been cancelled',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Track Your Wash',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isPaid)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Paid',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ),
            ),
          if (isCompleted && !isPaid)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.payment, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Pending Payment',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map View
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _clientLocation,
                    zoom: 14.5,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('client'),
                      position: _clientLocation,
                      infoWindow: InfoWindow(title: 'Your Location', snippet: widget.pickupAddress),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                    if (!isPaid)
                      Marker(
                        markerId: const MarkerId('provider'),
                        position: _providerLocation,
                        infoWindow: InfoWindow(title: 'Washer: ${widget.washerName}', snippet: '${_distanceKm.toStringAsFixed(1)} km away'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      ),
                  },
                  polylines: !isPaid
                      ? {
                          Polyline(
                            polylineId: const PolylineId('route'),
                            points: [_providerLocation, _clientLocation],
                            color: AppColors.primary,
                            width: 4,
                          ),
                        }
                      : {},
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                if (!isPaid)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_distanceKm.toStringAsFixed(1)} km away',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'ETA: $_etaMinutes mins',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Status Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : 
                  isCompleted ? Icons.payment : 
                  Icons.directions_car,
                  size: 24,
                  color: isPaid ? Colors.green : 
                         isCompleted ? Colors.orange : 
                         AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid ? 'Payment Successful!' :
                        isCompleted ? 'Service Completed!' :
                        'Washer On The Way',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPaid ? 'Thank you for using G Wash NG' :
                        isCompleted ? 'Please confirm and pay' :
                        _currentLocation,
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
          
          const SizedBox(height: 16),
          
          // Washer Info Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _washerImageUrl != null && _washerImageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _washerImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: AppColors.primary.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.primary.withOpacity(0.1),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.washerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                '4.8',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Professional Washer',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _callWasher,
                      icon: const Icon(
                        Icons.phone,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ETA & Service Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                if (!isPaid && !isCompleted)
                  Expanded(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              'ETA',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _etaMinutes.toString(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'mins',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (!isPaid && !isCompleted) const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Service',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.serviceName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Price',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPaid ? '✅ Paid' : 
                            widget.price > 0 
                                ? '₦${NumberFormat('#,###').format(widget.price)}'
                                : '₦0',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isPaid ? Colors.green : 
                                     widget.price > 0 ? AppColors.primary : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // ============================================================
          // FIX: ACTION BUTTONS - Customer driven
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // ============================================================
                // CASE 1: Service Completed but NOT Paid → "Confirm & Pay"
                // ============================================================
                if (isCompleted && !isPaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _customerConfirmCompletion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                          : const Text(
                              '✅ Confirm & Pay',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                
                // ============================================================
                // CASE 2: Paid → "Rate Service"
                // ============================================================
                if (isPaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RatingScreen(
                              jobId: widget.jobId,
                              washerId: _washerId ?? 'unknown',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '⭐ Rate Service',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                
                // ============================================================
                // CASE 3: Active job (not completed) → "Cancel Booking"
                // ============================================================
                if (!isCompleted && !isPaid && !isCancelled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel Booking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}