import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/communication_service.dart';
import '../../../services/app_notification_service.dart';

class RatingScreen extends StatefulWidget {
  final String jobId;
  final String washerId;
  final String? serviceName;

  const RatingScreen({
    super.key,
    required this.jobId,
    required this.washerId,
    this.serviceName,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  double _rating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _quickComments = [
    'Excellent service!',
    'Very professional',
    'On time and efficient',
    'Great value for money',
    'Will recommend',
    'Car looks brand new',
  ];

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final customerId = authService.getCurrentUserId() ?? '';
      final customerName = authService.userName ?? 'Customer';
      final commentText = _commentController.text.trim();

      // 1. Save review document to Firestore
      await FirebaseFirestore.instance.collection('reviews').add({
        'jobId': widget.jobId,
        'washerId': widget.washerId,
        'customerId': customerId,
        'customerName': customerName,
        'serviceName': widget.serviceName ?? 'Service',
        'rating': _rating,
        'comment': commentText.isNotEmpty ? commentText : 'No comment provided.',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update job record with rating & review
      if (widget.jobId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('jobs').doc(widget.jobId).set({
          'rating': _rating,
          'review': commentText.isNotEmpty ? commentText : 'No comment provided.',
          'ratedAt': FieldValue.serverTimestamp(),
          'isRated': true,
        }, SetOptions(merge: true));
      }

      // 3. Recalculate Washer Average Rating
      if (widget.washerId.isNotEmpty) {
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('washerId', isEqualTo: widget.washerId)
            .get();

        if (reviewsSnapshot.docs.isNotEmpty) {
          double totalSum = 0.0;
          for (var doc in reviewsSnapshot.docs) {
            totalSum += (doc.data()['rating'] ?? 5.0).toDouble();
          }
          final double avgRating = totalSum / reviewsSnapshot.docs.length;
          final double roundedRating = double.parse(avgRating.toStringAsFixed(1));

          await FirebaseFirestore.instance.collection('washers').doc(widget.washerId).set({
            'rating': roundedRating,
            'totalReviewsCount': reviewsSnapshot.docs.length,
          }, SetOptions(merge: true));
        }

        // Fetch washer info to dispatch notification
        final washerDoc = await FirebaseFirestore.instance.collection('washers').doc(widget.washerId).get();
        final washerData = washerDoc.data() ?? {};
        final wPhone = washerData['phone'] ?? '';
        final wEmail = washerData['email'] ?? '';

        final notificationMsg = '⭐ New ${_rating.toStringAsFixed(0)}-Star Review from $customerName: "${commentText.isNotEmpty ? commentText : 'Great service!'}"';

        // Dispatch System Push, SMS, Email
        AppNotificationService().notify(
          title: '⭐ New Rating & Review Received',
          message: notificationMsg,
          type: 'review',
        );

        if (wPhone.isNotEmpty) {
          await CommunicationService().sendRealSms(phone: wPhone, message: notificationMsg);
        }
        if (wEmail.isNotEmpty) {
          await CommunicationService().sendRealEmail(
            email: wEmail,
            subject: '⭐ You received a new review - G Wash NG',
            body: notificationMsg,
          );
        }
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your review!'),
            backgroundColor: AppColors.primary,
          ),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      print('❌ Error submitting rating: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Your Experience'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Car Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_emotions,
                size: 60,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'How was your experience?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your feedback helps us improve',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            
            // Star Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      size: 48,
                      color: Colors.amber,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              _rating > 0 ? '${_rating.toInt()}/5 stars' : 'Tap to rate',
              style: TextStyle(
                color: _rating > 0 ? AppColors.primary : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            
            // Comment Field
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
            
            // Quick Comments
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickComments.map((comment) {
                return FilterChip(
                  label: Text(comment),
                  selected: _commentController.text == comment,
                  onSelected: (selected) {
                    setState(() {
                      _commentController.text = selected ? comment : '';
                    });
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Rating',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    );
  }
}