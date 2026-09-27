// ignore_for_file: prefer_final_fields

part of 'package:schedular/main.dart';

class MachineEntryPage extends StatefulWidget {
  const MachineEntryPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<MachineEntryPage> createState() => _MachineEntryPageState();
}

class _MachineEntryPageState extends State<MachineEntryPage> {
  static const double _phoneLayoutMaxWidth = 600;
  static const double _tabletLayoutMaxWidth = 1024;
  static const String _webDatabaseNotice =
      'PWA notice: database functions are not available on web builds. '
      'Data is temporary for this browser session only.';
  static const String _optionalMachineFieldsPreferenceKey =
      'machineForm.optionalFields';
  static const String _optionalSubAssemblyFieldsPreferenceKey =
      'subAssemblyForm.optionalFields';
  static const String _employeeSearchPreferenceKey = 'employeeList.searchQuery';
  static const String _employeeFilterSkillPreferenceKey =
      'employeeList.filterSkill';
  static const String _employeeSortPreferenceKey = 'employeeList.sortMode';
  static const String _vendorsSearchPreferenceKey = 'vendors.searchQuery';
  static const String _vendorsSortPreferenceKey = 'vendors.sortMode';
  static const String _vendorsIncludeUnspecifiedPreferenceKey =
      'vendors.includeUnspecified';
  static const String _forecastPartsBucketPreferenceKey =
      'forecast.parts.selectedBucket';
  static const List<String> _defaultEmployeeSkills = [
    'Electrical',
    'Mechanical',
    'HVAC',
    'Diagnostics',
    'Welding',
  ];
  static const List<String> _baseLicenseTypes = [
    'HVAC',
    'Refrigeration',
    'Plumber',
    'Electrician',
    'Boiler',
  ];
  static final GlobalKey _licenseTypeSectionKey = GlobalKey();

  String? _selectedEmployeeFilterSkill;
  _EmployeeSortMode _employeeSortMode = _EmployeeSortMode.nameAsc;
  String _employeeSearchQuery = '';
  final Set<String> _selectedEmployeeSkills = <String>{};
  final Set<String> _selectedEmployeeLicenses = <String>{};

  List<String> _pickRandomSubset(List<String> values, Random rng) {
    final normalized =
        values
            .map((v) => v.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList(growable: true)
          ..shuffle(rng);
    if (normalized.isEmpty) return const <String>[];
    final count =
        1 + rng.nextInt(normalized.length > 3 ? 3 : normalized.length);
    return normalized.take(count).toList(growable: false);
  }

  String _requiredPartChipLabel(RequiredPart part) {
    final details = <String>[];
    if (part.oemPn.trim().isNotEmpty) details.add('OEM ${part.oemPn.trim()}');
    if (part.vendorPn.trim().isNotEmpty) {
      details.add('VPN ${part.vendorPn.trim()}');
    }
    if (part.vendorName.trim().isNotEmpty) details.add(part.vendorName.trim());
    if (part.estimatedLeadTime.trim().isNotEmpty) {
      details.add(part.estimatedLeadTime.trim());
    }
    return details.isEmpty ? 'Part details unavailable' : details.join(' • ');
  }

  List<String> get _availableSuperCategories => _superCategoryOptions.isEmpty
      ? List<String>.from(_maintenanceSuperCategory)
      : _superCategoryOptions;
  Widget _buildMachineLicenseRequirementChips([Machine? machine]) {
    final trades = _machineLicenseTradeLabels(machine);
    if (trades.isEmpty) {
      return const Text('None');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: trades.map((trade) => Chip(label: Text(trade))).toList(),
    );
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final List<SubAssemblyDraft> _subAssemblyDrafts = <SubAssemblyDraft>[];
  final Map<int, Future<List<MachineDetailHistoryEntry>>>
  _machineDetailHistoryFutures =
      <int, Future<List<MachineDetailHistoryEntry>>>{};
  final Map<int, _MachineDetailEditDraft> _maintenanceDueDetailDrafts =
      <int, _MachineDetailEditDraft>{};
  final Map<int, _SubAssemblyDetailEditDraft> _subAssemblyDetailDrafts =
      <int, _SubAssemblyDetailEditDraft>{};
  final Map<int, Future<List<SubAssemblyDetailHistoryEntry>>>
  _subAssemblyDetailHistoryFutures =
      <int, Future<List<SubAssemblyDetailHistoryEntry>>>{};
  final Map<int, Future<WorkOrderStatusEntry?>> _workOrderStatusFutures =
      <int, Future<WorkOrderStatusEntry?>>{};
  final Map<int, Future<Map<int, String>>> _workOrderTaskAssignmentFutures =
      <int, Future<Map<int, String>>>{};
  final Map<int, Future<Map<int, WorkOrderTaskOutcomeEntry>>>
  _workOrderTaskOutcomeFutures =
      <int, Future<Map<int, WorkOrderTaskOutcomeEntry>>>{};
  final Map<int, Future<List<ContractorCompany>>> _workOrderContractorFutures =
      <int, Future<List<ContractorCompany>>>{};
  final Map<int, String> _workOrderStatusSelectionDrafts = <int, String>{};
  final Map<int, bool> _workOrderRescheduledDrafts = <int, bool>{};
  final Map<int, bool> _workOrderLicensedWorkDrafts = <int, bool>{};
  final Map<int, String> _workOrderStatusNotesDrafts = <int, String>{};
  final Map<String, String> _workOrderTaskAssigneeDrafts = <String, String>{};
  final Map<String, String> _workOrderTaskOutcomeDrafts = <String, String>{};
  final Map<String, String> _workOrderTaskOutcomeNotesDrafts =
      <String, String>{};

  List<String> _machineLicenseTradeLabels([Machine? machine]) {
    if (machine == null) {
      return const <String>[];
    }

    final labels = <String>[];
    if (machine.requiresHvacLicense) {
      labels.add('HVAC');
    }
    if (machine.requiresRefrigerationLicense) {
      labels.add('Refrigeration');
    }
    if (machine.requiresPlumberLicense) {
      labels.add('Plumber');
    }
    if (machine.requiresElectricianLicense) {
      labels.add('Electrician');
    }
    if (machine.requiresBoilerLicense) {
      labels.add('Boiler');
    }

    for (final license in machine.additionalRequiredLicenses) {
      final normalized = license.trim();
      if (normalized.isNotEmpty) {
        labels.add(normalized);
      }
    }

    return labels.toSet().toList(growable: false);
  }

  final List<Employee> _employees = <Employee>[];

  List<Widget> _dialogActionsForContext(
    BuildContext context,
    List<Widget> actions,
  ) {
    return actions;
  }

  static const List<_AppTab> _defaultTabOrder = <_AppTab>[
    _AppTab.addMachine,
    _AppTab.workOrders,
    _AppTab.maintenanceDue,
    _AppTab.employees,
    _AppTab.contractors,
    _AppTab.vendors,
    _AppTab.calendar,
    _AppTab.reports,
    _AppTab.settings,
    _AppTab.information,
    _AppTab.help,
  ];
  static const String _tabOrderPreferenceKey = 'machineEntry.tabOrder';

  final TextEditingController _taskSearchController = TextEditingController();
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _employeeEmailController =
      TextEditingController();
  final TextEditingController _employeeCellPhoneController =
      TextEditingController();
  final TextEditingController _employeePhoneNumberController =
      TextEditingController();
  final TextEditingController _employeePhoneExtensionController =
      TextEditingController();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _bulkRandomRowsController = TextEditingController(
    text: '15',
  );
  final TextEditingController _bulkRandomMachinesController =
      TextEditingController(text: '15');
  final TextEditingController _bulkRandomEmployeesController =
      TextEditingController(text: '15');
  final TextEditingController _bulkRandomContractorsController =
      TextEditingController(text: '15');
  MachineDraft _machineDraft = MachineDraft();

  final Set<_MachineField> _optionalMachineFields = <_MachineField>{};
  final Set<_SubAssemblyField> _optionalSubAssemblyFields =
      <_SubAssemblyField>{};

  bool _isLoading = false;
  bool _showRandomizeButtons = false;
  String? _startupLoadError;
  bool _isWebDatabaseNoticeDismissed = false;
  bool _hasAttemptedDatabaseRecovery = false;
  bool _hasAutoOpenedHelpForMissingDatabase = false;
  bool _hasAutoOpenedHelpForDatabaseFailure = false;
  bool _preferHelpStartupTab = false;
  _AppTab? _pendingStartupTab;
  DateTime? _lastVisibilityReloadAttemptUtc;
  final List<Machine> _machines = <Machine>[];
  List<_AppTab> _tabOrder = List<_AppTab>.from(_defaultTabOrder);
  String? _selectedTaskType;
  String? _selectedTaskTimeCategory;
  String? _selectedSuperCategory;
  String? _selectedSubCategory;
  String _taskSearchQuery = '';
  String _vendorsSearchQuery = '';
  _VendorSortMode _vendorsSortMode = _VendorSortMode.vendorNameAsc;
  bool _vendorsIncludeUnspecifiedVendors = true;
  String _forecastPartsSelectedBucket = 'All';
  Timer? _vendorsSearchPersistDebounce;
  final List<String> _loadedMaintenanceTaskTypes = <String>[];
  List<String> get _availableMaintenanceTaskTypes =>
      _loadedMaintenanceTaskTypes.isEmpty
      ? List<String>.from(_maintenanceTaskTypes)
      : _loadedMaintenanceTaskTypes;
  final List<String> _loadedSubCategories = <String>[];
  List<String> get _availableSubCategories => _loadedSubCategories.isEmpty
      ? List<String>.from(_subCategories)
      : _loadedSubCategories;
  final List<String> _licenseTypeOptions = <String>[];
  final List<String> _superCategoryOptions = <String>[];
  final List<String> _maintenanceTaskTypeOptions = <String>[];
  final List<String> _subCategoryOptions = <String>[];
  final List<String> _customLicenseTypes = <String>[];
  final List<String> _customSuperCategories = <String>[];
  final List<String> _customMaintenanceTaskTypes = <String>[];
  final List<String> _customSubCategories = <String>[];
  bool _hasLoadedSkillTypes = false;
  final List<String> _skillTypeOptions = <String>[];
  Future<Map<String, String>>? _helpDiagnosticsFuture;
  final GlobalKey _tabControllerContextKey = GlobalKey();
  TabController? _activeTabController;
  int _tabControllerEpoch = 0;

  @override
  void initState() {
    super.initState();
    _tabOrder = _normalizeTabOrder(_defaultTabOrder);
    _isLoading = true;
    _bootstrapPage();
  }

  Future<void> _bootstrapPage() async {
    try {
      try {
        await _loadTabOrderPreference();
      } catch (_) {}
      try {
        await _loadEmployeeListViewPreferences();
      } catch (_) {}
      try {
        await _loadVendorsTabPreferences();
      } catch (_) {}
      try {
        await _loadForecastTabPreferences();
      } catch (_) {}
      try {
        await _loadMachineFieldRequirementsPreferences();
      } catch (_) {}
      try {
        await _loadSubAssemblyFieldRequirementsPreferences();
      } catch (_) {}

      // Prioritize the primary records first so startup doesn't feel blocked
      // by catalog backfills.
      await _loadMachines();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _startupLoadError = _visibleDatabaseLoadFailureMessage(error);
      });
      _openHelpTabForDatabaseFailure();
      _showErrorSnackBar('Failed to initialize app data.', error);
    }
  }

