// lib/presentation/screens/customer/matching_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import 'tracking_screen.dart';

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
  List<Map<String, dynamic>> _nearbyWashers = [];
  bool _isLoading = true;
  bool _isSearching = true;
  Timer? _searchTimer;
  int _searchCount = 0;

  @override
  void initState() {
    super.initState();
    _searchForWashers();
    _startPeriodicSearch();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicSearch() {
    _searchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_searchCount < 20) {
        _searchForWashers();
        _searchCount++;
      } else {
        timer.cancel();
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _searchForWashers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('washers')
          .where('isOnline', isEqualTo: true)
          .where('approved', isEqualTo: true)
          .limit(10)
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> washers = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] ?? doc.id;
          
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          String userName = 'Washer';
          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? 'Washer';
          }

          washers.add({
            'id': doc.id,
            'userId': userId,
            'name': userName,
            'phone': data['phone'] ?? '',
            'vehicleType': data['vehicleType'] ?? 'Car',
            'workingRadius': data['workingRadius'] ?? 10,
            'rating': data['rating'] ?? 4.5,
            'totalJobs': data['totalJobs'] ?? 0,
            'isOnline': data['isOnline'] ?? true,
            'distance': (data['workingRadius'] ?? 10) / 2,
            'eta': _calculateETA(data['workingRadius'] ?? 10),
          });
        }

        setState(() {
          _nearbyWashers = washers;
          _isLoading = false;
          _isSearching = false;
        });

        print('✅ Found ${washers.length} nearby washers');
      } else {
        // Demo washers if none in Firestore
        setState(() {
          _nearbyWashers = _getDemoWashers();
          _isLoading = false;
          _isSearching = false;
        });
        print('⚠️ No washers found in Firestore, using demo data');
      }
    } catch (e) {
      print('❌ Error searching for washers: $e');
      setState(() {
        _nearbyWashers = _getDemoWashers();
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  String _calculateETA(int workingRadius) {
    if (workingRadius < 5) return '3 mins';
    if (workingRadius < 10) return '5 mins';
    if (workingRadius < 15) return '8 mins';
    return '10 mins';
  }

  List<Map<String, dynamic>> _getDemoWashers() {
    return [
      {
        'id': 'demo1',
        'name': 'John A.',
        'rating': 4.8,
        'vehicleType': 'Car',
        'distance': 0.5,
        'eta': '3 mins',
        'isOnline': true,
        'totalJobs': 150,
      },
      {
        'id': 'demo2',
        'name': 'Mary B.',
        'rating': 4.9,
        'vehicleType': 'SUV',
        'distance': 1.2,
        'eta': '5 mins',
        'isOnline': true,
        'totalJobs': 200,
      },
      {
        'id': 'demo3',
        'name': 'Peter C.',
        'rating': 4.7,
        'vehicleType': 'Van',
        'distance': 2.0,
        'eta': '8 mins',
        'isOnline': true,
        'totalJobs': 120,
      },
      {
        'id': 'demo4',
        'name': 'Grace D.',
        'rating': 4.6,
        'vehicleType': 'Car',
        'distance': 2.5,
        'eta': '10 mins',
        'isOnline': true,
        'totalJobs': 80,
      },
    ];
  }

  void _selectWasher(Map<String, dynamic> washer) async {
    try {
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'washerId': washer['id'],
        'washerName': washer['name'],
        'washerRating': washer['rating'],
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              jobId: widget.jobId,
              washerName: washer['name'],
              pickupAddress: widget.location,
              pickupLocation: const LatLng(6.5244, 3.3792),
              serviceName: widget.serviceName,
              price: widget.price,
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error assigning washer: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Finding Service Provider',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Status
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              children: [
                _isSearching
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSearching ? 'Searching for providers...' : '${_nearbyWashers.length} providers found nearby',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _isSearching 
                            ? 'Please wait while we find the best match' 
                            : 'Select a provider to continue',
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

          // Washer List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Finding nearby providers...'),
                      ],
                    ),
                  )
                : _nearbyWashers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off, size: 60, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No providers available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please try again later',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _isSearching = true;
                                  _searchCount = 0;
                                });
                                _searchForWashers();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Try Again'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _nearbyWashers.length,
                        itemBuilder: (context, index) {
                          final washer = _nearbyWashers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: AppColors.primary,
                                ),
                              ),
                              title: Text(
                                washer['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        washer['rating'].toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${washer['vehicleType']}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${washer['totalJobs']} jobs',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: AppColors.primary,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${washer['distance']} km away',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Icon(
                                        Icons.timer,
                                        color: Colors.orange,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        washer['eta'],
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: ElevatedButton(
                                onPressed: _isSearching ? null : () => _selectWasher(washer),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(70, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Select'),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}