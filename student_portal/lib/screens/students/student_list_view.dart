import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../../main.dart';

class StudentListView extends StatefulWidget {
  final VoidCallback onAddStudentPressed;

  const StudentListView({super.key, required this.onAddStudentPressed});

  @override
  State<StudentListView> createState() => _StudentListViewState();
}

class _StudentListViewState extends State<StudentListView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  bool _isLoading = true;

  // Branding Palette
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  // Filter States
  String _selectedBranch = 'ALL';
  String _selectedYearSem = 'ALL';
  String _selectedSection = 'ALL';
  String _selectedGender = 'ALL';
  String _selectedPhoneFilter = 'ALL'; // 'ALL', 'WITH_PHONE', 'WITHOUT_PHONE'

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
  final List<String> _genders = ['ALL', 'Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchStudents();
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

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await supabase
          .from('users')
          .select('id, user_id, name, roll_no, year_sem, branch, section, email, gender, phone_no, role, created_at')
          .eq('role', 'student')
          .order('user_id', ascending: true);

      if (mounted) {
        setState(() {
          _allStudents = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error loading students: $e', isError: true);
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final id = (student['user_id'] ?? '').toString().toLowerCase();
        final name = (student['name'] ?? '').toString().toLowerCase();
        final email = (student['email'] ?? '').toString().toLowerCase();
        final branch = (student['branch'] ?? '').toString();
        final yearSem = (student['year_sem'] ?? '').toString();
        final section = (student['section'] ?? 'A').toString().toUpperCase();
        final gender = (student['gender'] ?? '').toString();
        final phone = (student['phone_no'] ?? '').toString().trim();

        // 1. Text Search (Matches Hallticket, Name, or Email)
        final matchesQuery = id.contains(query) || name.contains(query) || email.contains(query);

        // 2. Branch Filter
        final matchesBranch = _selectedBranch == 'ALL' || branch == _selectedBranch;

        // 3. Year & Semester Filter
        final matchesYearSem = _selectedYearSem == 'ALL' || yearSem == _selectedYearSem;

        // 4. Section Filter
        final matchesSection = _selectedSection == 'ALL' || section == _selectedSection;

        // 5. Gender Filter
        final matchesGender = _selectedGender == 'ALL' || gender.toLowerCase() == _selectedGender.toLowerCase();

        // 6. Phone Status Filter
        bool matchesPhone = true;
        if (_selectedPhoneFilter == 'WITH_PHONE') {
          matchesPhone = phone.isNotEmpty;
        } else if (_selectedPhoneFilter == 'WITHOUT_PHONE') {
          matchesPhone = phone.isEmpty;
        }

        return matchesQuery && matchesBranch && matchesYearSem && matchesSection && matchesGender && matchesPhone;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedBranch = 'ALL';
      _selectedYearSem = 'ALL';
      _selectedSection = 'ALL';
      _selectedGender = 'ALL';
      _selectedPhoneFilter = 'ALL';
      _searchController.clear();
      _applyFilters();
    });
  }

  // ==========================================
  // EDIT STUDENT MODAL (Section Editable)
  // ==========================================
  void _showEditStudentModal(Map<String, dynamic> student) {
    final nameCtrl = TextEditingController(text: student['name'] ?? '');
    final emailCtrl = TextEditingController(text: student['email'] ?? '');
    final phoneCtrl = TextEditingController(text: student['phone_no'] ?? '');

    String branchVal = (student['branch'] != null && _branches.contains(student['branch']))
        ? student['branch']
        : (_branches.length > 1 ? _branches[1] : 'CSE');

    String yearSemVal = (student['year_sem'] != null && _semesters.contains(student['year_sem']))
        ? student['year_sem']
        : _semesters[1];

    String genderVal = (student['gender'] != null && _genders.contains(student['gender']))
        ? student['gender']
        : 'Male';

    String sectionVal = (student['section'] ?? 'A').toString().toUpperCase();
    List<String> dynamicSections = [sectionVal];

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        bool isLoadingSections = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> fetchModalSections(String br, String ys) async {
              setModalState(() => isLoadingSections = true);
              try {
                final data = await supabase
                    .from('sections')
                    .select('section_name')
                    .eq('branch_code', br)
                    .eq('year_sem', ys)
                    .order('section_name', ascending: true);

                final list = (data as List).map((e) => e['section_name'].toString().toUpperCase()).toList();
                setModalState(() {
                  dynamicSections = list.isNotEmpty ? list : ['A'];
                  if (!dynamicSections.contains(sectionVal)) {
                    sectionVal = dynamicSections.first;
                  }
                  isLoadingSections = false;
                });
              } catch (_) {
                setModalState(() {
                  dynamicSections = ['A', 'B', 'C'];
                  isLoadingSections = false;
                });
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.edit_note, color: primaryNavy, size: 28),
                  SizedBox(width: 8),
                  Text('Edit Student Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryNavy)),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hallticket Number is LOCKED / READ-ONLY
                      TextFormField(
                        initialValue: student['user_id'] ?? '',
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Hallticket Number (Locked)',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          fillColor: Colors.grey.shade200,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Name
                      TextFormField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Full Name *',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name cannot be empty' : null,
                      ),
                      const SizedBox(height: 12),

                      // Email
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address *',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Branch Dropdown
                      DropdownButtonFormField<String>(
                        value: branchVal,
                        decoration: InputDecoration(
                          labelText: 'Branch',
                          prefixIcon: const Icon(Icons.account_tree_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _branches
                            .where((b) => b != 'ALL')
                            .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => branchVal = v);
                          fetchModalSections(branchVal, yearSemVal);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Year & Semester Dropdown
                      DropdownButtonFormField<String>(
                        value: yearSemVal,
                        decoration: InputDecoration(
                          labelText: 'Year & Sem',
                          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: _semesters
                            .where((s) => s != 'ALL')
                            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setModalState(() => yearSemVal = v);
                          fetchModalSections(branchVal, yearSemVal);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Section & Gender Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: isLoadingSections
                                ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                                : DropdownButtonFormField<String>(
                                    value: dynamicSections.contains(sectionVal) ? sectionVal : dynamicSections.first,
                                    decoration: InputDecoration(
                                      labelText: 'Section *',
                                      prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    items: dynamicSections
                                        .map((sec) => DropdownMenuItem(value: sec, child: Text('Sec $sec')))
                                        .toList(),
                                    onChanged: (v) => setModalState(() => sectionVal = v ?? 'A'),
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: genderVal,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: const Icon(Icons.transgender_outlined, size: 20),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              items: _genders
                                  .where((g) => g != 'ALL')
                                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setModalState(() => genderVal = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Phone Number (Optional)
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number (Optional)',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: textMuted)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setModalState(() => isSaving = true);

                          try {
                            await supabase.from('users').update({
                              'name': nameCtrl.text.trim(),
                              'email': emailCtrl.text.trim().toLowerCase(),
                              'branch': branchVal,
                              'year_sem': yearSemVal,
                              'section': sectionVal,
                              'gender': genderVal,
                              'phone_no': phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                            }).eq('user_id', student['user_id']);

                            if (mounted) {
                              Navigator.pop(context);
                              _showSnack('Student profile updated successfully!');
                              _fetchStudents();
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            _showSnack('Update failed: $e', isError: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
                  child: isSaving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // EXPORT 1: Excel (.xlsx) Generation
  // ==========================================
  Future<void> _exportToExcel() async {
    if (_filteredStudents.isEmpty) {
      _showSnack('No students to export', isError: true);
      return;
    }

    try {
      final excel = xl.Excel.createExcel();
      const sheetName = 'Students_Directory';
      final sheet = excel[sheetName];
      excel.setDefaultSheet(sheetName);

      final xl.CellStyle headerStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#0B2356'),
        fontColorHex: xl.ExcelColor.white,
        horizontalAlign: xl.HorizontalAlign.Center,
      );

      final List<String> headers = [
        'S.No',
        'Hallticket Number',
        'Full Name',
        'Roll No',
        'Branch',
        'Section',
        'Year & Sem',
        'Gender',
        'Email',
        'Phone Number',
      ];

      sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

      for (int col = 0; col < headers.length; col++) {
        final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = headerStyle;
      }

      for (int i = 0; i < _filteredStudents.length; i++) {
        final s = _filteredStudents[i];
        sheet.appendRow([
          xl.IntCellValue(i + 1),
          xl.TextCellValue(s['user_id']?.toString() ?? ''),
          xl.TextCellValue(s['name']?.toString() ?? ''),
          xl.TextCellValue(s['roll_no']?.toString() ?? ''),
          xl.TextCellValue(s['branch']?.toString() ?? ''),
          xl.TextCellValue(s['section']?.toString() ?? 'A'),
          xl.TextCellValue(s['year_sem']?.toString() ?? ''),
          xl.TextCellValue(s['gender']?.toString() ?? ''),
          xl.TextCellValue(s['email']?.toString() ?? ''),
          xl.TextCellValue(s['phone_no']?.toString() ?? 'N/A'),
        ]);
      }

      final List<int>? fileBytes = excel.save();
      if (fileBytes == null) {
        _showSnack('Failed to generate Excel file', isError: true);
        return;
      }

      final String fileName = 'MTIET_Students_${DateTime.now().millisecondsSinceEpoch}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: Uint8List.fromList(fileBytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      _showSnack('Excel sheet downloaded successfully!');
    } catch (e) {
      _showSnack('Error exporting Excel: $e', isError: true);
    }
  }

  // ==========================================
  // EXPORT 2: Professional PDF Report Generation
  // ==========================================
  Future<void> _exportToPdf() async {
    if (_filteredStudents.isEmpty) {
      _showSnack('No students to export', isError: true);
      return;
    }

    try {
      final pdf = pw.Document();
      const int rowsPerPage = 20;
      final int totalPages = (_filteredStudents.length / rowsPerPage).ceil();

      for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
        final int start = pageIndex * rowsPerPage;
        final int end = (start + rowsPerPage < _filteredStudents.length)
            ? start + rowsPerPage
            : _filteredStudents.length;
        final List<Map<String, dynamic>> pageData = _filteredStudents.sublist(start, end);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
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
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Student Enrollment & Profile Directory Report',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Page ${pageIndex + 1} of $totalPages',
                        style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
                  pw.SizedBox(height: 8),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                    columnWidths: const {
                      0: pw.FlexColumnWidth(1.0), // S.No
                      1: pw.FlexColumnWidth(2.6), // Hallticket
                      2: pw.FlexColumnWidth(3.8), // Name
                      3: pw.FlexColumnWidth(1.6), // Branch
                      4: pw.FlexColumnWidth(1.4), // Section
                      5: pw.FlexColumnWidth(2.6), // Year & Sem
                      6: pw.FlexColumnWidth(1.6), // Gender
                      7: pw.FlexColumnWidth(4.2), // Email
                      8: pw.FlexColumnWidth(2.4), // Phone
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('0B2356')),
                        children: [
                          _buildPdfCell('S.No', isHeader: true),
                          _buildPdfCell('Hallticket', isHeader: true),
                          _buildPdfCell('Full Name', isHeader: true),
                          _buildPdfCell('Branch', isHeader: true),
                          _buildPdfCell('Sec', isHeader: true),
                          _buildPdfCell('Year & Sem', isHeader: true),
                          _buildPdfCell('Gender', isHeader: true),
                          _buildPdfCell('Email', isHeader: true),
                          _buildPdfCell('Phone', isHeader: true),
                        ],
                      ),
                      ...pageData.asMap().entries.map((entry) {
                        final int serial = start + entry.key + 1;
                        final student = entry.value;
                        final isEven = entry.key % 2 == 0;

                        return pw.TableRow(
                          decoration: pw.BoxDecoration(
                            color: isEven ? PdfColors.white : PdfColors.grey100,
                          ),
                          children: [
                            _buildPdfCell('$serial'),
                            _buildPdfCell(student['user_id']?.toString() ?? ''),
                            _buildPdfCell(student['name']?.toString() ?? ''),
                            _buildPdfCell(student['branch']?.toString() ?? ''),
                            _buildPdfCell(student['section']?.toString() ?? 'A'),
                            _buildPdfCell(student['year_sem']?.toString() ?? ''),
                            _buildPdfCell(student['gender']?.toString() ?? ''),
                            _buildPdfCell(student['email']?.toString() ?? ''),
                            _buildPdfCell(student['phone_no']?.toString() ?? 'N/A'),
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
      }

      await Printing.layoutPdf(
        name: 'MTIET_Students_Report_${DateTime.now().millisecondsSinceEpoch}',
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      _showSnack('Error generating PDF report: $e', isError: true);
    }
  }

  pw.Widget _buildPdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4.5),
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

  // ==========================================
  // FILTER MODAL SHEET
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
                        const Text('Filter Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryNavy)),
                        TextButton(
                          onPressed: () {
                            _resetFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Reset All', style: TextStyle(color: accentRed)),
                        ),
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
                          onSelected: (sel) {
                            setSheetState(() => _selectedBranch = b);
                            setState(() => _selectedBranch = b);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Section Filter
                    const Text('Class Section', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _sections.map((sec) {
                        final isSel = _selectedSection == sec;
                        return ChoiceChip(
                          label: Text(sec == 'ALL' ? 'All Sections' : 'Section $sec'),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (sel) {
                            setSheetState(() => _selectedSection = sec);
                            setState(() => _selectedSection = sec);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Year & Semester Filter
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
                    const SizedBox(height: 14),

                    // Gender Filter
                    const Text('Gender', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: _genders.map((g) {
                        final isSel = _selectedGender == g;
                        return ChoiceChip(
                          label: Text(g),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (sel) {
                            setSheetState(() => _selectedGender = g);
                            setState(() => _selectedGender = g);
                            _applyFilters();
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Phone Status Filter
                    const Text('Phone Number Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textMuted)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        {'label': 'All Records', 'val': 'ALL'},
                        {'label': 'Phone Given', 'val': 'WITH_PHONE'},
                        {'label': 'Missing Phone', 'val': 'WITHOUT_PHONE'},
                      ].map((item) {
                        final isSel = _selectedPhoneFilter == item['val'];
                        return ChoiceChip(
                          label: Text(item['label'] as String),
                          selected: isSel,
                          selectedColor: primaryNavy,
                          labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black, fontSize: 12),
                          onSelected: (sel) {
                            setSheetState(() => _selectedPhoneFilter = item['val'] as String);
                            setState(() => _selectedPhoneFilter = item['val'] as String);
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
                        child: Text('Apply (${_filteredStudents.length} Results)'),
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
    final bool hasActiveFilters = _selectedBranch != 'ALL' ||
        _selectedYearSem != 'ALL' ||
        _selectedSection != 'ALL' ||
        _selectedGender != 'ALL' ||
        _selectedPhoneFilter != 'ALL';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search, Filter Trigger & Export Bar
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
                            hintText: 'Search Hallticket, Name, Email...',
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
                        tooltip: 'Filter Students',
                        onPressed: _openFilterBottomSheet,
                      ),
                      IconButton(
                        icon: const Icon(Icons.table_view_outlined, color: Colors.green),
                        tooltip: 'Export Excel (.xlsx)',
                        onPressed: _exportToExcel,
                      ),
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined, color: accentRed),
                        tooltip: 'Export PDF',
                        onPressed: _exportToPdf,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Status Banner & Refresh
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredStudents.length} Students Listed',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textMuted, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: primaryNavy, size: 20),
                    onPressed: _fetchStudents,
                    tooltip: 'Refresh list',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Student List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.person_search_outlined, size: 60, color: textMuted),
                                const SizedBox(height: 12),
                                const Text('No students match the current filters', style: TextStyle(color: textMuted, fontSize: 15)),
                                const SizedBox(height: 8),
                                TextButton(onPressed: _resetFilters, child: const Text('Reset All Filters')),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredStudents.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final hasPhone = (student['phone_no'] ?? '').toString().trim().isNotEmpty;

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: primaryNavy.withOpacity(0.1),
                                    child: Text(
                                      (student['roll_no'] ?? 'S').toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          student['name'] ?? 'Unnamed Student',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy, fontSize: 15),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryNavy.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${student['branch'] ?? ''} - Sec ${student['section'] ?? 'A'}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryNavy),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'HT: ${student['user_id']} | ${student['year_sem'] ?? 'Year N/A'} | ${student['email'] ?? 'No email'}\nPhone: ${hasPhone ? student['phone_no'] : 'Not Provided'}',
                                      style: const TextStyle(fontSize: 12, color: textMuted, height: 1.3),
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: primaryNavy),
                                    tooltip: 'Edit Student Details',
                                    onPressed: () => _showEditStudentModal(student),
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