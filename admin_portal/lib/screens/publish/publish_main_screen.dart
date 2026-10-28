import 'package:flutter/material.dart';
import '../../widgets/watermark_scaffold.dart';
import 'create_entry_view.dart';
import 'display_entries_view.dart';

class PublishMarksMainScreen extends StatefulWidget {
  const PublishMarksMainScreen({super.key});

  @override
  State<PublishMarksMainScreen> createState() => _PublishMarksMainScreenState();
}

class _PublishMarksMainScreenState extends State<PublishMarksMainScreen>
    with SingleTickerProviderStateMixin {
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
          'Publish Marks & Examination Windows',
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
            Tab(icon: Icon(Icons.add_task_outlined), text: 'Create Entry Window'),
            Tab(icon: Icon(Icons.list_alt_outlined), text: 'Published Windows'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CreateEntryView(onEntryCreated: () => _tabController.animateTo(1)),
          DisplayEntriesView(onCreatePressed: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }
}
