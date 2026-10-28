import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import '../../main.dart';

class AddSubjectView extends StatefulWidget {
  final VoidCallback onSubjectAdded;

  const AddSubjectView({super.key, required this.onSubjectAdded});

  @override
  State<AddSubjectView> createState() => _AddSubjectViewState();
}

class _AddSubjectViewState extends State<AddSubjectView> {
  int _entryMode = 0; // 0: Single Subject Entry, 1: Excel Import
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _creditsController = TextEditingController(text: '3.0');

  bool _isLoading = false;
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
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

  final List<String> _subjectTypes = [
    'Theory',
    'Laboratory',
    'Elective',
    'Seminar / Project',
  ];

  List<String> _branches = [];
  List<Map<String, dynamic>> _faculties = [];

  String? _selectedYearSem;
  String? _selectedBranch;
  String _selectedType = 'Theory';

  // Section allocations: maps sectionName ('A', 'B', ...) -> selected Faculty Map or null
  List<String> _availableSections = ['A'];
  final Map<String, Map<String, dynamic>?> _sectionFacultyMap = {'A': null};

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _loadFaculties();
    _selectedYearSem = _semesters.first;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _creditsController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    try {
      final data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final list = (data as List)
          .map((e) => e['branch_code'].toString())
          .toList();
      setState(() {
        _branches = list.isNotEmpty
            ? list
            : ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedBranch = _branches.first;
      });
      await _fetchSectionsForSelection();
    } catch (_) {
      setState(() {
        _branches = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedBranch = _branches.first;
      });
      await _fetchSectionsForSelection();
    }
  }

  Future<void> _loadFaculties() async {
    try {
      final data = await supabase
          .from('faculties')
          .select('faculty_id, name, department')
          .order('name', ascending: true);

      setState(() {
        _faculties = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  // Fetch sections corresponding to selected branch and semester
  Future<void> _fetchSectionsForSelection() async {
    if (_selectedBranch == null || _selectedYearSem == null) return;
    try {
      final data = await supabase
          .from('sections')
          .select('section_name')
          .eq('branch_code', _selectedBranch!)
          .eq('year_sem', _selectedYearSem!)
          .order('section_name', ascending: true);

      final list = (data as List)
          .map((e) => e['section_name'].toString().toUpperCase())
          .toList();

      setState(() {
        _availableSections = list.isNotEmpty ? list : ['A'];
        // Preserve existing assignments or initialize new sections to null
        for (final sec in _availableSections) {
          if (!_sectionFacultyMap.containsKey(sec)) {
            _sectionFacultyMap[sec] = null;
          }
        }
        // Remove sections no longer active for the branch/sem
        _sectionFacultyMap.removeWhere(
          (key, _) => !_availableSections.contains(key),
        );
      });
    } catch (_) {
      setState(() {
        _availableSections = ['A'];
        if (!_sectionFacultyMap.containsKey('A')) {
          _sectionFacultyMap['A'] = null;
        }
      });
    }
  }

  // --- SUBMIT 1: Single Subject across All Sections ---
  Future<void> _handleSaveSubject() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final credits = double.tryParse(_creditsController.text.trim()) ?? 3.0;

      // Prepare an insert row for each section
      List<Map<String, dynamic>> records = [];
      for (final sec in _availableSections) {
        final faculty = _sectionFacultyMap[sec];
        records.add({
          'subject_code': code,
          'subject_name': name,
          'branch': _selectedBranch,
          'year_sem': _selectedYearSem,
          'subject_type': _selectedType,
          'credits': credits,
          'section': sec,
          'incharge_id': faculty?['faculty_id'],
          'incharge_name': faculty?['name'],
        });
      }

      await supabase.from('subjects').upsert(
            records,
            onConflict: 'subject_code,section',
          );

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSnack(
        'Subject registered for ${_availableSections.length} sections (${_availableSections.join(", ")})!',
      );

      _codeController.clear();
      _nameController.clear();
      _creditsController.text = '3.0';
      setState(() {
        for (final s in _availableSections) {
          _sectionFacultyMap[s] = null;
        }
      });
      widget.onSubjectAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to add subject: $e', isError: true);
    }
  }

  // --- SUBMIT 2: Bulk Import via Excel ---
  Future<void> _handleExcelImport() async {
    try {
      // In file_picker ^12.x: Call directly without .platform
      // It returns List<PlatformFile>?
      final List<PlatformFile>? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.isEmpty) return; // User canceled

      final PlatformFile file = result.first;
      setState(() => _isLoading = true);

      // Read file bytes directly using readAsBytes()
      final Uint8List bytes = await file.readAsBytes();
      final excel = xl.Excel.decodeBytes(bytes);
      List<Map<String, dynamic>> records = [];

      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]!.rows;
        if (rows.isEmpty) continue;

        // Assumed headers: SubjectCode, SubjectName, Branch, YearSem, Section, SubjectType, Credits
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final code = row[0]?.value?.toString().trim().toUpperCase() ?? '';
          final name =
              row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
          final branch = row.length > 2
              ? row[2]?.value?.toString().trim().toUpperCase() ?? 'CSE'
              : 'CSE';
          final yearSem = row.length > 3
              ? row[3]?.value?.toString().trim() ?? _semesters.first
              : _semesters.first;
          final section = row.length > 4
              ? row[4]?.value?.toString().trim().toUpperCase() ?? 'A'
              : 'A';
          final type = row.length > 5
              ? row[5]?.value?.toString().trim() ?? 'Theory'
              : 'Theory';
          final credits = row.length > 6
              ? double.tryParse(row[6]?.value?.toString() ?? '3.0') ?? 3.0
              : 3.0;

          if (code.isNotEmpty && name.isNotEmpty) {
            records.add({
              'subject_code': code,
              'subject_name': name,
              'branch': branch,
              'year_sem': yearSem,
              'section': section,
              'subject_type': type,
              'credits': credits,
            });
          }
        }
      }

      if (records.isEmpty) {
        _showSnack('No valid rows found in Excel.', isError: true);
        return;
      }

      await supabase.from('subjects').upsert(
            records,
            onConflict: 'subject_code,section',
          );
      _showSnack('Successfully imported ${records.length} subjects!');
      widget.onSubjectAdded();
    } catch (e) {
      _showSnack('Error parsing Excel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Single Subject Entry'),
                        icon: Icon(Icons.edit_document),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Excel Import'),
                        icon: Icon(Icons.upload_file),
                      ),
                    ],
                    selected: {_entryMode},
                    onSelectionChanged: (set) =>
                        setState(() => _entryMode = set.first),
                  ),
                  const Divider(height: 32),

                  if (_entryMode == 0) _buildSingleForm(),
                  if (_entryMode == 1) _buildExcelView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Subject Specifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Allocate course details and assign faculties individually per section.',
            style: TextStyle(fontSize: 12, color: textMuted),
          ),
          const SizedBox(height: 20),

          // Course Code
          TextFormField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Subject / Course Code *',
              hintText: 'e.g. 20A05401T',
              prefixIcon: Icon(Icons.tag_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Enter subject code'
                : null,
          ),
          const SizedBox(height: 14),

          // Subject Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Subject Name *',
              hintText: 'e.g. Database Management Systems',
              prefixIcon: Icon(Icons.menu_book_outlined),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Enter subject name'
                : null,
          ),
          const SizedBox(height: 14),

          // Branch & Semester Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBranch,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Branch *',
                    prefixIcon: Icon(Icons.account_tree_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _branches
                      .map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedBranch = v);
                    _fetchSectionsForSelection();
                  },
                  validator: (v) => v == null ? 'Select branch' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYearSem,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Year & Sem *',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _semesters
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _selectedYearSem = v);
                    _fetchSectionsForSelection();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Type and Credits Row
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: _selectedType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Course Type',
                    prefixIcon: Icon(Icons.category_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _subjectTypes
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _creditsController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Credits',
                    prefixIcon: Icon(Icons.grade_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (val) {
                    if (val == null || double.tryParse(val) == null) {
                      return 'Enter credits';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ====================================================
          // RESPONSIVE SECTION & FACULTY INCHARGE ALLOCATION MATRIX
          // ====================================================
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryNavy.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Expanded to avoid right overflow
                Row(
                  children: [
                    const Icon(Icons.meeting_room_outlined, color: primaryNavy, size: 18),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Section Allocations',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: primaryNavy,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryNavy.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${_availableSections.length} Active',
                        style: const TextStyle(
                          fontSize: 11,
                          color: primaryNavy,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Responsive Section Rows
                ..._availableSections.map((sec) {
                  final assignedFaculty = _sectionFacultyMap[sec];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      elevation: 1,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: primaryNavy.withOpacity(0.1),
                              child: Text(
                                sec,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryNavy,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('Sec $sec', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<Map<String, dynamic>?>(
                                value: assignedFaculty,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Incharge (Sec $sec)',
                                  hintText: 'Select Faculty',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: const OutlineInputBorder(),
                                  suffixIcon: assignedFaculty != null
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 14),
                                          onPressed: () => setState(() => _sectionFacultyMap[sec] = null),
                                        )
                                      : null,
                                ),
                                items: [
                                  const DropdownMenuItem<Map<String, dynamic>?>(
                                    value: null,
                                    child: Text('None (Pending)', style: TextStyle(color: textMuted, fontSize: 11.5)),
                                  ),
                                  ..._faculties.map((f) => DropdownMenuItem<Map<String, dynamic>?>(
                                        value: f,
                                        child: Text(
                                          '${f['name']} (${f['faculty_id']})',
                                          style: const TextStyle(fontSize: 11.5),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )),
                                ],
                                onChanged: (v) => setState(() => _sectionFacultyMap[sec] = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSaveSubject,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Register for ${_availableSections.length} Section${_availableSections.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: primaryNavy.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 54,
                color: primaryNavy,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select .xlsx / .xls Syllabus File',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryNavy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Columns: SubjectCode, SubjectName, Branch, YearSem, Section, SubjectType, Credits',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleExcelImport,
                icon: const Icon(Icons.file_open),
                label: const Text('Browse Excel File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}