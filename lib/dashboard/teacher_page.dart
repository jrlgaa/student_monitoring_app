// dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:project/database/teacher_db.dart';

class TeacherPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const TeacherPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _announcements = [];
  // UPDATED: students list is now initialized from the database
  List<String> students = [];

  final TextEditingController _activityTitleController = TextEditingController();
  final TextEditingController _activityDescController = TextEditingController();
  final TextEditingController _announcementTitleController = TextEditingController();
  final TextEditingController _announcementMessageController = TextEditingController();

  late final TextEditingController _editActivityTitleController;
  late final TextEditingController _editActivityDescController;
  late final TextEditingController _editAnnouncementTitleController;
  late final TextEditingController _editAnnouncementMessageController;

  Map<String, dynamic> teacherProfile = {
    'name': 'Maria Santos',
    'teacherId': 'TCH-001',
    'email': 'maria.santos@school.com',
    'phone': '+63 912 345 6789',
    'subject': 'Mathematics',
    'advisoryClass': 'Grade 7-A',
  };
  bool isEditing = false;

  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _subjectController;
  late final TextEditingController _advisoryClassController;

  final List<String> menuTitles = [
    'Activities',
    'Students',
    'Announcements',
    'Attendance',
    'Profile',
  ];

  final List<IconData> menuIcons = [
    Icons.folder,
    Icons.school,
    Icons.campaign,
    Icons.calendar_month,
    Icons.person,
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

  @override
  void initState() {
    super.initState();
    _editActivityTitleController = TextEditingController();
    _editActivityDescController = TextEditingController();
    _editAnnouncementTitleController = TextEditingController();
    _editAnnouncementMessageController = TextEditingController();

    _emailController = TextEditingController(text: teacherProfile['email']);
    _phoneController = TextEditingController(text: teacherProfile['phone']);
    _subjectController = TextEditingController(text: teacherProfile['subject']);
    _advisoryClassController = TextEditingController(text: teacherProfile['advisoryClass']);

    _fetchDatabaseContent();
  }

  // UPDATED: Helper to initialize state for a newly added student
  void _addStudentToState(String studentName) {
    if (!students.contains(studentName)) {
      setState(() {
        students.add(studentName);
        _studentActivities[studentName] = List<Map<String, dynamic>>.from(_activities);
        _studentGrades[studentName] = {};
        _gradeControllers[studentName] = {};

        for (var activity in _activities) {
          String key = _getActivityKey(activity);
          _studentGrades[studentName]![key] = {
            'grade': null,
            'maxScore': _defaultMaxScore,
            'status': 'Ungraded'
          };
          _gradeControllers[studentName]![key] = TextEditingController();
        }
      });
    }
  }

  // UPDATED: Show dialog to pick students added by Admin
  void _showAddStudentDialog() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'user_data.db');
      final db = await openDatabase(path);

      // Fetch students from the admin's student table
      final List<Map<String, dynamic>> availableStudents = await db.query('students');

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Student to Add'),
          content: SizedBox(
            width: double.maxFinite,
            child: availableStudents.isEmpty
                ? const Text('No students found. Please ask the admin to add students.')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: availableStudents.length,
              itemBuilder: (context, index) {
                final student = availableStudents[index];
                final fullName = "${student['firstName']} ${student['lastName']}";
                return ListTile(
                  title: Text(fullName),
                  subtitle: Text("LRN: ${student['lrn']}"),
                  trailing: const Icon(Icons.add, color: Colors.green),
                  onTap: () {
                    _addStudentToState(fullName);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$fullName added to class')),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
          ],
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

  void _initGradingState() {
    for (String student in students) {
      _studentGrades[student] = {};
      _gradeControllers[student] = {};
    }
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
    _editActivityTitleController.dispose();
    _editActivityDescController.dispose();
    _editAnnouncementTitleController.dispose();
    _editAnnouncementMessageController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _advisoryClassController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () => _showUploadModal(context),
        label: const Text('Upload Activity'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : selectedIndex == 2
          ? FloatingActionButton.extended(
        onPressed: () => _showAnnouncementModal(context),
        label: const Text('Post Announcement'),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
              child: _buildSection(),
            ),
            if (isSidebarOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => isSidebarOpen = false),
                  child: Container(color: Colors.black26),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: isSidebarOpen ? 0 : -260,
              top: 0,
              bottom: 0,
              width: 260,
              child: Container(
                decoration: BoxDecoration(
                  color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => setState(() => isSidebarOpen = !isSidebarOpen),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      teacherProfile['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      "Teacher ID: ${teacherProfile['teacherId']}",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 30),
                    Expanded(
                      child: ListView.builder(
                        itemCount: menuTitles.length,
                        itemBuilder: (context, index) {
                          final selected = index == selectedIndex;
                          return ListTile(
                            leading: Icon(menuIcons[index], color: selected ? Colors.blue : null),
                            title: Text(menuTitles[index],
                                style: TextStyle(
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  color: selected ? Colors.blue : null,
                                )),
                            selected: selected,
                            selectedTileColor: Colors.blue.withOpacity(0.05),
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                                isSidebarOpen = false;
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: const Text("Dark Mode"),
                          trailing: Switch(
                            value: widget.isDarkMode,
                            onChanged: (_) => widget.toggleTheme(),
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                      onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            if (!isSidebarOpen)
              Positioned(
                top: 16,
                left: 16,
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => setState(() => isSidebarOpen = true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _studentsSection() {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: const [
                  SizedBox(width: 48),
                  SizedBox(width: 8),
                  Text(
                    'Student Grades',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('Click the "+Add" button to select students.'))
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, sIndex) {
                  String student = students[sIndex];
                  bool isExpanded = _expandedStudents.contains(student);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          if (expanded) {
                            _expandedStudents.add(student);
                            selectedStudent = student;
                          } else {
                            _expandedStudents.remove(student);
                          }
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(
                          student.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        student,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selectedStudent == student ? Colors.blue : null,
                        ),
                      ),
                      subtitle: Text('${_activities.length} activities'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: (_studentActivities[student]?.isEmpty ?? true)
                              ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text('No activities posted yet.',
                                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                                ],
                              ),
                            ),
                          )
                              : Column(
                            children: [
                              SizedBox(
                                height: 300,
                                child: ListView.separated(
                                  physics: const ClampingScrollPhysics(),
                                  itemCount: _studentActivities[student]!.length,
                                  separatorBuilder: (context, aIndex) => const Divider(),
                                  itemBuilder: (context, aIndex) {
                                    Map<String, dynamic> activity = _studentActivities[student]![aIndex];
                                    String key = _getActivityKey(activity);
                                    Map<String, dynamic> gradeData = _studentGrades[student]![key] ?? {};
                                    TextEditingController controller = _gradeControllers[student]![key]!;
                                    String status = gradeData['status'] ?? 'Ungraded';
                                    return Card(
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(activity['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: controller,
                                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                    decoration: InputDecoration(
                                                      labelText: 'Grade / $_defaultMaxScore',
                                                      border: const OutlineInputBorder(),
                                                      prefixIcon: const Icon(Icons.grade),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.save, color: Colors.blue),
                                                  onPressed: () => _saveGrade(student, key, controller.text),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          top: 16,
          right: 16,
          child: ElevatedButton.icon(
            // UPDATED: Now triggers the selection dialog
            onPressed: _showAddStudentDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreen,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showUploadModal(BuildContext context) {
    _selectedFile = null;
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
                    };

                    try {
                      await ActivityDatabase.instance.insertActivity(activityData);
                      setState(() {
                        _activities.insert(0, activityData);
                      });
                      _initNewActivityForAllStudents(activityData);

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
      debugPrint("Error picking file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _fetchDatabaseContent() async {
    try {
      final data = await ActivityDatabase.instance.getActivities();
      final announcementData = await ActivityDatabase.instance.getAnnouncements();
      setState(() {
        _activities = List<Map<String, dynamic>>.from(data);
        _announcements = List<Map<String, dynamic>>.from(announcementData);
      });
      for (var activity in _activities) {
        _initNewActivityForAllStudents(activity);
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
                  if (title.isEmpty || message.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please fill in all fields')),
                    );
                    return;
                  }
                  final newAnnouncement = {
                    'title': title,
                    'message': message,
                    'date': _getCurrentDate(),
                  };
                  try {
                    await ActivityDatabase.instance.insertAnnouncement(newAnnouncement);
                    setState(() {
                      _announcements.insert(0, newAnnouncement);
                    });
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Announcement posted successfully!')),
                      );
                      _announcementTitleController.clear();
                      _announcementMessageController.clear();
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
    );
  }

  Widget _buildSection() {
    switch (selectedIndex) {
      case 0:
        return _activitiesSection();
      case 1:
        return _studentsSection();
      case 2:
        return _announcementsSection();
      case 3:
        return _attendanceSection();
      case 4:
        return _genericSection('Teacher Profile', _profileContent());
      default:
        return const SizedBox();
    }
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
                Text('Upload your first activity!', style: TextStyle(fontSize: 14, color: Colors.grey)),
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
                      if (activity['description'] != null && activity['description'].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(activity['description']),
                        ),
                      Text('Posted on ${activity['date']}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                    ],
                    onSelected: (value) => _handleActivityMenuAction(value, index),
                  ),
                  onTap: fileName != null ? () => _showFileDetails(context, activity) : null,
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
                elevation: 2,
                child: ListTile(
                  leading: Icon(Icons.campaign, color: Colors.blue.shade700),
                  title: Text(announcement['title'] ?? 'Untitled', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(announcement['message'] ?? '', style: TextStyle(fontSize: 14, color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700], height: 1.5)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text('Posted on ${announcement['date']}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Delete')])),
                    ],
                    onSelected: (value) => _handleAnnouncementMenuAction(value, index),
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
            if (activity['fileName'] != null) ...[
              const Text('Attached File:', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(child: Text(activity['fileName'], style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
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
    final DateTime? picked = await showDatePicker(context: context, initialDate: _selectedAttendanceDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null && picked != _selectedAttendanceDate) {
      setState(() {
        _selectedAttendanceDate = picked;
        _currentAttendance = {};
      });
    }
  }

  void _markAllPresent() {
    final key = _getDateKey(_selectedAttendanceDate);
    setState(() => _attendanceRecords[key] = {for (var i = 0; i < students.length; i++) i: 'Present'});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All students marked as Present')));
  }

  void _saveAttendance() {
    final key = _getDateKey(_selectedAttendanceDate);
    setState(() => _attendanceRecords[key] = Map.from(_currentAttendance));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance saved for ${_formatDate(_selectedAttendanceDate)}')));
  }

  Widget _buildAttendanceSummary(Map<int, String> attendanceMap) {
    final present = _getCountForStatus(attendanceMap, 'Present');
    final absent = _getCountForStatus(attendanceMap, 'Absent');
    final late = _getCountForStatus(attendanceMap, 'Late');
    final notMarked = students.length - present - absent - late;
    final total = students.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total', total, Colors.blue),
                _buildSummaryItem('Present', present, Colors.green),
                _buildSummaryItem('Absent', absent, Colors.red),
                _buildSummaryItem('Late', late, Colors.orange),
                _buildSummaryItem('Not Marked', notMarked, Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Text(count.toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _attendanceSection() {
    if (students.isEmpty) {
      return _genericSection('Attendance Records', const Center(child: Text('No students found. Use the Students tab to add them.')));
    }
    if (_currentAttendance.isEmpty) _currentAttendance = _getAttendanceForDate(_selectedAttendanceDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SizedBox(width: 48),
              SizedBox(width: 8),
              Text('Attendance Records', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectAttendanceDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [const Icon(Icons.calendar_today, size: 20, color: Colors.blue), const SizedBox(width: 8), Text(_formatDate(_selectedAttendanceDate), style: const TextStyle(fontSize: 14))]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(onPressed: _markAllPresent, icon: const Icon(Icons.check_circle, size: 18), label: const Text('Mark All Present'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAttendanceSummary(_currentAttendance)),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final name = students[index];
              final current = _currentAttendance[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.shade100, child: Text(name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                  title: Text(name),
                  trailing: DropdownButton<String>(
                    value: current,
                    hint: const Text('Select status'),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(value: 'Present', child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Present')])),
                      DropdownMenuItem(value: 'Absent', child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Absent')])),
                      DropdownMenuItem(value: 'Late', child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)), const SizedBox(width: 6), const Text('Late')])),
                    ],
                    onChanged: (val) { if (val != null) setState(() => _currentAttendance[index] = val); },
                  ),
                ),
              );
            },
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(onPressed: _saveAttendance, icon: const Icon(Icons.save), label: const Text('Save Attendance'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)))),
      ],
    );
  }

  void _handleActivityMenuAction(String action, int index) {
    final activity = _activities[index];
    if (action == 'edit') {
      _editActivityTitleController.text = activity['title'] ?? '';
      _editActivityDescController.text = activity['description'] ?? '';
      _showEditActivityModal(index);
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Activity'),
          content: const Text('Are you sure you want to delete this activity?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () {
              final activityToDelete = Map<String, dynamic>.from(_activities[index]);
              _removeActivityFromAllStudents(activityToDelete);
              setState(() => _activities.removeAt(index));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity deleted successfully')));
            },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _handleAnnouncementMenuAction(String action, int index) {
    if (action == 'edit') {
      _editAnnouncementTitleController.text = _announcements[index]['title'] ?? '';
      _editAnnouncementMessageController.text = _announcements[index]['message'] ?? '';
      _showEditAnnouncementModal(index);
    } else if (action == 'delete') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Announcement'),
          content: const Text('Are you sure you want to delete this announcement?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () { setState(() => _announcements.removeAt(index)); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted successfully'))); }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      );
    }
  }

  void _showEditActivityModal(int index) {
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
            const Text('Edit Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _editActivityTitleController, decoration: const InputDecoration(labelText: 'Activity Title', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _editActivityDescController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description / Instructions', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)), child: Text(_activities[index]['fileName'] != null ? 'Current file: ${_activities[index]['fileName']}\n(Replacement not implemented)' : 'No file attached', style: const TextStyle(fontSize: 14))),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))), const SizedBox(width: 12), Expanded(flex: 2, child: ElevatedButton(onPressed: () {
              final oldActivity = Map<String, dynamic>.from(_activities[index]);
              _activities[index]['title'] = _editActivityTitleController.text;
              _activities[index]['description'] = _editActivityDescController.text;
              _activities[index]['date'] = _getCurrentDate();
              setState(() {});
              _removeActivityFromAllStudents(oldActivity);
              _initNewActivityForAllStudents(_activities[index]);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activity updated successfully')));
            }, child: const Text('Update Activity')))]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditAnnouncementModal(int index) {
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
            const Text('Edit Announcement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: _editAnnouncementTitleController, decoration: const InputDecoration(labelText: 'Announcement Title', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _editAnnouncementMessageController, maxLines: 4, decoration: const InputDecoration(labelText: 'Announcement Message', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))), const SizedBox(width: 12), Expanded(flex: 2, child: ElevatedButton(onPressed: () { setState(() { _announcements[index]['title'] = _editAnnouncementTitleController.text; _announcements[index]['message'] = _editAnnouncementMessageController.text; _announcements[index]['date'] = _getCurrentDate(); }); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement updated successfully'))); }, child: const Text('Update Announcement')))]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _toggleEditMode() {
    setState(() {
      if (isEditing) {
        teacherProfile['email'] = _emailController.text;
        teacherProfile['phone'] = _phoneController.text;
        teacherProfile['subject'] = _subjectController.text;
        teacherProfile['advisoryClass'] = _advisoryClassController.text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
      }
      isEditing = !isEditing;
    });
  }

  void _cancelEdit() {
    setState(() {
      _emailController.text = teacherProfile['email'];
      _phoneController.text = teacherProfile['phone'];
      _subjectController.text = teacherProfile['subject'];
      _advisoryClassController.text = teacherProfile['advisoryClass'];
      isEditing = false;
    });
  }

  Widget _profileContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 50, backgroundColor: Colors.blue, child: Icon(Icons.person, size: 50, color: Colors.white)),
                    const SizedBox(width: 20),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(teacherProfile['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), Text('Teacher ID: ${teacherProfile['teacherId']}', style: TextStyle(fontSize: 14, color: Colors.grey[600]))])),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Teacher Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.email, color: Colors.blue), title: const Text('Email'), subtitle: isEditing ? TextField(controller: _emailController, decoration: const InputDecoration(hintText: 'Enter email', border: InputBorder.none)) : Text(teacherProfile['email']))),
            Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.phone, color: Colors.blue), title: const Text('Phone Number'), subtitle: isEditing ? TextField(controller: _phoneController, decoration: const InputDecoration(hintText: 'Enter phone number', border: InputBorder.none), keyboardType: TextInputType.phone) : Text(teacherProfile['phone']))),
            Card(margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.school, color: Colors.blue), title: const Text('Subject'), subtitle: isEditing ? TextField(controller: _subjectController, decoration: const InputDecoration(hintText: 'Enter subject', border: InputBorder.none)) : Text(teacherProfile['subject']))),
            Card(margin: const EdgeInsets.only(bottom: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: ListTile(leading: const Icon(Icons.group, color: Colors.blue), title: const Text('Advisory Class'), subtitle: isEditing ? TextField(controller: _advisoryClassController, decoration: const InputDecoration(hintText: 'Enter advisory class', border: InputBorder.none)) : Text(teacherProfile['advisoryClass']))),
            SizedBox(width: double.infinity, height: 50, child: isEditing ? Row(children: [Expanded(child: ElevatedButton(onPressed: _cancelEdit, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('Cancel'))), const SizedBox(width: 12), Expanded(flex: 2, child: ElevatedButton.icon(onPressed: _toggleEditMode, icon: const Icon(Icons.save), label: const Text('Save Changes'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue)))]) : ElevatedButton.icon(onPressed: _toggleEditMode, icon: const Icon(Icons.edit), label: const Text('Edit Profile'), style: ElevatedButton.styleFrom(backgroundColor: Colors.blue))),
          ],
        ),
      ),
    );
  }

  void _saveGrade(String student, String activityKey, String gradeText) {
    double? grade;
    if (gradeText.isNotEmpty) {
      grade = double.tryParse(gradeText);
      if (grade == null || grade < 0 || grade > _defaultMaxScore) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid grade (0-${_defaultMaxScore.toStringAsFixed(0)})')));
        return;
      }
    }
    setState(() {
      _studentGrades[student]![activityKey]!['grade'] = grade;
      _studentGrades[student]![activityKey]!['status'] = grade != null ? 'Graded' : 'Ungraded';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Grade saved for $student')));
  }

  void _initNewActivityForAllStudents(Map<String, dynamic> activity) {
    String key = _getActivityKey(activity);
    for (String student in students) {
      _studentActivities[student] ??= [];
      _studentActivities[student]!.add(Map<String, dynamic>.from(activity));
      _studentGrades[student] ??= {};
      _studentGrades[student]![key] = {'grade': null, 'maxScore': _defaultMaxScore, 'status': 'Ungraded'};
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
      if (_gradeControllers[student]?[key] != null) {
        _gradeControllers[student]![key]!.dispose();
        _gradeControllers[student]!.remove(key);
      }
    }
    setState(() {});
  }
}