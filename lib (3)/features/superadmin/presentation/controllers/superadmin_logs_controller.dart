import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/domain/admin_log_model.dart';
import '../../../admin/presentation/controllers/admin_logs_controller.dart';
import '../../data/superadmin_repository.dart';

class SuperadminLogsController extends AsyncNotifier<AdminLogsState> {
  static const int pageSize = 10;
  int _offset = 0;

  @override
  Future<AdminLogsState> build() async {
    _offset = 0;
    return _fetchInitialLogs();
  }

  Future<AdminLogsState> _fetchInitialLogs() async {
    final repo = ref.read(superadminRepositoryProvider);
    final rawLogs = await repo.getAuditLogs(limit: pageSize, offset: 0);

    if (kDebugMode) {
      print('SuperadminLogs Initial Response count: ${rawLogs.length}');
    }

    final logs = rawLogs
        .map((log) => AdminLog.fromJson(log as Map<String, dynamic>))
        .toList();
    _offset = logs.length;

    return AdminLogsState(
      logs: logs,
      hasMore: logs.length >= pageSize,
      isLoadingMore: false,
    );
  }

  Future<void> fetchNextPage() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(superadminRepositoryProvider);
      final rawLogs = await repo.getAuditLogs(limit: pageSize, offset: _offset);

      final newLogs = rawLogs
          .map((log) => AdminLog.fromJson(log as Map<String, dynamic>))
          .toList();
      _offset += newLogs.length;

      state = AsyncData(current.copyWith(
        logs: [...current.logs, ...newLogs],
        hasMore: newLogs.length >= pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching next page of superadmin logs: $e');
      }
      state = AsyncData(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> refresh() async {
    _offset = 0;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchInitialLogs);
  }
}

final superadminLogsControllerProvider =
    AsyncNotifierProvider<SuperadminLogsController, AdminLogsState>(
        SuperadminLogsController.new);
