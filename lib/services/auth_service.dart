import 'package:shared_preferences/shared_preferences.dart';
import '../database/admin_db.dart'; // DatabaseHelper

class AuthService {
  static AuthService? _instance;
  static SharedPreferences? _prefs;

  AuthService._private();

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static AuthService get instance {
    _instance ??= AuthService._private();
    return _instance!;
  }

  Future<void> saveCurrentUser(String email, int userId) async {
    final prefs = await _getPrefs();
    await prefs.setString('current_user_email', email);
    await prefs.setInt('current_user_id', userId);
  }

  Future<String?> getCurrentUserEmail() async {
    final prefs = await _getPrefs();
    return prefs.getString('current_user_email');
  }

  Future<int?> getCurrentUserId() async {
    final prefs = await _getPrefs();
    return prefs.getInt('current_user_id');
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final email = await getCurrentUserEmail();
    final id = await getCurrentUserId();
    if (email == null || id == null) return null;

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;
    final results = await db.query(
      'users',
      where: 'id = ? AND email = ? AND status = ?',
      whereArgs: [id, email, 'Active'],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> logout() async {
    final prefs = await _getPrefs();
    await prefs.remove('current_user_email');
    await prefs.remove('current_user_id');
  }

  Future<bool> isLoggedIn() async {
    final email = await getCurrentUserEmail();
    return email != null;
  }
}
