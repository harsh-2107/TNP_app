import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../admin/presentation/pages/admin_logs_page.dart';
import '../controllers/superadmin_logs_controller.dart';

class SuperadminLogsPage extends ConsumerStatefulWidget {
  const SuperadminLogsPage({super.key});

  @override
  ConsumerState<SuperadminLogsPage> createState() => _SuperadminLogsPageState();
}

class _SuperadminLogsPageState extends ConsumerState<SuperadminLogsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(superadminLogsControllerProvider.notifier).fetchNextPage();
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
    final logsState = ref.watch(superadminLogsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'System Audit Logs',
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
                'No system audit logs found.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          final itemCount = logs.length + (state.hasMore ? 1 : 0);

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(superadminLogsControllerProvider.notifier).refresh(),
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
                'Failed to load audit logs',
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(superadminLogsControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
