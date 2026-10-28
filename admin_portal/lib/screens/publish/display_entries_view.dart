import 'package:flutter/material.dart';
import '../../main.dart';
import 'assessment_marks_view.dart';

class DisplayEntriesView extends StatefulWidget {
  final VoidCallback onCreatePressed;

  const DisplayEntriesView({super.key, required this.onCreatePressed});

  @override
  State<DisplayEntriesView> createState() => _DisplayEntriesViewState();
}

class _DisplayEntriesViewState extends State<DisplayEntriesView> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color textMuted = Color(0xFF6B7280);

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;

  // Filter States
  String _selectedBranch = 'ALL';
  String _selectedYearSem = 'ALL';
  String _selectedStatus = 'ALL'; // 'ALL', 'OPEN', 'CLOSED', 'UPCOMING'
  String _selectedVisibility = 'ALL'; // 'ALL', 'LIVE', 'HIDDEN'

  List<String> _branches = ['ALL', 'CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
  final List<String> _semesters = [
    'ALL',
    '1 Year 1 Sem',
    '1 Year 2 Sem',
    '2 Year 3 Sem',
    '2 Year 4 Sem',
    '3 Year 5 Sem',
    '3 Year 6 Sem',
    '4 Year 7 Sem',
    '4 Year 8 Sem',
  ];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchPublishedEntries();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final list = (data as List).map((e) => e['branch_code'].toString()).toList();
      if (mounted && list.isNotEmpty) {
        setState(() => _branches = ['ALL', ...list]);
      }
    } catch (_) {}
  }

  Future<void> _fetchPublishedEntries() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await supabase
          .from('assessment_windows')
          .select()
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allEntries = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading entries: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();
    final now = DateTime.now();

    setState(() {
      _filteredEntries = _allEntries.where((item) {
        final examName = (item['exam_name'] ?? '').toString().toLowerCase();
        final branch = (item['branch'] ?? '').toString();
        final yearSem = (item['year_sem'] ?? '').toString();
        final fromDate = DateTime.tryParse(item['from_date'] ?? '') ?? now;
        final lastDate = DateTime.tryParse(item['last_date'] ?? '') ?? now;
        final bool isForceClosed = item['is_closed'] ?? false;
        final bool isPublishedToStudents = item['published_to_students'] ?? false;

        final isBefore = now.isBefore(fromDate);
        final isAfter = now.isAfter(lastDate.add(const Duration(days: 1)));
        final bool isOpen = !isForceClosed && !isBefore && !isAfter;

        // 1. Text Query
        final matchesQuery = examName.contains(query) || branch.toLowerCase().contains(query);

        // 2. Branch & Sem
        final matchesBranch = _selectedBranch == 'ALL' || branch == _selectedBranch;
        final matchesYearSem = _selectedYearSem == 'ALL' || yearSem == _selectedYearSem;

        // 3. Status
        bool matchesStatus = true;
        if (_selectedStatus == 'OPEN') matchesStatus = isOpen;
        if (_selectedStatus == 'CLOSED') matchesStatus = isForceClosed || isAfter;
        if (_selectedStatus == 'UPCOMING') matchesStatus = isBefore && !isForceClosed;

        // 4. Student Visibility
        bool matchesVisibility = true;
        if (_selectedVisibility == 'LIVE') matchesVisibility = isPublishedToStudents;
        if (_selectedVisibility == 'HIDDEN') matchesVisibility = !isPublishedToStudents;

        return matchesQuery && matchesBranch && matchesYearSem && matchesStatus && matchesVisibility;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedBranch = 'ALL';
      _selectedYearSem = 'ALL';
      _selectedStatus = 'ALL';
      _selectedVisibility = 'ALL';
      _searchController.clear();
      _applyFilters();
    });
  }

  // ==========================================
  // TOGGLE CLOSE / REOPEN
  // ==========================================
  Future<void> _toggleCloseEntry(Map<String, dynamic> item) async {
    final bool currentlyClosed = item['is_closed'] ?? false;
    try {
      await supabase
          .from('assessment_windows')
          .update({'is_closed': !currentlyClosed})
          .eq('id', item['id']);

      _showSnack(!currentlyClosed ? 'Marks entry window CLOSED.' : 'Marks entry window RE-OPENED.');
      _fetchPublishedEntries();
    } catch (e) {
      _showSnack('Failed to update status: $e', isError: true);
    }
  }

  // ==========================================
  // TOGGLE PUBLISH TO STUDENTS
  // ==========================================
  Future<void> _togglePublishToStudents(Map<String, dynamic> item) async {
    final bool currentlyPublished = item['published_to_students'] ?? false;
    try {
      await supabase
          .from('assessment_windows')
          .update({'published_to_students': !currentlyPublished})
          .eq('id', item['id']);

      _showSnack(!currentlyPublished ? 'Results published to students!' : 'Results unpublished.');
      _fetchPublishedEntries();
    } catch (e) {
      _showSnack('Failed to update visibility: $e', isError: true);
    }
  }

  // ==========================================
  // EDIT ASSESSMENT MODAL
  // ==========================================
  void _showEditModal(Map<String, dynamic> item) {
    final nameCtrl = TextEditingController(text: item['exam_name'] ?? '');
    DateTime fromDate = DateTime.tryParse(item['from_date'] ?? '') ?? DateTime.now();
    DateTime lastDate = DateTime.tryParse(item['last_date'] ?? '') ?? DateTime.now();

    final List<dynamic> subjectConfigs = List<dynamic>.from(item['subject_configs'] ?? []);
    final Map<String, TextEditingController> marksControllers = {};

    for (var sub in subjectConfigs) {
      final code = sub['subject_code'].toString();
      marksControllers[code] = TextEditingController(text: (sub['total_marks'] ?? 30).toString());
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Assessment Window', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Examination Name (CAPITALS) *', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: fromDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                if (picked != null) setModalState(() => fromDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'From Date', border: OutlineInputBorder(), isDense: true),
                                child: Text(fromDate.toIso8601String().split('T')[0]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(context: context, initialDate: lastDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                                if (picked != null) setModalState(() => lastDate = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Last Date', border: OutlineInputBorder(), isDense: true),
                                child: Text(lastDate.toIso8601String().split('T')[0]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ...subjectConfigs.map((sub) {
                        final code = sub['subject_code'].toString();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Row(
                            children: [
                              Expanded(child: Text('${sub['subject_name']} ($code)', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 90,
                                child: TextFormField(
                                  controller: marksControllers[code],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: const InputDecoration(labelText: 'Max Marks', border: OutlineInputBorder(), isDense: true),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    final updatedConfigs = subjectConfigs.map((sub) {
                      final code = sub['subject_code'].toString();
                      return {
                        'subject_code': code,
                        'subject_name': sub['subject_name'],
                        'total_marks': double.tryParse(marksControllers[code]?.text.trim() ?? '30') ?? 30.0,
                      };
                    }).toList();

                    await supabase.from('assessment_windows').update({
                      'exam_name': nameCtrl.text.trim().toUpperCase(),
                      'from_date': fromDate.toIso8601String().split('T')[0],
                      'last_date': lastDate.toIso8601String().split('T')[0],
                      'subject_configs': updatedConfigs,
                    }).eq('id', item['id']);

                    if (mounted) {
                      Navigator.pop(context);
                      _showSnack('Assessment updated successfully');
                      _fetchPublishedEntries();
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // DELETE ASSESSMENT MODAL
  // ==========================================
  void _confirmDeleteWindow(String id, String examName, String branch) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Assessment Window', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text('Permanently remove "$examName ($branch)"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await supabase.from('assessment_windows').delete().eq('id', id);
                if (mounted) {
                  Navigator.pop(context);
                  _showSnack('Assessment window deleted');
                  _fetchPublishedEntries();
                }
              } catch (e) {
                _showSnack('Delete failed: $e', isError: true);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FILTER MODAL BOTTOM SHEET
  // ==========================================
  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filter Assessment Windows', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy)),
                        TextButton(onPressed: () { _resetFilters(); Navigator.pop(context); }, child: const Text('Reset All', style: TextStyle(color: accentRed))),
                      ],
                    ),
                    const Divider(),

                    // Branch Filter
                    const Text('Branch', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _branches.map((b) {
                        final isSel = _selectedBranch == b;
                        return ChoiceChip(
                          label: Text(b),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (s) {
                            setSheetState(() => _selectedBranch = b);
                            setState(() => _selectedBranch = b);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Semester Filter
                    const Text('Year & Semester', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedYearSem,
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) {
                        setSheetState(() => _selectedYearSem = v!);
                        setState(() => _selectedYearSem = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(height: 12),

                    // Entry Status Filter
                    const Text('Entry Portal Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': 'All Statuses', 'val': 'ALL'},
                        {'label': 'Entry Open', 'val': 'OPEN'},
                        {'label': 'Closed / Expired', 'val': 'CLOSED'},
                        {'label': 'Upcoming', 'val': 'UPCOMING'},
                      ].map((item) {
                        final isSel = _selectedStatus == item['val'];
                        return ChoiceChip(
                          label: Text(item['label'] as String),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (s) {
                            setSheetState(() => _selectedStatus = item['val'] as String);
                            setState(() => _selectedStatus = item['val'] as String);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Student Visibility Filter
                    const Text('Student Portal Results', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': 'All', 'val': 'ALL'},
                        {'label': 'Live for Students', 'val': 'LIVE'},
                        {'label': 'Hidden from Students', 'val': 'HIDDEN'},
                      ].map((item) {
                        final isSel = _selectedVisibility == item['val'];
                        return ChoiceChip(
                          label: Text(item['label'] as String),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (s) {
                            setSheetState(() => _selectedVisibility = item['val'] as String);
                            setState(() => _selectedVisibility = item['val'] as String);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        child: Text('Apply (${_filteredEntries.length} Results)'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? accentRed : Colors.green.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = _selectedBranch != 'ALL' || _selectedYearSem != 'ALL' || _selectedStatus != 'ALL' || _selectedVisibility != 'ALL';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search & Filter Trigger Bar
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: primaryNavy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by exam name, branch...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        ),
                      IconButton(
                        icon: Badge(
                          isLabelVisible: hasActiveFilters,
                          child: const Icon(Icons.tune, color: primaryNavy),
                        ),
                        tooltip: 'Filter Windows',
                        onPressed: _openFilterBottomSheet,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredEntries.length} Published Assessment Windows',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textMuted),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: primaryNavy, size: 20),
                    onPressed: _fetchPublishedEntries,
                    tooltip: 'Refresh entries',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                    : _filteredEntries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fact_check_outlined, size: 54, color: textMuted),
                                const SizedBox(height: 10),
                                const Text('No assessment windows match the selected filters', style: TextStyle(color: textMuted)),
                                const SizedBox(height: 8),
                                TextButton(onPressed: _resetFilters, child: const Text('Reset All Filters')),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredEntries.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _filteredEntries[index];
                              final now = DateTime.now();
                              final fromDate = DateTime.tryParse(item['from_date'] ?? '') ?? now;
                              final lastDate = DateTime.tryParse(item['last_date'] ?? '') ?? now;

                              final bool isForceClosed = item['is_closed'] ?? false;
                              final bool isPublishedToStudents = item['published_to_students'] ?? false;

                              final isBefore = now.isBefore(fromDate);
                              final isAfter = now.isAfter(lastDate.add(const Duration(days: 1)));
                              final bool isOpen = !isForceClosed && !isBefore && !isAfter;

                              final configs = (item['subject_configs'] as List?) ?? [];

                              return Card(
                                elevation: 2.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: isOpen ? Colors.green.shade400 : Colors.grey.shade300,
                                    width: isOpen ? 1.5 : 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['exam_name'] ?? '',
                                                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: primaryNavy),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Branch: ${item['branch']} • Semester: ${item['year_sem']}',
                                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textMuted),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              // Entry Status
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isForceClosed
                                                      ? accentRed.withOpacity(0.12)
                                                      : isOpen
                                                          ? Colors.green.withOpacity(0.12)
                                                          : isBefore
                                                              ? accentGold.withOpacity(0.2)
                                                              : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isForceClosed
                                                      ? 'FORCE CLOSED'
                                                      : isOpen
                                                          ? 'ENTRY OPEN'
                                                          : isBefore
                                                              ? 'UPCOMING'
                                                              : 'TIME EXPIRED',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: isForceClosed
                                                        ? accentRed
                                                        : isOpen
                                                            ? Colors.green.shade800
                                                            : isBefore
                                                                ? Colors.orange.shade900
                                                                : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              // Live for students
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isPublishedToStudents ? primaryNavy.withOpacity(0.12) : Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(isPublishedToStudents ? Icons.visibility : Icons.visibility_off, size: 12, color: isPublishedToStudents ? primaryNavy : textMuted),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isPublishedToStudents ? 'LIVE FOR STUDENTS' : 'HIDDEN FROM STUDENTS',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPublishedToStudents ? primaryNavy : textMuted),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      Text(
                                        'Schedule: ${item['from_date']} to ${item['last_date']} (${configs.length} Subjects Evaluated)',
                                        style: const TextStyle(fontSize: 12, color: textMuted),
                                      ),
                                      const SizedBox(height: 8),

                                      // Subject Max Marks Chips
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: configs.map((c) {
                                          return Chip(
                                            padding: EdgeInsets.zero,
                                            labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            backgroundColor: primaryNavy.withOpacity(0.06),
                                            label: Text(
                                              '${c['subject_code']}: ${c['total_marks']}M',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryNavy),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const Divider(height: 20),

                                      // Actions Row
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          // NEW ACTION: View Evaluation Marks Screen
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => AssessmentMarksView(assessmentWindow: item),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.table_chart_outlined, size: 16),
                                            label: const Text('View Marks & Reports', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryNavy,
                                              foregroundColor: Colors.white,
                                              elevation: 1,
                                            ),
                                          ),

                                          // Publish/Unpublish to Students
                                          OutlinedButton.icon(
                                            onPressed: () => _togglePublishToStudents(item),
                                            icon: Icon(isPublishedToStudents ? Icons.visibility_off : Icons.send_and_archive_outlined, size: 15),
                                            label: Text(isPublishedToStudents ? 'Unpublish from Students' : 'Publish to Students', style: const TextStyle(fontSize: 11.5)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isPublishedToStudents ? accentRed : primaryNavy,
                                              side: BorderSide(color: isPublishedToStudents ? accentRed : primaryNavy),
                                            ),
                                          ),

                                          // Force Close/Re-open
                                          OutlinedButton.icon(
                                            onPressed: () => _toggleCloseEntry(item),
                                            icon: Icon(isForceClosed ? Icons.lock_open : Icons.lock_outline, size: 15),
                                            label: Text(isForceClosed ? 'Re-open Entry' : 'Close Entry', style: const TextStyle(fontSize: 11.5)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isForceClosed ? Colors.green.shade800 : Colors.orange.shade900,
                                              side: BorderSide(color: isForceClosed ? Colors.green.shade800 : Colors.orange.shade900),
                                            ),
                                          ),

                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, color: primaryNavy, size: 20),
                                            tooltip: 'Edit Details',
                                            onPressed: () => _showEditModal(item),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, color: accentRed, size: 20),
                                            tooltip: 'Delete Window',
                                            onPressed: () => _confirmDeleteWindow(item['id'], item['exam_name'], item['branch']),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
