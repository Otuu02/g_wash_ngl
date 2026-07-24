// FILE: lib/presentation/screens/customer/my_bookings_screen.dart
// PURPOSE: Display user's bookings (upcoming and history) from Firestore

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';

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
              Tab(text: 'Upcoming'),
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
                  
                  // ✅ Separate upcoming and completed/cancelled
                  final upcoming = allJobs.where((j) =>
                      j['status'] == 'searching' ||
                      j['status'] == 'assigned' ||
                      j['status'] == 'in_progress' ||
                      j['status'] == 'accepted' ||
                      j['status'] == 'enRoute').toList();
                      
                  final history = allJobs.where((j) =>
                      j['status'] == 'completed' || 
                      j['status'] == 'cancelled' ||
                      j['status'] == 'delivered').toList(); // ✅ Added 'delivered'

                  return TabBarView(
                    children: [
                      // Upcoming Tab
                      upcoming.isEmpty
                          ? _buildEmptyState('No upcoming bookings', 'Book a new service to get started')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: upcoming.length,
                              itemBuilder: (context, index) => _buildBookingCard(context, upcoming[index]),
                            ),
                      // History Tab - Shows completed and delivered orders
                      history.isEmpty
                          ? _buildEmptyState('No booking history', 'Your completed and cancelled orders will appear here')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: history.length,
                              itemBuilder: (context, index) => _buildBookingCard(context, history[index]),
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

  Widget _buildBookingCard(BuildContext context, Map<String, dynamic> booking) {
    final serviceName = booking['serviceName'] ?? booking['serviceCategory'] ?? 'Service';
    final status = (booking['status'] ?? 'pending').toString().toUpperCase();
    final price = booking['price'] != null ? '₦${booking['price']}' : '₦0';
    final scheduledDate = booking['scheduledTime'] ?? booking['scheduledDate'] ?? 'Scheduled';
    final washerName = booking['washerName'] ?? 'Provider';

    final isCompleted = booking['status'] == 'completed' || booking['status'] == 'delivered';
    final isCancelled = booking['status'] == 'cancelled';

    Color statusColor;
    if (isCompleted) {
      statusColor = Colors.green;
    } else if (isCancelled) {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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
            // ✅ Show "Completed" badge for delivered orders
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
            if (isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/booking');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Book Again'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}