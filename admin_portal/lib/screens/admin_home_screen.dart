import 'package:flutter/material.dart';
import '../widgets/watermark_scaffold.dart';
import 'students/students_main_screen.dart';
import 'subjects/subjects_main_screen.dart';
import 'faculties/faculties_main_screen.dart';
import 'branches/branches_main_screen.dart';
import 'sections/sections_management_screen.dart';
import 'publish/publish_main_screen.dart';
// At top of admin_home_screen.dart:
import 'promotion/promotion_detention_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedNavIndex = 0;

  // College Brand Palette
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color darkNavy = Color(0xFF07193D);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color textMuted = Color(0xFF6B7280);

  // Management Sections Data
  final List<Map<String, dynamic>> _sections = [
    {
      'title': 'Students',
      'count': '1,420 Enrolled',
      'icon': Icons.school_outlined,
      'color': const Color(0xFF1E88E5),
      'description': 'Manage enrollments, profiles, and attendance records.',
    },
    {
      'title': 'Subjects',
      'count': 'Curriculum & Labs',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFF00897B),
      'description':
          'Course codes, semester schemes, credit allotments, and syllabi.',
    },
    {
      'title': 'Faculties',
      'count': '94 Members',
      'icon': Icons.groups_outlined,
      'color': const Color(0xFF43A047),
      'description': 'Staff directory, subject allocations, and departments.',
    },
    {
      'title': 'Branches',
      'count': '6 Disciplines',
      'icon': Icons.account_tree_outlined,
      'color': const Color(0xFF8E24AA),
      'description': 'CSE, ECE, EEE, MECH, CIVIL, and AI & DS curricula.',
    },
    {
      'title': 'Classes & Sections',
      'count': 'Manage Sections',
      'icon': Icons.meeting_room_outlined,
      'color': const Color(0xFFE65100),
      'description':
          'Configure class sections (A, B, C) per branch and semester.',
    },
    {
      'title': 'Publish Marks',
      'count': 'Mid-Term & Sem',
      'icon': Icons.fact_check_outlined,
      'color': const Color(0xFFE53935),
      'description':
          'Upload internal scores, grade sheets, and result declarations.',
    },
    {
      'title': 'Promote / Detain',
      'count': 'Academic Progression',
      'icon': Icons.trending_up_outlined,
      'color': const Color(0xFF2E7D32),
      'description':
          'Evaluate assessment results, filter by passing %, and promote or detain students.',
    },
    {
      'title': 'Settings',
      'count': 'System Config',
      'icon': Icons.settings_outlined,
      'color': const Color(0xFF546E7A),
      'description':
          'Academic calendar, role permissions, and portal controls.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth > 800;

        return WatermarkScaffold(
          scaleFactor: 0.75,
          watermarkOpacity: 0.05,
          appBar: isDesktop ? null : _buildMobileAppBar(),
          body: Row(
            children: [
              // Persistent Sidebar on Desktop / Tablet Landscape
              if (isDesktop) _buildSidebar(),

              // Main Responsive Body Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTopGreeting(isDesktop),
                          const SizedBox(height: 24),
                          _buildSectionGrid(constraints.maxWidth),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Mobile Top Header Bar
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: primaryNavy),
      title: const Text(
        'MTIET Admin',
        style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // Desktop Side Navigation Bar
  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        border: Border(
          right: BorderSide(color: Colors.black.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Row(
              children: [
                Image.asset('assets/mitet_logo.png', width: 42, height: 42),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'MTIET Portal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                _buildNavItem(1, 'Students', Icons.school_outlined),
                _buildNavItem(2, 'Subjects', Icons.menu_book_outlined),
                _buildNavItem(3, 'Faculties', Icons.groups_outlined),
                _buildNavItem(4, 'Branches', Icons.account_tree_outlined),
                _buildNavItem(5, 'Publish Marks', Icons.fact_check_outlined),
                _buildNavItem(
                  6,
                  'Promote / Detain',
                  Icons.trending_up_outlined,
                ), // Added here
                _buildNavItem(7, 'Settings', Icons.settings_outlined),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: accentRed),
            title: const Text('Sign Out', style: TextStyle(color: accentRed)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    final bool isSelected = _selectedNavIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryNavy.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? primaryNavy : textMuted),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? primaryNavy : textMuted,
          ),
        ),
        onTap: () {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentsMainScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubjectsMainScreen(),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FacultiesMainScreen(),
              ),
            );
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BranchesMainScreen(),
              ),
            );
          } else if (index == 6) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>  PromotionDetentionScreen(),
              ),
            );
          } else {
            setState(() => _selectedNavIndex = index);
          }
        },
      ),
    );
  }

  // Top Welcome Banner
  Widget _buildTopGreeting(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [darkNavy, primaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryNavy.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome, Administrator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Academic Year 2025–2026 | Mother Theresa Institute of Engineering and Technology',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          if (isDesktop)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: accentGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accentGold),
              ),
              child: const Text(
                'GROW RICH',
                style: TextStyle(
                  color: accentGold,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Dynamic Multi-Column Grid
  Widget _buildSectionGrid(double screenWidth) {
    // Determine column count based on available screen width
    int crossAxisCount = 1;
    if (screenWidth > 1100) {
      crossAxisCount = 3;
    } else if (screenWidth > 680) {
      crossAxisCount = 2;
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        mainAxisExtent: 170, // Fixed height for visual uniformity
      ),
      itemCount: _sections.length,
      itemBuilder: (context, index) {
        final item = _sections[index];
        return _buildCard(item);
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final Color itemColor = item['color'] as Color;

    return Card(
      elevation: 4,
      shadowColor: primaryNavy.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (item['title'] == 'Students') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentsMainScreen(),
              ),
            );
          } else if (item['title'] == 'Subjects') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SubjectsMainScreen(),
              ),
            );
          } else if (item['title'] == 'Faculties') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FacultiesMainScreen(),
              ),
            );
          } else if (item['title'] == 'Branches') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BranchesMainScreen(),
              ),
            );
          } else if (item['title'] == 'Classes & Sections') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SectionsManagementScreen(),
              ),
            );
          } else if (item['title'] == 'Publish Marks') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PublishMarksMainScreen(),
              ),
            );
          } else if (item['title'] == 'Promote / Detain') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PromotionDetentionScreen(),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: itemColor,
                      size: 26,
                    ),
                  ),
                  Text(
                    item['count'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: itemColor,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item['description'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
