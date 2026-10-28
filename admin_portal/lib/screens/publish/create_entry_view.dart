import 'package:flutter/material.dart';
import '../../main.dart';

class CreateEntryView extends StatefulWidget {
  final VoidCallback onEntryCreated;

  const CreateEntryView({super.key, required this.onEntryCreated});

  @override
  State<CreateEntryView> createState() => _CreateEntryViewState();
}

class _CreateEntryViewState extends State<CreateEntryView> {
  final _formKey = GlobalKey<FormState>();
  final _examNameController = TextEditingController();

  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  bool _isLoading = false;
  bool _isLoadingSubjects = false;

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

  DateTime? _fromDate;
  DateTime? _lastDate;

  // Loaded subjects for the selected Branch & Year/Sem
  List<Map<String, dynamic>> _subjects = [];
  final Map<String, TextEditingController> _marksControllers = {};

  @override
  void initState() {
    super.initState();
    _loadBranches();
    _fetchSubjectsForCriteria();
  }

  @override
  void dispose() {
    _examNameController.dispose();
    for (var c in _marksControllers.values) {
      c.dispose();
    }
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
      if (mounted) {
        setState(() {
          _branches = ['ALL', ...list];
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _branches = ['ALL', 'CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        });
      }
    }
  }

  Future<void> _fetchSubjectsForCriteria() async {
    setState(() => _isLoadingSubjects = true);

    for (var c in _marksControllers.values) {
      c.dispose();
    }
    _marksControllers.clear();

    try {
      var query = supabase
          .from('subjects')
          .select('subject_code, subject_name, branch, year_sem')
          .eq('year_sem', _selectedYearSem);

      if (_selectedBranch != 'ALL') {
        query = query.eq('branch', _selectedBranch);
      }

      final List<dynamic> data = await query.order(
        'subject_code',
        ascending: true,
      );

      // Deduplicate subjects by subject_code (since sections share course codes)
      final seenCodes = <String>{};
      final uniqueList = <Map<String, dynamic>>[];

      for (var row in data) {
        final code = row['subject_code'].toString();
        if (!seenCodes.contains(code)) {
          seenCodes.add(code);
          uniqueList.add(Map<String, dynamic>.from(row));
          _marksControllers[code] = TextEditingController(
            text: '30',
          ); // Default 30 marks
        }
      }

      if (mounted) {
        setState(() {
          _subjects = uniqueList;
          _isLoadingSubjects = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSubjects = false);
      }
    }
  }

  Future<void> _pickDate({required bool isFromDate}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (_fromDate ?? now)
          : (_lastDate ?? (_fromDate ?? now)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: primaryNavy),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_lastDate != null && _lastDate!.isBefore(_fromDate!)) {
            _lastDate = _fromDate;
          }
        } else {
          _lastDate = picked;
        }
      });
    }
  }

  Future<void> _handleCreatePublishWindow() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_fromDate == null || _lastDate == null) {
      _showSnack('Please select both From Date and Last Date', isError: true);
      return;
    }

    if (_subjects.isEmpty) {
      _showSnack(
        'No subjects available for the selected criteria',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final examName = _examNameController.text.trim().toUpperCase();

      // 1. Build subject configuration payload
      List<Map<String, dynamic>> subjectConfigs = [];
      List<String> subjectCodes = [];

      for (var s in _subjects) {
        final code = s['subject_code'].toString();
        final maxMarks =
            double.tryParse(_marksControllers[code]?.text.trim() ?? '30') ??
            30.0;
        subjectCodes.add(code);
        subjectConfigs.add({
          'subject_code': code,
          'subject_name': s['subject_name'],
          'total_marks': maxMarks,
        });
      }

      // 2. Insert record into assessment_windows table
      final insertRes = await supabase
          .from('assessment_windows')
          .insert({
            'exam_name': examName,
            'branch': _selectedBranch,
            'year_sem': _selectedYearSem,
            'section': 'ALL', // Allows all sections to match
            'is_published': true, // Makes visible in faculty app
            'is_closed': false,
            'published_to_students': false,
            'from_date': _fromDate!.toIso8601String().split('T')[0],
            'last_date': _lastDate!.toIso8601String().split('T')[0],
            'subject_configs': subjectConfigs,
          })
          .select('id')
          .single();

      final String windowId = insertRes['id'];

      // 3. Create dynamic table(s) via database function
      if (_selectedBranch == 'ALL') {
        // Run for each branch separately
        for (var b in _branches.where((br) => br != 'ALL')) {
          await supabase.rpc(
            'create_assessment_marks_table',
            params: {
              'p_window_id': windowId,
              'p_branch': b,
              'p_year_sem': _selectedYearSem,
              'p_subject_codes': subjectCodes,
            },
          );
        }
      } else {
        await supabase.rpc(
          'create_assessment_marks_table',
          params: {
            'p_window_id': windowId,
            'p_branch': _selectedBranch,
            'p_year_sem': _selectedYearSem,
            'p_subject_codes': subjectCodes,
          },
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      _showSnack('Examination Marks Entry Window Published Successfully!');
      _examNameController.clear();
      widget.onEntryCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Failed to publish marks window: $e', isError: true);
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
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create Assessment Marks Entry Window',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Configure examination windows, max marks, and generate student evaluation records.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                    const SizedBox(height: 22),

                    // Exam Name (Enforces UPPERCASE)
                    TextFormField(
                      controller: _examNameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Examination Name (CAPITALS) *',
                        hintText: 'e.g. MID-1 EXAMINATIONS / SEMESTER LAB',
                        prefixIcon: Icon(Icons.edit_note_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter examination name in capitals'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Year/Sem & Branch Dropdown Row
                    Row(
                      children: [
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
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedYearSem = v!);
                              _fetchSubjectsForCriteria();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      b == 'ALL' ? 'ALL BRANCHES' : b,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedBranch = v!);
                              _fetchSubjectsForCriteria();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date Selection Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isFromDate: true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Entry From Date *',
                                prefixIcon: Icon(Icons.date_range_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Text(
                                _fromDate != null
                                    ? _fromDate!.toIso8601String().split('T')[0]
                                    : 'Select Start Date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _fromDate != null
                                      ? Colors.black
                                      : textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(isFromDate: false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Entry Last Date *',
                                prefixIcon: Icon(Icons.event_busy_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Text(
                                _lastDate != null
                                    ? _lastDate!.toIso8601String().split('T')[0]
                                    : 'Select End Date',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _lastDate != null
                                      ? Colors.black
                                      : textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Available Subjects & Total Marks Section
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: primaryNavy.withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_outlined,
                                    size: 18,
                                    color: primaryNavy,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Configured Subjects & Max Marks',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: primaryNavy,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${_subjects.length} Subjects',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _isLoadingSubjects
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                      color: primaryNavy,
                                    ),
                                  ),
                                )
                              : _subjects.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(12.0),
                                  child: Center(
                                    child: Text(
                                      'No subjects found registered for this Year/Sem & Branch.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: textMuted,
                                      ),
                                    ),
                                  ),
                                )
                              : Column(
                                  children: _subjects.map((sub) {
                                    final code = sub['subject_code'].toString();
                                    return Card(
                                      elevation: 1,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sub['subject_name'] ?? '',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: primaryNavy,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Code: $code | ${sub['branch']}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            SizedBox(
                                              width: 110,
                                              child: TextFormField(
                                                controller:
                                                    _marksControllers[code],
                                                keyboardType:
                                                    TextInputType.number,
                                                textAlign: TextAlign.center,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: 'Max Marks',
                                                      border:
                                                          OutlineInputBorder(),
                                                      isDense: true,
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 8,
                                                          ),
                                                    ),
                                                validator: (v) =>
                                                    (v == null ||
                                                        double.tryParse(v) ==
                                                            null)
                                                    ? 'Required'
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _handleCreatePublishWindow,
                        icon: _isLoading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.publish, size: 20),
                        label: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Publish Assessment Window',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
