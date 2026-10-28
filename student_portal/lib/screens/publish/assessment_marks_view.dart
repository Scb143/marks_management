import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../../main.dart';
import '../../widgets/watermark_scaffold.dart';

class AssessmentMarksView extends StatefulWidget {
  final Map<String, dynamic>? assessmentWindow;

  const AssessmentMarksView({super.key, this.assessmentWindow});

  @override
  State<AssessmentMarksView> createState() => _AssessmentMarksViewState();
}

class _AssessmentMarksViewState extends State<AssessmentMarksView> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _allWindows = [];
  String? _selectedWindowId;
  Map<String, dynamic>? _selectedWindow;

  // Branch list loaded dynamically from database
  List<String> _branchList = [];
  String _selectedBranch = '';

  List<Map<String, dynamic>> _marksRecords = [];
  List<Map<String, dynamic>> _filteredRecords = [];

  String _selectedSection = 'ALL';
  List<String> _availableSections = ['ALL', 'A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();
    _loadBranchesFromDatabase();
    _initializeData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 1. Fetch branches dynamically from 'branches' table
  Future<void> _loadBranchesFromDatabase() async {
    try {
      final List<dynamic> data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final List<String> loaded = data
          .map((row) => (row['branch_code'] ?? '').toString().trim())
          .where((code) => code.isNotEmpty)
          .toList();

      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _branchList = loaded;
          if (!_branchList.contains(_selectedBranch)) {
            _selectedBranch = _branchList.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _branchList = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
          if (_selectedBranch.isEmpty) {
            _selectedBranch = _branchList.first;
          }
        });
      }
    }
  }

  // 2. Initialize assessment windows
  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> windowsData = await supabase
          .from('assessment_windows')
          .select()
          .order('created_at', ascending: false);

      _allWindows = List<Map<String, dynamic>>.from(windowsData);

      if (widget.assessmentWindow != null) {
        _selectedWindow = widget.assessmentWindow;
        _selectedWindowId = widget.assessmentWindow!['id'].toString();
      } else if (_allWindows.isNotEmpty) {
        _selectedWindow = _allWindows.first;
        _selectedWindowId = _allWindows.first['id'].toString();
      }

      if (_selectedWindow != null) {
        await _fetchMarksForWindow(_selectedWindow!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading assessments: $e', isError: true);
      }
    }
  }

  // 3. Fetch marks from dynamic [branch]_[window_id] table
  Future<void> _fetchMarksForWindow(Map<String, dynamic> window) async {
    setState(() => _isLoading = true);

    final String windowId = window['id'].toString();
    final String windowBranch = (window['branch'] ?? 'ALL').toString();

    // Use selected dropdown branch if the window was published for 'ALL'
    final String targetBranch = (windowBranch == 'ALL')
        ? (_selectedBranch.isNotEmpty
              ? _selectedBranch
              : (_branchList.isNotEmpty ? _branchList.first : 'CSE'))
        : windowBranch;

    // Normalizes "AI & DS" -> "aids", "CSE" -> "cse"
    final String cleanBranch = targetBranch.toLowerCase().replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );
    final String cleanId = windowId.replaceAll('-', '_');
    final String tableName = '${cleanBranch}_$cleanId';

    try {
      final List<dynamic> data = await supabase
          .from(tableName)
          .select()
          .order('student_id', ascending: true);

      final records = List<Map<String, dynamic>>.from(data);

      final Set<String> secs = {'ALL'};
      for (var r in records) {
        if (r['section'] != null && r['section'].toString().isNotEmpty) {
          secs.add(r['section'].toString().toUpperCase());
        }
      }

      if (mounted) {
        setState(() {
          _marksRecords = records;
          _availableSections = secs.toList()..sort();
          _selectedSection = 'ALL';
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _marksRecords = [];
          _filteredRecords = [];
          _isLoading = false;
        });
        _showSnack(
          'Notice: Could not load table "$tableName". Make sure students are registered in $targetBranch for ${window['year_sem']}.',
          isError: true,
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredRecords = _marksRecords.where((row) {
        final id = (row['student_id'] ?? '').toString().toLowerCase();
        final name = (row['student_name'] ?? '').toString().toLowerCase();
        final sec = (row['section'] ?? 'A').toString().toUpperCase();

        final matchesQuery = id.contains(query) || name.contains(query);
        final matchesSec = _selectedSection == 'ALL' || sec == _selectedSection;

        return matchesQuery && matchesSec;
      }).toList();
    });
  }

  // Calculate Student Marks Aggregates
  Map<String, dynamic> _calculateStudentStats(
    Map<String, dynamic> row,
    List<dynamic> configs,
  ) {
    double totalObtained = 0.0;
    double totalMax = 0.0;
    int enteredSubjectsCount = 0;

    for (var cfg in configs) {
      final code = cfg['subject_code'].toString();
      final maxMarks = (cfg['total_marks'] as num?)?.toDouble() ?? 30.0;
      totalMax += maxMarks;

      if (row[code] != null) {
        final val = (row[code] as num).toDouble();
        totalObtained += val;
        enteredSubjectsCount++;
      }
    }

    final double avg = configs.isNotEmpty
        ? (totalObtained / configs.length)
        : 0.0;
    final double percentage = totalMax > 0
        ? ((totalObtained / totalMax) * 100)
        : 0.0;

    return {
      'totalObtained': totalObtained,
      'totalMax': totalMax,
      'avg': avg,
      'percentage': percentage,
      'allEntered': enteredSubjectsCount == configs.length,
    };
  }

  // Export to Excel
  Future<void> _exportExcel() async {
    if (_selectedWindow == null || _filteredRecords.isEmpty) return;

    final configs = (_selectedWindow!['subject_configs'] as List?) ?? [];
    final excel = xl.Excel.createExcel();
    const sheetName = 'Marks_Evaluation';
    final sheet = excel[sheetName];
    excel.setDefaultSheet(sheetName);

    List<xl.CellValue> headers = [
      xl.TextCellValue('S.No'),
      xl.TextCellValue('Hallticket'),
      xl.TextCellValue('Student Name'),
      xl.TextCellValue('Section'),
    ];

    for (var cfg in configs) {
      headers.add(
        xl.TextCellValue('${cfg['subject_code']} (${cfg['total_marks']}M)'),
      );
    }

    headers.addAll([
      xl.TextCellValue('Total Obtained'),
      xl.TextCellValue('Max Marks'),
      xl.TextCellValue('Average'),
      xl.TextCellValue('Percentage (%)'),
    ]);

    sheet.appendRow(headers);

    for (int i = 0; i < _filteredRecords.length; i++) {
      final row = _filteredRecords[i];
      final stats = _calculateStudentStats(row, configs);

      List<xl.CellValue> values = [
        xl.IntCellValue(i + 1),
        xl.TextCellValue(row['student_id']?.toString() ?? ''),
        xl.TextCellValue(row['student_name']?.toString() ?? ''),
        xl.TextCellValue(row['section']?.toString() ?? 'A'),
      ];

      for (var cfg in configs) {
        final code = cfg['subject_code'].toString();
        final val = row[code];
        values.add(
          val != null
              ? xl.DoubleCellValue((val as num).toDouble())
              : xl.TextCellValue('AB / NULL'),
        );
      }

      values.addAll([
        xl.DoubleCellValue(stats['totalObtained']),
        xl.DoubleCellValue(stats['totalMax']),
        xl.DoubleCellValue(double.parse(stats['avg'].toStringAsFixed(2))),
        xl.TextCellValue('${stats['percentage'].toStringAsFixed(1)}%'),
      ]);

      sheet.appendRow(values);
    }

    final bytes = excel.save();
    if (bytes != null) {
      final String activeBranch = (_selectedWindow!['branch'] == 'ALL')
          ? _selectedBranch
          : _selectedWindow!['branch'];
      await FileSaver.instance.saveFile(
        name: '${_selectedWindow!['exam_name']}_${activeBranch}_Marks',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      _showSnack('Excel report downloaded successfully!');
    }
  }

  // Export to Landscape PDF
  Future<void> _exportPdf() async {
    if (_selectedWindow == null || _filteredRecords.isEmpty) return;

    final configs = (_selectedWindow!['subject_configs'] as List?) ?? [];
    final pdf = pw.Document();
    final String activeBranch = (_selectedWindow!['branch'] == 'ALL')
        ? _selectedBranch
        : _selectedWindow!['branch'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MOTHER THERESA INSTITUTE OF ENGINEERING & TECHNOLOGY',
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: PdfColor.fromHex('0B2356'),
                        ),
                      ),
                      pw.Text(
                        'Evaluation Sheet: ${_selectedWindow!['exam_name']} • Branch: $activeBranch (${_selectedWindow!['year_sem']})',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Total Students: ${_filteredRecords.length}',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('0B2356'),
                    ),
                    children: [
                      _pdfCell('HT No', isHeader: true),
                      _pdfCell('Student Name', isHeader: true),
                      _pdfCell('Sec', isHeader: true),
                      ...configs.map(
                        (c) => _pdfCell(
                          '${c['subject_code']}\n(${c['total_marks']}M)',
                          isHeader: true,
                        ),
                      ),
                      _pdfCell('Total', isHeader: true),
                      _pdfCell('Avg', isHeader: true),
                      _pdfCell('%', isHeader: true),
                    ],
                  ),
                  ..._filteredRecords.map((row) {
                    final stats = _calculateStudentStats(row, configs);
                    return pw.TableRow(
                      children: [
                        _pdfCell(row['student_id']?.toString() ?? ''),
                        _pdfCell(row['student_name']?.toString() ?? ''),
                        _pdfCell(row['section']?.toString() ?? 'A'),
                        ...configs.map((c) {
                          final code = c['subject_code'].toString();
                          final val = row[code];
                          return _pdfCell(val != null ? '$val' : '-');
                        }),
                        _pdfCell(
                          '${stats['totalObtained']} / ${stats['totalMax']}',
                        ),
                        _pdfCell(stats['avg'].toStringAsFixed(1)),
                        _pdfCell('${stats['percentage'].toStringAsFixed(1)}%'),
                      ],
                    );
                  }),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: '${_selectedWindow!['exam_name']}_Report',
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
      ),
    );
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
    final configs = (_selectedWindow?['subject_configs'] as List?) ?? [];

    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        title: const Text(
          'Marks Evaluation Directory (Read-Only)',
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
            icon: const Icon(Icons.table_view_outlined, color: Colors.green),
            tooltip: 'Export Excel',
            onPressed: _exportExcel,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: accentRed),
            tooltip: 'Export PDF',
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Top Selection Filters Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final bool isMobile = constraints.maxWidth < 650;

                        return Column(
                          children: [
                            if (isMobile) ...[
                              // Stacked layout for mobile phones
                              DropdownButtonFormField<String>(
                                value: _selectedWindowId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Select Assessment Window',
                                  prefixIcon: Icon(
                                    Icons.fact_check_outlined,
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 10,
                                  ),
                                ),
                                items: _allWindows.map((win) {
                                  return DropdownMenuItem<String>(
                                    value: win['id'].toString(),
                                    child: Text(
                                      '${win['exam_name']} - ${win['branch']} (${win['year_sem']})',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (selectedId) {
                                  if (selectedId == null) return;
                                  final match = _allWindows.firstWhere(
                                    (w) => w['id'].toString() == selectedId,
                                    orElse: () => _allWindows.first,
                                  );
                                  setState(() {
                                    _selectedWindowId = selectedId;
                                    _selectedWindow = match;
                                  });
                                  _fetchMarksForWindow(match);
                                },
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (_selectedWindow != null &&
                                      _selectedWindow!['branch'] == 'ALL') ...[
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value:
                                            _branchList.contains(
                                              _selectedBranch,
                                            )
                                            ? _selectedBranch
                                            : (_branchList.isNotEmpty
                                                  ? _branchList.first
                                                  : null),
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Branch',
                                          prefixIcon: Icon(
                                            Icons.account_tree_outlined,
                                            size: 18,
                                          ),
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 10,
                                          ),
                                        ),
                                        items: _branchList
                                            .map(
                                              (b) => DropdownMenuItem(
                                                value: b,
                                                child: Text(
                                                  b,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (newBranch) {
                                          if (newBranch == null) return;
                                          setState(
                                            () => _selectedBranch = newBranch,
                                          );
                                          _fetchMarksForWindow(
                                            _selectedWindow!,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedSection,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Section',
                                        prefixIcon: Icon(
                                          Icons.meeting_room_outlined,
                                          size: 18,
                                        ),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 10,
                                        ),
                                      ),
                                      items: _availableSections
                                          .map(
                                            (sec) => DropdownMenuItem(
                                              value: sec,
                                              child: Text(
                                                sec == 'ALL'
                                                    ? 'All Secs'
                                                    : 'Sec $sec',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (sec) {
                                        setState(() => _selectedSection = sec!);
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              // Desktop & Tablet Row
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedWindowId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Select Assessment Window',
                                        prefixIcon: Icon(
                                          Icons.fact_check_outlined,
                                        ),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: _allWindows.map((win) {
                                        return DropdownMenuItem<String>(
                                          value: win['id'].toString(),
                                          child: Text(
                                            '${win['exam_name']} - ${win['branch']} (${win['year_sem']})',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (selectedId) {
                                        if (selectedId == null) return;
                                        final match = _allWindows.firstWhere(
                                          (w) =>
                                              w['id'].toString() == selectedId,
                                          orElse: () => _allWindows.first,
                                        );
                                        setState(() {
                                          _selectedWindowId = selectedId;
                                          _selectedWindow = match;
                                        });
                                        _fetchMarksForWindow(match);
                                      },
                                    ),
                                  ),
                                  if (_selectedWindow != null &&
                                      _selectedWindow!['branch'] == 'ALL') ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value:
                                            _branchList.contains(
                                              _selectedBranch,
                                            )
                                            ? _selectedBranch
                                            : (_branchList.isNotEmpty
                                                  ? _branchList.first
                                                  : null),
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Branch',
                                          prefixIcon: Icon(
                                            Icons.account_tree_outlined,
                                          ),
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        items: _branchList
                                            .map(
                                              (b) => DropdownMenuItem(
                                                value: b,
                                                child: Text(
                                                  b,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (newBranch) {
                                          if (newBranch == null) return;
                                          setState(
                                            () => _selectedBranch = newBranch,
                                          );
                                          _fetchMarksForWindow(
                                            _selectedWindow!,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedSection,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Filter Section',
                                        prefixIcon: Icon(
                                          Icons.meeting_room_outlined,
                                        ),
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: _availableSections
                                          .map(
                                            (sec) => DropdownMenuItem(
                                              value: sec,
                                              child: Text(
                                                sec == 'ALL'
                                                    ? 'All Secs'
                                                    : 'Sec $sec',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (sec) {
                                        setState(() => _selectedSection = sec!);
                                        _applyFilters();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Search Field & Count
                            Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 20,
                                  color: primaryNavy,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Search student by Hallticket or Name...',
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_filteredRecords.length} Students',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Evaluation Marks DataTable
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryNavy),
                        )
                      : _filteredRecords.isEmpty
                      ? const Center(
                          child: Text(
                            'No student marks records available for this selection',
                            style: TextStyle(color: textMuted),
                          ),
                        )
                      : Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  primaryNavy.withOpacity(0.08),
                                ),
                                columns: [
                                  const DataColumn(
                                    label: Text(
                                      'HT No',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Student Name',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Sec',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                  ...configs.map(
                                    (c) => DataColumn(
                                      label: Text(
                                        '${c['subject_code']}\n(${c['total_marks']}M)',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryNavy,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Average',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Percentage',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                      ),
                                    ),
                                  ),
                                ],
                                rows: _filteredRecords.map((row) {
                                  final stats = _calculateStudentStats(
                                    row,
                                    configs,
                                  );

                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          row['student_id']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          row['student_name']?.toString() ?? '',
                                        ),
                                      ),
                                      DataCell(
                                        Text(row['section']?.toString() ?? 'A'),
                                      ),
                                      ...configs.map((c) {
                                        final code = c['subject_code']
                                            .toString();
                                        final val = row[code];
                                        return DataCell(
                                          Center(
                                            child: Text(
                                              val != null ? '$val' : 'NULL',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: val != null
                                                    ? Colors.black87
                                                    : accentRed,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                      DataCell(
                                        Text(
                                          '${stats['totalObtained']} / ${stats['totalMax']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryNavy,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(stats['avg'].toStringAsFixed(2)),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: stats['percentage'] >= 40
                                                ? Colors.green.withOpacity(0.1)
                                                : accentRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${stats['percentage'].toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: stats['percentage'] >= 40
                                                  ? Colors.green.shade800
                                                  : accentRed,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
