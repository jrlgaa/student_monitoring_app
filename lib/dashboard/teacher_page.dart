import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for input formatters
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

  String? _profileImagePath; // local path to the picked profile picture

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
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      backgroundImage: _profileImagePath != null
                          ? FileImage(File(_profileImagePath!))
                          : null,
                      child: _profileImagePath == null
                          ? const Icon(Icons.person, size: 40, color: Colors.white)
                          : null,
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
    List<String> filteredStudents = students.where((name) {
      return name.toLowerCase().contains(_studentSearchController.text.toLowerCase());
    }).toList();
    filteredStudents.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 24, 8),
              child: Row(
                children: const [
                  SizedBox(width: 48),
                  Text(
                    'Student Progress',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _studentSearchController,
                decoration: InputDecoration(
                  hintText: 'Search added students...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            Expanded(
              child: students.isEmpty
                  ? const Center(child: Text('Click the "+Add" button to select students.'))
                  : filteredStudents.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      "No student found matching '${_studentSearchController.text}'",
                      style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
                  : ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredStudents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, sIndex) {
                  String student = filteredStudents[sIndex];

                  double totalScore = 0;
                  int gradedCount = 0;
                  _studentGrades[student]?.forEach((key, data) {
                    if (data['grade'] != null) {
                      totalScore += data['grade'];
                      gradedCount++;
                    }
                  });
                  String summaryText = gradedCount > 0
                      ? "Summary: ${(totalScore / (gradedCount * 100) * 100).toStringAsFixed(0)}%"
                      : "Grade Summary: 0%";

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: Text(student.substring(0, 1).toUpperCase()),
                      ),
                      title: _highlightText(student, _studentSearchController.text),
                      subtitle: Text('${_activities.length} total activities'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              ..._activities.map((activity) {
                                String key = _getActivityKey(activity);
                                Map<String, dynamic> gradeData = _studentGrades[student]![key] ?? {};
                                TextEditingController controller = _gradeControllers[student]![key]!;

                                double score = gradeData['grade'] ?? 0.0;
                                String percentage = "${((score / _defaultMaxScore) * 100).toStringAsFixed(0)}%";

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(activity['title'],
                                                style: const TextStyle(fontWeight: FontWeight.w600)),
                                          ),
                                          DropdownButton<String>(
                                            value: gradeData['status'] ?? 'Pending',
                                            underline: const SizedBox(),
                                            items: ['Pending', 'Completed', 'Late', 'Missed'].map((String value) {
                                              return DropdownMenuItem<String>(
                                                value: value,
                                                child: Text(value, style: TextStyle(
                                                  fontSize: 12,
                                                  color: value == 'Missed' ? Colors.red
                                                      : value == 'Late' ? Colors.orange.shade700
                                                      : (value == 'Completed' ? Colors.green : Colors.orange),
                                                )),
                                              );
                                            }).toList(),
                                            onChanged: (newValue) {
                                              setState(() {
                                                _studentGrades[student]![key]!['status'] = newValue;
                                                if (newValue == 'Missed') {
                                                  _studentGrades[student]![key]!['grade'] = 0.0;
                                                  controller.text = "0";
                                                }
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Score',
                                                suffixText: '/ 100',
                                                hintText: '/ 100',
                                                border: const OutlineInputBorder(),
                                                helperText: 'Percentage: $percentage',
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
                                );
                              }).toList(),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      summaryText,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                  ],
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
            onPressed: _showAddStudentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreen, foregroundColor: Colors.white),
          ),
        ),
      ],
    );
  }

  void _saveGrade(String student, String activityKey, String gradeText) {
    double? score = double.tryParse(gradeText);

    if (score != null && (score < 0 || score > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a score between 0 and 100')),
      );
      return;
    }

    setState(() {
      _studentGrades[student]![activityKey]!['grade'] = score;
      String currentStatus = _studentGrades[student]![activityKey]!['status'] ?? 'Pending';
      if (score != null && currentStatus == 'Pending') {
        _studentGrades[student]![activityKey]!['status'] = 'Completed';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ${score?.toStringAsFixed(0) ?? "0"} for $student')),
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

  // UPDATED: Fetches profile and content from the database
  Future<void> _fetchDatabaseContent() async {
    // Fallback profile used when DB has no teacher record or throws an error
    final fallbackProfile = {
      'teacherId': _generateTeacherId(),
      'name': 'Ryan Caesar Mendoza',
      'email': 'rycaesarmendoza@deped.gov.ph',
      'phone': '09123456789',
      'subject': 'Software Engineering',
      'advisoryClass': 'BSIT-3A',
    };

    Map<String, dynamic>? profileData;
    List<Map<String, dynamic>> data = [];
    List<Map<String, dynamic>> announcementData = [];

    try {
      // 1. Fetch Teacher Profile from DB
      profileData = await ActivityDatabase.instance.getTeacherProfile();

      // 2. Fetch Activities and Announcements
      data = await ActivityDatabase.instance.getActivities();
      announcementData = await ActivityDatabase.instance.getAnnouncements();
    } catch (e) {
      debugPrint("Error loading data: $e");
      // profileData stays null — fallback will be used below
    }

    // Always call setState so the UI exits "Loading..." regardless of DB outcome
    setState(() {
      final profile = profileData ?? fallbackProfile;
      teacherProfile = Map<String, dynamic>.from(profile);

      // Sync text controllers with whatever profile data we have
      _nameController.text = teacherProfile['name'] ?? '';
      _emailController.text = teacherProfile['email'] ?? '';
      _phoneController.text = teacherProfile['phone'] ?? '';
      _advisoryClassController.text = teacherProfile['advisoryClass'] ?? '';

      _activities = List<Map<String, dynamic>>.from(data);
      _announcements = List<Map<String, dynamic>>.from(announcementData);
    });

    for (var activity in _activities) {
      _initNewActivityForAllStudents(activity);
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
                  subtitle: Text('Posted on ${activity['date']}'),
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
                  subtitle: Text(announcement['message'] ?? ''),
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
  }

  void _saveAttendance() {
    final key = _getDateKey(_selectedAttendanceDate);
    setState(() => _attendanceRecords[key] = Map.from(_currentAttendance));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attendance saved for ${_formatDate(_selectedAttendanceDate)}')));
  }

  Widget _buildAttendanceSummary(Map<int, String> attendanceMap) {
    final present = _getCountForStatus(attendanceMap, 'Present');
    final absent = _getCountForStatus(attendanceMap, 'Absent');
    final total = students.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(children: [Text(total.toString(), style: const TextStyle(fontWeight: FontWeight.bold)), const Text('Total')]),
            Column(children: [Text(present.toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)), const Text('Present')]),
            Column(children: [Text(absent.toString(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), const Text('Absent')]),
          ],
        ),
      ),
    );
  }

  Widget _attendanceSection() {
    if (students.isEmpty) {
      return _genericSection('Attendance', const Center(child: Text('Add students first.')));
    }
    if (_currentAttendance.isEmpty) _currentAttendance = _getAttendanceForDate(_selectedAttendanceDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
          child: Row(
            children: [
              const SizedBox(width: 48), // offset for burger menu icon
              const Text('Attendance Records', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                    child: Text(_formatDate(_selectedAttendanceDate)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: _markAllPresent, child: const Text('Mark All Present')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildAttendanceSummary(_currentAttendance)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final name = students[index];
              return ListTile(
                title: Text(name),
                trailing: DropdownButton<String>(
                  value: _currentAttendance[index],
                  hint: const Text('Status'),
                  items: [
                    DropdownMenuItem(
                      value: 'Present',
                      child: Text('Present', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600)),
                    ),
                    DropdownMenuItem(
                      value: 'Absent',
                      child: Text('Absent', style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600)),
                    ),
                    DropdownMenuItem(
                      value: 'Late',
                      child: Text('Late', style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.w600)),
                    ),
                  ],
                  onChanged: (val) { if (val != null) setState(() => _currentAttendance[index] = val); },
                ),
              );
            },
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saveAttendance, child: const Text('Save Attendance')))),
      ],
    );
  }

  void _handleActivityMenuAction(String action, int index) {
    if (action == 'edit') {
      _editActivityTitleController.text = _activities[index]['title'] ?? '';
      _editActivityDescController.text = _activities[index]['description'] ?? '';
      _showEditActivityModal(index);
    } else if (action == 'delete') {
      setState(() => _activities.removeAt(index));
    }
  }

  void _handleAnnouncementMenuAction(String action, int index) {
    if (action == 'edit') {
      _editAnnouncementTitleController.text = _announcements[index]['title'] ?? '';
      _editAnnouncementMessageController.text = _announcements[index]['message'] ?? '';
      _showEditAnnouncementModal(index);
    } else if (action == 'delete') {
      setState(() => _announcements.removeAt(index));
    }
  }

  void _showEditActivityModal(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _editActivityTitleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _editActivityDescController, decoration: const InputDecoration(labelText: 'Description')),
            ElevatedButton(onPressed: () {
              setState(() {
                _activities[index]['title'] = _editActivityTitleController.text;
                _activities[index]['description'] = _editActivityDescController.text;
              });
              Navigator.pop(context);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  void _showEditAnnouncementModal(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _editAnnouncementTitleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _editAnnouncementMessageController, decoration: const InputDecoration(labelText: 'Message')),
            ElevatedButton(onPressed: () {
              setState(() {
                _announcements[index]['title'] = _editAnnouncementTitleController.text;
                _announcements[index]['message'] = _editAnnouncementMessageController.text;
              });
              Navigator.pop(context);
            }, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  // UPDATED: Saves profile changes back to the SQL database
  void _toggleEditMode() async {
    if (isEditing) {
      final updatedProfile = {
        ...teacherProfile,
        'phone': _phoneController.text,
        'advisoryClass': _advisoryClassController.text,
      };

      try {
        // Save to Database via teacher_db.dart logic
        await ActivityDatabase.instance.updateTeacherProfile(updatedProfile);

        // Reload from DB so teacherId stays in sync (e.g. after first insert)
        final savedProfile = await ActivityDatabase.instance.getTeacherProfile();

        setState(() {
          teacherProfile = savedProfile ?? updatedProfile;
          _nameController.text = teacherProfile['name'] ?? '';
          _emailController.text = teacherProfile['email'] ?? '';
          _phoneController.text = teacherProfile['phone'] ?? '';
          _advisoryClassController.text = teacherProfile['advisoryClass'] ?? '';
          isEditing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated in database')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    } else {
      setState(() => isEditing = true);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _profileImagePath = result.files.single.path);
      }
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