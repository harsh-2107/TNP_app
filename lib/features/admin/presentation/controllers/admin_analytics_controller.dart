import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:place_row/features/admin/data/admin_repository.dart';
import '../../domain/admin_analytics_model.dart';

final adminDrivesProvider = FutureProvider.autoDispose<List<dynamic>>((
  ref,
) async {
  final repo = ref.watch(adminRepositoryProvider);
  return await repo.getDrives();
});

final cumulativeAnalyticsProvider =
    FutureProvider.autoDispose<AdminAnalyticsModel>((ref) async {
      final drivesData = await ref.watch(adminDrivesProvider.future);
      final repo = ref.watch(adminRepositoryProvider);

      if (drivesData.isEmpty) {
        return AdminAnalyticsModel.empty();
      }

      // 2. Fetch analytics for each drive concurrently
      final analyticsFutures = drivesData.map((drive) async {
        final driveId = drive['id'] as String;
        try {
          final json = await repo.getDriveAnalytics(driveId);
          return AdminAnalyticsModel.fromJson(json);
        } catch (e) {
          // If one fails, just return empty so we don't crash the whole cumulative view
          return AdminAnalyticsModel.empty();
        }
      });

      final allAnalytics = await Future.wait(analyticsFutures);

      // 3. Aggregate all the data
      return allAnalytics.fold<AdminAnalyticsModel>(
        AdminAnalyticsModel.empty(),
        (previousValue, element) => previousValue + element,
      );
    });

final specificDriveAnalyticsProvider = FutureProvider.autoDispose
    .family<AdminAnalyticsModel, String>((ref, driveId) async {
      final repo = ref.watch(adminRepositoryProvider);
      final json = await repo.getDriveAnalytics(driveId);
      return AdminAnalyticsModel.fromJson(json);
    });
