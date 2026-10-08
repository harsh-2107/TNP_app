import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_chip.dart';
import '../controllers/admin_logs_controller.dart';
import '../../domain/admin_log_model.dart';

class AdminLogsPage extends ConsumerStatefulWidget {
  const AdminLogsPage({super.key});

  @override
  ConsumerState<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends ConsumerState<AdminLogsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(adminLogsControllerProvider.notifier).fetchNextPage();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(adminLogsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'System Logs',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(0, 0, 0, 0),
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: logsState.when(
        data: (state) {
          final logs = state.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'No admin logs found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final itemCount = logs.length + (state.hasMore ? 1 : 0);

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(adminLogsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: itemCount,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == logs.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final log = logs[index];
                return LogCard(log: log);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load logs',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogCard extends StatelessWidget {
  const LogCard({super.key, required this.log});

  final AdminLog log;

  String _formatAction(String action) {
    return action
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  String _formatKey(String key) {
    return key
        .split('_')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    // Determine tone based on action
    AppChipTone tone = AppChipTone.neutral;
    if (log.action.toUpperCase().contains('CREATE') ||
        log.action.toUpperCase().contains('APPROVE') ||
        log.action.toUpperCase().contains('SUCCESS')) {
      tone = AppChipTone.success;
    } else if (log.action.toUpperCase().contains('DELETE') ||
        log.action.toUpperCase().contains('REJECT') ||
        log.action.toUpperCase().contains('ERROR')) {
      tone = AppChipTone.error;
    } else if (log.action.toUpperCase().contains('UPDATE') ||
        log.action.toUpperCase().contains('EDIT') ||
        log.action.toUpperCase().contains('SEND')) {
      tone = AppChipTone.warning;
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppChip(label: _formatAction(log.action), tone: tone),
                    const SizedBox(height: 8),
                    Text(
                      log.adminName ?? log.adminEmail ?? 'Unknown Admin',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (log.adminEmail != null && log.adminName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        log.adminEmail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                dateFormat.format(log.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (log.targetId != null) ...[
            const SizedBox(height: 12),
            Text(
              'Target ID: ${log.targetId}',
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (log.details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: log.details.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatKey(e.key)}: ',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${e.value}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
