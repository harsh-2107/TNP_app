import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../admin/data/admin_repository.dart';

final superadminDrivesProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getDrives();
});
