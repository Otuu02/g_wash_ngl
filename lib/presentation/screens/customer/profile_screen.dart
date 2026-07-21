// FILE: lib/presentation/screens/customer/profile_screen.dart
// PURPOSE: User profile management with Become a Washer option

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../welcome_screen.dart';
import '../washer/washer_registration_screen.dart';  // ← CHANGED: Use registration screen

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.green.shade50,
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: const Center(child: Icon(Icons.person, size: 50, color: Color(0xFF0CAF60))),
                ),
                const SizedBox(height: 16),
                Text(authService.userName ?? 'G-Wash User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(authService.userPhone ?? '', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ),
          
          // Account Section
          _buildSectionHeader('Account'),
          _buildMenuItem(Icons.credit_card, 'Payment Methods', 'Add or remove payment methods', () => Navigator.pushNamed(context, '/payment-methods')),
          _buildMenuItem(Icons.location_on, 'Saved Addresses', 'Manage your delivery addresses', () => Navigator.pushNamed(context, '/saved-addresses')),
          _buildMenuItem(Icons.notifications, 'Notifications', 'Manage notification preferences', () => Navigator.pushNamed(context, '/notifications')),
          
          // Security Section
          _buildSectionHeader('Security'),
          _buildMenuItem(Icons.security, 'Privacy & Security', 'Manage your privacy settings', () => Navigator.pushNamed(context, '/privacy-security')),
          
          // Support Section
          _buildSectionHeader('Support'),
          _buildMenuItem(Icons.help, 'Help & Support', 'Get help or contact support', () => Navigator.pushNamed(context, '/help-support')),
          
          // Earnings Section
          _buildSectionHeader('Earnings'),
          _buildMenuItem(Icons.money, 'My Earnings', 'Track your earnings and withdrawals', () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Earnings feature coming soon!')),
            );
          }),
          
          const Divider(),
          
          // Become a Washer Button (Uber-style) - FIXED
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0CAF60), Color(0xFF0A8E4F)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.emoji_transportation, color: Colors.white),
              title: const Text('Become a Washer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Start earning by washing cars', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward, color: Colors.white),
              onTap: () {
                // FIXED: Navigate to Registration Screen, not directly to Dashboard
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WasherRegistrationScreen()),
                );
              },
            ),
          ),
          
          const Divider(),
          
          // Logout
          _buildMenuItem(Icons.logout, 'Logout', 'Sign out of your account', () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Logout'),
                content: const Text('Are you sure you want to logout?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Logout')),
                ],
              ),
            );
            if (confirm == true && context.mounted) {
              await authService.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
              }
            }
          }, isDestructive: true),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}