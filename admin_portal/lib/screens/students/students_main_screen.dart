import 'package:flutter/material.dart';
import '../../widgets/watermark_scaffold.dart';
import 'student_list_view.dart';
import 'add_student_view.dart';

class StudentsMainScreen extends StatefulWidget {
  const StudentsMainScreen({super.key});

  @override
  State<StudentsMainScreen> createState() => _StudentsMainScreenState();
}

class _StudentsMainScreenState extends State<StudentsMainScreen> with SingleTickerProviderStateMixin {
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
          'Student Management',
          style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryNavy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryNavy,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.people_alt_outlined), text: 'Student Directory'),
            Tab(icon: Icon(Icons.person_add_alt_1_outlined), text: 'Enroll Student'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StudentListView(onAddStudentPressed: () => _tabController.animateTo(1)),
          AddStudentView(onStudentAdded: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }
}
