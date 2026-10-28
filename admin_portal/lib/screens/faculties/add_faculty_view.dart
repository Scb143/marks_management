import 'package:flutter/material.dart';
import '../../main.dart';
import 'package:bcrypt/bcrypt.dart';

class AddFacultyView extends StatefulWidget {
  final VoidCallback onFacultyAdded;

  const AddFacultyView({super.key, required this.onFacultyAdded});

  @override
  State<AddFacultyView> createState() => _AddFacultyViewState();
}

class _AddFacultyViewState extends State<AddFacultyView> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _qualificationController = TextEditingController(text: 'M.Tech');
  final _expController = TextEditingController(text: '1.0');

  bool _isLoading = false;
  static const Color primaryNavy = Color(0xFF0B2356);
  static const Color accentRed = Color(0xFFD32F2F);

  final List<String> _designations = [
    'Professor & HOD',
    'Professor',
    'Associate Professor',
    'Assistant Professor',
    'Lecturer',
    'Lab Technician',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];
  List<String> _departments = [];

  String? _selectedDepartment;
  String _selectedDesignation = 'Assistant Professor';
  String _selectedGender = 'Male';

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _qualificationController.dispose();
    _expController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await supabase
          .from('branches')
          .select('branch_code')
          .order('branch_code', ascending: true);

      final list = (data as List)
          .map((e) => e['branch_code'].toString())
          .toList();
      setState(() {
        _departments = list.isNotEmpty
            ? list
            : ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedDepartment = _departments.first;
      });
    } catch (_) {
      setState(() {
        _departments = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'AI & DS'];
        _selectedDepartment = _departments.first;
      });
    }
  }

  Future<void> _handleSaveFaculty() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    final facultyId = _idController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final phone = _phoneController.text.trim();
    final qualification = _qualificationController.text.trim();
    final exp = double.tryParse(_expController.text.trim()) ?? 0.0;

    try {
      // 1. MUST register in 'users' first to satisfy the foreign key constraint
      final String hashedDefaultPassword = BCrypt.hashpw(
        facultyId,
        BCrypt.gensalt(),
      );
      await supabase.from('users').upsert({
        'user_id': facultyId,
        'password_hash': hashedDefaultPassword, // default password
        'name': name,
        'email': email,
        'branch': _selectedDepartment,
        'gender': _selectedGender,
        'phone_no': phone.isEmpty ? null : phone,
        'role': 'faculty',
      });

      // 2. Insert into 'faculties' table now that user_id exists in 'users'
      await supabase.from('faculties').insert({
        'faculty_id': facultyId,
        'name': name,
        'email': email,
        'phone_no': phone.isEmpty ? null : phone,
        'department': _selectedDepartment,
        'designation': _selectedDesignation,
        'qualification': qualification,
        'gender': _selectedGender,
        'experience_years': exp,
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Faculty profile and login account created!'),
          backgroundColor: Colors.green,
        ),
      );

      _idController.clear();
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      widget.onFacultyAdded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add faculty: $e'),
          backgroundColor: accentRed,
        ),
      );
    }
  }

 @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isMobile = constraints.maxWidth < 500;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Register Faculty Member',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: primaryNavy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Provide academic profile and institutional department allocations.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 20),

                        // 1. Faculty ID & Name
                        if (isMobile) ...[
                          TextFormField(
                            controller: _idController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Faculty ID *',
                              hintText: 'e.g. MTFAC01',
                              prefixIcon: Icon(Icons.badge_outlined, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              hintText: 'e.g. Dr. K. Ramesh',
                              prefixIcon: Icon(Icons.person_outline, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _idController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    labelText: 'Faculty ID *',
                                    hintText: 'e.g. MTFAC01',
                                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name *',
                                    hintText: 'e.g. Dr. K. Ramesh',
                                    prefixIcon: Icon(Icons.person_outline, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 2. Department & Designation
                        if (isMobile) ...[
                          DropdownButtonFormField<String>(
                            value: _selectedDepartment,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Department *',
                              prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _departments
                                .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDepartment = v),
                            validator: (v) => v == null ? 'Select department' : null,
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedDesignation,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Designation *',
                              prefixIcon: Icon(Icons.work_outline, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _designations
                                .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDesignation = v!),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDepartment,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Department *',
                                    prefixIcon: Icon(Icons.account_tree_outlined, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _departments
                                      .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedDepartment = v),
                                  validator: (v) => v == null ? 'Select department' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedDesignation,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Designation *',
                                    prefixIcon: Icon(Icons.work_outline, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _designations
                                      .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedDesignation = v!),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 3. Qualification & Gender
                        if (isMobile) ...[
                          TextFormField(
                            controller: _qualificationController,
                            decoration: const InputDecoration(
                              labelText: 'Highest Qualification',
                              hintText: 'e.g. Ph.D / M.Tech',
                              prefixIcon: Icon(Icons.school_outlined, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: _selectedGender,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.transgender_outlined, size: 20),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _genders
                                .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedGender = v!),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _qualificationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Highest Qualification',
                                    hintText: 'e.g. Ph.D / M.Tech',
                                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    prefixIcon: Icon(Icons.transgender_outlined, size: 20),
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  items: _genders
                                      .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 12))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _selectedGender = v!),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // 4. Institutional Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email *',
                            prefixIcon: Icon(Icons.email_outlined, size: 20),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null,
                        ),
                        const SizedBox(height: 14),

                        // 5. Phone & Experience
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone (Optional)',
                                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _expController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Exp (Yrs)',
                                  prefixIcon: Icon(Icons.timeline_outlined, size: 20),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryNavy.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 18, color: primaryNavy),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'A faculty portal user account is automatically configured. Password is set to Faculty ID by default.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: primaryNavy,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSaveFaculty,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryNavy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Enroll Faculty', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
