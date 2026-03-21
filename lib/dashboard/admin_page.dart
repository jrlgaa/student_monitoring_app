import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project/database/admin_db.dart';

class AdminPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const AdminPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allArchivedItems = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _guardians = [];

  final List<String> menuTitles = ['Dashboard', 'Students', 'Teachers', 'Guardians', 'Archives'];
  final List<IconData> menuIcons = [
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.person_4_rounded,
    Icons.family_restroom_rounded,
    Icons.archive_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final activeData = await DatabaseHelper.instance.readActiveStudents();
    final archivedStudents = await DatabaseHelper.instance.readArchivedStudents();
    final teacherData = await DatabaseHelper.instance.readUsersByRole('Teacher');
    final guardianData = await DatabaseHelper.instance.readUsersByRole('Guardian');
    final archivedUsers = await DatabaseHelper.instance.readArchivedUsers();

    if (mounted) {
      setState(() {
        _students = activeData;
        _teachers = teacherData;
        _guardians = guardianData;
        _allArchivedItems = [...archivedStudents, ...archivedUsers];
      });
    }
  }

  List<dynamic> _getCurrentList() {
    if (selectedIndex == 1) return _students;
    if (selectedIndex == 2) return _teachers;
    if (selectedIndex == 3) return _guardians;
    if (selectedIndex == 4) return _allArchivedItems;
    return [];
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to sign out?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeletion(Map<String, dynamic> user, bool isStudent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Permanently?"),
        content: Text("Delete ${user['firstName']} ${user['lastName']}? This action is irreversible."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (isStudent) {
                await DatabaseHelper.instance.deleteStudent(user['id']);
              } else {
                await DatabaseHelper.instance.deleteUser(user['id']);
              }
              _refreshData();
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
              child: _buildSidebar(),
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

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 50),
          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue,
            child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 30),

          // Main Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: menuTitles.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return ListTile(
                  leading: Icon(menuIcons[index], color: selected ? Colors.blue : null),
                  title: Text(menuTitles[index], style: TextStyle(color: selected ? Colors.blue : null)),
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

          const Divider(),

          // --- DARK MODE TOGGLE (ABOVE LOGOUT) ---
          ListTile(
            leading: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              color: widget.isDarkMode ? Colors.amber : Colors.blueGrey,
            ),
            title: Text(widget.isDarkMode ? 'Light Mode' : 'Dark Mode'),
            trailing: Switch(
              value: widget.isDarkMode,
              activeColor: Colors.amber,
              onChanged: (val) => widget.toggleTheme(),
            ),
            onTap: widget.toggleTheme,
          ),

          // --- LOGOUT BUTTON (AT BOTTOM) ---
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: _handleLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSection() {
    switch (selectedIndex) {
      case 0: return _dashboardOverview();
      default: return _userListSection(menuTitles[selectedIndex]);
    }
  }

  Widget _dashboardOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(72, 22, 24, 20),
          child: Text('Dashboard Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _modernStatCard("Students", _students.length.toString(), Icons.school, Colors.blue),
              _modernStatCard("Teachers", _teachers.length.toString(), Icons.person_4, Colors.green),
              _modernStatCard("Guardians", _guardians.length.toString(), Icons.family_restroom, Colors.purple),
              _modernStatCard("Archived", _allArchivedItems.length.toString(), Icons.archive, Colors.orange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modernStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(count, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _userListSection(String title) {
    List<dynamic> currentList = _getCurrentList();
    bool isStudentTab = title == 'Students';
    bool isTeacherTab = title == 'Teachers';
    bool isGuardianTab = title == 'Guardians';
    bool isArchiveTab = title == 'Archives';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 22, 24, 20),
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search $title...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (isStudentTab) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showAddStudentModal(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: currentList.length,
            itemBuilder: (context, index) {
              final user = currentList[index];
              bool isStudentData = user.containsKey('lrn');
              String displayName = "${user['firstName']} ${user['lastName']}";

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isStudentData ? Colors.blue : Colors.green,
                    child: Text(displayName.isNotEmpty ? displayName[0] : "?"),
                  ),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStudentTab || isTeacherTab || isGuardianTab)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => isStudentTab ? _showEditStudentModal(user) : _showEditUserModal(user),
                        ),
                      if (isArchiveTab) ...[
                        IconButton(
                          icon: const Icon(Icons.unarchive, color: Colors.green),
                          onPressed: () async {
                            isStudentData ? await DatabaseHelper.instance.restoreStudent(user['id']) : await DatabaseHelper.instance.restoreUser(user['id']);
                            _refreshData();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                          onPressed: () => _confirmDeletion(user, isStudentData),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.archive, color: Colors.orange),
                          onPressed: () async {
                            isStudentData ? await DatabaseHelper.instance.archiveStudent(user['id']) : await DatabaseHelper.instance.archiveUser(user['id']);
                            _refreshData();
                          },
                        ),
                      ],
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

  void _showAddStudentModal() {
    final fName = TextEditingController();
    final lName = TextEditingController();
    final lrn = TextEditingController();
    String? selectedGrade;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Student"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name")),
              TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name")),
              TextField(controller: lrn, decoration: const InputDecoration(labelText: "LRN")),
              DropdownButtonFormField<String>(
                value: selectedGrade,
                items: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setDialogState(() => selectedGrade = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.createStudent({
                  'firstName': fName.text.trim(),
                  'lastName': lName.text.trim(),
                  'lrn': lrn.text.trim(),
                  'grade': selectedGrade!,
                  'status': 'Active',
                });
                _refreshData();
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentModal(Map<String, dynamic> student) {
    final fName = TextEditingController(text: student['firstName']);
    final lName = TextEditingController(text: student['lastName']);
    final lrn = TextEditingController(text: student['lrn']);
    String? selectedGrade = student['grade'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Student"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name")),
              TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name")),
              TextField(controller: lrn, decoration: const InputDecoration(labelText: "LRN")),
              DropdownButtonFormField<String>(
                value: selectedGrade,
                items: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setDialogState(() => selectedGrade = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await DatabaseHelper.instance.updateStudent(student['id'], {
                  'firstName': fName.text.trim(),
                  'lastName': lName.text.trim(),
                  'lrn': lrn.text.trim(),
                  'grade': selectedGrade!,
                });
                _refreshData();
                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserModal(Map<String, dynamic> user) {
    final fName = TextEditingController(text: user['firstName']);
    final lName = TextEditingController(text: user['lastName']);
    final email = TextEditingController(text: user['email']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${user['role']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name")),
            TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name")),
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await DatabaseHelper.instance.updateUser(user['id'], {
                'firstName': fName.text.trim(),
                'lastName': lName.text.trim(),
                'email': email.text.trim(),
              });
              _refreshData();
              Navigator.pop(context);
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}