// FILE: lib/presentation/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import 'signup_screen.dart';
import '../customer/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricEnabled = false;
  bool _twoFAEnabled = false;
  bool _rememberMe = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _loadSavedCredentials();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      setState(() {
        _biometricEnabled = isAvailable;
      });
    } catch (e) {
      print('Biometric check failed: $e');
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString('saved_phone');
      final password = prefs.getString('saved_password');
      final remember = prefs.getBool('remember_me') ?? false;

      setState(() {
        if (phone != null) _phoneController.text = phone;
        if (password != null) _passwordController.text = password;
        _rememberMe = remember;
      });

      // If biometric is enabled and credentials exist, auto-login with biometric
      if (_biometricEnabled && phone != null && password != null) {
        final authService = Provider.of<AuthService>(context, listen: false);
        // Auto login with saved credentials
        final success = await authService.login(phone, password);
        if (success) {
          if (mounted) {
            final routeName = authService.isAdmin
                ? '/admin'
                : (authService.isServiceProvider || authService.isWasher)
                    ? '/washer-dashboard'
                    : '/home';
            Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
          }
        }
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials(String phone, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('saved_phone', phone);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_me', true);
      } else {
        await prefs.remove('saved_phone');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      print('Error saving credentials: $e');
    }
  }

  Future<void> _login() async {
    if (_phoneController.text.isEmpty) {
      _showError('Please enter your phone number');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final success = await authService.login(phone, password);

    setState(() => _isLoading = false);

    if (success) {
      // Save credentials if remember me is checked
      await _saveCredentials(phone, password);
      
      final routeName = authService.isAdmin
          ? '/admin'
          : (authService.isServiceProvider || authService.isWasher)
              ? '/washer-dashboard'
              : '/home';
      Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
    } else {
      _showError('Invalid phone number or password. Use 123456 as password.');
    }
  }

  Future<void> _biometricLogin() async {
    if (!_biometricEnabled) {
      _showError('Biometric authentication is not available on this device');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login to G Wash NG',
        options: AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Load saved credentials
        final prefs = await SharedPreferences.getInstance();
        final phone = prefs.getString('saved_phone');
        final password = prefs.getString('saved_password');
        
        if (phone != null && password != null) {
          final success = await authService.login(phone, password);
          if (success) {
            if (mounted) {
              final routeName = authService.isAdmin
                  ? '/admin'
                  : (authService.isServiceProvider || authService.isWasher)
                      ? '/washer-dashboard'
                      : '/home';
              Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
            }
          } else {
            _showError('Biometric login failed. Please login with password.');
          }
        } else {
          _showError('Please login with password first to enable biometric login');
        }
      } else {
        _showError('Biometric authentication failed');
      }
    } catch (e) {
      print('Biometric auth error: $e');
      _showError('Biometric authentication failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome Back! 😊',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to continue',
                style: TextStyle(fontSize: 16, color: AppColors.grey600),
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixText: '+234 ',
                  prefixIcon: Icon(Icons.phone_android),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Remember Me
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() => _rememberMe = value ?? false);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const Text('Remember Me', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                  if (_biometricEnabled)
                    TextButton.icon(
                      onPressed: _isLoading ? null : _biometricLogin,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Biometric Login'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      _showError('Contact support to reset password: 07065584504');
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                  Row(
                    children: [
                      Switch(
                        value: _twoFAEnabled,
                        onChanged: (value) {
                          setState(() => _twoFAEnabled = value);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const Text(
                        'Enable 2FA',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0CAF60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
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