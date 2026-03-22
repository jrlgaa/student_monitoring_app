import 'dart:async';
import 'package:flutter/foundation.dart';
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
        teacher_id TEXT,
        profile_image TEXT
      )
    ''');

    // Add profile_image to existing DBs that were created before this column
    try {
      await db.execute('ALTER TABLE users ADD COLUMN profile_image TEXT');
    } catch (_) {} // Already exists — safe to ignore

    // 2. Activities table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        fileName TEXT,
        filePath TEXT,
        date TEXT NOT NULL,
        deadline TEXT DEFAULT '',
        roomCode TEXT DEFAULT ''
      )
    ''');
    try { await db.execute("ALTER TABLE activities ADD COLUMN roomCode TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE activities ADD COLUMN deadline TEXT DEFAULT ''"); } catch (_) {}

    // 3. Announcements table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT,
        date TEXT NOT NULL,
        imagePaths TEXT DEFAULT '',
        roomCode TEXT DEFAULT ''
      )
    ''');
    try { await db.execute("ALTER TABLE announcements ADD COLUMN roomCode TEXT DEFAULT ''"); } catch (_) {}
    try { await db.execute("ALTER TABLE announcements ADD COLUMN imagePaths TEXT DEFAULT ''"); } catch (_) {}

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
        roomCode TEXT DEFAULT '',
        UNIQUE(studentName, date, roomCode) ON CONFLICT REPLACE
      )
    ''');
    try { await db.execute("ALTER TABLE attendance ADD COLUMN roomCode TEXT DEFAULT ''"); } catch (_) {}

    // 6. Rooms table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rooms (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        teacherEmail TEXT NOT NULL,
        status TEXT DEFAULT 'Active',
        createdAt TEXT DEFAULT (datetime('now'))
      )
    ''');
    // Add status column to existing DBs that were created before this column
    try {
      await db.execute("ALTER TABLE rooms ADD COLUMN status TEXT DEFAULT 'Active'");
    } catch (_) {}
    await db.execute("UPDATE rooms SET status = 'Active' WHERE status IS NULL");

    // 7. Room members table (guardians who joined)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS room_members (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        roomCode TEXT NOT NULL,
        guardianEmail TEXT NOT NULL,
        joinedAt TEXT DEFAULT (datetime('now')),
        UNIQUE(roomCode, guardianEmail) ON CONFLICT IGNORE
      )
    ''');
  }

  Future _createDB(Database db, int version) async {
    await _ensureTables(db);
  }

  // --- ATTENDANCE METHODS ---

  Future<int> saveAttendance(String name, String date, String status, {String roomCode = ''}) async {
    final db = await instance.database;
    return await db.insert('attendance', {
      'studentName': name,
      'date': date,
      'status': status,
      'roomCode': roomCode,
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

  /// Returns all attendance records for a given student name, ordered by date DESC
  Future<List<Map<String, dynamic>>> getAttendanceByStudent(String studentName) async {
    final db = await instance.database;
    return await db.query(
      'attendance',
      where: 'studentName = ?',
      whereArgs: [studentName],
      orderBy: 'date DESC',
    );
  }

  /// Returns all attendance records (all students, all dates)
  Future<List<Map<String, dynamic>>> getAllAttendance() async {
    final db = await instance.database;
    return await db.query('attendance', orderBy: 'date DESC');
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

  /// Fetches teacher profile from teacher_data.db, matched by email.
  Future<Map<String, dynamic>?> getTeacherProfile({String? email}) async {
    try {
      final db = await instance.database;
      final maps = email != null
          ? await db.query('users', where: 'email = ? AND role = ?', whereArgs: [email, 'Teacher'], limit: 1)
          : await db.query('users', where: 'role = ?', whereArgs: ['Teacher'], limit: 1);

      if (maps.isNotEmpty) {
        final data = maps.first;
        String teacherId = (data['teacher_id'] ?? '').toString().trim();
        if (teacherId.isEmpty) {
          teacherId = _generateTeacherId();
          await db.update('users', {'teacher_id': teacherId}, where: 'id = ?', whereArgs: [data['id']]);
        }
        return {
          'teacherId': teacherId,
          'name': '${data['firstName']} ${data['lastName']}',
          'email': (data['email'] ?? '').toString(),
          'phone': (data['phone'] ?? '').toString(),
          'subject': (data['subject'] ?? '').toString(),
          'advisoryClass': (data['advisoryClass'] ?? '').toString(),
          'profileImage': (data['profile_image'] ?? '').toString(),
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetches teacher info from admin's user_data.db by email.
  Future<Map<String, dynamic>?> getTeacherFromAdminDB(String email) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'user_data.db');
      final adminDb = await openDatabase(path);

      final maps = await adminDb.query('users', where: 'email = ?', whereArgs: [email], limit: 1);

      if (maps.isNotEmpty) {
        final data = maps.first;
        final firstName = (data['firstName'] ?? '').toString().trim();
        final middleName = (data['middleName'] ?? '').toString().trim();
        final lastName = (data['lastName'] ?? '').toString().trim();
        final fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName]
            .where((s) => s.isNotEmpty).join(' ');
        return {
          'teacherId': _generateTeacherId(),
          'name': fullName,
          'email': (data['email'] ?? email).toString(),
          'phone': '',
          'subject': '',
          'advisoryClass': '',
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Saves teacher profile to teacher_data.db.
  /// Updates existing record by email, or inserts new one if none exists.
  Future<void> updateTeacherProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;

    final nameParts = (profile['name'] as String? ?? '').trim().split(' ');
    final fName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    final email = (profile['email'] ?? '').toString().trim();

    String teacherId = (profile['teacherId'] ?? '').toString().trim();
    if (teacherId.isEmpty) teacherId = _generateTeacherId();

    final rowData = {
      'firstName': fName,
      'lastName': lName,
      'email': email,
      'phone': (profile['phone'] ?? '').toString().trim(),
      'subject': (profile['subject'] ?? '').toString().trim(),
      'advisoryClass': (profile['advisoryClass'] ?? '').toString().trim(),
      'teacher_id': teacherId,
      'role': 'Teacher',
      'profile_image': (profile['profileImage'] ?? '').toString(),
    };

    final rowsAffected = await db.update('users', rowData, where: 'email = ?', whereArgs: [email]);
    if (rowsAffected == 0) {
      await db.insert('users', {'password': 'changeme', 'middleName': '', ...rowData});
    }
  }

  // --- ACTIVITY & ANNOUNCEMENT METHODS ---

  Future<int> insertActivity(Map<String, dynamic> activity) async {
    final db = await instance.database;
    // Only insert known columns — strip id and any extra fields
    final row = {
      'title': activity['title'] ?? '',
      'description': activity['description'] ?? '',
      'fileName': activity['fileName'] ?? '',
      'filePath': activity['filePath'] ?? '',
      'date': activity['date'] ?? '',
      'deadline': activity['deadline'] ?? '',
      'roomCode': activity['roomCode'] ?? '',
    };
    return await db.insert('activities', row);
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await instance.database;
    return await db.query('activities', orderBy: 'date DESC');
  }

  Future<int> insertAnnouncement(Map<String, dynamic> announcement) async {
    final db = await instance.database;
    // Only insert known columns — strip id and any extra fields
    final row = {
      'title': announcement['title'] ?? '',
      'message': announcement['message'] ?? '',
      'date': announcement['date'] ?? '',
      'imagePaths': announcement['imagePaths'] ?? '',
      'roomCode': announcement['roomCode'] ?? '',
    };
    return await db.insert('announcements', row);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final db = await instance.database;
    return await db.query('announcements', orderBy: 'id DESC');
  }

  // --- ROOM METHODS ---

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    String code = '';
    int seed = random;
    for (int i = 0; i < 6; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF; // LCG
      code += chars[seed % chars.length];
    }
    return code;
  }

  Future<Map<String, dynamic>?> createRoom(String title, String teacherEmail) async {
    try {
      final db = await instance.database;

      // Verify rooms table exists
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='rooms'");
      debugPrint('createRoom: rooms table exists = ${tables.isNotEmpty}');

      String code = _generateRoomCode();
      while (true) {
        final existing = await db.query('rooms', where: 'code = ?', whereArgs: [code], limit: 1);
        if (existing.isEmpty) break;
        code = _generateRoomCode();
      }

      final id = await db.insert('rooms', {
        'title': title,
        'code': code,
        'teacherEmail': teacherEmail,
      });
      debugPrint('createRoom: inserted row id=$id, title="$title", code=$code, email=$teacherEmail');

      // Verify it was saved
      final verify = await db.query('rooms');
      debugPrint('createRoom: all rooms after insert = $verify');

      return {'title': title, 'code': code, 'teacherEmail': teacherEmail};
    } catch (e) {
      debugPrint('createRoom ERROR: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRoomByTeacher(String teacherEmail) async {
    try {
      final db = await instance.database;
      final maps = await db.query('rooms', where: 'teacherEmail = ?', whereArgs: [teacherEmail], limit: 1);
      return maps.isNotEmpty ? maps.first : null;
    } catch (_) { return null; }
  }

  /// Returns ALL rooms created by this teacher
  Future<List<Map<String, dynamic>>> getRoomsByTeacher(String teacherEmail) async {
    try {
      final db = await instance.database;
      return await db.query('rooms', where: 'teacherEmail = ?', whereArgs: [teacherEmail], orderBy: 'id DESC');
    } catch (_) { return []; }
  }

  Future<Map<String, dynamic>?> getRoomByCode(String code) async {
    try {
      final db = await instance.database;
      final maps = await db.query('rooms', where: 'code = ?', whereArgs: [code.toUpperCase().trim()], limit: 1);
      debugPrint('getRoomByCode: code=$code, found=${maps.length} rows');
      return maps.isNotEmpty ? maps.first : null;
    } catch (e) {
      debugPrint('getRoomByCode error: $e');
      return null;
    }
  }

  Future<bool> joinRoom(String code, String guardianEmail) async {
    try {
      final db = await instance.database;

      // Ensure tables exist FIRST before any queries
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          teacherEmail TEXT NOT NULL,
          createdAt TEXT DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS room_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          roomCode TEXT NOT NULL,
          guardianEmail TEXT NOT NULL,
          joinedAt TEXT DEFAULT (datetime('now')),
          UNIQUE(roomCode, guardianEmail) ON CONFLICT IGNORE
        )
      ''');

      // Debug: show all rooms in DB
      final allRooms = await db.query('rooms');
      debugPrint('joinRoom DEBUG: all rooms in DB = $allRooms');
      debugPrint('joinRoom DEBUG: looking for code = "${code.toUpperCase().trim()}"');

      final room = await getRoomByCode(code);
      debugPrint('joinRoom: room found = ${room != null}');
      if (room == null) return false;

      await db.insert('room_members', {
        'roomCode': code.toUpperCase().trim(),
        'guardianEmail': guardianEmail,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      debugPrint('joinRoom: inserted member $guardianEmail into room $code');
      return true;
    } catch (e) {
      debugPrint('joinRoom error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getJoinedRoom(String guardianEmail) async {
    try {
      final db = await instance.database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS rooms (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          code TEXT NOT NULL UNIQUE,
          teacherEmail TEXT NOT NULL,
          createdAt TEXT DEFAULT (datetime('now'))
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS room_members (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          roomCode TEXT NOT NULL,
          guardianEmail TEXT NOT NULL,
          joinedAt TEXT DEFAULT (datetime('now')),
          UNIQUE(roomCode, guardianEmail) ON CONFLICT IGNORE
        )
      ''');
      final maps = await db.rawQuery('''
        SELECT r.* FROM rooms r
        JOIN room_members rm ON r.code = rm.roomCode
        WHERE rm.guardianEmail = ?
        LIMIT 1
      ''', [guardianEmail]);
      debugPrint('getJoinedRoom: guardianEmail=$guardianEmail, found=${maps.length} rows');
      return maps.isNotEmpty ? maps.first : null;
    } catch (e) {
      debugPrint('getJoinedRoom error: $e');
      return null;
    }
  }

  /// Returns ALL rooms this guardian has joined
  Future<List<Map<String, dynamic>>> getJoinedRooms(String guardianEmail) async {
    try {
      final db = await instance.database;
      final maps = await db.rawQuery('''
        SELECT r.* FROM rooms r
        JOIN room_members rm ON r.code = rm.roomCode
        WHERE rm.guardianEmail = ?
        ORDER BY rm.joinedAt DESC
      ''', [guardianEmail]);
      return maps;
    } catch (e) {
      debugPrint('getJoinedRooms error: $e');
      return [];
    }
  }

  /// Leave a specific room by code
  Future<void> leaveRoomByCode(String code, String guardianEmail) async {
    try {
      final db = await instance.database;
      await db.delete('room_members',
          where: 'roomCode = ? AND guardianEmail = ?',
          whereArgs: [code, guardianEmail]);
    } catch (_) {}
  }

  /// Returns list of guardians (with name + email) who joined the teacher's room.
  Future<List<Map<String, dynamic>>> getRoomMembers(String teacherEmail) async {
    try {
      final db = await instance.database;
      final room = await getRoomByTeacher(teacherEmail);
      if (room == null) return [];

      final members = await db.query('room_members', where: 'roomCode = ?', whereArgs: [room['code']]);
      if (members.isEmpty) return [];

      final adminDbPath = join(await getDatabasesPath(), 'user_data.db');
      final adminDb = await openDatabase(adminDbPath);

      final List<Map<String, dynamic>> result = [];
      for (final member in members) {
        final email = member['guardianEmail'].toString();
        final users = await adminDb.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
        if (users.isNotEmpty) {
          final u = users.first;
          final firstName = (u['firstName'] ?? '').toString().trim();
          final middleName = (u['middleName'] ?? '').toString().trim();
          final lastName = (u['lastName'] ?? '').toString().trim();
          final fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName]
              .where((s) => s.isNotEmpty).join(' ');
          result.add({'name': fullName, 'email': email});
        } else {
          result.add({'name': email, 'email': email});
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  /// Returns ALL active rooms from all teachers (for admin view)
  Future<List<Map<String, dynamic>>> getAllRooms() async {
    try {
      final db = await instance.database;
      return await db.query('rooms', where: 'status = ?', whereArgs: ['Active'], orderBy: 'id DESC');
    } catch (_) { return []; }
  }

  /// Returns ALL archived rooms (for admin archive view)
  Future<List<Map<String, dynamic>>> getArchivedRooms() async {
    try {
      final db = await instance.database;
      return await db.query('rooms', where: 'status = ?', whereArgs: ['Archived'], orderBy: 'id DESC');
    } catch (_) { return []; }
  }

  /// Archives a room by code (soft delete)
  Future<void> archiveRoomByCode(String code) async {
    try {
      final db = await instance.database;
      await db.update('rooms', {'status': 'Archived'}, where: 'code = ?', whereArgs: [code]);
    } catch (_) {}
  }

  /// Restores an archived room by code
  Future<void> restoreRoomByCode(String code) async {
    try {
      final db = await instance.database;
      await db.update('rooms', {'status': 'Active'}, where: 'code = ?', whereArgs: [code]);
    } catch (_) {}
  }

  /// Returns members of a specific room by code (for admin detail view)
  Future<List<Map<String, dynamic>>> getRoomMembersByCode(String code) async {
    try {
      final db = await instance.database;
      final members = await db.query('room_members', where: 'roomCode = ?', whereArgs: [code.toUpperCase().trim()]);
      if (members.isEmpty) return [];

      final adminDbPath = join(await getDatabasesPath(), 'user_data.db');
      final adminDb = await openDatabase(adminDbPath);

      final List<Map<String, dynamic>> result = [];
      for (final member in members) {
        final email = member['guardianEmail'].toString();
        final users = await adminDb.query('users', where: 'email = ?', whereArgs: [email], limit: 1);
        if (users.isNotEmpty) {
          final u = users.first;
          final firstName = (u['firstName'] ?? '').toString().trim();
          final middleName = (u['middleName'] ?? '').toString().trim();
          final lastName = (u['lastName'] ?? '').toString().trim();
          final fullName = [firstName, if (middleName.isNotEmpty) middleName, lastName]
              .where((s) => s.isNotEmpty).join(' ');
          result.add({'name': fullName, 'email': email});
        } else {
          result.add({'name': email, 'email': email});
        }
      }
      return result;
    } catch (_) { return []; }
  }

  Future<void> deleteRoom(String teacherEmail) async {
    try {
      final db = await instance.database;
      final room = await getRoomByTeacher(teacherEmail);
      if (room != null) {
        await db.delete('room_members', where: 'roomCode = ?', whereArgs: [room['code']]);
        await db.delete('rooms', where: 'teacherEmail = ?', whereArgs: [teacherEmail]);
      }
    } catch (_) {}
  }

  Future<void> deleteRoomByCode(String code) async {
    try {
      final db = await instance.database;
      await db.delete('room_members', where: 'roomCode = ?', whereArgs: [code]);
      await db.delete('rooms', where: 'code = ?', whereArgs: [code]);
    } catch (e) {
      debugPrint('deleteRoomByCode error: $e');
    }
  }

  Future close() async {
    if (_database != null) {
      await _database!.close();
      _database = null; // Will reopen on next access, re-running _ensureTables
    }
  }
}