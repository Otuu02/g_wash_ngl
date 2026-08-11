// FILE: lib/presentation/screens/washer/job_request_screen.dart
// PURPOSE: Display and manage incoming job requests from Firestore

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/job_service.dart';
import '../../../services/cloudinary_service.dart';
import '../customer/tracking_screen.dart';

class JobRequestScreen extends StatefulWidget {
  const JobRequestScreen({super.key});

  @override
  State<JobRequestScreen> createState() => _JobRequestScreenState();
}

class _JobRequestScreenState extends State<JobRequestScreen> {
  int _selectedTab = 0;

  Future<void> _acceptJob(Map<String, dynamic> job, String washerId) async {
    final jobId = job['id'];
    if (jobId == null) return;

    final resolvedWasherId = washerId.isNotEmpty
        ? washerId
        : (Provider.of<AuthService>(context, listen: false).userId ?? '');

    if (resolvedWasherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in as a service provider to accept jobs.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      final result = await JobService().assignProviderToJob(
        jobId: jobId, 
        providerId: resolvedWasherId,
      );

      final washerName = result['washerName'] ?? 'Provider';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job Accepted Successfully! Customer notified.'),
            backgroundColor: Colors.green,
          ),
        );

        final lat = job['latitude'] ?? 6.5244;
        final lng = job['longitude'] ?? 3.3792;
        final location = job['location'] ?? 'Customer Location';

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              jobId: jobId,
              washerName: washerName,
              pickupAddress: location,
              pickupLocation: LatLng(lat, lng),
              serviceName: job['serviceName'] ?? 'Service',
              price: job['price'] ?? 0,
              washerId: resolvedWasherId,
              washerImage: result['washerImage'],
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error accepting job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept job: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _declineJob(Map<String, dynamic> job) async {
    final jobId = job['id'];
    if (jobId == null) return;

    try {
      await JobService().cancelJob(
        jobId: jobId,
        reason: 'Declined by service provider',
        cancelledBy: 'Service Provider',
      );
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final washerId = authService.userId ?? '';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Job Requests',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            onTap: (index) => setState(() => _selectedTab = index),
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Pending Requests'),
              Tab(text: 'Active Jobs'),
            ],
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('jobs').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            final List<Map<String, dynamic>> allJobs = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                ...data,
              };
            }).toList();

            // Sort newest first
            allJobs.sort((a, b) {
              final aTime = a['createdAt'] is Timestamp ? (a['createdAt'] as Timestamp).toDate() : DateTime(2020);
              final bTime = b['createdAt'] is Timestamp ? (b['createdAt'] as Timestamp).toDate() : DateTime(2020);
              return bTime.compareTo(aTime);
            });

            // Pending Jobs: matching washerId OR unassigned/searching broadcast
            final pendingJobs = allJobs.where((j) {
              final status = (j['status'] ?? '').toString().toLowerCase();
              final jWasherId = (j['washerId'] ?? j['assignedWasherId'] ?? '').toString();
              
              final isDirectForMe = washerId.isNotEmpty && (jWasherId == washerId);
              final isUnassignedBroadcast = (jWasherId.isEmpty || jWasherId == 'null' || jWasherId == 'broadcast') &&
                  (status == 'searching' || status == 'pending' || status == 'unassigned');

              if (isDirectForMe && (status == 'assigned' || status == 'pending' || status == 'pending_acceptance' || status == 'searching')) {
                return true;
              }
              if (isUnassignedBroadcast) {
                return true;
              }
              return false;
            }).toList();

            // Active Jobs: strictly assigned to current washer & active status
            final activeJobs = allJobs.where((j) {
              final status = (j['status'] ?? '').toString().toLowerCase();
              final jWasherId = (j['washerId'] ?? j['assignedWasherId'] ?? '').toString();
              
              final isMyJob = washerId.isNotEmpty && (jWasherId == washerId);
              final isActiveStatus = status == 'accepted' || status == 'enroute' || status == 'in_progress' || status == 'arrived';

              return isMyJob && isActiveStatus;
            }).toList();

            return TabBarView(
              children: [
                pendingJobs.isEmpty
                    ? _buildEmptyState('No pending job requests', 'Check back later for new customer requests')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: pendingJobs.length,
                        itemBuilder: (context, index) =>
                            _buildJobCard(pendingJobs[index], washerId),
                      ),
                activeJobs.isEmpty
                    ? _buildEmptyState('No active jobs', 'Accepted jobs will appear here')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeJobs.length,
                        itemBuilder: (context, index) =>
                            _buildActiveJobCard(activeJobs[index]),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, String washerId) {
    final serviceName = job['serviceName'] ?? job['serviceCategory'] ?? 'Service';
    final price = job['price'] ?? 0;
    final customerName = job['customerName'] ?? 'Customer';
    final customerPhone = job['customerPhone'] ?? job['phone'] ?? '';
    final address = job['location'] ?? job['address'] ?? 'Customer Location';
    final scheduledInfo = job['scheduledTime'] ?? job['scheduledDate'] ?? 'Immediate';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 10, color: Colors.green),
                          SizedBox(width: 3),
                          Text(
                            'Escrow Paid',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  '₦$price',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (customerPhone.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.phone, size: 14, color: AppColors.grey600),
                  const SizedBox(width: 4),
                  Text(
                    customerPhone,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.timer, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Text(
                  scheduledInfo,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _declineJob(job),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptJob(job, washerId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobCard(Map<String, dynamic> job) {
    final serviceName = job['serviceName'] ?? job['serviceCategory'] ?? 'Service';
    final customerName = job['customerName'] ?? 'Customer';
    final address = job['location'] ?? job['address'] ?? 'Customer Location';
    final eta = job['eta'] ?? '15 mins';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    serviceName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        'ETA: $eta',
                        style: const TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    customerName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.grey600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // ============================================================
            // WORKFLOW STATUS BUTTONS FOR PROVIDER
            // ============================================================
            _buildStatusActionButton(job),
            
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelActiveJob(job),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final jobId = job['id'];
                      if (jobId != null) {
                        final lat = job['latitude'] ?? 6.5244;
                        final lng = job['longitude'] ?? 3.3792;
                        final location = job['location'] ?? 'Customer Location';
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TrackingScreen(
                              jobId: jobId,
                              washerName: job['washerName'] ?? 'Provider',
                              pickupAddress: location,
                              pickupLocation: LatLng(lat, lng),
                              serviceName: job['serviceName'] ?? 'Service',
                              price: job['price'] ?? 0,
                              washerId: job['washerId'],
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Track / Map'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.blue),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap buttons above to update customer on your arrival and service progress.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelActiveJob(Map<String, dynamic> job) async {
    final jobId = job['id'];
    if (jobId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Job'),
        content: Text('Are you sure you want to cancel ${job['serviceName'] ?? 'this job'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await JobService().cancelJob(
                  jobId: jobId,
                  reason: 'Cancelled by service provider',
                  cancelledBy: 'Service Provider',
                );
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Job cancelled'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to cancel job: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: AppColors.grey400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AppColors.grey600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (title == 'No pending job requests')
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 24,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'re all caught up!',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'New jobs will appear here',
                      style: TextStyle(
                        color: AppColors.grey600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusActionButton(Map<String, dynamic> job) {
    final status = job['status'] ?? 'assigned';
    final jobId = job['id'];

    if (status == 'assigned' || status == 'enRoute') {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () async {
            if (jobId != null) {
              await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
                'status': 'arrived',
                'arrivedAt': FieldValue.serverTimestamp(),
              });
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('📍 Updated: You have arrived!'), backgroundColor: Colors.blue),
                );
              }
            }
          },
          icon: const Icon(Icons.location_on, color: Colors.white, size: 20),
          label: const Text('📍 I Have Arrived', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else if (status == 'arrived') {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () async {
            if (jobId != null) {
              await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
                'status': 'in_progress',
                'startedAt': FieldValue.serverTimestamp(),
              });
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('🚿 Updated: Service Started!'), backgroundColor: Colors.purple),
                );
              }
            }
          },
          icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
          label: const Text('🚿 Start Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else if (status == 'in_progress') {
      return SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton.icon(
          onPressed: () {
            if (jobId != null) {
              _showCompletionProofModal(context, jobId);
            }
          },
          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
          label: const Text('📸 Complete Job & Upload Proof', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _showCompletionProofModal(BuildContext context, String jobId) async {
    XFile? pickedFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📸 Upload Proof of Completion',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Please snap or upload a photo of the completed job to release Escrow payment.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              if (pickedFile != null) ...[
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FutureBuilder(
                      future: pickedFile!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Image.memory(snapshot.data!, fit: BoxFit.cover);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                        if (img != null) {
                          setModalState(() => pickedFile = img);
                        }
                      },
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                        if (img != null) {
                          setModalState(() => pickedFile = img);
                        }
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isUploading
                      ? null
                      : () async {
                          if (pickedFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('❌ Please capture or upload a proof photo before completing.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isUploading = true);

                          try {
                            // Upload proof image to Cloudinary
                            final proofUrl = await CloudinaryService().uploadImage(
                              imageFile: pickedFile!,
                              folder: 'job_proofs',
                            );

                            // Update Firestore job doc with proof
                            await FirebaseFirestore.instance.collection('jobs').doc(jobId).update({
                              'completionProofUrl': proofUrl ?? '',
                              'completedAt': FieldValue.serverTimestamp(),
                            });

                            // Complete job and release Escrow
                            await JobService().completeJob(jobId, context: context);

                            if (mounted) {
                              Navigator.pop(modalContext);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('🎉 Service completed & Escrow payment released!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() => isUploading = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Upload error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                  icon: isUploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle),
                  label: Text(isUploading ? 'Uploading Proof...' : 'Submit Proof & Release Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
