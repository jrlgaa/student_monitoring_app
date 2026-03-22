import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ActivityDatabase {
  static final ActivityDatabase instance = ActivityDatabase._init();
  static Database? _database;

  ActivityDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('teacher_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: _ensureTables,
    );
  }

  Future _ensureTables(Database db) async {
    // 1. Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        password TEXT NOT NULL,
        phone TEXT,
        subject TEXT,
        advisoryClass TEXT,
        teacher_id TEXT
      )
    ''');

    // 2. Activities table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        fileName TEXT,
        filePath TEXT,
        date TEXT NOT NULL
      )
    ''');

    // 3. Announcements table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT,
        date TEXT NOT NULL
      )
    ''');

    // 4. Student Grades table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentName TEXT NOT NULL,
        activityKey TEXT NOT NULL,
        grade REAL,
        status TEXT,
        UNIQUE(studentName, activityKey) ON CONFLICT REPLACE
      )
    ''');

    // 5. Attendance table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        studentName TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        UNIQUE(studentName, date) ON CONFLICT REPLACE
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    await _ensureTables(db);
  }

  // --- ATTENDANCE METHODS ---

  Future<int> saveAttendance(String name, String date, String status) async {
    final db = await instance.database;
    return await db.insert('attendance', {
      'studentName': name,
      'date': date,
      'status': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Returns a Map where key is studentName and value is status (e.g., 'Present')
  Future<Map<String, String>> getAttendanceByDate(String date) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'date = ?',
      whereArgs: [date],
    );

    // Convert the List of maps into a single Map for easier UI lookup
    return {
      for (var item in maps)
        item['studentName'] as String : item['status'] as String
    };
  }

  // --- GRADE PERSISTENCE METHODS ---

  Future<int> saveStudentGrade(String name, String key, double? grade, String status) async {
    final db = await instance.database;
    return await db.insert('student_grades', {
      'studentName': name,
      'activityKey': key,
      'grade': grade,
      'status': status,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllGrades() async {
    final db = await instance.database;
    return await db.query('student_grades');
  }

  Future<int> deleteGradesByActivity(String activityKey) async {
    final db = await instance.database;
    return await db.delete(
      'student_grades',
      where: 'activityKey = ?',
      whereArgs: [activityKey],
    );
  }

  // --- TEACHER PROFILE METHODS ---

  String _generateTeacherId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return '${ms % 9000 + 1000}-${(ms ~/ 13) % 90 + 10}';
  }

  Future<Map<String, dynamic>?> getTeacherProfile() async {
    try {
      final db = await instance.database;
      final maps = await db.query('users', where: 'role = ?', whereArgs: ['Teacher'], limit: 1);

      if (maps.isNotEmpty) {
        final data = maps.first;
        return {
          'teacherId': data['teacher_id'] ?? _generateTeacherId(),
          'name': '${data['firstName']} ${data['lastName']}',
          'email': data['email'],
          'phone': data['phone'] ?? '',
          'subject': data['subject'] ?? '',
          'advisoryClass': data['advisoryClass'] ?? '',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<int> updateTeacherProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;
    List<String> nameParts = (profile['name'] as String).split(' ');
    String fName = nameParts.isNotEmpty ? nameParts[0] : '';
    String lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final rowData = {
      'firstName': fName,
      'lastName': lName,
      'email': profile['email'],
      'phone': profile['phone'],
      'subject': profile['subject'] ?? '',
      'advisoryClass': profile['advisoryClass'],
      'teacher_id': profile['teacherId'],
    };

    return await db.update('users', rowData, where: 'teacher_id = ?', whereArgs: [profile['teacherId']]);
  }

  // --- ACTIVITY & ANNOUNCEMENT METHODS ---

  Future<int> insertActivity(Map<String, dynamic> activity) async {
    final db = await instance.database;
    return await db.insert('activities', activity);
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await instance.database;
    return await db.query('activities', orderBy: 'date DESC');
  }

  Future<int> insertAnnouncement(Map<String, dynamic> announcement) async {
    final db = await instance.database;
    return await db.insert('announcements', announcement);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final db = await instance.database;
    return await db.query('announcements', orderBy: 'id DESC');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}