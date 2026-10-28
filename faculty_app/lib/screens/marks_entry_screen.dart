import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../main.dart';
import '../widgets/watermark_scaffold.dart';

class StudentMarksModel {
  final String studentId;
  final String studentName;
  final String rollNo;
  final String section;

  TextEditingController examController;
  TextEditingController assignmentController;
  TextEditingController activityController;

  double total;
  double average;

  StudentMarksModel({
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.section,
    double exam = 0.0,
    double assignment = 0.0,
    double activity = 0.0,
  })  : examController = TextEditingController(text: exam > 0 ? exam.toString() : ''),
        assignmentController = TextEditingController(text: assignment > 0 ? assignment.toString() : ''),
        activityController = TextEditingController(text: activity > 0 ? activity.toString() : ''),
        total = exam + assignment + activity,
        average = (exam + assignment + activity) / 3.0;

  void reCalculate() {
    final e = double.tryParse(examController.text.trim()) ?? 0.0;
    final a = double.tryParse(assignmentController.text.trim()) ?? 0.0;
    final act = double.tryParse(activityController.text.trim()) ?? 0.0;
    total = e + a + act;
    average = double.parse((total / 3.0).toStringAsFixed(2));
  }

  void dispose() {
    examController.dispose();
    assignmentController.dispose();
    activityController.dispose();
  }
}

class MarksEntryScreen extends StatefulWidget {
  final Map<String, dynamic> subject;
  final Map<String, dynamic> assessmentWindow;
  final String facultyId;

  const MarksEntryScreen({
    super.key,
    required this.subject,
    required this.assessmentWindow,
    required this.facultyId,
  });

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color darkNavy = Color(0xFF07193D);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitted = false;
  bool _isLockedDueToDate = false;

  List<StudentMarksModel> _allStudents = [];
  List<StudentMarksModel> _filteredStudents = [];

  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'ALL'; // 'ALL', 'COMPLETED', 'PENDING'

  String get _subjectCode => widget.subject['subject_code'].toString();
  String get _section => (widget.subject['section'] ?? 'A').toString().toUpperCase();
  String get _windowId => widget.assessmentWindow['id'].toString();
  String get _examName => widget.assessmentWindow['exam_name'] ?? 'EXAMINATION';

  @override
  void initState() {
    super.initState();
    _checkLockConditions();
    _loadStudentsAndMarks();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (var s in _allStudents) {
      s.dispose();
    }
    super.dispose();
  }

  void _checkLockConditions() {
    final now = DateTime.now();
    final lastDateStr = widget.assessmentWindow['last_date']?.toString() ?? '';
    final lastDate = DateTime.tryParse(lastDateStr) ?? now;
    
    // Window is expired if current date is after end date
    _isLockedDueToDate = now.isAfter(lastDate.add(const Duration(days: 1)));
  }

  bool get _isReadOnly => _isSubmitted && _isLockedDueToDate;

