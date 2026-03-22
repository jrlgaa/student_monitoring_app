import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:project/database/teacher_db.dart';

class TeacherPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final String loggedInEmail;

  const TeacherPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
    required this.loggedInEmail,
  });

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  late AnimationController _pageController;
  late Animation<double>   _pageFade;
  late Animation<Offset>   _pageSlide;

  // ── Design tokens (mirrors admin/guardian) ──────────────────────────────
  static const Color _primaryBlue  = Color(0xFF2563EB);
  static const Color _accentIndigo = Color(0xFF4F46E5);
  static const Color _successGreen = Color(0xFF059669);
  static const Color _warningAmber = Color(0xFFD97706);
  static const Color _dangerRed    = Color(0xFFDC2626);
  static const Color _teal         = Color(0xFF0891B2);

  Color get _surfaceColor  => widget.isDarkMode ? const Color(0xFF1E1E2E) : const Color(0xFFF8FAFC);
  Color get _cardColor     => widget.isDarkMode ? const Color(0xFF2A2A3E) : Colors.white;
  Color get _sidebarColor  => widget.isDarkMode ? const Color(0xFF16162A) : const Color(0xFF1E293B);
  Color get _textPrimary   => widget.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _textSecondary => widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _dividerColor  => widget.isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _fieldFill     => widget.isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _announcements = [];
  List<String> students = [];

  final TextEditingController _activityTitleController = TextEditingController();
  final TextEditingController _activityDescController = TextEditingController();
  final TextEditingController _announcementTitleController = TextEditingController();
  final TextEditingController _announcementMessageController = TextEditingController();
  final TextEditingController _studentSearchController = TextEditingController();

  late final TextEditingController _editActivityTitleController;
  late final TextEditingController _editActivityDescController;
  late final TextEditingController _editAnnouncementTitleController;
  late final TextEditingController _editAnnouncementMessageController;

  // Initialized with placeholders; will be populated from DB
  Map<String, dynamic> teacherProfile = {
    'name': 'Loading...',
    'teacherId': '',
    'email': '',
    'phone': '',
    'subject': '',
    'advisoryClass': '',
  };
  bool isEditing = false;

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _advisoryClassController;

  final List<String> menuTitles = [
    'Rooms',
    'Attendance',
  ];

  final List<IconData> menuIcons = [
    Icons.meeting_room_outlined,
    Icons.calendar_month,
  ];

  final Map<int, String> attendanceStatus = {};
  DateTime _selectedAttendanceDate = DateTime.now();
  final Map<String, Map<int, String>> _attendanceRecords = {};
  Map<int, String> _currentAttendance = {};

  String? selectedStudent;
  Map<String, List<Map<String, dynamic>>> _studentActivities = {};
  Map<String, Map<String, Map<String, dynamic>>> _studentGrades = {};
  Set<String> _expandedStudents = {};
  Map<String, Map<String, TextEditingController>> _gradeControllers = {};
  final double _defaultMaxScore = 100.0;

  String? _profileImagePath; // local path to the picked profile picture

  // Room state
  List<Map<String, dynamic>> _rooms = [];
  Map<String, dynamic>? _selectedAttendanceRoom;
  // Students per room: roomCode -> list of student names
  Map<String, List<String>> _roomStudents = {};
  final TextEditingController _roomTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _editActivityTitleController = TextEditingController();
    _editActivityDescController = TextEditingController();
    _editAnnouncementTitleController = TextEditingController();
    _editAnnouncementMessageController = TextEditingController();

    // Controllers initialized as empty; will be updated in _fetchDatabaseContent
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _advisoryClassController = TextEditingController();

    _pageController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _pageFade  = CurvedAnimation(parent: _pageController, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));
    _pageController.forward();
    _fetchDatabaseContent();
  }

  // Helper to capitalize every word in a name (First, Middle, Last)
  String _capitalizeName(String text) {
    if (text.trim().isEmpty) return text;
    return text
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  // Helper to highlight matching text in search results
  Widget _highlightText(String fullText, String query) {
    if (query.isEmpty || !fullText.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        fullText,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: widget.isDarkMode ? Colors.white : Colors.black,
        ),
      );
    }

    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;

    String lowerFullText = fullText.toLowerCase();
    String lowerQuery = query.toLowerCase();

    while ((indexOfMatch = lowerFullText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: fullText.substring(start, indexOfMatch)));
      }
      spans.add(TextSpan(
        text: fullText.substring(indexOfMatch, indexOfMatch + query.length),
        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      ));
      start = indexOfMatch + query.length;
    }

    if (start < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: widget.isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
        ),
        children: spans,
      ),
    );
  }

  void _addStudentToState(String studentName) {
    String formattedName = _capitalizeName(studentName);
    if (!students.contains(formattedName)) {
      setState(() {
        students.add(formattedName);
        _studentActivities[formattedName] = List<Map<String, dynamic>>.from(_activities);
        _studentGrades[formattedName] = {};
        _gradeControllers[formattedName] = {};

        for (var activity in _activities) {
          String key = _getActivityKey(activity);
          _studentGrades[formattedName]![key] = {
            'grade': null,
            'maxScore': _defaultMaxScore,
            'status': 'Pending'
          };
          _gradeControllers[formattedName]![key] = TextEditingController();
        }
      });
    }
  }

  void _showAddStudentDialog() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'user_data.db');
      final db = await openDatabase(path);

      final List<Map<String, dynamic>> allAvailableStudents = await db.query('students');

      List<Map<String, dynamic>> filteredStudents = List.from(allAvailableStudents);
      String currentDialogQuery = "";

      filteredStudents.sort((a, b) =>
          (a['firstName'] ?? '').toString().toLowerCase()
              .compareTo((b['firstName'] ?? '').toString().toLowerCase()));

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Add Student to Class'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Name or LRN',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        currentDialogQuery = value;
                        filteredStudents = allAvailableStudents.where((student) {
                          final fullName = "${student['firstName']} ${student['middleName'] ?? ''} ${student['lastName']}".toLowerCase();
                          final lrn = (student['lrn'] ?? '').toString().toLowerCase();
                          return value.isEmpty || fullName.contains(value.toLowerCase()) || lrn.contains(value.toLowerCase());
                        }).toList();
                        filteredStudents.sort((a, b) =>
                            (a['firstName'] ?? '').toString().toLowerCase()
                                .compareTo((b['firstName'] ?? '').toString().toLowerCase()));
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredStudents.isEmpty
                        ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          currentDialogQuery.isEmpty ? "No students found." : "No results found for '$currentDialogQuery'.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ),
                    )
                        : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = filteredStudents[index];
                        final String rawFullName = "${student['firstName']} ${student['middleName'] ?? ''} ${student['lastName']}";
                        final String formattedFullName = _capitalizeName(rawFullName);
                        return ListTile(
                          title: _highlightText(formattedFullName, currentDialogQuery),
                          subtitle: Text("LRN: ${student['lrn']}"),
                          trailing: const Icon(Icons.add, color: Colors.green),
                          onTap: () {
                            _addStudentToState(formattedFullName);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$formattedFullName added to class')),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing admin data: $e')),
      );
    }
  }

  String _getActivityKey(Map<String, dynamic> activity) {
    return '${activity['title']}_${activity['date']}';
  }

  void _openSidebar() => setState(() => isSidebarOpen = true);
  void _closeSidebar() => setState(() => isSidebarOpen = false);

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: isError ? _dangerRed : _successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  void dispose() {
    for (String student in _gradeControllers.keys) {
      for (String key in _gradeControllers[student]!.keys) {
        _gradeControllers[student]![key]!.dispose();
      }
    }
    _activityTitleController.dispose();
    _activityDescController.dispose();
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    _studentSearchController.dispose();
    _editActivityTitleController.dispose();
    _editActivityDescController.dispose();
    _editAnnouncementTitleController.dispose();
    _editAnnouncementMessageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _advisoryClassController.dispose();
    _roomTitleController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(bottom: false, child: _buildSection()),
          ),
          if (isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: Container(color: Colors.black.withOpacity(0.5)),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            left: isSidebarOpen ? 0 : -300,
            top: 0, bottom: 0, width: 280,
            child: _buildSidebar(),
          ),
          if (!isSidebarOpen)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: _hamburgerButton(),
            ),
          // Profile avatar top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () {
                setState(() { selectedIndex = 4; isSidebarOpen = false; });
                _triggerPageAnimation();
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryBlue.withOpacity(0.4), width: 2),
                  color: _cardColor,
                ),
                child: ClipOval(
                  child: _profileImagePath != null
                      ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                      : Center(child: Text(
                      (teacherProfile['name'] ?? 'T').toString().isNotEmpty
                          ? (teacherProfile['name'] ?? 'T').toString()[0].toUpperCase()
                          : 'T',
                      style: TextStyle(color: _primaryBlue, fontWeight: FontWeight.bold, fontSize: 18))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hamburgerButton() {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openSidebar,
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _dividerColor, width: 1.5),
          ),
          child: Icon(Icons.menu_rounded, color: _textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    final teacherName = (teacherProfile['name'] ?? '').toString();
    final teacherId = (teacherProfile['teacherId'] ?? '').toString();
    return Container(
      decoration: BoxDecoration(
        color: _sidebarColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(8, 0))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_primaryBlue, _accentIndigo], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: _profileImagePath != null
                          ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                          : const Icon(Icons.person_4_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(teacherName.isEmpty ? 'Teacher' : teacherName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: -0.3),
                        overflow: TextOverflow.ellipsis),
                    Text(teacherId.isEmpty ? 'ID: —' : 'ID: $teacherId',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ])),
                ]),
                const SizedBox(height: 24),
                Text('MENU', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                const SizedBox(height: 8),
              ]),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuTitles.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: selected ? _primaryBlue.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() { selectedIndex = index; isSidebarOpen = false; });
                        _triggerPageAnimation();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: selected ? _primaryBlue.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(menuIcons[index],
                                color: selected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.5), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Text(menuTitles[index], style: TextStyle(
                              color: selected ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.65),
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 14)),
                          if (selected) ...[
                            const Spacer(),
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF60A5FA), shape: BoxShape.circle)),
                          ],
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Divider(color: Colors.white.withOpacity(0.08), height: 1),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + MediaQuery.of(context).padding.bottom),
              child: Column(children: [
                _sidebarAction(
                  icon: widget.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  label: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
                  trailing: Transform.scale(scale: 0.8, child: Switch(value: widget.isDarkMode, activeColor: const Color(0xFFF59E0B), onChanged: (_) => widget.toggleTheme())),
                  onTap: widget.toggleTheme,
                  iconColor: widget.isDarkMode ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 4),
                _sidebarAction(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () async {
                    await ActivityDatabase.instance.close();
                    if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
                  },
                  iconColor: _dangerRed,
                  textColor: _dangerRed,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarAction({required IconData icon, required String label, required VoidCallback onTap, Widget? trailing, Color? iconColor, Color? textColor}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Icon(icon, color: iconColor ?? Colors.white.withOpacity(0.6), size: 18),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: textColor ?? Colors.white.withOpacity(0.65), fontWeight: FontWeight.w400, fontSize: 14)),
            if (trailing != null) ...[const Spacer(), trailing],
          ]),
        ),
      ),
    );
  }
  void _showCreateRoomDialog() {
    _roomTitleController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Create Room', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _roomTitleController,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: _textPrimary),
          decoration: InputDecoration(
            labelText: 'Room Title',
            hintText: 'e.g. GRADE 3 - SECTION A',
            filled: true, fillColor: _fieldFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _dividerColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _dividerColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primaryBlue, width: 1.5)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              final title = _roomTitleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(ctx);
              final room = await ActivityDatabase.instance.createRoom(title, widget.loggedInEmail);
              if (room != null) {
                final updatedRooms = await ActivityDatabase.instance.getRoomsByTeacher(widget.loggedInEmail);
                setState(() => _rooms = updatedRooms);
                if (mounted) _showRoomCodeDialog(room);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRoomCodeDialog([Map<String, dynamic>? room]) {
    final r = room ?? (_rooms.isNotEmpty ? _rooms.first : null);
    if (r == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Room Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(r['title'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Text(
                r['code'] ?? '',
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 8, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Share this code with guardians to join your room.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showDeleteRoomDialog([Map<String, dynamic>? room]) {
    final r = room ?? (_rooms.isNotEmpty ? _rooms.first : null);
    if (r == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Room', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold)),
        content: Text('Delete "${r['title']}"? All guardians will be removed.', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ActivityDatabase.instance.deleteRoomByCode(r['code']);
              final updatedRooms = await ActivityDatabase.instance.getRoomsByTeacher(widget.loggedInEmail);
              setState(() => _rooms = updatedRooms);
              if (mounted) _showSnackbar('Room deleted');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _dangerRed, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _roomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 58, 24, 16),
          child: Row(children: [
            Expanded(child: Text('Rooms', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5, color: _textPrimary))),
            GestureDetector(
              onTap: _showCreateRoomDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primaryBlue, _accentIndigo], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 6),
                  Text('New Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
        Expanded(
          child: _rooms.isEmpty
              ? Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: _dividerColor.withOpacity(0.5), shape: BoxShape.circle),
                  child: Icon(Icons.meeting_room_outlined, size: 28, color: _textSecondary)),
              const SizedBox(height: 12),
              Text('No rooms yet', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text('Tap New Room to create your first room.', style: TextStyle(color: _textSecondary, fontSize: 13)),
            ]),
          )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: _rooms.length,
            itemBuilder: (context, index) {
              final room = _rooms[index];
              final delay = (index * 0.08).clamp(0.0, 0.6);
              final itemAnim = CurvedAnimation(
                parent: _pageController,
                curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeOut),
              );
              return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) => Opacity(
                    opacity: itemAnim.value,
                    child: Transform.translate(offset: Offset(0, 20 * (1 - itemAnim.value)), child: child),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _enterRoom(room),
                      child: Container(
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _dividerColor)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(children: [
                            Container(width: 44, height: 44,
                                decoration: BoxDecoration(color: _teal.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
                                child: const Icon(Icons.meeting_room_rounded, color: _teal, size: 22)),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(room['title'] ?? '', style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _teal.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
                                child: Text('Code: ${room['code'] ?? ''}',
                                    style: TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w700, letterSpacing: 2)),
                              ),
                            ])),
                            GestureDetector(
                              onTap: () {},
                              child: GestureDetector(
                                onTap: () => _showDeleteRoomDialog(room),
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(color: _dangerRed.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                  child: Icon(Icons.delete_outline_rounded, color: _dangerRed, size: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
                          ]),
                        ),
                      ),
                    ),
                  ));
            },
          ),
        ),
      ],
    );
  }

  void _enterRoom(Map<String, dynamic> room) {
    final code = room['code'].toString();
    final roomSpecificStudents = _roomStudents[code] ?? [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailPage(
          room: room,
          students: roomSpecificStudents,
          studentLrns: const {},
          activities: _activities,
          announcements: _announcements,
          studentGrades: _studentGrades,
          gradeControllers: _gradeControllers,
          defaultMaxScore: _defaultMaxScore,
          isDarkMode: widget.isDarkMode,
          onSaveGrade: _saveGrade,
          onStatusChange: (student, key, status) {
            setState(() {
              _studentGrades[student] ??= {};
              _studentGrades[student]![key] ??= {};
              _studentGrades[student]![key]!['status'] = status;
            });
          },
          onActivityAdded: (activity) {
            setState(() => _activities = [activity, ..._activities]);
            _initNewActivityForAllStudents(activity);
          },
          onAnnouncementAdded: (ann) {
            setState(() => _announcements = [ann, ..._announcements]);
          },
        ),
      ),
    );
  }

  // Inside _TeacherPageState in teacher_page.dart:

  void _saveGrade(String student, String activityKey, String gradeText) async {
    double? score = double.tryParse(gradeText);

    if (score != null && (score < 0 || score > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a score between 0 and 100')),
      );
      return;
    }

    String currentStatus = _studentGrades[student]![activityKey]!['status'] ?? 'Pending';
    if (score != null && currentStatus == 'Pending') {
      currentStatus = 'Completed';
    }

    try {
      // PERSIST TO DATABASE
      await ActivityDatabase.instance.saveStudentGrade(
          student,
          activityKey,
          score,
          currentStatus
      );

      setState(() {
        _studentGrades[student]![activityKey]!['grade'] = score;
        _studentGrades[student]![activityKey]!['status'] = currentStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${score?.toStringAsFixed(0) ?? "0"} for $student')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving to database: $e')),
      );
    }
  }

  void _showUploadModal(BuildContext context) {
    _selectedFile = null;
    String? selectedRoomCode = _rooms.isNotEmpty ? _rooms.first["code"]?.toString() : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload New Activity',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Room selector
              DropdownButtonFormField<String>(
                value: selectedRoomCode,
                decoration: const InputDecoration(
                  labelText: 'Post to Room',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Rooms (General)')),
                  ..._rooms.map((room) => DropdownMenuItem<String>(
                    value: room['code']?.toString(),
                    child: Text(room['title']?.toString() ?? 'Room'),
                  )),
                ],
                onChanged: (value) => setModalState(() => selectedRoomCode = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _activityTitleController,
                decoration: const InputDecoration(
                  labelText: 'Activity Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _activityDescController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description / Instructions',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _selectedFile != null
                    ? Row(
                  children: [
                    const Icon(Icons.attach_file, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_selectedFile!.name, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () {
                        setModalState(() => _selectedFile = null);
                        setState(() => _selectedFile = null);
                      },
                    ),
                  ],
                )
                    : InkWell(
                  onTap: () async {
                    await _pickFile();
                    setModalState(() {});
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file),
                      SizedBox(width: 8),
                      Text('Tap to attach file'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    String title = _activityTitleController.text.trim();
                    String desc = _activityDescController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a title')),
                      );
                      return;
                    }

                    final activityData = {
                      'title': title,
                      'description': desc,
                      'fileName': _selectedFile?.name ?? '',
                      'filePath': _selectedFile?.path ?? '',
                      'date': DateTime.now().toString(),
                      'roomCode': selectedRoomCode ?? '',
                    };

                    try {
                      final insertedId = await ActivityDatabase.instance.insertActivity(activityData);
                      final withId = {...activityData, 'id': insertedId};
                      setState(() {
                        _activities.insert(0, withId);
                      });
                      _initNewActivityForAllStudents(withId);

                      if (mounted) {
                        Navigator.pop(context);
                        _activityTitleController.clear();
                        _activityDescController.clear();
                        _selectedFile = null;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Activity saved successfully!')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Database Error: $e')),
                      );
                    }
                  },
                  child: const Text('Post Activity'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  // Generates a unique Teacher ID in the format xxxx-xx
  // e.g. 4821-37
  String _generateTeacherId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final fourDigit = (ms % 9000 + 1000).toString().padLeft(4, '0'); // 1000–9999
    final twoDigit = ((ms ~/ 13) % 90 + 10).toString().padLeft(2, '0'); // 10–99
    return '$fourDigit-$twoDigit';
  }

  Future<void> _fetchDatabaseContent() async {
    Map<String, dynamic>? profileData;
    List<Map<String, dynamic>> data = [];
    List<Map<String, dynamic>> announcementData = [];
    List<Map<String, dynamic>> savedGrades = [];

    // Retry up to 2 times — handles race condition when DB re-opens after logout
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        profileData = await ActivityDatabase.instance.getTeacherProfile(email: widget.loggedInEmail);
        if (profileData == null) {
          profileData = await ActivityDatabase.instance.getTeacherFromAdminDB(widget.loggedInEmail);
        }
        profileData ??= {
          'teacherId': '',
          'name': '',
          'email': widget.loggedInEmail,
          'phone': '',
          'subject': '',
          'advisoryClass': '',
        };

        data = await ActivityDatabase.instance.getActivities();
        announcementData = await ActivityDatabase.instance.getAnnouncements();
        savedGrades = await ActivityDatabase.instance.getAllGrades();

        final rooms = await ActivityDatabase.instance.getRoomsByTeacher(widget.loggedInEmail);
        if (rooms.isNotEmpty) {
          setState(() => _rooms = rooms);
          // Load members per room — only guardians who joined that specific room
          for (final room in rooms) {
            final code = room['code'].toString();
            final members = await ActivityDatabase.instance.getRoomMembersByCode(code);
            final roomStudentNames = <String>[];
            for (final member in members) {
              final name = _capitalizeName(member['name']);
              roomStudentNames.add(name);
              _addStudentToState(name); // still add to global for attendance
            }
            _roomStudents[code] = roomStudentNames;
          }
        }
        break; // success — exit retry loop
      } catch (e) {
        debugPrint("Error loading data (attempt ${attempt + 1}): $e");
        if (attempt == 0) {
          // Brief pause then retry
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          profileData ??= {
            'teacherId': '',
            'name': '',
            'email': widget.loggedInEmail,
            'phone': '',
            'subject': '',
            'advisoryClass': '',
          };
        }
      }
    }

    setState(() {
      teacherProfile = Map<String, dynamic>.from(profileData!);

      _nameController.text = teacherProfile['name'] ?? '';
      _emailController.text = teacherProfile['email'] ?? '';
      _phoneController.text = teacherProfile['phone'] ?? '';
      _advisoryClassController.text = teacherProfile['advisoryClass'] ?? '';

      // Restore saved profile image if it exists
      final savedImage = (teacherProfile['profileImage'] ?? '').toString();
      if (savedImage.isNotEmpty && File(savedImage).existsSync()) {
        _profileImagePath = savedImage;
      }

      _activities = List<Map<String, dynamic>>.from(data);
      _announcements = List<Map<String, dynamic>>.from(announcementData);

      for (var activity in _activities) {
        _initNewActivityForAllStudents(activity);
      }

      for (var row in savedGrades) {
        String sName = row['studentName'];
        String aKey = row['activityKey'];
        double? score = row['grade'];
        String status = row['status'] ?? 'Pending';

        _studentGrades[sName] ??= {};
        _gradeControllers[sName] ??= {};

        _studentGrades[sName]![aKey] = {
          'grade': score,
          'maxScore': 100.0,
          'status': status,
        };

        if (_gradeControllers[sName]![aKey] == null) {
          _gradeControllers[sName]![aKey] = TextEditingController();
        }
        _gradeControllers[sName]![aKey]!.text = score?.toStringAsFixed(0) ?? "";
      }
    });
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _showAnnouncementModal(BuildContext context) {
    _announcementTitleController.clear();
    _announcementMessageController.clear();
    String? selectedRoomCode = _rooms.isNotEmpty ? _rooms.first["code"]?.toString() : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Post New Announcement',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              // Room selector
              DropdownButtonFormField<String>(
                value: selectedRoomCode,
                decoration: const InputDecoration(
                  labelText: 'Post to Room',
                  prefixIcon: Icon(Icons.meeting_room_outlined),
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('All Rooms (General)')),
                  ..._rooms.map((room) => DropdownMenuItem<String>(
                    value: room['code']?.toString(),
                    child: Text(room['title']?.toString() ?? 'Room'),
                  )),
                ],
                onChanged: (value) => setModalState(() => selectedRoomCode = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _announcementTitleController,
                decoration: const InputDecoration(
                  labelText: 'Announcement Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _announcementMessageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Announcement Message',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    String title = _announcementTitleController.text.trim();
                    String message = _announcementMessageController.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a title')),
                      );
                      return;
                    }
                    final newAnnouncement = {
                      'title': title,
                      'message': message,
                      'date': _getCurrentDate(),
                      'roomCode': selectedRoomCode ?? '',
                    };
                    try {
                      final insertedId = await ActivityDatabase.instance.insertAnnouncement(newAnnouncement);
                      final withId = {...newAnnouncement, 'id': insertedId};
                      setState(() {
                        _announcements.insert(0, withId);
                      });
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Announcement posted successfully!')),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Database Error: $e')),
                      );
                    }
                  },
                  child: const Text('Post Announcement'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _triggerPageAnimation() {
    _pageController.forward(from: 0.0);
  }

  Widget _buildSection() {
    Widget section;
    switch (selectedIndex) {
      case 0:
        section = _roomsSection();
        break;
      case 1:
        section = _attendanceSection();
        break;
      case 4:
        section = _genericSection('Teacher Profile', _profileContent());
        break;
      default:
        section = const SizedBox();
    }
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(position: _pageSlide, child: section),
    );
  }

  Widget _genericSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 22, 24, 20),
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(child: content),
      ],
    );
  }

  Widget _activitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SizedBox(width: 48),
              SizedBox(width: 8),
              Text('Teacher Activities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _activities.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No activities posted yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _activities.length,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) {
              final activity = _activities[index];
              final String? fileName = activity['fileName'];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Icon(
                    fileName != null ? Icons.insert_drive_file : Icons.description,
                    color: Colors.blue,
                  ),
                  title: Text(activity['title'] ?? 'Untitled'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Posted on ${activity['date']}'),
                      if ((activity['roomCode'] ?? '').toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('Room: ${activity['roomCode']}', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleActivityMenuAction(value, index),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                  onTap: () => _showFileDetails(context, activity),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _announcementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SizedBox(width: 48),
              SizedBox(width: 8),
              Text('Announcements', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: _announcements.isEmpty
              ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No announcements yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          )
              : ListView.builder(
            itemCount: _announcements.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final announcement = _announcements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.blue),
                  title: Text(announcement['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(announcement['message'] ?? ''),
                      if ((announcement['roomCode'] ?? '').toString().isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Text('Room: ${announcement['roomCode']}', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleAnnouncementMenuAction(value, index),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFileDetails(BuildContext context, Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(activity['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(activity['description'] ?? 'No description'),
            const SizedBox(height: 16),
            if (activity['fileName'] != null && activity['fileName'].isNotEmpty) ...[
              const Text('Attached File:', style: TextStyle(fontWeight: FontWeight.w500)),
              Text(activity['fileName']),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getDateKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Map<int, String> _getAttendanceForDate(DateTime date) {
    final key = _getDateKey(date);
    return _attendanceRecords.containsKey(key) ? Map.from(_attendanceRecords[key]!) : {};
  }

  int _getCountForStatus(Map<int, String> attendanceMap, String status) => attendanceMap.values.where((s) => s == status).length;

  Future<void> _selectAttendanceDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedAttendanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      final dateKey = _getDateKey(picked);
      final selectedCode = _selectedAttendanceRoom?['code']?.toString();
      final roomStudents = selectedCode != null ? (_roomStudents[selectedCode] ?? []) : [];
      final cacheKey = '${selectedCode}_$dateKey';
      Map<int, String> newAttendance = {};
      if (_attendanceRecords.containsKey(cacheKey)) {
        newAttendance = Map.from(_attendanceRecords[cacheKey]!);
      } else {
        final saved = await ActivityDatabase.instance.getAttendanceByDate(dateKey);
        for (int i = 0; i < roomStudents.length; i++) {
          if (saved.containsKey(roomStudents[i])) {
            newAttendance[i] = saved[roomStudents[i]]!;
          }
        }
      }
      setState(() {
        _selectedAttendanceDate = picked;
        _currentAttendance = newAttendance;
      });
    }
  }

  void _markAllPresent() {
    final selectedCode = _selectedAttendanceRoom?['code']?.toString();
    final roomStudents = selectedCode != null ? (_roomStudents[selectedCode] ?? []) : students;
    setState(() {
      for (int i = 0; i < roomStudents.length; i++) {
        _currentAttendance[i] = 'Present';
      }
    });
  }

  void _saveAttendance() async {
    final selectedCode = _selectedAttendanceRoom?['code']?.toString();
    if (selectedCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a room first.')));
      return;
    }
    final roomStudents = _roomStudents[selectedCode] ?? [];
    if (roomStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No students in this room.')));
      return;
    }
    final dateKey = _getDateKey(_selectedAttendanceDate);
    final cacheKey = '${selectedCode}_$dateKey';
    for (int i = 0; i < roomStudents.length; i++) {
      final name = roomStudents[i];
      final status = _currentAttendance[i] ?? 'Pending';
      await ActivityDatabase.instance.saveAttendance(name, dateKey, status);
    }
    // Cache with room+date key so switching rooms doesn't lose data
    setState(() {
      _attendanceRecords[cacheKey] = Map.from(_currentAttendance);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance saved for ${_formatDate(_selectedAttendanceDate)}'), backgroundColor: Colors.green),
      );
    }
  }

  Widget _buildAttendanceSummary(Map<int, String> attendanceMap) {
    final present = _getCountForStatus(attendanceMap, 'Present');
    final absent = _getCountForStatus(attendanceMap, 'Absent');
    final late = _getCountForStatus(attendanceMap, 'Late');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _attendanceStat(present.toString(), 'Present', Colors.green),
            _attendanceStat(absent.toString(), 'Absent', Colors.red),
            _attendanceStat(late.toString(), 'Late', Colors.amber[700]!),
          ],
        ),
      ),
    );
  }

  Widget _attendanceStat(String count, String label, Color color) => Column(children: [
    Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
    Text(label, style: const TextStyle(fontSize: 11)),
  ]);

  Widget _attendanceSection() {
    if (_rooms.isEmpty) {
      return _genericSection('Attendance', const Center(child: Text('Create a room first to take attendance.')));
    }

    final String? selectedCode = _selectedAttendanceRoom?['code']?.toString();
    final roomStudents = selectedCode != null ? (_roomStudents[selectedCode] ?? []) : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
          child: Row(children: [
            const SizedBox(width: 48),
            const Text('Attendance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ),
        // Room selector — default hint is "Select Room"
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: selectedCode,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.meeting_room_outlined),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            hint: const Text('Select Room'),
            items: _rooms.map((room) => DropdownMenuItem<String>(
              value: room['code'].toString(),
              child: Text(room['title'] ?? ''),
            )).toList(),
            onChanged: (code) async {
              final newRoom = _rooms.firstWhere((r) => r['code'].toString() == code, orElse: () => _rooms.first);
              final dateKey = _getDateKey(_selectedAttendanceDate);
              // First check in-memory cache
              Map<int, String> newAttendance = {};
              final cacheKey = '${code}_$dateKey';
              if (_attendanceRecords.containsKey(cacheKey)) {
                newAttendance = Map.from(_attendanceRecords[cacheKey]!);
              } else {
                // Load from DB
                final saved = await ActivityDatabase.instance.getAttendanceByDate(dateKey);
                final roomStudents = _roomStudents[code] ?? [];
                for (int i = 0; i < roomStudents.length; i++) {
                  if (saved.containsKey(roomStudents[i])) {
                    newAttendance[i] = saved[roomStudents[i]]!;
                  }
                }
              }
              setState(() {
                _selectedAttendanceRoom = newRoom;
                _currentAttendance = newAttendance;
              });
            },
          ),
        ),
        if (selectedCode == null) ...[
          const SizedBox(height: 32),
          const Center(child: Text('Please select a room to take attendance.', style: TextStyle(color: Colors.grey))),
        ] else if (roomStudents.isEmpty) ...[
          const SizedBox(height: 32),
          const Center(child: Text('No students in this room yet.', style: TextStyle(color: Colors.grey))),
        ] else ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectAttendanceDate(context),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(_formatDate(_selectedAttendanceDate), style: const TextStyle(fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _markAllPresent,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('All Present'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAttendanceSummary(_currentAttendance)),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: roomStudents.length,
              itemBuilder: (context, index) {
                final name = roomStudents[index];
                // Default to 'Pending' — never show null/hint
                final status = _currentAttendance[index] ?? 'Pending';
                Color statusColor = Colors.grey[400]!;
                if (status == 'Present') statusColor = Colors.green;
                else if (status == 'Absent') statusColor = Colors.red;
                else if (status == 'Late') statusColor = Colors.amber[700]!;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.15),
                      child: Text(name[0].toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    trailing: DropdownButton<String>(
                      value: status,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(value: 'Pending', child: Text('Pending', style: TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'Present', child: Text('Present', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'Late', child: Text('Late', style: TextStyle(color: Colors.amber[700], fontWeight: FontWeight.w600))),
                        DropdownMenuItem(value: 'Absent', child: Text('Absent', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600))),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        final code = _selectedAttendanceRoom?['code']?.toString();
                        final dateKey = _getDateKey(_selectedAttendanceDate);
                        final cacheKey = '${code}_$dateKey';
                        setState(() {
                          _currentAttendance[index] = val;
                          // Write through to cache immediately so navigating away preserves changes
                          _attendanceRecords[cacheKey] = Map.from(_currentAttendance);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveAttendance,
                icon: const Icon(Icons.save),
                label: Text('Save Attendance — ${_formatDate(_selectedAttendanceDate)}'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleActivityMenuAction(String action, int index) {
    if (action == 'edit') {
      _showEditActivityModal(index);
    } else if (action == 'delete') {
      final act = _activities[index];
      ActivityDatabase.instance.database.then((db) {
        if (act['id'] != null) {
          db.delete('activities', where: 'id = ?', whereArgs: [act['id']]);
        } else {
          db.delete('activities', where: 'title = ? AND date = ?', whereArgs: [act['title'], act['date']]);
        }
      });
      _removeActivityFromAllStudents(act);
      setState(() => _activities = List.from(_activities)..removeAt(index));
    }
  }

  void _handleAnnouncementMenuAction(String action, int index) {
    if (action == 'edit') {
      _showEditAnnouncementModal(index);
    } else if (action == 'delete') {
      final ann = _announcements[index];
      ActivityDatabase.instance.database.then((db) {
        if (ann['id'] != null) {
          db.delete('announcements', where: 'id = ?', whereArgs: [ann['id']]);
        } else {
          db.delete('announcements', where: 'title = ? AND date = ?', whereArgs: [ann['title'], ann['date']]);
        }
      });
      setState(() => _announcements = List.from(_announcements)..removeAt(index));
    }
  }

  void _showEditActivityModal(int index) {
    _editActivityTitleController.text = _activities[index]['title'] ?? '';
    _editActivityDescController.text = _activities[index]['description'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _editActivityTitleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editActivityDescController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  final updatedActivity = {
                    ..._activities[index],
                    'title': _editActivityTitleController.text.trim(),
                    'description': _editActivityDescController.text.trim(),
                  };
                  try {
                    final db = await ActivityDatabase.instance.database;
                    final fields = {'title': updatedActivity['title'], 'description': updatedActivity['description']};
                    if (_activities[index]['id'] != null) {
                      await db.update('activities', fields, where: 'id = ?', whereArgs: [_activities[index]['id']]);
                    } else {
                      await db.update('activities', fields, where: 'title = ? AND date = ?', whereArgs: [_activities[index]['title'], _activities[index]['date']]);
                    }
                    setState(() => _activities = List.from(_activities)..[index] = updatedActivity);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditAnnouncementModal(int index) {
    _editAnnouncementTitleController.text = _announcements[index]['title'] ?? '';
    _editAnnouncementMessageController.text = _announcements[index]['message'] ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Announcement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _editAnnouncementTitleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _editAnnouncementMessageController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  final updatedAnnouncement = {
                    ..._announcements[index],
                    'title': _editAnnouncementTitleController.text.trim(),
                    'message': _editAnnouncementMessageController.text.trim(),
                  };
                  try {
                    final db = await ActivityDatabase.instance.database;
                    final fields = {'title': updatedAnnouncement['title'], 'message': updatedAnnouncement['message']};
                    if (_announcements[index]['id'] != null) {
                      await db.update('announcements', fields, where: 'id = ?', whereArgs: [_announcements[index]['id']]);
                    } else {
                      await db.update('announcements', fields, where: 'title = ? AND date = ?', whereArgs: [_announcements[index]['title'], _announcements[index]['date']]);
                    }
                    setState(() => _announcements = List.from(_announcements)..[index] = updatedAnnouncement);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _toggleEditMode() async {
    if (isEditing) {
      final updatedProfile = {
        ...teacherProfile,
        'phone': _phoneController.text.trim(),
        'advisoryClass': _advisoryClassController.text.trim(),
        'email': widget.loggedInEmail,
        'profileImage': _profileImagePath ?? (teacherProfile['profileImage'] ?? ''),
        'teacherId': (teacherProfile['teacherId'] ?? '').toString().isNotEmpty
            ? teacherProfile['teacherId']
            : _generateTeacherId(),
      };

      try {
        await ActivityDatabase.instance.updateTeacherProfile(updatedProfile);

        // Re-fetch by email so teacherId and name are always in sync with what was saved
        final savedProfile = await ActivityDatabase.instance.getTeacherProfile(email: widget.loggedInEmail);

        setState(() {
          // Use savedProfile if available, otherwise keep updatedProfile — never fall back to stale defaults
          teacherProfile = savedProfile ?? updatedProfile;
          _nameController.text = teacherProfile['name'] ?? '';
          _emailController.text = teacherProfile['email'] ?? '';
          _phoneController.text = teacherProfile['phone'] ?? '';
          _advisoryClassController.text = teacherProfile['advisoryClass'] ?? '';
          isEditing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving: $e')),
          );
        }
      }
    } else {
      setState(() => isEditing = true);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      // 1. Pick image from gallery
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) return;

      // 2. Launch circular cropper
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: result.files.single.path!,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.blue,
            lockAspectRatio: true,
            hideBottomControls: false,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: [CropAspectRatioPreset.square],
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (croppedFile == null) return; // User cancelled cropper

      final path = croppedFile.path;
      setState(() => _profileImagePath = path);

      // 3. Persist immediately to DB
      final updatedProfile = {
        ...teacherProfile,
        'profileImage': path,
        'email': widget.loggedInEmail,
      };
      await ActivityDatabase.instance.updateTeacherProfile(updatedProfile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Widget _profileContent() {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        // Pushes content above the keyboard with extra breathing room
        bottom: bottomInset > 0 ? bottomInset + 80 : 24,
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue,
                  backgroundImage: _profileImagePath != null
                      ? FileImage(File(_profileImagePath!))
                      : null,
                  child: _profileImagePath == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildProfileField('Teacher ID', teacherProfile['teacherId'], isEditable: false),
          _buildProfileField('Full Name', teacherProfile['name'], isEditable: false),
          _buildProfileField('Email Address', teacherProfile['email'], isEditable: false),
          _buildProfileField('Phone Number', teacherProfile['phone'],
              controller: _phoneController,
              isEditing: isEditing,
              hint: '+63 9XXX XXXX XXXX',
              keyboardType: TextInputType.phone,
              formatters: [
                LengthLimitingTextInputFormatter(17), // Fits +63 9xx xxxx xxxx
              ]
          ),
          _buildProfileField('Advisory Class', teacherProfile['advisoryClass'], controller: _advisoryClassController, isEditing: isEditing),

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _toggleEditMode,
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
    TextEditingController? controller,
    bool isEditing = false,
    bool isEditable = true,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
  }) {
    // Non-editable fields always render as a locked gray container
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
              controller: controller,
              keyboardType: keyboardType,
              inputFormatters: formatters,
              decoration: InputDecoration(
                hintText: hint,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Locked fields use a slightly darker gray to signal non-editable
                color: isEditable
                    ? (widget.isDarkMode ? Colors.grey[800] : Colors.grey[100])
                    : (widget.isDarkMode ? Colors.grey[850] : Colors.grey[200]),
                borderRadius: BorderRadius.circular(8),
                border: isEditable
                    ? null
                    : Border.all(color: Colors.grey[400]!, width: 0.5),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  // Locked fields shown in gray text
                  color: isEditable
                      ? (widget.isDarkMode ? Colors.white : Colors.black87)
                      : Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _initNewActivityForAllStudents(Map<String, dynamic> activity) {
    String key = _getActivityKey(activity);
    for (String student in students) {
      _studentActivities[student] ??= [];
      _studentActivities[student]!.add(Map<String, dynamic>.from(activity));
      _studentGrades[student] ??= {};
      _studentGrades[student]![key] = {'grade': null, 'maxScore': _defaultMaxScore, 'status': 'Pending'};
      _gradeControllers[student] ??= {};
      _gradeControllers[student]![key] = TextEditingController();
    }
    setState(() {});
  }

  void _removeActivityFromAllStudents(Map<String, dynamic> activity) {
    String key = _getActivityKey(activity);
    for (String student in students) {
      _studentActivities[student]?.removeWhere((act) => _getActivityKey(act) == key);
      _studentGrades[student]?.remove(key);
      _gradeControllers[student]?.remove(key);
    }
    setState(() {});
  }
}
// ─── Room Detail Page ────────────────────────────────────────────────────────

class RoomDetailPage extends StatefulWidget {
  final Map<String, dynamic> room;
  final List<String> students;
  final Map<String, String> studentLrns;
  final List<Map<String, dynamic>> activities;
  final List<Map<String, dynamic>> announcements;
  final Map<String, Map<String, Map<String, dynamic>>> studentGrades;
  final Map<String, Map<String, TextEditingController>> gradeControllers;
  final double defaultMaxScore;
  final bool isDarkMode;
  final void Function(String, String, String) onSaveGrade;
  final void Function(String, String, String) onStatusChange;
  final void Function(Map<String, dynamic>) onActivityAdded;
  final void Function(Map<String, dynamic>) onAnnouncementAdded;

  const RoomDetailPage({
    super.key,
    required this.room,
    required this.students,
    required this.studentLrns,
    required this.activities,
    required this.announcements,
    required this.studentGrades,
    required this.gradeControllers,
    required this.defaultMaxScore,
    required this.isDarkMode,
    required this.onSaveGrade,
    required this.onStatusChange,
    required this.onActivityAdded,
    required this.onAnnouncementAdded,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  int _tabIndex = 0;
  late List<Map<String, dynamic>> _localActivities;
  late List<Map<String, dynamic>> _localAnnouncements;

  // Local copy of grades — fully owned by this page, no parent dependency
  late Map<String, Map<String, Map<String, dynamic>>> _localGrades;

  final _actTitleCtrl = TextEditingController();
  final _actDescCtrl = TextEditingController();
  final _annTitleCtrl = TextEditingController();
  final _annMsgCtrl = TextEditingController();

  DateTime? _actDeadline;
  List<File> _actImages = [];
  List<File> _annImages = [];

  @override
  void initState() {
    super.initState();
    final roomCode = (widget.room['code'] ?? '').toString();
    _localActivities = List.from(widget.activities
        .where((a) => (a['roomCode'] ?? '').toString() == roomCode)
        .toList());
    _localAnnouncements = List.from(widget.announcements
        .where((a) => (a['roomCode'] ?? '').toString() == roomCode)
        .toList());

    // Deep-copy grades so we own the data — no shared reference with parent
    _localGrades = {};
    widget.studentGrades.forEach((student, actMap) {
      _localGrades[student] = {};
      actMap.forEach((actKey, gradeData) {
        _localGrades[student]![actKey] = Map<String, dynamic>.from(gradeData);
      });
    });
  }

  @override
  void dispose() {
    _actTitleCtrl.dispose();
    _actDescCtrl.dispose();
    _annTitleCtrl.dispose();
    _annMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages(bool isActivity) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null) {
      final files = result.paths.whereType<String>().map((p) => File(p)).toList();
      setState(() {
        if (isActivity) _actImages = files;
        else _annImages = files;
      });
    }
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    const months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _tab(String label, int idx) => Expanded(
    child: InkWell(
      onTap: () => setState(() => _tabIndex = idx),
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _tabIndex == idx ? Colors.white : Colors.transparent, width: 3)),
        ),
        child: Text(label, style: TextStyle(color: _tabIndex == idx ? Colors.white : Colors.white60, fontWeight: FontWeight.w600, fontSize: 13)),
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
          Text('Code: ${widget.room['code'] ?? ''}', style: const TextStyle(fontSize: 12, letterSpacing: 3, color: Colors.white70)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Row(children: [
            _tab('Activities (${_localActivities.length})', 0),
            _tab('Announcements', 1),
            _tab('Students (${widget.students.length})', 2),
          ]),
        ),
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
        onPressed: _showUploadActivity,
        icon: const Icon(Icons.add),
        label: const Text('Upload Activity'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : _tabIndex == 1
          ? FloatingActionButton.extended(
        onPressed: _showPostAnnouncement,
        icon: const Icon(Icons.add),
        label: const Text('Post Announcement'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : null,
      body: [
        _buildActivitiesTab(),
        _buildAnnouncementsTab(),
        _buildStudentsTab(),
      ][_tabIndex],
    );
  }

  // ── Upload Activity Modal ────────────────────────────────────────────────
  void _showUploadActivity() {
    _actTitleCtrl.clear();
    _actDescCtrl.clear();
    _actDeadline = null;
    _actImages = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Upload New Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _actTitleCtrl, decoration: const InputDecoration(labelText: 'Activity Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _actDescCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / Instructions', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          // Deadline picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: _actDeadline ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setModal(() => _actDeadline = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  _actDeadline == null ? 'Set Deadline (optional)' : 'Deadline: ${_actDeadline!.year}-${_actDeadline!.month.toString().padLeft(2,'0')}-${_actDeadline!.day.toString().padLeft(2,'0')}',
                  style: TextStyle(color: _actDeadline == null ? Colors.grey[600] : Colors.black),
                ),
                const Spacer(),
                if (_actDeadline != null) GestureDetector(
                  onTap: () => setModal(() => _actDeadline = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Image picker
          OutlinedButton.icon(
            onPressed: () async {
              await _pickImages(true);
              setModal(() {});
            },
            icon: const Icon(Icons.image_outlined),
            label: Text(_actImages.isEmpty ? 'Attach Images' : '${_actImages.length} image(s) selected'),
          ),
          if (_actImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _actImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_actImages[i], width: 80, height: 80, fit: BoxFit.cover)),
                  Positioned(top: 2, right: 2, child: GestureDetector(
                    onTap: () => setModal(() => _actImages.removeAt(i)),
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                  )),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                final title = _actTitleCtrl.text.trim();
                if (title.isEmpty) return;
                final deadlineStr = _actDeadline != null
                    ? '${_actDeadline!.year}-${_actDeadline!.month.toString().padLeft(2,'0')}-${_actDeadline!.day.toString().padLeft(2,'0')}'
                    : '';
                final imagePathsStr = _actImages.map((f) => f.path).join('|');
                final activityData = {
                  'title': title,
                  'description': _actDescCtrl.text.trim(),
                  'fileName': _actImages.isNotEmpty ? '${_actImages.length} image(s)' : '',
                  'filePath': imagePathsStr,
                  'date': _getCurrentDate(),
                  'deadline': deadlineStr,
                  'roomCode': widget.room['code'] ?? '',
                };
                try {
                  final insertedId = await ActivityDatabase.instance.insertActivity(activityData);
                  final withId = {...activityData, 'id': insertedId};
                  setState(() => _localActivities = [withId, ..._localActivities]);
                  widget.onActivityAdded(withId);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Post Activity'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  // ── Post Announcement Modal ──────────────────────────────────────────────
  void _showPostAnnouncement() {
    _annTitleCtrl.clear();
    _annMsgCtrl.clear();
    _annImages = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Post Announcement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: _annTitleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _annMsgCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), alignLabelWithHint: true)),
          const SizedBox(height: 12),
          // Image picker
          OutlinedButton.icon(
            onPressed: () async {
              await _pickImages(false);
              setModal(() {});
            },
            icon: const Icon(Icons.image_outlined),
            label: Text(_annImages.isEmpty ? 'Attach Images' : '${_annImages.length} image(s) selected'),
          ),
          if (_annImages.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _annImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Stack(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_annImages[i], width: 80, height: 80, fit: BoxFit.cover)),
                  Positioned(top: 2, right: 2, child: GestureDetector(
                    onTap: () => setModal(() => _annImages.removeAt(i)),
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                  )),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                final title = _annTitleCtrl.text.trim();
                final msg = _annMsgCtrl.text.trim();
                if (title.isEmpty) return;
                final imagePathsStr = _annImages.map((f) => f.path).join('|');
                final ann = {
                  'title': title,
                  'message': msg,
                  'date': _getCurrentDate(),
                  'imagePaths': imagePathsStr,
                  'roomCode': widget.room['code'] ?? '',
                };
                try {
                  final insertedId = await ActivityDatabase.instance.insertAnnouncement(ann);
                  final withId = {...ann, 'id': insertedId};
                  setState(() => _localAnnouncements = [withId, ..._localAnnouncements]);
                  widget.onAnnouncementAdded(withId);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Post Announcement'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  // ── Activities Tab ───────────────────────────────────────────────────────
  Widget _buildActivitiesTab() {
    if (_localActivities.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No activities yet. Tap "+ Upload Activity" to post one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localActivities.length,
      itemBuilder: (context, i) {
        final act = _localActivities[i];
        final deadline = (act['deadline'] ?? '').toString();
        final imagePaths = (act['filePath'] ?? '').toString()
            .split('|').where((s) => s.isNotEmpty).toList();
        final hasDeadline = deadline.isNotEmpty;
        final isOverdue = hasDeadline && DateTime.tryParse(deadline)?.isBefore(DateTime.now()) == true;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(backgroundColor: Colors.blue, radius: 18, child: Icon(Icons.assignment, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(act['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Posted: ${act['date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                if (hasDeadline)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOverdue ? Colors.red.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isOverdue ? Colors.red : Colors.orange),
                    ),
                    child: Text(isOverdue ? 'Overdue' : 'Due: $deadline',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isOverdue ? Colors.red : Colors.orange)),
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) => value == 'edit' ? _editActivity(i) : _deleteActivity(i),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ]),
              if ((act['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(act['description'] ?? '', style: const TextStyle(fontSize: 13)),
              ],
              if (imagePaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imagePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: File(imagePaths[idx]).existsSync()
                          ? Image.file(File(imagePaths[idx]), width: 90, height: 90, fit: BoxFit.cover)
                          : Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  // ── Announcements Tab ────────────────────────────────────────────────────
  Widget _buildAnnouncementsTab() {
    if (_localAnnouncements.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text('No announcements yet. Tap "+ Post Announcement" to add one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localAnnouncements.length,
      itemBuilder: (context, i) {
        final ann = _localAnnouncements[i];
        final imagePaths = (ann['imagePaths'] ?? '').toString()
            .split('|').where((s) => s.isNotEmpty).toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const CircleAvatar(backgroundColor: Colors.orange, radius: 18, child: Icon(Icons.campaign, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ann['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(ann['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ])),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) => value == 'edit' ? _editAnnouncement(i) : _deleteAnnouncement(i),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text('Edit')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ]),
              if ((ann['message'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(ann['message'] ?? '', style: const TextStyle(fontSize: 13)),
              ],
              if (imagePaths.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: imagePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, idx) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: File(imagePaths[idx]).existsSync()
                          ? Image.file(File(imagePaths[idx]), width: 90, height: 90, fit: BoxFit.cover)
                          : Container(width: 90, height: 90, color: Colors.grey[200], child: const Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  // ── Students Tab ─────────────────────────────────────────────────────────
  Widget _buildStudentsTab() {
    if (widget.students.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('No students yet.', style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('Students appear when a guardian joins this room.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ]));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final student = widget.students[i];
        final lrn = widget.studentLrns[student] ?? '';
        return StatefulBuilder(builder: (context, setStudent) {
          // Grade summary: sum of all scored activities / (count * 100) * 100 = average %
          double total = 0; int graded = 0;
          final int totalActivities = _localActivities.length;
          for (final act in _localActivities) {
            final key = '${act['title']}_${act['date']}';
            final data = _localGrades[student]?[key] ?? {};
            final s = (data['status'] ?? 'Pending') as String;
            if ((s == 'Completed' || s == 'Late') && data['grade'] != null) {
              total += (data['grade'] as double);
              graded++;
            }
          }
          // Average = sum of scores / number graded (each score is already 0-100)
          final avg = graded > 0 ? (total / graded) : 0.0;
          final summaryDisplay = graded > 0
              ? '${avg.toStringAsFixed(1)} / 100'
              : '— / 100';

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text(student[0].toUpperCase())),
              title: Text(student, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: lrn.isNotEmpty ? Text('LRN: $lrn', style: const TextStyle(fontSize: 12, color: Colors.grey)) : null,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    ..._localActivities.map((activity) {
                      final key = '${activity['title']}_${activity['date']}';
                      return StatefulBuilder(builder: (ctx, setCard) {
                        final gradeData = _localGrades[student]?[key] ?? {};
                        final controller = widget.gradeControllers[student]?[key] ?? TextEditingController();
                        final rawGrade = gradeData['grade'];
                        final score = rawGrade != null ? (rawGrade as double) : 0.0;
                        final hasGrade = rawGrade != null;
                        // Sync controller text from local grades so score is always visible
                        if (hasGrade && controller.text.isEmpty) {
                          controller.text = score.toStringAsFixed(0);
                        }
                        final pct = hasGrade ? '${score.toStringAsFixed(0)}%' : '—';
                        final status = (gradeData['status'] ?? 'Pending') as String;
                        final canGrade = status == 'Completed' || status == 'Late';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: canGrade ? Colors.blue.shade200 : Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                            color: canGrade ? null : (widget.isDarkMode ? Colors.grey[850] : Colors.grey[100]),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Expanded(child: Text(activity['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                              DropdownButton<String>(
                                value: status,
                                underline: const SizedBox(),
                                items: ['Pending', 'Completed', 'Late', 'Missed'].map((v) => DropdownMenuItem(
                                  value: v,
                                  child: Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                      color: v == 'Missed' ? Colors.red
                                          : v == 'Late' ? Colors.orange.shade700
                                          : v == 'Completed' ? Colors.green
                                          : Colors.grey[500])),
                                )).toList(),
                                onChanged: (newStatus) {
                                  if (newStatus == null) return;
                                  // Update local grades immediately
                                  setState(() {
                                    _localGrades[student] ??= {};
                                    _localGrades[student]![key] ??= {};
                                    _localGrades[student]![key]!['status'] = newStatus;
                                    if (newStatus == 'Missed') {
                                      _localGrades[student]![key]!['grade'] = 0.0;
                                      controller.text = '0';
                                    } else if (newStatus == 'Pending') {
                                      controller.clear();
                                    } else if (status == 'Missed') {
                                      controller.clear();
                                    }
                                  });
                                  // Also notify parent
                                  widget.onStatusChange(student, key, newStatus);
                                  if (newStatus == 'Missed') widget.onSaveGrade(student, key, '0');
                                  setCard(() {});
                                  setStudent(() {});
                                },
                              ),
                            ]),
                            const SizedBox(height: 6),
                            if (status == 'Missed')
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('Score: 0 / 100', style: TextStyle(fontSize: 14, color: Colors.red[700], fontWeight: FontWeight.w600)),
                              )
                            else
                              Row(children: [
                                Expanded(child: TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  enabled: status != 'Pending',
                                  decoration: InputDecoration(
                                    labelText: 'Score',
                                    suffixText: '/ 100',
                                    border: const OutlineInputBorder(),
                                    helperText: status == 'Pending'
                                        ? '⚠ Set to Completed or Late to grade'
                                        : hasGrade ? 'Percentage: $pct' : 'Enter score (0–100)',
                                    helperStyle: TextStyle(
                                      color: status == 'Pending' ? Colors.grey[500] : Colors.grey[600],
                                      fontStyle: status == 'Pending' ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                )),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.save, color: status == 'Pending' ? Colors.grey[400] : Colors.blue),
                                  onPressed: status == 'Pending' ? null : () {
                                    final parsed = double.tryParse(controller.text);
                                    // Update local grades immediately
                                    setState(() {
                                      _localGrades[student] ??= {};
                                      _localGrades[student]![key] ??= {};
                                      _localGrades[student]![key]!['grade'] = parsed;
                                    });
                                    widget.onSaveGrade(student, key, controller.text);
                                    setCard(() {});
                                    setStudent(() {});
                                  },
                                ),
                              ]),
                          ]),
                        );
                      });
                    }).toList(),
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Grade Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blue)),
                        Text(summaryDisplay, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      ]),
                    ),
                  ]),
                ),
              ],
            ),
          );
        }); // end student StatefulBuilder
      },
    );
  }

  // ── Edit / Delete Activity ────────────────────────────────────────────────
  void _editActivity(int i) {
    final act = _localActivities[i];
    final titleCtrl = TextEditingController(text: act['title'] ?? '');
    final descCtrl = TextEditingController(text: act['description'] ?? '');
    DateTime? deadline = act['deadline'] != null && (act['deadline'] as String).isNotEmpty
        ? DateTime.tryParse(act['deadline']) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setModal) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Activity Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: deadline ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) setModal(() => deadline = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(deadline == null ? 'Set Deadline (optional)'
                    : 'Deadline: ${deadline!.year}-${deadline!.month.toString().padLeft(2,'0')}-${deadline!.day.toString().padLeft(2,'0')}',
                    style: TextStyle(color: deadline == null ? Colors.grey[600] : null)),
                const Spacer(),
                if (deadline != null) GestureDetector(
                  onTap: () => setModal(() => deadline = null),
                  child: const Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final deadlineStr = deadline != null
                    ? '${deadline!.year}-${deadline!.month.toString().padLeft(2,'0')}-${deadline!.day.toString().padLeft(2,'0')}' : '';
                final updated = {...act, 'title': title, 'description': descCtrl.text.trim(), 'deadline': deadlineStr};
                try {
                  final db = await ActivityDatabase.instance.database;
                  final fields = {'title': title, 'description': descCtrl.text.trim(), 'deadline': deadlineStr};
                  if (act['id'] != null) {
                    await db.update('activities', fields, where: 'id = ?', whereArgs: [act['id']]);
                  } else {
                    await db.update('activities', fields, where: 'title = ? AND date = ?', whereArgs: [act['title'], act['date']]);
                  }
                  setState(() {
                    _localActivities = List.from(_localActivities)..[i] = updated;
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ]),
      )),
    );
  }

  void _deleteActivity(int i) {
    final act = _localActivities[i];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Activity'),
        content: Text('Delete "${act['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final db = await ActivityDatabase.instance.database;
                if (act['id'] != null) {
                  await db.delete('activities', where: 'id = ?', whereArgs: [act['id']]);
                } else {
                  await db.delete('activities', where: 'title = ? AND date = ?', whereArgs: [act['title'], act['date']]);
                }
                setState(() {
                  _localActivities = List.from(_localActivities)..removeAt(i);
                });
              } catch (_) {}
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Edit / Delete Announcement ───────────────────────────────────────────
  void _editAnnouncement(int i) {
    final ann = _localAnnouncements[i];
    final titleCtrl = TextEditingController(text: ann['title'] ?? '');
    final msgCtrl = TextEditingController(text: ann['message'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Edit Announcement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: msgCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder(), alignLabelWithHint: true)),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final updated = {...ann, 'title': title, 'message': msgCtrl.text.trim()};
                try {
                  final db = await ActivityDatabase.instance.database;
                  final fields = {'title': title, 'message': msgCtrl.text.trim()};
                  if (ann['id'] != null) {
                    await db.update('announcements', fields, where: 'id = ?', whereArgs: [ann['id']]);
                  } else {
                    await db.update('announcements', fields, where: 'title = ? AND date = ?', whereArgs: [ann['title'], ann['date']]);
                  }
                  setState(() {
                    _localAnnouncements = List.from(_localAnnouncements)..[i] = updated;
                  });
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _deleteAnnouncement(int i) {
    final ann = _localAnnouncements[i];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Delete "${ann['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final db = await ActivityDatabase.instance.database;
                if (ann['id'] != null) {
                  await db.delete('announcements', where: 'id = ?', whereArgs: [ann['id']]);
                } else {
                  await db.delete('announcements', where: 'title = ? AND date = ?', whereArgs: [ann['title'], ann['date']]);
                }
                setState(() {
                  _localAnnouncements = List.from(_localAnnouncements)..removeAt(i);
                });
              } catch (_) {}
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}