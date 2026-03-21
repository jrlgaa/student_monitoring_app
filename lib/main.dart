import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Import Firebase Core
// Keep your existing imports
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'auth/forgot_password_page.dart';
import 'dashboard/teacher_page.dart';
import 'dashboard/guardian_page.dart';
import 'dashboard/admin_page.dart';

// 2. Change main to async
void main() async {
  // 3. Essential for Firebase initialization
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Initialize the connection to your database
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LMS Portal',

      // Themes logic stays the same
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      initialRoute: '/login',

      routes: {
        '/login': (context) => LoginPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        '/signup': (context) => SignUpPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        '/teacher-dashboard': (context) => TeacherPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        '/guardian-dashboard': (context) => GuardianPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        '/admin-dashboard': (context) => AdminPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
        '/forgot-password': (context) => ForgotPasswordPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
      },
    );
  }
}