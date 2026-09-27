// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageWorkOrdersExtension on _MachineEntryPageState {
  static const String _unassignedSelectionValue =
      '__UNASSIGNED__|Contractor Needed';
  static const String _contractorSelectionPrefix = '__CONTRACTOR__|';
  static const List<String> _taskOutcomeOptions = <String>[
    'Not set',
    'Completed',
    'Bypassed',
    'Deferred',
    'Needs Follow-up',
    'Cancelled',
  ];

  /// Collects unique, non-empty required parts across all tasks in a
  /// subassembly. Part identity is the normalized combination of its vendor,
  /// part numbers, contact details, and lead time.
  List<RequiredPart> _requiredPartsForWorkOrder(SubAssembly subAssembly) {
    final unique = <String, RequiredPart>{};
    for (final task in subAssembly.maintenanceTasks) {
      for (final part in task.requiredParts) {
        if (part.isEmpty) {
          continue;
        }
        final key = [
          part.oemPn.trim().toUpperCase(),
          part.vendorPn.trim().toUpperCase(),
          part.vendorName.trim().toUpperCase(),
          part.vendorUrl.trim().toLowerCase(),
          part.vendorPhoneNumber.trim(),
          part.estimatedLeadTime.trim(),
        ].join('|');
        unique.putIfAbsent(key, () => part);
      }
    }
    return unique.values.toList(growable: false);
  }

  /// Creates a stable assignment key even when a task has not been persisted.
  /// The index disambiguates multiple unsaved tasks, whose IDs are all `-1`.
  String _workOrderTaskAssignmentKey(
    int subAssemblyId,
    MaintenanceTask task,
    int taskIndex,
  ) {
    final taskId = task.id ?? -1;
    return '$subAssemblyId:$taskId:$taskIndex';
  }

  String _employeeSelectionValue(Employee employee) {
    final idPart = employee.id?.toString() ?? 'no-id';
    return '$idPart|${employee.name}';
  }

  String _employeeNameFromSelectionValue(String selectionValue) {
    if (selectionValue == _unassignedSelectionValue) {
      return 'Contractor Needed';
    }
    if (selectionValue.startsWith(_contractorSelectionPrefix)) {
      final remainder = selectionValue.substring(
        _contractorSelectionPrefix.length,
      );
      final separator = remainder.indexOf('|');
      if (separator < 0 || separator + 1 >= remainder.length) {
        return remainder.trim();
      }
      return remainder.substring(separator + 1).trim();
    }

    final separator = selectionValue.indexOf('|');
    if (separator < 0 || separator + 1 >= selectionValue.length) {
      return selectionValue.trim();
    }
    return selectionValue.substring(separator + 1).trim();
  }

  String _assigneeDisplayLabel(String selectionValue) {
    final name = _employeeNameFromSelectionValue(selectionValue);
    if (selectionValue.startsWith(_contractorSelectionPrefix)) {
      return 'Contractor: $name';
    }
    return name;
  }

  String _contractorSelectionValue(ContractorCompany company) {
    final idPart = company.id?.toString() ?? 'no-id';
    return '$_contractorSelectionPrefix$idPart|${company.companyName}';
  }

  /// Produces a stable seed from task identity so generated skill suggestions
  /// remain unchanged across rebuilds.
  int _workOrderSkillSeed(SubAssembly subAssembly, MaintenanceTask task) {
    final base =
        '${subAssembly.serialNumber}|${subAssembly.name}|${task.taskType}|${task.timeCategory}|${task.timeValue}';
    var hash = 0;
    for (final codeUnit in base.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  /// Selects one to three deterministic skill suggestions from the configured
  /// skill catalog. These are derived suggestions, not persisted assignments.
  List<String> _requiredSkillsForTask(
    SubAssembly subAssembly,
    MaintenanceTask task,
  ) {
    final skillPool =
        (_skillTypeOptions.isEmpty
                ? _MachineEntryPageState._defaultEmployeeSkills
                : _skillTypeOptions)
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList(growable: false);
    if (skillPool.isEmpty) {
      return const <String>[];
    }

    final rng = Random(_workOrderSkillSeed(subAssembly, task));
    final shuffled = List<String>.from(skillPool)..shuffle(rng);
    final maxCount = shuffled.length < 3 ? shuffled.length : 3;
    final count = 1 + rng.nextInt(maxCount);
    return shuffled.take(count).toList(growable: false);
  }

  List<String> _requiredSkillsForWorkOrder(SubAssembly subAssembly) {
    final merged = <String>{};
    for (final task in subAssembly.maintenanceTasks) {
      merged.addAll(_requiredSkillsForTask(subAssembly, task));
    }
    return merged.toList(growable: false);
  }

  bool _contractorSkillsMatchTask(
    ContractorCompany company,
    SubAssembly subAssembly,
    MaintenanceTask task,
  ) {
    final companySkills = company.matchedSkills
        .map((skill) => skill.trim().toUpperCase())
        .where((skill) => skill.isNotEmpty)
        .toList(growable: false);
    if (companySkills.isEmpty) {
      return false;
    }

    final requiredSkills = _requiredSkillsForTask(subAssembly, task)
        .map((skill) => skill.trim().toUpperCase())
        .where((skill) => skill.isNotEmpty)
        .toSet();
    if (requiredSkills.isEmpty) {
      return false;
    }

    return requiredSkills.every(companySkills.contains);
  }

  bool _contractorHasRequiredLicenses(
    ContractorCompany company,
    Machine machine,
  ) {
    final requiredLicenses = _machineLicenseTradeLabels(machine)
        .map((license) => license.trim().toUpperCase())
        .where((license) => license.isNotEmpty)
        .toSet();
    if (requiredLicenses.isEmpty) {
      return true;
    }

    final contractorLicenses = company.matchedLicenses
        .map((license) => license.trim().toUpperCase())
        .where((license) => license.isNotEmpty)
        .toSet();
    return requiredLicenses.every(contractorLicenses.contains);
  }

  List<ContractorCompany> _eligibleContractorsForTask({
    required Machine machine,
    required SubAssembly subAssembly,
    required MaintenanceTask task,
    required List<ContractorCompany> contractorCompanies,
  }) {
    final eligible = contractorCompanies
        .where(
          (company) =>
              _contractorHasRequiredLicenses(company, machine) &&
              _contractorSkillsMatchTask(company, subAssembly, task),
        )
        .toList(growable: false);

    eligible.sort(
      (a, b) =>
          a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase()),
    );
    return eligible;
  }

  String _taskLabel(MaintenanceTask task) {
    return '${task.taskType} (${task.timeCategory} ${task.timeValue})';
  }

  String _superCategoryForSubAssembly(SubAssembly subAssembly) {
    final superCategory = subAssembly.superCategory.trim();
    if (superCategory.isNotEmpty) {
      return superCategory;
    }
    return 'Not set';
  }

  bool _employeeIsQualifiedForMachineLicenses(
    Employee employee,
    Machine machine,
  ) {
    final requiredLicenses = _machineLicenseTradeLabels(machine)
        .map((license) => license.trim().toUpperCase())
        .where((license) => license.isNotEmpty)
        .toSet();

    if (requiredLicenses.isEmpty) {
      return true;
    }

    final employeeLicenses = employee.licenses
        .map((license) => license.trim().toUpperCase())
        .where((license) => license.isNotEmpty)
        .toSet();

    return requiredLicenses.every(employeeLicenses.contains);
  }

  bool _employeeHasRequiredSkillsForTask(
    Employee employee,
    SubAssembly subAssembly,
    MaintenanceTask task,
  ) {
    final requiredSkills = _requiredSkillsForTask(subAssembly, task)
        .map((skill) => skill.trim().toUpperCase())
        .where((skill) => skill.isNotEmpty)
        .toSet();
    if (requiredSkills.isEmpty) {
      return true;
    }

    final employeeSkills = employee.skills
        .map((skill) => skill.trim().toUpperCase())
        .where((skill) => skill.isNotEmpty)
        .toSet();
    return requiredSkills.every(employeeSkills.contains);
  }

  List<Employee> _qualifiedEmployeesForTask({
    required Machine machine,
    required SubAssembly subAssembly,
    required MaintenanceTask task,
  }) {
    final filtered = _employees
        .where((employee) {
          return _employeeIsQualifiedForMachineLicenses(employee, machine) &&
              _employeeHasRequiredSkillsForTask(employee, subAssembly, task);
        })
        .toList(growable: false);
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  String _resolvedAssigneeNameForTask({
    required int subAssemblyId,
    required Machine machine,
    required SubAssembly subAssembly,
    required MaintenanceTask task,
    required int taskIndex,
    required Map<int, String> persistedAssignments,
    List<ContractorCompany> contractorCompanies = const <ContractorCompany>[],
    bool updateDraft = true,
  }) {
    final qualified = _qualifiedEmployeesForTask(
      machine: machine,
      subAssembly: subAssembly,
      task: task,
    );
    if (qualified.isEmpty) {
      final eligibleContractors = _eligibleContractorsForTask(
        machine: machine,
        subAssembly: subAssembly,
        task: task,
        contractorCompanies: contractorCompanies,
      );
      if (eligibleContractors.isEmpty) {
        return 'Contractor Needed';
      }
      if (eligibleContractors.length == 1) {
        return eligibleContractors.first.companyName;
      }

      final assignmentKey = _workOrderTaskAssignmentKey(
        subAssemblyId,
        task,
        taskIndex,
      );
      final candidateValues = eligibleContractors
          .map(_contractorSelectionValue)
          .toSet();
      final taskId = task.id;
      final draftValue = _workOrderTaskAssigneeDrafts[assignmentKey];
      final persistedValue = taskId == null
          ? null
          : persistedAssignments[taskId];

      String selectedValue;
      if (draftValue != null && candidateValues.contains(draftValue)) {
        selectedValue = draftValue;
      } else if (persistedValue != null &&
          candidateValues.contains(persistedValue)) {
        selectedValue = persistedValue;
      } else {
        selectedValue = _contractorSelectionValue(eligibleContractors.first);
      }

      if (updateDraft) {
        _workOrderTaskAssigneeDrafts[assignmentKey] = selectedValue;
      }
      return _employeeNameFromSelectionValue(selectedValue);
    }

    if (qualified.length == 1) {
      return qualified.first.name;
    }

    final assignmentKey = _workOrderTaskAssignmentKey(
      subAssemblyId,
      task,
      taskIndex,
    );
    final eligibleContractors = _eligibleContractorsForTask(
      machine: machine,
      subAssembly: subAssembly,
      task: task,
      contractorCompanies: contractorCompanies,
    );
    final candidateValues = <String>{
      _unassignedSelectionValue,
      ...qualified.map(_employeeSelectionValue),
      ...eligibleContractors.map(_contractorSelectionValue),
    };
    final taskId = task.id;
    final draftValue = _workOrderTaskAssigneeDrafts[assignmentKey];
    final persistedValue = taskId == null ? null : persistedAssignments[taskId];

    String selectedValue;
    if (draftValue != null && candidateValues.contains(draftValue)) {
      selectedValue = draftValue;
    } else if (persistedValue != null &&
        candidateValues.contains(persistedValue)) {
      selectedValue = persistedValue;
    } else if (persistedValue != null &&
        persistedValue == _unassignedSelectionValue) {
      selectedValue = persistedValue;
    } else {
      selectedValue = _employeeSelectionValue(qualified.first);
    }

    if (updateDraft) {
      _workOrderTaskAssigneeDrafts[assignmentKey] = selectedValue;
    }

    return _employeeNameFromSelectionValue(selectedValue);
  }

  Widget _buildTaskAssignmentAndOutcomeSection({
    required int subAssemblyId,
    required Machine machine,
    required SubAssembly subAssembly,
    required Map<int, String> persistedAssignments,
    required Map<int, WorkOrderTaskOutcomeEntry> persistedOutcomes,
    required List<ContractorCompany> contractorCompanies,
  }) {
    final isWideTaskLayout = MediaQuery.sizeOf(context).width >= 980;
    final tasks = List<MaintenanceTask>.from(subAssembly.maintenanceTasks)
      ..sort((a, b) {
        final taskCmp = a.taskType.toLowerCase().compareTo(
          b.taskType.toLowerCase(),
        );
        if (taskCmp != 0) {
          return taskCmp;
        }
        return a.timeCategory.toLowerCase().compareTo(
          b.timeCategory.toLowerCase(),
        );
      });

    if (tasks.isEmpty) {
      return const Text('No maintenance tasks available.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Task Assignment and Outcomes',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...List<Widget>.generate(tasks.length, (taskIndex) {
          final task = tasks[taskIndex];
          final assignmentKey = _workOrderTaskAssignmentKey(
            subAssemblyId,
            task,
            taskIndex,
          );
          final qualified = _qualifiedEmployeesForTask(
            machine: machine,
            subAssembly: subAssembly,
            task: task,
          );
          final taskLabel = _taskLabel(task);
          final taskId = task.id;
          final persistedOutcome = taskId == null
              ? null
              : persistedOutcomes[taskId];
          final selectedOutcome =
              _workOrderTaskOutcomeDrafts[assignmentKey] ??
              persistedOutcome?.outcome ??
              _taskOutcomeOptions.first;
          final selectedNotes =
              _workOrderTaskOutcomeNotesDrafts[assignmentKey] ??
              persistedOutcome?.notes ??
              '';

          Widget assignmentControls;

          if (qualified.isEmpty) {
            final eligibleContractors = _eligibleContractorsForTask(
              machine: machine,
              subAssembly: subAssembly,
              task: task,
              contractorCompanies: contractorCompanies,
            );

            if (eligibleContractors.isEmpty) {
              _workOrderTaskAssigneeDrafts.remove(assignmentKey);
              assignmentControls = Text(
                'Contractor Needed',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              );
            } else if (eligibleContractors.length == 1) {
              final only = eligibleContractors.first;
              final selectedValue = _contractorSelectionValue(only);
              _workOrderTaskAssigneeDrafts[assignmentKey] = selectedValue;
              assignmentControls = TextFormField(
                initialValue: only.companyName,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned Contractor',
                  border: OutlineInputBorder(),
                ),
              );
            } else {
              final candidateValues = eligibleContractors
                  .map(_contractorSelectionValue)
                  .toSet();
              var selectedValue = _workOrderTaskAssigneeDrafts[assignmentKey];
              final persistedValue = taskId == null
                  ? null
                  : persistedAssignments[taskId];
              if (selectedValue == null ||
                  !candidateValues.contains(selectedValue)) {
                if (persistedValue != null &&
                    candidateValues.contains(persistedValue)) {
                  selectedValue = persistedValue;
                } else {
                  selectedValue = _contractorSelectionValue(
                    eligibleContractors.first,
                  );
                }
                _workOrderTaskAssigneeDrafts[assignmentKey] = selectedValue;
              }

              final dropdownItems = eligibleContractors
                  .map(
                    (company) => DropdownMenuItem<String>(
                      value: _contractorSelectionValue(company),
                      child: Text('Contractor: ${company.companyName}'),
                    ),
                  )
                  .toList(growable: false);

              assignmentControls = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedValue,
                    decoration: const InputDecoration(
                      labelText: 'Assignee',
                      border: OutlineInputBorder(),
                    ),
                    items: dropdownItems,
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _workOrderTaskAssigneeDrafts[assignmentKey] = value;
                      });
                      if (taskId == null) {
                        return;
                      }
                      try {
                        await MachineDatabase.instance
                            .upsertWorkOrderTaskAssignment(
                              subAssemblyId: subAssemblyId,
                              taskId: taskId,
                              assigneeValue: value,
                            );
                        _workOrderTaskAssignmentFutures.remove(subAssemblyId);
                      } catch (error) {
                        if (!mounted) {
                          return;
                        }
                        _showErrorSnackBar(
                          'Failed to save contractor selection.',
                          error,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selected: ${_assigneeDisplayLabel(selectedValue)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            }
          } else if (qualified.length == 1) {
            final only = qualified.first;
            _workOrderTaskAssigneeDrafts[assignmentKey] =
                _employeeSelectionValue(only);
            assignmentControls = Text('Assigned: ${only.name}');
          } else {
            final candidateValues = <String>{
              _unassignedSelectionValue,
              ...qualified.map(_employeeSelectionValue),
              ..._eligibleContractorsForTask(
                machine: machine,
                subAssembly: subAssembly,
                task: task,
                contractorCompanies: contractorCompanies,
              ).map(_contractorSelectionValue),
            };
            var selectedValue = _workOrderTaskAssigneeDrafts[assignmentKey];
            final persistedValue = taskId == null
                ? null
                : persistedAssignments[taskId];
            final hasSavedAssignment =
                persistedValue != null &&
                candidateValues.contains(persistedValue);
            if (selectedValue == null ||
                !candidateValues.contains(selectedValue)) {
              if (persistedValue != null &&
                  candidateValues.contains(persistedValue)) {
                selectedValue = persistedValue;
              } else {
                selectedValue = _employeeSelectionValue(qualified.first);
              }
              _workOrderTaskAssigneeDrafts[assignmentKey] = selectedValue;
            }

            final dropdownItems = <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: _unassignedSelectionValue,
                child: Text('Unassigned (Contractor Needed)'),
              ),
              ...qualified.map(
                (employee) => DropdownMenuItem<String>(
                  value: _employeeSelectionValue(employee),
                  child: Text(employee.name),
                ),
              ),
              ...(() {
                final eligibleContractors = _eligibleContractorsForTask(
                  machine: machine,
                  subAssembly: subAssembly,
                  task: task,
                  contractorCompanies: contractorCompanies,
                );
                if (eligibleContractors.isEmpty) {
                  return const <DropdownMenuItem<String>>[];
                }

                return <DropdownMenuItem<String>>[
                  const DropdownMenuItem<String>(
                    enabled: false,
                    value: '__CONTRACTOR_HEADER__',
                    child: Text('Eligible Contractors'),
                  ),
                  ...eligibleContractors.map(
                    (company) => DropdownMenuItem<String>(
                      value: _contractorSelectionValue(company),
                      child: Text('Contractor: ${company.companyName}'),
                    ),
                  ),
                ];
              })(),
            ];

            assignmentControls = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Chip(
                  avatar: Icon(
                    hasSavedAssignment
                        ? Icons.save_outlined
                        : Icons.auto_fix_high_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hasSavedAssignment
                        ? 'Saved selection'
                        : 'Default selection',
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: selectedValue,
                  decoration: const InputDecoration(
                    labelText: 'Assignee',
                    border: OutlineInputBorder(),
                  ),
                  items: dropdownItems,
                  onChanged: (value) async {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _workOrderTaskAssigneeDrafts[assignmentKey] = value;
                    });
                    if (taskId == null) {
                      return;
                    }
                    try {
                      await MachineDatabase.instance
                          .upsertWorkOrderTaskAssignment(
                            subAssemblyId: subAssemblyId,
                            taskId: taskId,
                            assigneeValue: value,
                          );
                      _workOrderTaskAssignmentFutures.remove(subAssemblyId);
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      _showErrorSnackBar(
                        'Failed to save task assignee selection.',
                        error,
                      );
                    }
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Selected: ${_assigneeDisplayLabel(selectedValue)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            );
          }

          Future<void> persistTaskOutcomeDraft() async {
            if (taskId == null) {
              return;
            }

            final outcome =
                _workOrderTaskOutcomeDrafts[assignmentKey] ??
                persistedOutcome?.outcome ??
                _taskOutcomeOptions.first;
            final notes =
                _workOrderTaskOutcomeNotesDrafts[assignmentKey] ??
                persistedOutcome?.notes ??
                '';

            try {
              await MachineDatabase.instance.upsertWorkOrderTaskOutcome(
                subAssemblyId: subAssemblyId,
                taskId: taskId,
                outcome: outcome,
                notes: notes,
              );
              _workOrderTaskOutcomeFutures.remove(subAssemblyId);
            } catch (error) {
              if (!mounted) {
                return;
              }
              _showErrorSnackBar('Failed to save task outcome.', error);
            }
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${taskIndex + 1}. $taskLabel',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  if (task.requiredParts.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Required Parts',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    ...List<Widget>.generate(
                      task.requiredParts.where((p) => !p.isEmpty).length,
                      (pi) {
                        final nonEmpty = task.requiredParts
                            .where((p) => !p.isEmpty)
                            .toList(growable: false);
                        final part = nonEmpty[pi];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pi + 1}. ',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Expanded(
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 2,
                                  children: [
                                    if (part.oemPn.trim().isNotEmpty)
                                      Text(
                                        'OEM: ${part.oemPn.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (part.vendorPn.trim().isNotEmpty)
                                      Text(
                                        'Vendor PN: ${part.vendorPn.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (part.vendorName.trim().isNotEmpty)
                                      Text(
                                        'Vendor: ${part.vendorName.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (part.vendorUrl.trim().isNotEmpty)
                                      Text(
                                        'URL: ${part.vendorUrl.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (part.vendorPhoneNumber
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        'Phone: ${part.vendorPhoneNumber.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    if (part.estimatedLeadTime
                                        .trim()
                                        .isNotEmpty)
                                      Text(
                                        'Lead Time: ${part.estimatedLeadTime.trim()}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (taskId == null)
                    assignmentControls
                  else ...[
                    if (isWideTaskLayout)
                      assignmentControls
                    else ...[
                      assignmentControls,
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _taskOutcomeOptions.contains(selectedOutcome)
                            ? selectedOutcome
                            : _taskOutcomeOptions.first,
                        decoration: const InputDecoration(
                          labelText: 'Outcome',
                          border: OutlineInputBorder(),
                        ),
                        items: _taskOutcomeOptions
                            .map(
                              (option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _workOrderTaskOutcomeDrafts[assignmentKey] = value;
                          });
                          persistTaskOutcomeDraft();
                        },
                      ),
                    ],
                    const SizedBox(height: 6),
                    if (isWideTaskLayout)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  _taskOutcomeOptions.contains(selectedOutcome)
                                  ? selectedOutcome
                                  : _taskOutcomeOptions.first,
                              decoration: const InputDecoration(
                                labelText: 'Outcome',
                                border: OutlineInputBorder(),
                              ),
                              items: _taskOutcomeOptions
                                  .map(
                                    (option) => DropdownMenuItem<String>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _workOrderTaskOutcomeDrafts[assignmentKey] =
                                      value;
                                });
                                persistTaskOutcomeDraft();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                'task-outcome-notes-$assignmentKey-${persistedOutcome?.notes ?? ''}',
                              ),
                              initialValue: selectedNotes,
                              minLines: 2,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Documentation Notes',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                _workOrderTaskOutcomeNotesDrafts[assignmentKey] =
                                    value;
                                persistTaskOutcomeDraft();
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      TextFormField(
                        key: ValueKey(
                          'task-outcome-notes-$assignmentKey-${persistedOutcome?.notes ?? ''}',
                        ),
                        initialValue: selectedNotes,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Documentation Notes',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          _workOrderTaskOutcomeNotesDrafts[assignmentKey] =
                              value;
                          persistTaskOutcomeDraft();
                        },
                      ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<Map<int, String>> _workOrderTaskAssignmentFutureForSubAssembly(
    int subAssemblyId,
  ) {
    return _workOrderTaskAssignmentFutures.putIfAbsent(
      subAssemblyId,
      () => MachineDatabase.instance.getWorkOrderTaskAssignments(subAssemblyId),
    );
  }

  Future<Map<int, WorkOrderTaskOutcomeEntry>>
  _workOrderTaskOutcomeFutureForSubAssembly(int subAssemblyId) {
    return _workOrderTaskOutcomeFutures.putIfAbsent(
      subAssemblyId,
      () => MachineDatabase.instance.getWorkOrderTaskOutcomes(subAssemblyId),
    );
  }

  Future<List<ContractorCompany>> _workOrderContractorsFutureForSubAssembly(
    int subAssemblyId,
  ) {
    return _workOrderContractorFutures.putIfAbsent(
      subAssemblyId,
      () => MachineDatabase.instance.getContractorCompanies(),
    );
  }

  List<_WorkOrderItem> _buildWorkOrderItemsForNextFiveDays() {
    return _buildWorkOrderItemsForNextDays(5);
  }

  List<_WorkOrderItem> _buildWorkOrderItemsForNextDays(int daysAhead) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final windowEnd = todayStart.add(
      Duration(days: daysAhead, hours: 23, minutes: 59, seconds: 59),
    );

    final items = <_WorkOrderItem>[];
    for (final machine in _machines) {
      for (final subAssembly in machine.subAssemblies) {
        final projected = _projectedNextDateForSubAssembly(
          machine,
          subAssembly,
        );
        if (projected == null) {
          continue;
        }
        if (projected.isBefore(todayStart) || projected.isAfter(windowEnd)) {
          continue;
        }

        final dueDate = DateTime(
          projected.year,
          projected.month,
          projected.day,
        );
        final daysUntilDue = dueDate.difference(todayStart).inDays;

        items.add(
          _WorkOrderItem(
            machine: machine,
            subAssembly: subAssembly,
            projectedNextDate: projected,
            daysUntilDue: daysUntilDue,
          ),
        );
      }
    }

    items.sort((a, b) {
      final dateCmp = a.projectedNextDate.compareTo(b.projectedNextDate);
      if (dateCmp != 0) {
        return dateCmp;
      }
      final machineCmp = a.machine.name.compareTo(b.machine.name);
      if (machineCmp != 0) {
        return machineCmp;
      }
      return a.subAssembly.name.compareTo(b.subAssembly.name);
    });

    return items;
  }

  Future<void> _printWorkOrdersPdf() async {
    final weeklyItems = _buildWorkOrderItemsForNextDays(7);
    final dueToday = weeklyItems
        .where((item) => item.daysUntilDue == 0)
        .toList(growable: false);
    final dueThisWeek = weeklyItems
        .where((item) => item.daysUntilDue >= 1 && item.daysUntilDue <= 7)
        .toList(growable: false);
    final now = DateTime.now();
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final yyyy = now.year.toString().padLeft(4, '0');
    final fileName = 'workorder$mm$dd$yyyy.pdf';
    final statusEntries = await Future.wait(
      weeklyItems.map((item) async {
        final subAssemblyId = item.subAssembly.id;
        if (subAssemblyId == null) {
          return null;
        }
        return MachineDatabase.instance.getWorkOrderStatus(subAssemblyId);
      }),
    );
    final workOrderStatusesBySubAssemblyId = <int, WorkOrderStatusEntry>{
      for (final entry in statusEntries.whereType<WorkOrderStatusEntry>())
        entry.subAssemblyId: entry,
    };
    final subAssemblyIds = weeklyItems
        .map((item) => item.subAssembly.id)
        .whereType<int>()
        .toSet()
        .toList(growable: false);
    final assigneeEntries = await Future.wait(
      subAssemblyIds.map((id) async {
        final assignments = await MachineDatabase.instance
            .getWorkOrderTaskAssignments(id);
        return MapEntry(id, assignments);
      }),
    );
    final taskOutcomeEntries = await Future.wait(
      subAssemblyIds.map((id) async {
        final outcomes = await MachineDatabase.instance
            .getWorkOrderTaskOutcomes(id);
        return MapEntry(id, outcomes);
      }),
    );
    final contractorCompanies = await MachineDatabase.instance
        .getContractorCompanies();
    final persistedAssignmentsBySubAssemblyId = <int, Map<int, String>>{
      for (final entry in assigneeEntries) entry.key: entry.value,
    };
    final taskOutcomesBySubAssemblyId =
        <int, Map<int, WorkOrderTaskOutcomeEntry>>{
          for (final entry in taskOutcomeEntries) entry.key: entry.value,
        };

    final document = pw.Document();

    pw.Widget section(String title, List<_WorkOrderItem> items) {
      final titleStyle = pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
      );

      if (items.isEmpty) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: titleStyle),
            pw.SizedBox(height: 6),
            pw.Text('No work orders in this section.'),
            pw.SizedBox(height: 14),
          ],
        );
      }

      final groupedTasks = <String, List<Map<String, String>>>{};
      for (final item in items) {
        final dueDate = _formatDate(item.projectedNextDate);
        final dueText = item.daysUntilDue == 0
            ? 'Due today'
            : 'Due in ${item.daysUntilDue} day${item.daysUntilDue == 1 ? '' : 's'}';
        final subAssemblyId = item.subAssembly.id;
        final licenseTrades = _machineLicenseTradeLabels(item.machine);
        final requiredSkills = _requiredSkillsForWorkOrder(item.subAssembly);
        final statusEntry = subAssemblyId == null
            ? null
            : workOrderStatusesBySubAssemblyId[subAssemblyId];
        final statusNotes = (statusEntry?.notes ?? '').trim();
        final statusSummary = statusEntry == null
            ? 'Not set'
            : '${statusEntry.status} | Licensed Work: ${statusEntry.isLicensedWork ? 'Yes' : 'No'} | Rescheduled: ${statusEntry.isRescheduled ? 'Yes' : 'No'} | Notes: ${statusNotes.isEmpty ? 'Not set' : statusNotes}';
        final tasks =
            List<MaintenanceTask>.from(item.subAssembly.maintenanceTasks)
              ..sort((a, b) {
                final taskCmp = a.taskType.toLowerCase().compareTo(
                  b.taskType.toLowerCase(),
                );
                if (taskCmp != 0) {
                  return taskCmp;
                }
                return a.timeCategory.toLowerCase().compareTo(
                  b.timeCategory.toLowerCase(),
                );
              });

        for (int taskIndex = 0; taskIndex < tasks.length; taskIndex += 1) {
          final task = tasks[taskIndex];
          final taskOutcome = subAssemblyId == null || task.id == null
              ? null
              : taskOutcomesBySubAssemblyId[subAssemblyId]?[task.id!];
          final assigneeName = subAssemblyId == null
              ? 'Contractor Needed'
              : _resolvedAssigneeNameForTask(
                  subAssemblyId: subAssemblyId,
                  machine: item.machine,
                  subAssembly: item.subAssembly,
                  task: task,
                  taskIndex: taskIndex,
                  persistedAssignments:
                      persistedAssignmentsBySubAssemblyId[subAssemblyId] ??
                      const <int, String>{},
                  contractorCompanies: contractorCompanies,
                  updateDraft: false,
                );

          groupedTasks.putIfAbsent(assigneeName, () => []).add({
            'task': _taskLabel(task),
            'due': '$dueDate ($dueText)',
            'superCategory': _superCategoryForSubAssembly(item.subAssembly),
            'machine': item.machine.name,
            'subAssembly':
                '${item.subAssembly.name} (${item.subAssembly.modelName})',
            'serial': item.subAssembly.serialNumber,
            'component': item.subAssembly.subCategory,
            'location': item.subAssembly.location,
            'trades': licenseTrades.isEmpty ? 'None' : licenseTrades.join(', '),
            'skills': requiredSkills.isEmpty
                ? 'None'
                : requiredSkills.join(', '),
            'taskOutcome': (taskOutcome?.outcome ?? '').trim().isEmpty
                ? 'Not set'
                : taskOutcome!.outcome,
            'taskOutcomeNotes': (taskOutcome?.notes ?? '').trim().isEmpty
                ? 'Not set'
                : taskOutcome!.notes,
            'status': statusSummary,
          });
        }
      }

      final assignees = groupedTasks.keys.toList(growable: false)
        ..sort((a, b) {
          if (a == 'Contractor Needed') {
            return 1;
          }
          if (b == 'Contractor Needed') {
            return -1;
          }
          return a.toLowerCase().compareTo(b.toLowerCase());
        });

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: titleStyle),
          pw.SizedBox(height: 6),
          ...assignees.map((assignee) {
            final taskRows =
                groupedTasks[assignee] ?? const <Map<String, String>>[];
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '$assignee (${taskRows.length})',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  ...taskRows.map((row) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Task: ${row['task'] ?? ''}'),
                          pw.Text('Due: ${row['due'] ?? ''}'),
                          pw.Text(
                            'Super Category: ${row['superCategory'] ?? 'Not set'}',
                          ),
                          pw.Text(
                            'Machine: ${row['machine'] ?? ''} | Sub-Assembly: ${row['subAssembly'] ?? ''}',
                          ),
                          pw.Text(
                            'Serial: ${row['serial'] ?? ''} | Component: ${row['component'] ?? ''} | Location: ${row['location'] ?? ''}',
                          ),
                          pw.Text(
                            'Required Trades: ${row['trades'] ?? 'None'}',
                          ),
                          pw.Text(
                            'Required Skills: ${row['skills'] ?? 'None'}',
                          ),
                          pw.Text(
                            'Task Outcome: ${row['taskOutcome'] ?? 'Not set'}',
                          ),
                          pw.Text(
                            'Task Notes: ${row['taskOutcomeNotes'] ?? 'Not set'}',
                          ),
                          pw.Text('Work Status: ${row['status'] ?? 'Not set'}'),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 10),
        ],
      );
    }

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
          return [
            pw.Text(
              'Work Orders Report',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Generated: ${_formatDate(DateTime.now())}'),
            pw.SizedBox(height: 12),
            section('Due Today (${dueToday.length})', dueToday),
            section('Due This Week (${dueThisWeek.length})', dueThisWeek),
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
  }

  Widget _buildWorkOrdersTab() {
    _ensureMachinesVisible();
    final workOrders = _buildWorkOrderItemsForNextFiveDays();
    const cardPadding = 16.0;

    if (workOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No sub-assemblies are due in the next five days.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _reloadMachinesFromDatabase(showFeedback: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Reload Data'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: workOrders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = workOrders[index];
        final subAssemblyId = item.subAssembly.id;
        final machineLicenseTrades = _machineLicenseTradeLabels(item.machine);
        final requiredSkills = _requiredSkillsForWorkOrder(item.subAssembly);
        final requiredParts = _requiredPartsForWorkOrder(item.subAssembly);
        final dueLabel = _formatDate(item.projectedNextDate);
        final dueText = item.daysUntilDue == 0
            ? 'Due today'
            : 'Due in ${item.daysUntilDue} day${item.daysUntilDue == 1 ? '' : 's'}';
        final superCategory = _superCategoryForSubAssembly(item.subAssembly);

        return Card(
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subAssembly.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Super Category: $superCategory'),
                const SizedBox(height: 8),
                Text('Due Date: $dueLabel ($dueText)'),
                Text('Machine: ${item.machine.name}'),
                Text(
                  'Model: ${item.subAssembly.modelName} (${item.subAssembly.modelNumber})',
                ),
                Text('Serial: ${item.subAssembly.serialNumber}'),
                Text('Location: ${item.subAssembly.location}'),
                const SizedBox(height: 8),
                Text(
                  'Required Trades',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: machineLicenseTrades.isEmpty
                      ? const [Chip(label: Text('None'))]
                      : machineLicenseTrades
                            .map((trade) => Chip(label: Text(trade)))
                            .toList(growable: false),
                ),
                const SizedBox(height: 10),
                Text(
                  'Required Skills',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: requiredSkills.isEmpty
                      ? const [Chip(label: Text('None'))]
                      : requiredSkills
                            .map((skill) => Chip(label: Text(skill)))
                            .toList(growable: false),
                ),
                if (requiredParts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Required Parts',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: requiredParts
                        .map(
                          (part) => Tooltip(
                            message: [
                              if (part.vendorUrl.trim().isNotEmpty)
                                'Tap chip to open vendor link',
                              if (part.vendorUrl.trim().isNotEmpty)
                                'URL: ${part.vendorUrl.trim()}',
                              if (part.vendorPhoneNumber.trim().isNotEmpty)
                                'Phone: ${part.vendorPhoneNumber.trim()}',
                            ].join('\n'),
                            child: ActionChip(
                              onPressed: part.vendorUrl.trim().isEmpty
                                  ? null
                                  : () async {
                                      await _openVendorUrl(part.vendorUrl);
                                    },
                              avatar: Icon(
                                part.vendorUrl.trim().isEmpty
                                    ? Icons.inventory_2_outlined
                                    : Icons.open_in_new_outlined,
                                size: 18,
                              ),
                              label: Text(_requiredPartChipLabel(part)),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 10),
                if (subAssemblyId != null)
                  FutureBuilder<Map<int, String>>(
                    future: _workOrderTaskAssignmentFutureForSubAssembly(
                      subAssemblyId,
                    ),
                    builder: (context, snapshot) {
                      final persistedAssignments =
                          snapshot.data ?? const <int, String>{};
                      return FutureBuilder<List<ContractorCompany>>(
                        future: _workOrderContractorsFutureForSubAssembly(
                          subAssemblyId,
                        ),
                        builder: (context, contractorSnapshot) {
                          final contractorCompanies =
                              contractorSnapshot.data ??
                              const <ContractorCompany>[];
                          return FutureBuilder<
                            Map<int, WorkOrderTaskOutcomeEntry>
                          >(
                            future: _workOrderTaskOutcomeFutureForSubAssembly(
                              subAssemblyId,
                            ),
                            builder: (context, outcomeSnapshot) {
                              final persistedOutcomes =
                                  outcomeSnapshot.data ??
                                  const <int, WorkOrderTaskOutcomeEntry>{};
                              return _buildTaskAssignmentAndOutcomeSection(
                                subAssemblyId: subAssemblyId,
                                machine: item.machine,
                                subAssembly: item.subAssembly,
                                persistedAssignments: persistedAssignments,
                                persistedOutcomes: persistedOutcomes,
                                contractorCompanies: contractorCompanies,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
