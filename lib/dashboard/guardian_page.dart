import 'package:flutter/material.dart';

class GuardianPage extends StatefulWidget {
  const GuardianPage({super.key});



  @override
  State<GuardianPage> createState() => _GuardianPageState();
}

class _GuardianPageState extends State<GuardianPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  final List<String> menuTitles = [
    'Activity',
    'Activity Grades',
    'Student Grades',
    'Announcements',
    'Messages',
    'Attendance',
    'Profile',
  ];

  final List<IconData> menuIcons = [
    Icons.folder_outlined,
    Icons.bar_chart_rounded,
    Icons.groups_outlined,
    Icons.newspaper_rounded,
    Icons.email_outlined,
    Icons.calendar_month_outlined,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // FIX 1: Prevent the keyboard from causing overflow if it opens
      resizeToAvoidBottomInset: false,
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 80,
                    height: 50,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => setState(() => isSidebarOpen = !isSidebarOpen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Navigation Items
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero, // FIX 2: Remove default padding
                      itemCount: menuTitles.length,
                      itemBuilder: (context, index) {
                        final selected = index == selectedIndex;
                        return ListTile(
                          leading: SizedBox(
                            width: 32,
                            child: Icon(menuIcons[index],
                                color: selected ? Colors.blue : null),
                          ),
                          title: isSidebarOpen ? Text(menuTitles[index], maxLines: 1) : null,
                          selected: selected,
                          selectedTileColor: Colors.blue.withOpacity(0.1),
                          onTap: () => setState(() => selectedIndex = index),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  // Logout Button at bottom
                  ListTile(
                    leading: const SizedBox(
                      width: 32,
                      child: Icon(Icons.logout, color: Colors.redAccent),
                    ),
                    title: isSidebarOpen ? const Text('Logout') : null,
                    onTap: () => Navigator.pushReplacementNamed(context, '/login'),
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

  Widget _buildSection() {
    switch (selectedIndex) {
      case 0: return _activitySection();
      case 1: return _activityGradesSection();
      case 2: return _studentGradesSection();
      case 3: return _announcementsSection();
      case 5: return _attendanceSection();
      case 6: return _profileSection();
      default: return _genericSection(menuTitles[selectedIndex], const Center(child: Text("Content coming soon")));
    }
  }

  // Helper for Pinned Header Layout
  Widget _genericSection(String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible( // FIX 3: Prevent title text from overflowing horizontally
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selectedIndex == 0 && isSidebarOpen == false)
                const Text("Welcome!", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }

  // ================= 5. PROFILE (The most likely culprit for overflow) =================
  Widget _profileSection() {
    // FIX 4: Wrap profile content in a scroll view so it doesn't push against the bottom
    return _genericSection('My Profile', SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text("Information"),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Text("Guardian Name: Maria Dela Cruz"),
                  Text("Email: maria@email.com"),
                ],
              ),
              trailing: Icon(Icons.edit),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text("Add Student"),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          )
        ],
      ),
    ));
  }

  // Rest of your sections remain the same...
  Widget _activitySection() {
    return _genericSection('Teacher Activities', ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 3,
      itemBuilder: (context, index) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          title: Text("New Learning Material: Module ${index + 1}"),
          subtitle: const Text("Posted by Teacher Juan • 2 hours ago"),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    ));
  }

  Widget _studentGradesSection() {
    return _genericSection('Student Grade', SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Juan Dela Cruz (Grade 5)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: ['Q1', 'Q2', 'Q3', 'Q4'].map((q) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(label: Text(q), selected: q == 'Q1'),
                )).toList(),
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.5,
                children: [
                  _gradeTile("Filipino", "88"),
                  _gradeTile("English", "92"),
                  _gradeTile("Math", "85"),
                  _gradeTile("Science", "90"),
                ],
              )
            ],
          ),
        ),
      ),
    ));
  }

  Widget _gradeTile(String subject, String grade) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subject, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(grade, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _announcementsSection() {
    return _genericSection('Announcements', ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 2,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("School General Assembly", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            SizedBox(height: 8),
            Text("Please be informed that there will be a meeting this coming Friday...",
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ));
  }

  Widget _attendanceSection() {
    return _genericSection('Attendance Records', Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("Present", "20", Colors.green),
              _statItem("Absent", "2", Colors.red),
            ],
          ),
        ),
        const Expanded(child: Center(child: Text("Calendar View Placeholder"))),
      ],
    ));
  }

  Widget _statItem(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _activityGradesSection() => _genericSection('Activity Grades', const Center(child: Text('Chart/Grades List')));
}