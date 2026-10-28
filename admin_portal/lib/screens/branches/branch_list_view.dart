import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import '../../main.dart';

class BranchListView extends StatefulWidget {
  final VoidCallback onAddBranchPressed;

  const BranchListView({super.key, required this.onAddBranchPressed});

  @override
  State<BranchListView> createState() => _BranchListViewState();
}

class _BranchListViewState extends State<BranchListView> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allBranches = [];
  List<Map<String, dynamic>> _filteredBranches = [];
  bool _isLoading = true;

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _fetchBranches();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBranches() async {
    setState(() => _isLoading = true);
    try {
      final List<dynamic> data = await supabase
          .from('branches')
          .select()
          .order('branch_code', ascending: true);

      setState(() {
        _allBranches = List<Map<String, dynamic>>.from(data);
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching branches: $e'), backgroundColor: accentRed),
        );
      }
    }
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _filteredBranches = _allBranches.where((b) {
        final code = (b['branch_code'] ?? '').toString().toLowerCase();
        final name = (b['branch_name'] ?? '').toString().toLowerCase();
        final hod = (b['hod_name'] ?? '').toString().toLowerCase();

        return code.contains(query) || name.contains(query) || hod.contains(query);
      }).toList();
    });
  }

  // --- EDIT BRANCH MODAL ---
  void _showEditBranchModal(Map<String, dynamic> branch) {
    final nameCtrl = TextEditingController(text: branch['branch_name'] ?? '');
    final intakeCtrl = TextEditingController(text: branch['intake_capacity']?.toString() ?? '60');
    final hodCtrl = TextEditingController(text: branch['hod_name'] ?? '');
    final yearCtrl = TextEditingController(text: branch['established_year']?.toString() ?? '2008');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Branch Details',
          style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: branch['branch_code'],
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Branch Code (Locked)',
                  fillColor: Color(0xFFEEEEEE),
                  filled: true,
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Branch Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: intakeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Intake Capacity',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: yearCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Est. Year',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: hodCtrl,
                decoration: const InputDecoration(
                  labelText: 'HOD Name (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryNavy,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await supabase.from('branches').update({
                  'branch_name': nameCtrl.text.trim(),
                  'intake_capacity': int.tryParse(intakeCtrl.text.trim()) ?? 60,
                  'established_year': int.tryParse(yearCtrl.text.trim()) ?? 2008,
                  'hod_name': hodCtrl.text.trim().isEmpty ? null : hodCtrl.text.trim(),
                }).eq('id', branch['id']);

                if (mounted) {
                  Navigator.pop(context);
                  _fetchBranches();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update error: $e'), backgroundColor: accentRed),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // --- SAFE DELETE CONFIRMATION ---
  void _confirmDeleteBranch(String id, String code, String name) async {
    // Check if students are linked to this branch before deleting
    final studentCountRes = await supabase
        .from('users')
        .select('id')
        .eq('branch', code);

    final int studentCount = (studentCountRes as List).length;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Branch',
          style: TextStyle(color: accentRed, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "$name ($code)"?'),
            if (studentCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Warning: $studentCount students are currently enrolled under this branch.',
                style: const TextStyle(color: accentRed, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await supabase.from('branches').delete().eq('id', id);
                if (mounted) {
                  Navigator.pop(context);
                  _fetchBranches();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e')),
                );
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
    if (_filteredBranches.isEmpty) return;

    final excel = xl.Excel.createExcel();
    final sheet = excel['Branches_Directory'];
    excel.setDefaultSheet('Branches_Directory');

    sheet.appendRow([
      xl.TextCellValue('S.No'),
      xl.TextCellValue('Branch Code'),
      xl.TextCellValue('Department / Branch Name'),
      xl.TextCellValue('Intake Capacity'),
      xl.TextCellValue('Head of Department (HOD)'),
      xl.TextCellValue('Established Year'),
    ]);

    for (int i = 0; i < _filteredBranches.length; i++) {
      final b = _filteredBranches[i];
      sheet.appendRow([
        xl.IntCellValue(i + 1),
        xl.TextCellValue(b['branch_code'] ?? ''),
        xl.TextCellValue(b['branch_name'] ?? ''),
        xl.IntCellValue((b['intake_capacity'] as num?)?.toInt() ?? 60),
        xl.TextCellValue(b['hod_name'] ?? 'Not Assigned'),
        xl.IntCellValue((b['established_year'] as num?)?.toInt() ?? 2008),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await FileSaver.instance.saveFile(
        name: 'MTIET_Branches_${DateTime.now().millisecondsSinceEpoch}',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
    }
  }

  // Export to PDF
  Future<void> _exportPdf() async {
    if (_filteredBranches.isEmpty) return;
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
            pw.Text('Academic Branches & Departmental Quotas', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Divider(thickness: 1.5, color: PdfColor.fromHex('0B2356')),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('0B2356')),
                  children: [
                    _pdfCell('Code', isHeader: true),
                    _pdfCell('Department Name', isHeader: true),
                    _pdfCell('Intake', isHeader: true),
                    _pdfCell('Head of Department (HOD)', isHeader: true),
                    _pdfCell('Est. Year', isHeader: true),
                  ],
                ),
                ..._filteredBranches.map((b) => pw.TableRow(
                  children: [
                    _pdfCell(b['branch_code'] ?? ''),
                    _pdfCell(b['branch_name'] ?? ''),
                    _pdfCell('${b['intake_capacity'] ?? 60} Seats'),
                    _pdfCell(b['hod_name'] ?? 'Not Assigned'),
                    _pdfCell('${b['established_year'] ?? 2008}'),
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
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
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
                            hintText: 'Search by Code, Branch Name, or HOD...',
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredBranches.length} Branches Registered',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: textMuted, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: primaryNavy, size: 20),
                    onPressed: _fetchBranches,
                    tooltip: 'Refresh list',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Branch Cards Grid/List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                    : _filteredBranches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_tree_outlined, size: 54, color: textMuted),
                                const SizedBox(height: 10),
                                const Text('No branches found', style: TextStyle(color: textMuted)),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: widget.onAddBranchPressed,
                                  style: ElevatedButton.styleFrom(backgroundColor: primaryNavy),
                                  child: const Text('Add Branch', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _filteredBranches.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _filteredBranches[index];
                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: primaryNavy.withOpacity(0.1),
                                    child: Text(
                                      item['branch_code'] ?? 'BR',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryNavy,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item['branch_name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                                  ),
                                  subtitle: Text(
                                    'Intake: ${item['intake_capacity'] ?? 60} Seats | Est: ${item['established_year'] ?? 2008}\nHOD: ${item['hod_name'] ?? 'Not Assigned'}',
                                    style: const TextStyle(fontSize: 12, color: textMuted),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: primaryNavy, size: 20),
                                        onPressed: () => _showEditBranchModal(item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: accentRed, size: 20),
                                        onPressed: () => _confirmDeleteBranch(
                                          item['id'],
                                          item['branch_code'],
                                          item['branch_name'],
                                        ),
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
