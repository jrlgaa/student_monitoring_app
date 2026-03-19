import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p; // FIX: Added 'as p' to avoid Context conflicts

class LoginPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const LoginPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- SQLITE LOGIN LOGIC ---
  Future<void> login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }

    // 1. DIRECT ADMIN SIGN IN (Hardcoded)
    if (email == "admin123" && password == "123456") {
      Navigator.pushReplacementNamed(context, '/admin-dashboard');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Open the existing local database [cite: 1, 36]
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'application_data.db'); // FIX: Used p.join
      final Database db = await openDatabase(path);

      // 3. Query the 'users' table [cite: 36, 37]
      final List<Map<String, dynamic>> results = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (results.isNotEmpty) {
        // Retrieve role and convert to lowercase for comparison [cite: 37, 159]
        String role = results[0]['role'].toString().toLowerCase();

        if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, '/teacher-dashboard');
        } else if (role == 'guardian') {
          Navigator.pushReplacementNamed(context, '/guardian-dashboard');
        } else {
          _showSnackBar('Role "$role" not recognized.');
        }
      } else {
        _showSnackBar('Invalid email or password.');
      }
    } catch (e) {
      _showSnackBar('Database error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  } // Stray 'as BuildContext' removed here

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
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
                Image.network(
                  'https://github.com/jrlgaa/LMS/blob/Source-Code/cropped_circle_image%20(1).png?raw=true',
                  height: 100,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Student Monitoring Application',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Log in to your account',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : login,
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Sign in', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/signup'),
                      child: const Text(
                        'Sign up',
                        style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
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