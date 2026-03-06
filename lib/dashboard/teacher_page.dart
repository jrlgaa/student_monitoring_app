import 'package:flutter/material.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  final List<String> menuTitles = [
    'Activities',
    'Students',
    'Announcements',
    'Messages',
    'Attendance',
    'Profile',
  ];

  final List<IconData> menuIcons = [
    Icons.folder,
    Icons.school,
    Icons.campaign,
    Icons.message,
    Icons.calendar_month,
    Icons.person,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // ================= SIDEBAR =================
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSidebarOpen ? 240 : 80,
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              child: Column(
                children: [
                  // This SizedBox aligns the menu icon vertically with the header text
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 80,
                    height: 50,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () {
                          setState(() {
                            isSidebarOpen = !isSidebarOpen;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: menuTitles.length,
                      itemBuilder: (context, index) {
                        final selected = index == selectedIndex;
                        return ListTile(
                          leading: SizedBox(
                            width: 32,
                            child: Icon(menuIcons[index]),
                          ),
                          title: isSidebarOpen ? Text(menuTitles[index]) : null,
                          selected: selected,
                          selectedTileColor: Colors.blue.withOpacity(0.2),
                          onTap: () {
                            setState(() {
                              selectedIndex = index;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const SizedBox(
                      width: 32,
                      child: Icon(Icons.logout, color: Colors.redAccent),
                    ),
                    title: isSidebarOpen ? const Text('Logout') : null,
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),

            // ================= MAIN CONTENT =================
            Expanded(
              child: Container(
                color: isDark ? Colors.grey[900] : Colors.white,
                child: _buildSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SECTION SWITCHER =================
  Widget _buildSection() {
    // All sections now use the same header logic to ensure alignment
    switch (selectedIndex) {
      case 0:
        return _activitiesSection();
      case 1:
        return _genericSection('Student Grades', _studentsContent());
      case 2:
        return _genericSection('Announcements', _announcementsContent());
      case 3:
        return _genericSection('Messages', const Center(child: Text('No Messages')));
      case 4:
        return _genericSection('Attendance Records', const Center(child: Text('Attendance Data')));
      case 5:
        return _genericSection('Teacher Profile', _profileContent());
      default:
        return const SizedBox();
    }
  }

  // ================= STICKY HEADER WRAPPER =================
  // This helper ensures every page has the same "Sticky Bar" position
  Widget _genericSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          // Top padding of 22 matches the sidebar menu icon position
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  // ================= SECTION CONTENTS =================

  Widget _activitiesSection() {
    return _genericSection(
      'Teacher Activities',
      ListView.builder(
        itemCount: 5,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text('Activity ${index + 1}'),
            subtitle: const Text('Activity description'),
          ),
        ),
      ),
    );
  }

  Widget _studentsContent() => const Center(child: Text('Grades List Here'));

  Widget _announcementsContent() => ListView.builder(
    itemCount: 3,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    itemBuilder: (context, index) => Card(
      child: ListTile(title: Text('Announcement ${index + 1}')),
    ),
  );

  Widget _profileContent() => Padding(
    padding: const EdgeInsets.all(20),
    child: Card(
      child: ListTile(
        title: const Text('Juan Dela Cruz'),
        subtitle: const Text('teacher@email.com'),
      ),
    ),
  );
}