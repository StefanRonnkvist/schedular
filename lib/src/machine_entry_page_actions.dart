// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageActionsExtension on _MachineEntryPageState {
  bool get _opensPdfInViewerForPrinting =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  String get _workOrdersPdfActionLabel => _opensPdfInViewerForPrinting
      ? 'Open Work Orders PDF'
      : 'Print Work Orders PDF';

  String get _schedulePdfActionLabel =>
      _opensPdfInViewerForPrinting ? 'Open Schedule PDF' : 'Print Schedule PDF';

  String get _machinesListPdfActionLabel => _opensPdfInViewerForPrinting
      ? 'Open Machines List PDF'
      : 'Print Machines List PDF';

  bool get _opensBackupInViewer =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  IconData get _pdfActionIcon => _opensPdfInViewerForPrinting
      ? Icons.open_in_new_outlined
      : Icons.picture_as_pdf_outlined;

  /// Identifies database failures that can plausibly clear after a short delay
  /// or after reopening the database.
  bool _isTransientDatabaseGenerationError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('database is locked') ||
        message.contains('database locked') ||
        message.contains('database_busy') ||
        message.contains('busy timeout') ||
        message.contains('sql_busy') ||
        message.contains('timed out') ||
        message.contains('timeout') ||
        message.contains('unable to open database file') ||
        message.contains('sql_cantopen') ||
        message.contains('cannot open') ||
        message.contains('access is denied') ||
        message.contains('permission denied');
  }

  /// Runs a database-backed generation step with short, increasing delays.
  ///
  /// Non-transient failures are rethrown immediately. After the delayed retries
  /// are exhausted, one database recovery and final attempt are made. If that
  /// final attempt fails, the last transient error is preserved for diagnosis.
  Future<T> _runDatabaseGenerationStepWithRetry<T>(
    Future<T> Function() action,
  ) async {
    const retryDelays = <Duration>[
      Duration(milliseconds: 180),
      Duration(milliseconds: 380),
      Duration(milliseconds: 700),
    ];

    Object? lastError;
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        return await action();
      } catch (error) {
        lastError = error;
        if (!_isTransientDatabaseGenerationError(error)) {
          rethrow;
        }

        if (attempt < retryDelays.length) {
          await Future<void>.delayed(retryDelays[attempt]);
          continue;
        }
      }
    }

    // Last resort for transient/open failures: attempt a quick DB recovery and
    // retry once.
    await MachineDatabase.instance.attemptDatabaseRecovery();
    try {
      return await action();
    } catch (_) {
      throw lastError ?? StateError('Database generation failed.');
    }
  }

  Future<void> _presentBackupForReview(
    String fileName,
    String backupJson,
  ) async {
    if (_opensBackupInViewer) {
      final opened = await Printing.sharePdf(
        bytes: Uint8List.fromList(utf8.encode(backupJson)),
        filename: fileName,
      );

      if (!opened) {
        throw StateError('Unable to open $fileName.');
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Database backup copied to clipboard and opened as $fileName.',
          ),
        ),
      );
      return;
    }

    final preview = backupJson.length > 3500
        ? '${backupJson.substring(0, 3500)}\n\n...output truncated for preview...'
        : backupJson;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(24.0),
          title: const Text('Database Exported'),
          content: SizedBox(
            width: 400.0,
            child: SingleChildScrollView(
              child: SelectableText(
                preview,
                style: Theme.of(
                  dialogContext,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          actions: _dialogActionsForContext(dialogContext, [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ]),
        );
      },
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Database backup copied to clipboard as JSON.'),
      ),
    );
  }

  Future<void> _presentPdfForPrinting(
    String fileName,
    Uint8List pdfBytes, {
    required String successMessage,
  }) async {
    if (_opensPdfInViewerForPrinting) {
      final opened = await Printing.sharePdf(
        bytes: pdfBytes,
        filename: fileName,
      );

      if (!opened) {
        throw StateError('Unable to open $fileName.');
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
      return;
    }

    await Printing.layoutPdf(name: fileName, onLayout: (_) => pdfBytes);
  }

  Future<bool> _confirmRandomAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    if (!mounted) {
      return false;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(24.0),
          title: Text(title),
          content: Text(message),
          actions: _dialogActionsForContext(dialogContext, [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmLabel),
            ),
          ]),
        );
      },
    );

    return confirm == true;
  }

  Future<int?> _confirmRandomActionWithRowCount({
    required String title,
    required String message,
    required String confirmLabel,
    String rowLabel = 'Rows to generate',
    int initialCount = 15,
    int minCount = 1,
    int maxCount = 500,
    String Function(int rowCount)? estimateBuilder,
  }) async {
    if (!mounted) {
      return null;
    }

    final normalizedInitialCount = initialCount < minCount
        ? minCount
        : (initialCount > maxCount ? maxCount : initialCount);
    final rowController = TextEditingController(
      text: normalizedInitialCount.toString(),
    );
    try {
      final selectedCount = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          String? validationError;
          var previewCount = normalizedInitialCount;

          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              final estimateText = estimateBuilder?.call(previewCount);

              return AlertDialog(
                insetPadding: const EdgeInsets.all(24.0),
                title: Text(title),
                content: SizedBox(
                  width: 400.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rowController,
                        keyboardType: const TextInputType.numberWithOptions(
                          signed: false,
                          decimal: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          final parsedCount = int.tryParse(value.trim());
                          setDialogState(() {
                            if (parsedCount != null) {
                              final clampedCount = parsedCount < minCount
                                  ? minCount
                                  : (parsedCount > maxCount
                                        ? maxCount
                                        : parsedCount);
                              previewCount = clampedCount;
                              if (parsedCount != clampedCount) {
                                rowController.value = TextEditingValue(
                                  text: clampedCount.toString(),
                                  selection: TextSelection.collapsed(
                                    offset: clampedCount.toString().length,
                                  ),
                                );
                              }
                            }
                            validationError = null;
                          });
                        },
                        decoration: InputDecoration(
                          labelText: rowLabel,
                          helperText:
                              'Allowed range: $minCount to $maxCount rows.',
                          border: const OutlineInputBorder(),
                          errorText: validationError,
                        ),
                      ),
                      if (estimateText != null &&
                          estimateText.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            estimateText,
                            style: Theme.of(dialogContext).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                actions: _dialogActionsForContext(dialogContext, [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () {
                      final parsedCount = int.tryParse(
                        rowController.text.trim(),
                      );
                      if (parsedCount == null ||
                          parsedCount < minCount ||
                          parsedCount > maxCount) {
                        setDialogState(() {
                          validationError =
                              'Enter a whole number between $minCount and $maxCount.';
                        });
                        return;
                      }
                      Navigator.of(dialogContext).pop(parsedCount);
                    },
                    child: Text(confirmLabel),
                  ),
                ]),
              );
            },
          );
        },
      );

      return selectedCount;
    } finally {
      rowController.dispose();
    }
  }

  int _countDistinctVendorRowsFromMachines(List<Machine> machines) {
    final vendors = <String>{};
    var hasUnspecified = false;
    for (final machine in machines) {
      for (final subAssembly in machine.subAssemblies) {
        for (final task in subAssembly.maintenanceTasks) {
          for (final part in task.requiredParts) {
            if (part.isEmpty) {
              continue;
            }
            final vendorName = part.vendorName.trim();
            if (vendorName.isEmpty) {
              hasUnspecified = true;
            } else {
              vendors.add(vendorName);
            }
          }
        }
      }
    }

    return vendors.length + (hasUnspecified ? 1 : 0);
  }

  Future<void> _appendRandomAllDataWithRowCount(int rowCount) async {
    if (rowCount < 1 || rowCount > 500) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rows must be between 1 and 500.')),
      );
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);
      final serialPrefix = 'RND${DateTime.now().millisecondsSinceEpoch}';

      final existingEmployees = await MachineDatabase.instance.getEmployees();
      final existingEmployeeIds = existingEmployees
          .map((employee) => employee.id)
          .whereType<int>()
          .toSet();

      final machines = _buildSampleMachines(
        rng: rng,
        serialPrefix: serialPrefix,
        count: rowCount,
      );
      final employees = _withSyntheticEmployeeCoverage(
        _buildSampleEmployees(
          rng: Random(rng.nextInt(1 << 32)),
          count: rowCount,
        ),
        Random(rng.nextInt(1 << 32)),
      );

      await MachineDatabase.instance.insertMachines(machines);
      await MachineDatabase.instance.insertEmployees(employees);

      final allMachines = await MachineDatabase.instance.getMachines();
      final appendedMachines = allMachines
          .where((m) => m.serialNumber.startsWith(serialPrefix))
          .toList(growable: false);
      if (appendedMachines.isNotEmpty) {
        await MachineDatabase.instance.insertSampleHistory(
          appendedMachines,
          Random(rng.nextInt(1 << 32)),
        );
      }

      final allEmployees = await MachineDatabase.instance.getEmployees();
      final appendedEmployees = allEmployees
          .where(
            (employee) =>
                employee.id != null &&
                !existingEmployeeIds.contains(employee.id!),
          )
          .toList(growable: false);

      final contractorCompanies = _withSyntheticContractorCoverage(
        _buildSampleContractorCompanies(
          rng: Random(rng.nextInt(1 << 32)),
          count: rowCount,
        ),
        Random(rng.nextInt(1 << 32)),
      );
      var contractorCompanyCount = 0;
      var contractorContactCount = 0;
      for (final company in contractorCompanies) {
        final withSuffix = company.copyWith(
          companyName:
              '${company.companyName} ${DateTime.now().millisecondsSinceEpoch % 100000}',
        );
        final savedCompany = await MachineDatabase.instance
            .upsertContractorCompany(withSuffix);
        final companyId = savedCompany.id;
        if (companyId == null) {
          continue;
        }
        contractorCompanyCount += 1;
        final contacts = _buildSampleContractorContacts(companyId, rng);
        for (final contact in contacts) {
          await MachineDatabase.instance.upsertContractorEmployee(contact);
          contractorContactCount += 1;
        }
      }

      if (!mounted) {
        return;
      }

      final machineCount = appendedMachines.length;
      final subAssemblyCount = appendedMachines
          .expand((m) => m.subAssemblies)
          .length;
      final employeeCount = appendedEmployees.length;
      final vendorCount = _countDistinctVendorRowsFromMachines(allMachines);

      setState(() {
        _machines
          ..clear()
          ..addAll(allMachines);
        _employees
          ..clear()
          ..addAll(allEmployees);
        _pruneMaintenanceDueState();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appended random all data: $machineCount machines, '
            '$subAssemblyCount sub-assemblies, $employeeCount employees, '
            '$contractorCompanyCount contractors, $contractorContactCount contractor contacts, '
            '$vendorCount vendors.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to append random all data.', error);
    }
  }

  Future<void> _deleteRandomAllData() async {
    final confirmed = await _confirmRandomAction(
      title: 'Delete All Records in Database?',
      message:
          'This deletes all records shown in Add Machine, Work Orders, Maintenance Due, Employees, Contractors, Vendors, Calendar, and Reports while keeping the database file.',
      confirmLabel: 'Delete',
    );
    if (!confirmed) {
      return;
    }

    try {
      await MachineDatabase.instance.replaceAllMachines(const []);
      await MachineDatabase.instance.replaceAllEmployees(const []);
      await MachineDatabase.instance.deleteAllContractors();

      if (!mounted) {
        return;
      }

      setState(() {
        _machines.clear();
        _employees.clear();
        _pruneMaintenanceDueState();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Deleted all records in Add Machine, Work Orders, Maintenance Due, Employees, Contractors, Vendors, Calendar, and Reports.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to delete combined data.', error);
    }
  }

  Future<void> _generateRandomMachinesData() async {
    final rowCount = await _confirmRandomActionWithRowCount(
      title: 'Generate Random Machines?',
      message:
          'This replaces all machines, sub-assemblies, work orders, and history with random machine data.',
      confirmLabel: 'Generate',
      rowLabel: 'Machines to generate',
      initialCount: 15,
      estimateBuilder: (rows) =>
          'Estimated output: $rows machines and ${rows * 10} sub-assemblies.',
    );
    if (rowCount == null) {
      return;
    }

    try {
      Future<(List<Machine> insertedMachines, int expectedMachineCount)>
      generateOnce() async {
        final rng = Random();
        await _prepareRandomSkillAndLicenseCatalogs(rng);
        final machines = _buildSampleMachines(
          rng: rng,
          serialPrefix: 'SIM',
          count: rowCount,
        );
        final expectedMachineCount = machines.length;

        await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.replaceAllMachines(machines),
        );
        final insertedMachines = await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.getMachines(),
        );

        if (insertedMachines.isNotEmpty) {
          await _runDatabaseGenerationStepWithRetry(
            () => MachineDatabase.instance.insertSampleHistory(
              insertedMachines,
              Random(rng.nextInt(1 << 32)),
            ),
          );
        }

        return (insertedMachines, expectedMachineCount);
      }

      late final List<Machine> insertedMachines;
      late final int expectedMachineCount;
      try {
        final result = await generateOnce();
        insertedMachines = result.$1;
        expectedMachineCount = result.$2;
      } catch (_) {
        await MachineDatabase.instance.attemptDatabaseRecovery();
        final result = await generateOnce();
        insertedMachines = result.$1;
        expectedMachineCount = result.$2;
      }

      if (!mounted) {
        return;
      }

      final machineCount = insertedMachines.length;
      final subAssemblyCount = insertedMachines
          .expand((m) => m.subAssemblies)
          .length;

      setState(() {
        _machines
          ..clear()
          ..addAll(insertedMachines);
        _pruneMaintenanceDueState();
        _isLoading = false;
      });

      if (!mounted) {
        return;
      }

      if (machineCount < expectedMachineCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: generated $machineCount of $expectedMachineCount machines.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated random machines: $machineCount machines, $subAssemblyCount sub-assemblies.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to generate random machines.', error);
    }
  }

  Future<void> _generateRandomEmployeesData() async {
    final rowCount = await _confirmRandomActionWithRowCount(
      title: 'Generate Random Employees?',
      message: 'This replaces all employees with random employee data.',
      confirmLabel: 'Generate',
      rowLabel: 'Employees to generate',
      initialCount: 15,
      estimateBuilder: (rows) => 'Estimated output: $rows employees.',
    );
    if (rowCount == null) {
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);
      final employees = _withSyntheticEmployeeCoverage(
        _buildSampleEmployees(rng: rng, count: rowCount),
        Random(rng.nextInt(1 << 32)),
      );
      final expectedEmployeeCount = employees.length;
      await MachineDatabase.instance.replaceAllEmployees(employees);
      final insertedEmployees = await MachineDatabase.instance.getEmployees();

      if (!mounted) {
        return;
      }

      setState(() {
        _employees
          ..clear()
          ..addAll(insertedEmployees);
        _isLoading = false;
      });

      final employeeCount = insertedEmployees.length;
      if (employeeCount < expectedEmployeeCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: generated $employeeCount of $expectedEmployeeCount employees.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generated random employees: $employeeCount.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to generate random employees.', error);
    }
  }

  List<String> _pickRandomSubset(
    List<String> pool,
    Random rng, {
    int minCount = 1,
    int maxCount = 3,
  }) {
    final normalized = pool
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return const [];
    }

    final shuffled = List<String>.from(normalized)..shuffle(rng);
    final boundedMax = maxCount < shuffled.length ? maxCount : shuffled.length;
    final boundedMin = minCount > boundedMax ? boundedMax : minCount;
    final count = boundedMin + rng.nextInt((boundedMax - boundedMin) + 1);
    return shuffled.take(count).toList(growable: false);
  }

  List<String> _buildRandomSkillCatalog(Random rng) {
    const additionalSkills = <String>[
      'Calibration',
      'Rigging',
      'Controls',
      'Hydraulics',
      'Pneumatics',
      'Machining',
      'Commissioning',
      'Inspection',
      'Troubleshooting',
      'Vibration Analysis',
      'Instrumentation',
      'Steam Systems',
      'Pipefitting',
      'Conveyance',
      'Process Safety',
    ];

    final combined = <String>{
      ..._MachineEntryPageState._defaultEmployeeSkills,
      ...additionalSkills,
    }.toList(growable: false)..shuffle(rng);

    final extraCount = 4 + rng.nextInt(5);
    final syntheticCount = 2 + rng.nextInt(3);
    const syntheticPrefixes = <String>[
      'Advanced',
      'Applied',
      'Precision',
      'Industrial',
      'Integrated',
      'Certified',
      'Field',
      'Plant',
      'Process',
    ];
    const syntheticDomains = <String>[
      'Controls',
      'Hydraulics',
      'Diagnostics',
      'Calibration',
      'Instrumentation',
      'Maintenance',
      'Commissioning',
      'Alignment',
      'Reliability',
      'Automation',
    ];
    final syntheticSkills = List<String>.generate(
      syntheticCount,
      (_) =>
          '${syntheticPrefixes[rng.nextInt(syntheticPrefixes.length)]} ${syntheticDomains[rng.nextInt(syntheticDomains.length)]}',
      growable: false,
    );

    return (combined.take(extraCount).toList(growable: true)
          ..addAll(syntheticSkills)
          ..addAll(_MachineEntryPageState._defaultEmployeeSkills))
        .toSet()
        .toList(growable: false);
  }

  List<String> _buildRandomLicenseCatalog(Random rng) {
    const additionalLicenses = <String>[
      'Millwright',
      'Welder',
      'Low Voltage',
      'Controls',
      'Steam',
      'Pipefitter',
      'Gas Fitter',
      'Crane',
      'Forklift Trainer',
      'Confined Space',
      'Lockout Tagout',
      'Pressure Systems',
    ];

    final combined = <String>{
      ..._MachineEntryPageState._baseLicenseTypes,
      ...additionalLicenses,
    }.toList(growable: false)..shuffle(rng);

    final extraCount = 3 + rng.nextInt(4);
    final syntheticCount = 2 + rng.nextInt(3);
    const syntheticScopes = <String>[
      'Industrial',
      'Plant',
      'Field',
      'Process',
      'Systems',
      'Advanced',
      'Heavy Equipment',
      'Controls',
      'Utility',
      'Mechanical',
    ];
    const syntheticTypes = <String>[
      'Technician',
      'Operator',
      'Specialist',
      'Certification',
      'License',
      'Endorsement',
      'Authority',
      'Permit',
    ];
    final syntheticLicenses = List<String>.generate(
      syntheticCount,
      (_) =>
          '${syntheticScopes[rng.nextInt(syntheticScopes.length)]} ${syntheticTypes[rng.nextInt(syntheticTypes.length)]}',
      growable: false,
    );

    return (combined.take(extraCount).toList(growable: true)
          ..addAll(syntheticLicenses)
          ..addAll(_MachineEntryPageState._baseLicenseTypes))
        .toSet()
        .toList(growable: false);
  }

  Future<void> _prepareRandomSkillAndLicenseCatalogs(Random rng) async {
    await MachineDatabase.instance.ensureDefaultSkillTypes(
      _buildRandomSkillCatalog(rng),
    );
    await MachineDatabase.instance.ensureDefaultLicenseTypes(
      _buildRandomLicenseCatalog(rng),
    );

    await _refreshSkillTypes();
    await _refreshLicenseTypes();
  }

  String _buildSyntheticCoverageSkill(Random rng) {
    const prefixes = <String>[
      'Advanced',
      'Applied',
      'Precision',
      'Industrial',
      'Integrated',
      'Field',
      'Plant',
      'Process',
    ];
    const domains = <String>[
      'Controls',
      'Hydraulics',
      'Diagnostics',
      'Calibration',
      'Instrumentation',
      'Reliability',
      'Automation',
    ];
    return '${prefixes[rng.nextInt(prefixes.length)]} ${domains[rng.nextInt(domains.length)]}';
  }

  String _buildSyntheticCoverageLicense(Random rng) {
    const scopes = <String>[
      'Industrial',
      'Plant',
      'Field',
      'Systems',
      'Controls',
      'Utility',
      'Mechanical',
    ];
    const types = <String>[
      'Technician',
      'Operator',
      'Certification',
      'License',
      'Endorsement',
      'Permit',
    ];
    return '${scopes[rng.nextInt(scopes.length)]} ${types[rng.nextInt(types.length)]}';
  }

  List<Employee> _withSyntheticEmployeeCoverage(
    List<Employee> employees,
    Random rng, {
    double minCoverage = 0.4,
  }) {
    if (employees.isEmpty) {
      return employees;
    }

    final indices = List<int>.generate(employees.length, (i) => i)
      ..shuffle(rng);
    final targetCount = (employees.length * minCoverage).ceil();
    final selected = indices.take(targetCount).toSet();

    return employees
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final employee = entry.value;
          if (!selected.contains(index)) {
            return employee;
          }

          final nextSkills = <String>{
            ...employee.skills,
            _buildSyntheticCoverageSkill(rng),
          }.toList(growable: false);
          final nextLicenses = <String>{
            ...employee.licenses,
            _buildSyntheticCoverageLicense(rng),
          }.toList(growable: false);

          return employee.copyWith(skills: nextSkills, licenses: nextLicenses);
        })
        .toList(growable: false);
  }

  List<ContractorCompany> _withSyntheticContractorCoverage(
    List<ContractorCompany> companies,
    Random rng, {
    double minCoverage = 0.5,
  }) {
    if (companies.isEmpty) {
      return companies;
    }

    final indices = List<int>.generate(companies.length, (i) => i)
      ..shuffle(rng);
    final targetCount = (companies.length * minCoverage).ceil();
    final selected = indices.take(targetCount).toSet();

    return companies
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final company = entry.value;
          if (!selected.contains(index)) {
            return company;
          }

          final nextSkills = <String>{
            ...company.matchedSkills,
            _buildSyntheticCoverageSkill(rng),
          }.toList(growable: false);
          final nextLicenses = <String>{
            ...company.matchedLicenses,
            _buildSyntheticCoverageLicense(rng),
          }.toList(growable: false);

          return company.copyWith(
            matchedSkills: nextSkills,
            matchedLicenses: nextLicenses,
          );
        })
        .toList(growable: false);
  }

  String _randomAlphaNumeric(Random rng, {int minLen = 4, int maxLen = 12}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final length = minLen + rng.nextInt((maxLen - minLen) + 1);
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(chars[rng.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  List<ContractorCompany> _buildSampleContractorCompanies({
    required Random rng,
    int count = 15,
  }) {
    const baseNames = [
      'Nordic Field Services',
      'Precision Lift Solutions',
      'Industrial Repair Group',
      'Summit Mechanical Partners',
      'Rapid Response Engineering',
      'Prime Utility Contractors',
      'Metro Plant Support',
      'Arctic Process Services',
      'Blue Line Maintenance',
      'Foundry Technical Services',
      'Harbor Equipment Team',
      'Pioneer Tradeworks',
      'Ironclad Facility Support',
      'Frontier Industrial Assist',
      'Delta Site Services',
    ];

    final skillPool = _availableSkillTypes.isEmpty
        ? List<String>.from(_MachineEntryPageState._defaultEmployeeSkills)
        : List<String>.from(_availableSkillTypes);
    final licensePool = List<String>.from(_licenseTypeOptions);

    return List<ContractorCompany>.generate(count, (index) {
      final baseName = baseNames[index % baseNames.length];
      final number = _randomAlphaNumeric(rng, minLen: 2, maxLen: 5);
      return ContractorCompany(
        companyName:
            '$baseName $number ${_randomAlphaNumeric(rng, minLen: 2, maxLen: 6)}',
        address:
            '${120 + index} ${_randomAlphaNumeric(rng, minLen: 5, maxLen: 10)} Road, Zone ${1 + rng.nextInt(12)}',
        phoneNumber:
            '${100 + rng.nextInt(900)}-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}',
        faxNumber:
            '${100 + rng.nextInt(900)}-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}',
        companyUrl:
            'https://contractor-${_randomAlphaNumeric(rng, minLen: 4, maxLen: 9).toLowerCase()}.example.com',
        matchedSkills: _pickRandomSubset(
          skillPool,
          rng,
          minCount: 1,
          maxCount: 4,
        ),
        matchedLicenses: _pickRandomSubset(
          licensePool,
          rng,
          minCount: 0,
          maxCount: 3,
        ),
      );
    });
  }

  List<ContractorEmployeeContact> _buildSampleContractorContacts(
    int companyId,
    Random rng,
  ) {
    const firstNames = [
      'Noah',
      'Liam',
      'Emma',
      'Maja',
      'Elias',
      'Nora',
      'Lucas',
      'Ella',
      'Anton',
      'Sofia',
      'Milo',
      'Olivia',
    ];
    const lastNames = [
      'Johansson',
      'Lind',
      'Nyberg',
      'Bergman',
      'Ek',
      'Sandin',
      'Ahlgren',
      'Forsman',
      'Westin',
      'Sundberg',
    ];

    final contactCount = 1 + rng.nextInt(4);
    return List<ContractorEmployeeContact>.generate(contactCount, (index) {
      final first = firstNames[rng.nextInt(firstNames.length)];
      final last = lastNames[rng.nextInt(lastNames.length)];
      final email =
          '${first.toLowerCase()}.${last.toLowerCase()}${_randomAlphaNumeric(rng, minLen: 2, maxLen: 5).toLowerCase()}@contractor.example.com';
      return ContractorEmployeeContact(
        contractorCompanyId: companyId,
        fullName:
            '$first $last ${_randomAlphaNumeric(rng, minLen: 1, maxLen: 4)}',
        email: email,
        phoneNumber:
            '${100 + rng.nextInt(900)}-${100 + rng.nextInt(900)}-${1000 + rng.nextInt(9000)}',
      );
    });
  }

  Future<void> _generateRandomContractorsData() async {
    final rowCount = await _confirmRandomActionWithRowCount(
      title: 'Generate Random Contractors?',
      message:
          'This replaces all contractor companies and contractor employee contacts with random data.',
      confirmLabel: 'Generate',
      rowLabel: 'Contractor companies to generate',
      initialCount: 12,
      estimateBuilder: (rows) =>
          'Estimated output: $rows contractor companies and '
          '$rows-${rows * 4} contractor contacts.',
    );
    if (rowCount == null) {
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);
      await MachineDatabase.instance.deleteAllContractors();
      final companies = _withSyntheticContractorCoverage(
        _buildSampleContractorCompanies(rng: rng, count: rowCount),
        Random(rng.nextInt(1 << 32)),
      );

      var insertedCompanies = 0;
      var insertedContacts = 0;
      for (final company in companies) {
        final savedCompany = await MachineDatabase.instance
            .upsertContractorCompany(company);
        final companyId = savedCompany.id;
        if (companyId == null) {
          continue;
        }
        insertedCompanies += 1;
        final contacts = _buildSampleContractorContacts(companyId, rng);
        for (final contact in contacts) {
          await MachineDatabase.instance.upsertContractorEmployee(contact);
          insertedContacts += 1;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated random contractors: $insertedCompanies companies, $insertedContacts contacts.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to generate random contractors.', error);
    }
  }

  Future<void> _appendRandomContractorsWithRowCount(int rowCount) async {
    if (rowCount < 1 || rowCount > 500) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rows must be between 1 and 500.')),
      );
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);
      final companies = _withSyntheticContractorCoverage(
        _buildSampleContractorCompanies(rng: rng, count: rowCount),
        Random(rng.nextInt(1 << 32)),
      );

      var insertedCompanies = 0;
      var insertedContacts = 0;
      for (final company in companies) {
        final withSuffix = company.copyWith(
          companyName:
              '${company.companyName} ${DateTime.now().millisecondsSinceEpoch % 100000}',
        );
        final savedCompany = await MachineDatabase.instance
            .upsertContractorCompany(withSuffix);
        final companyId = savedCompany.id;
        if (companyId == null) {
          continue;
        }
        insertedCompanies += 1;
        final contacts = _buildSampleContractorContacts(companyId, rng);
        for (final contact in contacts) {
          await MachineDatabase.instance.upsertContractorEmployee(contact);
          insertedContacts += 1;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appended random contractors: $insertedCompanies companies, $insertedContacts contacts.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to append random contractors.', error);
    }
  }

  Future<void> _appendRandomMachinesWithRowCount(int rowCount) async {
    if (rowCount < 1 || rowCount > 500) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rows must be between 1 and 500.')),
      );
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);
      final serialPrefix = 'RND${DateTime.now().millisecondsSinceEpoch}';

      final machines = _buildSampleMachines(
        rng: rng,
        serialPrefix: serialPrefix,
        count: rowCount,
      );

      await MachineDatabase.instance.insertMachines(machines);

      final allMachines = await MachineDatabase.instance.getMachines();
      final appendedMachines = allMachines
          .where((m) => m.serialNumber.startsWith(serialPrefix))
          .toList(growable: false);
      if (appendedMachines.isNotEmpty) {
        await MachineDatabase.instance.insertSampleHistory(
          appendedMachines,
          Random(rng.nextInt(1 << 32)),
        );
      }

      if (!mounted) {
        return;
      }

      final machineCount = appendedMachines.length;
      final subAssemblyCount = appendedMachines
          .expand((m) => m.subAssemblies)
          .length;

      setState(() {
        _machines
          ..clear()
          ..addAll(allMachines);
        _pruneMaintenanceDueState();
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Appended random machines: $machineCount machines, $subAssemblyCount sub-assemblies.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to append random machines.', error);
    }
  }

  Future<void> _appendRandomEmployeesWithRowCount(int rowCount) async {
    if (rowCount < 1 || rowCount > 500) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rows must be between 1 and 500.')),
      );
      return;
    }

    try {
      final rng = Random();
      await _prepareRandomSkillAndLicenseCatalogs(rng);

      final existingEmployees = await MachineDatabase.instance.getEmployees();
      final existingEmployeeIds = existingEmployees
          .map((e) => e.id)
          .whereType<int>()
          .toSet();

      final employees = _withSyntheticEmployeeCoverage(
        _buildSampleEmployees(rng: rng, count: rowCount),
        Random(rng.nextInt(1 << 32)),
      );

      await MachineDatabase.instance.insertEmployees(employees);

      final allEmployees = await MachineDatabase.instance.getEmployees();
      final appendedCount = allEmployees
          .where((e) => e.id != null && !existingEmployeeIds.contains(e.id!))
          .length;

      if (!mounted) {
        return;
      }

      setState(() {
        _employees
          ..clear()
          ..addAll(allEmployees);
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appended random employees: $appendedCount employees.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to append random employees.', error);
    }
  }

  Future<void> _generateRandomDatabaseData({
    bool requireConfirmation = true,
  }) async {
    if (!mounted) {
      return;
    }

    var rowCount = 15;
    if (requireConfirmation) {
      final selectedCount = await _confirmRandomActionWithRowCount(
        title: 'Generate Random Data?',
        message:
            'This will replace all current data with randomly generated machines, sub-assemblies, and history. Some machines may have no license requirement.',
        confirmLabel: 'Generate',
        rowLabel: 'Rows per data group',
        initialCount: 15,
        estimateBuilder: (rows) =>
            'Estimated output: $rows machines, ${rows * 10} sub-assemblies, '
            '$rows employees, $rows contractor companies, and '
            '$rows-${rows * 4} contractor contacts.',
      );
      if (selectedCount == null) {
        return;
      }
      rowCount = selectedCount;
    }

    try {
      Future<
        ({
          List<Machine> insertedMachines,
          List<Employee> insertedEmployees,
          int contractorCompanyCount,
          int contractorContactCount,
          int expectedMachineCount,
          int expectedEmployeeCount,
        })
      >
      generateOnce() async {
        final rng = Random();
        await _prepareRandomSkillAndLicenseCatalogs(rng);
        final machines = _buildSampleMachines(
          rng: rng,
          serialPrefix: 'SIM',
          count: rowCount,
        );
        final employees = _withSyntheticEmployeeCoverage(
          _buildSampleEmployees(
            rng: Random(rng.nextInt(1 << 32)),
            count: rowCount,
          ),
          Random(rng.nextInt(1 << 32)),
        );

        await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.replaceAllMachines(machines),
        );
        await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.replaceAllEmployees(employees),
        );
        await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.deleteAllContractors(),
        );

        final insertedMachines = await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.getMachines(),
        );
        final insertedEmployees = await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.getEmployees(),
        );
        await _runDatabaseGenerationStepWithRetry(
          () => MachineDatabase.instance.insertSampleHistory(
            insertedMachines,
            Random(rng.nextInt(1 << 32)),
          ),
        );

        final contractorCompanies = _withSyntheticContractorCoverage(
          _buildSampleContractorCompanies(
            rng: Random(rng.nextInt(1 << 32)),
            count: rowCount,
          ),
          Random(rng.nextInt(1 << 32)),
        );
        var contractorCompanyCount = 0;
        var contractorContactCount = 0;
        for (final company in contractorCompanies) {
          final savedCompany = await _runDatabaseGenerationStepWithRetry(
            () => MachineDatabase.instance.upsertContractorCompany(company),
          );
          final companyId = savedCompany.id;
          if (companyId == null) {
            continue;
          }

          contractorCompanyCount += 1;
          final contacts = _buildSampleContractorContacts(companyId, rng);
          for (final contact in contacts) {
            await _runDatabaseGenerationStepWithRetry(
              () => MachineDatabase.instance.upsertContractorEmployee(contact),
            );
            contractorContactCount += 1;
          }
        }

        return (
          insertedMachines: insertedMachines,
          insertedEmployees: insertedEmployees,
          contractorCompanyCount: contractorCompanyCount,
          contractorContactCount: contractorContactCount,
          expectedMachineCount: machines.length,
          expectedEmployeeCount: employees.length,
        );
      }

      ({
        List<Machine> insertedMachines,
        List<Employee> insertedEmployees,
        int contractorCompanyCount,
        int contractorContactCount,
        int expectedMachineCount,
        int expectedEmployeeCount,
      })
      generationResult;

      try {
        generationResult = await generateOnce();
      } catch (_) {
        await MachineDatabase.instance.attemptDatabaseRecovery();
        generationResult = await generateOnce();
      }

      final insertedMachines = generationResult.insertedMachines;
      final insertedEmployees = generationResult.insertedEmployees;
      final contractorCompanyCount = generationResult.contractorCompanyCount;
      final contractorContactCount = generationResult.contractorContactCount;
      final expectedMachineCount = generationResult.expectedMachineCount;
      final expectedEmployeeCount = generationResult.expectedEmployeeCount;

      if (!mounted) {
        return;
      }

      final machineCount = insertedMachines.length;
      final employeeCount = insertedEmployees.length;
      final subAssemblyCount = insertedMachines
          .expand((m) => m.subAssemblies)
          .length;

      setState(() {
        _machines
          ..clear()
          ..addAll(insertedMachines);
        _employees
          ..clear()
          ..addAll(insertedEmployees);
        _pruneMaintenanceDueState();
        _isLoading = false;
      });

      if (!mounted) {
        return;
      }

      if (machineCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Warning: random data generation completed, but 0 machines were inserted.',
            ),
          ),
        );
        return;
      }

      if (machineCount < expectedMachineCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: generated $machineCount of $expectedMachineCount machines. Some rows may have been rejected by database constraints.',
            ),
          ),
        );
        return;
      }

      if (employeeCount < expectedEmployeeCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Warning: generated $employeeCount of $expectedEmployeeCount employees.',
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Generated random data: $machineCount machines, '
            '$subAssemblyCount sub-assemblies, $employeeCount employees, '
            '$contractorCompanyCount contractors, $contractorContactCount contractor contacts.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _startupLoadError = _databaseLoadFailureMessage(error);
      });
      _showErrorSnackBar('Failed to generate random data.', error);
      if (!requireConfirmation) {
        rethrow;
      }
    }
  }

  Future<void> _exportDatabaseBackup() async {
    try {
      final backupJson = await MachineDatabase.instance.exportDatabaseJson();
      await Clipboard.setData(ClipboardData(text: backupJson));

      if (!mounted) {
        return;
      }
      final now = DateTime.now();
      final yyyy = now.year.toString().padLeft(4, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final hh = now.hour.toString().padLeft(2, '0');
      final min = now.minute.toString().padLeft(2, '0');
      final ss = now.second.toString().padLeft(2, '0');
      final fileName = 'machine_registry_backup_$yyyy$mm${dd}_$hh$min$ss.json';

      await _presentBackupForReview(fileName, backupJson);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to export database.', error);
    }
  }

  Future<void> _importDatabaseBackup() async {
    final inputController = TextEditingController();
    try {
      final backupJson = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.all(24.0),
            title: const Text('Import Database Backup'),
            content: SizedBox(
              width: 400.0,
              child: TextField(
                controller: inputController,
                minLines: 8,
                maxLines: 18,
                decoration: const InputDecoration(
                  hintText: 'Paste exported backup JSON here',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(inputController.text.trim());
                },
                child: const Text('Import'),
              ),
            ]),
          );
        },
      );

      if (backupJson == null || backupJson.isEmpty) {
        return;
      }

      if (!mounted) {
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.all(24.0),
            title: const Text('Replace Existing Data?'),
            content: const Text(
              'Import will replace all current machines, sub-assemblies, and tasks.',
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Replace'),
              ),
            ]),
          );
        },
      );

      if (confirm != true) {
        return;
      }

      final importedCount = await MachineDatabase.instance.importDatabaseJson(
        backupJson,
        clearExisting: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = true;
      });
      await _loadMachines(seedSampleData: false);

      if (!mounted) {
        return;
      }

      final importedNoMachines = importedCount == 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $importedCount machine(s).')),
      );
      if (importedNoMachines) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No machines imported. Use Database Actions to build or import data.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to import database backup.', error);
    } finally {
      inputController.dispose();
    }
  }

  Future<void> _deleteDatabase() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          insetPadding: const EdgeInsets.all(24.0),
          title: const Text('Delete Entire Database'),
          content: const Text(
            'This will permanently delete all machines, sub-assemblies, and tasks. Continue?',
          ),
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
      return;
    }

    try {
      await MachineDatabase.instance.deleteEntireDatabaseFile();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = true;
        _machines.clear();
        _employees.clear();
        _selectedTaskType = null;
        _selectedTaskTimeCategory = null;
        _selectedSubCategory = null;
        _taskSearchQuery = '';
        _taskSearchController.clear();
        _hasAttemptedDatabaseRecovery = false;
      });

      await _loadMachines(seedSampleData: false);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database deleted successfully.')),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use Database Actions to build or import database data.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to delete database.', error);
    }
  }

  Future<void> _backupAndResetLocalDatabaseFromHelp() async {
    if (_isLoading) {
      return;
    }

    try {
      final backupJson = await MachineDatabase.instance.exportDatabaseJson();
      await Clipboard.setData(ClipboardData(text: backupJson));

      final now = DateTime.now();
      final yyyy = now.year.toString().padLeft(4, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final hh = now.hour.toString().padLeft(2, '0');
      final min = now.minute.toString().padLeft(2, '0');
      final ss = now.second.toString().padLeft(2, '0');
      final fileName = 'machine_registry_backup_$yyyy$mm${dd}_$hh$min$ss.json';

      await _presentBackupForReview(fileName, backupJson);
      if (!mounted) {
        return;
      }

      final confirmReset = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.all(24.0),
            title: const Text('Reset Local Database?'),
            content: const Text(
              'Backup is copied to clipboard. Continue to delete and recreate the local database now?',
            ),
            actions: _dialogActionsForContext(dialogContext, [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Reset Database'),
              ),
            ]),
          );
        },
      );

      if (confirmReset != true) {
        return;
      }

      await _deleteDatabase();
      if (!mounted) {
        return;
      }

      setState(() {
        _helpDiagnosticsFuture = _buildHelpDiagnostics();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to backup and reset local database.', error);
    }
  }

  Future<void> _printEmployeesPdf() async {
    try {
      final employees = await MachineDatabase.instance.getEmployees();
      final now = DateTime.now();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final yyyy = now.year.toString().padLeft(4, '0');
      final fileName = 'employees$mm$dd$yyyy.pdf';

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          footer: (context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '$fileName | ${_formatDate(now)} | Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          },
          build: (context) {
            if (employees.isEmpty) {
              return [
                pw.Text(
                  'Employees',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('No employee records available.'),
              ];
            }

            return [
              pw.Text(
                'Employees',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Generated: ${_formatDate(now)}'),
              pw.SizedBox(height: 10),
              ...employees.map((employee) {
                final skills = employee.skills.isEmpty
                    ? 'None'
                    : employee.skills.join(', ');
                final licenses = employee.licenses.isEmpty
                    ? 'None'
                    : employee.licenses.join(', ');
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        employee.name,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Skills: $skills'),
                      pw.Text('Licenses: $licenses'),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      final pdfBytes = await document.save();
      await _presentPdfForPrinting(
        fileName,
        pdfBytes,
        successMessage:
            'Opened $fileName in your default PDF viewer. Use the viewer print command to print it.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to open employees PDF.', error);
    }
  }

  Future<void> _printContractorsPdf() async {
    try {
      final contractors = await MachineDatabase.instance
          .getContractorCompanies();
      final now = DateTime.now();
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');
      final yyyy = now.year.toString().padLeft(4, '0');
      final fileName = 'contractors$mm$dd$yyyy.pdf';

      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          footer: (context) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 8),
              child: pw.Text(
                '$fileName | ${_formatDate(now)} | Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            );
          },
          build: (context) {
            if (contractors.isEmpty) {
              return [
                pw.Text(
                  'Contractors',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text('No contractor records available.'),
              ];
            }

            return [
              pw.Text(
                'Contractors',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Generated: ${_formatDate(now)}'),
              pw.SizedBox(height: 10),
              ...contractors.map((company) {
                final skills = company.matchedSkills.isEmpty
                    ? 'None'
                    : company.matchedSkills.join(', ');
                final licenses = company.matchedLicenses.isEmpty
                    ? 'None'
                    : company.matchedLicenses.join(', ');
                final contactBits = <String>[];
                if (company.phoneNumber.trim().isNotEmpty) {
                  contactBits.add('Phone: ${company.phoneNumber.trim()}');
                }
                if (company.companyUrl.trim().isNotEmpty) {
                  contactBits.add('URL: ${company.companyUrl.trim()}');
                }

                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        company.companyName,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      if (company.address.trim().isNotEmpty)
                        pw.Text('Address: ${company.address.trim()}'),
                      if (contactBits.isNotEmpty)
                        pw.Text(contactBits.join(' | ')),
                      pw.Text('Matched Skills: $skills'),
                      pw.Text('Matched Licenses: $licenses'),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      final pdfBytes = await document.save();
      await _presentPdfForPrinting(
        fileName,
        pdfBytes,
        successMessage:
            'Opened $fileName in your default PDF viewer. Use the viewer print command to print it.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorSnackBar('Failed to open contractors PDF.', error);
    }
  }
}
