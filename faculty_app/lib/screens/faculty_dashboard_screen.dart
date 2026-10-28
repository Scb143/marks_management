import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/watermark_scaffold.dart';
import 'marks_entry_screen.dart';

class FacultyDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const FacultyDashboardScreen({super.key, required this.user});

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color accentGold = Color(0xFFFBC02D);
  static const Color textMuted = Color(0xFF6B7280);

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Map<String, dynamic>> _assignedSubjects = [];
  List<Map<String, dynamic>> _filteredSubjects = [];

  String _selectedSemFilter = 'ALL';
  List<String> _semestersList = ['ALL'];

  @override
  void initState() {
    super.initState();
    _loadAssignedSubjects();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedSubjects() async {
    setState(() => _isLoading = true);
    try {
      final facultyId = widget.user['faculty_id'] ?? widget.user['user_id'];

      final List<dynamic> data = await supabase
          .from('subjects')
          .select()
          .eq('incharge_id', facultyId)
          .order('year_sem', ascending: true);

      final subjects = List<Map<String, dynamic>>.from(data);

      final Set<String> sems = {'ALL'};
      for (var s in subjects) {
        if (s['year_sem'] != null && s['year_sem'].toString().isNotEmpty) {
          sems.add(s['year_sem'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _assignedSubjects = subjects;
          _semestersList = sems.toList();
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading assigned subjects: $e'),
            backgroundColor: accentRed,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredSubjects = _assignedSubjects.where((sub) {
        final name = (sub['subject_name'] ?? '').toString().toLowerCase();
        final code = (sub['subject_code'] ?? '').toString().toLowerCase();
        final sem = (sub['year_sem'] ?? '').toString();

        final matchesQuery = name.contains(query) || code.contains(query);
        final matchesSem = _selectedSemFilter == 'ALL' || sem == _selectedSemFilter;

        return matchesQuery && matchesSem;
      }).toList();
    });
  }

  // =========================================================================
  // ACTION 1: VIEW ENROLLED STUDENTS DETAILS
  // =========================================================================
  void _viewStudentsDetails(Map<String, dynamic> subject) {
    final String branch = (subject['branch'] ?? '').toString();
    final String yearSem = (subject['year_sem'] ?? '').toString();
    final String section = (subject['section'] ?? 'A').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enrolled Students - Sec $section',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subject['subject_name']} • $branch ($yearSem)',
                          style: const TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: supabase
                      .from('users')
                      .select('user_id, name, section, branch, phone_no, email')
                      .eq('role', 'student')
                      .eq('branch', branch)
                      .eq('year_sem', yearSem)
                      .eq('section', section)
                      .order('user_id', ascending: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryNavy),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load students: ${snapshot.error}',
                          style: const TextStyle(color: accentRed, fontSize: 13),
                        ),
                      );
                    }

                    final students = snapshot.data ?? [];
                    if (students.isEmpty) {
                      return Center(
                        child: Text(
                          'No students enrolled in Section $section for $branch ($yearSem).',
                          style: const TextStyle(color: textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: students.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final st = students[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: primaryNavy.withOpacity(0.08),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: primaryNavy,
                              ),
                            ),
                          ),
                          title: Text(
                            st['name'] ?? 'Student',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: primaryNavy,
                            ),
                          ),
                          subtitle: Text(
                            'HT No: ${st['user_id']} • Sec: ${st['section'] ?? section}',
                            style: const TextStyle(fontSize: 12, color: textMuted),
                          ),
                          trailing: (st['phone'] != null && st['phone'].toString().isNotEmpty)
                              ? Text(
                                  st['phone'].toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // ACTION 2: MARKS ENTRY ASSESSMENT WINDOWS MODAL
  // =========================================================================
  void _openAssessmentWindowsModal(Map<String, dynamic> subject) {
    final String branch = (subject['branch'] ?? '').toString();
    final String yearSem = (subject['year_sem'] ?? '').toString();
    final String section = (subject['section'] ?? 'A').toString().toUpperCase();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject['subject_name'] ?? 'Subject',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subject['subject_code']} • $branch • Sec $section ($yearSem)',
                          style: const TextStyle(fontSize: 12, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Select Examination Assessment Window',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryNavy,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: supabase
                      .from('assessment_windows')
                      .select()
                      .or('branch.eq.$branch,branch.eq.ALL')
                      .eq('year_sem', yearSem)
                      .or('section.eq.$section,section.eq.ALL,section.is.null')
                      .order('created_at', ascending: false),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryNavy),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Failed to load assessment windows: ${snapshot.error}',
                          style: const TextStyle(color: accentRed, fontSize: 13),
                        ),
                      );
                    }

                    final windows = snapshot.data ?? [];
                    if (windows.isEmpty) {
                      return const Center(
                        child: Text(
                          'No assessment entry windows published for this class.',
                          style: TextStyle(color: textMuted),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: windows.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final win = windows[index];
                        final now = DateTime.now();
                        final fromDate = DateTime.tryParse(win['from_date'] ?? '') ?? now;
                        final lastDate = DateTime.tryParse(win['last_date'] ?? '') ?? now;

                        final bool isForceClosed = win['is_closed'] == true;
                        final bool isBefore = now.isBefore(fromDate);
                        final bool isExpired = now.isAfter(lastDate.add(const Duration(days: 1)));
                        final bool isReadOnly = isForceClosed || isExpired || isBefore;

                        return Card(
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: !isReadOnly
                                  ? Colors.green.shade400
                                  : Colors.grey.shade300,
                              width: !isReadOnly ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Text(
                              win['exam_name'] ?? 'Internal Assessment',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: primaryNavy,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Schedule: ${win['from_date']} to ${win['last_date']}',
                                  style: const TextStyle(fontSize: 12, color: textMuted),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isForceClosed
                                        ? accentRed.withOpacity(0.12)
                                        : isExpired
                                            ? Colors.grey.shade200
                                            : isBefore
                                                ? accentGold.withOpacity(0.2)
                                                : Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isForceClosed
                                        ? 'CLOSED BY ADMIN (READ-ONLY)'
                                        : isExpired
                                            ? 'TIME EXPIRED (READ-ONLY)'
                                            : isBefore
                                                ? 'UPCOMING (READ-ONLY)'
                                                : 'PORTAL ACTIVE',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isForceClosed
                                          ? accentRed
                                          : isExpired
                                              ? Colors.grey.shade800
                                              : isBefore
                                                  ? Colors.orange.shade900
                                                  : Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MarksEntryScreen(
                                      subject: subject,
                                      assessmentWindow: win,
                                      facultyId: (widget.user['faculty_id'] ??
                                              widget.user['user_id'] ??
                                              '')
                                          .toString(),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isReadOnly ? Colors.grey.shade700 : primaryNavy,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                isReadOnly ? Icons.visibility_outlined : Icons.edit_note,
                                size: 16,
                              ),
                              label: Text(isReadOnly ? 'View Marks' : 'Enter Marks'),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final facultyName = widget.user['name'] ?? 'Faculty Member';
    final facultyId = widget.user['faculty_id'] ?? widget.user['user_id'] ?? '';
    final department = widget.user['department'] ?? '';

    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
        title: const Text(
          'Faculty Evaluation Portal',
          style: TextStyle(
            color: primaryNavy,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryNavy),
            onPressed: _loadAssignedSubjects,
            tooltip: 'Refresh assigned classes',
          ),

          // TOP-RIGHT CORNER PROFILE AVATAR MENU
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryNavy.withOpacity(0.1),
                    child: const Icon(Icons.person, size: 22, color: primaryNavy),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: primaryNavy, size: 18),
                ],
              ),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facultyName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryNavy,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'ID: $facultyId ${department.isNotEmpty ? "• $department" : ""}',
                        style: const TextStyle(fontSize: 12, color: textMuted),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: accentRed, size: 18),
                      SizedBox(width: 8),
                      Text('Log Out', style: TextStyle(color: accentRed, fontSize: 13)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                if (value == 'logout') {
                  await supabase.auth.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/');
                  }
                }
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TOP SEARCH & FILTER BAR
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: primaryNavy, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search subject name or code...',
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: primaryNavy.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedSemFilter,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.filter_list, size: 18, color: primaryNavy),
                            items: _semestersList.map((sem) {
                              return DropdownMenuItem<String>(
                                value: sem,
                                child: Text(
                                  sem == 'ALL' ? 'All Semesters' : sem,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() => _selectedSemFilter = val);
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Count Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Assigned Courses & Sections',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                      ),
                    ),
                    Text(
                      '${_filteredSubjects.length} of ${_assignedSubjects.length} Courses',
                      style: const TextStyle(
                        fontSize: 12,
                        color: textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ASSIGNED SUBJECTS LIST WITH IN-CARD ACTION BUTTONS
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: primaryNavy),
                        )
                      : _filteredSubjects.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.menu_book_outlined,
                                    size: 50,
                                    color: textMuted,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No matching courses or sections found.',
                                    style: TextStyle(color: textMuted),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_assignedSubjects.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _selectedSemFilter = 'ALL');
                                        _applyFilters();
                                      },
                                      child: const Text('Reset Filters'),
                                    ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _filteredSubjects.length,
                              separatorBuilder: (c, i) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final sub = _filteredSubjects[index];
                                final sec = (sub['section'] ?? 'A').toString().toUpperCase();

                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: primaryNavy.withOpacity(0.12),
                                      width: 1,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Header Row: Avatar, Subject info & Credits
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 22,
                                              backgroundColor: primaryNavy.withOpacity(0.1),
                                              child: Text(
                                                sec,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryNavy,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    sub['subject_name'] ?? 'Subject',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      color: primaryNavy,
                                                      fontSize: 15.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${sub['subject_code']} • ${sub['branch']} • Sec $sec • ${sub['year_sem']}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: primaryNavy.withOpacity(0.06),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${sub['credits'] ?? 3.0} Cr',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryNavy,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 22),

                                        // IN-CARD ACTION BUTTONS ROW
                                        Row(
                                          children: [
                                            // Action 1: View Students Details
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () => _viewStudentsDetails(sub),
                                                icon: const Icon(
                                                  Icons.people_alt_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'View Students Details',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: primaryNavy,
                                                  side: const BorderSide(color: primaryNavy),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            // Action 2: Marks Entry
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                onPressed: () => _openAssessmentWindowsModal(sub),
                                                icon: const Icon(
                                                  Icons.fact_check_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Marks Entry',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: primaryNavy,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                                ),
                                              ),
                                            ),
                                          ],
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
      ),
    );
  }
}