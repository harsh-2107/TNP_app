import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/error_helper.dart';
import '../../data/admin_repository.dart';

class CustomCriteria {
  String field;
  String operator;
  dynamic value;
  bool isManual;
  CustomCriteria({
    required this.field,
    required this.operator,
    required this.value,
    this.isManual = false,
  });
  Map<String, dynamic> toJson() => {
    'field': field,
    'operator': operator,
    'value': value,
  };
}

//remaining to share _isJob with supabase
//completely write the predefined ruled in red color
class AdminCreateDrivePage extends ConsumerStatefulWidget {
  const AdminCreateDrivePage({super.key});

  @override
  ConsumerState<AdminCreateDrivePage> createState() =>
      _AdminCreateDrivePageState();
}

class _AdminCreateDrivePageState extends ConsumerState<AdminCreateDrivePage> {
  final _formKey = GlobalKey<FormState>();

  // Basic Info
  final _companyController = TextEditingController();
  final _roleController = TextEditingController();
  final _jdController = TextEditingController();
  final _packageController = TextEditingController();
  DateTime? _deadline;

  // Primary Criteria
  final _cgpaController = TextEditingController();
  final _backlogsController = TextEditingController();
  final _educationGapsController = TextEditingController();
  final _tenthController = TextEditingController();
  final _twelfthController = TextEditingController();
  final _branchesController = TextEditingController(); // Comma separated
  final _batchesController = TextEditingController(); // Comma separated

  // Advanced / Custom Criteria
  List<Map<String, dynamic>> _csvColumns = [];
  List<CustomCriteria> _customCriteria = [];
  bool _isUploadingCsv = false;

