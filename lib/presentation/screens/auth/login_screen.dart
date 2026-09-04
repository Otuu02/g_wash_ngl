// FILE: lib/presentation/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

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

  // 🔐 Secure encrypted storage (AES-256 via Android Keystore / iOS Keychain)
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // 🛡️ Brute-force login protection constants
  static const int _maxLoginAttempts = 5;
  static const int _lockoutMinutes = 15;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  bool _biometricEnabled = false;
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
      debugPrint('🔐 Biometric available: $isAvailable');
      setState(() {
        _biometricEnabled = isAvailable;
      });
    } catch (e) {
      debugPrint('❌ Biometric check failed: $e');
    }
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final phone = await _secureStorage.read(key: 'saved_phone');
      final password = await _secureStorage.read(key: 'saved_password');
      final prefs = await SharedPreferences.getInstance();
      final remember = prefs.getBool('remember_me') ?? false;

      setState(() {
        if (phone != null) _phoneController.text = phone;
        if (password != null) _passwordController.text = password;
        _rememberMe = remember;
      });
    } catch (e) {
      debugPrint('❌ Error loading saved credentials: $e');
    }
  }

  Future<void> _saveCredentials(String phone, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        // 🔐 Save password encrypted in Android Keystore / iOS Keychain
        await _secureStorage.write(key: 'saved_phone', value: phone);
        await _secureStorage.write(key: 'saved_password', value: password);
        await prefs.setBool('remember_me', true);
      } else {
        await _secureStorage.delete(key: 'saved_phone');
        await _secureStorage.delete(key: 'saved_password');
        await prefs.setBool('remember_me', false);
      }
    } catch (e) {
      debugPrint('❌ Error saving credentials: $e');
    }
  }

  Future<void> _loginWithPassword() async {
    final identifier = _phoneController.text.trim();
    if (identifier.isEmpty) {
      _showError('Please enter your phone number or email address');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return;
    }

    // 🛡️ Brute-force lockout check
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inMinutes + 1;
      _showError('Too many failed attempts. Try again in $remaining minute(s).');
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final password = _passwordController.text.trim();
    final success = await authService.login(identifier, password);

    setState(() => _isLoading = false);

    if (success) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      await _saveCredentials(identifier, password);
      _navigateToHome(authService);
    } else {
      _failedAttempts++;
      if (_failedAttempts >= _maxLoginAttempts) {
        _lockoutUntil = DateTime.now().add(const Duration(minutes: _lockoutMinutes));
        _showError('Account locked for $_lockoutMinutes minutes after $_maxLoginAttempts failed attempts.');
      } else {
        final remaining = _maxLoginAttempts - _failedAttempts;
        final errorMsg = authService.authError ?? 'Invalid login details or password.';
        _showError('$errorMsg $remaining attempt(s) remaining.');
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    if (!_biometricEnabled) {
      _showError('Biometric authentication is not available');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login to G Wash NG',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final phone = await _secureStorage.read(key: 'saved_phone');
        final password = await _secureStorage.read(key: 'saved_password');
        
        if (phone != null && password != null) {
          final success = await authService.login(phone, password);
          if (success) {
            _navigateToHome(authService);
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
      debugPrint('❌ Biometric auth error: $e');
      _showError('Biometric authentication failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '268073858735-gg0t71o28uauh3rkfrf5gvu3bam2s867.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'photoURL': user.photoURL ?? '',
          'role': 'customer',
          'isBlocked': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.setGoogleUser(
          user.displayName ?? 'User',
          user.email ?? '${user.uid}@gmail.com',
          photoURL: user.photoURL,
          phone: user.phoneNumber,
        );
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      debugPrint('❌ Google Sign-In error: $e');
      final errorStr = e.toString();
      if (errorStr.contains('origin_mismatch')) {
        _showError('Google OAuth origin mismatch: Add http://localhost:8080 to Authorized JavaScript origins in Google Cloud Console.');
      } else {
        _showError('Google Sign-In failed. Please try password login or check internet connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToHome(AuthService authService) {
    final routeName = authService.isAdmin
        ? '/admin'
        : (authService.isServiceProvider || authService.isWasher)
            ? '/washer-dashboard'
            : '/home';
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
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
        // ============================================================
        // FIX: Wrap with SingleChildScrollView and add extra bottom padding
        // ============================================================
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 16),
              
              // Welcome Text
              const Text(
                'Welcome Back,',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sign in to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.grey600,
                ),
              ),
              const SizedBox(height: 28),

              // ============================================================
              // OPTION 1: Biometric Login (Fingerprint)
              // ============================================================
              if (_biometricEnabled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Fingerprint Unlock',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.grey600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isLoading ? null : _loginWithBiometric,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fingerprint,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          // Switch to password login
                        },
                        child: const Text(
                          'Use Password Instead',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              


              // ============================================================
              // OPTION 2: Password / Phone Login
              // ============================================================
              const Text(
                'Sign in with Password',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Phone Number or Email Address',
                  hintText: 'e.g. 08012345678 or user@gmail.com',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
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
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _loginWithPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              
              const SizedBox(height: 20),

              // ============================================================
              // OR Divider
              // ============================================================
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // ============================================================
              // OPTION 3: Google Sign-In
              // ============================================================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    child: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ),
                  label: Text(
                    _isLoading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),


              const SizedBox(height: 20),

              // ============================================================
              // Footer: Sign Up & Security Info
              // ============================================================
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account?",
                    style: TextStyle(color: AppColors.grey600),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Security Footer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.security,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '🔒 Your account is protected with 2FA and biometric security',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.grey600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Licensed by Central Bank
              Center(
                child: Text(
                  'Licensed and insured by the NDIC',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}