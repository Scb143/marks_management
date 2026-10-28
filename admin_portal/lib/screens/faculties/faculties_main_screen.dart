import 'package:flutter/material.dart';
import '../../widgets/watermark_scaffold.dart';
import 'faculty_list_view.dart';
import 'add_faculty_view.dart';

class FacultiesMainScreen extends StatefulWidget {
  const FacultiesMainScreen({super.key});

  @override
  State<FacultiesMainScreen> createState() => _FacultiesMainScreenState();
}

class _FacultiesMainScreenState extends State<FacultiesMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color primaryNavy = Color(0xFF0B2356);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
        title: const Text(
          'Faculty & Staff Management',
          style: TextStyle(
            color: primaryNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryNavy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryNavy,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined), text: 'Faculty Directory'),
            Tab(icon: Icon(Icons.person_add_outlined), text: 'Enroll Faculty'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FacultyListView(onAddFacultyPressed: () => _tabController.animateTo(1)),
          AddFacultyView(onFacultyAdded: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }
}
