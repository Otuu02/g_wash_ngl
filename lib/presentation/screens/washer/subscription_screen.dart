// FILE: lib/presentation/screens/washer/subscription_screen.dart
// PURPOSE: Monthly subscription payment for washers

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'washer_dashboard.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  bool _isAnnual = false;

  Future<void> _processSubscription() async {
    setState(() => _isLoading = true);
    
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() => _isLoading = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subscription activated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WasherDashboard()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthlyPrice = 5000;
    final annualPrice = monthlyPrice * 12 * 0.8; // 20% discount
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subscribe to Continue'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.workspace_premium, size: 80, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Choose Your Plan',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Subscribe to start receiving job requests',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey600),
            ),
            const SizedBox(height: 32),
            
            // Monthly Plan
            _buildPlanCard(
              title: 'Monthly Plan',
              price: '₦${monthlyPrice.toString()}',
              period: '/month',
              features: [
                'Unlimited job requests',
                'Priority support',
                'Higher earnings potential',
                'Access to premium features',
              ],
              isPopular: true,
              isSelected: !_isAnnual,
              onTap: () => setState(() => _isAnnual = false),
            ),
            const SizedBox(height: 16),
            
            // Annual Plan
            _buildPlanCard(
              title: 'Annual Plan',
              price: '₦${annualPrice.toInt().toString()}',
              period: '/year',
              features: [
                'Everything in Monthly',
                'Save 20%',
                'Free profile promotion',
                'Monthly bonus rewards',
              ],
              isPopular: false,
              isSelected: _isAnnual,
              onTap: () => setState(() => _isAnnual = true),
            ),
            const SizedBox(height: 32),
            
            // Benefits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildBenefitItem(Icons.check_circle, 'No hidden fees'),
                  const SizedBox(height: 8),
                  _buildBenefitItem(Icons.check_circle, 'Cancel anytime'),
                  const SizedBox(height: 8),
                  _buildBenefitItem(Icons.check_circle, '100% secure payments'),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Subscribe Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processSubscription,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Subscribe ${_isAnnual ? 'Annually' : 'Monthly'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Start 7-day free trial
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const WasherDashboard()),
                );
              },
              child: const Text('Try 7-day free trial'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isPopular,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPopular)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Most Popular',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Text(
                  period,
                  style: TextStyle(color: AppColors.grey600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.check, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(feature, style: const TextStyle(fontSize: 14)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}