import 'package:flutter/material.dart';

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

  final List<String> menuTitles = [
    'Activities',
    'tudent Grades',
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
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: Prevents layout overflow when the keyboard opens for uploading
      resizeToAvoidBottomInset: false,

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
                      "Maria Santos",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Text(
                      "Guardian ID: G2024-001",
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

  Widget _buildSection() {
    switch (selectedIndex) {
      case 0:
        return _activitySection();
      case 1:
        return _studentGradesSection();
      case 2:
        return _announcementsSection();
      case 3:
        return _attendanceSection();
      case 4:
        return _genericSection('Profile', _profileContent());
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

  Widget _profileContent() => Padding(
    padding: const EdgeInsets.all(20),
    child: Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: const Text('Maria Santos'),
        subtitle: const Text('guardian@school.com'),
      ),
    ),
  );



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