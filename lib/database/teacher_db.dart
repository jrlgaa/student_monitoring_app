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
      // Runs every time the DB is opened — guarantees tables exist
      // even if the DB file was created before the schema was defined
      onOpen: _ensureTables,
    );
  }

  // Called on every open to safely create missing tables
  Future _ensureTables(Database db) async {
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

    // Add teacher_id column to existing DBs that were created before this column existed
    try {
      await db.execute('ALTER TABLE users ADD COLUMN teacher_id TEXT');
    } catch (_) {
      // Column already exists — safe to ignore
    }

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

    await db.execute('''
      CREATE TABLE IF NOT EXISTS announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT,
        date TEXT NOT NULL
      )
    ''');
  }

  // Delegates to _ensureTables so both paths stay in sync
  Future _createDB(Database db, int version) async {
    await _ensureTables(db);
  }

  // --- DYNAMIC PROFILE METHODS ---

  // Generates a unique Teacher ID in the format xxxx-xx (e.g. 4821-37)
  String _generateTeacherId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final fourDigit = (ms % 9000 + 1000).toString().padLeft(4, '0');
    final twoDigit = ((ms ~/ 13) % 90 + 10).toString().padLeft(2, '0');
    return '$fourDigit-$twoDigit';
  }

  Future<Map<String, dynamic>?> getTeacherProfile() async {
    try {
      final db = await instance.database;

      final maps = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['Teacher'],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        final data = maps.first;

        // If teacher_id is missing/null/empty, generate and persist one now
        String teacherId = (data['teacher_id'] ?? '').toString().trim();
        if (teacherId.isEmpty) {
          teacherId = _generateTeacherId();
          await db.update(
            'users',
            {'teacher_id': teacherId},
            where: 'id = ?',
            whereArgs: [data['id']],
          );
        }

        return {
          'teacherId': teacherId,
          'name': '${data['firstName']} ${data['lastName']}',
          'email': data['email'],
          'phone': data['phone'] ?? '',
          'subject': data['subject'] ?? '',
          'advisoryClass': data['advisoryClass'] ?? '',
        };
      } else {
        return null; // Let the caller's fallback handle this
      }
    } catch (e) {
      return null;
    }
  }

  Future<int> updateTeacherProfile(Map<String, dynamic> profile) async {
    final db = await instance.database;

    List<String> nameParts = (profile['name'] as String).split(' ');
    String fName = nameParts.isNotEmpty ? nameParts[0] : '';
    String lName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final String teacherId = profile['teacherId']?.toString() ?? '';

    final rowData = {
      'firstName': fName,
      'lastName': lName,
      'email': profile['email'],
      'phone': profile['phone'],
      'subject': profile['subject'] ?? '',
      'advisoryClass': profile['advisoryClass'],
      'teacher_id': teacherId,
    };

    // Try updating the existing Teacher row by teacher_id first
    int rowsAffected = 0;
    if (teacherId.isNotEmpty) {
      rowsAffected = await db.update(
        'users',
        rowData,
        where: 'teacher_id = ?',
        whereArgs: [teacherId],
      );
    }

    if (rowsAffected == 0) {
      // No existing row — insert a new one with role = 'Teacher'
      return await db.insert('users', {
        ...rowData,
        'role': 'Teacher',
        'password': 'changeme',
        'middleName': '',
      });
    }

    return rowsAffected;
  }

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