import 'package:flutter/material.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  int selectedIndex = 0;

  final List<String> menuTitles = [
    'Activities',
    'Students',
    'Announcements',
    'Messages',
    'Attendance',
    'Profile',
  ];

  final List<String> menuIcons = [
    '📂',
    '👨‍🎓',
    '📰',
    '✉️',
    '📅',
    '👤',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // ================= SIDEBAR =================
          Container(
            width: 240,
            color: isDark ? Colors.grey[850] : Colors.grey[200],
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  'Teacher',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                ...List.generate(menuTitles.length, (index) {
                  final selected = index == selectedIndex;
                  return ListTile(
                    leading: Text(menuIcons[index]),
                    title: Text(menuTitles[index]),
                    selected: selected,
                    selectedTileColor: Colors.blue.withOpacity(0.2),
                    onTap: () {
                      setState(() => selectedIndex = index);
                    },
                  );
                }),
              ],
            ),
          ),

          // ================= MAIN CONTENT =================
          Expanded(
            child: Column(
              children: [
                // ================= HEADER =================
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Welcome, Teacher!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                ),

                // ================= SECTIONS =================
                Expanded(child: _buildSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= SECTION SWITCHER =================
  Widget _buildSection() {
    switch (selectedIndex) {
      case 0:
        return _activitiesSection();
      case 1:
        return _studentsSection();
      case 2:
        return _announcementsSection();
      case 3:
        return _messagesSection();
      case 4:
        return _attendanceSection();
      case 5:
        return _profileSection();
      default:
        return const SizedBox();
    }
  }

  // ================= ACTIVITIES =================
  Widget _activitiesSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teacher Activities',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  title: Text('Activity ${index + 1}'),
                  subtitle: const Text('Activity description'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= STUDENTS =================
  Widget _studentsSection() {
    return const Center(
      child: Text(
        'Student Grades',
        style: TextStyle(fontSize: 20),
      ),
    );
  }

  // ================= ANNOUNCEMENTS =================
  Widget _announcementsSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Announcements',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: 3,
              itemBuilder: (context, index) => Card(
                child: ListTile(
                  title: Text('Announcement ${index + 1}'),
                  subtitle: const Text('Announcement details'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= MESSAGES =================
  Widget _messagesSection() {
    return const Center(
      child: Text(
        'Messages',
        style: TextStyle(fontSize: 20),
      ),
    );
  }

  // ================= ATTENDANCE =================
  Widget _attendanceSection() {
    return const Center(
      child: Text(
        'Attendance Records',
        style: TextStyle(fontSize: 20),
      ),
    );
  }

  // ================= PROFILE =================
  Widget _profileSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Teacher Profile',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('Name: Juan Dela Cruz'),
              Text('Email: teacher@email.com'),
            ],
          ),
        ),
      ),
    );
  }
}