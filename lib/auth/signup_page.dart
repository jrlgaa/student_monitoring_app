import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// IMPORTANT: Pointing to your specific database file
import 'package:project/database/signup_db.dart';

class SignUpPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const SignUpPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String role = 'Guardian';
  final List<String> roles = ['Guardian', 'Teacher'];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController middleNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController verificationController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    firstNameController.dispose();
    middleNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    verificationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint,
      IconData icon, {
        List<TextInputFormatter>? inputFormatters,
      }) {
    return TextFormField(
      controller: controller,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    String email = emailController.text.trim();

    // 1. Basic Validation
    if (firstNameController.text.isEmpty ||
        lastNameController.text.isEmpty ||
        email.isEmpty ||
        passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      return;
    }

    if (role == 'Teacher' && !email.endsWith('@deped.gov.ph')) {
      _showSnackBar('Teachers must use a @deped.gov.ph email address');
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar('Passwords do not match');
      return;
    }

    // 2. Database Action
    try {
      // Map keys MUST match the CREATE TABLE columns in signup_db.dart
      Map<String, dynamic> userRow = {
        'firstName': firstNameController.text.trim(),
        'middleName': middleNameController.text.trim(), // Now supported by DB
        'lastName': lastNameController.text.trim(),
        'email': email,
        'role': role,
        'password': passwordController.text,
      };

      await DatabaseHelper.instance.registerUser(userRow);
      _showSnackBar('Account registered successfully!', isError: false);

      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pushNamed(context, '/login');
      });

    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        _showSnackBar('This email is already in use.');
      } else {
        _showSnackBar('Error saving to database: $e');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
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
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Create an Account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                _buildTextField(firstNameController, 'First Name', Icons.person_outline,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))]),
                const SizedBox(height: 16),
                _buildTextField(middleNameController, 'Middle Name (Optional)', Icons.person_search_outlined),
                const SizedBox(height: 16),
                _buildTextField(lastNameController, 'Last Name', Icons.person_outline,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))]),
                const SizedBox(height: 16),
                _buildTextField(emailController, 'Enter email address', Icons.email_outlined),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(flex: 2, child: _buildTextField(verificationController, 'Code', Icons.verified_user_outlined)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showSnackBar('Code sent!', isError: false),
                        child: const Text('Get code', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (value) => setState(() => role = value!),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.assignment_ind_outlined),
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                // Using TextField here for obscureText capability
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(onPressed: _handleSignUp, child: const Text('Create Account')),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('Already have an account? Log in',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}