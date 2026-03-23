import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:project/database/admin_db.dart';

class SignUpPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const SignUpPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> with SingleTickerProviderStateMixin {
  String role = 'Guardian';
  final List<String> roles = ['Guardian', 'Teacher'];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Verification state
  bool _isSendingCode    = false;
  bool _codeSent         = false;
  bool _codeVerified     = false;
  int  _resendCountdown  = 0;

  // ── Server URL ── change to your server's IP when running on a real device
  // e.g. 'http://192.168.1.10:8080' if server and phone are on the same Wi-Fi
  static const String _serverUrl = 'http://10.30.97.249:8080';

  final TextEditingController firstNameController    = TextEditingController();
  final TextEditingController middleNameController   = TextEditingController();
  final TextEditingController lastNameController     = TextEditingController();
  final TextEditingController emailLocalController   = TextEditingController();
  final TextEditingController verificationController = TextEditingController();
  final TextEditingController passwordController     = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Design tokens ────────────────────────────────────────────────────────
  static const Color _primaryBlue  = Color(0xFF2563EB);
  static const Color _accentIndigo = Color(0xFF4F46E5);
  static const Color _dangerRed    = Color(0xFFDC2626);
  static const Color _successGreen = Color(0xFF059669);

  Color get _surfaceColor  => widget.isDarkMode ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC);
  Color get _cardColor     => widget.isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
  Color get _textPrimary   => widget.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _textSecondary => widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _dividerColor  => widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _fieldFill     => widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailLocalController.dispose();
    verificationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  final List<TextInputFormatter> _nameFormatter = [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
  ];

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon, String? suffixText, TextStyle? suffixStyle}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: suffixStyle,
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _dividerColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _dividerColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _label(String text, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(text, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          if (optional) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _dividerColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('optional', style: TextStyle(color: _textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  Future<void> _sendVerificationCode() async {
    final String localPart = emailLocalController.text.trim();
    if (localPart.isEmpty) {
      _showSnackBar('Please enter your email username first', isError: true);
      return;
    }
    final String domain = role == 'Teacher' ? '@deped.gov.ph' : '@gmail.com';
    final String email  = '$localPart$domain';

    setState(() => _isSendingCode = true);
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> result = jsonDecode(response.body);
      if (result['success'] == true) {
        setState(() {
          _codeSent      = true;
          _codeVerified  = false;
        });
        _startResendTimer();
        _showSnackBar('Code sent to $email', isError: false);
      } else {
        _showSnackBar(result['message'] ?? 'Failed to send code', isError: true);
      }
    } catch (e) {
      _showSnackBar('Cannot reach server. Check your connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _verifyCode() async {
    final String localPart = emailLocalController.text.trim();
    final String domain    = role == 'Teacher' ? '@deped.gov.ph' : '@gmail.com';
    final String email     = '$localPart$domain';
    final String code      = verificationController.text.trim();

    if (code.length != 6) {
      _showSnackBar('Please enter the 6-digit code', isError: true);
      return;
    }

    setState(() => _isSendingCode = true);
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> result = jsonDecode(response.body);
      if (result['success'] == true) {
        setState(() => _codeVerified = true);
        _showSnackBar('Email verified!', isError: false);
      } else {
        _showSnackBar(result['message'] ?? 'Incorrect code', isError: true);
      }
    } catch (e) {
      _showSnackBar('Cannot reach server. Check your connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  Future<void> _handleSignUp() async {
    final String localPart = emailLocalController.text.trim();
    final String domain = role == 'Teacher' ? '@deped.gov.ph' : '@gmail.com';
    final String email = localPart.isNotEmpty ? '$localPart$domain' : '';

    if (firstNameController.text.isEmpty || lastNameController.text.isEmpty || localPart.isEmpty || passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all required fields', isError: true);
      return;
    }
    if (!_codeVerified) {
      _showSnackBar('Please verify your email first', isError: true);
      return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }
    if (passwordController.text.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    try {
      await DatabaseHelper.instance.registerUser({
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': email,
        'role': role,
        'password': passwordController.text,
      });
      _showSnackBar('Account created successfully!', isError: false);
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.pushNamed(context, '/login');
      });
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        _showSnackBar('This email is already registered.', isError: true);
      } else {
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: isError ? _dangerRed : _successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Email suffix based on role
    final String emailSuffix = role == 'Teacher' ? '@deped.gov.ph' : '@gmail.com';
    final Color emailSuffixColor = role == 'Teacher' ? _primaryBlue : _successGreen;

    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _dividerColor),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Header
                  Text(
                    'Create Account',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in the details below to get started',
                    style: TextStyle(color: _textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 28),

                  // Role selector
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _dividerColor),
                    ),
                    child: Row(
                      children: roles.map((r) {
                        final bool selected = role == r;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => role = r),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? _primaryBlue : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: selected
                                    ? [BoxShadow(color: _primaryBlue.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 2))]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  r,
                                  style: TextStyle(
                                    color: selected ? Colors.white : _textSecondary,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _dividerColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name section header
                        Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.person_rounded, color: _primaryBlue, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text('Personal Info', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _label('First Name'),
                        TextField(
                          controller: firstNameController,
                          inputFormatters: _nameFormatter,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          decoration: _inputDecoration('e.g. Juan', Icons.person_outline_rounded),
                        ),
                        const SizedBox(height: 14),

                        _label('Middle Name', optional: true),
                        TextField(
                          controller: middleNameController,
                          inputFormatters: _nameFormatter,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          decoration: _inputDecoration('e.g. Santos', Icons.person_search_outlined),
                        ),
                        const SizedBox(height: 14),

                        _label('Last Name'),
                        TextField(
                          controller: lastNameController,
                          inputFormatters: _nameFormatter,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          decoration: _inputDecoration('e.g. Dela Cruz', Icons.person_outline_rounded),
                        ),

                        const SizedBox(height: 20),
                        Divider(color: _dividerColor, height: 1),
                        const SizedBox(height: 20),

                        // Account section
                        Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(color: _accentIndigo.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Icon(Icons.manage_accounts_rounded, color: _accentIndigo, size: 14),
                            ),
                            const SizedBox(width: 8),
                            Text('Account Details', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _label('Email Address'),
                        TextField(
                          controller: emailLocalController,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          keyboardType: TextInputType.emailAddress,
                          // Block @ and spaces — domain is appended automatically
                          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[@\s]'))],
                          decoration: _inputDecoration(
                            'username',
                            Icons.email_outlined,
                            suffixText: emailSuffix,
                            suffixStyle: TextStyle(color: emailSuffixColor, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Verification code row
                        _label('Verification Code'),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: verificationController,
                                style: TextStyle(color: _textPrimary, fontSize: 14),
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                enabled: _codeSent && !_codeVerified,
                                decoration: _inputDecoration(
                                  'Enter 6-digit code',
                                  Icons.verified_user_outlined,
                                  suffixIcon: _codeVerified
                                      ? Icon(Icons.check_circle_rounded, color: _successGreen, size: 20)
                                      : null,
                                ).copyWith(counterText: ''),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Send / Resend button
                            if (!_codeSent || _resendCountdown == 0)
                              GestureDetector(
                                onTap: _isSendingCode ? null : _sendVerificationCode,
                                child: Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: _primaryBlue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _primaryBlue.withOpacity(0.3)),
                                  ),
                                  child: Center(
                                    child: _isSendingCode
                                        ? SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: _primaryBlue),
                                    )
                                        : Text(
                                      _codeSent ? 'Resend' : 'Get Code',
                                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                ),
                              )
                            else
                              Container(
                                height: 52,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: _dividerColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    '${_resendCountdown}s',
                                    style: TextStyle(color: _textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Verify button — shown after code is sent and not yet verified
                        if (_codeSent && !_codeVerified) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: _isSendingCode ? null : _verifyCode,
                            child: Container(
                              width: double.infinity,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _successGreen.withOpacity(0.3)),
                              ),
                              child: Center(
                                child: _isSendingCode
                                    ? SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: _successGreen),
                                )
                                    : Text(
                                  'Verify Code',
                                  style: TextStyle(color: _successGreen, fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Verified badge
                        if (_codeVerified) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _successGreen.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _successGreen.withOpacity(0.25)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: _successGreen, size: 16),
                                const SizedBox(width: 6),
                                Text('Email verified', style: TextStyle(color: _successGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        _label('Password'),
                        TextField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            'Min. 6 characters',
                            Icons.lock_outline_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _textSecondary, size: 20),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        _label('Confirm Password'),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          style: TextStyle(color: _textPrimary, fontSize: 14),
                          decoration: _inputDecoration(
                            'Re-enter your password',
                            Icons.lock_rounded,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: _textSecondary, size: 20),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Submit button
                        GestureDetector(
                          onTap: _handleSignUp,
                          child: Container(
                            width: double.infinity,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_primaryBlue, _accentIndigo],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryBlue.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'Create Account',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Already have an account? ', style: TextStyle(color: _textSecondary, fontSize: 14)),
                          Text('Sign in', style: TextStyle(color: _primaryBlue, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: _cardColor,
        foregroundColor: _textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _dividerColor),
        ),
        onPressed: widget.toggleTheme,
        child: Icon(widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
      ),
    );
  }
}