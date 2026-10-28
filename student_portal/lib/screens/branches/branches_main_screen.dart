import 'package:flutter/material.dart';
import '../../widgets/watermark_scaffold.dart';
import 'branch_list_view.dart';
import 'add_branch_view.dart';

class BranchesMainScreen extends StatefulWidget {
  const BranchesMainScreen({super.key});

  @override
  State<BranchesMainScreen> createState() => _BranchesMainScreenState();
}

class _BranchesMainScreenState extends State<BranchesMainScreen>
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
          'Academic Branches & Departments',
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
            Tab(icon: Icon(Icons.account_tree_outlined), text: 'Branches Directory'),
            Tab(icon: Icon(Icons.add_business_outlined), text: 'Add Branch'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BranchListView(onAddBranchPressed: () => _tabController.animateTo(1)),
          AddBranchView(onBranchAdded: () => _tabController.animateTo(0)),
        ],
      ),
    );
  }
}