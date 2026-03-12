// dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

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

  // File upload state
  PlatformFile? _selectedFile;

  // Activity model
  final List<Map<String, dynamic>> _activities = [
    {'title': 'Module 1: Introduction', 'description': 'Basic concepts and fundamentals', 'fileName': 'intro.pdf', 'date': 'Oct 24, 2023'},
    {'title': 'Module 2: Advanced Topics', 'description': 'Deep dive into advanced concepts', 'fileName': 'advanced.pdf', 'date': 'Oct 25, 2023'},
    {'title': 'Module 3: Practice Exercises', 'description': 'Hands-on practice problems', 'fileName': null, 'date': 'Oct 26, 2023'},
    {'title': 'Module 4: Case Studies', 'description': 'Real-world applications', 'fileName': 'cases.docx', 'date': 'Oct 27, 2023'},
    {'title': 'Module 5: Final Review', 'description': 'Com prehensive review material', 'fileName': 'review.pptx', 'date': 'Oct 28, 2023'},
  ];

  // Announcements model
  final List<Map<String, dynamic>> _announcements = [
    {
      'title': 'Quiz Reminder',
      'message': 'There will be a short quiz about HTML Basics in our next meeting. Please review the lesson and prepare your notes.',
      'date': 'March 15, 2026',
    },
    {
      'title': 'Activity Submission',
      'message': 'Please submit your Inventory System UI Design before the deadline. Make sure all sections are complete.',
      'date': 'March 18, 2026',
    },
    {
      'title': 'New Learning Materials',
      'message': 'The lesson slides about HTML and CSS have been uploaded. You can download the file in the Activities section.',
      'date': 'March 12, 2026',
    },
  ];

  // Controllers for the upload modal
  final TextEditingController _activityTitleController = TextEditingController();
  final TextEditingController _activityDescController = TextEditingController();

  // Controllers for the announcement modal
  final TextEditingController _announcementTitleController = TextEditingController();
  final TextEditingController _announcementMessageController = TextEditingController();

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

  // Attendance state
  final List<String> students = [
    'Dometita, Rainer',
    'Mendoza, Ryan Caesar',
    'Gaa, Jeriel',
    'Tagapan, Jhem',
    'Tayag, Joshua',
    'Ravida, Kris Lawrenc'
  ];
  final Map<int, String> attendanceStatus = {};
  
  // Enhanced Attendance state
  DateTime _selectedAttendanceDate = DateTime.now();
  final Map<String, Map<int, String>> _attendanceRecords = {}; // date string -> student index -> status
  Map<int, String> _currentAttendance = {}; // Current attendance being edited (not saved yet)

  @override
  void initState() {
    super.initState();
    // Initialize attendance status for each student to a safe default
    for (var i = 0; i < students.length; i++) {
      attendanceStatus[i] = 'Present';
    }
  }

  @override
  void dispose() {
    _activityTitleController.dispose();
    _activityDescController.dispose();
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Prevents layout overflow when the keyboard opens for uploading
      resizeToAvoidBottomInset: false,

      // Floating Action Button only appears when "Activities" or "Announcements" is selected
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
            // ================= MAIN CONTENT =================
            Container(
              color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
              child: _buildSection(),
            ),

            // ================= OVERLAY SIDEBAR =================
            if (isSidebarOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => isSidebarOpen = false),
                  child: Container(color: Colors.black26),
                ),
              ),

            // ================= SIDEBAR DRAWER =================
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
                    // HAMBURGER MENU ICON
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

                    // PROFILE SECTION
                    const SizedBox(height: 20),
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Juan Dela Cruz",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text(
                      "Teacher ID: 2024-001",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 30),

                    // NAVIGATION MENU
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

                    // BOTTOM SECTION: THEME & LOGOUT
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

            // ================= HAMBURGER MENU BUTTON (Floating) =================
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

  // ================= UPLOAD MODAL LOGIC =================
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result!.files.first;
      });
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  void _showUploadModal(BuildContext context) {
    // Reset file selection when opening modal
    _selectedFile = null;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows modal to move up with keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard padding
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
              // File Upload Section
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
                            child: Text(
                              _selectedFile!.name,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setModalState(() {
                                _selectedFile = null;
                              });
                              setState(() {});
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      )
                    : InkWell(
                        onTap: () async {
                          await _pickFile();
                          setModalState(() {});
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload_file, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Tap to attach file',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Create new activity with file
                    final newActivity = {
                      'title': _activityTitleController.text,
                      'description': _activityDescController.text,
                      'fileName': _selectedFile?.name,
                      'filePath': _selectedFile?.path,
                      'date': 'Just now',
                    };
                    
                    setState(() {
                      _activities.insert(0, newActivity);
                    });
                    
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_selectedFile != null 
                          ? 'Activity with file uploaded successfully!' 
                          : 'Activity uploaded successfully!'),
                      ),
                    );
                    _activityTitleController.clear();
                    _activityDescController.clear();
                    _selectedFile = null;
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

  // ================= ANNOUNCEMENT MODAL LOGIC =================
  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  void _showAnnouncementModal(BuildContext context) {
    // Clear controllers when opening modal
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
                onPressed: () {
                  if (_announcementTitleController.text.isEmpty ||
                      _announcementMessageController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please fill in all fields'),
                      ),
                    );
                    return;
                  }

                  // Create new announcement
                  final newAnnouncement = {
                    'title': _announcementTitleController.text,
                    'message': _announcementMessageController.text,
                    'date': _getCurrentDate(),
                  };

                  setState(() {
                    _announcements.insert(0, newAnnouncement);
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement posted successfully!'),
                    ),
                  );
                  _announcementTitleController.clear();
                  _announcementMessageController.clear();
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

  // ================= SECTION SWITCHER =================
  Widget _buildSection() {
    switch (selectedIndex) {
      case 0:
        return _activitiesSection();
      case 1:
        return _genericSection('Student Grades', const Center(child: Text('Grades List Here')));
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
        // Increased left padding so the title clears the floating hamburger/menu area.
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
        // Header row aligned with the floating hamburger (placed at top: 16, left: 16)
        Padding(
          // top set to 16 so it aligns vertically with the floating IconButton
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              // Reserve horizontal space for the floating hamburger button
              SizedBox(width: 48),

              // Small gap between the hamburger area and the title
              SizedBox(width: 8),

              // The actual title
              Text(
                'Teacher Activities',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
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
                  trailing: fileName != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.attach_file, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            const Icon(Icons.more_vert),
                          ],
                        )
                      : const Icon(Icons.more_vert),
                  onTap: fileName != null
                      ? () => _showFileDetails(context, activity)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= ANNOUNCEMENTS SECTION =================
  Widget _announcementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row aligned with the floating hamburger
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              // Reserve horizontal space for the floating hamburger button
              SizedBox(width: 48),
              // Small gap between the hamburger area and the title
              SizedBox(width: 8),
              // The actual title
              Text(
                'Announcements',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _announcements.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final announcement = _announcements[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title with icon
                      Row(
                        children: [
                          Icon(
                            Icons.campaign,
                            color: Colors.blue.shade700,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              announcement['title'] ?? 'Untitled',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Message / Description
                      Text(
                        announcement['message'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Date Posted
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Posted on ${announcement['date']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
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
    );
  }

  // Show file details dialog
  void _showFileDetails(BuildContext context, Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activity['title'] ?? 'Untitled',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(activity['description'] ?? 'No description'),
            const SizedBox(height: 16),
            if (activity['fileName'] != null) ...[
              const Text(
                'Attached File:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.insert_drive_file, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activity['fileName'],
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ================= ATTENDANCE SECTION =================
  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<int, String> _getAttendanceForDate(DateTime date) {
    final key = _getDateKey(date);
    if (_attendanceRecords.containsKey(key)) {
      return Map.from(_attendanceRecords[key]!);
    }
    // Return empty map for new dates - no default status
    return {};
  }

  int _getCountForStatus(Map<int, String> attendanceMap, String status) {
    return attendanceMap.values.where((s) => s == status).length;
  }

  Future<void> _selectAttendanceDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedAttendanceDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedAttendanceDate) {
      setState(() {
        _selectedAttendanceDate = picked;
        _currentAttendance = {}; // Clear current attendance for new date
      });
    }
  }

  void _markAllPresent() {
    final key = _getDateKey(_selectedAttendanceDate);
    setState(() {
      _attendanceRecords[key] = {for (var i = 0; i < students.length; i++) i: 'Present'};
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All students marked as Present')),
    );
  }

  void _saveAttendance() {
    final key = _getDateKey(_selectedAttendanceDate);
    setState(() {
      _attendanceRecords[key] = Map.from(_currentAttendance);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attendance saved for ${_formatDate(_selectedAttendanceDate)}')),
    );
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
            const Text(
              'Attendance Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _attendanceSection() {
    if (students.isEmpty) {
      return _genericSection('Attendance Records', const Center(child: Text('No students available')));
    }

    // Initialize _currentAttendance if empty (new date selected)
    if (_currentAttendance.isEmpty) {
      _currentAttendance = _getAttendanceForDate(_selectedAttendanceDate);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 24, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SizedBox(width: 48),
              SizedBox(width: 8),
              Text(
                'Attendance Records',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // Date selector and action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Date selector
              Expanded(
                child: InkWell(
                  onTap: () => _selectAttendanceDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(_selectedAttendanceDate),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Mark All Present button
              ElevatedButton.icon(
                onPressed: _markAllPresent,
                icon: const Icon(Icons.check_circle, size: 18),
                label: const Text('Mark All Present'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Attendance Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildAttendanceSummary(_currentAttendance),
        ),

        // Student list
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
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join(),
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name),
                  trailing: DropdownButton<String>(
                    value: current,
                    hint: const Text('Select status'),
                    underline: const SizedBox(),
                    items: [
                      DropdownMenuItem(
                        value: 'Present',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Present'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Absent',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Absent'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Late',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('Late'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        _currentAttendance[index] = val;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ),

        // Save button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveAttendance,
              icon: const Icon(Icons.save),
              label: const Text('Save Attendance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _profileContent() => Padding(
    padding: const EdgeInsets.all(20),
    child: Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: const Text('Juan Dela Cruz'),
        subtitle: const Text('teacher@deped.gov.ph'),
      ),
    ),
  );
}
