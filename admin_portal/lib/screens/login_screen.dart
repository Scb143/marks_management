import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'forgot_password_screen.dart';
import '../widgets/watermark_scaffold.dart';
import 'admin_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  // College Brand Palette
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color darkNavy = Color(0xFF07193D);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final credentials = UserCredentials(
      userId: _idController.text,
      password: _passwordController.text,
    );

    final result = await _authService.login(credentials);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.isSuccess) {
      // Check if the user's role is admin
      if (result.role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminHomeScreen()),
        );
      } else {
        // Route for student, faculty, or other non-admin users
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome! Logged in as ${result.role ?? "user"}.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        // Example: Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const StudentHomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WatermarkScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isLandscape = constraints.maxWidth > 720;
              return ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isLandscape ? 880 : 420),
                child: Card(
                  elevation: 10,
                  shadowColor: primaryNavy.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isLandscape
                      ? IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _buildBrandingPanel(isMobile: false),
                              ),
                              Expanded(child: _buildFormPanel()),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildBrandingPanel(isMobile: true),
                            _buildFormPanel(),
                          ],
                        ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingPanel({required bool isMobile}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [darkNavy, primaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 24.0 : 36.0,
        horizontal: 20.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'assets/mitet_logo.png',
              width: isMobile ? 80 : 110,
              height: isMobile ? 80 : 110,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.school,
                size: isMobile ? 60 : 80,
                color: primaryNavy,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'MOTHER THERESA INSTITUTE OF\nENGINEERING & TECHNOLOGY',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'GROW RICH',
            style: TextStyle(
              color: accentGold,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          if (isMobile) const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Portal Login',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: primaryNavy,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter your credentials to access your dashboard',
              style: TextStyle(fontSize: 13, color: textMuted),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _idController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Roll Number / Staff ID',
                hintText: 'e.g. 21MT1A0501',
                prefixIcon: const Icon(Icons.person_outline, size: 20),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryNavy, width: 2),
                ),
              ),
              validator: (val) => (val == null || val.trim().isEmpty)
                  ? 'Please enter your ID'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: primaryNavy, width: 2),
                ),
              ),
              validator: (val) => (val == null || val.isEmpty)
                  ? 'Please enter your password'
                  : null,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        activeColor: primaryNavy,
                        onChanged: _isLoading
                            ? null
                            : (val) =>
                                  setState(() => _rememberMe = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Remember me',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: accentRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: primaryNavy.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
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
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
