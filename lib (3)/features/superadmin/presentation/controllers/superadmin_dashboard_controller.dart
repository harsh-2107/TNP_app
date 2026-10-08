import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/superadmin_repository.dart';

final superadminStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(superadminRepositoryProvider);
  return repo.getStats();
});

final superadminDatabaseOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(superadminRepositoryProvider);
  return repo.getDatabaseOverview();
});
