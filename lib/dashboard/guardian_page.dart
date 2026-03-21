import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

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

  final List<String> students = [
    'Dometita, Rainer', 'Mendoza, Ryan Caesar', 'Gaa, Jeriel',
    'Tagapan, Jhem', 'Tayag, Joshua', 'Ravida, Kris Lawrence'
  ];

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
    _fetchDatabaseData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchDatabaseData() async {
    setState(() => isLoading = true);
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'teacher_data.db');
      final Database db = await openDatabase(path);

      final List<Map<String, dynamic>> activityMaps = await db.query('activities', orderBy: 'id DESC');
      final List<Map<String, dynamic>> announcementMaps = await db.query('announcements', orderBy: 'id DESC');

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
    for (String student in students) {
      _studentGrades[student] = {};
      for (var activity in _activities) {
        String key = '${activity['title']}_${activity['date']}';
        _studentGrades[student]![key] = {'grade': 85.0, 'maxScore': 100.0, 'status': 'Graded'};
      }
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

  Widget _studentRegistrationSection() => _genericSection('Add Student', const Center(child: Text("Registration Logic")));
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