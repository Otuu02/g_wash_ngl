// FILE: lib/presentation/screens/washer/washer_job_history_screen.dart
// PURPOSE: Full Job History Screen for Service Providers / Washers

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import 'washer_order_details_screen.dart';

class WasherJobHistoryScreen extends StatefulWidget {
  final String? washerId;
  const WasherJobHistoryScreen({super.key, this.washerId});

  @override
  State<WasherJobHistoryScreen> createState() => _WasherJobHistoryScreenState();
}

class _WasherJobHistoryScreenState extends State<WasherJobHistoryScreen> {
  int _selectedFilterIndex = 0; // 0: All, 1: Completed, 2: Active, 3: Cancelled

  final List<String> _filters = ['All', 'Completed', 'Active', 'Cancelled'];

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final resolvedWasherId = widget.washerId ?? authService.userId ?? '';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Job History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_filters.length, (index) {
                  final isSelected = _selectedFilterIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(_filters[index]),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey.shade100,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedFilterIndex = index);
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
          ),

          // Real-time Firestore Jobs Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error loading history: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];

                // Filter jobs belonging to current washer
                final List<Map<String, dynamic>> washerJobs = [];
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final jobWasherId = (data['washerId'] ?? data['assignedWasherId'] ?? '').toString();

                  if (resolvedWasherId.isNotEmpty && jobWasherId == resolvedWasherId) {
                    washerJobs.add({
                      'id': doc.id,
                      ...data,
                    });
                  }
                }

                // Sort by date (newest first)
                washerJobs.sort((a, b) {
                  final aTime = a['createdAt'] is Timestamp
                      ? (a['createdAt'] as Timestamp).toDate()
                      : DateTime(2020);
                  final bTime = b['createdAt'] is Timestamp
                      ? (b['createdAt'] as Timestamp).toDate()
                      : DateTime(2020);
                  return bTime.compareTo(aTime);
                });

                // Apply tab filter
                final filteredJobs = washerJobs.where((job) {
                  final status = (job['status'] ?? '').toString().toLowerCase();

                  if (_selectedFilterIndex == 1) {
                    // Completed
                    return status == 'completed' || status == 'paid';
                  } else if (_selectedFilterIndex == 2) {
                    // Active
                    return status == 'assigned' || status == 'accepted' || status == 'in_progress' || status == 'arrived' || status == 'enroute';
                  } else if (_selectedFilterIndex == 3) {
                    // Cancelled
                    return status == 'cancelled' || status == 'declined';
                  }
                  return true; // All
                }).toList();

                if (filteredJobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No ${_filters[_selectedFilterIndex].toLowerCase()} jobs found',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Completed and active job history will appear here.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    final job = filteredJobs[index];
                    return _buildJobItemCard(context, job);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobItemCard(BuildContext context, Map<String, dynamic> job) {
    final String serviceName = job['serviceName'] ?? job['serviceCategory'] ?? 'Service';
    final String customerName = job['customerName'] ?? job['userName'] ?? 'Customer';
    final num price = job['price'] ?? 0;
    final String location = job['location'] ?? job['address'] ?? 'Customer Location';
    final String status = (job['status'] ?? 'pending').toString().toLowerCase();

    DateTime? jobDate;
    if (job['createdAt'] is Timestamp) {
      jobDate = (job['createdAt'] as Timestamp).toDate();
    }

    final dateStr = jobDate != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(jobDate) : 'Recently';

    Color statusColor;
    String statusLabel;

    switch (status) {
      case 'completed':
      case 'paid':
        statusColor = Colors.green;
        statusLabel = 'Completed';
        break;
      case 'cancelled':
      case 'declined':
        statusColor = Colors.red;
        statusLabel = 'Cancelled';
        break;
      case 'in_progress':
      case 'accepted':
      case 'enroute':
      case 'arrived':
        statusColor = Colors.blue;
        statusLabel = 'In Progress';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = status.toUpperCase();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WasherOrderDetailsScreen(
                jobId: job['id'],
                order: job,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      serviceName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(customerName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  const Spacer(),
                  Text(
                    '₦${NumberFormat('#,###').format(price)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Row(
                    children: [
                      Text('Details', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
