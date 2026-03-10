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
      case 0: return _activitiesSection();
      case 1: return _genericSection('Student Grades', const Center(child: Text('Grades List Here')));
      case 2: return _genericSection('Announcements', const Center(child: Text('Announcements List')));
      case 4: return _genericSection('Attendance Records', const Center(child: Text('Attendance Data')));
      case 5: return _genericSection('Teacher Profile', _profileContent());
      default: return const SizedBox();
    }
  }

  Widget _genericSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
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
          padding: const EdgeInsets.fromLTRB(24, 70, 24, 20),
          child: const Text('Teacher Activities', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
