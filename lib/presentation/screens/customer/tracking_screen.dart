import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/location_service.dart';
import '../../../services/app_notification_service.dart';
import '../../../services/job_service.dart';
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
  int _currentStep = 0;
  String _jobStatus = 'searching';
  String? _washerId;
  String? _washerImageUrl;
  String? _lastStatus;
  String _currentLocation = 'Searching for nearby service providers...';
  int _etaMinutes = 0;
  double _distanceKm = 0.0;
  bool _isProcessing = false;

  GoogleMapController? _mapController;
  late LatLng _clientLocation;
  late LatLng _providerLocation;
  StreamSubscription? _jobSubscription;
  StreamSubscription? _washerSubscription;
  Timer? _movementTimer;

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
    // Do NOT start movement simulation on unassigned jobs!
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _washerSubscription?.cancel();
    _movementTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startMovementSimulation() {
    _movementTimer?.cancel();

    // Only simulate or track movement if provider is actually assigned & active
    final bool isAccepted = _washerId != null && _washerId!.isNotEmpty &&
        (_jobStatus == 'assigned' || _jobStatus == 'accepted' || _jobStatus == 'enRoute');

    if (!isAccepted) return;

    _movementTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      if (_jobStatus == 'assigned' || _jobStatus == 'accepted' || _jobStatus == 'enRoute') {
        final dLat = _clientLocation.latitude - _providerLocation.latitude;
        final dLng = _clientLocation.longitude - _providerLocation.longitude;

        if (dLat.abs() < 0.0002 && dLng.abs() < 0.0002) {
          setState(() {
            _providerLocation = _clientLocation;
            _currentLocation = 'Washer is arriving at your location';
            _etaMinutes = 1;
            _distanceKm = 0.05;
          });
        } else {
          final newLat = _providerLocation.latitude + dLat * 0.08;
          final newLng = _providerLocation.longitude + dLng * 0.08;
          final newLoc = LatLng(newLat, newLng);

          final dist = _calculateDistance(_clientLocation.latitude, _clientLocation.longitude, newLat, newLng);
          final eta = (dist * 4).round().clamp(1, 45);

          setState(() {
            _providerLocation = newLoc;
            _distanceKm = dist;
            _etaMinutes = eta;
          });

          _mapController?.animateCamera(CameraUpdate.newLatLng(newLoc));
        }
      }
    });
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
        final status = data['status'] ?? 'searching';
        final paymentStatus = data['paymentStatus'] ?? 'pending';
        
        _washerId = data['washerId'] ?? data['assignedWasherId'] ?? widget.washerId;
        
        final bool isAssigned = _washerId != null && _washerId!.isNotEmpty &&
            (status == 'assigned' || status == 'accepted' || status == 'enRoute' || status == 'arrived' || status == 'completed' || status == 'paid');

        if (isAssigned && _washerSubscription == null) {
          _listenToWasherLocation(_washerId!);
          _fetchWasherDetails();
        }

        if (_lastStatus != null && _lastStatus != status) {
          _showStatusNotification(status);
        }
        _lastStatus = status;
        
        setState(() {
          _jobStatus = status;
          _isLoading = false;
          
          switch (status) {
            case 'pending':
            case 'searching':
            case 'unassigned':
              _currentStep = 0;
              _currentLocation = 'Searching for nearby service providers...';
              _etaMinutes = 0;
              _distanceKm = 0.0;
              _movementTimer?.cancel();
              break;
            case 'assigned':
            case 'accepted':
              _currentStep = 1;
              _currentLocation = 'Provider accepted request! En route to pickup';
              if (_distanceKm == 0.0) _distanceKm = 1.5;
              if (_etaMinutes == 0) _etaMinutes = 15;
              _startMovementSimulation();
              break;
            case 'enRoute':
              _currentStep = 1;
              _currentLocation = 'Your washer is on the way';
              if (_distanceKm == 0.0) _distanceKm = 1.5;
              if (_etaMinutes == 0) _etaMinutes = 15;
              _startMovementSimulation();
              break;
            case 'arrived':
              _currentStep = 2;
              _currentLocation = 'Washer has arrived at your location';
              _etaMinutes = 0;
              _movementTimer?.cancel();
              break;
            case 'completed':
              _currentStep = 3;
              _currentLocation = 'Service completed! Please confirm and pay.';
              _movementTimer?.cancel();
              break;
            case 'paid':
              _currentStep = 4;
              _currentLocation = 'Payment successful! Thank you.';
              _movementTimer?.cancel();
              break;
            case 'cancelled':
              _currentLocation = 'This job has been cancelled';
              _movementTimer?.cancel();
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

  Future<void> _customerConfirmCompletion() async {
    setState(() => _isProcessing = true);

    try {
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

  Future<void> _processPayment() async {
    Navigator.pop(context);

    try {
      setState(() => _isProcessing = true);

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
          setState(() {
            _isPaid = true;
            _currentStep = 4;
          });
          
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
              Navigator.pop(context);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isProcessing = true);
              try {
                await JobService().cancelJob(
                  jobId: widget.jobId,
                  reason: 'Cancelled by customer',
                  cancelledBy: 'Customer',
                );

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
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _callWasher() async {
    final Uri url = Uri.parse('tel:08000000000');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
          // ============================================================
          // MAP VIEW - Prominent Live Map with Real-Time Marker Animation
          // ============================================================
          Container(
            height: 260,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
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
                      if (!isPaid && _washerId != null && _washerId!.isNotEmpty && (_jobStatus == 'assigned' || _jobStatus == 'accepted' || _jobStatus == 'enRoute' || _jobStatus == 'arrived'))
                        Marker(
                          markerId: const MarkerId('provider'),
                          position: _providerLocation,
                          infoWindow: InfoWindow(title: 'Washer: ${widget.washerName}', snippet: '${_distanceKm > 0 ? _distanceKm.toStringAsFixed(1) : '1.5'} km away'),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                        ),
                    },
                    polylines: (!isPaid && _washerId != null && _washerId!.isNotEmpty && (_jobStatus == 'assigned' || _jobStatus == 'accepted' || _jobStatus == 'enRoute'))
                        ? {
                            Polyline(
                              polylineId: const PolylineId('route'),
                              points: [_providerLocation, _clientLocation],
                              color: AppColors.primary,
                              width: 5,
                            ),
                          }
                        : {},
                    onMapCreated: (controller) => _mapController = controller,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                    padding: const EdgeInsets.all(8),
                  ),

                  // Live Animated Indicator Overlay Banner
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: (_washerId != null && _washerId!.isNotEmpty) ? Colors.green : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_washerId == null || _washerId!.isEmpty || _jobStatus == 'searching' || _jobStatus == 'pending')
                                  ? 'Searching for nearby service providers...'
                                  : _jobStatus == 'arrived'
                                      ? 'Provider has arrived at your location'
                                      : isCompleted
                                          ? 'Service Completed'
                                          : 'En Route • ${_distanceKm.toStringAsFixed(1)} km away • ETA: ${_etaMinutes > 0 ? _etaMinutes : 15} mins',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_jobStatus == 'searching' || _jobStatus == 'pending' || _jobStatus == 'assigned' || _jobStatus == 'accepted' || _jobStatus == 'enRoute')
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ============================================================
          // STATUS CARD - Dynamic for searching vs assigned
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_washerId != null && _washerId!.isNotEmpty) 
                    ? Colors.green.withOpacity(0.1) 
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_washerId != null && _washerId!.isNotEmpty) 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.orange.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_washerId != null && _washerId!.isNotEmpty) ? Colors.green : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (_washerId != null && _washerId!.isNotEmpty) ? Icons.directions_car : Icons.search,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (_washerId != null && _washerId!.isNotEmpty) ? 'Washer On The Way' : 'Searching For Provider',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentLocation,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (_washerId != null && _washerId!.isNotEmpty) 
                          ? Colors.green.withOpacity(0.2) 
                          : Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (_washerId != null && _washerId!.isNotEmpty) ? Icons.timer : Icons.hourglass_top,
                          color: (_washerId != null && _washerId!.isNotEmpty) ? Colors.green : Colors.orange.shade800,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (_washerId != null && _washerId!.isNotEmpty && _etaMinutes > 0) 
                              ? '$_etaMinutes mins' 
                              : 'Searching',
                          style: TextStyle(
                            color: (_washerId != null && _washerId!.isNotEmpty) ? Colors.green : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
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
          
          // ============================================================
          // WASHER INFO CARD - Like second screenshot
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Provider Image
                  Container(
                    width: 60,
                    height: 60,
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
                                  size: 30,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.primary.withOpacity(0.1),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.primary,
                                  size: 30,
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.primary.withOpacity(0.1),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.washerName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              '4.8',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Professional Washer',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_distanceKm.toStringAsFixed(1)} km away',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _callWasher,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // ============================================================
          // ETA & SERVICE DETAILS - Like second screenshot
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Estimated Arrival',
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
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
              ],
            ),
          ),
          
          const Spacer(),
          
          // ============================================================
          // ACTION BUTTONS
          // ============================================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // COMPLETE ORDER BUTTON
                if (isCompleted && !isPaid)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isProcessing ? null : _customerConfirmCompletion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
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
                          : const Text(
                              '✅ Complete Order & Pay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                
                // RATE SERVICE BUTTON
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '⭐ Rate Your Service Provider',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                // ============================================================
                // PROVIDER ACTION SIMULATOR QUICK BAR (DEMO CONTROLS)
                // ============================================================
                _buildProviderSimulationQuickBar(),
                
                // CANCEL BOOKING BUTTON
                if (!isCompleted && !isPaid && !isCancelled)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isProcessing ? null : _cancelOrder,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel Booking',
                        style: TextStyle(
                          fontSize: 16,
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

  Widget _buildProviderSimulationQuickBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.touch_app, size: 16, color: AppColors.primary),
              SizedBox(width: 6),
              Text(
                'Provider Actions Control (Demo/Testing)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Simulate provider status actions live in real-time:',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
                      'status': 'arrived',
                      'arrivedAt': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 1,
                  ),
                  child: const Text('📍 Arrived', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
                      'status': 'in_progress',
                      'startedAt': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 1,
                  ),
                  child: const Text('🚿 Started', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).update({
                      'status': 'completed',
                      'completedAt': FieldValue.serverTimestamp(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 1,
                  ),
                  child: const Text('✅ Complete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