  List<String> get _availableSkillTypes {
    if (!_hasLoadedSkillTypes) {
      return List<String>.from(_defaultEmployeeSkills);
    }

    final normalized = <String>{};
    final merged = <String>[];

    for (final type in _skillTypeOptions) {
      final trimmed = type.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toUpperCase();
      if (normalized.add(key)) {
        merged.add(trimmed);
      }
    }

    return merged;
  }

  Future<void> _refreshLicenseTypes() async {
    final savedTypes = await MachineDatabase.instance.getLicenseTypes();
    if (!mounted) {
      return;
    }

    setState(() {
      _licenseTypeOptions
        ..clear()
        ..addAll(savedTypes);
    });
  }

  Future<void> _showAddLicenseTypeDialog({
    void Function(String type)? onSaved,
  }) async {
    final controller = TextEditingController();
    try {
      final enteredType = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add License Type'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'License Type',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      final normalized = enteredType?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }

      final savedType = await MachineDatabase.instance.addLicenseType(
        normalized,
      );
      if (savedType == null || savedType.trim().isEmpty) {
        return;
      }

      final finalType = savedType.trim();
      await _refreshLicenseTypes();
      onSaved?.call(finalType);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('License type "$finalType" saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save license type.', error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showManageLicenseTypesDialog({
    void Function(String oldName, String newName)? onRenamed,
    void Function(String deletedName)? onDeleted,
  }) async {
    if (_customLicenseTypes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No custom license types to manage.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final customLicenses = _customLicenseTypes;
            return AlertDialog(
              title: const Text('Manage License Types'),
              content: SizedBox(
                width: 520,
                child: customLicenses.isEmpty
                    ? const Text('No custom license types to manage.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: customLicenses.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final license = customLicenses[index];
                          return ListTile(
                            title: Text(license),
                            trailing: Wrap(
                              spacing: 6,
                              children: [
                                IconButton(
                                  tooltip: 'Rename',
                                  onPressed: () async {
                                    final renamedTo =
                                        await _showRenameLicenseTypeDialog(
                                          license,
                                        );
                                    if (renamedTo == null || !mounted) {
                                      return;
                                    }
                                    onRenamed?.call(license, renamedTo);
                                    await _refreshLicenseTypes();
                                    if (dialogContext.mounted) {
                                      setDialogState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  onPressed: () async {
                                    final shouldDelete =
                                        await _confirmDeleteLicenseType(
                                          license,
                                        );
                                    if (!shouldDelete || !mounted) {
                                      return;
                                    }
                                    onDeleted?.call(license);
                                    await _refreshLicenseTypes();
                                    if (dialogContext.mounted) {
                                      setDialogState(() {});
                                    }
                                  },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<String?> _showRenameLicenseTypeDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    try {
      final nextName = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Rename License Type'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'License Type',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      final normalized = nextName?.trim() ?? '';
      if (normalized.isEmpty ||
          normalized.toUpperCase() == currentName.toUpperCase()) {
        return null;
      }

      final renamed = await MachineDatabase.instance.renameLicenseType(
        currentName,
        normalized,
      );
      if (renamed == null || renamed.trim().isEmpty) {
        return null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'License type "$currentName" renamed to "${renamed.trim()}".',
            ),
          ),
        );
      }

      return renamed.trim();
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to rename license type.', error);
      }
      return null;
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirmDeleteLicenseType(String licenseType) async {
    try {
      final usageCount = await MachineDatabase.instance
          .getMachineRequiredLicenseUsageCount(licenseType);
      if (!mounted) {
        return false;
      }

      if (usageCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Cannot Delete License Type'),
              content: Text(
                '"$licenseType" is currently used by $usageCount machine(s). Remove it from those machines before deleting this license type.',
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ]),
            );
          },
        );
        return false;
      }

      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete License Type'),
            content: Text('Delete "$licenseType"?'),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ]),
          );
        },
      );

      if (shouldDelete != true) {
        return false;
      }

      await MachineDatabase.instance.deleteLicenseType(licenseType);
      await _loadMachines(seedSampleData: false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('License type "$licenseType" deleted.')),
        );
      }

      return true;
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete license type.', error);
      }
      return false;
    }
  }

  Future<void> _refreshSuperCategories({String? selectedCategory}) async {
    final savedTypes = await MachineDatabase.instance.getSuperCategoryTypes();
    final resolvedTypes = savedTypes.isEmpty
        ? _maintenanceSuperCategory
        : savedTypes;
    if (!mounted) {
      return;
    }

    setState(() {
      _superCategoryOptions
        ..clear()
        ..addAll(resolvedTypes);

      if (selectedCategory != null && selectedCategory.trim().isNotEmpty) {
        _selectedSuperCategory = selectedCategory.trim();
      } else if (_selectedSuperCategory != null &&
          !_availableSuperCategories.contains(_selectedSuperCategory)) {
        _selectedSuperCategory = null;
      }
    });
  }

  Future<void> _showAddSuperCategoryDialog({
    void Function(String type)? onSaved,
  }) async {
    final controller = TextEditingController();
    try {
      final enteredType = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add Super Category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Super Category',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      final normalized = enteredType?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }

      final savedType = await MachineDatabase.instance.addSuperCategoryType(
        normalized,
      );
      if (savedType == null || savedType.trim().isEmpty) {
        return;
      }

      final finalType = savedType.trim();
      await _refreshSuperCategories(selectedCategory: finalType);
      onSaved?.call(finalType);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Super category "$finalType" saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save super category.', error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showManageSuperCategoriesDialog({
    void Function(String deletedName)? onDeleted,
  }) async {
    if (_customSuperCategories.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No custom super categories to manage.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final customTypes = _customSuperCategories;
            return AlertDialog(
              title: const Text('Manage Super Categories'),
              content: SizedBox(
                width: 520,
                child: customTypes.isEmpty
                    ? const Text('No custom super categories to manage.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: customTypes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final superCategory = customTypes[index];
                          return ListTile(
                            title: Text(superCategory),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                final shouldDelete =
                                    await _confirmDeleteSuperCategory(
                                      superCategory,
                                    );
                                if (!shouldDelete || !mounted) {
                                  return;
                                }
                                onDeleted?.call(superCategory);
                                await _refreshSuperCategories();
                                if (dialogContext.mounted) {
                                  setDialogState(() {});
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteSuperCategory(String superCategory) async {
    try {
      final usageCount = await MachineDatabase.instance
          .getSubAssemblySuperCategoryUsageCount(superCategory);
      if (!mounted) {
        return false;
      }

      if (usageCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Cannot Delete Super Category'),
              content: Text(
                '"$superCategory" is currently used by $usageCount sub-assemblies. Remove it from those records before deleting this super category.',
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ]),
            );
          },
        );
        return false;
      }

      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete Super Category'),
            content: Text('Delete "$superCategory"?'),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ]),
          );
        },
      );

      if (shouldDelete != true) {
        return false;
      }

      await MachineDatabase.instance.deleteSuperCategoryType(superCategory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Super category "$superCategory" deleted.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete super category.', error);
      }
      return false;
    }
  }

  Future<void> _refreshMaintenanceTaskTypes() async {
    final savedTypes = await MachineDatabase.instance.getMaintenanceTaskTypes();
    final resolvedTypes = savedTypes.isEmpty
        ? _maintenanceTaskTypes
        : savedTypes;
    if (!mounted) {
      return;
    }

    setState(() {
      _loadedMaintenanceTaskTypes
        ..clear()
        ..addAll(resolvedTypes);
      _maintenanceTaskTypeOptions
        ..clear()
        ..addAll(resolvedTypes);

      if (_selectedTaskType != null &&
          !_availableMaintenanceTaskTypes.contains(_selectedTaskType)) {
        _selectedTaskType = null;
      }
    });
  }

  Future<void> _showAddMaintenanceTaskTypeDialog({
    void Function(String type)? onSaved,
  }) async {
    final controller = TextEditingController();
    try {
      final enteredType = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add Maintenance Task Type'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Task Type',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      final normalized = enteredType?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }

      final savedType = await MachineDatabase.instance.addMaintenanceTaskType(
        normalized,
      );
      if (savedType == null || savedType.trim().isEmpty) {
        return;
      }

      final finalType = savedType.trim();
      await _refreshMaintenanceTaskTypes();
      onSaved?.call(finalType);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task type "$finalType" saved.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save task type.', error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showManageMaintenanceTaskTypesDialog({
    void Function(String deletedName)? onDeleted,
  }) async {
    if (_customMaintenanceTaskTypes.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No custom task types to manage.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final customTypes = _customMaintenanceTaskTypes;
            return AlertDialog(
              title: const Text('Manage Maintenance Task Types'),
              content: SizedBox(
                width: 520,
                child: customTypes.isEmpty
                    ? const Text('No custom task types to manage.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: customTypes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final taskType = customTypes[index];
                          return ListTile(
                            title: Text(taskType),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                final shouldDelete =
                                    await _confirmDeleteMaintenanceTaskType(
                                      taskType,
                                    );
                                if (!shouldDelete || !mounted) {
                                  return;
                                }
                                onDeleted?.call(taskType);
                                await _refreshMaintenanceTaskTypes();
                                if (dialogContext.mounted) {
                                  setDialogState(() {});
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteMaintenanceTaskType(String taskType) async {
    try {
      final usageCount = await MachineDatabase.instance
          .getMaintenanceTaskTypeUsageCount(taskType);
      if (!mounted) {
        return false;
      }

      if (usageCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Cannot Delete Task Type'),
              content: Text(
                '"$taskType" is currently used by $usageCount maintenance task(s). Remove it from those records before deleting this task type.',
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ]),
            );
          },
        );
        return false;
      }

      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete Task Type'),
            content: Text('Delete "$taskType"?'),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ]),
          );
        },
      );

      if (shouldDelete != true) {
        return false;
      }

      await MachineDatabase.instance.deleteMaintenanceTaskType(taskType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task type "$taskType" deleted.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete task type.', error);
      }
      return false;
    }
  }

  Future<void> _refreshSubCategories({String? selectedType}) async {
    final savedTypes = await MachineDatabase.instance.getComponentTypes();
    final resolvedTypes = savedTypes.isEmpty ? _subCategories : savedTypes;
    if (!mounted) {
      return;
    }

    setState(() {
      _loadedSubCategories
        ..clear()
        ..addAll(resolvedTypes);
      _subCategoryOptions
        ..clear()
        ..addAll(resolvedTypes);

      if (selectedType != null && selectedType.trim().isNotEmpty) {
        _selectedSubCategory = selectedType.trim();
      } else if (_selectedSubCategory != null &&
          !_availableSubCategories.contains(_selectedSubCategory)) {
        _selectedSubCategory = null;
      }
    });
  }

  Future<void> _showAddSubCategoryDialog({
    void Function(String type)? onSaved,
  }) async {
    final controller = TextEditingController();
    try {
      final enteredType = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Add Sub Category'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Sub Category',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(controller.text.trim());
                },
                child: const Text('Save'),
              ),
            ]),
          );
        },
      );

      final normalized = enteredType?.trim() ?? '';
      if (normalized.isEmpty) {
        return;
      }

      final savedType = await MachineDatabase.instance.addComponentType(
        normalized,
      );
      if (savedType == null || savedType.trim().isEmpty) {
        return;
      }

      final finalType = savedType.trim();
      await _refreshSubCategories(selectedType: finalType);
      onSaved?.call(finalType);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sub category "$finalType" saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to save sub category.', error);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showManageSubCategoriesDialog({
    void Function(String deletedName)? onDeleted,
  }) async {
    if (_customSubCategories.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No custom sub categories to manage.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final customSubCategories = _customSubCategories;
            return AlertDialog(
              title: const Text('Manage Sub Categories'),
              content: SizedBox(
                width: 520,
                child: customSubCategories.isEmpty
                    ? const Text('No custom sub categories to manage.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: customSubCategories.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final subCategory = customSubCategories[index];
                          return ListTile(
                            title: Text(subCategory),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                final shouldDelete =
                                    await _confirmDeleteSubCategory(
                                      subCategory,
                                    );
                                if (!shouldDelete || !mounted) {
                                  return;
                                }
                                onDeleted?.call(subCategory);
                                await _refreshSubCategories();
                                if (dialogContext.mounted) {
                                  setDialogState(() {});
                                }
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmDeleteSubCategory(String subCategory) async {
    try {
      final usageCount = await MachineDatabase.instance
          .getSubAssemblyComponentTypeUsageCount(subCategory);
      if (!mounted) {
        return false;
      }

      if (usageCount > 0) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Cannot Delete Sub Category'),
              content: Text(
                '"$subCategory" is currently used by $usageCount sub-assemblies. Remove it from those records before deleting this sub category.',
              ),
              actions: _dialogActionsForContext(dialogContext, [
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('OK'),
                ),
              ]),
            );
          },
        );
        return false;
      }

      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete Sub Category'),
            content: Text('Delete "$subCategory"?'),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ]),
          );
        },
      );

      if (shouldDelete != true) {
        return false;
      }

      await MachineDatabase.instance.deleteComponentType(subCategory);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sub category "$subCategory" deleted.')),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        _showErrorSnackBar('Failed to delete sub category.', error);
      }
      return false;
    }
  }

  Future<void> _loadTabOrderPreference() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(_tabOrderPreferenceKey);
    if (stored == null || stored.isEmpty) {
      return;
    }

    final parsed = <_AppTab>[];
    for (final value in stored) {
      try {
        parsed.add(_AppTab.values.byName(value));
      } catch (_) {
        // Ignore unknown values and fallback to default order if invalid.
      }
    }

    final normalized = _normalizeTabOrder(parsed);
    if (!mounted) {
      return;
    }

    setState(() {
      _tabOrder = normalized;
    });
  }

  List<_AppTab> _normalizeTabOrder(List<_AppTab> input) {
    final unique = <_AppTab>[];
    for (final tab in input) {
      final canonicalTab = _canonicalTab(tab);
      if (!unique.contains(canonicalTab)) {
        unique.add(canonicalTab);
      }
    }

    if (unique.length != _defaultTabOrder.length) {
      return List<_AppTab>.from(_defaultTabOrder);
    }

    final hasAll = _defaultTabOrder.every(unique.contains);
    if (!hasAll) {
      return List<_AppTab>.from(_defaultTabOrder);
    }

    return unique;
  }

  _AppTab _canonicalTab(_AppTab tab) {
    switch (tab) {
      case _AppTab.addMachine:
      case _AppTab.machinesList:
      case _AppTab.editMachines:
        return _AppTab.addMachine;
      case _AppTab.employees:
      case _AppTab.contractors:
      case _AppTab.vendors:
      case _AppTab.maintenanceDue:
      case _AppTab.workOrders:
      case _AppTab.calendar:
      case _AppTab.reports:
      case _AppTab.information:
      case _AppTab.help:
      case _AppTab.settings:
        return tab;
    }
  }

  Future<void> _persistTabOrder(List<_AppTab> order) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _tabOrderPreferenceKey,
      order.map((tab) => tab.name).toList(growable: false),
    );
  }

  Future<void> _loadMachineFieldRequirementsPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(
      _optionalMachineFieldsPreferenceKey,
    );
    if (stored == null || !mounted) {
      return;
    }
    final resolved = stored
        .map(
          (name) =>
              _MachineField.values.where((f) => f.name == name).firstOrNull,
        )
        .whereType<_MachineField>()
        .toSet();
    setState(() {
      _optionalMachineFields
        ..clear()
        ..addAll(resolved);
    });
  }

  Future<void> _persistMachineFieldRequirementsPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _optionalMachineFieldsPreferenceKey,
      _optionalMachineFields.map((f) => f.name).toList(growable: false),
    );
  }

  bool _isMachineFieldOptional(_MachineField field) =>
      _optionalMachineFields.contains(field);

  Future<void> _loadSubAssemblyFieldRequirementsPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getStringList(
      _optionalSubAssemblyFieldsPreferenceKey,
    );
    if (stored == null || !mounted) {
      return;
    }
    final resolved = stored
        .map(
          (name) =>
              _SubAssemblyField.values.where((f) => f.name == name).firstOrNull,
        )
        .whereType<_SubAssemblyField>()
        .toSet();
    setState(() {
      _optionalSubAssemblyFields
        ..clear()
        ..addAll(resolved);
    });
  }

  Future<void> _persistSubAssemblyFieldRequirementsPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _optionalSubAssemblyFieldsPreferenceKey,
      _optionalSubAssemblyFields.map((f) => f.name).toList(growable: false),
    );
  }

  bool _isSubAssemblyFieldOptional(_SubAssemblyField field) =>
      _optionalSubAssemblyFields.contains(field);

  void _switchToTab(_AppTab tab, {int attempt = 0}) {
    final tabIndex = _normalizeTabOrder(_tabOrder).indexOf(tab);
    if (tabIndex < 0) {
      return;
    }

    const maxAttempts = 10;

    void retryLater() {
      if (attempt >= maxAttempts || !mounted) {
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) {
          return;
        }
        _switchToTab(tab, attempt: attempt + 1);
      });
    }

    void animate() {
      final controller =
          _activeTabController ??
          (() {
            final resolvedTabContext = _tabControllerContextKey.currentContext;
            if (resolvedTabContext == null) {
              return null;
            }
            return DefaultTabController.maybeOf(resolvedTabContext);
          })();
      if (controller == null) {
        retryLater();
        return;
      }
      if (tabIndex >= controller.length) {
        return;
      }
      controller.animateTo(tabIndex);
    }

    animate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      animate();
    });
  }

  Future<void> _handleInitialDatabaseSetupAction(
    InitialDatabaseSetupAction action,
  ) async {
    switch (action) {
      case InitialDatabaseSetupAction.buildCompleteDb:
        await _generateRandomDatabaseData();
        break;
      case InitialDatabaseSetupAction.buildMachineDb:
        await _generateRandomMachinesData();
        break;
      case InitialDatabaseSetupAction.buildEmployeeDb:
        await _generateRandomEmployeesData();
        break;
      case InitialDatabaseSetupAction.buildVenderDb:
        await _generateRandomContractorsData();
        break;
      case InitialDatabaseSetupAction.uploadMachineCsv:
        await importMachinesFromCsv();
        break;
      case InitialDatabaseSetupAction.uploadEmployeeCsv:
        await importEmployeesFromCsv();
        break;
      case InitialDatabaseSetupAction.uploadVenderCsv:
        await importContractorsFromCsv();
        break;
      case InitialDatabaseSetupAction.addMachine:
        _switchToTab(_AppTab.addMachine);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Open the Machines tab to add your first machine.'),
            ),
          );
        }
        break;
    }

    if (!mounted) {
      return;
    }

    await _loadMachines(seedSampleData: false);
  }

  String _tabTitle(_AppTab tab) {
    switch (tab) {
      case _AppTab.addMachine:
      case _AppTab.machinesList:
      case _AppTab.editMachines:
        return 'Machines';
      case _AppTab.employees:
        return 'Employees';
      case _AppTab.contractors:
        return 'Contractors';
      case _AppTab.vendors:
        return 'Vendors';
      case _AppTab.maintenanceDue:
        return 'Schedule';
      case _AppTab.workOrders:
        return 'Work Orders';
      case _AppTab.calendar:
        return 'Forecast';
      case _AppTab.reports:
        return 'Reports';
      case _AppTab.information:
        return 'Information';
      case _AppTab.settings:
        return 'Settings';
      case _AppTab.help:
        return 'Help';
    }
  }

  IconData _tabIcon(_AppTab tab) {
    switch (tab) {
      case _AppTab.addMachine:
      case _AppTab.machinesList:
      case _AppTab.editMachines:
        return Icons.precision_manufacturing_outlined;
      case _AppTab.employees:
        return Icons.group_outlined;
      case _AppTab.contractors:
        return Icons.business_outlined;
      case _AppTab.vendors:
        return Icons.inventory_2_outlined;
      case _AppTab.maintenanceDue:
        return Icons.build_circle_outlined;
      case _AppTab.workOrders:
        return Icons.assignment_outlined;
      case _AppTab.calendar:
        return Icons.calendar_month_outlined;
      case _AppTab.reports:
        return Icons.assessment_outlined;
      case _AppTab.information:
        return Icons.info_outline;
      case _AppTab.settings:
        return Icons.settings_outlined;
      case _AppTab.help:
        return Icons.help_outline;
    }
  }

  Widget _tabViewFor(_AppTab tab) {
    switch (tab) {
      case _AppTab.addMachine:
      case _AppTab.machinesList:
      case _AppTab.editMachines:
        return _buildMachinesTab();
      case _AppTab.employees:
        return _buildEmployeesTab();
      case _AppTab.contractors:
        return _buildContractorsTab();
      case _AppTab.vendors:
        return _buildVendorsTab();
      case _AppTab.maintenanceDue:
        return _buildMaintenanceDueTab();
      case _AppTab.workOrders:
        return _buildWorkOrdersTab();
      case _AppTab.calendar:
        return _buildCalendarTab();
      case _AppTab.reports:
        return _buildReportsTab();
      case _AppTab.information:
        return _buildInformationTab();
      case _AppTab.settings:
        return _buildGlobalSettingsTab();
      case _AppTab.help:
        return _buildHelpTab();
    }
  }

  Widget _buildInformationTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Material(
            child: TabBar(
              tabs: [
                Tab(
                  icon: Icon(Icons.contact_support_outlined),
                  text: 'Contact',
                ),
                Tab(icon: Icon(Icons.article_outlined), text: 'Submissions'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ContactPage(
                  serverUri: Uri.parse(
                    'https://stefanronnkvist.com/contact.php',
                  ),
                  showAppBar: false,
                ),
                const SubmissionsCsvCardsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDatabaseActionSelection(String value) async {
    switch (value) {
      case 'export':
        await _exportDatabaseBackup();
        break;
      case 'import':
        await _importDatabaseBackup();
        break;
      case 'generate_all':
        await _generateRandomDatabaseData();
        break;
      case 'delete_all':
        await _deleteRandomAllData();
        break;
      case 'setup_upload_machine_csv':
        await _handleInitialDatabaseSetupAction(
          InitialDatabaseSetupAction.uploadMachineCsv,
        );
        break;
      case 'setup_upload_employee_csv':
        await _handleInitialDatabaseSetupAction(
          InitialDatabaseSetupAction.uploadEmployeeCsv,
        );
        break;
      case 'setup_upload_vender_csv':
        await _handleInitialDatabaseSetupAction(
          InitialDatabaseSetupAction.uploadVenderCsv,
        );
        break;
      case 'setup_upload_contractor_csv':
        await _handleInitialDatabaseSetupAction(
          InitialDatabaseSetupAction.uploadVenderCsv,
        );
        break;
      case 'setup_export_machine_template_csv':
        await exportMachineCsvTemplate();
        break;
      case 'setup_export_employee_template_csv':
        await exportEmployeeCsvTemplate();
        break;
      case 'setup_export_vendor_template_csv':
        await exportVendorCsvTemplate();
        break;
      case 'setup_export_contractor_template_csv':
        await exportContractorCsvTemplate();
        break;
    }
  }

  Widget _buildGlobalSettingsTab() {
    final showRandomDatabaseActions = !kReleaseMode;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.casino_outlined),
                  title: const Text('Show Randomize Buttons'),
                  subtitle: const Text(
                    'Controls visibility of all random value buttons across the app.',
                  ),
                  value: _showRandomizeButtons,
                  onChanged: (value) {
                    setState(() {
                      _showRandomizeButtons = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <ThemeMode>{widget.themeMode},
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    widget.onThemeModeChanged(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Machine Form Field Requirements'),
            subtitle: const Text('Toggle fields as required or optional'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toggle any field to make it optional (no validation error when left blank).',
                ),
              ),
              const SizedBox(height: 8),
              for (final field in _MachineField.values)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(field.label),
                  subtitle: Text(
                    _optionalMachineFields.contains(field)
                        ? 'Optional'
                        : 'Required',
                  ),
                  value: !_optionalMachineFields.contains(field),
                  onChanged: (isRequired) {
                    setState(() {
                      if (isRequired) {
                        _optionalMachineFields.remove(field);
                      } else {
                        _optionalMachineFields.add(field);
                      }
                    });
                    unawaited(_persistMachineFieldRequirementsPreferences());
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Sub-Assembly Form Field Requirements'),
            subtitle: const Text('Toggle fields as required or optional'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Toggle any field to make it optional (no validation error when left blank).',
                ),
              ),
              const SizedBox(height: 8),
              for (final field in _SubAssemblyField.values)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(field.label),
                  subtitle: Text(
                    _optionalSubAssemblyFields.contains(field)
                        ? 'Optional'
                        : 'Required',
                  ),
                  value: !_optionalSubAssemblyFields.contains(field),
                  onChanged: (isRequired) {
                    setState(() {
                      if (isRequired) {
                        _optionalSubAssemblyFields.remove(field);
                      } else {
                        _optionalSubAssemblyFields.add(field);
                      }
                    });
                    unawaited(
                      _persistSubAssemblyFieldRequirementsPreferences(),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Application Actions'),
            subtitle: const Text('PDF exports, tab order, and reload'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _reloadMachinesFromDatabase(showFeedback: true);
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Reload Saved Data'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showTabOrderDialog,
                    icon: const Icon(Icons.reorder),
                    label: const Text('Customize Tab Order'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printMachinesListPdf,
                    icon: Icon(_pdfActionIcon),
                    label: Text(_machinesListPdfActionLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printEmployeesPdf,
                    icon: Icon(_pdfActionIcon),
                    label: const Text('Open Employees PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printContractorsPdf,
                    icon: Icon(_pdfActionIcon),
                    label: const Text('Open Contractors PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printSchedulePdf,
                    icon: Icon(_pdfActionIcon),
                    label: Text(_schedulePdfActionLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: _printWorkOrdersPdf,
                    icon: Icon(_pdfActionIcon),
                    label: Text(_workOrdersPdfActionLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Database Actions'),
            subtitle: const Text('Import, export, backup, and CSV templates'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _handleDatabaseActionSelection('export'),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Database JSON'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _handleDatabaseActionSelection('import'),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Import Database JSON'),
                  ),
                  if (showRandomDatabaseActions)
                    OutlinedButton.icon(
                      onPressed: () =>
                          _handleDatabaseActionSelection('delete_all'),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Delete Database'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_upload_machine_csv',
                    ),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload Machine CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_upload_employee_csv',
                    ),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload Employee CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_upload_vender_csv',
                    ),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload Vender CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_upload_contractor_csv',
                    ),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('Upload Contractor CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_export_machine_template_csv',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Machine CSV Template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_export_employee_template_csv',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Employee CSV Template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_export_vendor_template_csv',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Vendor CSV Template'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _handleDatabaseActionSelection(
                      'setup_export_contractor_template_csv',
                    ),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Export Contractor CSV Template'),
                  ),
                ],
              ),
              if (_showRandomizeButtons) ...[
                const SizedBox(height: 12),
                Text(
                  'Bulk Random Rows',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 190,
                      child: TextField(
                        controller: _bulkRandomRowsController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Rows per group',
                          helperText: '1 to 500',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              final parsedCount = int.tryParse(
                                _bulkRandomRowsController.text.trim(),
                              );
                              if (parsedCount == null ||
                                  parsedCount < 1 ||
                                  parsedCount > 500) {
                                if (!mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Enter a whole number between 1 and 500.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              await _appendRandomAllDataWithRowCount(
                                parsedCount,
                              );
                            },
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text(
                        'Add Random Machines, Employees, Vendors, Contractors',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHelpTab() {
    _helpDiagnosticsFuture ??= _buildHelpDiagnostics();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Quick Start',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'Schedular keeps maintenance planning, qualified labor, parts, and work-order history together in a local database.',
                ),
                SizedBox(height: 8),
                Text(
                  '1. Add machines, sub-assemblies, and recurring maintenance tasks in Machines.',
                ),
                SizedBox(height: 4),
                Text(
                  '2. Add Employees and Contractors, including the skills and licenses used for assignment matching.',
                ),
                SizedBox(height: 4),
                Text(
                  '3. Review due work in Schedule and future workload and parts demand in Forecast.',
                ),
                SizedBox(height: 4),
                Text(
                  '4. Use Work Orders to assign the next five days of work, update status, and record outcomes.',
                ),
                SizedBox(height: 4),
                Text(
                  '5. Review Reports, export operational files, and back up the database from Settings.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tips',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the Settings tab actions to reload data from the local database.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use Customize Tab Order to arrange tabs based on your workflow.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use Settings > Database Actions to import/export backups and CSV templates.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Export a Database JSON backup before bulk imports, major edits, or resetting local data.',
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use Settings > Application Actions for available PDF exports. Vendors and Forecast provide CSV exports for parts planning.',
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    _switchToTab(_AppTab.settings);
                  },
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Open Global Settings'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Current Tabs and Actions'),
            subtitle: const Text('What each tab is used for today'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: const [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Machines: create/edit machines, sub-assemblies, and maintenance tasks.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Employees: manage technician records, skills, and licenses.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contractors: manage external companies and contacts.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Vendors: view required parts grouped by vendor, open links, and export CSV files.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Schedule (Maintenance Due): review due items and required parts for each maintenance task.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Work Orders: assign the next five days of work, check qualifications, track status, and capture outcomes.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Forecast: view grouped future workload, required-parts tables, and export CSV files.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Reports: summarize planning and output work-order reporting PDFs.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Settings: control theme, tab order, required fields, exports, backups, imports, and database actions.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Help: diagnostics, recovery steps, and import/export walkthroughs.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Troubleshooting'),
            subtitle: const Text('If tabs are empty or data looks stale'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('1. Press Reload Saved Data in the Settings tab.'),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '2. Check Diagnostics below to confirm DB path and record counts.',
                ),
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '3. If counts are zero unexpectedly, import from the latest backup JSON.',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await _reloadMachinesFromDatabase(
                              showFeedback: true,
                            );
                            if (!mounted) {
                              return;
                            }
                            setState(() {
                              _helpDiagnosticsFuture = _buildHelpDiagnostics();
                            });
                          },
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('Reload Data Now'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _helpDiagnosticsFuture = _buildHelpDiagnostics();
                      });
                    },
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Refresh Diagnostics'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _helpDiagnosticsFuture = _buildHelpDiagnostics();
                      });
                    },
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Run DB Health Check'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            await _backupAndResetLocalDatabaseFromHelp();
                          },
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Backup + Reset Local DB'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: const Text('Import / Export Walkthrough'),
            subtitle: const Text('Safe backup and restore flow'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: const [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '1. Export Database JSON before large edits, bulk imports, or a database reset.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '2. Use Upload CSV actions to append/update machine, employee, or contractor data.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '3. Use Vendors/Forecast Export CSV actions to save parts planning files for purchasing.',
                ),
              ),
              SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '4. Use Import Database JSON to restore a known-good backup. After confirmation, importing replaces the current app data.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diagnostics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                FutureBuilder<Map<String, String>>(
                  future: _helpDiagnosticsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 2),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Failed to load diagnostics: ${snapshot.error}',
                      );
                    }

                    final diagnostics =
                        snapshot.data ?? const <String, String>{};
                    final dbPath =
                        diagnostics['Database Path'] ?? 'Unavailable';
                    final machineCount = diagnostics['Machine Count'] ?? '-';
                    final employeeCount = diagnostics['Employee Count'] ?? '-';
                    final contractorCount =
                        diagnostics['Contractor Count'] ?? '-';
                    final vendorCount = diagnostics['Vendor Count'] ?? '-';
                    final vendorPartRows =
                        diagnostics['Vendor Part Rows'] ?? '-';
                    final vendorPartUsages =
                        diagnostics['Vendor Part Usages'] ?? '-';
                    final healthStatus = diagnostics['Health Status'] ?? '-';
                    final missingTables = diagnostics['Missing Tables'] ?? '-';
                    final isHealthy = healthStatus.toUpperCase() == 'OK';
                    final statusColor = isHealthy
                        ? Colors.green.shade700
                        : Colors.orange.shade800;
                    final statusBackground = isHealthy
                        ? Colors.green.shade50
                        : Colors.orange.shade50;
                    final hasMissingTables =
                        missingTables.trim().isNotEmpty &&
                        missingTables.trim().toLowerCase() != 'none' &&
                        missingTables.trim() != '-';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText('Database Path: $dbPath'),
                        const SizedBox(height: 4),
                        Text('Machine Count: $machineCount'),
                        Text('Employee Count: $employeeCount'),
                        Text('Contractor Count: $contractorCount'),
                        Text('Vendor Count: $vendorCount'),
                        Text('Vendor Part Rows: $vendorPartRows'),
                        Text('Vendor Part Usages: $vendorPartUsages'),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Health Status:'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusBackground,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: statusColor),
                              ),
                              child: Text(
                                healthStatus,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SelectableText('Missing Tables: $missingTables'),
                        if (hasMissingTables) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Fix Suggestions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '1. Press Reload Saved Data and run DB Health Check again.',
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '2. Import the latest Database JSON backup to restore missing structures/data.',
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            '3. If still failing, copy diagnostics and share for troubleshooting.',
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        await _reloadMachinesFromDatabase(
                                          showFeedback: true,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _helpDiagnosticsFuture =
                                              _buildHelpDiagnostics();
                                        });
                                      },
                                icon: const Icon(Icons.refresh_outlined),
                                label: const Text('Reload + Recheck'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        await _importDatabaseBackup();
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _helpDiagnosticsFuture =
                                              _buildHelpDiagnostics();
                                        });
                                      },
                                icon: const Icon(Icons.upload_file_outlined),
                                label: const Text('Import Backup JSON'),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final details = StringBuffer()
                              ..writeln('Database Path: $dbPath')
                              ..writeln('Machine Count: $machineCount')
                              ..writeln('Employee Count: $employeeCount')
                              ..writeln('Contractor Count: $contractorCount')
                              ..writeln('Vendor Count: $vendorCount')
                              ..writeln('Vendor Part Rows: $vendorPartRows')
                              ..writeln('Vendor Part Usages: $vendorPartUsages')
                              ..writeln('Health Status: $healthStatus')
                              ..writeln('Missing Tables: $missingTables');
                            final now = DateTime.now();
                            final yyyy = now.year.toString().padLeft(4, '0');
                            final mm = now.month.toString().padLeft(2, '0');
                            final dd = now.day.toString().padLeft(2, '0');
                            final hh = now.hour.toString().padLeft(2, '0');
                            final min = now.minute.toString().padLeft(2, '0');
                            final ss = now.second.toString().padLeft(2, '0');

                            final result = await FilePicker.saveFile(
                              dialogTitle: 'Export Diagnostics',
                              fileName:
                                  'diagnostics_$yyyy$mm${dd}_$hh$min$ss.txt',
                              type: FileType.custom,
                              allowedExtensions: ['txt'],
                              bytes: Uint8List.fromList(
                                utf8.encode(details.toString()),
                              ),
                            );
                            if (result == null) {
                              return;
                            }

                            if (!mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Diagnostics exported to: $result',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Export Diagnostics'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>> _buildHelpDiagnostics() async {
    final dbPath = await MachineDatabase.instance.activeDatabasePath();
    final machines = await MachineDatabase.instance.getMachines();
    final employees = await MachineDatabase.instance.getEmployees();
    final contractors = await MachineDatabase.instance.getContractorCompanies();
    final healthCheck = await MachineDatabase.instance.getDatabaseHealthCheck();
    final vendorUsage = _collectVendorPartUsage(
      searchQuery: '',
      includeUnspecifiedVendor: true,
    );

    var vendorPartRows = 0;
    var vendorPartUsages = 0;
    for (final entries in vendorUsage.values) {
      vendorPartRows += entries.length;
      for (final usage in entries) {
        vendorPartUsages += usage.occurrences;
      }
    }

    return <String, String>{
      'Database Path': dbPath,
      'Machine Count': machines.length.toString(),
      'Employee Count': employees.length.toString(),
      'Contractor Count': contractors.length.toString(),
      'Vendor Count': vendorUsage.length.toString(),
      'Vendor Part Rows': vendorPartRows.toString(),
      'Vendor Part Usages': vendorPartUsages.toString(),
      'Health Status': healthCheck['Health Status'] ?? 'Unknown',
      'Missing Tables': healthCheck['Missing Tables'] ?? 'Unknown',
    };
  }

  Future<void> _showTabOrderDialog() async {
    final workingOrder = List<_AppTab>.from(_tabOrder);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.all(24.0),
              title: const Text('Customize Tab Order'),
              content: SizedBox(
                width: 400.0,
                height: 360,
                child: ReorderableListView.builder(
                  itemCount: workingOrder.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setDialogState(() {
                      final item = workingOrder.removeAt(oldIndex);
                      workingOrder.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final tab = workingOrder[index];
                    return ListTile(
                      key: ValueKey(tab),
                      leading: Icon(_tabIcon(tab)),
                      title: Text(_tabTitle(tab)),
                      trailing: const Icon(Icons.drag_handle),
                    );
                  },
                ),
              ),
              actions: _dialogActionsForContext(dialogContext, [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Save'),
                ),
              ]),
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    final normalized = _normalizeTabOrder(workingOrder);
    if (!mounted) {
      return;
    }

    setState(() {
      _tabOrder = normalized;
    });
    await _persistTabOrder(normalized);
  }

  @override
  void dispose() {
    _vendorsSearchPersistDebounce?.cancel();
    _machineDraft.dispose();
    _taskSearchController.dispose();
    _employeeNameController.dispose();
    _employeeEmailController.dispose();
    _employeeCellPhoneController.dispose();
    _employeePhoneNumberController.dispose();
    _employeePhoneExtensionController.dispose();
    _employeeSearchController.dispose();
    _bulkRandomRowsController.dispose();
    _bulkRandomMachinesController.dispose();
    _bulkRandomEmployeesController.dispose();
    _bulkRandomContractorsController.dispose();
    _disposeSubAssemblyDrafts(_subAssemblyDrafts);
    _disposeMaintenanceDueDetailDrafts();
    super.dispose();
  }

  void _disposeSubAssemblyDrafts(List<SubAssemblyDraft> drafts) {
    for (final draft in drafts) {
      draft.dispose();
    }
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatHistoryTimestamp(String rawUtcIso) {
    final parsed = DateTime.tryParse(rawUtcIso);
    if (parsed == null) {
      return rawUtcIso;
    }

    final local = parsed.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  String _randomLastCheckDate(Random rng, {int maxDaysBack = 730}) {
    final daysBack = rng.nextInt(maxDaysBack + 1);
    final date = DateTime.now().subtract(Duration(days: daysBack));
    return _formatDate(date);
  }

  String _randomAlphaNumeric(Random rng, {int minLen = 4, int maxLen = 14}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final length = minLen + rng.nextInt((maxLen - minLen) + 1);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  List<String> _buildSampleAdditionalRequiredLicenses(Random rng) {
    final sourceLicenses = _licenseTypeOptions.isEmpty
        ? _customLicenseTypes
        : _licenseTypeOptions;
    final choices = List<String>.from(sourceLicenses);
    if (choices.isEmpty) {
      return const [];
    }

    choices.shuffle(rng);
    final limit = choices.length < 3 ? choices.length : 3;
    final count = rng.nextInt(limit + 1);
    return choices.take(count).toList(growable: false);
  }

  List<String> _buildSampleEmployeeSkills(Random rng) {
    final skillPool = _availableSkillTypes.isEmpty
        ? List<String>.from(_defaultEmployeeSkills)
        : List<String>.from(_availableSkillTypes);
    final normalized = skillPool
        .map((skill) => skill.trim())
        .where((skill) => skill.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalized.isEmpty) {
      return const ['Mechanic'];
    }

    final shuffled = List<String>.from(normalized)..shuffle(rng);
    final limit = shuffled.length < 3 ? shuffled.length : 3;
    final count = 1 + rng.nextInt(limit);
    return shuffled.take(count).toList(growable: false);
  }

  List<String> _buildSampleEmployeeLicenses(Random rng) {
    final licensePool = _licenseTypeOptions;
    final normalized = licensePool
        .map((license) => license.trim())
        .where((license) => license.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalized.isEmpty) {
      return const [];
    }

    // Some employees intentionally have no license assignment.
    if (rng.nextInt(100) < 35) {
      return const [];
    }

    final shuffled = List<String>.from(normalized)..shuffle(rng);
    final limit = shuffled.length < 2 ? shuffled.length : 2;
    final count = 1 + rng.nextInt(limit);
    return shuffled.take(count).toList(growable: false);
  }

  List<Employee> _buildSampleEmployees({Random? rng, int count = 15}) {
    const firstNames = [
      'Alex',
      'Jordan',
      'Taylor',
      'Casey',
      'Morgan',
      'Riley',
      'Jamie',
      'Cameron',
      'Drew',
      'Skyler',
    ];
    const lastNames = [
      'Andersson',
      'Karlsson',
      'Lindberg',
      'Svensson',
      'Eriksson',
      'Holm',
      'Nordin',
      'Berg',
      'Dahl',
      'Wikstrom',
    ];

    final random = rng ?? Random(20260318 ^ 0x35E5);
    final employeeCount = count < 1 ? 1 : count;

    return List<Employee>.generate(employeeCount, (index) {
      final first = firstNames[random.nextInt(firstNames.length)];
      final last = lastNames[random.nextInt(lastNames.length)];
      final sequence = _randomAlphaNumeric(random, minLen: 2, maxLen: 5);
      final emailLocal =
          '${first.toLowerCase()}.${last.toLowerCase()}${_randomAlphaNumeric(random, minLen: 2, maxLen: 6).toLowerCase()}';
      final email = '$emailLocal@example.com';
      final cellPhone =
          '${100 + random.nextInt(900)}-${100 + random.nextInt(900)}-${1000 + random.nextInt(9000)}';
      final phoneNumber =
          '${100 + random.nextInt(900)}-${100 + random.nextInt(900)}-${1000 + random.nextInt(9000)}';
      final phoneExtension = _randomAlphaNumeric(random, minLen: 2, maxLen: 5);
      return Employee(
        name: '$first $last $sequence',
        email: email,
        cellPhone: cellPhone,
        phoneNumber: phoneNumber,
        phoneExtension: phoneExtension,
        skills: _buildSampleEmployeeSkills(random),
        licenses: _buildSampleEmployeeLicenses(random),
      );
    });
  }

  List<Machine> _buildSampleMachines({
    Random? rng,
    String serialPrefix = 'SIM',
    int count = 15,
  }) {
    const manufacturers = [
      'Cincinnati Milling Machine Company',
      'Bridgeport Machines, Inc.',
      'Brown & Sharpe',
      'South Bend Lathe Works',
      'Warner & Swasey Company',
      'Monarch Machine Tool Company',
      'Pratt & Whitney',
      'Kearney & Trecker',
      'Hardings Brothers, Inc.',
      'Jones & Lamson Machine Company',
      'Bullard Company',
      'Landis Tool Company',
      'Norton Company',
      'Gisholt Machine Company',
      'Atlas Press Company',
    ];
    const modelNames = [
      'Engine Lathes',
      'Turret Lathes',
      'Milling Machines',
      'Shapers',
      'Planers',
      'Radial Drill Presses',
      'Sensitive Drill Presses',
      'Surface Grinders',
      'Cylindrical Grinders',
      'Centerless Grinders',
      'Horizontal Boring Mills',
      'Vertical Boring Mills',
      'Broaching Machines',
      'Gear Cutters and Hobbers',
      'Power Hack Saws',
      'Metal-Cutting Band Saws',
      'Mechanical Press Brakes',
      'Punch Presses',
      'Drop Hammers',
      'Screw Machines',
    ];
    const locations = [
      'North Yard',
      'South Yard',
      'Plant A',
      'Plant B',
      'Field Depot',
    ];

    final random = rng ?? Random(20260318);
    final normalizedPrefix = serialPrefix
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '')
        .toUpperCase();
    final machineCount = count < 1 ? 1 : count;

    return List<Machine>.generate(machineCount, (index) {
      final manufacturer = manufacturers[index % manufacturers.length];
      final modelName = modelNames[index % modelNames.length];
      final location = locations[index % locations.length];
      final machineSerial =
          '$serialPrefix-${index + 1}-${_randomAlphaNumeric(random, minLen: 4, maxLen: 8)}';
      const subAssemblyCount = 10;
      final noLicenseRequired = random.nextInt(100) < 30;
      final additionalLicenses = noLicenseRequired
          ? const <String>[]
          : _buildSampleAdditionalRequiredLicenses(random);

      return Machine(
        name: 'Machine ${_randomAlphaNumeric(random, minLen: 3, maxLen: 10)}',
        modelName: modelName,
        modelNumber:
            '${manufacturer.substring(0, 3).toUpperCase()}-${_randomAlphaNumeric(random, minLen: 3, maxLen: 7)}',
        operatingHours: '${900 + random.nextInt(3500)}',
        idleHours: '${80 + random.nextInt(900)}',
        lastCheckDate: _randomLastCheckDate(random),
        serialNumber: machineSerial,
        location:
            '$location ${_randomAlphaNumeric(random, minLen: 2, maxLen: 5)}',
        manufacturer: manufacturer,
        maintenanceDocumentName:
            'Maintenance Manual ${_randomAlphaNumeric(random, minLen: 4, maxLen: 9)}',
        maintenanceDocumentNumber:
            '${normalizedPrefix.isEmpty ? 'SIM' : normalizedPrefix}-DOC-${index + 1}-${_randomAlphaNumeric(random, minLen: 4, maxLen: 9)}',
        maintenancePublisher:
            'Engineering ${_randomAlphaNumeric(random, minLen: 3, maxLen: 6)}',
        requiresHvacLicense: noLicenseRequired ? false : random.nextBool(),
        requiresRefrigerationLicense: noLicenseRequired
            ? false
            : random.nextBool(),
        requiresPlumberLicense: noLicenseRequired ? false : random.nextBool(),
        requiresElectricianLicense: noLicenseRequired
            ? false
            : random.nextBool(),
        requiresBoilerLicense: noLicenseRequired ? false : random.nextBool(),
        additionalRequiredLicenses: additionalLicenses,
        subAssemblies: _buildSampleSubAssemblies(
          machineSerial: machineSerial,
          manufacturer: manufacturer,
          location: location,
          startIndex: index * subAssemblyCount,
          count: subAssemblyCount,
          rng: random,
        ),
      );
    });
  }

  List<SubAssembly> _buildSampleSubAssemblies({
    required String machineSerial,
    required String manufacturer,
    required String location,
    required int startIndex,
    required int count,
    Random? rng,
  }) {
    const subCategories = [
      'Hydraulic Pump',
      'Cooling Fan',
      'Control Panel',
      'Drive Motor',
      'Fuel Module',
      'Gearbox',
      'Valve Block',
      'Sensor Array',
      'Compressor',
      'Power Unit',
    ];

    final random = rng ?? Random(20260318);
    final subCategoryChoices = _availableSubCategories.isEmpty
        ? _subCategories
        : _availableSubCategories;
    final superCategoryChoices = _availableSuperCategories.isEmpty
        ? _maintenanceSuperCategory
        : _availableSuperCategories;
    final taskTypeChoices = _availableMaintenanceTaskTypes.isEmpty
        ? _maintenanceTaskTypes
        : _availableMaintenanceTaskTypes;

    return List<SubAssembly>.generate(count, (offset) {
      final componentName = subCategories[random.nextInt(subCategories.length)];
      final serialBase = machineSerial.replaceAll('SIM-', 'SUB');

      return SubAssembly(
        name:
            '$componentName ${_randomAlphaNumeric(random, minLen: 2, maxLen: 6)}',
        modelName: componentName,
        modelNumber: 'SA-${_randomAlphaNumeric(random, minLen: 4, maxLen: 8)}',
        operatingHours: '${100 + random.nextInt(1800)}',
        idleHours: '${10 + random.nextInt(350)}',
        serialNumber:
            '$serialBase-${_randomAlphaNumeric(random, minLen: 3, maxLen: 7)}',
        location:
            '$location-${_randomAlphaNumeric(random, minLen: 2, maxLen: 4)}',
        manufacturer: manufacturer,
        maintenanceDocumentName:
            'Sub-Assembly Manual ${_randomAlphaNumeric(random, minLen: 5, maxLen: 10)}',
        maintenanceDocumentNumber:
            'SUBDOC-${startIndex + offset + 1}-${_randomAlphaNumeric(random, minLen: 5, maxLen: 10)}',
        maintenancePublisher:
            'Engineering ${_randomAlphaNumeric(random, minLen: 3, maxLen: 6)}',
        superCategory:
            superCategoryChoices[random.nextInt(superCategoryChoices.length)],
        subCategory:
            subCategoryChoices[random.nextInt(subCategoryChoices.length)],
        maintenanceTasks: List<MaintenanceTask>.generate(
          taskTypeChoices.length,
          (taskIndex) => MaintenanceTask(
            taskType: taskTypeChoices[taskIndex],
            timeCategory:
                _maintenanceTimeCategories[random.nextInt(
                  _maintenanceTimeCategories.length,
                )],
            timeValue: random.nextInt(23) + 1,
            requiredParts: List<RequiredPart>.generate(
              1 + random.nextInt(3),
              (_) => RequiredPart(
                oemPn: _randomAlphaNumeric(random, minLen: 5, maxLen: 11),
                vendorPn: _randomAlphaNumeric(random, minLen: 5, maxLen: 11),
                vendorName:
                    'Vendor ${_randomAlphaNumeric(random, minLen: 3, maxLen: 8)}',
                vendorUrl:
                    'https://vendor-${_randomAlphaNumeric(random, minLen: 4, maxLen: 8).toLowerCase()}.example.com',
                vendorPhoneNumber:
                    '${100 + random.nextInt(900)}-${100 + random.nextInt(900)}-${1000 + random.nextInt(9000)}',
                estimatedLeadTime:
                    '${1 + random.nextInt(24)} ${random.nextBool() ? 'days' : 'weeks'}',
              ),
            ),
          ),
        ),
      );
    });
  }

  Future<void> _loadMachines({bool seedSampleData = true}) async {
    try {
      var machines = await _withDatabaseLoadTimeout(
        () => MachineDatabase.instance.getMachines(),
      );
      final employees = await _withDatabaseLoadTimeout(
        () => MachineDatabase.instance.getEmployees(),
      );

      if (!seedSampleData) {
        _openHelpTabIfNoDatabaseFound(machines: machines, employees: employees);

        if (!mounted) {
          return;
        }

        setState(() {
          _machines
            ..clear()
            ..addAll(machines);
          _employees
            ..clear()
            ..addAll(employees);
          _pruneMaintenanceDueState();
          _isLoading = false;
          _startupLoadError = null;
          _hasAttemptedDatabaseRecovery = false;
        });
        return;
      }

      _openHelpTabIfNoDatabaseFound(machines: machines, employees: employees);

      if (!mounted) {
        return;
      }

      setState(() {
        _machines
          ..clear()
          ..addAll(machines);
        _employees
          ..clear()
          ..addAll(employees);
        _pruneMaintenanceDueState();
        _isLoading = false;
        _startupLoadError = null;
        _hasAttemptedDatabaseRecovery = false;
      });

      if (machines.isEmpty) {
        return;
      }

      if (machines.isNotEmpty) {
        Future<void>(() async {
          await _runSampleDataBackfills(machines);
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _startupLoadError = _visibleDatabaseLoadFailureMessage(error);
      });

      if (!_hasAttemptedDatabaseRecovery) {
        _hasAttemptedDatabaseRecovery = true;
        try {
          if (_isDatabaseTimeoutOrLockError(error)) {
            await MachineDatabase.instance.reconnectDatabase();
          } else {
            await MachineDatabase.instance.attemptDatabaseRecovery();
          }
          if (!mounted) {
            return;
          }
          await _loadMachines(seedSampleData: seedSampleData);
          return;
        } catch (_) {
          // Keep original error surface if recovery also fails.
        }
      }

      _openHelpTabForDatabaseFailure();
      _showErrorSnackBar('Failed to load saved machines.', error);
    }
  }

  void _openHelpTabIfNoDatabaseFound({
    required List<Machine> machines,
    required List<Employee> employees,
  }) {
    if (_hasAutoOpenedHelpForMissingDatabase) {
      return;
    }

    final openedExistingDatabaseFile =
        MachineDatabase.instance.openedExistingDatabaseFile;
    final isStartupDataEmpty = machines.isEmpty && employees.isEmpty;
    if (openedExistingDatabaseFile && !isStartupDataEmpty) {
      return;
    }

    _hasAutoOpenedHelpForMissingDatabase = true;
    if (mounted) {
      setState(() {
        _pendingStartupTab = _AppTab.help;
        _preferHelpStartupTab = true;
        _tabControllerEpoch += 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _switchToTab(_AppTab.help);
      });
    } else {
      _pendingStartupTab = _AppTab.help;
      _preferHelpStartupTab = true;
      _tabControllerEpoch += 1;
    }

    if (!mounted) {
      return;
    }

    final message = openedExistingDatabaseFile
        ? 'Database is empty. Opened Help tab for setup guidance.'
        : 'No existing database file was found. Opened Help tab for setup guidance.';

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openHelpTabForDatabaseFailure() {
    if (_hasAutoOpenedHelpForDatabaseFailure) {
      return;
    }

    _hasAutoOpenedHelpForDatabaseFailure = true;
    if (mounted) {
      setState(() {
        _pendingStartupTab = _AppTab.help;
        _preferHelpStartupTab = true;
        _tabControllerEpoch += 1;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _switchToTab(_AppTab.help);
      });
    } else {
      _pendingStartupTab = _AppTab.help;
      _preferHelpStartupTab = true;
      _tabControllerEpoch += 1;
    }

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Database failed to load. Opened Help tab for troubleshooting steps.',
        ),
      ),
    );
  }

  Future<void> _reloadMachinesFromDatabase({bool showFeedback = false}) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _startupLoadError = null;
      });
    }

    try {
      final machines = await _withDatabaseLoadTimeout(
        () => MachineDatabase.instance.getMachines(),
      );
      final employees = await _withDatabaseLoadTimeout(
        () => MachineDatabase.instance.getEmployees(),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _machines
          ..clear()
          ..addAll(machines);
        _employees
          ..clear()
          ..addAll(employees);
        _pruneMaintenanceDueState();
        _isLoading = false;
        _startupLoadError = null;
        _hasAttemptedDatabaseRecovery = false;
      });

      if (showFeedback) {
        final subAssemblyCount = machines.expand((m) => m.subAssemblies).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reloaded ${machines.length} machines and $subAssemblyCount sub-assemblies.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _startupLoadError = _visibleDatabaseLoadFailureMessage(error);
      });

      if (!_hasAttemptedDatabaseRecovery) {
        _hasAttemptedDatabaseRecovery = true;
        try {
          if (_isDatabaseTimeoutOrLockError(error)) {
            await MachineDatabase.instance.reconnectDatabase();
          } else {
            await MachineDatabase.instance.attemptDatabaseRecovery();
          }
          if (!mounted) {
            return;
          }
          await _reloadMachinesFromDatabase(showFeedback: showFeedback);
          return;
        } catch (_) {
          // Keep original error surface if recovery also fails.
        }
      }

      _openHelpTabForDatabaseFailure();
      _showErrorSnackBar('Failed to reload database data.', error);
    }
  }

  Future<T> _withDatabaseLoadTimeout<T>(Future<T> Function() operation) async {
    final initialTimeout = databaseLoadInitialTimeout;
    final retryTimeout = databaseLoadRetryTimeout;

    try {
      return await operation().timeout(
        initialTimeout,
        onTimeout: () => throw TimeoutException(
          'Timed out while waiting for the local database.',
        ),
      );
    } on TimeoutException {
      // Slow desktop disks or temporary file locks can make the first load miss
      // the deadline; reconnect and retry once before surfacing an error.
      try {
        await MachineDatabase.instance.reconnectDatabase();
      } catch (_) {
        // Ignore reconnect errors here and still perform one final retry.
      }

      try {
        return await operation().timeout(
          retryTimeout,
          onTimeout: () => throw TimeoutException(
            'Timed out while waiting for the local database after retry.',
          ),
        );
      } on TimeoutException {
        throw TimeoutException(
          'Timed out while waiting for the local database after retry.',
        );
      }
    }
  }

  String _databaseLoadFailureMessage(Object error) {
    final message = error.toString().toLowerCase();
    final detail = _shortErrorSummary(error);
    if (message.contains('databasefactory not initialized')) {
      return _webDatabaseNotice;
    }
    if (message.contains('timed out') || message.contains('timeout')) {
      return detail.isEmpty
          ? 'Database timed out while loading.'
          : 'Database timed out while loading. $detail';
    }
    if (message.contains('unable to open') || message.contains('cantopen')) {
      return detail.isEmpty
          ? 'Database file could not be opened.'
          : 'Database file could not be opened. $detail';
    }
    if (message.contains('access is denied') ||
        message.contains('permission')) {
      return detail.isEmpty
          ? 'Database access was denied by the system.'
          : 'Database access was denied by the system. $detail';
    }
    return detail.isEmpty
        ? 'Database failed to load.'
        : 'Database failed to load. $detail';
  }

  String? _visibleDatabaseLoadFailureMessage(Object error) {
    final message = _databaseLoadFailureMessage(error);
    if (message == _webDatabaseNotice && _isWebDatabaseNoticeDismissed) {
      return null;
    }
    return message;
  }

  String _shortErrorSummary(Object error) {
    final raw = error.toString().trim();
    if (raw.isEmpty) {
      return '';
    }

    final causingIndex = raw.toLowerCase().indexOf('causing statement:');
    if (causingIndex >= 0) {
      final statement = raw.substring(causingIndex).trim();
      return statement.length <= 180
          ? statement
          : '${statement.substring(0, 180)}...';
    }

    final firstLine = raw.split('\n').first.trim();
    return firstLine.length <= 180
        ? firstLine
        : '${firstLine.substring(0, 180)}...';
  }

  bool _isDatabaseTimeoutOrLockError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('database is locked') ||
        message.contains('database locked') ||
        message.contains('sql_busy') ||
        message.contains('busy timeout');
  }

  void _ensureMachinesVisible() {
    if (_isLoading || _machines.isNotEmpty) {
      return;
    }

    final now = DateTime.now().toUtc();
    final lastAttempt = _lastVisibilityReloadAttemptUtc;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 2)) {
      return;
    }

    _lastVisibilityReloadAttemptUtc = now;
    Future<void>(() async {
      await _reloadMachinesFromDatabase();
    });
  }

  Future<void> _runSampleDataBackfills(List<Machine> machines) async {
    try {
      final dateRng = Random(20260318);
      final missingLastCheckDate = machines
          .where((machine) => machine.lastCheckDate.trim().isEmpty)
          .toList(growable: false);
      if (missingLastCheckDate.isNotEmpty) {
        for (final machine in missingLastCheckDate) {
          final machineId = machine.id;
          if (machineId == null) {
            continue;
          }
          await MachineDatabase.instance.updateMachineLastCheckDate(
            machineId,
            _randomLastCheckDate(dateRng),
          );
        }
        machines = await MachineDatabase.instance.getMachines();
      }

      final sampleMachines = machines
          .where((machine) => machine.serialNumber.startsWith('SIM-'))
          .toList(growable: false);
      final missingSampleSubAssemblies = sampleMachines.where(
        (machine) => machine.subAssemblies.isEmpty,
      );

      if (missingSampleSubAssemblies.isNotEmpty) {
        for (final machine in missingSampleSubAssemblies) {
          final machineId = machine.id;
          if (machineId == null) {
            continue;
          }

          const missingCount = 8;
          final additions = _buildSampleSubAssemblies(
            machineSerial: machine.serialNumber,
            manufacturer: machine.manufacturer,
            location: machine.location,
            startIndex: machine.subAssemblies.length,
            count: missingCount,
          );

          final updatedMachine = machine.copyWith(
            subAssemblies: [...machine.subAssemblies, ...additions],
          );

          await MachineDatabase.instance.updateMachine(updatedMachine);
        }

        machines = await MachineDatabase.instance.getMachines();
      }

      final sampleMissingTasks = sampleMachines.where(
        (machine) => machine.subAssemblies.any(
          (subAssembly) => subAssembly.maintenanceTasks.isEmpty,
        ),
      );

      if (sampleMissingTasks.isNotEmpty) {
        for (final machine in sampleMissingTasks) {
          final updatedSubAssemblies = machine.subAssemblies
              .map((subAssembly) {
                if (subAssembly.maintenanceTasks.isNotEmpty) {
                  return subAssembly;
                }

                final generatedTasks = List<MaintenanceTask>.generate(
                  _availableMaintenanceTaskTypes.length,
                  (taskIndex) => MaintenanceTask(
                    taskType: _availableMaintenanceTaskTypes[taskIndex],
                    timeCategory:
                        _maintenanceTimeCategories[taskIndex %
                            _maintenanceTimeCategories.length],
                    timeValue: (taskIndex * 7 + 3) % 23 + 1,
                  ),
                );

                return subAssembly.copyWith(maintenanceTasks: generatedTasks);
              })
              .toList(growable: false);

          await MachineDatabase.instance.updateMachine(
            machine.copyWith(subAssemblies: updatedSubAssemblies),
          );
        }

        machines = await MachineDatabase.instance.getMachines();
      }

      // Backfill subCategory for sample sub-assemblies that have none.
      final sampleMissingSubCategory = machines
          .where((m) => m.serialNumber.startsWith('SIM-'))
          .where((m) => m.subAssemblies.any((sa) => sa.subCategory.isEmpty))
          .toList(growable: false);

      if (sampleMissingSubCategory.isNotEmpty) {
        final subCategoryChoices = _availableSubCategories;
        for (final machine in sampleMissingSubCategory) {
          final updatedSubAssemblies = machine.subAssemblies
              .asMap()
              .entries
              .map((entry) {
                final sa = entry.value;
                if (sa.subCategory.isNotEmpty) return sa;
                return sa.copyWith(
                  subCategory:
                      subCategoryChoices[entry.key % subCategoryChoices.length],
                );
              })
              .toList(growable: false);
          await MachineDatabase.instance.updateMachine(
            machine.copyWith(subAssemblies: updatedSubAssemblies),
          );
        }
        machines = await MachineDatabase.instance.getMachines();
      }

      final customLicenseChoices = _customLicenseTypes;
      final sampleMissingAdditionalLicenses = customLicenseChoices.isEmpty
          ? const <Machine>[]
          : machines
                .where((m) => m.serialNumber.startsWith('SIM-'))
                .where((m) => m.additionalRequiredLicenses.isEmpty)
                .toList(growable: false);

      if (sampleMissingAdditionalLicenses.isNotEmpty) {
        final licenseRng = Random(20260318 ^ 0x51A7);
        for (final machine in sampleMissingAdditionalLicenses) {
          final generatedLicenses = _buildSampleAdditionalRequiredLicenses(
            licenseRng,
          );
          if (generatedLicenses.isEmpty) {
            continue;
          }

          await MachineDatabase.instance.updateMachine(
            machine.copyWith(additionalRequiredLicenses: generatedLicenses),
          );
        }
        machines = await MachineDatabase.instance.getMachines();
      }

      // Backfill timeValue for sample tasks that still have the default 0.
      final rng = Random(42);
      final sampleMissingTimeValue = machines
          .where((m) => m.serialNumber.startsWith('SIM-'))
          .where(
            (m) => m.subAssemblies.any(
              (sa) => sa.maintenanceTasks.any((t) => t.timeValue == 0),
            ),
          )
          .toList(growable: false);

      if (sampleMissingTimeValue.isNotEmpty) {
        for (final machine in sampleMissingTimeValue) {
          final updatedSubAssemblies = machine.subAssemblies
              .map((sa) {
                final hasMissing = sa.maintenanceTasks.any(
                  (t) => t.timeValue == 0,
                );
                if (!hasMissing) return sa;
                final tasks = sa.maintenanceTasks
                    .map(
                      (t) => t.timeValue == 0
                          ? t.copyWith(timeValue: rng.nextInt(23) + 1)
                          : t,
                    )
                    .toList(growable: false);
                return sa.copyWith(maintenanceTasks: tasks);
              })
              .toList(growable: false);
          await MachineDatabase.instance.updateMachine(
            machine.copyWith(subAssemblies: updatedSubAssemblies),
          );
        }
        machines = await MachineDatabase.instance.getMachines();
      }

      // Seed history for sample machines on first launch.
      final historySampleMachines = machines
          .where((m) => m.serialNumber.startsWith('SIM-'))
          .toList(growable: false);
      if (historySampleMachines.isNotEmpty) {
        final hasHistory = await MachineDatabase.instance
            .hasMachineDetailHistory();
        if (!hasHistory) {
          final historyRng = Random(20260318 ^ 0xABCD1234);
          await MachineDatabase.instance.insertSampleHistory(
            historySampleMachines,
            historyRng,
          );
          machines = await MachineDatabase.instance.getMachines();
        }
      }

      if (!mounted) {
        return;
      }

      // Avoid stale async backfill runs from clobbering newly visible data.
      if (machines.isEmpty && _machines.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _machines
          ..clear()
          ..addAll(machines);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Failed to load saved machines.', error);
    }
  }

  List<SubAssembly> _currentSubAssembliesFromDrafts(
    List<SubAssemblyDraft> drafts,
  ) {
    return drafts.map((draft) => draft.toSubAssembly()).toList(growable: false);
  }

  String _normalizeDocumentNumber(String value) {
    return value.trim().toUpperCase();
  }

  bool get _hasTaskFilter {
    return _selectedTaskType != null ||
        _selectedTaskTimeCategory != null ||
        _selectedSuperCategory != null ||
        _selectedSubCategory != null ||
        _taskSearchQuery.trim().isNotEmpty;
  }

  bool _containsIgnoreCase(String source, String query) {
    return source.toLowerCase().contains(query.toLowerCase());
  }

  List<Machine> _getFilteredMachines() {
    if (!_hasTaskFilter) {
      return _machines;
    }

    final query = _taskSearchQuery.trim().toLowerCase();

    return _machines
        .map((machine) {
          final filteredSubAssemblies = machine.subAssemblies
              .map((subAssembly) {
                final matchesSuperCategory =
                    _selectedSuperCategory == null ||
                    subAssembly.superCategory == _selectedSuperCategory;
                if (!matchesSuperCategory) {
                  return null;
                }

                final filteredTasks = subAssembly.maintenanceTasks
                    .where((task) {
                      final matchesTaskType =
                          _selectedTaskType == null ||
                          task.taskType == _selectedTaskType;
                      final matchesTimeCategory =
                          _selectedTaskTimeCategory == null ||
                          task.timeCategory == _selectedTaskTimeCategory;

                      final matchesSearch =
                          query.isEmpty ||
                          _containsIgnoreCase(machine.name, query) ||
                          _containsIgnoreCase(machine.serialNumber, query) ||
                          _containsIgnoreCase(subAssembly.name, query) ||
                          _containsIgnoreCase(
                            subAssembly.serialNumber,
                            query,
                          ) ||
                          _containsIgnoreCase(task.taskType, query) ||
                          _containsIgnoreCase(task.timeCategory, query);

                      return matchesTaskType &&
                          matchesTimeCategory &&
                          matchesSearch;
                    })
                    .toList(growable: false);

                if (filteredTasks.isEmpty) {
                  return null;
                }

                final matchesSubCategory =
                    _selectedSubCategory == null ||
                    subAssembly.subCategory == _selectedSubCategory;

                if (!matchesSubCategory) {
                  return null;
                }

                return subAssembly.copyWith(maintenanceTasks: filteredTasks);
              })
              .whereType<SubAssembly>()
              .toList(growable: false);

          if (filteredSubAssemblies.isEmpty) {
            return null;
          }

          return machine.copyWith(subAssemblies: filteredSubAssemblies);
        })
        .whereType<Machine>()
        .toList(growable: false);
  }

  String? _checkInternalDocumentNumberDuplicates(Machine machine) {
    final allNumbers = <String>[];

    final machineDocumentNumber = _normalizeDocumentNumber(
      machine.maintenanceDocumentNumber,
    );
    if (machineDocumentNumber.isNotEmpty) {
      allNumbers.add(machineDocumentNumber);
    }

    for (final subAssembly in machine.subAssemblies) {
      final subDocumentNumber = _normalizeDocumentNumber(
        subAssembly.maintenanceDocumentNumber,
      );
      if (subDocumentNumber.isNotEmpty) {
        allNumbers.add(subDocumentNumber);
      }
    }

    final unique = allNumbers.toSet();
    if (unique.length != allNumbers.length) {
      return 'Maintenance document numbers must be unique for the machine and its sub-assemblies.';
    }

    return null;
  }

  Future<String?> _checkPersistedDocumentNumberConflicts(
    Machine machine, {
    int? editingMachineId,
  }) async {
    final machineNumber = machine.maintenanceDocumentNumber.trim();

    final machineConflict = await MachineDatabase.instance
        .hasMachineDocumentNumber(
          machineNumber,
          excludeMachineId: editingMachineId,
        );
    if (machineConflict) {
      return 'Maintenance document number already used by another machine.';
    }

    final machineVsSubConflict = await MachineDatabase.instance
        .hasSubAssemblyDocumentNumber(
          machineNumber,
          excludeMachineId: editingMachineId,
        );
    if (machineVsSubConflict) {
      return 'Maintenance document number already used by another sub-assembly.';
    }

    for (final subAssembly in machine.subAssemblies) {
      final subNumber = subAssembly.maintenanceDocumentNumber.trim();

      final subVsMachineConflict = await MachineDatabase.instance
          .hasMachineDocumentNumber(
            subNumber,
            excludeMachineId: editingMachineId,
          );
      if (subVsMachineConflict) {
        return 'A sub-assembly maintenance document number is already used by another machine.';
      }

      final subVsSubConflict = await MachineDatabase.instance
          .hasSubAssemblyDocumentNumber(
            subNumber,
            excludeMachineId: editingMachineId,
          );
      if (subVsSubConflict) {
        return 'A sub-assembly maintenance document number is already used by another sub-assembly.';
      }
    }

    return null;
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _numericRequiredValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }

    if (!RegExp(r'^\d+$').hasMatch(value!.trim())) {
      return 'Numbers only';
    }

    return null;
  }

  String? _dateRequiredValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }

    final text = value!.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      return 'Use YYYY-MM-DD';
    }

    final parts = text.split('-');
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return 'Use YYYY-MM-DD';
    }

    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return 'Enter a valid date';
    }

    return null;
  }

  void _showErrorSnackBar(String message, Object error) {
    final rawError = error.toString().trim();
    final details = rawError.isEmpty ? message : '$message\n\n$rawError';
    final summary = _shortErrorSummary(error);
    final resolvedMessage = message.trim().isEmpty
        ? 'Operation failed.'
        : message.trim();
    final lowerMessage = resolvedMessage.toLowerCase();
    final lowerError = rawError.toLowerCase();
    final content = lowerError.contains('databasefactory not initialized')
        ? _webDatabaseNotice
        : summary.isEmpty
        ? resolvedMessage
        : '$resolvedMessage $summary';
    final shouldPinToBanner =
        lowerMessage.contains('database') ||
        lowerError.contains('sqlite') ||
        lowerError.contains('sql logic error');

    final shouldShowBanner =
        content != _webDatabaseNotice || !_isWebDatabaseNoticeDismissed;
    if (shouldPinToBanner && shouldShowBanner && mounted) {
      setState(() {
        _startupLoadError = content;
      });
    }

    debugPrint(details);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(content),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Details',
          onPressed: () {
            Future<void>(() async {
              if (!mounted) {
                return;
              }

              await showDialog<void>(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    insetPadding: const EdgeInsets.all(24.0),
                    title: const Text('Database Error Details'),
                    content: SizedBox(
                      width: 720,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          details,
                          style: Theme.of(dialogContext).textTheme.bodySmall
                              ?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                    actions: _dialogActionsForContext(dialogContext, [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: details));
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error details copied to clipboard.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Copy'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('Close'),
                      ),
                    ]),
                  );
                },
              );
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadError = _startupLoadError;
    final startupTab =
        _pendingStartupTab ?? (_preferHelpStartupTab ? _AppTab.help : null);
    final startupTabIndex = startupTab == null
        ? 0
        : _normalizeTabOrder(_tabOrder).indexOf(startupTab);
    final resolvedStartupIndex =
        startupTabIndex >= 0 && startupTabIndex < _tabOrder.length
        ? startupTabIndex
        : 0;
    final controllerKey = ValueKey<String>(
      '${_tabOrder.map((tab) => tab.name).join('|')}|$_tabControllerEpoch',
    );

    return DefaultTabController(
      key: controllerKey,
      length: _tabOrder.length,
      initialIndex: resolvedStartupIndex,
      child: Builder(
        key: _tabControllerContextKey,
        builder: (tabControllerContext) {
          _activeTabController = DefaultTabController.maybeOf(
            tabControllerContext,
          );
          if (_pendingStartupTab != null || _preferHelpStartupTab) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              final pendingTab =
                  _pendingStartupTab ??
                  (_preferHelpStartupTab ? _AppTab.help : null);
              if (pendingTab == null) {
                return;
              }
              final controller = DefaultTabController.maybeOf(
                tabControllerContext,
              );
              final tabIndex = _normalizeTabOrder(
                _tabOrder,
              ).indexOf(pendingTab);
              if (controller != null &&
                  tabIndex >= 0 &&
                  tabIndex < controller.length) {
                if (controller.index != tabIndex) {
                  controller.index = tabIndex;
                }
                _pendingStartupTab = null;
                _preferHelpStartupTab = false;
                return;
              }

              _switchToTab(pendingTab);
            });
          }

          return KeyedSubtree(
            key: ValueKey<String>(_tabOrder.map((tab) => tab.name).join('|')),
            child: LayoutBuilder(
              builder: (layoutContext, constraints) {
                final width = constraints.maxWidth;
                final isPhone = width < _phoneLayoutMaxWidth;
                final isTablet =
                    width >= _phoneLayoutMaxWidth &&
                    width < _tabletLayoutMaxWidth;
                final isDesktop = !isPhone && !isTablet;

                Widget contentWithBanner() {
                  return Stack(
                    children: [
                      TabBarView(
                        children: [
                          for (final tab in _tabOrder) _tabViewFor(tab),
                        ],
                      ),
                      if (loadError != null)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.only(
                              left: 16,
                              top: 8,
                              bottom: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    loadError,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Dismiss notice',
                                  onPressed: () {
                                    setState(() {
                                      if (_startupLoadError ==
                                          _webDatabaseNotice) {
                                        _isWebDatabaseNoticeDismissed = true;
                                      }
                                      _startupLoadError = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                }

                Widget phoneDrawer() {
                  return Drawer(
                    child: SafeArea(
                      child: AnimatedBuilder(
                        animation:
                            _activeTabController ??
                            const AlwaysStoppedAnimation<int>(0),
                        builder: (context, _) {
                          final selectedIndex =
                              _activeTabController?.index ?? 0;
                          return ListView(
                            children: [
                              const DrawerHeader(
                                child: Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Text('Navigate'),
                                ),
                              ),
                              for (var i = 0; i < _tabOrder.length; i++)
                                ListTile(
                                  selected: i == selectedIndex,
                                  leading: Icon(_tabIcon(_tabOrder[i])),
                                  title: Text(_tabTitle(_tabOrder[i])),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    _switchToTab(_tabOrder[i]);
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                }

                if (isPhone) {
                  return Scaffold(
                    drawer: phoneDrawer(),
                    appBar: AppBar(
                      title: const Text('Schedular'),
                      bottom: _isLoading
                          ? const PreferredSize(
                              preferredSize: Size.fromHeight(2),
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : null,
                    ),
                    body: contentWithBanner(),
                  );
                }

                if (isTablet) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Schedular'),
                      bottom: PreferredSize(
                        preferredSize: Size.fromHeight(
                          72.0 + 8 + (_isLoading ? 2 : 0),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            TabBar(
                              isScrollable: true,
                              tabs: [
                                for (final tab in _tabOrder)
                                  Tab(
                                    text: _tabTitle(tab),
                                    icon: Icon(_tabIcon(tab)),
                                  ),
                              ],
                            ),
                            if (_isLoading)
                              const LinearProgressIndicator(minHeight: 2),
                          ],
                        ),
                      ),
                    ),
                    body: contentWithBanner(),
                  );
                }

                if (isDesktop) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Schedular'),
                      bottom: _isLoading
                          ? const PreferredSize(
                              preferredSize: Size.fromHeight(2),
                              child: LinearProgressIndicator(minHeight: 2),
                            )
                          : null,
                    ),
                    body: Row(
                      children: [
                        SingleChildScrollView(
                          child: IntrinsicHeight(
                            child: AnimatedBuilder(
                              animation:
                                  _activeTabController ??
                                  const AlwaysStoppedAnimation<int>(0),
                              builder: (context, _) {
                                final selectedIndex =
                                    _activeTabController?.index ?? 0;
                                return NavigationRail(
                                  selectedIndex: selectedIndex,
                                  onDestinationSelected: (index) {
                                    _switchToTab(_tabOrder[index]);
                                  },
                                  labelType: NavigationRailLabelType.all,
                                  extended: width >= 1450,
                                  destinations: [
                                    for (final tab in _tabOrder)
                                      NavigationRailDestination(
                                        icon: Icon(_tabIcon(tab)),
                                        label: Text(_tabTitle(tab)),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: contentWithBanner()),
                      ],
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}
