import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/superadmin_repository.dart';

class SuperadminAdminsController extends AsyncNotifier<List<dynamic>> {
  String _currentRoleFilter = 'all';

  String get currentRoleFilter => _currentRoleFilter;

  @override
  Future<List<dynamic>> build() async {
    final repo = ref.watch(superadminRepositoryProvider);
    return repo.getAdmins(role: _currentRoleFilter == 'all' ? null : _currentRoleFilter);
  }

  Future<void> setRoleFilter(String role) async {
    if (_currentRoleFilter == role) return;
    _currentRoleFilter = role;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(superadminRepositoryProvider);
      return repo.getAdmins(role: _currentRoleFilter == 'all' ? null : _currentRoleFilter);
    });
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(superadminRepositoryProvider);
      return repo.getAdmins(role: _currentRoleFilter == 'all' ? null : _currentRoleFilter);
    });
  }

  Future<void> assignRole({
    String? btid,
    String? email,
    required bool isSuperadmin,
    required bool isAdmin,
  }) async {
    final repo = ref.read(superadminRepositoryProvider);

    final payload = <String, dynamic>{
      'is_superadmin': isSuperadmin,
      'is_admin': isAdmin,
    };
    if (btid != null && btid.isNotEmpty) {
      payload['bt_id'] = btid;
      payload['identifier'] = btid;
    } else if (email != null && email.isNotEmpty) {
      payload['email'] = email;
      payload['identifier'] = email;
    } else {
      throw Exception('Must provide either BTID or Email');
    }

    await repo.assignRole(payload);
    // Refresh the list after assigning a new role
    ref.invalidateSelf();
    await future;
  }
}

final superadminAdminsControllerProvider =
    AsyncNotifierProvider<SuperadminAdminsController, List<dynamic>>(
      SuperadminAdminsController.new,
    );

