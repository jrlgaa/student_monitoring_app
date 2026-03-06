import 'package:flutter/material.dart';

// Ensure these paths match your folder structure exactly
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'dashboard/teacher_page.dart';
import 'dashboard/guardian_page.dart';
import 'dashboard/admin_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDarkMode = false;

  // This function is passed down to all pages to change the global theme
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

      // ================= THEMES =================
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        primarySwatch: Colors.blue,
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),

      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // ================= INITIAL ROUTE =================
      initialRoute: '/login',

      // ================= ROUTES =================
      routes: {
        '/login': (context) => LoginPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),

        '/signup': (context) => SignUpPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),

        // Teacher Portal
        '/teacher-dashboard': (context) => TeacherPage(
        ),

        // Guardian Portal
        '/guardian-dashboard': (context) => GuardianPage(
        ),
        // Inside routes in main.dart
        '/admin-dashboard': (context) => AdminPage(
          toggleTheme: toggleTheme,
          isDarkMode: isDarkMode,
        ),
      },
    );
  }
}