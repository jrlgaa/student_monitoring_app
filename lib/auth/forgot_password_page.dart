import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class ForgotPasswordPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const ForgotPasswordPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _emailStep = true; // true: email input, false: password reset
  int? _userId;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyEmail() async {
    String email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'user_data.db');
      final Database db = await openDatabase(path);

      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ? AND status = ?',
        whereArgs: [email, 'Active'],
      );

      if (results.isNotEmpty) {
        setState(() {
          _userId = results[0]['id'] as int;
          _emailStep = false;
        });
        _showSnackBar('Email verified. You can now reset your password.');
      } else {
        _showSnackBar('Invalid or unregistered email');
      }
    } catch (e) {
      _showSnackBar('Error checking email: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    String newPass = newPasswordController.text.trim();
    String confirmPass = confirmPasswordController.text.trim();

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showSnackBar('Please fill in both password fields');
      return;
    }

    if (newPass.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    if (newPass != confirmPass) {
      _showSnackBar('Passwords do not match');
      return;
    }

    if (_userId == null) {
      _showSnackBar('No user selected. Please verify email first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'user_data.db');
      final Database db = await openDatabase(path);

      final rowsAffected = await db.update(
        'users',
        {'password': newPass},
        where: 'id = ?',
        whereArgs: [_userId],
      );

      if (rowsAffected > 0) {
        _showSnackBar('Password updated successfully!');
        Navigator.pop(context); // Back to login
      } else {
        _showSnackBar('Failed to update password');
      }
    } catch (e) {
      _showSnackBar('Error updating password: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header image matching login
                Image.network(
                  'https://github.com/jrlgaa/LMS/blob/Source-Code/cropped_circle_image%20(1).png?raw=true',
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailStep ? 'Enter your email to verify' : 'Enter new password',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                // Email input (step 1 only)
                if (_emailStep) ...[
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'Email address',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Password inputs (step 2 only)
                if (!_emailStep) ...[
                  TextField(
                    controller: newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      hintText: 'New Password (min 6 chars)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                      ),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : (_emailStep ? _verifyEmail : _resetPassword),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_emailStep ? 'Verify Email' : 'Reset Password', style: const TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 24),
                // Back to login
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Back to Login',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: widget.isDarkMode ? Colors.grey[700] : Colors.grey[200],
        foregroundColor: widget.isDarkMode ? Colors.white : Colors.black,
        onPressed: widget.toggleTheme,
        child: Text(widget.isDarkMode ? '☀️' : '🌙'),
      ),
    );
  }
}
