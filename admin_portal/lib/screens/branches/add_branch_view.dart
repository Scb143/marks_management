import 'package:flutter/material.dart';
import '../../main.dart';

class AddBranchView extends StatefulWidget {
  final VoidCallback onBranchAdded;

  const AddBranchView({super.key, required this.onBranchAdded});

  @override
  State<AddBranchView> createState() => _AddBranchViewState();
}

class _AddBranchViewState extends State<AddBranchView> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _intakeController = TextEditingController(text: '60');
  final _yearController = TextEditingController(text: DateTime.now().year.toString());

  bool _isLoading = false;
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);
  static const Color textMuted = Color(0xFF6B7280);

  List<Map<String, dynamic>> _professors = [];
  String? _selectedHod; // Optional

  @override
  void initState() {
    super.initState();
    _loadProfessors();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _intakeController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _loadProfessors() async {
    try {
      final data = await supabase
          .from('faculties')
          .select('faculty_id, name')
          .order('name', ascending: true);

      setState(() {
        _professors = List<Map<String, dynamic>>.from(data);
      });
    } catch (_) {}
  }

  Future<void> _handleSaveBranch() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final code = _codeController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final intake = int.tryParse(_intakeController.text.trim()) ?? 60;
    final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;

    try {
      await supabase.from('branches').insert({
        'branch_code': code,
        'branch_name': name,
        'hod_name': _selectedHod,
        'intake_capacity': intake,
        'established_year': year,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Branch successfully registered!'),
          backgroundColor: Colors.green,
        ),
      );

      _codeController.clear();
      _nameController.clear();
      _intakeController.text = '60';
      setState(() => _selectedHod = null);
      widget.onBranchAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add branch: $e'), backgroundColor: accentRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Academic Branch',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Define department disciplines, intake quotas, and leadership.',
                      style: TextStyle(fontSize: 12.5, color: textMuted),
                    ),
                    const SizedBox(height: 24),

                    // Branch Code & Capacity
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Branch Code *',
                              hintText: 'e.g. CSE / ECE',
                              prefixIcon: Icon(Icons.tag_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Enter code' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _intakeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Intake Capacity *',
                              hintText: 'e.g. 60 / 120',
                              prefixIcon: Icon(Icons.people_alt_outlined),
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || int.tryParse(v) == null)
                                ? 'Valid number'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Full Branch Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Department / Branch Name *',
                        hintText: 'e.g. Computer Science & Engineering',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Enter branch name' : null,
                    ),
                    const SizedBox(height: 16),

                    // HOD Selection (Optional)
                    DropdownButtonFormField<String?>(
                      value: _selectedHod,
                      decoration: InputDecoration(
                        labelText: 'Head of Department (HOD) - Optional',
                        prefixIcon: const Icon(Icons.person_pin_outlined),
                        border: const OutlineInputBorder(),
                        suffixIcon: _selectedHod != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() => _selectedHod = null),
                              )
                            : null,
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Not Assigned (Pending)', style: TextStyle(color: textMuted)),
                        ),
                        ..._professors.map((p) => DropdownMenuItem<String?>(
                              value: '${p['name']} (${p['faculty_id']})',
                              child: Text('${p['name']} (${p['faculty_id']})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedHod = v),
                    ),
                    const SizedBox(height: 16),

                    // Established Year
                    TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Established Year',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || int.tryParse(v) == null) ? 'Enter valid year' : null,
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSaveBranch,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Register Branch',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
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
