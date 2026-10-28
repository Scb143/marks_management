import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:bcrypt/bcrypt.dart';
import '../../main.dart';

class AddStudentView extends StatefulWidget {
  final VoidCallback onStudentAdded;

  const AddStudentView({super.key, required this.onStudentAdded});

  @override
  State<AddStudentView> createState() => _AddStudentViewState();
}

class _AddStudentViewState extends State<AddStudentView> {
  int _entryMode = 0; // 0: Single Form, 1: Batch Manual, 2: Excel Upload
  bool _isLoading = false;

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  // Semesters: 1 Year 1 Sem to 4 Year 8 Sem (2 sems per year)
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

  final List<String> _genders = ['Male', 'Female', 'Other'];
  List<String> _branches = [];
  List<String> _availableSections = ['A'];

  // Single Entry Form Controllers
  final _singleFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _htController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedYearSem;
  String? _selectedBranch;
  String? _selectedGender;
  String _selectedSection = 'A';

  // Batch Manual Mode State
  final _batchCountController = TextEditingController(text: '3');
  List<Map<String, dynamic>> _batchStudents = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _htController.addListener(_computeRollNo);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _htController.dispose();
    _rollNoController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _batchCountController.dispose();
    super.dispose();
  }

  // Load branches dynamically from branches table
  Future<void> _loadBranches() async {
    try {
      final data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final list = (data as List).map((e) => e['branch_code'].toString()).toList();
      setState(() {
        _branches = list.isNotEmpty ? list : ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedBranch = _branches.first;
        _selectedYearSem = _semesters.first;
      });
      await _fetchAvailableSections();
    } catch (_) {
      setState(() {
        _branches = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedBranch = _branches.first;
        _selectedYearSem = _semesters.first;
      });
      await _fetchAvailableSections();
    }
  }

  // Fetch sections corresponding to selected branch and semester
  Future<void> _fetchAvailableSections() async {
    if (_selectedBranch == null || _selectedYearSem == null) return;
    try {
      final data = await supabase
          .from('sections')
          .select('section_name')
          .eq('branch_code', _selectedBranch!)
          .eq('year_sem', _selectedYearSem!)
          .order('section_name', ascending: true);

      final list = (data as List).map((e) => e['section_name'].toString()).toList();
      setState(() {
        _availableSections = list.isNotEmpty ? list : ['A'];
        if (!_availableSections.contains(_selectedSection)) {
          _selectedSection = _availableSections.first;
        }
      });
    } catch (_) {
      setState(() {
        _availableSections = ['A'];
        _selectedSection = 'A';
      });
    }
  }

  // Automatically take the last 2 digits of the hall ticket number
  void _computeRollNo() {
    final text = _htController.text.trim();
    if (text.length >= 2) {
      _rollNoController.text = text.substring(text.length - 2);
    } else {
      _rollNoController.text = text;
    }
  }

  // --- SUBMIT 1: Single Student Enrollment ---
  Future<void> _submitSingleStudent() async {
    if (!(_singleFormKey.currentState?.validate() ?? false)) return;

    final htNumber = _htController.text.trim().toUpperCase();
    final String hashedPassword = BCrypt.hashpw(htNumber, BCrypt.gensalt());

    final studentData = {
      'user_id': htNumber,
      'password_hash': hashedPassword,
      'name': _nameController.text.trim(),
      'roll_no': _rollNoController.text.trim(),
      'year_sem': _selectedYearSem,
      'branch': _selectedBranch,
      'section': _selectedSection,
      'email': _emailController.text.trim().toLowerCase(),
      'gender': _selectedGender,
      'phone_no': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'role': 'student',
    };

    setState(() => _isLoading = true);
    try {
      await supabase.from('users').insert(studentData);
      _showSnack('Student enrolled successfully!');
      _resetSingleForm();
      widget.onStudentAdded();
    } catch (e) {
      _showSnack('Error adding student: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetSingleForm() {
    _nameController.clear();
    _htController.clear();
    _rollNoController.clear();
    _emailController.clear();
    _phoneController.clear();
    setState(() {
      _selectedGender = null;
    });
  }

  // --- SUBMIT 2: Batch Manual Rows ---
  void _initializeBatchRows() {
    final count = int.tryParse(_batchCountController.text) ?? 1;
    final validCount = count.clamp(1, 50);

    setState(() {
      _batchStudents = List.generate(
        validCount,
        (i) => {
          'name': TextEditingController(),
          'ht': TextEditingController(),
          'email': TextEditingController(),
          'phone': TextEditingController(),
          'year_sem': _semesters.first,
          'branch': _branches.isNotEmpty ? _branches.first : 'CSE',
          'section': 'A',
          'gender': 'Male',
        },
      );
    });
  }

  Future<void> _submitBatchManual() async {
    List<Map<String, dynamic>> records = [];

    for (var i = 0; i < _batchStudents.length; i++) {
      final row = _batchStudents[i];
      final name = (row['name'] as TextEditingController).text.trim();
      final ht = (row['ht'] as TextEditingController).text.trim().toUpperCase();
      final email = (row['email'] as TextEditingController).text.trim().toLowerCase();
      final phone = (row['phone'] as TextEditingController).text.trim();
      final rollNo = ht.length >= 2 ? ht.substring(ht.length - 2) : ht;

      if (name.isEmpty || ht.isEmpty || email.isEmpty) {
        _showSnack('Row #${i + 1} is missing Name, Hallticket, or Email', isError: true);
        return;
      }

      final String hashedPassword = BCrypt.hashpw(ht, BCrypt.gensalt());

      records.add({
        'user_id': ht,
        'password_hash': hashedPassword,
        'name': name,
        'roll_no': rollNo,
        'year_sem': row['year_sem'],
        'branch': row['branch'],
        'section': row['section'],
        'email': email,
        'gender': row['gender'],
        'phone_no': phone.isEmpty ? null : phone,
        'role': 'student',
      });
    }

    setState(() => _isLoading = true);
    try {
      await supabase.from('users').insert(records);
      _showSnack('Successfully added ${records.length} students!');
      widget.onStudentAdded();
    } catch (e) {
      _showSnack('Batch upload error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- SUBMIT 3: Excel File Upload ---
  Future<void> _pickAndProcessExcel() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result == null || result.isEmpty) return;

      setState(() => _isLoading = true);
      final file = result.first;
      final bytes = await file.readAsBytes();
      final excel = xl.Excel.decodeBytes(Uint8List.fromList(bytes));

      List<Map<String, dynamic>> records = [];

      for (var table in excel.tables.keys) {
        final rows = excel.tables[table]!.rows;
        if (rows.isEmpty) continue;

        // Assumed headers: Name, Hallticket, YearSem, Branch, Section, Email, Gender, Phone
        for (var i = 1; i < rows.length; i++) {
          final row = rows[i];
          if (row.isEmpty || row[0] == null) continue;

          final name = row[0]?.value?.toString().trim() ?? '';
          final ht = row.length > 1 ? row[1]?.value?.toString().trim().toUpperCase() ?? '' : '';
          final yearSem = row.length > 2 ? row[2]?.value?.toString().trim() ?? _semesters.first : _semesters.first;
          final branch = row.length > 3 ? row[3]?.value?.toString().trim().toUpperCase() ?? 'CSE' : 'CSE';
          final section = row.length > 4 ? row[4]?.value?.toString().trim().toUpperCase() ?? 'A' : 'A';
          final email = row.length > 5 ? row[5]?.value?.toString().trim().toLowerCase() ?? '' : '';
          final gender = row.length > 6 ? row[6]?.value?.toString().trim() ?? 'Male' : 'Male';
          final phone = row.length > 7 ? row[7]?.value?.toString().trim() : null;

          if (name.isNotEmpty && ht.isNotEmpty && email.isNotEmpty) {
            final rollNo = ht.length >= 2 ? ht.substring(ht.length - 2) : ht;
            final String hashedPassword = BCrypt.hashpw(ht, BCrypt.gensalt());

            records.add({
              'user_id': ht,
              'password_hash': hashedPassword,
              'name': name,
              'roll_no': rollNo,
              'year_sem': yearSem,
              'branch': branch,
              'section': section,
              'email': email,
              'gender': gender,
              'phone_no': phone,
              'role': 'student',
            });
          }
        }
      }

      if (records.isEmpty) {
        _showSnack('No valid records found. Ensure rows have Name, Hallticket, and Email.', isError: true);
        return;
      }

      await supabase.from('users').insert(records);
      _showSnack('Imported ${records.length} students from Excel file!');
      widget.onStudentAdded();
    } catch (e) {
      _showSnack('Error parsing Excel: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? accentRed : Colors.green.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _entryMode == 1 ? 1200 : 650),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Single Entry'), icon: Icon(Icons.person)),
                      ButtonSegment(value: 1, label: Text('Batch Manual'), icon: Icon(Icons.format_list_numbered)),
                      ButtonSegment(value: 2, label: Text('Excel Upload'), icon: Icon(Icons.upload_file)),
                    ],
                    selected: {_entryMode},
                    onSelectionChanged: (set) {
                      setState(() => _entryMode = set.first);
                      if (_entryMode == 1 && _batchStudents.isEmpty) {
                        _initializeBatchRows();
                      }
                    },
                  ),
                  const Divider(height: 32),

                  if (_entryMode == 0) _buildSingleEntryForm(),
                  if (_entryMode == 1) _buildBatchManualView(),
                  if (_entryMode == 2) _buildExcelUploadView(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- VIEW 1: Single Student Form ---
  Widget _buildSingleEntryForm() {
    return Form(
      key: _singleFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Student Credentials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
          const SizedBox(height: 12),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          const SizedBox(height: 14),

          // Hallticket & Automated Roll Number
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _htController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Hallticket Number *',
                    hintText: 'e.g. 21MT1A0545',
                    prefixIcon: Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Hallticket required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _rollNoController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Roll No (Auto)',
                    helperText: 'Last 2 digits',
                    prefixIcon: const Icon(Icons.tag),
                    fillColor: Colors.grey.shade100,
                    filled: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Branch & Year/Sem Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBranch,
                  decoration: const InputDecoration(labelText: 'Branch *', prefixIcon: Icon(Icons.account_tree_outlined), border: OutlineInputBorder()),
                  items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedBranch = v);
                    _fetchAvailableSections();
                  },
                  validator: (v) => v == null ? 'Branch required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedYearSem,
                  decoration: const InputDecoration(labelText: 'Year & Sem *', prefixIcon: Icon(Icons.calendar_month_outlined), border: OutlineInputBorder()),
                  items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    setState(() => _selectedYearSem = v);
                    _fetchAvailableSections();
                  },
                  validator: (v) => v == null ? 'Select Year and Sem' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Section & Gender Dropdowns
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _availableSections.contains(_selectedSection) ? _selectedSection : null,
                  decoration: const InputDecoration(
                    labelText: 'Class Section *',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: _availableSections
                      .map((sec) => DropdownMenuItem(value: sec, child: Text('Section $sec')))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedSection = v ?? 'A'),
                  validator: (v) => v == null ? 'Select Section' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: 'Gender *', prefixIcon: Icon(Icons.transgender_outlined), border: OutlineInputBorder()),
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (v) => setState(() => _selectedGender = v),
                  validator: (v) => v == null ? 'Select Gender' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email Address *', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
            validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Valid email required' : null,
          ),
          const SizedBox(height: 14),

          // Phone (Optional)
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number (Optional)', prefixIcon: Icon(Icons.phone_outlined), border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryNavy.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: primaryNavy),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'User ID and initial Password are set to the Hallticket Number (BCrypt hashed in database).',
                    style: TextStyle(fontSize: 12, color: primaryNavy, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSubmitButton('Enroll Student', _submitSingleStudent),
        ],
      ),
    );
  }

  // --- VIEW 2: Batch Manual View ---
  Widget _buildBatchManualView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Enter number of students: ', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(
              width: 70,
              height: 40,
              child: TextField(
                controller: _batchCountController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _initializeBatchRows,
              style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
              child: const Text('Generate Rows'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Full Name *')),
              DataColumn(label: Text('Hallticket *')),
              DataColumn(label: Text('Branch')),
              DataColumn(label: Text('Year & Sem')),
              DataColumn(label: Text('Section')),
              DataColumn(label: Text('Gender')),
              DataColumn(label: Text('Email *')),
              DataColumn(label: Text('Phone')),
            ],
            rows: _batchStudents.map((row) {
              return DataRow(cells: [
                DataCell(SizedBox(width: 130, child: TextField(controller: row['name'], decoration: const InputDecoration(hintText: 'Name')))),
                DataCell(SizedBox(
                  width: 120,
                  child: TextField(
                    controller: row['ht'],
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(hintText: '21MT1A05xx'),
                  ),
                )),
                DataCell(DropdownButton<String>(
                  value: row['branch'],
                  items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => row['branch'] = v),
                )),
                DataCell(DropdownButton<String>(
                  value: row['year_sem'],
                  items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => row['year_sem'] = v),
                )),
                DataCell(SizedBox(
                  width: 50,
                  child: TextField(
                    controller: TextEditingController(text: row['section']),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => row['section'] = v.trim().toUpperCase(),
                  ),
                )),
                DataCell(DropdownButton<String>(
                  value: row['gender'],
                  items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) => setState(() => row['gender'] = v),
                )),
                DataCell(SizedBox(width: 150, child: TextField(controller: row['email'], decoration: const InputDecoration(hintText: 'mail@mtiet.edu')))),
                DataCell(SizedBox(width: 100, child: TextField(controller: row['phone'], decoration: const InputDecoration(hintText: 'Phone')))),
              ]);
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        _buildSubmitButton('Enroll All ${_batchStudents.length} Students', _submitBatchManual),
      ],
    );
  }

  // --- VIEW 3: Excel Upload View ---
  Widget _buildExcelUploadView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            border: Border.all(color: primaryNavy.withOpacity(0.3), width: 1.5),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Column(
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 56, color: primaryNavy),
              const SizedBox(height: 12),
              const Text('Select .xlsx or .xls Spreadsheet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryNavy)),
              const SizedBox(height: 6),
              const Text(
                'Columns format: Name, Hallticket, YearSem, Branch, Section, Email, Gender, Phone',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _pickAndProcessExcel,
                icon: const Icon(Icons.file_open),
                label: const Text('Browse Excel File'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
