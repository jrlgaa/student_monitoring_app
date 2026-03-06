import 'package:flutter/material.dart';

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

  final List<String> menuTitles = [
    'Dashboard Overview',
    'Students',
    'Teachers',
    'Guardians',
  ];

  final List<IconData> menuIcons = [
    Icons.dashboard_rounded,
    Icons.school_rounded,
    Icons.person_4_rounded,
    Icons.family_restroom_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Row(
          children: [
            // ================= SIDEBAR =================
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSidebarOpen ? 240 : 80,
              color: widget.isDarkMode ? Colors.grey[850] : Colors.grey[200],
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
                  Expanded(
                    child: ListView.builder(
                      itemCount: menuTitles.length,
                      itemBuilder: (context, index) {
                        final selected = index == selectedIndex;
                        return ListTile(
                          leading: SizedBox(
                            width: 32,
                            child: Icon(menuIcons[index], color: selected ? Colors.blue : null),
                          ),
                          title: isSidebarOpen ? Text(menuTitles[index], maxLines: 1) : null,
                          selected: selected,
                          selectedTileColor: Colors.blue.withOpacity(0.1),
                          onTap: () => setState(() => selectedIndex = index),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
                    onPressed: widget.toggleTheme,
                  ),
                  const Divider(),
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
                color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
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
      case 0: return _dashboardOverview();
      case 1: return _userListSection("Student List", ["Name", "LRN", "Grade", "Status"]);
      case 2: return _userListSection("Teacher List", ["Name", "ID", "Email", "Status"]);
      case 3: return _userListSection("Guardian List", ["Name", "Email", "Role", "Status"]);
      default: return Container();
    }
  }

  // ================= 1. DASHBOARD OVERVIEW =================
  Widget _dashboardOverview() {
    return _pageFrame('Dashboard Overview', SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _statCard("Students", "Active: 45", "Inactive: 2", Colors.green),
              _statCard("Teachers", "Active: 12", "Inactive: 1", Colors.blue),
              _statCard("Guardians", "Active: 40", "Inactive: 0", Colors.teal),
              _statCard("Total Users", "99", "System Accounts", Colors.purple),
            ],
          ),
          const SizedBox(height: 24),
          // Placeholder for Chart
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text("System User Types Chart Placeholder")),
          ),
        ],
      ),
    ));
  }

  Widget _statCard(String title, String main, String sub, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(main, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  // ================= 2. USER LISTS (Reusable Table) =================
  Widget _userListSection(String title, List<String> headers) {
    return _pageFrame(title, Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text("Add New"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: headers.map((h) => DataColumn(label: Text(h))).toList()
                  ..add(const DataColumn(label: Text("Actions"))),
                rows: List.generate(10, (index) => DataRow(cells: [
                  ...headers.map((_) => const DataCell(Text("Sample Data"))),
                  DataCell(Row(
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.blue), onPressed: () {}),
                      IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () {}),
                    ],
                  )),
                ])),
              ),
            ),
          ),
        ),
      ],
    ));
  }

  // Reusable Frame for Layout Consistency
  Widget _pageFrame(String title, Widget content) {
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
}