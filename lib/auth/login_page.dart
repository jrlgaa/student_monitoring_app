import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const LoginPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Controllers and State variables
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _obscurePassword = true; // State to track if password is hidden

  // Dummy Accounts
  static const String adminEmail = "admin123";
  static const String teacherEmail = 'teacher@example.com';
  static const String guardianEmail = 'guardian@example.com';
  static const String commonPassword = '123456';

  void login() {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    if (password == commonPassword) {
      if (email == teacherEmail) {
        Navigator.pushReplacementNamed(context, '/teacher-dashboard');
      } else if (email == guardianEmail) {
        Navigator.pushReplacementNamed(context, '/guardian-dashboard');
      } else if (email == adminEmail) {
        Navigator.pushReplacementNamed(context, '/admin-dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid email or password!')),
      );
    }
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),
                Text(
                  'Log in to your account',
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                // Email Field
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'Email Address',
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
                // Password Field with Toggle
                TextField(
                  controller: passwordController,
                  obscureText: _obscurePassword, // Controlled by state
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    // Added Suffix Icon for Toggle
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
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
                    onPressed: login,
                    child: const Text('Sign in', style: TextStyle(fontSize: 16)),
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
                      onTap: () {
                        Navigator.pushNamed(context, '/signup');
                      },
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