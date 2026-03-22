import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../database/admin_db.dart';
import '../database/teacher_db.dart';

class GuardianPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final String loggedInEmail;

  const GuardianPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.loggedInEmail,
  });

  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;
  bool isLoading = true;
  bool isEditing = false;

  late TextEditingController _lrnController;
  List<Map<String, dynamic>> linkedStudents = [];
  bool isLinking = false;
  int? currentGuardianId;

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;

  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _announcements = [];
  final List<Map<String, String>> _myRegisteredStudents = [];

  // Room state
  Map<String, dynamic>? _joinedRoom;
  final TextEditingController _roomCodeController = TextEditingController();

  final Map<String, String> _profileData = {
    'firstName': '',
    'middleName': '',
    'lastName': '',
    'id': '',
    'phone': '',
  };

  String get _getFullName {
    String first = _profileData['firstName'] ?? '';
    String middle = _profileData['middleName'] ?? '';
    String last = _profileData['lastName'] ?? '';
    return middle.isEmpty ? "$first $last".trim() : "$first $middle $last".trim();
  }

  // Format account ID as xx-xx from the raw integer id
  String get _formattedAccountId {
    final raw = _profileData['id'] ?? '';
    if (raw.isEmpty) return '';
    final ms = int.tryParse(raw) ?? DateTime.now().millisecondsSinceEpoch;
    final part1 = (ms % 90 + 10).toString().padLeft(2, '0');
    final part2 = ((ms ~/ 7) % 90 + 10).toString().padLeft(2, '0');
    return '$part1-$part2';
  }

  Map<String, Map<String, Map<String, dynamic>>> _studentGrades = {};

  final List<String> menuTitles = ['Activities', 'Student Grades', 'Announcements', 'Room', 'Profile'];
  final List<IconData> menuIcons = [Icons.folder, Icons.school, Icons.campaign, Icons.meeting_room_outlined, Icons.person];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController();
    _middleNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _phoneController = TextEditingController();
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
    _roomCodeController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseData() async {
    setState(() => isLoading = true);
    try {
      // Use the singleton — avoids opening a conflicting connection to teacher_data.db
      final teacherDb = await ActivityDatabase.instance.database;

      // Check if guardian has joined a room
      final joinedRoom = await ActivityDatabase.instance.getJoinedRoom(widget.loggedInEmail);

      List<Map<String, dynamic>> activityMaps = [];
      List<Map<String, dynamic>> announcementMaps = [];

      // Only load activities/announcements if guardian has joined a room
      if (joinedRoom != null) {
        activityMaps = await teacherDb.query('activities', orderBy: 'id DESC');
        announcementMaps = await teacherDb.query('announcements', orderBy: 'id DESC');
      }

      final adminDb = await DatabaseHelper.instance.database;

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

      final List<Map<String, dynamic>> guardianMaps = await adminDb.query(
        'users',
        where: 'email = ?',
        whereArgs: [widget.loggedInEmail],
        limit: 1,
      );

      if (guardianMaps.isNotEmpty) {
        final data = guardianMaps.first;
        currentGuardianId = data['id'] as int?;
        setState(() {
          _profileData['firstName'] = (data['firstName'] ?? '').toString();
          _profileData['middleName'] = (data['middleName'] ?? '').toString();
          _profileData['lastName'] = (data['lastName'] ?? '').toString();
          _profileData['phone'] = (data['phone'] ?? '').toString();
          _profileData['id'] = currentGuardianId?.toString() ?? '';
          _firstNameController.text = _profileData['firstName']!;
          _middleNameController.text = _profileData['middleName']!;
          _lastNameController.text = _profileData['lastName']!;
          _phoneController.text = _profileData['phone']!;
        });
      }

      if (currentGuardianId != null) {
        final List<Map<String, dynamic>> links = await adminDb.rawQuery('''
          SELECT s.* FROM students s
          JOIN guardian_students gs ON s.id = gs.student_id
          WHERE gs.guardian_id = ?
          AND s.status = 'Active'
        ''', [currentGuardianId]);
        linkedStudents = links;
      }

      // Do NOT close teacherDb — it's the singleton, closing it breaks other sessions

      setState(() {
        _joinedRoom = joinedRoom;
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
      final adminDb = await DatabaseHelper.instance.database;
      await adminDb.update(
        'users',
        {'phone': _profileData['phone']},
        where: 'email = ?',
        whereArgs: [widget.loggedInEmail],
      );
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  void _initGuardianGrades() {
    for (var studentMap in linkedStudents) {
      String studentKey = '${studentMap['firstName']} ${studentMap['lastName']}';
      _studentGrades[studentKey] = {};
      for (var activity in _activities) {
        String key = '${activity['title']}_${activity['date']}';
        _studentGrades[studentKey]![key] = {
          'grade': 85.0,
          'maxScore': 100.0,
          'status': 'Graded'
        };
      }
    }
    setState(() {});
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

  Future<void> _unlinkStudent(Map<String, dynamic> student) async {
    final studentId = student['id'] as int;
    final fullName = _formatFullName(student);
    final guardianId = currentGuardianId ?? 1;

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Are you sure you want to remove $fullName from your linked students?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final adminDb = await DatabaseHelper.instance.database;
      await adminDb.delete(
        'guardian_students',
        where: 'guardian_id = ? AND student_id = ?',
        whereArgs: [guardianId, studentId],
      );

      setState(() {
        linkedStudents.removeWhere((s) => s['id'] == studentId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fullName removed.'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing student: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _linkStudent() async {
    final int guardianId = currentGuardianId ?? 1;

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

      await adminDb.execute('''
        CREATE TABLE IF NOT EXISTS guardian_students (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          guardian_id INTEGER NOT NULL,
          student_id INTEGER NOT NULL,
          created_at TEXT DEFAULT (datetime('now')),
          UNIQUE(guardian_id, student_id)
        )
      ''');

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

      final count = Sqflite.firstIntValue(await adminDb.rawQuery(
        'SELECT COUNT(*) as count FROM guardian_students WHERE guardian_id = ? AND student_id = ?',
        [guardianId, studentId],
      )) ?? 0;

      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already linked'), backgroundColor: Colors.orange),
        );
        return;
      }

      await adminDb.insert('guardian_students', {
        'guardian_id': guardianId,
        'student_id': studentId,
      });

      final links = await adminDb.rawQuery('''
        SELECT s.* FROM students s
        JOIN guardian_students gs ON s.id = gs.student_id
        WHERE gs.guardian_id = ? AND s.status = 'Active'
        ORDER BY s.lastName
      ''', [guardianId]);

      setState(() => linkedStudents = links);

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
            Text("Account ID: ${_formattedAccountId}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
      case 3: return _roomSection();
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final fullName = _getFullName;
    final email = widget.loggedInEmail;

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: bottomInset > 0 ? bottomInset + 80 : 24),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
          const SizedBox(height: 24),
          _buildProfileField('Account ID', _formattedAccountId, isEditable: false),
          _buildProfileField('Full Name', fullName, isEditable: false),
          _buildProfileField('Email Address', email, isEditable: false),
          _buildProfileField('Phone Number', '+63 ${_profileData['phone'] ?? ''}',
            controller: _phoneController, isEditing: isEditing,
            hint: '+63 9XXX XXXX XXXX', keyboardType: TextInputType.phone,
            formatters: [LengthLimitingTextInputFormatter(17)],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (isEditing) {
                  setState(() { _profileData['phone'] = _phoneController.text.trim(); isEditing = false; });
                  await _updateProfileInDatabase();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                } else {
                  setState(() => isEditing = true);
                }
              },
              icon: Icon(isEditing ? Icons.save : Icons.edit),
              label: Text(isEditing ? 'Save Profile' : 'Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileField(String label, String value, {
    TextEditingController? controller, bool isEditing = false, bool isEditable = true,
    String? hint, TextInputType? keyboardType, List<TextInputFormatter>? formatters,
  }) {
    final bool showInput = isEditing && isEditable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          if (showInput)
            TextField(
              controller: controller, keyboardType: keyboardType, inputFormatters: formatters,
              decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
            )
          else
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isEditable ? (widget.isDarkMode ? Colors.grey[800] : Colors.grey[100]) : (widget.isDarkMode ? Colors.grey[850] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
                border: isEditable ? null : Border.all(color: Colors.grey[400]!, width: 0.5),
              ),
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isEditable ? (widget.isDarkMode ? Colors.white : Colors.black87) : Colors.grey[600])),
            ),
        ],
      ),
    );
  }

  Widget _noRoomJoinedWall() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No room joined yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Go to "Room" and enter the room code given by your teacher to view activities and announcements.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => selectedIndex = 3),
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Go to Room'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activitySection() {
    if (_joinedRoom == null) return _genericSection('Teacher Activities', _noRoomJoinedWall());
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
    if (_joinedRoom == null) return _genericSection('Announcements', _noRoomJoinedWall());
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

  Widget _roomSection() {
    return _genericSection('Room', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),

            if (_joinedRoom == null) ...[
              // Not in a room — show join UI
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Join a Room', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Enter the 6-character code given by your teacher.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _roomCodeController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'XXXXXX',
                        hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 6),
                        filled: true,
                        fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLinking ? null : _joinRoom,
                        icon: isLinking
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login),
                        label: Text(isLinking ? 'Joining...' : 'Join Room'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Already in a room — show room info
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.meeting_room, size: 48, color: Colors.blue),
                    const SizedBox(height: 12),
                    Text(_joinedRoom!['title'] ?? 'Classroom', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text('Room Code: ${_joinedRoom!['code']}', style: const TextStyle(fontSize: 16, letterSpacing: 4, color: Colors.blue, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('You are connected to this teacher\'s room.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _leaveRoom,
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        label: const Text('Leave Room', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a 6-character room code'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => isLinking = true);
    try {
      // --- DIAGNOSTIC: show everything in the DB ---
      final db = await ActivityDatabase.instance.database;
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
      debugPrint('=== TABLES IN teacher_data.db: $tables');
      try {
        final allRooms = await db.query('rooms');
        debugPrint('=== ALL ROOMS: $allRooms');
        debugPrint('=== GUARDIAN TRYING CODE: "$code"');
      } catch (e) {
        debugPrint('=== rooms table does not exist: $e');
      }
      // --- END DIAGNOSTIC ---

      final success = await ActivityDatabase.instance.joinRoom(code, widget.loggedInEmail);
      if (success) {
        final room = await ActivityDatabase.instance.getJoinedRoom(widget.loggedInEmail);
        setState(() {
          _joinedRoom = room;
          isLinking = false;
        });
        _roomCodeController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined room: ${room?['title'] ?? code}'), backgroundColor: Colors.green),
          );
        }
        await _fetchDatabaseData();
      } else {
        setState(() => isLinking = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Room not found. Check the code and try again.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => isLinking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  Future<void> _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this room? You will no longer see activities and announcements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ActivityDatabase.instance.leaveRoom(widget.loggedInEmail);
    setState(() {
      _joinedRoom = null;
      _activities = [];
      _announcements = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the room.')),
      );
    }
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
          if (activity['filePath'] != null && (activity['filePath'] as String).isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 18, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activity['fileName'] ?? 'Attached file',
                      style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }
}