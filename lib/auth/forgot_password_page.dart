import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class ForgotPasswordPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ForgotPasswordPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController        = TextEditingController();
  final TextEditingController codeController         = TextEditingController();
  final TextEditingController newPasswordController  = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // 0 = email step, 1 = code verification step, 2 = reset password step
  int _step = 0;
  int? _userId;

  bool _isLoading       = false;
  bool _isSendingCode   = false;
  bool _codeVerified    = false;
  int  _resendCountdown = 0;

  bool _obscureNewPassword     = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  // ── Same server URL as signup_page ───────────────────────────────────────
  static const String _serverUrl = 'http://192.168.1.35:8080';

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
    emailController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── STEP 1: verify email exists in DB ────────────────────────────────────
  Future<void> _verifyEmail() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final path   = p.join(dbPath, 'user_data.db');
      final db     = await openDatabase(path);
      final results = await db.query('users',
          where: 'email = ? AND status = ?', whereArgs: [email, 'Active']);

      if (results.isNotEmpty) {
        setState(() {
          _userId = results[0]['id'] as int;
        });
        // Auto-send code after email is found
        await _sendVerificationCode();
        setState(() => _step = 1);
        _animController.forward(from: 0.0);
      } else {
        _showSnackBar('Email not found or account inactive', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── STEP 2a: send code via email server ───────────────────────────────────
  Future<void> _sendVerificationCode() async {
    final email = emailController.text.trim();
    setState(() => _isSendingCode = true);
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/send-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
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

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  // ── STEP 2b: verify code ─────────────────────────────────────────────────
  Future<void> _verifyCode() async {
    final email = emailController.text.trim();
    final code  = codeController.text.trim();

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

      final result = jsonDecode(response.body);
      if (result['success'] == true) {
        setState(() {
          _codeVerified = true;
          _step = 2;
        });
        _animController.forward(from: 0.0);
        _showSnackBar('Code verified! Set your new password.', isError: false);
      } else {
        _showSnackBar(result['message'] ?? 'Incorrect code', isError: true);
      }
    } catch (e) {
      _showSnackBar('Cannot reach server. Check your connection.', isError: true);
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  // ── STEP 3: reset password ───────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPass     = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar('Please fill in both password fields', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showSnackBar('Passwords do not match', isError: true);
      return;
    }
    if (_userId == null) {
      _showSnackBar('Session expired. Please start again.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final path   = p.join(dbPath, 'user_data.db');
      final db     = await openDatabase(path);
      final rows   = await db.update(
          'users', {'password': newPass}, where: 'id = ?', whereArgs: [_userId]);

      if (rows > 0) {
        _showSnackBar('Password updated successfully!', isError: false);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar('Failed to update password', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
        ]),
        backgroundColor: isError ? _dangerRed : _successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: _textSecondary, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFill,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _dividerColor)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _dividerColor)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _stepTitle {
    if (_step == 0) return 'Forgot Password';
    if (_step == 1) return 'Verify Your Email';
    return 'Set New Password';
  }

  String get _stepSubtitle {
    if (_step == 0) return 'Enter your registered email to continue';
    if (_step == 1) return 'Enter the 6-digit code sent to your email';
    return 'Choose a strong password (min. 6 characters)';
  }

  IconData get _stepIcon {
    if (_step == 0) return Icons.lock_reset_rounded;
    if (_step == 1) return Icons.mark_email_read_rounded;
    return Icons.lock_open_rounded;
  }

  Color get _stepColor {
    if (_step == 0) return _primaryBlue;
    if (_step == 1) return _accentIndigo;
    return _successGreen;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: SafeArea(
        child: Center(
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
                      onTap: () {
                        if (_step == 0) {
                          Navigator.pop(context);
                        } else {
                          setState(() {
                            _step--;
                            if (_step == 0) { _codeVerified = false; codeController.clear(); }
                          });
                          _animController.forward(from: 0.0);
                        }
                      },
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _dividerColor),
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: _textPrimary, size: 18),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Header
                    Center(
                      child: Column(children: [
                        Container(
                          width: 64, height: 64,
                          decoration: BoxDecoration(
                            color: _stepColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(_stepIcon, color: _stepColor, size: 30),
                        ),
                        const SizedBox(height: 16),
                        Text(_stepTitle,
                            style: TextStyle(color: _textPrimary, fontSize: 24,
                                fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Text(_stepSubtitle,
                            style: TextStyle(color: _textSecondary, fontSize: 13),
                            textAlign: TextAlign.center),
                      ]),
                    ),

                    const SizedBox(height: 28),

                    // Step progress bar (3 steps)
                    Row(children: [
                      Expanded(child: Container(height: 4,
                          decoration: BoxDecoration(color: _primaryBlue, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4,
                          decoration: BoxDecoration(
                              color: _step >= 1 ? _accentIndigo : _dividerColor,
                              borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(width: 6),
                      Expanded(child: Container(height: 4,
                          decoration: BoxDecoration(
                              color: _step >= 2 ? _successGreen : _dividerColor,
                              borderRadius: BorderRadius.circular(2)))),
                    ]),
                    const SizedBox(height: 24),

                    // Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _dividerColor),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(widget.isDarkMode ? 0.3 : 0.06),
                            blurRadius: 24, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── STEP 0: Email ────────────────────────────────
                          if (_step == 0) ...[
                            Text('Email Address',
                                style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              style: TextStyle(color: _textPrimary, fontSize: 14),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _inputDecoration('Enter your email', Icons.email_outlined),
                            ),
                            const SizedBox(height: 24),
                            _actionButton(
                              label: 'Continue',
                              isLoading: _isLoading,
                              color: _primaryBlue,
                              secondColor: _accentIndigo,
                              onTap: _verifyEmail,
                            ),
                          ],

                          // ── STEP 1: Code verification ────────────────────
                          if (_step == 1) ...[
                            Text('Verification Code',
                                style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: codeController,
                                  style: TextStyle(color: _textPrimary, fontSize: 14),
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  enabled: !_codeVerified,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  decoration: _inputDecoration('6-digit code', Icons.verified_user_outlined,
                                    suffixIcon: _codeVerified
                                        ? Icon(Icons.check_circle_rounded, color: _successGreen, size: 20)
                                        : null,
                                  ).copyWith(counterText: ''),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Resend / countdown button
                              if (_resendCountdown > 0)
                                Container(
                                  height: 52,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                      color: _dividerColor, borderRadius: BorderRadius.circular(14)),
                                  child: Center(child: Text('${_resendCountdown}s',
                                      style: TextStyle(color: _textSecondary,
                                          fontWeight: FontWeight.w600, fontSize: 13))),
                                )
                              else
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
                                          ? SizedBox(width: 18, height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: _primaryBlue))
                                          : Text('Resend',
                                          style: TextStyle(color: _primaryBlue,
                                              fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                  ),
                                ),
                            ]),
                            const SizedBox(height: 16),
                            // Verify code button
                            _actionButton(
                              label: 'Verify Code',
                              isLoading: _isSendingCode,
                              color: _accentIndigo,
                              secondColor: _primaryBlue,
                              onTap: _verifyCode,
                            ),
                          ],

                          // ── STEP 2: New password ─────────────────────────
                          if (_step == 2) ...[
                            Text('New Password',
                                style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: newPasswordController,
                              obscureText: _obscureNewPassword,
                              style: TextStyle(color: _textPrimary, fontSize: 14),
                              decoration: _inputDecoration('New password (min. 6 chars)',
                                  Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscureNewPassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: _textSecondary, size: 20),
                                    onPressed: () => setState(
                                            () => _obscureNewPassword = !_obscureNewPassword),
                                  )),
                            ),
                            const SizedBox(height: 16),
                            Text('Confirm Password',
                                style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              style: TextStyle(color: _textPrimary, fontSize: 14),
                              decoration: _inputDecoration('Confirm your new password',
                                  Icons.lock_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: _textSecondary, size: 20),
                                    onPressed: () => setState(
                                            () => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  )),
                            ),
                            const SizedBox(height: 24),
                            _actionButton(
                              label: 'Reset Password',
                              isLoading: _isLoading,
                              color: _successGreen,
                              secondColor: const Color(0xFF047857),
                              onTap: _resetPassword,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
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
            borderRadius: BorderRadius.circular(12), side: BorderSide(color: _dividerColor)),
        onPressed: widget.toggleTheme,
        child: Icon(
            widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded, size: 18),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool isLoading,
    required Color color,
    required Color secondColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, secondColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}