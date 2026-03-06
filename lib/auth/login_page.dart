import 'package:flutter/material.dart';

class LoginPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const LoginPage({super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // Dummy teacher account
    const String dummyEmail = 'teacher@example.com';
    const String dummyPassword = '123456';

    void login(String email, String password) {
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields')),
        );
        return;
      }

      if (email == dummyEmail && password == dummyPassword) {
        // Navigate to teacher dashboard
        Navigator.pushReplacementNamed(context, '/teacher-dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password!')),
        );
      }
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[800] : Colors.white,
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
                Text(
                  'Log in to your account',
                  style: TextStyle(
                    color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'Phone or Email',
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[700]?.withOpacity(0.2) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      login(emailController.text.trim(), passwordController.text.trim());
                    },
                    child: const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 10),
                // Dummy login button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Login as Dummy Teacher'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      emailController.text = dummyEmail;
                      passwordController.text = dummyPassword;
                      login(dummyEmail, dummyPassword);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don’t have an account? ",
                      style: TextStyle(color: isDarkMode ? Colors.grey[300] : Colors.grey[700]),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(color: Colors.blue),
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
        backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[200],
        foregroundColor: isDarkMode ? Colors.white : Colors.black,
        onPressed: toggleTheme,
        child: Text(isDarkMode ? '☀️' : '🌙'),
      ),
    );
  }
}