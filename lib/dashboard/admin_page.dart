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

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  int selectedIndex = 0;
  bool isSidebarOpen = false;

  // Animation Controllers
  late AnimationController _dashboardController;
  late AnimationController _listController;

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

  final List<TextInputFormatter> _textOnlyFormatter = [
    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
  ];

  @override
  void initState() {
    super.initState();
    _dashboardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _refreshData();
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    _listController.dispose();
    super.dispose();
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
      _triggerSectionAnimation();
    }
  }

  void _triggerSectionAnimation() {
    if (selectedIndex == 0) {
      _dashboardController.forward(from: 0.0);
    } else {
      _listController.forward(from: 0.0);
    }
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
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getCurrentList() {
    if (selectedIndex == 1) return _students;
    if (selectedIndex == 2) return _teachers;
    if (selectedIndex == 3) return _guardians;
    if (selectedIndex == 4) return _allArchivedItems;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    // Key Fix: The Scaffold background must match the theme color
    // so there is no flicker when the sidebar slides.
    final bgColor = widget.isDarkMode ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBody: true, // Key Fix: Let body extend behind navigation bars
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // MAIN CONTENT AREA
          SafeArea(
            bottom: false,
            child: _buildSection(),
          ),

          // OVERLAY
          if (isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => isSidebarOpen = false),
                child: Container(color: Colors.black45),
              ),
            ),

          // SIDEBAR (Pins top 0 to bottom 0 of the actual screen)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: isSidebarOpen ? 0 : -280,
            top: 0,
            bottom: 0,
            width: 280,
            child: _buildSidebar(),
          ),

          // MENU BUTTON
          if (!isSidebarOpen)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => setState(() => isSidebarOpen = true),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      // CRITICAL FIX: The background decoration is here at the top level
      // of the sidebar, so it covers 100% height from top 0 to bottom 0.
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(5, 0))
        ],
      ),
      child: Column(
        children: [
          // Header inside its own SafeArea
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 40),
                const CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.admin_panel_settings, size: 45, color: Colors.white),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero, // Important: Removes default top/bottom gaps in lists
              itemCount: menuTitles.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Icon(menuIcons[index], color: selected ? Colors.blue : null),
                  title: Text(
                    menuTitles[index],
                    style: TextStyle(
                      color: selected ? Colors.blue : null,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      selectedIndex = index;
                      isSidebarOpen = false;
                    });
                    _triggerSectionAnimation();
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Settings and Logout (Do NOT wrap this in a SafeArea)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
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
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: _handleLogout,
          ),

          // Manual Padding for system navigation bars (the gap for the back button)
          // The background Container WILL stay under it.
          SizedBox(height: MediaQuery.of(context).padding.bottom + 15),
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

  // --- ANIMATED DASHBOARD OVERVIEW ---
  Widget _dashboardOverview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(72, 40, 24, 30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: widget.isDarkMode
                    ? [Colors.blueGrey.shade900, Colors.grey.shade900]
                    : [Colors.blue.shade700, Colors.blue.shade500],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome back, Admin!', style: TextStyle(color: Colors.white70, fontSize: 16)),
                SizedBox(height: 8),
                Text('Dashboard Overview', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1,
              children: [
                _animatedCard(0, "Active Students", _students.length.toString(), Icons.school_rounded, Colors.blue),
                _animatedCard(1, "Teachers", _teachers.length.toString(), Icons.person_4_rounded, Colors.green),
                _animatedCard(2, "Guardians", _guardians.length.toString(), Icons.family_restroom_rounded, Colors.purple),
                _animatedCard(3, "Archived Items", _allArchivedItems.length.toString(), Icons.archive_rounded, Colors.orange),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _animatedCard(int index, String title, String count, IconData icon, Color color) {
    final animation = CurvedAnimation(
      parent: _dashboardController,
      curve: Interval((0.1 * index).clamp(0, 1.0), (0.1 * index + 0.6).clamp(0, 1.0), curve: Curves.easeOutCirc),
    );
    return AnimatedBuilder(
      animation: _dashboardController,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(offset: Offset(0, 30 * (1 - animation.value)), child: child),
      ),
      child: _modernStatCard(title, count, icon, color),
    );
  }

  Widget _modernStatCard(String title, String count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Stack(
        children: [
          Positioned(right: -10, bottom: -10, child: Icon(icon, size: 70, color: color.withOpacity(0.05))),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(count, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text(title, style: TextStyle(color: widget.isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ANIMATED USER LIST ---
  Widget _userListSection(String title) {
    List<dynamic> currentList = _getCurrentList();
    bool isStudentTab = title == 'Students';

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
                    hintText: "Search $title...", prefixIcon: const Icon(Icons.search),
                    filled: true, fillColor: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (isStudentTab) ...[
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _showAddStudentModal(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
              return _animatedListItem(index, user);
            },
          ),
        ),
      ],
    );
  }

  Widget _animatedListItem(int index, dynamic user) {
    final animation = CurvedAnimation(
      parent: _listController,
      curve: Interval((0.05 * index).clamp(0, 1.0), (0.05 * index + 0.5).clamp(0, 1.0), curve: Curves.easeOut),
    );
    bool isStudentData = user.containsKey('lrn');
    String displayName = "${user['firstName']} ${user['lastName']}";

    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - animation.value)), child: child),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isStudentData ? Colors.blue : Colors.green,
            child: Text(displayName.isNotEmpty ? displayName[0] : "?", style: const TextStyle(color: Colors.white)),
          ),
          title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(isStudentData ? "LRN: ${user['lrn']} | ${user['grade']}" : "${user['role']} | ${user['email']}"),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedIndex != 4)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => isStudentData ? _showEditStudentModal(user) : _showEditUserModal(user),
                ),
              IconButton(
                icon: Icon(selectedIndex == 4 ? Icons.unarchive : Icons.archive, color: Colors.orange),
                onPressed: () async {
                  if (selectedIndex == 4) {
                    isStudentData ? await DatabaseHelper.instance.restoreStudent(user['id']) : await DatabaseHelper.instance.restoreUser(user['id']);
                  } else {
                    isStudentData ? await DatabaseHelper.instance.archiveStudent(user['id']) : await DatabaseHelper.instance.archiveUser(user['id']);
                  }
                  _refreshData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODALS (Unchanged for logic, but kept for full code) ---
  void _showAddStudentModal() {
    final fName = TextEditingController(); final mName = TextEditingController(); final lName = TextEditingController(); final lrn = TextEditingController();
    String? selectedGrade;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add New Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name"), inputFormatters: _textOnlyFormatter),
                TextField(controller: mName, decoration: const InputDecoration(labelText: "Middle Name"), inputFormatters: _textOnlyFormatter),
                TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name"), inputFormatters: _textOnlyFormatter),
                TextField(controller: lrn, decoration: const InputDecoration(labelText: "LRN (12 digits)"), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
                DropdownButtonFormField<String>(
                  value: selectedGrade,
                  items: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setDialogState(() => selectedGrade = val),
                  decoration: const InputDecoration(labelText: "Grade Level"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (fName.text.isNotEmpty && lName.text.isNotEmpty && lrn.text.length == 12 && selectedGrade != null) {
                  await DatabaseHelper.instance.createStudent({'firstName': fName.text.trim(), 'middleName': mName.text.trim(), 'lastName': lName.text.trim(), 'lrn': int.parse(lrn.text.trim()), 'grade': selectedGrade!, 'status': 'Active'});
                  _refreshData(); Navigator.pop(context);
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentModal(Map<String, dynamic> student) {
    final fName = TextEditingController(text: student['firstName']); final lName = TextEditingController(text: student['lastName']); final lrn = TextEditingController(text: student['lrn']?.toString());
    String? selectedGrade = student['grade'];
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Student"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name"), inputFormatters: _textOnlyFormatter),
                TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name"), inputFormatters: _textOnlyFormatter),
                TextField(controller: lrn, decoration: const InputDecoration(labelText: "LRN"), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: selectedGrade,
                  items: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setDialogState(() => selectedGrade = val),
                  decoration: const InputDecoration(labelText: "Grade Level"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(onPressed: () async {
              await DatabaseHelper.instance.updateStudent(student['id'], {'firstName': fName.text.trim(), 'lastName': lName.text.trim(), 'lrn': int.parse(lrn.text.trim()), 'grade': selectedGrade!});
              _refreshData(); Navigator.pop(context);
            }, child: const Text("Update")),
          ],
        ),
      ),
    );
  }

  void _showEditUserModal(Map<String, dynamic> user) {
    final fName = TextEditingController(text: user['firstName']); final lName = TextEditingController(text: user['lastName']); final email = TextEditingController(text: user['email']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Edit ${user['role']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: fName, decoration: const InputDecoration(labelText: "First Name"), inputFormatters: _textOnlyFormatter),
            TextField(controller: lName, decoration: const InputDecoration(labelText: "Last Name"), inputFormatters: _textOnlyFormatter),
            TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            await DatabaseHelper.instance.updateUser(user['id'], {'firstName': fName.text.trim(), 'lastName': lName.text.trim(), 'email': email.text.trim()});
            _refreshData(); Navigator.pop(context);
          }, child: const Text("Update")),
        ],
      ),
    );
  }
}