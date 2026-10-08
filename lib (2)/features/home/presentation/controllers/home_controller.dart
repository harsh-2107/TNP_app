import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/job_repository.dart';
import '../../domain/job_model.dart';
import '../../domain/student_summary_model.dart';

class HomeState {
  const HomeState({required this.opportunities, this.summary});

  final List<CompanyDrive> opportunities;
  final StudentSummary? summary;
}

/// Drives the Home page: loads the active-opportunities feed alongside
/// the student's CGPA/year summary strip in parallel.
class HomeController extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    final repository = ref.watch(jobRepositoryProvider);
    final user = ref.watch(authControllerProvider).value;

    final results = await Future.wait([
      repository.fetchActiveOpportunities(),
      if (user != null) repository.fetchStudentSummary(user.id) else Future.value(null),
    ]);

    return HomeState(
      opportunities: results[0] as List<CompanyDrive>,
      summary: results.length > 1 ? results[1] as StudentSummary? : null,
    );
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final homeControllerProvider = AsyncNotifierProvider<HomeController, HomeState>(
  HomeController.new,
);
