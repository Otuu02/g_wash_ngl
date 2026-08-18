// FILE: lib/presentation/screens/welcome_screen.dart
// PURPOSE: Welcome/Onboarding screen with all services and Google Sign-In

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _onboardingPages = [
    {
      'title': 'Professional Car Wash',
      'subtitle': 'Get your car sparkling clean at your doorstep',
      'icon': Icons.directions_car_rounded,
      'iconColor': Color(0xFFE53935), // Red car
      'bgColor': Color(0xFFE8F5E9),   // Mint green circle
    },
    {
      'title': 'Expert House Cleaning',
      'subtitle': 'Professional cleaning services for your home',
      'icon': Icons.cleaning_services_rounded,
      'iconColor': Color(0xFFFB8C00), // Orange broom
      'bgColor': Color(0xFFFFF3E0),   // Peach circle
    },
    {
      'title': 'Premium Laundry Service',
      'subtitle': 'Wash, dry, and fold - we do it all',
      'icon': Icons.local_laundry_service_rounded,
      'iconColor': Color(0xFF1E88E5), // Blue laundry
      'bgColor': Color(0xFFE3F2FD),   // Soft blue circle
    },
    {
      'title': 'Dispatch Rider Service',
      'subtitle': 'Fast, reliable delivery anywhere in Nigeria',
      'icon': Icons.two_wheeler_rounded,
      'iconColor': Color(0xFF8E24AA), // Purple bike
      'bgColor': Color(0xFFF3E5F5),   // Soft purple circle
    },
  ];

  // ============================================================
  // GOOGLE SIGN-IN - CORRECT FIREBASE WEB CLIENT ID
  // ============================================================
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '268073858735-gg0t71o28uauh3rkfrf5gvu3bam2s867.apps.googleusercontent.com',
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'name': user.displayName ?? 'User',
            'email': user.email ?? '',
            'phone': user.phoneNumber ?? '',
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
            'walletBalance': 0.0,
          });
        }

        final authService = Provider.of<AuthService>(context, listen: false);
        authService.notifyListeners();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${user.displayName ?? 'User'}!'),
              backgroundColor: AppColors.primary,
            ),
          );
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with Logo
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'G',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'G Wash NG',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // PageView for Onboarding Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() => _currentPage = page);
                },
                itemCount: _onboardingPages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_onboardingPages[index]);
                },
              ),
            ),

            // Page Indicator Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingPages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  // Get Started / Create Account Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Google Sign-In Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  child: const Text(
                                    'G',
                                    style: TextStyle(
                                      color: Color(0xFF4285F4),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Continue with Google',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ONBOARDING PAGE BUILDER (Circular container as in screenshot)
  // ============================================================
  Widget _buildPage(Map<String, dynamic> page) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Circular container badge (matching user screenshot 2)
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: page['bgColor'],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              page['icon'],
              size: 70,
              color: page['iconColor'],
            ),
          ),
        ),
        const SizedBox(height: 32),
        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            page['title'],
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Text(
            page['subtitle'],
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'G Wash NG',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}