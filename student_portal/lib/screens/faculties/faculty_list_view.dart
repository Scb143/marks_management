import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../../main.dart';

class FacultyListView extends StatefulWidget {
  final VoidCallback onAddFacultyPressed;

  const FacultyListView({super.key, required this.onAddFacultyPressed});

  @override
  State<FacultyListView> createState() => _FacultyListViewState();
}

class _FacultyListViewState extends State<FacultyListView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFaculties = [];
  List<Map<String, dynamic>> _filteredFaculties = [];
  bool _isLoading = true;

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  String _selectedDept = 'ALL';
  String _selectedDesignation = 'ALL';

  final List<String> _departments = ['ALL', 'CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
  final List<String> _designations = [
    'ALL',
    'Professor & HOD',
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Lab Technician',
  ];

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFaculties() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await supabase
          .from('faculties')
          .select()
          .order('faculty_id', ascending: true);

      setState(() {
        _allFaculties = List<Map<String, dynamic>>.from(data);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading faculty: $e'), backgroundColor: accentRed),
        );
      }
    }
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredFaculties = _allFaculties.where((f) {
        final id = (f['faculty_id'] ?? '').toString().toLowerCase();
        final name = (f['name'] ?? '').toString().toLowerCase();
        final email = (f['email'] ?? '').toString().toLowerCase();
        final dept = (f['department'] ?? '').toString();
        final desig = (f['designation'] ?? '').toString();

        final matchesQ = id.contains(q) || name.contains(q) || email.contains(q);
        final matchesDept = _selectedDept == 'ALL' || dept == _selectedDept;
        final matchesDesig = _selectedDesignation == 'ALL' || desig == _selectedDesignation;

        return matchesQ && matchesDept && matchesDesig;
      }).toList();
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedDept = 'ALL';
      _selectedDesignation = 'ALL';
      _searchController.clear();
      _applyFilters();
    });
  }

  // ==========================================
  // EDIT FACULTY (Locks Faculty ID)
  // ==========================================
  void _showEditModal(Map<String, dynamic> f) {
    final nameCtrl = TextEditingController(text: f['name'] ?? '');
    final emailCtrl = TextEditingController(text: f['email'] ?? '');
    final phoneCtrl = TextEditingController(text: f['phone_no'] ?? '');
    final qualCtrl = TextEditingController(text: f['qualification'] ?? '');
    final expCtrl = TextEditingController(text: f['experience_years']?.toString() ?? '0.0');

    String deptVal = _departments.contains(f['department']) && f['department'] != 'ALL'
        ? f['department']
        : 'CSE';
    String desigVal = _designations.contains(f['designation']) && f['designation'] != 'ALL'
        ? f['designation']
        : 'Assistant Professor';

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Edit Faculty Profile',
                style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: f['faculty_id'],
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Faculty ID (Locked)',
                        filled: true,
                        fillColor: Color(0xFFEEEEEE),
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: deptVal,
                      decoration: const InputDecoration(
                        labelText: 'Department',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _departments
                          .where((d) => d != 'ALL')
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setModalState(() => deptVal = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: desigVal,
                      decoration: const InputDecoration(
                        labelText: 'Designation',
                        prefixIcon: Icon(Icons.work_outline),
                        border: OutlineInputBorder(),
                      ),
                      items: _designations
                          .where((d) => d != 'ALL')
                          .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setModalState(() => desigVal = v!),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: qualCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Qualification',
                              prefixIcon: Icon(Icons.school_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: expCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Exp (Yrs)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                        prefixIcon: Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryNavy,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setModalState(() => isSaving = true);
                          final facultyId = f['faculty_id'];
                          final updatedName = nameCtrl.text.trim();
                          final updatedEmail = emailCtrl.text.trim().toLowerCase();
                          final updatedPhone = phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim();

                          try {
                            // 1. Update faculties table
                            await supabase.from('faculties').update({
                              'name': updatedName,
                              'email': updatedEmail,
                              'phone_no': updatedPhone,
                              'department': deptVal,
                              'designation': desigVal,
                              'qualification': qualCtrl.text.trim(),
                              'experience_years': double.tryParse(expCtrl.text.trim()) ?? 0.0,
                            }).eq('faculty_id', facultyId);

                            // 2. Sync to users table for login
                            await supabase.from('users').update({
                              'name': updatedName,
                              'email': updatedEmail,
                              'branch': deptVal,
                              'phone_no': updatedPhone,
                            }).eq('user_id', facultyId);

                            // 3. Sync to subjects table if they are incharge
                            await supabase.from('subjects').update({
                              'incharge_name': updatedName,
                            }).eq('incharge_id', facultyId);

                            if (mounted) {
                              Navigator.pop(context);
                              _fetchFaculties();
                            }
                          } catch (e) {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Update failed: $e'), backgroundColor: accentRed),
                            );
                          }
                        },
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
  // DELETE FACULTY (Cascades cleanly)
  // ==========================================
  void _confirmDelete(String facultyId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Faculty', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text('Remove $name ($facultyId) from faculties, portal users, and clear any assigned subject incharge roles?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                // 1. Delete from faculties
                await supabase.from('faculties').delete().eq('faculty_id', facultyId);

                // 2. Delete login account from users
                await supabase.from('users').delete().eq('user_id', facultyId);

                // 3. Clear incharge role in subjects
                await supabase.from('subjects').update({
                  'incharge_id': null,
                  'incharge_name': null,
                }).eq('incharge_id', facultyId);

                if (mounted) {
                  Navigator.pop(context);
                  _fetchFaculties();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete error: $e')));
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Export to Excel
  Future<void> _exportExcel() async {
    if (_filteredFaculties.isEmpty) return;

    final excel = xl.Excel.createExcel();
    final sheet = excel['Faculties_Directory'];
    excel.setDefaultSheet('Faculties_Directory');

    sheet.appendRow([
      xl.TextCellValue('S.No'),
      xl.TextCellValue('Faculty ID'),
      xl.TextCellValue('Name'),
      xl.TextCellValue('Department'),
      xl.TextCellValue('Designation'),
      xl.TextCellValue('Qualification'),
      xl.TextCellValue('Experience (Years)'),
      xl.TextCellValue('Email'),
      xl.TextCellValue('Phone'),
    ]);

    for (int i = 0; i < _filteredFaculties.length; i++) {
      final f = _filteredFaculties[i];
      sheet.appendRow([
        xl.IntCellValue(i + 1),
        xl.TextCellValue(f['faculty_id'] ?? ''),
        xl.TextCellValue(f['name'] ?? ''),
        xl.TextCellValue(f['department'] ?? ''),
        xl.TextCellValue(f['designation'] ?? ''),
        xl.TextCellValue(f['qualification'] ?? ''),
        xl.DoubleCellValue((f['experience_years'] as num?)?.toDouble() ?? 0.0),
        xl.TextCellValue(f['email'] ?? ''),
        xl.TextCellValue(f['phone_no'] ?? 'N/A'),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'MTIET_Faculties_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  // Export to PDF
  Future<void> _exportPdf() async {
    if (_filteredFaculties.isEmpty) return;
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'MOTHER THERESA INSTITUTE OF ENGINEERING & TECHNOLOGY',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColor.fromHex('0B2356')),
            ),
            pw.Text('Faculty & Academic Staff Directory', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0B2356')),
                  children: [
                    _pdfCell('ID', isHeader: true),
                    _pdfCell('Name', isHeader: true),
                    _pdfCell('Dept', isHeader: true),
                    _pdfCell('Designation', isHeader: true),
                    _pdfCell('Qualification', isHeader: true),
                    _pdfCell('Exp (Yrs)', isHeader: true),
                    _pdfCell('Email', isHeader: true),
                    _pdfCell('Phone', isHeader: true),
                  ],
                ),
                ..._filteredFaculties.map((f) => pw.TableRow(
                  children: [
                    _pdfCell(f['faculty_id'] ?? ''),
                    _pdfCell(f['name'] ?? ''),
                    _pdfCell(f['department'] ?? ''),
                    _pdfCell(f['designation'] ?? ''),
                    _pdfCell(f['qualification'] ?? ''),
                    _pdfCell(f['experience_years']?.toString() ?? '0'),
                    _pdfCell(f['email'] ?? ''),
                    _pdfCell(f['phone_no'] ?? 'N/A'),
                  ],
                )),
              ],
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
                            hintText: 'Search by Faculty ID, Name, or Email...',
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

              // Filter Controls
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _selectedDept,
                      items: _departments.map((d) => DropdownMenuItem(value: d, child: Text('Dept: $d'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedDept = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _selectedDesignation,
                      items: _designations.map((d) => DropdownMenuItem(value: d, child: Text('Designation: $d'))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedDesignation = v!);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 16),
                    TextButton(onPressed: _resetFilters, child: const Text('Reset Filters')),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Faculty List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                    : _filteredFaculties.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.groups_outlined, size: 54, color: textMuted),
                                const SizedBox(height: 10),
                                const Text('No faculty records found', style: TextStyle(color: textMuted)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: widget.onAddFacultyPressed,
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
                                  child: const Text('Enroll Faculty', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredFaculties.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final f = _filteredFaculties[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryNavy.withOpacity(0.1),
                                    child: const Icon(Icons.person, color: primaryNavy),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${f['name']} (${f['qualification'] ?? ''})',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryNavy.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          f['department'] ?? '',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryNavy),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    'ID: ${f['faculty_id']} | ${f['designation']} | Exp: ${f['experience_years'] ?? 0} Yrs\nEmail: ${f['email']} | Phone: ${f['phone_no'] ?? 'N/A'}',
                                    style: const TextStyle(fontSize: 12, color: textMuted),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: primaryNavy, size: 20),
                                        onPressed: () => _showEditModal(f),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: accentRed, size: 20),
                                        onPressed: () => _confirmDelete(f['faculty_id'], f['name']),
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