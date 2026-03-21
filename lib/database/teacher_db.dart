import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

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
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Activities Table
    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        fileName TEXT,
        filePath TEXT,
        date TEXT
      )
    ''');

    // Announcements Table
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT,
        date TEXT
      )
    ''');
  }

  // --- ACTIVITY METHODS ---

  Future<int> insertActivity(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('activities', row);
  }

  Future<List<Map<String, dynamic>>> getActivities() async {
    final db = await instance.database;
    return await db.query('activities', orderBy: 'id DESC');
  }

  Future<int> deleteActivity(int id) async {
    final db = await instance.database;
    return await db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  // --- ANNOUNCEMENT METHODS ---

  Future<int> insertAnnouncement(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('announcements', row);
  }

  Future<List<Map<String, dynamic>>> getAnnouncements() async {
    final db = await instance.database;
    return await db.query('announcements', orderBy: 'id DESC');
  }

  Future<Object?> readAllAnnouncements() async {}
}