import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/error_helper.dart';
import '../../../../core/theme/app_colors.dart';
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

class DescriptionSubfieldItem {
  final TextEditingController label;
  final TextEditingController value;

  DescriptionSubfieldItem({String labelText = '', String valueText = ''})
    : label = TextEditingController(text: labelText),
      value = TextEditingController(text: valueText);

  void dispose() {
    label.dispose();
    value.dispose();
  }

  Map<String, String> toJson() => {
    'label': label.text.trim(),
    'value': value.text.trim(),
  };
}

class DescriptionSectionItem {
  final TextEditingController heading;
  final TextEditingController content;
  final List<DescriptionSubfieldItem> subfields;

  DescriptionSectionItem({
    String headingText = '',
    String contentText = '',
    List<DescriptionSubfieldItem>? subfieldsList,
  }) : heading = TextEditingController(text: headingText),
       content = TextEditingController(text: contentText),
       subfields = subfieldsList ?? [];

  void dispose() {
    heading.dispose();
    content.dispose();
    for (final sf in subfields) {
      sf.dispose();
    }
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'heading': heading.text.trim(),
      'content': content.text.trim(),
    };
    final validSubfields = subfields
        .where(
          (s) =>
              s.label.text.trim().isNotEmpty || s.value.text.trim().isNotEmpty,
        )
        .map((s) => s.toJson())
        .toList();
    if (validSubfields.isNotEmpty) {
      map['subfields'] = validSubfields;
    }
    return map;
  }
}

class RoundFormItem {
  int roundNumber;
  final TextEditingController roundName;
  String roundType;
  String roundMode; // 'Online' or 'Offline'
  DateTime? roundDatetime;
  final TextEditingController syllabus;

  RoundFormItem({
    required this.roundNumber,
    String name = '',
    this.roundType = 'coding',
    this.roundMode = 'Online',
    this.roundDatetime,
    String syllabusText = '',
  }) : roundName = TextEditingController(text: name),
       syllabus = TextEditingController(text: syllabusText);

