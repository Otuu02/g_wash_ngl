// lib/presentation/screens/washer/matching_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/job_service.dart';
import '../../../services/location_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/app_notification_service.dart';
import '../customer/tracking_screen.dart';

class MatchingScreen extends StatefulWidget {
  final String jobId;
  final String serviceCategory;
  final String serviceName;
  final int price;
  final String location;

  const MatchingScreen({
    super.key,
    required this.jobId,
    required this.serviceCategory,
    required this.serviceName,
    required this.price,
    required this.location,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  bool _isSearching = true;
  List<Map<String, dynamic>> _washers = [];
  String? _selectedWasherId;

  @override
  void initState() {
    super.initState();
    _findWashers();
    _listenToJobStatus();
  }

  Future<void> _findWashers() async {
    setState(() => _isSearching = true);

    try {
      double userLat = 6.5244;
      double userLng = 3.3792;
      try {
        final loc = await LocationService().getCurrentLocation();
        userLat = loc.latitude;
        userLng = loc.longitude;
      } catch (_) {
        // Fallback to default Lagos coordinates
      }

      final fetchedWashers = await JobService().getProvidersByCategory(
        category: widget.serviceCategory,
        userLat: userLat,
        userLng: userLng,
      );

      setState(() {
        _washers = fetchedWashers;
        _isSearching = false;
      });
    } catch (e) {
      print('❌ Error finding washers: $e');
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error finding washers: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _listenToJobStatus() {
    FirebaseFirestore.instance
        .collection('jobs')
        .doc(widget.jobId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final status = snapshot.data()?['status'];
        final washerId = snapshot.data()?['washerId'];
        
        if (status == 'assigned' && washerId != null && mounted) {
          // Job assigned - navigate to tracking
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrackingScreen(
                jobId: widget.jobId,
                washerName: _washers.firstWhere(
                  (w) => w['id'] == washerId,
                  orElse: () => {'name': 'Assigned Washer'},
                )['name'],
                pickupAddress: widget.location,
                pickupLocation: const LatLng(6.4281, 3.4213),
                serviceName: widget.serviceName,
                price: widget.price,
              ),
            ),
          );
        }
      }
    });
  }

  void _assignWasher(Map<String, dynamic> washer) async {
    setState(() => _selectedWasherId = washer['id']);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Confirm ${widget.serviceCategory}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👤 ${washer['name']}'),
            Text('⭐ ${washer['rating']}'),
            Text('📍 ${washer['distance']} away'),
            Text('⏱ ${washer['eta']}'),
            const Divider(),
            Text('💰 ₦${widget.price}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedWasherId = null);
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _assignWasherToJob(washer);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm & Assign'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignWasherToJob(Map<String, dynamic> washer) async {
    try {
      setState(() => _isSearching = true);

      // Update job in Firestore
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'washerId': washer['id'],
        'washerName': washer['name'],
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Washer ${washer['name']} assigned to job ${widget.jobId}');

      // Trigger local in-app top popup & offline notification
      AppNotificationService().notify(
        context: context,
        title: '📍 Provider Assigned!',
        message: '${washer['name']} is assigned for your ${widget.serviceCategory}.',
        type: 'provider',
        icon: Icons.person_pin_circle,
        backgroundColor: Colors.blue.shade700,
      );

      // Send WhatsApp and Email notifications to assigned provider
      final nowFormatted = DateFormat('EEE, MMM d, yyyy').format(DateTime.now());
      final nowTimeFormatted = DateFormat('hh:mm a').format(DateTime.now());
      CommunicationService.sendBookingNotifications(
        providerPhone: washer['phone']?.toString(),
        providerEmail: washer['email']?.toString(),
        providerName: washer['name'] ?? 'Provider',
        customerName: 'G-Wash Customer',
        serviceCategory: widget.serviceCategory,
        serviceName: widget.serviceName,
        price: widget.price,
        location: widget.location,
        scheduledDate: nowFormatted,
        scheduledTime: nowTimeFormatted,
        jobId: widget.jobId,
        context: context,
      );

      // Navigate to tracking screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              jobId: widget.jobId,
              washerName: washer['name'],
              pickupAddress: widget.location,
              pickupLocation: const LatLng(6.4281, 3.4213),
              serviceName: widget.serviceName,
              price: widget.price,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error assigning washer: $e');
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning washer: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: const Text('Finding Service Provider'),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (_isSearching) ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                      SizedBox(height: 24),
                      Text(
                        '🔍 Finding nearest service provider...',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Searching within 5km radius',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_washers.isEmpty) ...[
              // FIXED: Removed 'const' from Expanded to allow non-constant child
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_transportation, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No washers available nearby',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please try again later',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _findWashers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                '✅ ${_washers.length} providers found nearby',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _washers.length,
                  itemBuilder: (context, index) {
                    final washer = _washers[index];
                    final isSelected = _selectedWasherId == washer['id'];
                    final rawName = washer['name']?.toString() ?? 'Service Provider';
                    final name = rawName.isNotEmpty ? rawName : 'Service Provider';
                    final initial = name[0].toUpperCase();
                    final rating = washer['rating']?.toString() ?? '4.8';
                    final distance = washer['distance']?.toString() ?? '1.5 km';
                    final eta = washer['eta']?.toString() ?? '10 mins';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primary.withOpacity(0.15),
                            child: Text(
                              initial,
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                        Text(' $rating', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                    Text('📍 $distance', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                    Text('⏱ $eta', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 75,
                            height: 34,
                            child: isSelected
                                ? const Center(
                                    child: SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    onPressed: _selectedWasherId == null
                                        ? () => _assignWasher(washer)
                                        : null,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text('Assign', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}