import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AdminDatabase {
  static final AdminDatabase instance = AdminDatabase._init();
  static Database? _database;

  AdminDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('admin.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE students ADD COLUMN status TEXT DEFAULT 'Active'");
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        lrn TEXT NOT NULL,
        grade TEXT NOT NULL,
        status TEXT DEFAULT 'Active'
      )
    ''');
  }

  Future<int> createStudent(Map<String, String> student) async {
    final db = await instance.database;
    return await db.insert('students', student);
  }

  Future<List<Map<String, dynamic>>> readActiveStudents() async {
    final db = await instance.database;
    return await db.query('students', where: 'status = ?', whereArgs: ['Active'], orderBy: 'lastName ASC');
  }

  // NEW: Fetch archived students
  Future<List<Map<String, dynamic>>> readArchivedStudents() async {
    final db = await instance.database;
    return await db.query('students', where: 'status = ?', whereArgs: ['Archived'], orderBy: 'lastName ASC');
  }

  Future<int> updateStudent(int id, Map<String, String> student) async {
    final db = await instance.database;
    return await db.update('students', student, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archiveStudent(int id) async {
    final db = await instance.database;
    return await db.update('students', {'status': 'Archived'}, where: 'id = ?', whereArgs: [id]);
  }

  // NEW: Restore from archive
  Future<int> restoreStudent(int id) async {
    final db = await instance.database;
    return await db.update('students', {'status': 'Active'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}