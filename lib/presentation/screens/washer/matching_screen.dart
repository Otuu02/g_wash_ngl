import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
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
  List<Map<String, dynamic>> _nearbyWashers = [];
  bool _isLoading = true;
  bool _isSearching = true;
  Timer? _searchTimer;
  int _searchCount = 0;
  String? _selectedWasherId;
  bool _isAssigning = false;
  final Map<String, String> _providerImages = {};

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

      List<Map<String, dynamic>> washers = [];

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final userId = data['userId'] ?? doc.id;
          
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          String userName = 'Service Provider';
          if (userDoc.exists) {
            userName = userDoc.data()?['name'] ?? 'Service Provider';
          }

          String? profileImage = data['profileImage'];
          if (profileImage == null || profileImage.isEmpty) {
            if (userDoc.exists) {
              profileImage = userDoc.data()?['profileImage'];
            }
          }

          if (profileImage != null && profileImage.isNotEmpty) {
            _providerImages[doc.id] = profileImage;
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
            'totalEarnings': data['totalEarnings'] ?? 0,
            'isOnline': data['isOnline'] ?? true,
            'profileImage': profileImage,
            'distance': _calculateDistance(data),
            'eta': _calculateETA(data['workingRadius'] ?? 10),
            'bio': data['bio'] ?? 'Professional service provider',
          });
        }

        washers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

        setState(() {
          _nearbyWashers = washers;
          _isLoading = false;
          _isSearching = false;
        });
      } else {
        // No washers found - show message
        setState(() {
          _nearbyWashers = [];
          _isLoading = false;
          _isSearching = false;
        });
        print('⚠️ No washers found in Firestore. Please add some washers to the database.');
      }
    } catch (e) {
      print('❌ Error searching for providers: $e');
      setState(() {
        _nearbyWashers = [];
        _isLoading = false;
        _isSearching = false;
      });
    }
  }

  double _calculateDistance(Map<String, dynamic> data) {
    final radius = (data['workingRadius'] ?? 10) as int;
    return 0.3 + (radius / 2) * (DateTime.now().millisecondsSinceEpoch % 100) / 100;
  }

  String _calculateETA(int workingRadius) {
    if (workingRadius < 5) return '3 mins';
    if (workingRadius < 10) return '5 mins';
    if (workingRadius < 15) return '8 mins';
    return '10 mins';
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Future<void> _selectProvider(Map<String, dynamic> provider) async {
    setState(() {
      _selectedWasherId = provider['id'];
      _isAssigning = true;
    });

    try {
      // Check if the provider exists in Firestore
      final docExists = await FirebaseFirestore.instance
          .collection('washers')
          .doc(provider['id'])
          .get();

      if (!docExists.exists) {
        print('❌ Provider ${provider['id']} does not exist in Firestore');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Provider not found. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isAssigning = false;
          _selectedWasherId = null;
        });
        return;
      }

      // Update job with selected provider
      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'washerId': provider['id'],
        'washerName': provider['name'],
        'washerRating': provider['rating'],
        'washerPhone': provider['phone'] ?? '',
        'status': 'assigned',
        'assignedAt': FieldValue.serverTimestamp(),
        'washerImage': provider['profileImage'] ?? '',
      });

      // Update provider stats
      await FirebaseFirestore.instance
          .collection('washers')
          .doc(provider['id'])
          .update({
        'pendingJobs': FieldValue.increment(1),
        'lastJobAssigned': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrackingScreen(
              jobId: widget.jobId,
              washerName: provider['name'],
              pickupAddress: widget.location,
              pickupLocation: const LatLng(6.5244, 3.3792),
              serviceName: widget.serviceName,
              price: widget.price,
              washerId: provider['id'],
              washerImage: provider['profileImage'],
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error assigning provider: $e');
      setState(() {
        _isAssigning = false;
        _selectedWasherId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error assigning provider. Please try again.'),
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
        actions: [
          if (!_isSearching && _nearbyWashers.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_nearbyWashers.length}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue.withOpacity(0.05),
            child: Row(
              children: [
                _isSearching
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 24,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSearching 
                            ? 'Searching for providers...' 
                            : _nearbyWashers.isEmpty
                                ? 'No providers available'
                                : '${_nearbyWashers.length} providers found nearby',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _isSearching 
                            ? 'Please wait while we find the best match' 
                            : _nearbyWashers.isEmpty
                                ? 'Please try again later or add providers to Firestore'
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
                              'Please add washers to Firestore or try again later',
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
                                backgroundColor: Colors.green,
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
                          final provider = _nearbyWashers[index];
                          final isSelected = _selectedWasherId == provider['id'];
                          final imageUrl = _providerImages[provider['id']];
                          final initials = _getInitials(provider['name']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? Colors.green : Colors.grey.shade200,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            elevation: isSelected ? 4 : 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? Colors.green : Colors.grey.shade300,
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: imageUrl != null && imageUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey.shade200,
                                                child: Center(
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Colors.grey.shade200,
                                                child: Center(
                                                  child: Text(
                                                    initials,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Text(
                                                  initials,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey,
                                                  ),
                                                ),
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
                                          provider['name'],
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
                                            Text(
                                              provider['rating'].toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 4,
                                              height: 4,
                                              decoration: const BoxDecoration(
                                                color: Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              Icons.work,
                                              color: Colors.grey.shade500,
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${provider['totalJobs']} jobs',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.green,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              provider['distance'].toStringAsFixed(1),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                            const Text(' km away'),
                                            const SizedBox(width: 12),
                                            Icon(
                                              Icons.timer,
                                              color: Colors.orange,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              provider['eta'],
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: _isAssigning && isSelected
                                        ? null
                                        : () => _selectProvider(provider),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
                                      foregroundColor: isSelected ? Colors.white : Colors.green,
                                      minimumSize: const Size(70, 36),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: _isAssigning && isSelected
                                        ? const SizedBox(
                                            height: 16,
                                            width: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            isSelected ? 'Selected' : 'Assign',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                  ),
                                ],
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
