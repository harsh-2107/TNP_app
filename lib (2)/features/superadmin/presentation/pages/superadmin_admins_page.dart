import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../controllers/superadmin_admins_controller.dart';

class SuperadminAdminsPage extends ConsumerStatefulWidget {
  const SuperadminAdminsPage({super.key});

  @override
  ConsumerState<SuperadminAdminsPage> createState() =>
      _SuperadminAdminsPageState();
}

class _SuperadminAdminsPageState extends ConsumerState<SuperadminAdminsPage> {
  final _identifierController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String _selectedRole = 'admin'; // 'admin', 'superadmin', 'student'
  String _selectedRoleFilter = 'all'; // 'all', 'admin', 'superadmin'
  String _searchQuery = '';
  bool _isAssigning = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _assignRole({
    String? customIdentifier,
    String? customRole,
  }) async {
    final identifier = (customIdentifier ?? _identifierController.text).trim();
    if (identifier.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a BTID or Email')),
      );
      return;
    }

    final role = customRole ?? _selectedRole;
    final isEmail = identifier.contains('@');

    setState(() => _isAssigning = true);
    FocusScope.of(context).unfocus();

    try {
      await ref
          .read(superadminAdminsControllerProvider.notifier)
          .assignRole(
            btid: isEmail ? null : identifier,
            email: isEmail ? identifier : null,
            isAdmin: role == 'admin' || role == 'superadmin',
            isSuperadmin: role == 'superadmin',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              role == 'student'
                  ? 'User privileges revoked (demoted to student).'
                  : 'Role "$role" assigned successfully.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _identifierController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHelper.getPolishedMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigning = false);
      }
    }
  }

  void _confirmDemoteToStudent(Map<String, dynamic> admin) {
    final name = admin['full_name'] ?? admin['email'] ?? 'User';
    final id = admin['email'] ?? admin['bt_id'] ?? '';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Demote Administrator'),
        content: Text(
          'Are you sure you want to revoke all administrative permissions for $name ($id)? They will be demoted to a regular student.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.pop(ctx);
              _assignRole(customIdentifier: id, customRole: 'student');
            },
            child: const Text('Demote', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _onRoleFilterSelected(String filter) {
    if (_selectedRoleFilter == filter) return;
    setState(() => _selectedRoleFilter = filter);
    ref.read(superadminAdminsControllerProvider.notifier).setRoleFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    // Watch the list of admins from the controller
    final adminsAsyncValue = ref.watch(superadminAdminsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Admins',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        actions: [
          IconButton(
            tooltip: 'Refresh list',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(superadminAdminsControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Role Assignment Form Card
          AppCard(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Assign or Update Permissions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _identifierController,
                  decoration: const InputDecoration(
                    labelText: 'Student BTID or College Email',
                    hintText: 'e.g. BT22CSE045 or student@iiitn.ac.in',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.borderStrong),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedRole,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'admin',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.security,
                                      size: 18,
                                      color: Colors.blueGrey,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Admin'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'superadmin',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shield,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 8),
                                    Text('SuperAdmin'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'student',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.person_off_outlined,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Demote to Student'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRole = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    AppButton(
                      onPressed: _isAssigning ? null : () => _assignRole(),
                      label: _isAssigning ? 'Saving...' : 'Apply',
                      isFullWidth: false,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 6.0,
            ),
            child: Column(
              children: [
                // Search Input
                TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search by name, BTID, or email...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Role Filter Chips Row
                Row(
                  children: [
                    const Text(
                      'Filter Role:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(label: 'All', value: 'all'),
                    const SizedBox(width: 6),
                    _buildFilterChip(label: 'Admins', value: 'admin'),
                    const SizedBox(width: 6),
                    _buildFilterChip(label: 'SuperAdmins', value: 'superadmin'),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Admins List
          Expanded(
            child: adminsAsyncValue.when(
              data: (admins) {
                // Apply local search query
                final filteredAdmins = admins.where((admin) {
                  if (_searchQuery.isEmpty) return true;
                  final name = (admin['full_name'] ?? '')
                      .toString()
                      .toLowerCase();
                  final btid = (admin['bt_id'] ?? '').toString().toLowerCase();
                  final email = (admin['email'] ?? '').toString().toLowerCase();
                  final branch = (admin['branch'] ?? '')
                      .toString()
                      .toLowerCase();
                  return name.contains(_searchQuery) ||
                      btid.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      branch.contains(_searchQuery);
                }).toList();

                if (filteredAdmins.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.manage_accounts_outlined,
                            size: 56,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty ||
                                    _selectedRoleFilter != 'all'
                                ? 'No administrators match your filter.'
                                : 'No administrators found.',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty ||
                              _selectedRoleFilter != 'all') ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedRoleFilter = 'all';
                                });
                                ref
                                    .read(
                                      superadminAdminsControllerProvider
                                          .notifier,
                                    )
                                    .setRoleFilter('all');
                              },
                              icon: const Icon(Icons.clear_all),
                              label: const Text('Reset filters'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(superadminAdminsControllerProvider.notifier)
                        .refresh();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filteredAdmins.length,
                    itemBuilder: (context, index) {
                      final admin = filteredAdmins[index];
                      final isSuper = admin['is_superadmin'] == true;
                      final name = admin['full_name'] ?? 'Unknown';
                      final email = admin['email'] ?? '';
                      final btid = admin['bt_id'] ?? '';

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              /*
                              if (btid.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    btid,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                              */
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildRoleBadge(isSuper: isSuper),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) {
                                  if (action == 'edit') {
                                    setState(() {
                                      _identifierController.text =
                                          email.isNotEmpty ? email : btid;
                                      _selectedRole = isSuper
                                          ? 'superadmin'
                                          : 'admin';
                                    });
                                    _scrollController.animateTo(
                                      0,
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                  } else if (action == 'make_super') {
                                    _assignRole(
                                      customIdentifier: email.isNotEmpty
                                          ? email
                                          : btid,
                                      customRole: 'superadmin',
                                    );
                                  } else if (action == 'make_admin') {
                                    _assignRole(
                                      customIdentifier: email.isNotEmpty
                                          ? email
                                          : btid,
                                      customRole: 'admin',
                                    );
                                  } else if (action == 'demote') {
                                    _confirmDemoteToStudent(admin);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit in form'),
                                      ],
                                    ),
                                  ),
                                  if (!isSuper)
                                    const PopupMenuItem(
                                      value: 'make_super',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.shield,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Promote to SuperAdmin'),
                                        ],
                                      ),
                                    )
                                  else
                                    const PopupMenuItem(
                                      value: 'make_admin',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.security,
                                            size: 16,
                                            color: Colors.blueGrey,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Set as standard Admin'),
                                        ],
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'demote',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_remove,
                                          size: 16,
                                          color: AppColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Demote to student',
                                          style: TextStyle(
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            setState(() {
                              _identifierController.text = email.isNotEmpty
                                  ? email
                                  : btid;
                              _selectedRole = isSuper ? 'superadmin' : 'admin';
                            });
                          },
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        ErrorHelper.getPolishedMessage(err),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          ref
                              .read(superadminAdminsControllerProvider.notifier)
                              .refresh();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({required String label, required String value}) {
    final isSelected = _selectedRoleFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryLight.withValues(alpha: 0.35),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (_) => _onRoleFilterSelected(value),
    );
  }

  Widget _buildRoleBadge({required bool isSuper}) {
    if (isSuper) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield, size: 12, color: AppColors.primary),
            SizedBox(width: 4),
            Text(
              'SuperAdmin',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withValues(alpha: 0.3)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.security, size: 12, color: Colors.blueGrey),
          SizedBox(width: 4),
          Text(
            'Admin',
            style: TextStyle(
              color: Colors.blueGrey,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
