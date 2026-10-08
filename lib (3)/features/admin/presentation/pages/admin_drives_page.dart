import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/core/theme/app_colors.dart';
import 'package:place_row/core/errors/error_helper.dart';
import 'package:place_row/features/admin/presentation/pages/admin_rounds_page.dart';
import '../../data/admin_repository.dart';

class AdminDrivesPage extends ConsumerStatefulWidget {
  const AdminDrivesPage({super.key});

  @override
  ConsumerState<AdminDrivesPage> createState() => _AdminDrivesPageState();
}

class _AdminDrivesPageState extends ConsumerState<AdminDrivesPage> {
  List<dynamic> _drives = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDrives();
  }

  Future<void> _fetchDrives() async {
    setState(() => _isLoading = true);
    try {
      final repository = ref.read(adminRepositoryProvider);
      final drives = await repository.getDrives();
      setState(() => _drives = drives);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAdvancedRules(BuildContext context, Map<String, dynamic> drive) {
    showDialog(
      context: context,
      builder: (ctx) {
        final rules = Map<String, dynamic>.from(
          drive['eligibility_rules'] ?? {},
        );
        final conditionsList =
            (rules['conditions'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.surface,
          elevation: 10,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(0),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Eligibility Rules',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            drive['company_name'] ?? 'Company',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 24),

                // Rules Content
                if (conditionsList.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No specific eligibility rules defined.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                AppColors.primary.withValues(alpha: 0.05),
                              ),
                              dataRowMinHeight: 48,
                              dataRowMaxHeight: 56,
                              dividerThickness: 1,
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'Field',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Condition',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Value',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                              rows: conditionsList.map((cond) {
                                final field =
                                    cond['field']?.toString() ?? 'Unknown';
                                final operator =
                                    cond['operator']?.toString() ?? '';
                                final valueObj = cond['value'];

                                String conditionText = operator;
                                switch (operator) {
                                  case '>=':
                                    conditionText = 'Minimum';
                                    break;
                                  case '<=':
                                    conditionText = 'Maximum';
                                    break;
                                  case '==':
                                    conditionText = 'Exact';
                                    break;
                                  case 'in':
                                    conditionText = 'Allowed';
                                    break;
                                  case 'not in':
                                    conditionText = 'Excluded';
                                    break;
                                  case '>':
                                    conditionText = 'Greater than';
                                    break;
                                  case '<':
                                    conditionText = 'Less than';
                                    break;
                                }

                                String fieldText = field
                                    .replaceAll('_', ' ')
                                    .toUpperCase();
                                IconData icon = Icons.rule_folder_outlined;

                                if (field == 'cgpa') {
                                  fieldText = 'CGPA';
                                  icon = Icons.school;
                                } else if (field == 'backlogs') {
                                  fieldText = 'Active Backlogs';
                                  icon = Icons.warning_amber_rounded;
                                } else if (field == 'total_backlogs') {
                                  fieldText = 'Total Backlogs';
                                  icon = Icons.history;
                                } else if (field == 'branch') {
                                  fieldText = 'Branches';
                                  icon = Icons.account_tree_outlined;
                                } else if (field == 'education_gaps') {
                                  fieldText = 'Education Gaps';
                                  icon = Icons.timeline_rounded;
                                } else if (field == 'batch') {
                                  fieldText = 'Batch';
                                  icon = Icons.groups;
                                }

                                String valueText = valueObj?.toString() ?? '';
                                if (valueObj is List) {
                                  valueText = valueObj.join(', ');
                                }

                                return _buildDataRow(
                                  icon,
                                  fieldText,
                                  conditionText,
                                  valueText,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  DataRow _buildDataRow(
    IconData icon,
    String field,
    String condition,
    String value,
  ) {
    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                field,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              condition,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  int? expandedIndex;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Placement Drives'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDrives),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drives.isEmpty
          ? const Center(child: Text('No placement drives found.'))
          : ListView.builder(
              itemCount: _drives.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemBuilder: (context, index) {
                final isExpanded = expandedIndex == index;
                final drive = _drives[index];
                final rawData = drive['raw_csv_data'] ?? {};
                final status = (drive['status'] ?? 'Open')
                    .toString()
                    .toUpperCase();

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(0),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowLight,
                        offset: const Offset(-6, -6),
                        blurRadius: 12,
                      ),
                      BoxShadow(
                        color: AppColors.shadowDark.withValues(alpha: 0.4),
                        offset: const Offset(6, 6),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(width: 16),

                                  // Drive Information
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          drive['company_name'] ??
                                              'Unknown Company',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18,
                                            color: AppColors.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          drive['role_title'] ??
                                              'Role not specified',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _buildBadge(
                                              status,
                                              status == 'OPEN'
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                              status == 'OPEN'
                                                  ? Colors.green.shade50
                                                  : Colors.orange.shade50,
                                            ),
                                            if (rawData['expected_package'] !=
                                                null)
                                              _buildBadge(
                                                rawData['expected_package'],
                                                AppColors.textSecondary,
                                                AppColors.surfaceMuted,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Expand Icon
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Expanded Details Area
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: Alignment.topCenter,
                              child: isExpanded
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted
                                            .withValues(alpha: 0.5),
                                        border: const Border(
                                          top: BorderSide(
                                            color: AppColors.border,
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildDetailRow(
                                            Icons.description_outlined,
                                            'Description',
                                            rawData['job_description'] ??
                                                'No description provided',
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _buildDetailRow(
                                                  Icons.event_outlined,
                                                  'Created',
                                                  drive['created_at']
                                                          ?.toString()
                                                          .split('T')
                                                          .first ??
                                                      'N/A',
                                                ),
                                              ),
                                              Expanded(
                                                child: _buildDetailRow(
                                                  Icons.timer_outlined,
                                                  'Deadline',
                                                  drive['application_deadline']
                                                          ?.toString()
                                                          .split('T')
                                                          .first ??
                                                      'N/A',
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => AdminRoundsPage(
                                                    driveId: drive['id']
                                                        .toString(),
                                                    companyName:
                                                        drive['company_name'] ??
                                                        'Company',
                                                  ),
                                                ),
                                              );
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AppColors.primary,
                                              side: const BorderSide(
                                                color: AppColors.primary,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons
                                                  .format_list_numbered_rounded,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'Manage Rounds',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _showAdvancedRules(
                                              context,
                                              drive,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                            icon: const Icon(
                                              Icons.rule,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              'View Eligibility Rules',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildBadge(String text, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