  bool _isSubmitting = false;
  bool _isJob = true;

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _jdController.dispose();
    _packageController.dispose();
    _cgpaController.dispose();
    _backlogsController.dispose();
    _educationGapsController.dispose();
    _tenthController.dispose();
    _twelfthController.dispose();
    _branchesController.dispose();
    _batchesController.dispose();
    super.dispose();
  }

  Future<void> _pickAndParseCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isUploadingCsv = true);

        final repository = ref.read(adminRepositoryProvider);
        final response = await repository.parseCsvColumns(
          fileBytes: result.files.single.bytes!.toList(),
          filename: result.files.single.name,
        );

        setState(() {
          _csvColumns = List<Map<String, dynamic>>.from(
            response['columns'] ?? [],
          );
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded ${_csvColumns.length} columns from CSV'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingCsv = false);
      }
    }
  }

  void _addCustomCriteria() {
    setState(() {
      _customCriteria.add(CustomCriteria(field: '', operator: '==', value: ''));
    });
  }

  void _removeCustomCriteria(int index) {
    setState(() {
      _customCriteria.removeAt(index);
    });
  }

  void toggleJob(val) {
    setState(() {
      _isJob = (val == 1 ? true : false);
      //remaining to update it in supabase
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(adminRepositoryProvider);

      final branches = _branchesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final batches = _batchesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final payload = {
        'is_job': _isJob,
        'company_name': _companyController.text.trim(),
        'role_title': _roleController.text.trim(),
        'job_description': _jdController.text.trim().isEmpty
            ? 'N/A'
            : _jdController.text.trim(),
        'expected_package': _packageController.text.trim().isEmpty
            ? 'N/A'
            : _packageController.text.trim(),
        if (_deadline != null)
          'application_deadline': _deadline!.toUtc().toIso8601String(),

        if (_cgpaController.text.isNotEmpty)
          'min_cgpa': double.tryParse(_cgpaController.text),
        if (_backlogsController.text.isNotEmpty)
          'max_backlogs': int.tryParse(_backlogsController.text),
        if (_educationGapsController.text.isNotEmpty)
          'max_education_gaps': int.tryParse(_educationGapsController.text),
        if (_tenthController.text.isNotEmpty)
          'min_tenth_percentage': double.tryParse(_tenthController.text),
        if (_twelfthController.text.isNotEmpty)
          'min_twelfth_percentage': double.tryParse(_twelfthController.text),

        if (branches.isNotEmpty) 'allowed_branches': branches,
        if (batches.isNotEmpty) 'allowed_batches': batches,

        if (_customCriteria.isNotEmpty)
          'custom_criteria': _customCriteria
              .where((c) => c.field.isNotEmpty)
              .map((c) => c.toJson())
              .toList(),
      };

      await repository.createDrive(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drive created successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Placement Drive')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('1. Basic Information'),
              DropdownMenu<int>(
                initialSelection: _isJob ? 1 : -1,
                label: const Text('Type'),
                width: double.infinity,
                menuHeight: 150,
                inputDecorationTheme: InputDecorationTheme(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  fillColor: Colors.white,
                ),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: -1, label: 'Internship'),
                  DropdownMenuEntry(value: 1, label: 'Job'),
                ],
                onSelected: (value) {
                  if (value != null) {
                    toggleJob(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(
                  labelText: 'Role Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jdController,
                decoration: InputDecoration(
                  labelText: (_isJob
                      ? 'Job Description'
                      : 'Internship Description'),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _packageController,
                decoration: const InputDecoration(
                  labelText: 'Expected Package (e.g. 15 LPA)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _deadline == null
                      ? 'Set Application Deadline'
                      : 'Deadline: ${_deadline!.toLocal()}',
                ),
                trailing: const Icon(Icons.calendar_today),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() {
                        _deadline = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('2. Primary Eligibility Rules'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cgpaController,
                      decoration: const InputDecoration(
                        labelText: 'Min CGPA',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _backlogsController,
                      decoration: const InputDecoration(
                        labelText: 'Max Backlogs',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tenthController,
                      decoration: const InputDecoration(
                        labelText: 'Min 10th %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _twelfthController,
                      decoration: const InputDecoration(
                        labelText: 'Min 12th %',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _educationGapsController,
                decoration: const InputDecoration(
                  labelText: 'Max Education Gaps (Years)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchesController,
                decoration: InputDecoration(
                  labelText:
                      'Allowed Branches (comma separated, e.g. CSE, ECE)',
                  border: const OutlineInputBorder(),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (String branch) {
                      final currentText = _branchesController.text.trim();
                      if (currentText.isEmpty) {
                        _branchesController.text = branch;
                      } else {
                        final branches = currentText
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (!branches.contains(branch)) {
                          branches.add(branch);
                          _branchesController.text = branches.join(',');
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      const options = [
                        'CSE',
                        'ECE',
                        'CSD',
                        'CSA',
                        'ECI',
                        'CSH',
                      ];
                      return options.map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _batchesController,
                decoration: InputDecoration(
                  labelText:
                      'Allowed Batches (comma separated, e.g. 2026, 2027)',
                  border: const OutlineInputBorder(),
                  suffixIcon: PopupMenuButton<String>(
                    icon: const Icon(Icons.arrow_drop_down),
                    onSelected: (String batch) {
                      final currentText = _batchesController.text.trim();
                      if (currentText.isEmpty) {
                        _batchesController.text = batch;
                      } else {
                        final batches = currentText
                            .split(',')
                            .map((e) => e.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        if (!batches.contains(batch)) {
                          batches.add(batch);
                          _batchesController.text = batches.join(',');
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      final currentYear = DateTime.now().year;
                      final options = [
                        (currentYear).toString(),
                        (currentYear + 1).toString(),
                        (currentYear - 1).toString(),
                        (currentYear - 2).toString(),
                        (currentYear + 2).toString(),
                      ];
                      return options.map((String choice) {
                        return PopupMenuItem<String>(
                          value: choice,
                          child: Text(choice),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              if (_isJob)
                Column(
                  children: [
                    Text(
                      "*x1.5% rule",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                    ),
                    Text(
                      "*other predefined rules",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              _buildSectionTitle('3. Advanced CSV Rules'),
              const Text(
                'Upload a sample CSV with student data columns to dynamically build custom rules.',
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isUploadingCsv ? null : _pickAndParseCsv,
                icon: _isUploadingCsv
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: const Text('Upload Sample CSV'),
              ),
              if (_csvColumns.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Available Columns from CSV:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 8,
                  children: _csvColumns
                      .map(
                        (c) => Chip(label: Text('${c["name"]} (${c["type"]})')),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              const Text(
                'Custom Eligibility Rules:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._customCriteria.asMap().entries.map((entry) {
                final index = entry.key;
                final criteria = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: (criteria.isManual || _csvColumns.isEmpty)
                              ? TextFormField(
                                  initialValue: criteria.field,
                                  decoration: const InputDecoration(
                                    labelText: 'Field (e.g. gender)',
                                  ),
                                  onChanged: (val) =>
                                      criteria.field = val.trim(),
                                )
                              : DropdownButtonFormField<String>(
                                  initialValue:
                                      criteria.field.isEmpty ||
                                          !_csvColumns.any(
                                            (c) =>
                                                c['name'].toString() ==
                                                criteria.field,
                                          )
                                      ? null
                                      : criteria.field,
                                  decoration: const InputDecoration(
                                    labelText: 'Field',
                                  ),
                                  items: _csvColumns
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c['name'].toString(),
                                          child: Text(c['name'].toString()),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) => setState(
                                    () => criteria.field = val ?? '',
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            initialValue: criteria.operator,
                            decoration: const InputDecoration(
                              labelText: 'Operator',
                            ),
                            items: const [
                              DropdownMenuItem(value: '==', child: Text('==')),
                              DropdownMenuItem(value: '!=', child: Text('!=')),
                              DropdownMenuItem(value: '>=', child: Text('>=')),
                              DropdownMenuItem(value: '<=', child: Text('<=')),
                              DropdownMenuItem(
                                value: 'contains',
                                child: Text('contains'),
                              ),
                              DropdownMenuItem(value: 'in', child: Text('in')),
                            ],
                            onChanged: (val) =>
                                setState(() => criteria.operator = val ?? '=='),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            initialValue: criteria.value.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Value',
                            ),
                            onChanged: (val) => criteria.value = val,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeCustomCriteria(index),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Row(
                children: [
                  if (_csvColumns.isNotEmpty) ...[
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _customCriteria.add(
                            CustomCriteria(
                              field: '',
                              operator: '==',
                              value: '',
                              isManual: false,
                            ),
                          );
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add CSV Rule'),
                    ),
                    const SizedBox(width: 16),
                  ],
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _customCriteria.add(
                          CustomCriteria(
                            field: '',
                            operator: '==',
                            value: '',
                            isManual: true,
                          ),
                        );
                      });
                    },
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Add Manual Rule'),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Create Drive',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blueAccent,
        ),
      ),
    );
  }
}
