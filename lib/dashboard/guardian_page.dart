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

  List<Map<String, dynamic>> _joinedRooms = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> _allAttendance = [];
  final List<Map<String, String>> _myRegisteredStudents = [];

  // Room state
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

  final List<String> menuTitles = ['Rooms', 'Student Grades', 'Attendance', 'Profile'];
  final List<IconData> menuIcons = [Icons.meeting_room_outlined, Icons.school, Icons.calendar_today, Icons.person];

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
      final teacherDb = await ActivityDatabase.instance.database;

      // Load ALL rooms this guardian joined
      final joinedRooms = await ActivityDatabase.instance.getJoinedRooms(widget.loggedInEmail);

      List<Map<String, dynamic>> activityMaps = [];
      List<Map<String, dynamic>> announcementMaps = [];

      if (joinedRooms.isNotEmpty) {
        final roomCodes = joinedRooms.map((r) => "'${r['code']}'").join(',');
        // Only load activities/announcements from joined rooms
        final allActivities = await teacherDb.query('activities', orderBy: 'id DESC');
        final allAnnouncements = await teacherDb.query('announcements', orderBy: 'id DESC');
        activityMaps = allActivities.where((a) =>
            roomCodes.contains("'${a['roomCode']}'")).toList();
        announcementMaps = allAnnouncements.where((a) =>
            roomCodes.contains("'${a['roomCode']}'")).toList();
      }

      // Load real grades from DB
      final allGrades = await ActivityDatabase.instance.getAllGrades();
      final allAttendance = await ActivityDatabase.instance.getAllAttendance();

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
        'users', where: 'email = ?', whereArgs: [widget.loggedInEmail], limit: 1,
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
          WHERE gs.guardian_id = ? AND s.status = 'Active'
        ''', [currentGuardianId]);
        linkedStudents = links;
      }

      setState(() {
        _joinedRooms = List<Map<String, dynamic>>.from(joinedRooms);
        _activities = activityMaps;
        _announcements = announcementMaps;
        _allAttendance = List<Map<String, dynamic>>.from(allAttendance);
        _initGuardianGrades(allGrades);
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

  void _initGuardianGrades(List<Map<String, dynamic>> allGrades) {
    _studentGrades = {};

    // Guardian's own name — teacher keys grades by guardian's name (from room_members → users table)
    final guardianName = _getFullName.trim();
    // Capitalized version (teacher applies _capitalizeName)
    final guardianNameCapitalized = guardianName.split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');

    for (var studentMap in linkedStudents) {
      final fullName = _formatFullName(studentMap);
      final firstLast = '${studentMap['firstName'] ?? ''} ${studentMap['lastName'] ?? ''}'.trim();
      _studentGrades[fullName] = {};

      for (var activity in _activities) {
        final key = '${activity['title']}_${activity['date']}';
        // Teacher keys grade by guardian's name (not student's name)
        // Try: guardian name, guardian capitalized, student fullName, student firstLast
        final gradeRow = allGrades.where((g) {
          final sn = (g['studentName'] ?? '').toString().trim();
          final ak = (g['activityKey'] ?? '').toString();
          return ak == key && (
              sn == guardianName ||
                  sn == guardianNameCapitalized ||
                  sn.toLowerCase() == guardianName.toLowerCase() ||
                  sn == fullName ||
                  sn == firstLast ||
                  sn.toLowerCase() == fullName.toLowerCase() ||
                  sn.toLowerCase() == firstLast.toLowerCase()
          );
        }).firstOrNull;

        _studentGrades[fullName]![key] = {
          'grade': gradeRow?['grade'],
          'maxScore': 100.0,
          'status': gradeRow?['status'] ?? 'Pending',
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
            ListTile(
              leading: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode, color: widget.isDarkMode ? const Color(0xFFFFE082) : Colors.black54),
              title: Text(widget.isDarkMode ? 'Light Mode' : 'Dark Mode', style: TextStyle(color: widget.isDarkMode ? const Color(0xFFFFE082) : null)),
              trailing: Switch(
                value: widget.isDarkMode,
                onChanged: (_) => widget.toggleTheme(),
                activeColor: widget.isDarkMode ? const Color(0xFFFFE082) : null,
                activeTrackColor: widget.isDarkMode ? const Color(0xFFFFE082).withOpacity(0.4) : null,
              ),
            ),
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
      case 0: return _roomsSection();
      case 1: return _studentGradesSection();
      case 2: return _attendanceSection();
      case 3: return _genericSection('Guardian Profile', _profileContent());
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
          _buildProfileField('Phone Number', _profileData['phone']?.isNotEmpty == true ? '+63 ${_profileData['phone']}' : 'Not set',
            controller: _phoneController, isEditing: isEditing,
            hint: '9XX XXXX XXXX', keyboardType: TextInputType.phone,
            formatters: [PhoneNumberFormatter()],
            prefix: '+63 ',
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (isEditing) {
                  // Save: strip any non-digit chars, store raw digits after +63
                  final raw = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
                  setState(() { _profileData['phone'] = raw; isEditing = false; });
                  await _updateProfileInDatabase();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                } else {
                  // Pre-fill controller with existing digits (without +63)
                  final existing = (_profileData['phone'] ?? '').toString().replaceAll(RegExp(r'[^\d]'), '');
                  _phoneController.text = existing.isEmpty ? '9' : existing;
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
    String? prefix,
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
              decoration: InputDecoration(
                hintText: hint,
                prefixText: prefix,
                prefixStyle: const TextStyle(fontWeight: FontWeight.w500),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
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
            Text('Go to "Rooms" and enter the room code given by your teacher.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey[500])),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() => selectedIndex = 0),
              icon: const Icon(Icons.meeting_room_outlined),
              label: const Text('Go to Rooms'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomsSection() {
    return _genericSection('Rooms', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 16),
          // Join a new room
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Join a Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _roomCodeController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 4),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: 'XXXXXX',
                      hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 4),
                      filled: true,
                      fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: isLinking ? null : _joinRoom,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                  child: isLinking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Join'),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          if (_joinedRooms.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('No rooms joined yet.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 8),
                Text('Enter a room code above to join your teacher\'s room.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ]),
            ))
          else
            ...(_joinedRooms.map((room) {
              final roomCode = room['code'].toString();
              final roomActivities = _activities.where((a) => a['roomCode'] == roomCode).toList();
              final roomAnnouncements = _announcements.where((a) => a['roomCode'] == roomCode).toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.blue.withOpacity(0.07),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => GuardianRoomDetailPage(
                      room: room,
                      activities: roomActivities,
                      announcements: roomAnnouncements,
                      studentGrades: _studentGrades,
                      linkedStudents: linkedStudents,
                      isDarkMode: widget.isDarkMode,
                    ),
                  )),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      const Icon(Icons.meeting_room, color: Colors.blue, size: 36),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(room['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${roomActivities.length} activities • ${roomAnnouncements.length} announcements', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ])),
                      // Leave button
                      GestureDetector(
                        onTap: () => _leaveSpecificRoom(room),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Leave', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            })).toList(),
          const SizedBox(height: 80),
        ],
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
    // Check if already joined this room
    if (_joinedRooms.any((r) => r['code'].toString() == code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already joined this room.'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => isLinking = true);
    try {
      final success = await ActivityDatabase.instance.joinRoom(code, widget.loggedInEmail);
      if (success) {
        _roomCodeController.clear();
        await _fetchDatabaseData();
        if (mounted) {
          final joined = _joinedRooms.firstWhere((r) => r['code'] == code, orElse: () => {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Joined room: ${joined['title'] ?? code}'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Room not found. Check the code and try again.'), backgroundColor: Colors.orange, duration: Duration(seconds: 4)),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLinking = false);
    }
  }

  Future<void> _leaveSpecificRoom(Map<String, dynamic> room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Room'),
        content: Text('Leave "${room['title']}"? You won\'t see its activities anymore.'),
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
    await ActivityDatabase.instance.leaveRoomByCode(room['code'].toString(), widget.loggedInEmail);
    await _fetchDatabaseData();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left the room.')));
  }

  Widget _attendanceSection() {
    if (_joinedRooms.isEmpty) return _genericSection('Attendance', _noRoomJoinedWall());

    final guardianName = _getFullName.trim();
    final guardianNameCap = guardianName.split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');

    // All records matching this guardian
    final allRecords = _allAttendance.where((r) {
      final sn = (r['studentName'] ?? '').toString().trim();
      return sn == guardianName || sn == guardianNameCap ||
          sn.toLowerCase() == guardianName.toLowerCase();
    }).toList();

    // Overall counts across all rooms
    final totalPresent = allRecords.where((r) => r['status'] == 'Present').length;
    final totalAbsent = allRecords.where((r) => r['status'] == 'Absent').length;
    final totalLate = allRecords.where((r) => r['status'] == 'Late').length;
    final totalAll = allRecords.length;

    return _genericSection('Attendance', RefreshIndicator(
      onRefresh: _fetchDatabaseData,
      child: allRecords.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No attendance records yet.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
      ]))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          // 1. Overall summary
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _attendanceStat('Total', totalAll.toString(), Colors.blue),
              _attendanceStat('Present', totalPresent.toString(), Colors.green),
              _attendanceStat('Late', totalLate.toString(), Colors.orange.shade700),
              _attendanceStat('Absent', totalAbsent.toString(), Colors.red),
            ]),
          ),
          // 2. Per-room: room name → records
          ..._joinedRooms.map((room) {
            final roomCode = room['code'].toString();
            final roomTitle = room['title']?.toString() ?? roomCode;
            final isFirstRoom = roomCode == _joinedRooms.first['code'].toString();

            final roomRecords = allRecords.where((r) {
              final rc = (r['roomCode'] ?? '').toString().trim();
              return rc == roomCode || (rc.isEmpty && isFirstRoom);
            }).toList();

            if (roomRecords.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Room name header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.meeting_room, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.blue)),
                  ]),
                ),
                const SizedBox(height: 10),
                // Attendance records
                ...roomRecords.map((r) {
                  final status = (r['status'] ?? '').toString();
                  final date = (r['date'] ?? '').toString();
                  Color statusColor = Colors.grey[500]!;
                  IconData statusIcon = Icons.radio_button_unchecked;
                  if (status == 'Present') { statusColor = Colors.green; statusIcon = Icons.check_circle; }
                  else if (status == 'Late') { statusColor = Colors.orange.shade700; statusIcon = Icons.watch_later; }
                  else if (status == 'Absent') { statusColor = Colors.red; statusIcon = Icons.cancel; }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(10),
                      color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 10),
                      Expanded(child: Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Icon(statusIcon, size: 18, color: statusColor),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor)),
                      ),
                    ]),
                  );
                }).toList(),
              ]),
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
      ),
    ));
  }

  Widget _attendanceStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }

  Widget _studentGradesSection() {
    if (_joinedRooms.isEmpty) return _genericSection('Student Grades', _noRoomJoinedWall());
    if (linkedStudents.isEmpty) {
      return _genericSection('Student Grades', Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No linked students.', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          ]),
        ),
      ));
    }

    return _genericSection('Student Grades', ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: linkedStudents.length,
      itemBuilder: (context, si) {
        final student = linkedStudents[si];
        final name = _formatFullName(student);
        final grades = _studentGrades[name] ?? {};

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text(name[0].toUpperCase())),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((student['lrn'] ?? 0) != 0)
                Text('LRN: ${_formatLRN(student['lrn'] as int)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
            children: [
              // Per-room breakdown
              ..._joinedRooms.map((room) {
                final roomCode = room['code'].toString();
                final roomTitle = room['title']?.toString() ?? roomCode;
                final roomActivities = _activities.where((a) => a['roomCode'] == roomCode).toList();

                if (roomActivities.isEmpty) return const SizedBox.shrink();

                // Per-room average
                double roomTotal = 0; int roomGraded = 0;
                for (final act in roomActivities) {
                  final key = '${act['title']}_${act['date']}';
                  final data = grades[key] ?? {};
                  final s = (data['status'] ?? 'Pending') as String;
                  if ((s == 'Completed' || s == 'Late') && data['grade'] != null) {
                    roomTotal += (data['grade'] as double); roomGraded++;
                  }
                }
                final roomAvg = roomGraded > 0 ? (roomTotal / roomGraded).toStringAsFixed(1) : '—';

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Room header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.meeting_room, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Expanded(child: Text(roomTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.blue))),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    // Activities in this room
                    ...roomActivities.map((act) {
                      final key = '${act['title']}_${act['date']}';
                      final gradeData = grades[key] ?? {};
                      final rawGrade = gradeData['grade'];
                      final status = (gradeData['status'] ?? 'Pending') as String;
                      final scoreText = status == 'Missed' ? '0 / 100'
                          : rawGrade != null ? '${(rawGrade as double).toStringAsFixed(0)} / 100'
                          : 'Not graded';
                      Color statusColor = Colors.grey[500]!;
                      if (status == 'Completed') statusColor = Colors.green;
                      else if (status == 'Late') statusColor = Colors.orange.shade700;
                      else if (status == 'Missed') statusColor = Colors.red;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: widget.isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                          color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[50],
                        ),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text(act['date'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                            ),
                            const SizedBox(height: 4),
                            Text(scoreText, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ]),
                        ]),
                      );
                    }).toList(),
                    // Per-room average
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Average', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green, fontSize: 13)),
                        Text('$roomAvg / 100', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ));
  }
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
// ── Guardian Room Detail Page ─────────────────────────────────────────────

class GuardianRoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> announcements;
  final Map<String, Map<String, Map<String, dynamic>>> studentGrades;
  final List<Map<String, dynamic>> linkedStudents;
  final bool isDarkMode;

  const GuardianRoomDetailPage({
    super.key,
    required this.room,
    required this.activities,
    required this.announcements,
    required this.studentGrades,
    required this.linkedStudents,
    required this.isDarkMode,
  });

  @override
  State<GuardianRoomDetailPage> createState() => _GuardianRoomDetailPageState();
}

class _GuardianRoomDetailPageState extends State<GuardianRoomDetailPage> {
  int _tabIndex = 0;

  String _formatFullName(Map<String, dynamic> s) {
    final first = (s['firstName'] ?? '').toString().trim();
    final mid = (s['middleName'] ?? '').toString().trim();
    final last = (s['lastName'] ?? '').toString().trim();
    return mid.isEmpty ? '$first $last'.trim() : '$first $mid $last'.trim();
  }

  void _showImagePreview(BuildContext ctx, List<String> paths, int initial) {
    final controller = PageController(initialPage: initial);
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          PageView.builder(
            controller: controller,
            itemCount: paths.length,
            itemBuilder: (_, i) {
              final f = File(paths[i]);
              return Center(
                child: f.existsSync()
                    ? InteractiveViewer(child: Image.file(f, fit: BoxFit.contain))
                    : const Icon(Icons.broken_image, color: Colors.white, size: 64),
              );
            },
          ),
          Positioned(
            top: 12, right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (paths.length > 1)
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: Center(child: Text('${initial + 1} / ${paths.length}', style: const TextStyle(color: Colors.white70, fontSize: 13))),
            ),
        ]),
      ),
    );
  }

  Widget _tab(String label, int idx) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        height: 46, alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _tabIndex == idx ? Colors.white : Colors.transparent, width: 3)),
        ),
        child: Text(label, style: TextStyle(
            color: _tabIndex == idx ? Colors.white : Colors.white60,
            fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.room['title'] ?? 'Room', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Row(children: [
            _tab('Activities (${widget.activities.length})', 0),
            _tab('Announcements', 1),
          ]),
        ),
      ),
      body: _tabIndex == 0 ? _buildActivities() : _buildAnnouncements(),
    );
  }

  Widget _buildActivities() {
    if (widget.activities.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No activities posted yet.', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.activities.length,
      itemBuilder: (context, i) {
        final act = widget.activities[i];
        final deadline = (act['deadline'] ?? '').toString();
        final hasDeadline = deadline.isNotEmpty;
        final isOverdue = hasDeadline && DateTime.tryParse(deadline)?.isBefore(DateTime.now()) == true;
        final imagePaths = (act['filePath'] ?? '').toString().split('|').where((s) => s.isNotEmpty).toList();

        // Get student status for this activity
        String studentStatus = 'Pending';
        Color statusColor = Colors.grey[500]!;
        for (final student in widget.linkedStudents) {
          final name = _formatFullName(student);
          final firstLast = '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
          final key = '${act['title']}_${act['date']}';
          final gradeData = widget.studentGrades[name]?[key]
              ?? widget.studentGrades[firstLast]?[key] ?? {};
          studentStatus = (gradeData['status'] ?? 'Pending') as String;
          if (studentStatus == 'Completed') statusColor = Colors.green;
          else if (studentStatus == 'Late') statusColor = Colors.orange.shade700;
          else if (studentStatus == 'Missed') statusColor = Colors.red;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => GuardianActivityDetailPage(
                activity: act,
                studentStatus: studentStatus,
                statusColor: statusColor,
                isDarkMode: widget.isDarkMode,
                studentGrades: widget.studentGrades,
                linkedStudents: widget.linkedStudents,
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const CircleAvatar(backgroundColor: Colors.blue, radius: 18, child: Icon(Icons.assignment, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Posted: ${act['date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if (hasDeadline) ...[
                    const SizedBox(height: 4),
                    Text(isOverdue ? '⚠ Overdue: $deadline' : 'Due: $deadline',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : Colors.orange)),
                  ],
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: statusColor.withOpacity(0.4))),
                    child: Text(studentStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                  ),
                  if (imagePaths.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [const Icon(Icons.image, size: 12, color: Colors.grey), const SizedBox(width: 2), Text('${imagePaths.length}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                  ],
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnnouncements() {
    if (widget.announcements.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No announcements yet.', style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.announcements.length,
      itemBuilder: (context, i) {
        final ann = widget.announcements[i];
        final imagePaths = (ann['imagePaths'] ?? '').toString().split('|').where((s) => s.isNotEmpty).toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => GuardianAnnouncementDetailPage(
                announcement: ann,
                isDarkMode: widget.isDarkMode,
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const CircleAvatar(backgroundColor: Colors.orange, radius: 18, child: Icon(Icons.campaign, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(ann['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if ((ann['message'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(ann['message'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (imagePaths.isNotEmpty)
                    Row(children: [const Icon(Icons.image, size: 12, color: Colors.grey), const SizedBox(width: 2), Text('${imagePaths.length}', style: const TextStyle(fontSize: 11, color: Colors.grey))]),
                ]),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ── Guardian Activity Detail Page ────────────────────────────────────────────
class GuardianActivityDetailPage extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String studentStatus;
  final Color statusColor;
  final bool isDarkMode;
  final Map<String, Map<String, Map<String, dynamic>>> studentGrades;
  final List<Map<String, dynamic>> linkedStudents;

  const GuardianActivityDetailPage({
    super.key,
    required this.activity,
    required this.studentStatus,
    required this.statusColor,
    required this.isDarkMode,
    required this.studentGrades,
    required this.linkedStudents,
  });

  String _formatFullName(Map<String, dynamic> s) {
    final first = (s['firstName'] ?? '').toString().trim();
    final mid = (s['middleName'] ?? '').toString().trim();
    final last = (s['lastName'] ?? '').toString().trim();
    return mid.isEmpty ? '$first $last'.trim() : '$first $mid $last'.trim();
  }

  void _showImagePreview(BuildContext ctx, List<String> paths, int initial) {
    final controller = PageController(initialPage: initial);
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          PageView.builder(
            controller: controller,
            itemCount: paths.length,
            itemBuilder: (_, i) {
              final f = File(paths[i]);
              return Center(
                child: f.existsSync()
                    ? InteractiveViewer(child: Image.file(f, fit: BoxFit.contain))
                    : const Icon(Icons.broken_image, color: Colors.white, size: 64),
              );
            },
          ),
          Positioned(top: 12, right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 20)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deadline = (activity['deadline'] ?? '').toString();
    final hasDeadline = deadline.isNotEmpty;
    final isOverdue = hasDeadline && DateTime.tryParse(deadline)?.isBefore(DateTime.now()) == true;
    final imagePaths = (activity['filePath'] ?? '').toString().split('|').where((s) => s.isNotEmpty).toList();
    final key = '${activity['title']}_${activity['date']}';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(activity['title'] ?? 'Activity', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header info
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Posted: ${activity['date'] ?? ''}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              if (hasDeadline) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isOverdue ? Colors.red : Colors.orange),
                  ),
                  child: Text(isOverdue ? '⚠ Overdue: $deadline' : 'Due: $deadline',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : Colors.orange)),
                ),
              ],
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.4))),
              child: Text(studentStatus, style: TextStyle(fontWeight: FontWeight.w700, color: statusColor)),
            ),
          ]),
          // Description
          if ((activity['description'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(activity['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.5)),
          ],
          // Images
          if (imagePaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...imagePaths.map((path) {
              final f = File(path);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _showImagePreview(context, imagePaths, imagePaths.indexOf(path)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: f.existsSync()
                        ? Image.file(f, width: double.infinity, fit: BoxFit.cover)
                        : Container(height: 120, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))),
                  ),
                ),
              );
            }).toList(),
          ],
        ]),
      ),
    );
  }
}

// ── Guardian Announcement Detail Page ────────────────────────────────────────
class GuardianAnnouncementDetailPage extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final bool isDarkMode;

  const GuardianAnnouncementDetailPage({
    super.key,
    required this.announcement,
    required this.isDarkMode,
  });

  void _showImagePreview(BuildContext ctx, List<String> paths, int initial) {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(children: [
          PageView.builder(
            controller: PageController(initialPage: initial),
            itemCount: paths.length,
            itemBuilder: (_, i) {
              final f = File(paths[i]);
              return Center(
                child: f.existsSync()
                    ? InteractiveViewer(child: Image.file(f, fit: BoxFit.contain))
                    : const Icon(Icons.broken_image, color: Colors.white, size: 64),
              );
            },
          ),
          Positioned(top: 12, right: 12,
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 20)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagePaths = (announcement['imagePaths'] ?? '').toString().split('|').where((s) => s.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: Text(announcement['title'] ?? 'Announcement', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(announcement['date'] ?? '', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          if ((announcement['message'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(announcement['message'] ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
          ],
          if (imagePaths.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Attachments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            ...imagePaths.map((path) {
              final f = File(path);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _showImagePreview(context, imagePaths, imagePaths.indexOf(path)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: f.existsSync()
                        ? Image.file(f, width: double.infinity, fit: BoxFit.cover)
                        : Container(height: 120, color: Colors.grey[200], child: const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 40))),
                  ),
                ),
              );
            }).toList(),
          ],
        ]),
      ),
    );
  }
}
// ── Phone Number Formatter ────────────────────────────────────────────────
// Formats input as: 9XX XXXX XXXX (prefix +63 shown separately)
// Enforces starts with 9, max 11 digits total
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue val) {
    // Strip all non-digits
    String digits = val.text.replaceAll(RegExp(r'[^\d]'), '');

    // Always enforce starts with 9
    if (digits.isEmpty) digits = '9';
    if (!digits.startsWith('9')) digits = '9' + digits.replaceAll('9', '');

    // Limit to 11 digits (9 + 10 more)
    if (digits.length > 11) digits = digits.substring(0, 11);

    // Format: 9XX XXXX XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 7) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}