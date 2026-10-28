import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/watermark_scaffold.dart';

class FacultyForgotPasswordScreen extends StatefulWidget {
  const FacultyForgotPasswordScreen({super.key});

  @override
  State<FacultyForgotPasswordScreen> createState() =>
      _FacultyForgotPasswordScreenState();
}

class _FacultyForgotPasswordScreenState
    extends State<FacultyForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = FacultyAuthService();

  int _currentStep = 1; // 1: Email, 2: OTP, 3: Set Password
  bool _isLoading = false;
  bool _obscurePassword = true;

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? accentRed : Colors.green.shade700,
      ),
    );
  }

  // Step 1: Send OTP to Email
  Future<void> _handleSendOtp() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final res = await _authService.sendPasswordResetOtp(_emailController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      _showMessage(res.message);
      setState(() => _currentStep = 2);
    } else {
      _showMessage(res.message, isError: true);
    }
  }

  // Step 2: Verify OTP
  Future<void> _handleVerifyOtp() async {
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final res = await _authService.verifyOtp(
      _emailController.text,
      _otpController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      _showMessage(res.message);
      setState(() => _currentStep = 3);
    } else {
      _showMessage(res.message, isError: true);
    }
  }

  // Step 3: Set New Password
  Future<void> _handleResetPassword() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final res = await _authService.updatePassword(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.isSuccess) {
      _showMessage(res.message);
      Navigator.pop(context); // Return to login page
    } else {
      _showMessage(res.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WatermarkScaffold(
      
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 10,
              shadowColor: primaryNavy.withOpacity(0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 32.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryNavy.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _currentStep == 1
                            ? Icons.mark_email_read_outlined
                            : _currentStep == 2
                                ? Icons.pin_outlined
                                : Icons.lock_reset_outlined,
                        size: 40,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentStep == 1
                          ? 'Reset Faculty Password'
                          : _currentStep == 2
                              ? 'Enter Verification Code'
                              : 'Set New Password',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentStep == 1
                          ? 'Enter your registered email to receive a password reset OTP'
                          : 'Enter the verification code sent to ${_emailController.text}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Step 1: Email Form
                    if (_currentStep == 1) ...[
                      Form(
                        key: _emailFormKey,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Faculty Email',
                            hintText: 'name@mtiet.edu.in',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your registered email';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildButton('Send OTP Code', _handleSendOtp),
                    ],

                    // Step 2: OTP Verification Form
                    if (_currentStep == 2) ...[
                      Form(
                        key: _otpFormKey,
                        child: TextFormField(
                          controller: _otpController,
                          keyboardType: TextInputType.text,
                          maxLength: 8,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            letterSpacing: 6,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            counterText: "",
                            hintText: '--------',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (val) =>
                              (val == null || val.trim().length < 6)
                                  ? 'Enter the full verification code'
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _currentStep = 1),
                            child: const Text(
                              'Change Email',
                              style: TextStyle(color: textMuted),
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading ? null : _handleSendOtp,
                            child: const Text(
                              'Resend Code',
                              style: TextStyle(
                                color: accentRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildButton('Verify Code', _handleVerifyOtp),
                    ],

                    // Step 3: New Password Form
                    if (_currentStep == 3) ...[
                      Form(
                        key: _resetFormKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (val) => (val == null || val.length < 6)
                                  ? 'Password must be at least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              validator: (val) {
                                if (val != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildButton('Update Password', _handleResetPassword),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}