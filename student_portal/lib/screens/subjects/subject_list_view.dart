import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../../main.dart';

class SubjectListView extends StatefulWidget {
  final VoidCallback onAddSubjectPressed;

  const SubjectListView({super.key, required this.onAddSubjectPressed});

  @override
  State<SubjectListView> createState() => _SubjectListViewState();
}

class _SubjectListViewState extends State<SubjectListView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allSubjects = [];
  List<Map<String, dynamic>> _filteredSubjects = [];
  List<Map<String, dynamic>> _faculties = [];
  bool _isLoading = true;

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  // Filter States
  String _selectedBranch = 'ALL';
  String _selectedYearSem = 'ALL';
  String _selectedSection = 'ALL';
  String _selectedType = 'ALL';

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
  final List<String> _sections = ['ALL', 'A', 'B', 'C', 'D'];
  final List<String> _types = ['ALL', 'Theory', 'Laboratory', 'Elective', 'Seminar / Project'];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadFaculties();
    _fetchSubjects();
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
        setState(() {
          _branches = ['ALL', ...list];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFaculties() async {
    try {
      final data = await supabase
          .from('faculties')
          .select('faculty_id, name, department')
          .order('name', ascending: true);
      _faculties = List<Map<String, dynamic>>.from(data);
    } catch (_) {}
  }

  Future<void> _fetchSubjects() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await supabase
          .from('subjects')
          .select('id, subject_code, subject_name, branch, year_sem, section, subject_type, credits, incharge_id, incharge_name')
          .order('subject_code', ascending: true)
          .order('section', ascending: true);

      if (mounted) {
        setState(() {
          _allSubjects = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading subjects: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredSubjects = _allSubjects.where((s) {
        final code = (s['subject_code'] ?? '').toString().toLowerCase();
        final name = (s['subject_name'] ?? '').toString().toLowerCase();
        final incharge = (s['incharge_name'] ?? '').toString().toLowerCase();
        final inchargeId = (s['incharge_id'] ?? '').toString().toLowerCase();
        final branch = (s['branch'] ?? '').toString();
        final yearSem = (s['year_sem'] ?? '').toString();
        final section = (s['section'] ?? 'A').toString().toUpperCase();
        final type = (s['subject_type'] ?? '').toString();

        final matchesQuery = code.contains(query) ||
            name.contains(query) ||
            incharge.contains(query) ||
            inchargeId.contains(query);

        final matchesBranch = _selectedBranch == 'ALL' || branch == _selectedBranch;
        final matchesYearSem = _selectedYearSem == 'ALL' || yearSem == _selectedYearSem;
        final matchesSection = _selectedSection == 'ALL' || section == _selectedSection;
        final matchesType = _selectedType == 'ALL' || type.toLowerCase() == _selectedType.toLowerCase();

        return matchesQuery && matchesBranch && matchesYearSem && matchesSection && matchesType;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedBranch = 'ALL';
      _selectedYearSem = 'ALL';
      _selectedSection = 'ALL';
      _selectedType = 'ALL';
      _searchController.clear();
      _applyFilters();
    });
  }

  // ==========================================
  // EDIT SUBJECT & INCHARGE PER SECTION MODAL
  // ==========================================
  void _showEditSubjectModal(Map<String, dynamic> subject) {
    final nameCtrl = TextEditingController(text: subject['subject_name'] ?? '');
    final creditsCtrl = TextEditingController(text: subject['credits']?.toString() ?? '3.0');
    String branchVal = subject['branch'] ?? 'CSE';
    String yearSemVal = subject['year_sem'] ?? _semesters[1];
    String typeVal = subject['subject_type'] ?? 'Theory';
    String sectionVal = (subject['section'] ?? 'A').toString().toUpperCase();

    String? currentInchargeId = subject['incharge_id'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Edit Subject Details',
                style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Locked Subject Code & Section
                      TextFormField(
                        initialValue: '${subject['subject_code']} (Sec $sectionVal)',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Subject Code (Locked)',
                          fillColor: Color(0xFFEEEEEE),
                          filled: true,
                          prefixIcon: Icon(Icons.lock_outline, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subject Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Subject Name',
                          prefixIcon: Icon(Icons.book_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Branch Dropdown
                      DropdownButtonFormField<String>(
                        value: _branches.contains(branchVal) && branchVal != 'ALL' ? branchVal : 'CSE',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Branch',
                          prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _branches.where((b) => b != 'ALL').map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (v) => setModalState(() => branchVal = v!),
                      ),
                      const SizedBox(height: 12),

                      // Year & Sem Dropdown
                      DropdownButtonFormField<String>(
                        value: _semesters.contains(yearSemVal) && yearSemVal != 'ALL' ? yearSemVal : _semesters[1],
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Year & Sem',
                          prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _semesters.where((s) => s != 'ALL').map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setModalState(() => yearSemVal = v!),
                      ),
                      const SizedBox(height: 12),

                      // Type & Credits Row (Optimized flex & sizing)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _types.contains(typeVal) && typeVal != 'ALL' ? typeVal : 'Theory',
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              items: _types.where((t) => t != 'ALL').map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setModalState(() => typeVal = v!),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: creditsCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Credits',
                                border: OutlineInputBorder(),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Section Incharge Dropdown
                      DropdownButtonFormField<String?>(
                        value: _faculties.any((f) => f['faculty_id'] == currentInchargeId) ? currentInchargeId : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Faculty Incharge',
                          prefixIcon: Icon(Icons.person_pin_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not Assigned (Pending)', style: TextStyle(color: textMuted, fontSize: 12)),
                          ),
                          ..._faculties.map((f) => DropdownMenuItem<String?>(
                                value: f['faculty_id']?.toString(),
                                child: Text('${f['name']} (${f['faculty_id']})', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (v) => setModalState(() => currentInchargeId = v),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  onPressed: () async {
                    String? inchargeName;
                    if (currentInchargeId != null) {
                      final match = _faculties.firstWhere(
                        (f) => f['faculty_id'] == currentInchargeId,
                        orElse: () => {},
                      );
                      inchargeName = match['name'];
                    }

                    try {
                      await supabase.from('subjects').update({
                        'subject_name': nameCtrl.text.trim(),
                        'branch': branchVal,
                        'year_sem': yearSemVal,
                        'subject_type': typeVal,
                        'credits': double.tryParse(creditsCtrl.text.trim()) ?? 3.0,
                        'incharge_id': currentInchargeId,
                        'incharge_name': inchargeName,
                      }).eq('id', subject['id']);

                      if (mounted) {
                        Navigator.pop(context);
                        _showSnack('Subject updated successfully!');
                        _fetchSubjects();
                      }
                    } catch (e) {
                      _showSnack('Update error: $e', isError: true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // DELETE SUBJECT ALLOCATION
  // ==========================================
  void _confirmDelete(String id, String name, String code, String sec) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subject Allocation', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove "$name ($code)" for Section $sec?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await supabase.from('subjects').delete().eq('id', id);
                if (mounted) {
                  Navigator.pop(context);
                  _showSnack('Subject section removed');
                  _fetchSubjects();
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
  // EXPORT TO EXCEL
  // ==========================================
  Future<void> _exportExcel() async {
    if (_filteredSubjects.isEmpty) return;
    final excel = xl.Excel.createExcel();
    final sheet = excel['Subjects_Directory'];
    excel.setDefaultSheet('Subjects_Directory');

    sheet.appendRow([
      xl.TextCellValue('S.No'),
      xl.TextCellValue('Course Code'),
      xl.TextCellValue('Subject Name'),
      xl.TextCellValue('Branch'),
      xl.TextCellValue('Year & Sem'),
      xl.TextCellValue('Section'),
      xl.TextCellValue('Type'),
      xl.TextCellValue('Credits'),
      xl.TextCellValue('Incharge Faculty'),
      xl.TextCellValue('Faculty ID'),
    ]);

    for (int i = 0; i < _filteredSubjects.length; i++) {
      final s = _filteredSubjects[i];
      sheet.appendRow([
        xl.IntCellValue(i + 1),
        xl.TextCellValue(s['subject_code'] ?? ''),
        xl.TextCellValue(s['subject_name'] ?? ''),
        xl.TextCellValue(s['branch'] ?? ''),
        xl.TextCellValue(s['year_sem'] ?? ''),
        xl.TextCellValue(s['section'] ?? 'A'),
        xl.TextCellValue(s['subject_type'] ?? ''),
        xl.DoubleCellValue((s['credits'] as num?)?.toDouble() ?? 3.0),
        xl.TextCellValue(s['incharge_name'] ?? 'Not Assigned'),
        xl.TextCellValue(s['incharge_id'] ?? 'N/A'),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'MTIET_Subjects_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  // ==========================================
  // EXPORT TO PDF
  // ==========================================
  Future<void> _exportPdf() async {
    if (_filteredSubjects.isEmpty) return;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MOTHER THERESA INSTITUTE OF ENGINEERING & TECHNOLOGY',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('0B2356')),
              ),
              pw.Text('Curriculum Syllabus & Section Faculty Allocations', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
              pw.SizedBox(height: 8),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('0B2356')),
                    children: [
                      _pdfCell('Code', isHeader: true),
                      _pdfCell('Subject Name', isHeader: true),
                      _pdfCell('Branch', isHeader: true),
                      _pdfCell('Year & Sem', isHeader: true),
                      _pdfCell('Sec', isHeader: true),
                      _pdfCell('Type', isHeader: true),
                      _pdfCell('Credits', isHeader: true),
                      _pdfCell('Faculty Incharge', isHeader: true),
                    ],
                  ),
                  ..._filteredSubjects.map((s) => pw.TableRow(
                    children: [
                      _pdfCell(s['subject_code'] ?? ''),
                      _pdfCell(s['subject_name'] ?? ''),
                      _pdfCell(s['branch'] ?? ''),
                      _pdfCell(s['year_sem'] ?? ''),
                      _pdfCell(s['section'] ?? 'A'),
                      _pdfCell(s['subject_type'] ?? ''),
                      _pdfCell(s['credits']?.toString() ?? '3.0'),
                      _pdfCell(s['incharge_name'] != null ? '${s['incharge_name']} (${s['incharge_id']})' : 'Not Assigned'),
                    ],
                  )),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search & Export Header
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: primaryNavy),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by Code, Subject Name, or Incharge...',
                            border: InputBorder.none,
                          ),
                        ),
                      ),
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
                ),
              ),
              const SizedBox(height: 8),

              // Filter Chips / Dropdowns
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedBranch,
                      items: _branches.map((b) => DropdownMenuItem(value: b, child: Text('Branch: $b'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedBranch = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: _selectedYearSem,
                      items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text('Sem: $s'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedYearSem = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 14),
                    // Section Filter
                    DropdownButton<String>(
                      value: _selectedSection,
                      items: _sections.map((sec) => DropdownMenuItem(value: sec, child: Text(sec == 'ALL' ? 'Section: ALL' : 'Section: $sec'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedSection = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: _selectedType,
                      items: _types.map((t) => DropdownMenuItem(value: t, child: Text('Type: $t'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedType = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 14),
                    TextButton(onPressed: _resetFilters, child: const Text('Reset Filters')),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Subject Row List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                    : _filteredSubjects.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.menu_book_outlined, size: 54, color: textMuted),
                                const SizedBox(height: 10),
                                const Text('No subjects match the selected filters', style: TextStyle(color: textMuted)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: widget.onAddSubjectPressed,
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
                                  child: const Text('Add Subject Now', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredSubjects.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _filteredSubjects[index];
                              final hasIncharge = item['incharge_name'] != null && item['incharge_name'].toString().isNotEmpty;
                              final sec = (item['section'] ?? 'A').toString().toUpperCase();

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryNavy.withOpacity(0.1),
                                    child: Text(
                                      '${item['credits'] ?? 3}C',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 12),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['subject_name'] ?? '',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                                        ),
                                      ),
                                      // Section Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: primaryNavy.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${item['branch']} - Sec $sec',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryNavy),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Code: ${item['subject_code']} | ${item['year_sem']} | Type: ${item['subject_type']}',
                                          style: const TextStyle(fontSize: 12, color: textMuted),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              hasIncharge ? Icons.person_pin : Icons.person_outline,
                                              size: 14,
                                              color: hasIncharge ? Colors.green.shade700 : textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              hasIncharge
                                                  ? 'Incharge: ${item['incharge_name']} (${item['incharge_id']})'
                                                  : 'Incharge: Not Assigned',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: hasIncharge ? FontWeight.bold : FontWeight.normal,
                                                color: hasIncharge ? Colors.green.shade800 : textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: primaryNavy, size: 20),
                                        tooltip: 'Edit Section Allocation',
                                        onPressed: () => _showEditSubjectModal(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: accentRed, size: 20),
                                        tooltip: 'Remove Section Subject',
                                        onPressed: () => _confirmDelete(item['id'], item['subject_name'], item['subject_code'], sec),
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