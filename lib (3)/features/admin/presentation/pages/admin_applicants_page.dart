import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/error_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_rounds_page.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/admin_repository.dart';

class AdminApplicantsPage extends ConsumerStatefulWidget {
  const AdminApplicantsPage({super.key});

  @override
  ConsumerState<AdminApplicantsPage> createState() =>
      _AdminApplicantsPageState();
}

class _AdminApplicantsPageState extends ConsumerState<AdminApplicantsPage> {
  // Available companies fetched from drives
  List<String> _availableCompanies = [];
  Map<String, String> _companyToJobId = {};
  bool _isLoadingCompanies = true;

  // Selected companies for multi-selectable filter
  List<String> _selectedCompanies = [];

  // Optional backend filters
  String _roleTitle = '';
  String _branch = '';

  // Local advanced filters
  String _studentNameQuery = '';
  String _btIdQuery = '';
  double _minCgpa = 0.0;
  String _statusFilter = 'All';

  List<dynamic> _allApplicants = [];
  bool _hasSearched = false;
  bool _isLoading = false;
  bool _showAdvancedFilters = false;
  String? _updatingAppId;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      final repository = ref.read(adminRepositoryProvider);
      final drives = await repository.getDrives();
      final Map<String, String> compToJob = {};
      final Set<String> comps = {};

