import 'package:flutter/material.dart';

import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'dashboard/teacher_page.dart';
// import 'dashboard/guardian_dashboard.dart'; // future use

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

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ================= THEMES =================
      theme: ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
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
        '/teacher-dashboard': (context) => const TeacherPage(),

        // Guardian Portal (future)
        // '/guardian-dashboard': (context) => const GuardianDashboard(),
      },
    );
  }
}