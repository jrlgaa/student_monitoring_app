import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('user_data.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Bumped version to 3 to add status to users table
      onCreate: _createDB,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createStudentsTable(db);
        }
        // ADDED: Logic to add status column to users if upgrading from v2 to v3
        if (oldVersion < 3) {
          await db.execute("ALTER TABLE users ADD COLUMN status TEXT DEFAULT 'Active'");
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    // UPDATED: Added 'status' column to the initial creation
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        middleName TEXT,
        lastName TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        role TEXT NOT NULL,
        password TEXT NOT NULL,
        status TEXT DEFAULT 'Active' 
      )
    ''');

    await _createStudentsTable(db);
  }

  Future _createStudentsTable(Database db) async {
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

  // --- AUTHENTICATION METHODS ---

  Future<int> registerUser(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Ensure new users start as Active
    var data = Map<String, dynamic>.from(row);
    data['status'] = 'Active';
    return await db.insert('users', data);
  }

  Future<Map<String, dynamic>?> loginUser(String email, String password) async {
    final db = await instance.database;
    final results = await db.query(
      'users',
      where: 'email = ? AND password = ? AND status = ?',
      whereArgs: [email, password, 'Active'], // Only let active users login
    );
    return results.isNotEmpty ? results.first : null;
  }

  // --- ADMIN METHODS (Teachers & Guardians) ---

  // UPDATED: Filter to only show Active users in the main lists
  Future<List<Map<String, dynamic>>> readUsersByRole(String role) async {
    final db = await instance.database;
    return await db.query(
        'users',
        where: 'role = ? AND status = ?',
        whereArgs: [role, 'Active'],
        orderBy: 'lastName ASC'
    );
  }

  // ADDED: Fetch archived teachers/guardians for the Archives tab
  Future<List<Map<String, dynamic>>> readArchivedUsers() async {
    final db = await instance.database;
    return await db.query(
        'users',
        where: 'status = ?',
        whereArgs: ['Archived'],
        orderBy: 'lastName ASC'
    );
  }

  Future<int> archiveUser(int id) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'status': 'Archived'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ADDED: Restore method for Teachers/Guardians
  Future<int> restoreUser(int id) async {
    final db = await instance.database;
    return await db.update(
      'users',
      {'status': 'Active'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await instance.database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // --- STUDENT MANAGEMENT METHODS ---

  Future<int> createStudent(Map<String, dynamic> student) async {
    final db = await instance.database;
    return await db.insert('students', student);
  }

  Future<List<Map<String, dynamic>>> readActiveStudents() async {
    final db = await instance.database;
    return await db.query('students', where: 'status = ?', whereArgs: ['Active'], orderBy: 'lastName ASC');
  }

  Future<List<Map<String, dynamic>>> readArchivedStudents() async {
    final db = await instance.database;
    return await db.query('students', where: 'status = ?', whereArgs: ['Archived'], orderBy: 'lastName ASC');
  }

  Future<int> updateStudent(int id, Map<String, dynamic> student) async {
    final db = await instance.database;
    return await db.update('students', student, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> archiveStudent(int id) async {
    final db = await instance.database;
    return await db.update('students', {'status': 'Archived'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> restoreStudent(int id) async {
    final db = await instance.database;
    return await db.update('students', {'status': 'Active'}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteStudent(int id) async {
    final db = await instance.database;
    return await db.delete('students', where: 'id = ?', whereArgs: [id]);
  }
}