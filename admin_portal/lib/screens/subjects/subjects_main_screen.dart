import 'package:flutter/material.dart';
import '../../widgets/watermark_scaffold.dart';
import 'subject_list_view.dart';
import 'add_subject_view.dart';

class SubjectsMainScreen extends StatefulWidget {
  const SubjectsMainScreen({super.key});

  @override
  State<SubjectsMainScreen> createState() => _SubjectsMainScreenState();
}

class _SubjectsMainScreenState extends State<SubjectsMainScreen> with SingleTickerProviderStateMixin {
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
          'Curriculum & Subject Management',
          style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryNavy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryNavy,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Subjects Directory'),
            Tab(icon: Icon(Icons.post_add_outlined), text: 'Add Subject / Excel Import'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SubjectListView(onAddSubjectPressed: () => _tabController.animateTo(1)),
          AddSubjectView(onSubjectAdded: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }
}
