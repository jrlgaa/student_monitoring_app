// dart
import 'package:flutter/material.dart';

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

  // Controllers for the upload modal
  final TextEditingController _activityTitleController = TextEditingController();
  final TextEditingController _activityDescController = TextEditingController();

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Prevents layout overflow when the keyboard opens for uploading
      resizeToAvoidBottomInset: false,

      // Floating Action Button only appears when "Activities" is selected
      floatingActionButton: selectedIndex == 0
          ? FloatingActionButton.extended(
        onPressed: () => _showUploadModal(context),
        label: const Text('Upload Activity'),
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
  void _showUploadModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows modal to move up with keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // Handle logic to add activity here
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity uploaded successfully!')),
                  );
                  _activityTitleController.clear();
                  _activityDescController.clear();
                },
                child: const Text('Post Activity'),
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
        return _genericSection('Announcements', const Center(child: Text('Announcements List')));
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
            itemCount: 5,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemBuilder: (context, index) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: const Icon(Icons.description, color: Colors.blue),
                title: Text('Module ${index + 1}: Lesson Topic'),
                subtitle: const Text('Posted on Oct 24, 2023'),
                trailing: const Icon(Icons.more_vert),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ================= ATTENDANCE SECTION =================
  Widget _attendanceSection() {
    if (students.isEmpty) {
      return _genericSection('Attendance Records', const Center(child: Text('No students available')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ensure title clears floating hamburger
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 22, 24, 12),
          child: const Text('Attendance Records', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final name = students[index];
              final current = attendanceStatus[index] ?? 'Present';
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(child: Text(name.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join())),
                  title: Text(name),
                  subtitle: const Text('Tap to change status'),
                  trailing: DropdownButton<String>(
                    value: current,
                    items: const [
                      DropdownMenuItem(value: 'Present', child: Text('Present')),
                      DropdownMenuItem(value: 'Absent', child: Text('Absent')),
                      DropdownMenuItem(value: 'Lates', child: Text('Late')),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() {
                        attendanceStatus[index] = val;
                      });
                    },
                  ),
                ),
              );
            },
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
