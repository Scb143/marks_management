import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../main.dart';
import '../../widgets/watermark_scaffold.dart';

class StudentEvaluationSummary {
  final String userId;
  final String name;
  final String branch;
  final String section;
  final String yearSem;
  final Map<String, double?> assessmentPercentages; // windowId -> percentage
  double overallPercentage;
  bool isSelected;

  StudentEvaluationSummary({
    required this.userId,
    required this.name,
    required this.branch,
    required this.section,
    required this.yearSem,
    required this.assessmentPercentages,
    this.overallPercentage = 0.0,
    this.isSelected = false,
  });
}

class PromotionDetentionScreen extends StatefulWidget {
  const PromotionDetentionScreen({super.key}); // Ensure 'const' is present here

  @override
  State<PromotionDetentionScreen> createState() =>
      _PromotionDetentionScreenState();
}

class _PromotionDetentionScreenState extends State<PromotionDetentionScreen> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color textMuted = Color(0xFF6B7280);

  final List<String> _semesters = [
    '1 Year 1 Sem',
    '1 Year 2 Sem',
    '2 Year 3 Sem',
    '2 Year 4 Sem',
    '3 Year 5 Sem',
    '3 Year 6 Sem',
    '4 Year 7 Sem',
    '4 Year 8 Sem',
  ];

  List<String> _branches = ['ALL'];
  String _selectedYearSem = '1 Year 1 Sem';
  String _selectedBranch = 'ALL';

  // Filter & Logic Controls
  double _passingThreshold = 40.0;
  final TextEditingController _thresholdController =
      TextEditingController(text: '40');
  String _comparisonOperator = '>='; // '>=', '<=', '>', '<', '='
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isProcessing = false;

  List<Map<String, dynamic>> _conductedWindows = [];
  List<StudentEvaluationSummary> _allEvaluations = [];
  List<StudentEvaluationSummary> _filteredEvaluations = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchAssessmentDataAndStudents();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final list = (data as List)
          .map((e) => e['branch_code'].toString().trim())
          .toList();

      if (mounted) {
        setState(() {
          _branches = ['ALL', ...list];
        });
      }
    } catch (_) {}
  }

  // Load conducted assessment windows and calculate scores for each student
  Future<void> _fetchAssessmentDataAndStudents() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch Students
      var studentQuery = supabase
          .from('users')
          .select('user_id, name, branch, section, year_sem')
          .eq('role', 'student')
          .eq('year_sem', _selectedYearSem);

      if (_selectedBranch != 'ALL') {
        studentQuery = studentQuery.eq('branch', _selectedBranch);
      }

      final List<dynamic> studentData =
          await studentQuery.order('user_id', ascending: true);

      // 2. Fetch Conducted Assessment Windows for this Year/Sem
      var windowQuery = supabase
          .from('assessment_windows')
          .select('id, exam_name, branch, year_sem, subject_configs')
          .eq('year_sem', _selectedYearSem);

      if (_selectedBranch != 'ALL') {
        windowQuery = windowQuery.or(
            'branch.eq.$_selectedBranch,branch.eq.ALL');
      }

      final List<dynamic> windowData =
          await windowQuery.order('created_at', ascending: true);
      _conductedWindows = List<Map<String, dynamic>>.from(windowData);

      // 3. Query marks from dynamic evaluation tables for each assessment
      Map<String, Map<String, double>> windowStudentPercentages = {};

      for (var win in _conductedWindows) {
        final String windowId = win['id'].toString();
        final String winBranch = (win['branch'] ?? 'ALL').toString();
        final List<dynamic> configs =
            (win['subject_configs'] as List?) ?? [];

        double maxPossibleMarks = 0.0;
        for (var c in configs) {
          maxPossibleMarks +=
              (c['total_marks'] as num?)?.toDouble() ?? 30.0;
        }

        windowStudentPercentages[windowId] = {};

        // Determine target branches to query
        List<String> targetBranches = [];
        if (_selectedBranch != 'ALL') {
          targetBranches = [_selectedBranch];
        } else if (winBranch != 'ALL') {
          targetBranches = [winBranch];
        } else {
          targetBranches = _branches.where((b) => b != 'ALL').toList();
        }

        for (var b in targetBranches) {
          final cleanBranch =
              b.toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
          final cleanId = windowId.replaceAll('-', '_');
          final tableName = '${cleanBranch}_$cleanId';

          try {
            final List<dynamic> marksRows = await supabase
                .from(tableName)
                .select();

            for (var row in marksRows) {
              final studentId = row['student_id']?.toString() ?? '';
              double totalObtained = 0.0;
              int enteredCount = 0;

              for (var c in configs) {
                final code = c['subject_code'].toString();
                if (row[code] != null) {
                  totalObtained += (row[code] as num).toDouble();
                  enteredCount++;
                }
              }

              if (maxPossibleMarks > 0 && enteredCount > 0) {
                final pct = (totalObtained / maxPossibleMarks) * 100.0;
                windowStudentPercentages[windowId]![studentId] = pct;
              }
            }
          } catch (_) {
            // Assessment table may not exist yet if unpopulated
          }
        }
      }

      // 4. Build Evaluation Summary List
      List<StudentEvaluationSummary> summaries = [];

      for (var st in studentData) {
        final uid = st['user_id'].toString();
        Map<String, double?> studentWindowScores = {};
        double sumPercentages = 0.0;
        int evaluatedCount = 0;

        for (var win in _conductedWindows) {
          final wId = win['id'].toString();
          final score = windowStudentPercentages[wId]?[uid];
          studentWindowScores[wId] = score;

          if (score != null) {
            sumPercentages += score;
            evaluatedCount++;
          }
        }

        final overall = evaluatedCount > 0
            ? (sumPercentages / evaluatedCount)
            : 0.0;

        summaries.add(
          StudentEvaluationSummary(
            userId: uid,
            name: st['name'] ?? 'Student',
            branch: st['branch'] ?? '',
            section: st['section'] ?? 'A',
            yearSem: st['year_sem'] ?? _selectedYearSem,
            assessmentPercentages: studentWindowScores,
            overallPercentage: double.parse(overall.toStringAsFixed(1)),
          ),
        );
      }

      if (mounted) {
        setState(() {
          _allEvaluations = summaries;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading promotion data: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredEvaluations = _allEvaluations.where((s) {
        // Text Match
        final matchesText = s.userId.toLowerCase().contains(query) ||
            s.name.toLowerCase().contains(query) ||
            s.branch.toLowerCase().contains(query);

        // Mathematical Operator Match (<, <=, >, >=, =)
        bool matchesCondition = true;
        switch (_comparisonOperator) {
          case '>=':
            matchesCondition = s.overallPercentage >= _passingThreshold;
            break;
          case '<=':
            matchesCondition = s.overallPercentage <= _passingThreshold;
            break;
          case '>':
            matchesCondition = s.overallPercentage > _passingThreshold;
            break;
          case '<':
            matchesCondition = s.overallPercentage < _passingThreshold;
            break;
          case '=':
            matchesCondition =
                (s.overallPercentage - _passingThreshold).abs() < 0.01;
            break;
        }

        return matchesText && matchesCondition;
      }).toList();
    });
  }

  String _getNextSemester(String currentSem) {
    final idx = _semesters.indexOf(currentSem);
    if (idx != -1 && idx < _semesters.length - 1) {
      return _semesters[idx + 1];
    }
    return 'Graduated / Completed';
  }

  // Bulk Promote Selected Students to Next Semester
  Future<void> _handleBulkPromote() async {
    final selectedStudents =
        _filteredEvaluations.where((s) => s.isSelected).toList();

    if (selectedStudents.isEmpty) {
      _showSnack('Select at least one student to promote.', isError: true);
      return;
    }

    final nextSem = _getNextSemester(_selectedYearSem);
    if (nextSem.contains('Graduated')) {
      _showSnack(
          'Students are already in the final semester ($_selectedYearSem).',
          isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Promotion',
            style: TextStyle(
                color: primaryNavy, fontWeight: FontWeight.bold)),
        content: Text(
          'Promote ${selectedStudents.length} student(s) from "$_selectedYearSem" to "$nextSem"?\n\n'
          'All database assessment allocations will automatically re-sync.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Promote'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final studentIds = selectedStudents.map((s) => s.userId).toList();

      await supabase
          .from('users')
          .update({'year_sem': nextSem})
          .inFilter('user_id', studentIds);

      _showSnack(
          'Successfully promoted ${selectedStudents.length} student(s) to $nextSem!');
      _fetchAssessmentDataAndStudents();
    } catch (e) {
      _showSnack('Promotion failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Bulk Detain Selected Students
  Future<void> _handleBulkDetain() async {
    final selectedStudents =
        _filteredEvaluations.where((s) => s.isSelected).toList();

    if (selectedStudents.isEmpty) {
      _showSnack('Select at least one student to detain.', isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Detention',
            style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text(
          'Detain ${selectedStudents.length} student(s) in "$_selectedYearSem"?\n'
          'Their semester progression will remain frozen.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Detain'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final studentIds = selectedStudents.map((s) => s.userId).toList();

      // Confirms retention in same semester
      await supabase
          .from('users')
          .update({'year_sem': _selectedYearSem})
          .inFilter('user_id', studentIds);

      _showSnack(
          'Marked ${selectedStudents.length} student(s) as detained in $_selectedYearSem.');
      _fetchAssessmentDataAndStudents();
    } catch (e) {
      _showSnack('Detention action failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _selectAll(bool select) {
    setState(() {
      for (var s in _filteredEvaluations) {
        s.isSelected = select;
      }
    });
  }

  void _selectByStatus({required bool passing}) {
    setState(() {
      for (var s in _filteredEvaluations) {
        if (passing) {
          s.isSelected = s.overallPercentage >= _passingThreshold;
        } else {
          s.isSelected = s.overallPercentage < _passingThreshold;
        }
      }
    });
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? accentRed : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nextSemester = _getNextSemester(_selectedYearSem);
    final selectedCount =
        _filteredEvaluations.where((s) => s.isSelected).length;

    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        title: const Text(
          'Student Academic Progression',
          style: TextStyle(
            color: primaryNavy,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryNavy),
            onPressed: _fetchAssessmentDataAndStudents,
            tooltip: 'Refresh Records',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1300),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TOP CONTROL BAR (ADAPTIVE WRAP)
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: LayoutBuilder(
                          builder: (context, filterConstraints) {
                            final itemWidth = isMobile
                                ? (filterConstraints.maxWidth - 10) / 2
                                : 170.0;

                            return Wrap(
                              spacing: 10,
                              runSpacing: 12,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Current Semester
                                SizedBox(
                                  width: itemWidth,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedYearSem,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Semester *',
                                      prefixIcon: Icon(Icons.calendar_month_outlined, size: 18),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    ),
                                    items: _semesters
                                        .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => _selectedYearSem = v!);
                                      _fetchAssessmentDataAndStudents();
                                    },
                                  ),
                                ),

                                // Branch
                                SizedBox(
                                  width: itemWidth,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedBranch,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Branch',
                                      prefixIcon: Icon(Icons.account_tree_outlined, size: 18),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    ),
                                    items: _branches
                                        .map((b) => DropdownMenuItem(
                                            value: b,
                                            child: Text(b == 'ALL' ? 'All Branches' : b,
                                                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => _selectedBranch = v!);
                                      _fetchAssessmentDataAndStudents();
                                    },
                                  ),
                                ),

                                // Pass Cutoff %
                                SizedBox(
                                  width: itemWidth,
                                  child: TextFormField(
                                    controller: _thresholdController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.center,
                                    decoration: const InputDecoration(
                                      labelText: 'Pass Cutoff',
                                      prefixIcon: Icon(Icons.tune, size: 18),
                                      suffixText: '%',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    ),
                                    onChanged: (val) {
                                      final parsed = double.tryParse(val.trim());
                                      if (parsed != null) {
                                        setState(() => _passingThreshold = parsed);
                                        _applyFilters();
                                      }
                                    },
                                  ),
                                ),

                                // Condition
                                SizedBox(
                                  width: itemWidth,
                                  child: DropdownButtonFormField<String>(
                                    value: _comparisonOperator,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Condition',
                                      prefixIcon: Icon(Icons.filter_alt_outlined, size: 18),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: '>=', child: Text('>= (Passed)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '<', child: Text('< (Failed)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '>', child: Text('> (Greater)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '<=', child: Text('<= (Less/Eq)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: '=', child: Text('= (Exact)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (op) {
                                      if (op == null) return;
                                      setState(() => _comparisonOperator = op);
                                      _applyFilters();
                                    },
                                  ),
                                ),

                                // Search Field
                                SizedBox(
                                  width: isMobile ? double.infinity : 220,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search HT, Name...',
                                      prefixIcon: Icon(Icons.search, size: 18),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2. QUICK ACTION & SELECTION BUTTONS (RESPONSIVE WRAP)
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Selection Actions',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: textMuted, fontSize: 12),
                                ),
                                Text(
                                  '$selectedCount of ${_filteredEvaluations.length} Selected',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _selectAll(true),
                                  icon: const Icon(Icons.select_all, size: 14),
                                  label: const Text('All', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    foregroundColor: primaryNavy,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _selectAll(false),
                                  icon: const Icon(Icons.deselect, size: 14),
                                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    foregroundColor: textMuted,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _selectByStatus(passing: true),
                                  icon: const Icon(Icons.check_circle_outline, size: 14),
                                  label: Text('Passed (>= ${_passingThreshold.toInt()}%)', style: const TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _selectByStatus(passing: false),
                                  icon: const Icon(Icons.cancel_outlined, size: 14),
                                  label: Text('Failed (< ${_passingThreshold.toInt()}%)', style: const TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: accentRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. TABLE
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                          : _filteredEvaluations.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No student records match the selected criteria.',
                                    style: TextStyle(color: textMuted),
                                  ),
                                )
                              : Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(primaryNavy.withOpacity(0.08)),
                                        columns: [
                                          DataColumn(
                                            label: Checkbox(
                                              value: _filteredEvaluations.isNotEmpty &&
                                                  _filteredEvaluations.every((s) => s.isSelected),
                                              onChanged: (v) => _selectAll(v ?? false),
                                            ),
                                          ),
                                          const DataColumn(label: Text('Hallticket', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                          const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                          const DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                          const DataColumn(label: Text('Sec', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                          ..._conductedWindows.map((win) => DataColumn(
                                                label: Text(
                                                  win['exam_name'] ?? 'Exam',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 11),
                                                ),
                                              )),
                                          const DataColumn(label: Text('Aggregate %', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                          const DataColumn(label: Text('Verdict', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy))),
                                        ],
                                        rows: _filteredEvaluations.map((st) {
                                          final isPass = st.overallPercentage >= _passingThreshold;
                                          return DataRow(
                                            selected: st.isSelected,
                                            onSelectChanged: (val) => setState(() => st.isSelected = val ?? false),
                                            cells: [
                                              DataCell(Checkbox(
                                                value: st.isSelected,
                                                onChanged: (val) => setState(() => st.isSelected = val ?? false),
                                              )),
                                              DataCell(Text(st.userId, style: const TextStyle(fontWeight: FontWeight.bold))),
                                              DataCell(Text(st.name)),
                                              DataCell(Text(st.branch)),
                                              DataCell(Text(st.section)),
                                              ..._conductedWindows.map((win) {
                                                final wId = win['id'].toString();
                                                final score = st.assessmentPercentages[wId];
                                                return DataCell(Center(
                                                  child: Text(
                                                    score != null ? '${score.toStringAsFixed(1)}%' : 'N/A',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      color: score != null
                                                          ? (score >= _passingThreshold ? Colors.green.shade800 : accentRed)
                                                          : textMuted,
                                                    ),
                                                  ),
                                                ));
                                              }),
                                              DataCell(Text('${st.overallPercentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: isPass ? Colors.green.withOpacity(0.12) : accentRed.withOpacity(0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    isPass ? 'ELIGIBLE' : 'FAIL',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10.5,
                                                      color: isPass ? Colors.green.shade800 : accentRed,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                    const SizedBox(height: 8),

                    // 4. BOTTOM EXECUTION BAR (AUTO-STACKS ON MOBILE)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: isMobile
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Target: $nextSemester',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: textMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: (_isProcessing || selectedCount == 0) ? null : _handleBulkDetain,
                                          icon: const Icon(Icons.block, color: accentRed, size: 16),
                                          label: Text('Detain ($selectedCount)', style: const TextStyle(color: accentRed, fontSize: 12)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: accentRed),
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: ElevatedButton.icon(
                                          onPressed: (_isProcessing || selectedCount == 0) ? null : _handleBulkPromote,
                                          icon: _isProcessing
                                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                              : const Icon(Icons.trending_up, size: 16),
                                          label: Text('Promote ($selectedCount)', style: const TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryNavy,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 10),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Target Semester: $nextSemester', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: textMuted)),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: (_isProcessing || selectedCount == 0) ? null : _handleBulkDetain,
                                        icon: const Icon(Icons.block, color: accentRed, size: 16),
                                        label: Text('Detain Selected ($selectedCount)', style: const TextStyle(color: accentRed)),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: accentRed),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: (_isProcessing || selectedCount == 0) ? null : _handleBulkPromote,
                                        icon: _isProcessing
                                            ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.trending_up, size: 16),
                                        label: Text('Promote Selected ($selectedCount) to $nextSemester'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryNavy,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}