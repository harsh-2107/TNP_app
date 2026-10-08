import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/superadmin_repository.dart';

final superadminStudentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repo = ref.watch(superadminRepositoryProvider);
  return repo.getStudents();
});
