import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/superadmin_repository.dart';
import '../controllers/superadmin_students_controller.dart';

class SuperadminStudentsPage extends ConsumerStatefulWidget {
  const SuperadminStudentsPage({super.key});

  @override
  ConsumerState<SuperadminStudentsPage> createState() =>
      _SuperadminStudentsPageState();
}

class _SuperadminStudentsPageState
    extends ConsumerState<SuperadminStudentsPage> {
  bool _isImporting = false;

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes == null) {
          throw Exception("File bytes are empty");
        }

        setState(() {
          _isImporting = true;
        });

        await ref
            .read(superadminRepositoryProvider)
            .batchImportCsv(file.bytes!.toList(), file.name);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV Imported Successfully')),
          );
        }
        ref.invalidate(superadminStudentsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to import CSV: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _downloadSampleCsv() async {
    const sampleCsv =
        'bt_id,full_name,email,branch,cgpa,backlogs,phone_number,tenth_percentage,twelfth_percentage,education_gaps\n';
    final bytes = Uint8List.fromList(utf8.encode(sampleCsv));

    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Sample Students CSV Template',
        fileName: 'students_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
      );

      if (savePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sample CSV template saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save template: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.table_chart_outlined,
              color: AppColors.primary,
              size: 24,
            ),
            SizedBox(width: 10),
            Text(
              'Bulk Student CSV Import',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload a CSV file containing student roster details to enroll or update students in bulk.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Required Columns:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• bt_id (or roll_number, student_id)\n• full_name (or name)\n• email (or college_email)\n• branch (defaults to CSE)\n• cgpa (defaults to 0.0)\n• backlogs (defaults to 0)\n• phone_number\n• tenth_percentage\n• twelfth_percentage\n• education_gaps',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _downloadSampleCsv,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download Sample CSV Template'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _importCsv();
            },
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Choose & Upload CSV'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this student? This action cannot be undone and may fail if there are foreign key constraints.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(superadminRepositoryProvider).deleteStudent(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Student deleted')));
      }
      ref.invalidate(superadminStudentsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete student: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showStudentDialog({Map<String, dynamic>? student}) {
    showDialog(
      context: context,
      builder: (context) {
        return _StudentFormDialog(student: student);
      },
    ).then((_) {
      ref.invalidate(superadminStudentsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(superadminStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Student Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Import CSV',
            icon: _isImporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.upload_file),
            onPressed: _isImporting ? null : _showBulkImportDialog,
          ),
          IconButton(
            tooltip: 'Add Student',
            icon: const Icon(Icons.add),
            onPressed: () => _showStudentDialog(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superadminStudentsProvider);
        },
        child: studentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return const Center(child: Text('No students found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      student['full_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${student['email']} • ${student['branch'] ?? 'N/A'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: AppColors.primary,
                          ),
                          onPressed: () => _showStudentDialog(student: student),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: AppColors.error,
                          ),
                          onPressed: () => _deleteStudent(student['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}

class _StudentFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? student;

  const _StudentFormDialog({this.student});

  @override
  ConsumerState<_StudentFormDialog> createState() => _StudentFormDialogState();
}

class _StudentFormDialogState extends ConsumerState<_StudentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _branchController;
  late TextEditingController _courseController;
  late TextEditingController _btidController;
  late TextEditingController _cgpaController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.student?['full_name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.student?['email'] ?? '',
    );
    _branchController = TextEditingController(
      text: widget.student?['branch'] ?? '',
    );
    _courseController = TextEditingController(
      text: widget.student?['course'] ?? '',
    );
    _btidController = TextEditingController(
      text: widget.student?['btid'] ?? '',
    );
    _cgpaController = TextEditingController(
      text: widget.student?['cgpa']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _branchController.dispose();
    _courseController.dispose();
    _btidController.dispose();
    _cgpaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = {
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'branch': _branchController.text.trim(),
        'course': _courseController.text.trim(),
        'btid': _btidController.text.trim(),
        if (_cgpaController.text.trim().isNotEmpty)
          'cgpa': double.tryParse(_cgpaController.text.trim()),
      };

      if (widget.student == null) {
        await ref.read(superadminRepositoryProvider).createStudent(payload);
      } else {
        await ref
            .read(superadminRepositoryProvider)
            .updateStudent(widget.student!['id'], payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.student == null ? 'Add Student' : 'Edit Student'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _btidController,
                decoration: const InputDecoration(labelText: 'BTID'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(labelText: 'Branch'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _courseController,
                decoration: const InputDecoration(labelText: 'Course'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cgpaController,
                decoration: const InputDecoration(labelText: 'CGPA'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        AppButton(
          onPressed: _isLoading ? null : _submit,
          isLoading: _isLoading,
          label: 'Save',
        ),
      ],
    );
  }
}
