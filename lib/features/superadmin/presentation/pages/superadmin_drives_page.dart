import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/superadmin_repository.dart';
import '../controllers/superadmin_drives_controller.dart';

class SuperadminDrivesPage extends ConsumerWidget {
  const SuperadminDrivesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivesAsync = ref.watch(superadminDrivesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Drive Overrides',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(superadminDrivesProvider);
        },
        child: drivesAsync.when(
          data: (drives) {
            if (drives.isEmpty) {
              return const Center(child: Text('No drives found.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: drives.length,
              itemBuilder: (context, index) {
                final drive = drives[index];
                return _DriveCard(drive: drive);
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

class _DriveCard extends ConsumerWidget {
  final Map<String, dynamic> drive;

  const _DriveCard({required this.drive});

  void _showForceApplyDialog(BuildContext context, WidgetRef ref) {
    final studentIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Force Apply Student'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter the Student BTID to force-apply them to this drive. This overrides all eligibility checks.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: studentIdController,
                    decoration: const InputDecoration(
                      labelText: 'Student BTID',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                AppButton(
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          final id = studentIdController.text.trim();
                          if (id.isEmpty) return;

                          setState(() => isLoading = true);
                          try {
                            await ref
                                .read(superadminRepositoryProvider)
                                .forceApplyStudentToDrive(drive['id'], id);
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Student forcefully applied!'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  label: 'Force Apply',
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Force Delete Drive'),
        content: const Text(
          'This will delete the drive and cascade to all its rounds and applications. Proceed with extreme caution!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref
                    .read(superadminRepositoryProvider)
                    .forceDeleteDrive(drive['id']);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Drive deleted')),
                  );
                }
                ref.invalidate(superadminDrivesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Force Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    // A simplified override dialog
    final statusController = TextEditingController(text: drive['status'] ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Override Drive Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Force change the status (e.g., open, closed).'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: statusController,
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                AppButton(
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            await ref
                                .read(superadminRepositoryProvider)
                                .updateDrive(drive['id'], {
                                  'status': statusController.text.trim(),
                                });
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Drive updated')),
                              );
                            }
                            ref.invalidate(superadminDrivesProvider);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          } finally {
                            setState(() => isLoading = false);
                          }
                        },
                  label: 'Save',
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    drive['company_name'] ?? 'Unknown Company',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (drive['status'] ?? 'unknown').toString().toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(drive['role_title'] ?? 'N/A'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppButton(
                  onPressed: () => _showForceApplyDialog(context, ref),
                  isSmall: true,
                  variant: AppButtonVariant.tertiary,
                  label: 'Force Apply Student',
                ),
                AppButton(
                  onPressed: () => _showDeleteDialog(context, ref),
                  isSmall: true,
                  variant: AppButtonVariant.outline,
                  label: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