  Future<void> _loadStudentsAndMarks() async {
    setState(() => _isLoading = true);
    try {
      // 1. Check Submission state
      final subRes = await supabase
          .from('faculty_marks_submissions')
          .select('is_submitted')
          .eq('window_id', _windowId)
          .eq('subject_code', _subjectCode)
          .eq('section', _section)
          .maybeSingle();

      if (subRes != null && subRes['is_submitted'] == true) {
        _isSubmitted = true;
      }

      // 2. Fetch Enrolled Students for this Section
      final List<dynamic> studentsData = await supabase
          .from('users')
          .select('user_id, name, roll_no, section')
          .eq('role', 'student')
          .eq('branch', widget.subject['branch'])
          .eq('year_sem', widget.subject['year_sem'])
          .eq('section', _section)
          .order('user_id', ascending: true);

      // 3. Fetch Existing Marks
      final List<dynamic> marksData = await supabase
          .from('student_component_marks')
          .select('student_id, exam_marks, assignment_marks, activity_marks')
          .eq('window_id', _windowId)
          .eq('subject_code', _subjectCode);

      final marksMap = <String, Map<String, dynamic>>{};
      for (var m in marksData) {
        marksMap[m['student_id'].toString()] = m;
      }

      List<StudentMarksModel> list = [];
      for (var s in studentsData) {
        final uid = s['user_id'].toString();
        final m = marksMap[uid];

        final studentMarks = StudentMarksModel(
          studentId: uid,
          studentName: s['name'] ?? 'Student',
          rollNo: s['roll_no'] ?? 'N/A',
          section: _section,
          exam: (m?['exam_marks'] as num?)?.toDouble() ?? 0.0,
          assignment: (m?['assignment_marks'] as num?)?.toDouble() ?? 0.0,
          activity: (m?['activity_marks'] as num?)?.toDouble() ?? 0.0,
        );

        studentMarks.examController.addListener(() {
          studentMarks.reCalculate();
          setState(() {});
        });
        studentMarks.assignmentController.addListener(() {
          studentMarks.reCalculate();
          setState(() {});
        });
        studentMarks.activityController.addListener(() {
          studentMarks.reCalculate();
          setState(() {});
        });

        list.add(studentMarks);
      }

      if (mounted) {
        setState(() {
          _allStudents = list;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading student marks: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredStudents = _allStudents.where((s) {
        final matchesQuery = s.studentId.toLowerCase().contains(query) ||
            s.studentName.toLowerCase().contains(query) ||
            s.rollNo.toLowerCase().contains(query);

        bool matchesStatus = true;
        final hasEnteredAll = s.examController.text.isNotEmpty &&
            s.assignmentController.text.isNotEmpty &&
            s.activityController.text.isNotEmpty;

        if (_statusFilter == 'COMPLETED') matchesStatus = hasEnteredAll;
        if (_statusFilter == 'PENDING') matchesStatus = !hasEnteredAll;

        return matchesQuery && matchesStatus;
      }).toList();
    });
  }

  // ==========================================
  // ACTION BUTTON 1: SAVE DRAFT
  // ==========================================
  Future<void> _handleSave({bool silent = false}) async {
    if (_isReadOnly) {
      _showSnack('Evaluation period is locked. Modifications are disabled.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      List<Map<String, dynamic>> records = [];

      for (var s in _allStudents) {
        final e = double.tryParse(s.examController.text.trim()) ?? 0.0;
        final a = double.tryParse(s.assignmentController.text.trim()) ?? 0.0;
        final act = double.tryParse(s.activityController.text.trim()) ?? 0.0;

        records.add({
          'window_id': _windowId,
          'student_id': s.studentId,
          'subject_code': _subjectCode,
          'section': _section,
          'exam_marks': e,
          'assignment_marks': a,
          'activity_marks': act,
          'total_marks': s.total,
          'average_marks': s.average,
        });
      }

      // Upsert component marks
      await supabase.from('student_component_marks').upsert(
            records,
            onConflict: 'window_id,student_id,subject_code',
          );

      // Sync total marks into dynamic assessment table ([branch]_[window_id])
      final cleanBranch = widget.subject['branch'].toString().toLowerCase().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final cleanWindowId = _windowId.replaceAll('-', '_');
      final tableName = '${cleanBranch}_$cleanWindowId';

      for (var s in _allStudents) {
        try {
          await supabase.from(tableName).update({
            _subjectCode: s.total,
          }).eq('student_id', s.studentId);
        } catch (_) {}
      }

      if (mounted && !silent) {
        _showSnack('Marks saved as draft successfully!');
      }
    } catch (e) {
      if (mounted) _showSnack('Failed to save marks: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // ACTION BUTTON 2: RESET MARKS
  // ==========================================
  void _handleReset() {
    if (_isReadOnly) {
      _showSnack('Cannot reset. Marks are submitted and window is closed.', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Marks', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to clear all entered marks?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              for (var s in _allStudents) {
                s.examController.clear();
                s.assignmentController.clear();
                s.activityController.clear();
                s.reCalculate();
              }
              setState(() {});
              _showSnack('Marks reset locally. Press Save to persist changes.');
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // ACTION BUTTON 3: SUBMIT MARKS
  // ==========================================
  Future<void> _handleSubmit() async {
    if (_isReadOnly) {
      _showSnack('Cannot re-submit. Entry period has concluded.', isError: true);
      return;
    }

    // Check if any student marks are blank
    bool hasBlanks = _allStudents.any((s) =>
        s.examController.text.trim().isEmpty ||
        s.assignmentController.text.trim().isEmpty ||
        s.activityController.text.trim().isEmpty);

    if (hasBlanks) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete Marks Detected', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Some students have blank marks which will be counted as 0. Do you still want to proceed?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Proceed & Submit'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    // Save first
    await _handleSave(silent: true);

    setState(() => _isSaving = true);
    try {
      await supabase.from('faculty_marks_submissions').upsert({
        'window_id': _windowId,
        'subject_code': _subjectCode,
        'section': _section,
        'faculty_id': widget.facultyId,
        'is_submitted': true,
        'submitted_at': DateTime.now().toIso8601String(),
      }, onConflict: 'window_id,subject_code,section');

      if (mounted) {
        setState(() => _isSubmitted = true);
        _showSnack('Marks submitted successfully to the Administration!');
      }
    } catch (e) {
      if (mounted) _showSnack('Submission failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ==========================================
  // ACTION BUTTON 4: PRINT / EXPORT REPORT
  // ==========================================
  Future<void> _handlePrint() async {
    if (_filteredStudents.isEmpty) {
      _showSnack('No student records to print.', isError: true);
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'MOTHER THERESA INSTITUTE OF ENGINEERING & TECHNOLOGY',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('0B2356')),
                    ),
                    pw.Text(
                      'Assessment: $_examName | Subject: ${widget.subject['subject_name']} ($_subjectCode)',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      'Branch: ${widget.subject['branch']} | Year & Sem: ${widget.subject['year_sem']} | Section: $_section',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Text(
                  _isSubmitted ? 'SUBMITTED' : 'DRAFT',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _isSubmitted ? PdfColors.green800 : PdfColors.orange800, fontSize: 11),
                ),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0B2356')),
                  children: [
                    _buildPdfHeader('S.No'),
                    _buildPdfHeader('HT No'),
                    _buildPdfHeader('Student Name'),
                    _buildPdfHeader('Exam'),
                    _buildPdfHeader('Assign'),
                    _buildPdfHeader('Activity'),
                    _buildPdfHeader('Total'),
                    _buildPdfHeader('Average'),
                  ],
                ),
                ..._filteredStudents.asMap().entries.map((entry) {
                  final i = entry.key + 1;
                  final s = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : PdfColors.grey100),
                    children: [
                      _buildPdfCell('$i'),
                      _buildPdfCell(s.studentId),
                      _buildPdfCell(s.studentName),
                      _buildPdfCell(s.examController.text.isEmpty ? '-' : s.examController.text),
                      _buildPdfCell(s.assignmentController.text.isEmpty ? '-' : s.assignmentController.text),
                      _buildPdfCell(s.activityController.text.isEmpty ? '-' : s.activityController.text),
                      _buildPdfCell(s.total.toStringAsFixed(1), isBold: true),
                      _buildPdfCell(s.average.toStringAsFixed(2), isBold: true),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: '${_subjectCode}_Sec_${_section}_Marks',
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _buildPdfHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
      ),
    );
  }

  pw.Widget _buildPdfCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? accentRed : Colors.green.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        title: Text(
          'Marks Entry - $_subjectCode (Sec $_section)',
          style: const TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isReadOnly
                  ? accentRed.withOpacity(0.12)
                  : _isSubmitted
                      ? Colors.green.withOpacity(0.12)
                      : accentGold.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _isReadOnly
                  ? 'ENTRY LOCKED (DATE CLOSED)'
                  : _isSubmitted
                      ? 'SUBMITTED'
                      : 'EDITABLE DRAFT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: _isReadOnly
                    ? accentRed
                    : _isSubmitted
                        ? Colors.green.shade800
                        : Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              children: [
                // Top Header Info
                _buildHeaderCard(),
                const SizedBox(height: 10),

                // Live Search and Status Filter Row
                _buildFilterBar(),
                const SizedBox(height: 10),

               // Student Evaluation Table (Dual-Axis Scrollable)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                      : _filteredStudents.isEmpty
                          ? const Center(
                              child: Text(
                                'No students found for this section',
                                style: TextStyle(color: textMuted),
                              ),
                            )
                          : Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 14,
                                      horizontalMargin: 12,
                                      headingRowColor: WidgetStateProperty.all(primaryNavy.withOpacity(0.06)),
                                      columns: const [
                                        DataColumn(label: Text('S.No', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('HT No & Name', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('Exam', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('Assign', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                        DataColumn(label: Text('Average', style: TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12))),
                                      ],
                                      rows: _filteredStudents.asMap().entries.map((entry) {
                                        final index = entry.key + 1;
                                        final student = entry.value;

                                        return DataRow(
                                          cells: [
                                            DataCell(Text('$index', style: const TextStyle(fontSize: 12))),
                                            DataCell(
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(minWidth: 100, maxWidth: 140),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(student.studentId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                    Text(student.studentName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: textMuted)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              _buildMarkField(student.examController),
                                            ),
                                            DataCell(
                                              _buildMarkField(student.assignmentController),
                                            ),
                                            DataCell(
                                              _buildMarkField(student.activityController),
                                            ),
                                            DataCell(
                                              Center(
                                                child: Text(
                                                  student.total.toStringAsFixed(1),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Center(
                                                child: Text(
                                                  student.average.toStringAsFixed(2),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color: student.average >= 12 ? Colors.green.shade800 : accentRed,
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
                ),
                const SizedBox(height: 12),

                // 4 Action Buttons Bar
                _buildActionButtonsBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkField(TextEditingController controller) {
    return SizedBox(
      width: 65,
      child: TextFormField(
        controller: controller,
        enabled: !_isReadOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          filled: _isReadOnly,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [darkNavy, primaryNavy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _examName,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.subject['subject_name']} ($_subjectCode) • ${widget.subject['branch']} | ${widget.subject['year_sem']} | Section $_section',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'End Date: ${widget.assessmentWindow['last_date']}',
                style: const TextStyle(fontSize: 12, color: accentGold, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                '${_allStudents.length} Students Allocated',
                style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  hintText: 'Filter by Hallticket, Student Name, or Roll No...',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Students', style: TextStyle(fontSize: 12.5))),
                DropdownMenuItem(value: 'COMPLETED', child: Text('Marks Completed', style: TextStyle(fontSize: 12.5))),
                DropdownMenuItem(value: 'PENDING', child: Text('Pending Marks', style: TextStyle(fontSize: 12.5))),
              ],
              onChanged: (val) {
                setState(() => _statusFilter = val!);
                _applyFilters();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtonsBar() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. SAVE DRAFT
            ElevatedButton.icon(
              onPressed: (_isReadOnly || _isSaving) ? null : () => _handleSave(),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Draft'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
            ),

            // 2. PRINT / EXPORT
            OutlinedButton.icon(
              onPressed: _handlePrint,
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print / Export'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryNavy,
                side: const BorderSide(color: primaryNavy),
              ),
            ),

            // 3. SUBMIT MARKS
            ElevatedButton.icon(
              onPressed: (_isReadOnly || _isSaving) ? null : _handleSubmit,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: Text(_isSubmitted ? 'Re-Submit' : 'Submit Final Marks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
            ),

            // 4. RESET
            TextButton.icon(
              onPressed: (_isReadOnly || _isSaving) ? null : _handleReset,
              icon: const Icon(Icons.restart_alt, size: 18, color: accentRed),
              label: const Text('Reset', style: TextStyle(color: accentRed)),
            ),
          ],
        ),
      ),
    );
  }
}