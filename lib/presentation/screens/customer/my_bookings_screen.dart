// FILE: lib/presentation/screens/customer/my_bookings_screen.dart
// PURPOSE: Display user's bookings with click to track functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';
import 'tracking_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.userId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'My Bookings',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: userId == null || userId.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.account_circle_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Please login to view your bookings',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/login'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Go to Login'),
                    ),
                  ],
                ),
              )
            : FutureBuilder<List<Map<String, dynamic>>>(
                future: JobService().getUserJobs(userId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allJobs = snapshot.data ?? [];
                  
                  // ✅ Active jobs: searching, assigned, enRoute, arrived, accepted
                  final active = allJobs.where((j) =>
                      j['status'] == 'searching' ||
                      j['status'] == 'assigned' ||
                      j['status'] == 'in_progress' ||
                      j['status'] == 'accepted' ||
                      j['status'] == 'enRoute' ||
                      j['status'] == 'arrived').toList();
                      
                  // ✅ History: completed, paid, cancelled
                  final history = allJobs.where((j) =>
                      j['status'] == 'completed' || 
                      j['status'] == 'paid' ||
                      j['status'] == 'cancelled' ||
                      j['status'] == 'delivered').toList();

                  return TabBarView(
                    children: [
                      // Active Tab - Click to track
                      active.isEmpty
                          ? _buildEmptyState('No active bookings', 'Book a service to get started')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: active.length,
                              itemBuilder: (context, index) => 
                                  _buildBookingCard(context, active[index], isActive: true),
                            ),
                      // History Tab
                      history.isEmpty
                          ? _buildEmptyState('No booking history', 'Your completed orders will appear here')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: history.length,
                              itemBuilder: (context, index) => 
                                  _buildBookingCard(context, history[index], isActive: false),
                            ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking, {required bool isActive}) {
    final serviceName = booking['serviceName'] ?? booking['serviceCategory'] ?? 'Service';
    final status = (booking['status'] ?? 'pending').toString().toUpperCase();
    final price = booking['price'] != null ? '₦${booking['price']}' : '₦0';
    final scheduledDate = booking['scheduledTime'] ?? booking['scheduledDate'] ?? 'Scheduled';
    final washerName = booking['washerName'] ?? 'Provider';
    final jobId = booking['id'] ?? '';

    final isCompleted = booking['status'] == 'completed' || booking['status'] == 'paid' || booking['status'] == 'delivered';
    final isCancelled = booking['status'] == 'cancelled';
    final isAssigned = booking['status'] == 'assigned' || booking['status'] == 'enRoute' || booking['status'] == 'arrived';

    Color statusColor;
    if (isCompleted) {
      statusColor = Colors.green;
    } else if (isCancelled) {
      statusColor = Colors.red;
    } else if (isAssigned) {
      statusColor = Colors.blue;
    } else {
      statusColor = Colors.orange;
    }

    return GestureDetector(
      // ✅ CLICK TO TRACK - Only for active orders
      onTap: () {
        if (isActive && jobId.isNotEmpty) {
          _navigateToTracking(context, booking, jobId);
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isAssigned ? BorderSide(color: AppColors.primary, width: 2) : BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    scheduledDate,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    price,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        washerName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              
              // ✅ TRACK BUTTON - For active orders
              if (isActive && jobId.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToTracking(context, booking, jobId),
                      icon: const Icon(Icons.location_on, size: 18),
                      label: const Text('Track Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
              
              // Completed badge
              if (isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text(
                        'Service Completed',
                        style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTracking(BuildContext context, Map<String, dynamic> booking, String jobId) {
    final lat = booking['latitude'] ?? 6.5244;
    final lng = booking['longitude'] ?? 3.3792;
    final location = booking['location'] ?? 'Your Location';
    final serviceName = booking['serviceName'] ?? 'Service';
    final price = booking['price'] ?? 0;
    final washerName = booking['washerName'] ?? 'Provider';
    final washerId = booking['washerId'];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackingScreen(
          jobId: jobId,
          washerName: washerName,
          pickupAddress: location,
          pickupLocation: LatLng(lat, lng),
          serviceName: serviceName,
          price: price,
          washerId: washerId,
        ),
      ),
    );
  }
}
