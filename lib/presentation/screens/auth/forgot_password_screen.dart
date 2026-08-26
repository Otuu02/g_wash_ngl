// FILE: lib/presentation/screens/auth/forgot_password_screen.dart
// PURPOSE: Complete 3-step Forgot Password workflow (Email/Phone OTP -> Verify -> Reset Password)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step tracking: 1 = Enter Identifier, 2 = Verify OTP, 3 = Reset Password
  int _currentStep = 1;
  bool _isLoading = false;

  // Controllers
  final TextEditingController _identifierController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // Resend Timer
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  // Account details loaded from request
  String _targetEmail = '';
  String _targetPhone = '';
  String _targetName = '';
  String? _demoOtpHint;

  @override
  void dispose() {
    _identifierController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ============================================================
  // STEP 1: REQUEST OTP
  // ============================================================
  Future<void> _handleRequestOtp() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) {
      _showError('Please enter your registered email address or phone number.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.requestPasswordReset(identifier);

      if (result['success'] == true) {
        setState(() {
          _targetEmail = result['targetEmail'] ?? '';
          _targetPhone = result['targetPhone'] ?? '';
          _targetName = result['targetName'] ?? 'User';
          _demoOtpHint = result['otpCode'];
          _currentStep = 2;
        });

        _startResendTimer();
        _showSuccess(result['message'] ?? 'Verification code sent successfully!');
      } else {
        _showError(result['error'] ?? 'Failed to request password reset.');
      }
    } catch (e) {
      _showError('An error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // STEP 2: VERIFY OTP
  // ============================================================
  Future<void> _handleVerifyOtp() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showError('Please enter the 6-digit verification code sent to your email/phone.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final identifier = _identifierController.text.trim();
      final result = await authService.verifyPasswordResetOtp(identifier: identifier, otp: otp);

      if (result['success'] == true) {
        setState(() {
          _currentStep = 3;
        });
        _showSuccess('Code verified! Set your new password below.');
      } else {
        _showError(result['error'] ?? 'Invalid or expired verification code.');
      }
    } catch (e) {
      _showError('Verification error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // STEP 3: RESET PASSWORD
  // ============================================================
  Future<void> _handleResetPassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (newPass.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match. Please check and try again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final identifier = _identifierController.text.trim();
      final otp = _otpControllers.map((c) => c.text).join();

      final result = await authService.resetUserPassword(
        identifier: identifier,
        otp: otp,
        newPassword: newPass,
      );

      if (result['success'] == true) {
        _showSuccessDialog();
      } else {
        _showError(result['error'] ?? 'Failed to reset password.');
      }
    } catch (e) {
      _showError('Error resetting password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF0CAF60), size: 28),
            SizedBox(width: 10),
            Text('Password Reset!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Your password has been updated successfully. You can now sign in using your new password.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to Login
            },
            child: const Text('Back to Sign In', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onOtpDigitChanged(String val, int index) {
    if (val.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (val.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }

    final fullOtp = _otpControllers.map((c) => c.text).join();
    if (fullOtp.length == 6 && !_isLoading) {
      _handleVerifyOtp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🚦 Progress Bar Steps Indicator
              Row(
                children: [
                  _buildStepDot(1, 'Identify'),
                  _buildStepLine(_currentStep >= 2),
                  _buildStepDot(2, 'Verify OTP'),
                  _buildStepLine(_currentStep >= 3),
                  _buildStepDot(3, 'New Password'),
                ],
              ),

              const SizedBox(height: 32),

              // Step View Selector
              if (_currentStep == 1) _buildStep1IdentifierInput(),
              if (_currentStep == 2) _buildStep2OtpVerification(),
              if (_currentStep == 3) _buildStep3NewPasswordInput(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primary : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.primary : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        color: isActive ? AppColors.primary : Colors.grey.shade200,
      ),
    );
  }

  // ============================================================
  // STEP 1 UI: INPUT EMAIL OR PHONE
  // ============================================================
  Widget _buildStep1IdentifierInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              size: 60,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Forgot Your Password?',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter your registered email address or phone number. We will send you a 6-digit OTP code to verify your identity.',
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),
        const SizedBox(height: 24),

        TextField(
          controller: _identifierController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Email Address or Phone Number',
            hintText: 'e.g. user@gmail.com or +2347065584504',
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRequestOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Send OTP Verification Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 2 UI: VERIFY OTP CODE
  // ============================================================
  Widget _buildStep2OtpVerification() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Enter Verification Code',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a 6-digit code to ${_targetEmail.isNotEmpty ? _targetEmail : _targetPhone}. Enter it below:',
          style: const TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),

        // 🔒 SECURITY: OTP hint only shown in debug/development builds, never in production
        if (kDebugMode && _demoOtpHint != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[DEBUG ONLY] OTP: $_demoOtpHint (sent via Email & SMS)',
                    style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 28),

        // 6 Digit OTP Fields
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            6,
            (index) => SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _otpControllers[index],
                focusNode: _otpFocusNodes[index],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                enabled: !_isLoading,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
                onChanged: (val) => _onOtpDigitChanged(val, index),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Didn\'t receive code? ', style: TextStyle(color: Colors.grey)),
            TextButton(
              onPressed: _canResend && !_isLoading ? _handleRequestOtp : null,
              child: Text(
                _canResend ? 'Resend Code' : 'Resend in ${_secondsRemaining}s',
                style: TextStyle(
                  color: _canResend ? AppColors.primary : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleVerifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Verify Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STEP 3 UI: SET NEW PASSWORD
  // ============================================================
  Widget _buildStep3NewPasswordInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_clock_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Create New Password',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your new password must be at least 6 characters long.',
          style: TextStyle(fontSize: 14, color: AppColors.grey600, height: 1.5),
        ),

        const SizedBox(height: 24),

        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleResetPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
