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
  String _searchQuery = '';

  late AnimationController _dashboardController;
  late AnimationController _listController;
  late AnimationController _sidebarController;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _allArchivedItems = [];
  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _guardians = [];

  final List<String> menuTitles = [
    'Dashboard',
    'Students',
    'Teachers',
    'Guardians',
    'Archives',
  ];

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

  // Design tokens
  static const Color _primaryBlue = Color(0xFF2563EB);
  static const Color _accentIndigo = Color(0xFF4F46E5);
  static const Color _successGreen = Color(0xFF059669);
  static const Color _warningAmber = Color(0xFFD97706);
  static const Color _dangerRed = Color(0xFFDC2626);
  static const Color _purple = Color(0xFF7C3AED);

  Color get _surfaceColor => widget.isDarkMode
      ? const Color(0xFF1E1E2E)
      : const Color(0xFFF8FAFC);
  Color get _cardColor => widget.isDarkMode
      ? const Color(0xFF2A2A3E)
      : Colors.white;
  Color get _sidebarColor => widget.isDarkMode
      ? const Color(0xFF16162A)
      : const Color(0xFF1E293B);
  Color get _textPrimary =>
      widget.isDarkMode ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _textSecondary =>
      widget.isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _dividerColor => widget.isDarkMode
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _dashboardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _sidebarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _refreshData();
  }

  @override
  void dispose() {
    _dashboardController.dispose();
    _listController.dispose();
    _sidebarController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final activeData = await DatabaseHelper.instance.readActiveStudents();
    final archivedStudents =
    await DatabaseHelper.instance.readArchivedStudents();
    final teacherData =
    await DatabaseHelper.instance.readUsersByRole('Teacher');
    final guardianData =
    await DatabaseHelper.instance.readUsersByRole('Guardian');
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

  void _openSidebar() {
    setState(() => isSidebarOpen = true);
    _sidebarController.forward();
  }

  void _closeSidebar() {
    _sidebarController.reverse().then((_) {
      setState(() => isSidebarOpen = false);
    });
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        title: 'Sign Out',
        icon: Icons.logout_rounded,
        iconColor: _dangerRed,
        content: 'Are you sure you want to sign out of the admin panel?',
        actions: [
          _dialogButton(
            label: 'Cancel',
            onTap: () => Navigator.pop(context),
            outlined: true,
          ),
          _dialogButton(
            label: 'Sign Out',
            onTap: () => Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false),
            color: _dangerRed,
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item, bool isStudent) {
    showDialog(
      context: context,
      builder: (context) => _styledDialog(
        title: 'Permanent Delete',
        icon: Icons.delete_forever_rounded,
        iconColor: _dangerRed,
        content:
        'Permanently delete ${item['firstName']} ${item['lastName']}? This cannot be undone.',
        actions: [
          _dialogButton(
            label: 'Cancel',
            onTap: () => Navigator.pop(context),
            outlined: true,
          ),
          _dialogButton(
            label: 'Delete',
            onTap: () async {
              if (isStudent) {
                await DatabaseHelper.instance.deleteStudent(item['id']);
              } else {
                await DatabaseHelper.instance.deleteUser(item['id']);
              }
              Navigator.pop(context);
              _refreshData();
              _showSnackbar('Record permanently deleted', isError: true);
            },
            color: _dangerRed,
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(message,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.white)),
          ],
        ),
        backgroundColor: isError ? _dangerRed : _successGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  List<dynamic> _getCurrentList() {
    List<dynamic> list = [];
    if (selectedIndex == 1) list = _students;
    if (selectedIndex == 2) list = _teachers;
    if (selectedIndex == 3) list = _guardians;
    if (selectedIndex == 4) list = _allArchivedItems;

    if (_searchQuery.isEmpty) return list;
    return list.where((item) {
      final name =
      '${item['firstName']} ${item['lastName']}'.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceColor,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _buildSection(),
          ),

          // Overlay when sidebar is open
          if (isSidebarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: AnimatedBuilder(
                  animation: _sidebarController,
                  builder: (context, _) => Container(
                    color: Colors.black
                        .withOpacity(0.5 * _sidebarController.value),
                  ),
                ),
              ),
            ),

          // Sidebar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            left: isSidebarOpen ? 0 : -300,
            top: 0,
            bottom: 0,
            width: 280,
            child: _buildSidebar(),
          ),

          // Hamburger button
          if (!isSidebarOpen)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _hamburgerButton(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hamburgerButton() {
    return Material(
      color: _cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openSidebar,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _dividerColor, width: 1.5),
          ),
          child: Icon(Icons.menu_rounded, color: _textPrimary, size: 20),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      decoration: BoxDecoration(
        color: _sidebarColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(8, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primaryBlue, _accentIndigo],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AdminPanel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Administrator',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'MENU',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: menuTitles.length,
              itemBuilder: (context, index) {
                final selected = index == selectedIndex;
                return _sidebarItem(index, selected);
              },
            ),
          ),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Divider(
              color: Colors.white.withOpacity(0.08),
              height: 1,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  _sidebarAction(
                    icon: widget.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    label: widget.isDarkMode ? 'Light Mode' : 'Dark Mode',
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: widget.isDarkMode,
                        activeColor: const Color(0xFFF59E0B),
                        onChanged: (_) => widget.toggleTheme(),
                      ),
                    ),
                    onTap: widget.toggleTheme,
                    iconColor: widget.isDarkMode
                        ? const Color(0xFFF59E0B)
                        : Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(height: 4),
                  _sidebarAction(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    onTap: _handleLogout,
                    iconColor: _dangerRed,
                    textColor: _dangerRed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? _primaryBlue.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              selectedIndex = index;
              _searchQuery = '';
            });
            _closeSidebar();
            _triggerSectionAnimation();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? _primaryBlue.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    menuIcons[index],
                    color: selected
                        ? const Color(0xFF60A5FA)
                        : Colors.white.withOpacity(0.5),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  menuTitles[index],
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF60A5FA)
                        : Colors.white.withOpacity(0.65),
                    fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF60A5FA),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
    Color? iconColor,
    Color? textColor,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon,
                  color: iconColor ?? Colors.white.withOpacity(0.6), size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.white.withOpacity(0.65),
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection() {
    switch (selectedIndex) {
      case 0:
        return _dashboardOverview();
      default:
        return _userListSection(menuTitles[selectedIndex]);
    }
  }

  // ─────────────────────── DASHBOARD ───────────────────────

  Widget _dashboardOverview() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardHeader(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: [
                _animatedCard(0, 'Students', _students.length.toString(),
                    Icons.school_rounded, _primaryBlue),
                _animatedCard(1, 'Teachers', _teachers.length.toString(),
                    Icons.person_4_rounded, _successGreen),
                _animatedCard(2, 'Guardians', _guardians.length.toString(),
                    Icons.family_restroom_rounded, _purple),
                _animatedCard(3, 'Archived', _allArchivedItems.length.toString(),
                    Icons.archive_rounded, _warningAmber),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _quickActionsCard(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF1E3A5F), const Color(0xFF1E1E2E)]
              : [const Color(0xFF1D4ED8), const Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF34D399),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'System Online',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome back,',
            style: TextStyle(
              color: Colors.white.withOpacity(0.65),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Administrator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Access',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _quickAccessButton(
                'Students',
                Icons.school_rounded,
                _primaryBlue,
                    () {
                  setState(() => selectedIndex = 1);
                  _triggerSectionAnimation();
                },
              ),
              const SizedBox(width: 10),
              _quickAccessButton(
                'Teachers',
                Icons.person_4_rounded,
                _successGreen,
                    () {
                  setState(() => selectedIndex = 2);
                  _triggerSectionAnimation();
                },
              ),
              const SizedBox(width: 10),
              _quickAccessButton(
                'Guardians',
                Icons.family_restroom_rounded,
                _purple,
                    () {
                  setState(() => selectedIndex = 3);
                  _triggerSectionAnimation();
                },
              ),
              const SizedBox(width: 10),
              _quickAccessButton(
                'Archives',
                Icons.archive_rounded,
                _warningAmber,
                    () {
                  setState(() => selectedIndex = 4);
                  _triggerSectionAnimation();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickAccessButton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedCard(
      int index, String title, String count, IconData icon, Color color) {
    final animation = CurvedAnimation(
      parent: _dashboardController,
      curve: Interval(
        (0.1 * index).clamp(0, 1.0),
        (0.1 * index + 0.6).clamp(0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: _dashboardController,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: _statCard(title, count, icon, color),
    );
  }

  Widget _statCard(
      String title, String count, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    color: color.withOpacity(0.7),
                    size: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              count,
              style: TextStyle(
                color: _textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── LIST SECTION ───────────────────────

  Widget _userListSection(String title) {
    final currentList = _getCurrentList();
    final isStudentTab = title == 'Students';
    final isArchiveTab = selectedIndex == 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 58, 24, 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '${currentList.length} record${currentList.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: _textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (isStudentTab)
                _addButton(() => _showAddStudentModal()),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _searchBar(title),
        ),
        const SizedBox(height: 16),

        // List
        Expanded(
          child: currentList.isEmpty
              ? _emptyState(title, isArchiveTab)
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: currentList.length,
            itemBuilder: (context, index) {
              return _animatedListItem(index, currentList[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar(String section) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _dividerColor, width: 1),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: _textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search $section...',
          hintStyle: TextStyle(color: _textSecondary, fontSize: 14),
          prefixIcon:
          Icon(Icons.search_rounded, color: _textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _addButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryBlue, _accentIndigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primaryBlue.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'Add',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String section, bool isArchive) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _dividerColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isArchive ? Icons.archive_outlined : Icons.person_off_outlined,
              color: _textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArchive ? 'No archived records' : 'No $section found',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Records will appear here',
            style: TextStyle(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _animatedListItem(int index, dynamic user) {
    final animation = CurvedAnimation(
      parent: _listController,
      curve: Interval(
        (0.05 * index).clamp(0, 1.0),
        (0.05 * index + 0.5).clamp(0, 1.0),
        curve: Curves.easeOut,
      ),
    );

    final bool isStudentData = user.containsKey('lrn');
    final String displayName =
        '${user['firstName']} ${user['lastName']}';
    final String initial =
    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    final Color avatarColor = isStudentData ? _primaryBlue : _successGreen;

    return AnimatedBuilder(
      animation: _listController,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
            offset: Offset(0, 16 * (1 - animation.value)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _dividerColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: avatarColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 13),

                // Name + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isStudentData
                            ? 'LRN: ${user['lrn']}  ·  ${user['grade']}'
                            : '${user['role']}  ·  ${user['email']}',
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedIndex != 4)
                      _iconAction(
                        icon: Icons.edit_rounded,
                        color: _primaryBlue,
                        bgColor: _primaryBlue.withOpacity(0.08),
                        onTap: () => isStudentData
                            ? _showEditStudentModal(user)
                            : _showEditUserModal(user),
                      ),
                    if (selectedIndex == 4) ...[
                      _iconAction(
                        icon: Icons.unarchive_rounded,
                        color: _successGreen,
                        bgColor: _successGreen.withOpacity(0.08),
                        onTap: () async {
                          isStudentData
                              ? await DatabaseHelper.instance
                              .restoreStudent(user['id'])
                              : await DatabaseHelper.instance
                              .restoreUser(user['id']);
                          _refreshData();
                          _showSnackbar('Record restored');
                        },
                      ),
                      const SizedBox(width: 6),
                      _iconAction(
                        icon: Icons.delete_forever_rounded,
                        color: _dangerRed,
                        bgColor: _dangerRed.withOpacity(0.08),
                        onTap: () =>
                            _showDeleteConfirmation(user, isStudentData),
                      ),
                    ],
                    if (selectedIndex != 4) ...[
                      const SizedBox(width: 6),
                      _iconAction(
                        icon: Icons.archive_rounded,
                        color: _warningAmber,
                        bgColor: _warningAmber.withOpacity(0.08),
                        onTap: () async {
                          isStudentData
                              ? await DatabaseHelper.instance
                              .archiveStudent(user['id'])
                              : await DatabaseHelper.instance
                              .archiveUser(user['id']);
                          _refreshData();
                          _showSnackbar('Record archived');
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  // ─────────────────────── DIALOGS ───────────────────────

  Widget _styledDialog({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String content,
    required List<Widget> actions,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: _cardColor,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              content,
              style: TextStyle(color: _textSecondary, fontSize: 14, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: actions
                  .map((a) => Expanded(child: a))
                  .toList()
                  .expand((w) => [w, const SizedBox(width: 10)])
                  .toList()
                ..removeLast(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogButton({
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : (color ?? _primaryBlue),
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: _dividerColor, width: 1.5) : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: outlined ? _textPrimary : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _textSecondary, fontSize: 13),
      filled: true,
      fillColor: _surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
      ),
    );
  }

  Widget _formDialog({
    required String title,
    required List<Widget> fields,
    required String saveLabel,
    required VoidCallback onSave,
  }) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: _cardColor,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _dividerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        color: _textSecondary, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...fields
                .expand((f) => [f, const SizedBox(height: 12)])
                .toList()
              ..removeLast(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _dialogButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                    outlined: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _dialogButton(
                    label: saveLabel,
                    onTap: onSave,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── MODALS ───────────────────────

  void _showAddStudentModal() {
    final fName = TextEditingController();
    final mName = TextEditingController();
    final lName = TextEditingController();
    final lrn = TextEditingController();
    String? selectedGrade;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _formDialog(
          title: 'Add New Student',
          saveLabel: 'Save',
          onSave: () async {
            if (fName.text.isNotEmpty &&
                lName.text.isNotEmpty &&
                lrn.text.length == 12 &&
                selectedGrade != null) {
              await DatabaseHelper.instance.createStudent({
                'firstName': fName.text.trim(),
                'middleName': mName.text.trim(),
                'lastName': lName.text.trim(),
                'lrn': int.parse(lrn.text.trim()),
                'grade': selectedGrade!,
                'status': 'Active',
              });
              _refreshData();
              Navigator.pop(context);
              _showSnackbar('Student added successfully');
            }
          },
          fields: [
            TextField(
              controller: fName,
              decoration: _inputDecoration('First Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
            ),
            TextField(
              controller: mName,
              decoration: _inputDecoration('Middle Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
            ),
            TextField(
              controller: lName,
              decoration: _inputDecoration('Last Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
            ),
            TextField(
              controller: lrn,
              decoration: _inputDecoration('LRN (12 digits)'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              style: TextStyle(color: _textPrimary),
            ),
            DropdownButtonFormField<String>(
              value: selectedGrade,
              dropdownColor: _cardColor,
              style: TextStyle(color: _textPrimary, fontSize: 14),
              items: [
                'Grade 1',
                'Grade 2',
                'Grade 3',
                'Grade 4',
                'Grade 5',
                'Grade 6',
              ]
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) =>
                  setDialogState(() => selectedGrade = val),
              decoration: _inputDecoration('Grade Level'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentModal(Map<String, dynamic> student) {
    final fName = TextEditingController(text: student['firstName']);
    final lName = TextEditingController(text: student['lastName']);
    final lrn =
    TextEditingController(text: student['lrn']?.toString());
    String? selectedGrade = student['grade'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _formDialog(
          title: 'Edit Student',
          saveLabel: 'Update',
          onSave: () async {
            await DatabaseHelper.instance.updateStudent(student['id'], {
              'firstName': fName.text.trim(),
              'lastName': lName.text.trim(),
              'lrn': int.parse(lrn.text.trim()),
              'grade': selectedGrade!,
            });
            _refreshData();
            Navigator.pop(context);
            _showSnackbar('Student updated');
          },
          fields: [
            TextField(
              controller: fName,
              decoration: _inputDecoration('First Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
            ),
            TextField(
              controller: lName,
              decoration: _inputDecoration('Last Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
            ),
            TextField(
              controller: lrn,
              decoration: _inputDecoration('LRN'),
              keyboardType: TextInputType.number,
              style: TextStyle(color: _textPrimary),
            ),
            DropdownButtonFormField<String>(
              value: selectedGrade,
              dropdownColor: _cardColor,
              style: TextStyle(color: _textPrimary, fontSize: 14),
              items: [
                'Grade 1',
                'Grade 2',
                'Grade 3',
                'Grade 4',
                'Grade 5',
                'Grade 6',
              ]
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) =>
                  setDialogState(() => selectedGrade = val),
              decoration: _inputDecoration('Grade Level'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserModal(Map<String, dynamic> user) {
    final fName = TextEditingController(text: user['firstName']);
    final lName = TextEditingController(text: user['lastName']);

    final bool isTeacher = user['role'] == 'Teacher';
    final bool isGuardian = user['role'] == 'Guardian';
    final String existingEmail = user['email'] ?? '';

    // Extract local part for teacher (@deped.gov.ph) or guardian (@gmail.com)
    final String existingLocal = isTeacher && existingEmail.endsWith('@deped.gov.ph')
        ? existingEmail.replaceAll('@deped.gov.ph', '')
        : isGuardian && existingEmail.endsWith('@gmail.com')
        ? existingEmail.replaceAll('@gmail.com', '')
        : existingEmail;
    final emailLocal = TextEditingController(text: existingLocal);
    final email = TextEditingController(text: existingEmail);

    showDialog(
        context: context,
        builder: (context) => _formDialog(
            title: 'Edit ${user['role']}',
            saveLabel: 'Update',
            onSave: () async {
              final local = emailLocal.text.trim();
              if ((isTeacher || isGuardian) && local.isEmpty) {
                _showSnackbar('Email username cannot be empty', isError: true);
                return;
              }

              final String finalEmail = isTeacher
                  ? '${local}@deped.gov.ph'
                  : isGuardian
                  ? '${local}@gmail.com'
                  : email.text.trim();

              await DatabaseHelper.instance.updateUser(user['id'], {
                'firstName': fName.text.trim(),
                'lastName': lName.text.trim(),
                'email': finalEmail,
              });
              _refreshData();
              Navigator.pop(context);
              _showSnackbar('${user['role']} updated');
              },
              fields: [
              TextField(
              controller: fName,
              decoration: _inputDecoration('First Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
              ),
              TextField(
              controller: lName,
              decoration: _inputDecoration('Last Name'),
              inputFormatters: _textOnlyFormatter,
              style: TextStyle(color: _textPrimary),
              ),
              if (isTeacher)
              TextField(
              controller: emailLocal,
              decoration: _inputDecoration('Email').copyWith(
              suffixText: '@deped.gov.ph',
              suffixStyle: TextStyle(
              color: _primaryBlue,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              ),
              hintText: 'username',
              ),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[@\s]')),
              ],
              style: TextStyle(color: _textPrimary),
              )
              else if (isGuardian)
              TextField(
              controller: emailLocal,
              decoration: _inputDecoration('Email').copyWith(
              suffixText: '@gmail.com',
              suffixStyle: TextStyle(
              color: _successGreen,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              ),
              hintText: 'username',
              ),
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[@\s]')),
              ],
              style: TextStyle(color: _textPrimary),
              )
              else
              TextField(
              controller: email,
              decoration: _inputDecoration('Email'),
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: _textPrimary),
              ),
              ],
              ),
              );
            }
            }