      for (final d in drives) {
        final cName = (d['company_name'] ?? '').toString().trim();
        final jId = (d['id'] ?? '').toString().trim();
        if (cName.isNotEmpty) {
          comps.add(cName);
          if (jId.isNotEmpty && !compToJob.containsKey(cName)) {
            compToJob[cName] = jId;
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableCompanies = comps.toList()..sort();
          _companyToJobId = compToJob;
          _isLoadingCompanies = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCompanies = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    }
  }

  Future<void> _fetchApplicants() async {
    if (_selectedCompanies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one company from the dropdown.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final repository = ref.read(adminRepositoryProvider);
      final applicants = await repository.getApplicants(
        companyNames: _selectedCompanies,
        roleTitle: _roleTitle.isNotEmpty ? _roleTitle : null,
        branch: _branch.isNotEmpty ? _branch : null,
      );
      if (mounted) {
        setState(() {
          _allApplicants = applicants;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    }
  }

  List<dynamic> get _filteredApplicants {
    return _allApplicants.where((app) {
      final name = (app['full_name'] ?? '').toString().toLowerCase();
      final btId = (app['bt_id'] ?? '').toString().toLowerCase();
      final status = (app['application_status'] ?? '').toString().toLowerCase();
      final cgpa = (app['cgpa'] as num?)?.toDouble() ?? 0.0;

      if (_studentNameQuery.isNotEmpty &&
          !name.contains(_studentNameQuery.toLowerCase())) {
        return false;
      }

      if (_btIdQuery.isNotEmpty && !btId.contains(_btIdQuery.toLowerCase())) {
        return false;
      }
      if (_statusFilter != 'All' && status != _statusFilter.toLowerCase()) {
        return false;
      }
      if (cgpa < _minCgpa) return false;

      return true;
    }).toList();
  }

  Future<void> _openCompanyFilterDialog() async {
    if (_availableCompanies.isEmpty && !_isLoadingCompanies) {
      await _loadCompanies();
    }

    if (_availableCompanies.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active companies/drives found.')),
        );
      }
      return;
    }

    final tempSelected = Set<String>.from(_selectedCompanies);
    String searchQuery = '';

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filteredCompanies = _availableCompanies.where((c) {
              return c.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              expand: false,
              builder: (sheetCtx, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Companies',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tempSelected.length} of ${_availableCompanies.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search input
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search companies...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (val) {
                          setModalState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 8),
                      // Quick actions: Select All & Clear
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.select_all, size: 18),
                            label: const Text('Select All'),
                            onPressed: () {
                              setModalState(() {
                                tempSelected.addAll(_availableCompanies);
                              });
                            },
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear All'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: () {
                              setModalState(() {
                                tempSelected.clear();
                              });
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 1),
                      // Company Checkbox List
                      Expanded(
                        child: filteredCompanies.isEmpty
                            ? const Center(
                                child: Text(
                                  'No matching companies found',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filteredCompanies.length,
                                itemBuilder: (context, idx) {
                                  final company = filteredCompanies[idx];
                                  final isChecked = tempSelected.contains(company);
                                  return CheckboxListTile(
                                    title: Text(
                                      company,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isChecked
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isChecked
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    value: isChecked,
                                    activeColor: AppColors.primary,
                                    dense: true,
                                    onChanged: (bool? val) {
                                      setModalState(() {
                                        if (val == true) {
                                          tempSelected.add(company);
                                        } else {
                                          tempSelected.remove(company);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      // Confirm button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop(tempSelected);
                          },
                          child: Text(
                            tempSelected.isEmpty
                                ? 'Done (0 Selected)'
                                : 'Apply (${tempSelected.length} Selected)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCompanies = result.toList()..sort();
      });
      if (_selectedCompanies.isNotEmpty) {
        _fetchApplicants();
      } else {
        setState(() {
          _allApplicants = [];
          _hasSearched = false;
        });
      }
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCompanies.clear();
      _allApplicants.clear();
      _hasSearched = false;
      _roleTitle = '';
      _branch = '';
      _studentNameQuery = '';
      _btIdQuery = '';
      _minCgpa = 0.0;
      _statusFilter = 'All';
    });
  }

  Future<void> _updateApplicantStatus(
    String applicationId,
    String newStatus,
  ) async {
    setState(() => _updatingAppId = applicationId);
    try {
      final repository = ref.read(adminRepositoryProvider);
      await repository.updateApplicantStatus(applicationId, newStatus);
      if (mounted) {
        setState(() {
          final target = _allApplicants.firstWhere(
            (a) => a['application_id']?.toString() == applicationId,
            orElse: () => null,
          );
          if (target != null) {
            target['application_status'] = newStatus;
          }
          _updatingAppId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus == 'selected'
                  ? 'Applicant Approved successfully!'
                  : 'Applicant Rejected successfully!',
            ),
            backgroundColor:
                newStatus == 'selected' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _updatingAppId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorHelper.getPolishedMessage(e))),
        );
      }
    }
  }

  Future<void> _manageRounds() async {
    String targetJobId = '';
    if (_selectedCompanies.length == 1) {
      targetJobId = _companyToJobId[_selectedCompanies.first] ?? '';
    }
    if (targetJobId.isEmpty && _filteredApplicants.isNotEmpty) {
      targetJobId = _filteredApplicants.first['job_id']?.toString() ?? '';
    }

    if (targetJobId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a specific company to manage drive rounds.',
          ),
        ),
      );
      return;
    }

    final companyTitle = _selectedCompanies.length == 1
        ? _selectedCompanies.first
        : (_filteredApplicants.isNotEmpty
            ? _filteredApplicants.first['company_name'] ?? 'Drive'
            : 'Drive');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminRoundsPage(
          driveId: targetJobId,
          companyName: companyTitle,
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    // 1. Resolve target drive / company
    String? targetJobId;

    if (_selectedCompanies.length == 1) {
      targetJobId = _companyToJobId[_selectedCompanies.first] ?? '';
    } else if (_selectedCompanies.length > 1) {
      // Prompt user to select which drive to export or export all
      targetJobId = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text(
            'Export Applicants CSV',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text(
                'Choose a specific company drive or export across all:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 8),
            ..._selectedCompanies.map((company) {
              final jobId = _companyToJobId[company] ?? '';
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, jobId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment_rounded,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          company,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'ALL'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18, color: Colors.green),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Export All Applicants (Across Drives)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

      if (targetJobId == null) return; // User cancelled dialog
    } else if (_selectedCompanies.isEmpty) {
      if (_filteredApplicants.isNotEmpty) {
        targetJobId = _filteredApplicants.first['job_id']?.toString() ?? '';
      }
    }

    if ((targetJobId == null || targetJobId.isEmpty) &&
        _selectedCompanies.isEmpty &&
        _allApplicants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a company and fetch applicants first to export CSV.',
          ),
        ),
      );
      return;
    }

    // 2. Build URL using AdminRepository with all active filters
    final repo = ref.read(adminRepositoryProvider);
    final url = repo.getApplicantsCsvExportUri(
      driveId: targetJobId,
      studentName: _studentNameQuery,
      btId: _btIdQuery,
      minCgpa: _minCgpa,
      status: _statusFilter,
    );

    // 3. User feedback & Launch URL
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading CSV export with applied filters...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open the export URL: $url'),
              backgroundColor: AppColors.error,
            ),
          );
        }
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedApplicants = _filteredApplicants;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'View Applicants',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Manage Rounds',
            icon: const Icon(Icons.assessment_outlined),
            onPressed: _manageRounds,
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_rounded),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: 'Toggle Advanced Filters',
            icon: Icon(
              Icons.tune_rounded,
              color: _showAdvancedFilters ? AppColors.primary : null,
            ),
            onPressed: () {
              setState(() => _showAdvancedFilters = !_showAdvancedFilters);
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _selectedCompanies.isNotEmpty ? _fetchApplicants : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Multi-Select Companies Section
          _buildCompanySelectorHeader(),

          // Optional Advanced Filters (Search by Student Name, BTID, Status, CGPA)
          if (_showAdvancedFilters && _hasSearched)
            _buildAdvancedFiltersPanel(),

          // Main Content Area
          Expanded(
            child: _buildMainContent(displayedApplicants),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanySelectorHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_alt, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Filter by Companies',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (_selectedCompanies.isNotEmpty)
                TextButton(
                  onPressed: _clearAllFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(50, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red,
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Tappable Multi-Select Dropdown Container
          InkWell(
            onTap: _openCompanyFilterDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _selectedCompanies.isNotEmpty
                      ? AppColors.primary
                      : AppColors.border,
                  width: _selectedCompanies.isNotEmpty ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment_rounded,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _isLoadingCompanies
                        ? const Text(
                            'Loading available companies...',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : Text(
                            _selectedCompanies.isEmpty
                                ? 'Select companies to view applicants (Multi-Select)...'
                                : _selectedCompanies.length ==
                                        _availableCompanies.length
                                    ? 'All Companies Selected (${_availableCompanies.length})'
                                    : '${_selectedCompanies.length} selected: ${_selectedCompanies.take(2).join(', ')}${_selectedCompanies.length > 2 ? '...' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _selectedCompanies.isNotEmpty
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: _selectedCompanies.isNotEmpty
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  const Icon(Icons.arrow_drop_down,
                      color: AppColors.primary, size: 26),
                ],
              ),
            ),
          ),

          // Selected Company Chips Display
          if (_selectedCompanies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedCompanies.map((company) {
                return Chip(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3)),
                  label: Text(
                    company,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  deleteIcon:
                      const Icon(Icons.close, size: 14, color: AppColors.primary),
                  onDeleted: () {
                    setState(() {
                      _selectedCompanies.remove(company);
                    });
                    if (_selectedCompanies.isNotEmpty) {
                      _fetchApplicants();
                    } else {
                      setState(() {
                        _allApplicants = [];
                        _hasSearched = false;
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _studentNameQuery = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'BT ID',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _btIdQuery = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Min CGPA',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => setState(
                    () => _minCgpa = double.tryParse(val) ?? 0.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _statusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Applied', child: Text('Applied')),
                    DropdownMenuItem(
                        value: 'Shortlisted', child: Text('Shortlisted')),
                    DropdownMenuItem(
                        value: 'Rejected', child: Text('Rejected')),
                    DropdownMenuItem(
                        value: 'Selected', child: Text('Selected')),
                  ],
                  onChanged: (val) =>
                      setState(() => _statusFilter = val ?? 'All'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(List<dynamic> displayedApplicants) {
    if (!_hasSearched || _selectedCompanies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apartment_rounded,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Companies to View Applicants',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use the company dropdown filter above to choose one or more companies. The server will fetch only the applicants belonging to your selected companies.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openCompanyFilterDialog,
                icon: const Icon(Icons.arrow_drop_down_circle_outlined),
                label: const Text(
                  'Choose Companies',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (displayedApplicants.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No applicants found for the selected companies.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openCompanyFilterDialog,
              child: const Text('Change Company Selection'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayedApplicants.length} applicants',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Across ${_selectedCompanies.length} company(ies)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: displayedApplicants.length,
            itemBuilder: (context, index) {
              final app = displayedApplicants[index];
              return _buildApplicantCard(app);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildApplicantCard(dynamic app) {
    final statusLower =
        (app['application_status'] ?? '').toString().toLowerCase();
    final isApproved = statusLower == 'selected' ||
        statusLower == 'accepted' ||
        statusLower == 'approved';
    final isRejected = statusLower == 'rejected' || statusLower == 'failed';
    final isPending = !isApproved && !isRejected;
    final isUpdatingThis = _updatingAppId == app['application_id']?.toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                app['full_name']?.toString().substring(0, 1).toUpperCase() ??
                    '?',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: Text(
              '${app['full_name']} (${app['bt_id']})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Company: ${app['company_name']} • ${app['role_title']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Branch: ${app['branch']} | CGPA: ${app['cgpa']}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('Status: ', style: TextStyle(fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? Colors.green.shade50
                            : isRejected
                                ? Colors.red.shade50
                                : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isApproved
                              ? Colors.green
                              : isRejected
                                  ? Colors.red
                                  : Colors.orange,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        app['application_status']?.toString().toUpperCase() ??
                            'APPLIED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApproved
                              ? Colors.green.shade800
                              : isRejected
                                  ? Colors.red.shade800
                                  : Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: app['resume_link'] != 'N/A' && app['resume_link'] != null
                ? IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      final uri = Uri.tryParse(app['resume_link'].toString());
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  )
                : null,
            isThreeLine: true,
          ),
          if (isPending) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isUpdatingThis)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    OutlinedButton.icon(
                      onPressed: () => _updateApplicantStatus(
                        app['application_id'].toString(),
                        'rejected',
                      ),
                      icon: const Icon(Icons.close, size: 16, color: Colors.red),
                      label: const Text(
                        'Reject',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: const Size(90, 34),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _updateApplicantStatus(
                        app['application_id'].toString(),
                        'selected',
                      ),
                      icon: const Icon(Icons.check, size: 16, color: Colors.white),
                      label: const Text(
                        'Approve',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        minimumSize: const Size(90, 34),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