  void dispose() {
    roundName.dispose();
    syllabus.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'round_number': roundNumber,
      'round_name': roundName.text.trim().isEmpty
          ? 'Round $roundNumber'
          : roundName.text.trim(),
      'round_type': roundType,
      'round_mode': roundMode,
      if (roundDatetime != null)
        'round_datetime': roundDatetime!.toUtc().toIso8601String(),
      if (syllabus.text.trim().isNotEmpty) 'syllabus': syllabus.text.trim(),
    };
  }
}

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

  // Dynamic Description Sections
  final List<DescriptionSectionItem> _descriptionSections = [];

  // Selection Rounds
  final List<RoundFormItem> _rounds = [];

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
  void initState() {
    super.initState();
    _initDefaultSectionsAndRounds();
  }

  void _initDefaultSectionsAndRounds() {
    // Prepopulate default dynamic blocks
    _descriptionSections.add(
      DescriptionSectionItem(
        headingText: 'Package Details',
        contentText: 'Comprehensive Compensation Structure',
        subfieldsList: [
          DescriptionSubfieldItem(
            labelText: 'Base Salary',
            valueText: '24 LPA',
          ),
          DescriptionSubfieldItem(
            labelText: 'Bonus / Stocks',
            valueText: '8 LPA',
          ),
        ],
      ),
    );

    _descriptionSections.add(
      DescriptionSectionItem(
        headingText: 'Work Location',
        contentText: 'Bangalore / Hybrid',
      ),
    );

    // Prepopulate 3 default selection rounds
    _rounds.add(
      RoundFormItem(
        roundNumber: 1,
        name: 'Online Assessment',
        roundType: 'coding',
        roundMode: 'Online',
        syllabusText: 'Arrays, Strings, Dynamic Programming, Graphs',
      ),
    );

    _rounds.add(
      RoundFormItem(
        roundNumber: 2,
        name: 'Technical Interview 1',
        roundType: 'technical',
        roundMode: 'Offline',
        syllabusText: 'System Design, OOP, DBMS',
      ),
    );

    _rounds.add(
      RoundFormItem(
        roundNumber: 3,
        name: 'HR & Cultural Fit',
        roundType: 'hr',
        roundMode: 'Offline',
        syllabusText: 'Behavioral assessment, Team communication, Culture fit',
      ),
    );
  }

  @override
  void dispose() {
    _companyController.dispose();
    _roleController.dispose();
    _jdController.dispose();
    _packageController.dispose();
    for (final s in _descriptionSections) {
      s.dispose();
    }
    for (final r in _rounds) {
      r.dispose();
    }
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

  void _addDescriptionSection() {
    setState(() {
      _descriptionSections.add(
        DescriptionSectionItem(
          headingText: 'Additional Information',
          contentText: '',
        ),
      );
    });
  }

  void _removeDescriptionSection(int index) {
    setState(() {
      final removed = _descriptionSections.removeAt(index);
      removed.dispose();
    });
  }

  void _addSubfield(DescriptionSectionItem section) {
    setState(() {
      section.subfields.add(DescriptionSubfieldItem());
    });
  }

  void _removeSubfield(DescriptionSectionItem section, int index) {
    setState(() {
      final removed = section.subfields.removeAt(index);
      removed.dispose();
    });
  }

  void _addRound() {
    setState(() {
      final nextNumber = _rounds.length + 1;
      _rounds.add(
        RoundFormItem(
          roundNumber: nextNumber,
          name: 'Round $nextNumber',
          roundType: 'technical',
          roundMode: 'Online',
          syllabusText: '',
        ),
      );
    });
  }

  void _removeRound(int index) {
    setState(() {
      final removed = _rounds.removeAt(index);
      removed.dispose();
      // Renumber subsequent rounds
      for (int i = 0; i < _rounds.length; i++) {
        _rounds[i].roundNumber = i + 1;
      }
    });
  }

  void _removeCustomCriteria(int index) {
    if (index >= 0 && index < _customCriteria.length) {
      setState(() {
        _customCriteria.removeAt(index);
      });
    }
  }

  Future<void> _pickRoundDateTime(RoundFormItem round) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: round.roundDatetime ?? now.add(const Duration(days: 3)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;
    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: round.roundDatetime != null
          ? TimeOfDay.fromDateTime(round.roundDatetime!)
          : const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    setState(() {
      round.roundDatetime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void toggleJob(val) {
    setState(() {
      _isJob = (val == 1 ? true : false);
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

      final sectionsJson = _descriptionSections
          .where(
            (s) =>
                s.heading.text.trim().isNotEmpty ||
                s.content.text.trim().isNotEmpty,
          )
          .map((s) => s.toJson())
          .toList();

      final roundsJson = _rounds
          .where((r) => r.roundName.text.trim().isNotEmpty)
          .map((r) => r.toJson())
          .toList();

      final fallbackJd = _jdController.text.trim().isNotEmpty
          ? _jdController.text.trim()
          : (sectionsJson.isNotEmpty
                ? '${sectionsJson.first['heading']}: ${sectionsJson.first['content']}'
                : 'Campus recruitment drive');

      final payload = {
        'is_job': _isJob,
        'company_name': _companyController.text.trim(),
        'role_title': _roleController.text.trim(),
        'job_description': fallbackJd,
        'expected_package': _packageController.text.trim().isEmpty
            ? 'N/A'
            : _packageController.text.trim(),
        if (_deadline != null)
          'application_deadline': _deadline!.toUtc().toIso8601String(),

        if (sectionsJson.isNotEmpty) 'description_sections': sectionsJson,
        if (roundsJson.isNotEmpty) 'rounds': roundsJson,

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
                      ? 'Brief Summary / Overview'
                      : 'Internship Overview'),
                  hintText: 'e.g. Campus recruitment drive for 2026 batch',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              ListTile(
                title: Text(
                  _deadline == null
                      ? 'Set Application Deadline'
                      : 'Deadline: ${DateFormat('MMM d, yyyy • h:mm a').format(_deadline!.toLocal())}',
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
              // 2. Structured Description Sections
              _buildSectionTitle('2. Job Description & Dynamic Sections'),
              const Text(
                'Customize structured blocks for students (e.g. Package Breakdown, Eligibility, Location).',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._descriptionSections.asMap().entries.map((entry) {
                final index = entry.key;
                final section = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: section.heading,
                                decoration: InputDecoration(
                                  labelText: 'Section Heading ${index + 1}',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Remove Section',
                              onPressed: () => _removeDescriptionSection(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: section.content,
                          decoration: const InputDecoration(
                            labelText: 'Content / Details',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        if (section.subfields.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          const Text(
                            'Nested Subfields / Breakdown:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...section.subfields.asMap().entries.map((sfEntry) {
                            final sfIndex = sfEntry.key;
                            final sf = sfEntry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: sf.label,
                                      decoration: const InputDecoration(
                                        labelText: 'Label (e.g. Base)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: sf.value,
                                      decoration: const InputDecoration(
                                        labelText: 'Value (e.g. 24 LPA)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () =>
                                        _removeSubfield(section, sfIndex),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _addSubfield(section),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Add Subfield (e.g. Fixed/Bonus)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addDescriptionSection,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add Section Block'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              // 3. Selection Rounds Configuration
              _buildSectionTitle('3. Selection Rounds Configuration'),
              const Text(
                'Define rounds with Mode (Online/Offline), schedule Date & Time, and Syllabus.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._rounds.asMap().entries.map((entry) {
                final index = entry.key;
                final round = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                '${round.roundNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: round.roundName,
                                decoration: InputDecoration(
                                  labelText: 'Round ${round.roundNumber} Name',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              tooltip: 'Remove Round',
                              onPressed: () => _removeRound(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            // Round Type
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: round.roundType,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Round Type',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'coding',
                                    child: Text(
                                      'Coding / OA',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'technical',
                                    child: Text('Technical'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'aptitude',
                                    child: Text('Aptitude'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'hr',
                                    child: Text('HR Interview'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'group_discussion',
                                    child: Text('GD / Case Study'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => round.roundType = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 7),
                            // Round Mode (Online / Offline)
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: round.roundMode,
                                decoration: const InputDecoration(
                                  labelText: 'Mode',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Online',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.wifi,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        SizedBox(width: 6),
                                        Text('Online'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Offline',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                        SizedBox(width: 6),
                                        Text('Offline'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => round.roundMode = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Date & Time Picker
                        InkWell(
                          onTap: () => _pickRoundDateTime(round),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade50,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.event_available_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    round.roundDatetime == null
                                        ? 'Schedule Date & Time (Optional)'
                                        : DateFormat(
                                            'MMM d, yyyy • h:mm a',
                                          ).format(
                                            round.roundDatetime!.toLocal(),
                                          ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: round.roundDatetime == null
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      color: round.roundDatetime == null
                                          ? Colors.grey.shade700
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                if (round.roundDatetime != null)
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(
                                        () => round.roundDatetime = null,
                                      );
                                    },
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.grey,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Syllabus / Topics
                        TextFormField(
                          controller: round.syllabus,
                          decoration: const InputDecoration(
                            labelText: 'Syllabus / Guidelines / Topics',
                            hintText:
                                'e.g. Arrays, Strings, Dynamic Programming',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                );
              }),
              OutlinedButton.icon(
                onPressed: _addRound,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add Selection Round'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle('4. Primary Eligibility Rules'),
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
              _buildSectionTitle('5. Advanced CSV Rules'),
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
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: (criteria.isManual || _csvColumns.isEmpty)
                                  ? TextFormField(
                                      initialValue: criteria.field,
                                      decoration: const InputDecoration(
                                        labelText: 'Field (e.g. gender)',
                                        isDense: true,
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
                                        isDense: true,
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
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              tooltip: 'Delete Rule',
                              onPressed: () => _removeCustomCriteria(index),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: criteria.operator,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Operator',
                                  isDense: true,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: '==',
                                    child: Text(
                                      'Equal to',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '!=',
                                    child: Text(
                                      'Not equal to',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '>=',
                                    child: Text(
                                      'Greater than or equal to',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: '<=',
                                    child: Text(
                                      'Less than or equal to',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'contains',
                                    child: Text(
                                      'contains',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in',
                                    child: Text('in'),
                                  ),
                                ],
                                onChanged: (val) => setState(
                                  () => criteria.operator = val ?? '==',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: criteria.value.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Value',
                                  isDense: true,
                                ),
                                onChanged: (val) => criteria.value = val,
                              ),
                            ),
                          ],
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create Drive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
          color: AppColors.primary,
        ),
      ),
    );
  }
}
