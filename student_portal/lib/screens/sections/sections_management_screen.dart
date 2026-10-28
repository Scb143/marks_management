import 'package:flutter/material.dart';
import '../../main.dart';
import '../../widgets/watermark_scaffold.dart';

class SectionsManagementScreen extends StatefulWidget {
  const SectionsManagementScreen({super.key});

  @override
  State<SectionsManagementScreen> createState() => _SectionsManagementScreenState();
}

class _SectionsManagementScreenState extends State<SectionsManagementScreen> {
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  bool _isLoading = true;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _filteredSections = [];
  List<String> _branches = [];

  String _selectedBranch = 'ALL';
  String _selectedYearSem = 'ALL';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final branchData = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      _branches = ['ALL', ...(branchData as List).map((e) => e['branch_code'].toString())];

      final secData = await supabase
          .from('sections')
          .select()
          .order('branch_code', ascending: true)
          .order('year_sem', ascending: true)
          .order('section_name', ascending: true);

      setState(() {
        _sections = List<Map<String, dynamic>>.from(secData);
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sections: $e'), backgroundColor: accentRed),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredSections = _sections.where((sec) {
        final matchBranch = _selectedBranch == 'ALL' || sec['branch_code'] == _selectedBranch;
        final matchSem = _selectedYearSem == 'ALL' || sec['year_sem'] == _selectedYearSem;
        return matchBranch && matchSem;
      }).toList();
    });
  }

  void _showAddSectionDialog() {
    final nameCtrl = TextEditingController(text: 'B');
    final roomCtrl = TextEditingController();
    String branch = _branches.firstWhere((b) => b != 'ALL', orElse: () => 'CSE');
    String sem = _semesters[1];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Classroom Section', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: branch,
                decoration: const InputDecoration(labelText: 'Branch', border: OutlineInputBorder()),
                items: _branches.where((b) => b != 'ALL').map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => branch = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sem,
                decoration: const InputDecoration(labelText: 'Year & Semester', border: OutlineInputBorder()),
                items: _semesters.where((s) => s != 'ALL').map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => sem = v!,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Section Name (e.g. B, C, D)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Classroom / Room No (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryNavy, foregroundColor: Colors.white),
            onPressed: () async {
              final secName = nameCtrl.text.trim().toUpperCase();
              if (secName.isEmpty) return;
              try {
                await supabase.from('sections').insert({
                  'branch_code': branch,
                  'year_sem': sem,
                  'section_name': secName,
                  'room_no': roomCtrl.text.trim().isEmpty ? null : roomCtrl.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add section: $e'), backgroundColor: accentRed),
                );
              }
            },
            child: const Text('Add Section'),
          ),
        ],
      ),
    );
  }

  void _deleteSection(String id, String branch, String sem, String secName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Section', style: TextStyle(color: accentRed, fontWeight: FontWeight.bold)),
        content: Text('Delete Section $secName for $branch ($sem)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentRed, foregroundColor: Colors.white),
            onPressed: () async {
              await supabase.from('sections').delete().eq('id', id);
              if (mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WatermarkScaffold(
      scaleFactor: 0.75,
      watermarkOpacity: 0.05,
      appBar: AppBar(
        title: const Text('Sections & Classes', style: TextStyle(color: primaryNavy, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: primaryNavy),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryNavy,
        onPressed: _showAddSectionDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Section', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Filter Row
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                        const SizedBox(width: 20),
                        DropdownButton<String>(
                          value: _selectedYearSem,
                          items: _semesters.map((s) => DropdownMenuItem(value: s, child: Text('Sem: $s'))).toList(),
                          onChanged: (v) {
                            setState(() => _selectedYearSem = v!);
                            _applyFilters();
                          },
                        ),
                        const Spacer(),
                        Text('${_filteredSections.length} Sections', style: const TextStyle(fontWeight: FontWeight.bold, color: textMuted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Grid View of Sections
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: primaryNavy))
                      : _filteredSections.isEmpty
                          ? const Center(child: Text('No sections match the filters', style: TextStyle(color: textMuted)))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 320,
                                mainAxisExtent: 140,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _filteredSections.length,
                              itemBuilder: (context, i) {
                                final s = _filteredSections[i];
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: primaryNavy.withOpacity(0.1),
                                              child: Text(
                                                s['section_name'] ?? 'A',
                                                style: const TextStyle(color: primaryNavy, fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            Text(
                                              s['branch_code'] ?? '',
                                              style: const TextStyle(fontWeight: FontWeight.bold, color: primaryNavy),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: accentRed),
                                              onPressed: () => _deleteSection(s['id'], s['branch_code'], s['year_sem'], s['section_name']),
                                            ),
                                          ],
                                        ),
                                        Text(s['year_sem'] ?? '', style: const TextStyle(fontSize: 13, color: textMuted)),
                                        Text(
                                          s['room_no'] != null ? 'Room: ${s['room_no']}' : 'Room: Not Assigned',
                                          style: const TextStyle(fontSize: 11, color: Colors.grey),
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