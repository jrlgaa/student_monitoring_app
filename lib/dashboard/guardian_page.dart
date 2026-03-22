import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../database/admin_db.dart';

class GuardianPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const GuardianPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;
  bool isLoading = true;
  bool isEditing = false;

  // Add Student state
  late TextEditingController _lrnController;
  List<Map<String, dynamic>> linkedStudents = [];
  bool isLinking = false;
  int? currentGuardianId;

  // Profile Controllers
  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _announcements = [];
  final List<Map<String, String>> _myRegisteredStudents = [];

  final Map<String, String> _profileData = {
    'firstName': 'Ryan Caesar',
    'middleName': '',
    'lastName': 'Mendoza',
    'id': 'G2024-0812',
    'phone': '9123456789', // Stored as raw digits
  };

  String get _getFullName {
    String first = _profileData['firstName'] ?? '';
    String middle = _profileData['middleName'] ?? '';
    String last = _profileData['lastName'] ?? '';
    return middle.isEmpty ? "$first $last".trim() : "$first $middle $last".trim();
  }

  // final List<String> students = [
  //   'Dometita, Rainer', 'Mendoza, Ryan Caesar', 'Gaa, Jeriel',
  //   'Tagapan, Jhem', 'Tayag, Joshua', 'Ravida, Kris Lawrence'
  // ];

  Map<String, Map<String, Map<String, dynamic>>> _studentGrades = {};

  final List<String> menuTitles = ['Activities', 'Student Grades', 'Announcements', 'Add Student', 'Profile'];
  final List<IconData> menuIcons = [Icons.folder, Icons.school, Icons.campaign, Icons.person_add, Icons.person];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: _profileData['firstName']);
    _middleNameController = TextEditingController(text: _profileData['middleName']);
    _lastNameController = TextEditingController(text: _profileData['lastName']);
    _phoneController = TextEditingController(text: _profileData['phone']);
    _lrnController = TextEditingController();
    _fetchDatabaseData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _lrnController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseData() async {
    setState(() => isLoading = true);
    try {
      // Teacher data DB for activities/announcements
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'teacher_data.db');
      final Database teacherDb = await openDatabase(path);

      final List<Map<String, dynamic>> activityMaps = await teacherDb.query('activities', orderBy: 'id DESC');
      final List<Map<String, dynamic>> announcementMaps = await teacherDb.query('announcements', orderBy: 'id DESC');

      // Admin DB for students and linking
      final adminDb = await DatabaseHelper.instance.database;

      // Ensure guardian_students table exists (moved to linkStudent for reliability)
      try {
        await adminDb.execute('''
          CREATE TABLE IF NOT EXISTS guardian_students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            guardian_id INTEGER NOT NULL,
            student_id INTEGER NOT NULL,
            created_at TEXT DEFAULT (datetime('now')),
            UNIQUE(guardian_id, student_id) ON CONFLICT IGNORE
          )
        ''');
      } catch (e) {
        debugPrint('Table already exists: $e');
      }

      // Fetch current guardian (first active Guardian role from teacher_data users)
      final List<Map<String, dynamic>> guardianMaps = await teacherDb.query(
        'users',
        where: "role = ? AND status = ?",
        whereArgs: ['Guardian', 'Active'],
        limit: 1,
      );
      if (guardianMaps.isNotEmpty) {
        currentGuardianId = guardianMaps.first['id'] as int?;
      }

      // Load linked students if guardian_id available
      if (currentGuardianId != null) {
        final List<Map<String, dynamic>> links = await adminDb.rawQuery('''
          SELECT s.* FROM students s
          JOIN guardian_students gs ON s.id = gs.student_id
          WHERE gs.guardian_id = ?
          AND s.status = 'Active'
        ''', [currentGuardianId]);
        linkedStudents = links;
      }

      teacherDb.close();

      setState(() {
        _activities = activityMaps;
        _announcements = announcementMaps;
        _initGuardianGrades();
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Database Error: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateProfileInDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'teacher_data.db');
      final Database db = await openDatabase(path);

      await db.update(
        'users',
        {
          'first_name': _profileData['firstName'],
          'middle_name': _profileData['middleName'],
          'last_name': _profileData['lastName'],
          'phone': _profileData['phone'],
        },
        where: 'id = ?',
        whereArgs: [_profileData['id']],
      );
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  void _initGuardianGrades() {
    // Palitan ang 'students' ng '_linkedStudents'
    for (var studentMap in linkedStudents) {
      // Kunin ang Full Name bilang key para mag-match sa UI logic mo
      String studentKey = '${studentMap['firstName']} ${studentMap['lastName']}';

      _studentGrades[studentKey] = {};

      for (var activity in _activities) {
        String key = '${activity['title']}_${activity['date']}';

        // Dito papasok ang logic: Dapat mag-match ang LRN ng activity sa LRN ng bata
        // Pero for now, static muna para makita mo ang result
        _studentGrades[studentKey]![key] = {
          'grade': 85.0,
          'maxScore': 100.0,
          'status': 'Graded'
        };
      }
    }
    setState(() {}); // Siguraduhing mag-refresh ang UI
  }

  String _formatFullName(Map<String, dynamic> student) {
    String first = student['firstName'] ?? '';
    String middle = student['middleName'] ?? '';
    String last = student['lastName'] ?? '';
    return middle.isEmpty ? '$first $last'.trim() : '$first $middle $last'.trim();
  }

  String _formatLRN(int lrn) {
    final str = lrn.toString().padLeft(12, '0');
    return '${str.substring(0,4)}-${str.substring(4,8)}-${str.substring(8,12)}';
  }

  Future<void> _linkStudent() async {
    // Fixed demo guardian_id = 1
    const int demoGuardianId = 1;

    final lrnStr = _lrnController.text.trim();
    if (lrnStr.length != 12 || !RegExp(r'^\d{12}$').hasMatch(lrnStr)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter exactly 12 digits LRN'), backgroundColor: Colors.red),
      );
      return;
    }

    final lrnInt = int.tryParse(lrnStr);
    if (lrnInt == null) return;

    setState(() => isLinking = true);

    try {
      final adminDb = await DatabaseHelper.instance.database;

      // Ensure table exists (safe call every time)
      await adminDb.execute('''
        CREATE TABLE IF NOT EXISTS guardian_students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          guardian_id INTEGER NOT NULL,
          student_id INTEGER NOT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          UNIQUE(guardian_id, student_id)
        )
      ''');

      // Check student
      final List<Map<String, dynamic>> studentMaps = await adminDb.query(
        'students',
        where: 'lrn = ? AND status = ?',
        whereArgs: [lrnInt, 'Active'],
      );

      if (studentMaps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student not found'), backgroundColor: Colors.orange),
        );
        return;
      }

      final student = studentMaps.first;
      final studentId = student['id'] as int;

      // Check duplicate
      final count = Sqflite.firstIntValue(await adminDb.rawQuery(
        'SELECT COUNT(*) as count FROM guardian_students WHERE guardian_id = ? AND student_id = ?',
        [demoGuardianId, studentId],
      )) ?? 0;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already linked'), backgroundColor: Colors.orange),
        );
        return;
      }

      // Insert link
      await adminDb.insert('guardian_students', {
        'guardian_id': demoGuardianId,
        'student_id': studentId,
      });

      // Reload list
      final links = await adminDb.rawQuery('''
        SELECT s.* FROM students s
        JOIN guardian_students gs ON s.id = gs.student_id
        WHERE gs.guardian_id = ? AND s.status = 'Active'
        ORDER BY s.lastName
      ''', [demoGuardianId]);
      setState(() {
        linkedStudents = links;
      });

      _lrnController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_formatFullName(student)} linked!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint('Link error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Link failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => isLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Container(color: widget.isDarkMode ? Colors.grey[900] : Colors.white, child: _buildSection()),
            if (isSidebarOpen) Positioned.fill(child: GestureDetector(onTap: () => setState(() => isSidebarOpen = false), child: Container(color: Colors.black26))),
            _buildSidebar(),
            if (!isSidebarOpen) Positioned(top: 16, left: 16, child: IconButton(icon: Icon(Icons.menu, color: widget.isDarkMode ? Colors.white : Colors.black), onPressed: () => setState(() => isSidebarOpen = true))),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      left: isSidebarOpen ? 0 : -260,
      top: 0, bottom: 0, width: 260,
      child: Container(
        decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[900] : Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)]),
        child: Column(
          children: [
            const SizedBox(height: 12),
            IconButton(icon: Icon(Icons.menu, color: widget.isDarkMode ? Colors.white : Colors.black), onPressed: () => setState(() => isSidebarOpen = !isSidebarOpen)),
            const SizedBox(height: 20),
            const CircleAvatar(radius: 40, backgroundColor: Colors.blueAccent, child: Icon(Icons.person, size: 40, color: Colors.white)),
            const SizedBox(height: 12),
            Text(_getFullName, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: widget.isDarkMode ? Colors.white : Colors.black)),
            Text("Guardian ID: ${_profileData['id']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 30),
            Expanded(child: ListView.builder(itemCount: menuTitles.length, itemBuilder: (context, index) {
              final selected = index == selectedIndex;
              return ListTile(
                leading: Icon(menuIcons[index], color: selected ? Colors.blue : (widget.isDarkMode ? Colors.white70 : Colors.black54)),
                title: Text(menuTitles[index], style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? Colors.blue : (widget.isDarkMode ? Colors.white : Colors.black))),
                onTap: () => setState(() { selectedIndex = index; isSidebarOpen = false; }),
              );
            })),
            ListTile(title: const Text("Dark Mode"), trailing: Switch(value: widget.isDarkMode, onChanged: (_) => widget.toggleTheme())),
            ListTile(leading: const Icon(Icons.logout, color: Colors.redAccent), title: const Text('Logout', style: TextStyle(color: Colors.redAccent)), onTap: () => Navigator.pushReplacementNamed(context, '/login')),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection() {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    switch (selectedIndex) {
      case 0: return _activitySection();
      case 1: return _studentGradesSection();
      case 2: return _announcementsSection();
      case 3: return _studentRegistrationSection();
      case 4: return _genericSection('Guardian Profile', _profileContent());
      default: return const SizedBox();
    }
  }

  Widget _genericSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(72, 22, 24, 20), child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: widget.isDarkMode ? Colors.white : Colors.black))),
        Expanded(child: content),
      ],
    );
  }

  Widget _profileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Personal Info", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              TextButton.icon(
                onPressed: () async {
                  if (isEditing) {
                    setState(() {
                      _profileData['firstName'] = _firstNameController.text;
                      _profileData['middleName'] = _middleNameController.text;
                      _profileData['lastName'] = _lastNameController.text;
                      _profileData['phone'] = _phoneController.text;
                      isEditing = false;
                    });
                    await _updateProfileInDatabase();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile saved.")));
                  } else {
                    setState(() => isEditing = true);
                  }
                },
                icon: Icon(isEditing ? Icons.check_circle : Icons.edit, size: 18),
                label: Text(isEditing ? "Done" : "Edit"),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isEditing) ...[
            _buildInfoTile("Full Name", _getFullName, Icons.person),
            _buildInfoTile("Phone Number", "+63 ${_profileData['phone']}", Icons.phone),
            _buildInfoTile("Account ID", _profileData['id']!, Icons.badge_outlined),
          ] else ...[
            _buildEditableField("First Name", _firstNameController, Icons.person_outline),
            _buildEditableField("Middle Name", _middleNameController, Icons.person_outline),
            _buildEditableField("Last Name", _lastNameController, Icons.person_outline),
            _buildEditableField(
              "Phone Number",
              _phoneController,
              Icons.phone,
              inputType: TextInputType.phone,
              hint: "9XX XXXX XXXX",
              isPhone: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, IconData icon, {TextInputType inputType = TextInputType.text, String? hint, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: inputType,
        inputFormatters: isPhone ? [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10), // Limits to 10 digits after +63
        ] : [],
        style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: isPhone ? "+63 " : null,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          filled: true,
          fillColor: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ])),
      ]),
    );
  }

  Widget _activitySection() {
    return _genericSection('Teacher Activities', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: _activities.isEmpty ? const Center(child: Text("No activities.")) : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final act = _activities[index];
          return Card(
            color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(act['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Posted: ${act['date']}"),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ActivityDetailPage(activity: act, isDarkMode: widget.isDarkMode))),
            ),
          );
        },
      ),
    ));
  }

  Widget _announcementsSection() {
    return _genericSection('Announcements', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: _announcements.isEmpty ? const Center(child: Text("No announcements.")) : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _announcements.length,
        itemBuilder: (context, index) {
          final ann = _announcements[index];
          return Card(
            color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(ann['title'] ?? 'School Update', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(ann['date'] ?? ''),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AnnouncementDetailPage(announcement: ann, isDarkMode: widget.isDarkMode))),
            ),
          );
        },
      ),
    ));
  }

  Widget _studentRegistrationSection() {
    return _genericSection('Add Student', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Simplified - always show UI
              // LRN Input
              TextField(
                controller: _lrnController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(12),
                ],
                style: TextStyle(color: widget.isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Student LRN (12 digits)',
                  hintText: 'Enter exactly 12 digits',
                  prefixIcon: const Icon(Icons.school, color: Colors.blueAccent),
                  filled: true,
                  fillColor: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _lrnController.clear(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Link Button
              ElevatedButton.icon(
                onPressed: isLinking ? null : _linkStudent,
                icon: isLinking 
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                  : const Icon(Icons.link),
                label: Text(isLinking ? 'Linking...' : 'Link Student'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              // Linked Students List
              Text('Linked Students (${linkedStudents.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (linkedStudents.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('No students linked yet. Enter LRN to link.', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: linkedStudents.length,
                  itemBuilder: (context, index) {
                    final student = linkedStudents[index];
                    final fullName = _formatFullName(student);
                    final lrnStr = _formatLRN(student['lrn'] as int);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: Text('${fullName[0]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('LRN: $lrnStr'),
                        trailing: const Icon(Icons.check_circle, color: Colors.green),
                      ),
                    );
                  },
                ),
            ],
        ),
      ),
    ));
  }
  Widget _studentGradesSection() => _genericSection('Student Grades', const Center(child: Text("Grades Logic")));
}

// --- Detail Page Classes ---

class AnnouncementDetailPage extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final bool isDarkMode;
  const AnnouncementDetailPage({super.key, required this.announcement, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(title: const Text('Announcement Details'), backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(announcement['title'] ?? 'Update', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text("Date: ${announcement['date']}", style: const TextStyle(color: Colors.grey)),
          const Divider(height: 40),
          Text(announcement['message'] ?? announcement['content'] ?? '', style: TextStyle(fontSize: 17, color: isDarkMode ? Colors.white70 : Colors.black87)),
        ]),
      ),
    );
  }
}

class ActivityDetailPage extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isDarkMode;
  const ActivityDetailPage({super.key, required this.activity, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(title: Text(activity['title'] ?? 'Detail'), backgroundColor: isDarkMode ? Colors.grey[900] : Colors.blueAccent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(activity['title'] ?? 'No Title', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text("Posted: ${activity['date']}", style: const TextStyle(color: Colors.grey)),
          const Divider(height: 40),
          Text(activity['description'] ?? 'No description.', style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 30),
          if (activity['filePath'] != null) Image.file(File(activity['filePath'])),
        ]),
      ),
    );
  }
}