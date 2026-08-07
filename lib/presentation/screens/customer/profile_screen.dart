// FILE: lib/presentation/screens/customer/profile_screen.dart
// PURPOSE: User profile management with Become a Washer option

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import '../../../services/cloudinary_service.dart';
import '../welcome_screen.dart';
import '../washer/washer_registration_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAndUploadProfileImage(BuildContext context, AuthService authService) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take a Photo'),
              onTap: () async {
                final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Uploading profile photo to Cloudinary...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final cloudinaryService = CloudinaryService();
      final photoUrl = await cloudinaryService.uploadImage(imageFile: image);

      if (photoUrl != null && photoUrl.isNotEmpty) {
        await authService.updateProfilePicture(photoUrl);
        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile photo updated successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Upload failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
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
                GestureDetector(
                  onTap: () => _pickAndUploadProfileImage(context, authService),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Stack(
                      children: [
                        ClipOval(
                          child: authService.photoURL != null && authService.photoURL!.isNotEmpty
                              ? Image.network(
                                  authService.photoURL!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.person, size: 50, color: Color(0xFF0CAF60)),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.person, size: 50, color: Color(0xFF0CAF60)),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(authService.userName ?? 'G-Wash User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(authService.userPhone ?? '', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showEditProfileDialog(context, authService),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit Profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          
          // My Account Section
          _buildSectionHeader('My Account'),
          _buildMenuItem(
            Icons.account_circle, 
            'My Profile', 
            'View and edit your profile details', 
            () => _showEditProfileDialog(context, authService)
          ),
          
          // Payments & Addresses
          _buildSectionHeader('Payments & Addresses'),
          _buildMenuItem(
            Icons.credit_card, 
            'Payment Methods', 
            'Add or remove payment methods', 
            () => Navigator.pushNamed(context, '/payment-methods')
          ),
          _buildMenuItem(
            Icons.location_on, 
            'Saved Addresses', 
            'Manage your delivery addresses', 
            () => Navigator.pushNamed(context, '/saved-addresses')
          ),
          
          // Security
          _buildSectionHeader('Security'),
          _buildMenuItem(
            Icons.security, 
            'Privacy & Security', 
            'Manage your privacy settings', 
            () => Navigator.pushNamed(context, '/privacy-security')
          ),
          _buildMenuItem(
            Icons.notifications, 
            'Notifications', 
            'Manage notification preferences', 
            () => Navigator.pushNamed(context, '/notifications')
          ),
          
          // Support
          _buildSectionHeader('Support'),
          _buildMenuItem(
            Icons.help, 
            'Help & Support', 
            'Get help or contact support', 
            () => Navigator.pushNamed(context, '/help-support')
          ),
          
          // Earnings
          _buildSectionHeader('Earnings'),
          _buildMenuItem(
            Icons.money, 
            'My Earnings', 
            'Track your earnings and withdrawals', 
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Earnings feature coming soon!')),
              );
            }
          ),
          
          const Divider(),
          
          // Become a Washer Button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0CAF60), Color(0xFF0A8E4F)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.emoji_transportation, color: Colors.white),
              title: const Text('Become a Washer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: const Text('Join our network of professional service providers and start earning', style: TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.arrow_forward, color: Colors.white),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WasherRegistrationScreen()),
                );
              },
            ),
          ),
          
          const Divider(),
          
          // Logout
          _buildMenuItem(
            Icons.logout, 
            'Logout', 
            'Sign out of your account', 
            () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true), 
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
                      child: const Text('Logout')
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await authService.logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context, 
                    MaterialPageRoute(builder: (context) => const WelcomeScreen()), 
                    (route) => false
                  );
                }
              }
            }, 
            isDestructive: true
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, AuthService authService) {
    final nameController = TextEditingController(text: authService.userName ?? '');
    final phoneController = TextEditingController(text: authService.userPhone ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              
              if (name.isNotEmpty || phone.isNotEmpty) {
                await authService.updateUserProfile(
                  name: name.isNotEmpty ? name : null,
                  phone: phone.isNotEmpty ? phone : null,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Profile updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title, 
        style: const TextStyle(
          fontSize: 16, 
          fontWeight: FontWeight.bold, 
          color: AppColors.primary
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon, 
    String title, 
    String subtitle, 
    VoidCallback onTap, {
    bool isDestructive = false
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppColors.primary),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red : Colors.black)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}