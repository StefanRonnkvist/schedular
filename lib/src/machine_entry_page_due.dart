// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

class _MachineDetailEditDraft {
  _MachineDetailEditDraft.fromMachine(Machine machine)
    : operatingHoursController = TextEditingController(
        text: machine.operatingHours,
      ),
      idleHoursController = TextEditingController(text: machine.idleHours),
      lastCheckDateController = TextEditingController(
        text: machine.lastCheckDate,
      );

  final TextEditingController operatingHoursController;
  final TextEditingController idleHoursController;
  final TextEditingController lastCheckDateController;

  void syncFromMachine(Machine machine) {
    operatingHoursController.text = machine.operatingHours;
    idleHoursController.text = machine.idleHours;
    lastCheckDateController.text = machine.lastCheckDate;
  }

  void dispose() {
    operatingHoursController.dispose();
    idleHoursController.dispose();
    lastCheckDateController.dispose();
  }
}

class _SubAssemblyDetailEditDraft {
  _SubAssemblyDetailEditDraft.fromSubAssembly(SubAssembly subAssembly)
    : operatingHoursController = TextEditingController(
        text: subAssembly.operatingHours,
      ),
      idleHoursController = TextEditingController(text: subAssembly.idleHours),
      superCategory = subAssembly.superCategory,
      subCategory = subAssembly.subCategory;

  final TextEditingController operatingHoursController;
  final TextEditingController idleHoursController;
  String superCategory;
  String subCategory;

  void syncFromSubAssembly(SubAssembly subAssembly) {
    operatingHoursController.text = subAssembly.operatingHours;
    idleHoursController.text = subAssembly.idleHours;
    superCategory = subAssembly.superCategory;
    subCategory = subAssembly.subCategory;
  }

  void dispose() {
    operatingHoursController.dispose();
    idleHoursController.dispose();
  }
}

extension _MachineEntryPageDueExtension on _MachineEntryPageState {
  void _disposeMaintenanceDueDetailDrafts() {
    for (final draft in _maintenanceDueDetailDrafts.values) {
      draft.dispose();
    }
    for (final draft in _subAssemblyDetailDrafts.values) {
      draft.dispose();
    }
    _maintenanceDueDetailDrafts.clear();
    _machineDetailHistoryFutures.clear();
    _subAssemblyDetailDrafts.clear();
    _subAssemblyDetailHistoryFutures.clear();
    _workOrderStatusFutures.clear();
    _workOrderTaskAssignmentFutures.clear();
    _workOrderTaskOutcomeFutures.clear();
    _workOrderContractorFutures.clear();
    _workOrderStatusSelectionDrafts.clear();
    _workOrderRescheduledDrafts.clear();
    _workOrderLicensedWorkDrafts.clear();
    _workOrderStatusNotesDrafts.clear();
    _workOrderTaskAssigneeDrafts.clear();
    _workOrderTaskOutcomeDrafts.clear();
    _workOrderTaskOutcomeNotesDrafts.clear();
  }

  void _pruneMaintenanceDueState() {
    final validMachineIds = _machines
        .map((machine) => machine.id)
        .whereType<int>()
        .toSet();
    final validSubAssemblyIds = _machines
        .expand((machine) => machine.subAssemblies)
        .map((subAssembly) => subAssembly.id)
        .whereType<int>()
        .toSet();

    final staleDraftIds = _maintenanceDueDetailDrafts.keys
        .where((id) => !validMachineIds.contains(id))
        .toList(growable: false);
    for (final id in staleDraftIds) {
      _maintenanceDueDetailDrafts.remove(id)?.dispose();
      _machineDetailHistoryFutures.remove(id);
    }

    final staleSubAssemblyDraftIds = _subAssemblyDetailDrafts.keys
        .where((id) => !validSubAssemblyIds.contains(id))
        .toList(growable: false);
    for (final id in staleSubAssemblyDraftIds) {
      _subAssemblyDetailDrafts.remove(id)?.dispose();
      _subAssemblyDetailHistoryFutures.remove(id);
      _workOrderStatusFutures.remove(id);
      _workOrderTaskAssignmentFutures.remove(id);
      _workOrderContractorFutures.remove(id);
      _workOrderStatusSelectionDrafts.remove(id);
      _workOrderRescheduledDrafts.remove(id);
      _workOrderLicensedWorkDrafts.remove(id);
      _workOrderStatusNotesDrafts.remove(id);
      _workOrderTaskAssigneeDrafts.removeWhere(
        (key, _) => key.startsWith('$id:'),
      );
    }
  }

  _MachineDetailEditDraft? _detailDraftForMachine(Machine machine) {
    final machineId = machine.id;
    if (machineId == null) {
      return null;
    }

    return _maintenanceDueDetailDrafts.putIfAbsent(
      machineId,
      () => _MachineDetailEditDraft.fromMachine(machine),
    );
  }

  Future<List<MachineDetailHistoryEntry>> _historyFutureForMachine(
    int machineId,
  ) {
    return _machineDetailHistoryFutures.putIfAbsent(
      machineId,
      () => MachineDatabase.instance.getMachineDetailHistory(machineId),
    );
  }

  _SubAssemblyDetailEditDraft? _detailDraftForSubAssembly(
    SubAssembly subAssembly,
  ) {
    final subAssemblyId = subAssembly.id;
    if (subAssemblyId == null) {
      return null;
    }

    return _subAssemblyDetailDrafts.putIfAbsent(
      subAssemblyId,
      () => _SubAssemblyDetailEditDraft.fromSubAssembly(subAssembly),
    );
  }

  Future<List<SubAssemblyDetailHistoryEntry>> _historyFutureForSubAssembly(
    int subAssemblyId,
  ) {
    return _subAssemblyDetailHistoryFutures.putIfAbsent(
      subAssemblyId,
      () => MachineDatabase.instance.getSubAssemblyDetailHistory(subAssemblyId),
    );
  }

  Future<WorkOrderStatusEntry?> _workOrderStatusFutureForSubAssembly(
    int subAssemblyId,
  ) {
    return _workOrderStatusFutures.putIfAbsent(
      subAssemblyId,
      () => MachineDatabase.instance.getWorkOrderStatus(subAssemblyId),
    );
  }

  Widget _buildMaintenanceDueWorkOrderStatusColumns(SubAssembly subAssembly) {
    final subAssemblyId = subAssembly.id;
    if (subAssemblyId == null) {
      return const Text(
        'Work Order Status: Unavailable\nStatus Entered: Unavailable\nNotes: Unavailable',
      );
    }

    return FutureBuilder<WorkOrderStatusEntry?>(
      future: _workOrderStatusFutureForSubAssembly(subAssemblyId),
      builder: (context, snapshot) {
        final status = snapshot.data?.status ?? 'Not set';
        final rescheduled = snapshot.data?.isRescheduled == true ? 'Yes' : 'No';
        final licensedWork = snapshot.data?.isLicensedWork == true
            ? 'Yes'
            : 'No';
        final notes = (snapshot.data?.notes ?? '').trim();
        final enteredAt = snapshot.data == null
            ? 'Not set'
            : _formatHistoryTimestamp(snapshot.data!.enteredAtUtc);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Work Status')),
              DataColumn(label: Text('Rescheduled')),
              DataColumn(label: Text('Licensed Work')),
              DataColumn(label: Text('Notes')),
              DataColumn(label: Text('Status Entered')),
            ],
            rows: [
              DataRow(
                cells: [
                  DataCell(Text(status)),
                  DataCell(Text(rescheduled)),
                  DataCell(Text(licensedWork)),
                  DataCell(Text(notes.isEmpty ? 'Not set' : notes)),
                  DataCell(Text(enteredAt)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWorkOrderStatusSummaryChips(SubAssembly subAssembly) {
    final subAssemblyId = subAssembly.id;
    if (subAssemblyId == null) {
      return const Text('Work Order Status: Unavailable');
    }

    return FutureBuilder<WorkOrderStatusEntry?>(
      future: _workOrderStatusFutureForSubAssembly(subAssemblyId),
      builder: (context, snapshot) {
        final entry = snapshot.data;
        if (entry == null || entry.status.trim().isEmpty) {
          return const Text('Work Order Status: Not set');
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(
                entry.isRescheduled
                    ? Icons.schedule_outlined
                    : Icons.verified_outlined,
                size: 18,
              ),
              label: Text('Status: ${entry.status}'),
            ),
            if (entry.isLicensedWork)
              const Chip(
                avatar: Icon(Icons.rule_folder_outlined, size: 18),
                label: Text('Licensed Work'),
              ),
            if (entry.isRescheduled)
              const Chip(
                avatar: Icon(Icons.event_repeat_outlined, size: 18),
                label: Text('Rescheduled'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMachineDetailHistory(int machineId) {
    return FutureBuilder<List<MachineDetailHistoryEntry>>(
      future: _historyFutureForMachine(machineId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Failed to load detail history.'),
          );
        }

        final entries = snapshot.data ?? const <MachineDetailHistoryEntry>[];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No prior values saved yet.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries
                .map((entry) {
                  final recordedAt = _formatHistoryTimestamp(
                    entry.recordedAtUtc,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Saved: $recordedAt\n'
                      'Operating: ${entry.operatingHours} | '
                      'Idle: ${entry.idleHours} | '
                      'Last Check: ${entry.lastCheckDate}',
                    ),
                  );
                })
                .toList(growable: false),
          ),
        );
      },
    );
  }

  Widget _buildSubAssemblyDetailHistory(int subAssemblyId) {
    return FutureBuilder<List<SubAssemblyDetailHistoryEntry>>(
      future: _historyFutureForSubAssembly(subAssemblyId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Failed to load sub-assembly detail history.'),
          );
        }

        final entries =
            snapshot.data ?? const <SubAssemblyDetailHistoryEntry>[];
        if (entries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No prior values saved yet.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries
                .map((entry) {
                  final recordedAt = _formatHistoryTimestamp(
                    entry.recordedAtUtc,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Saved: $recordedAt\n'
                      'Operating: ${entry.operatingHours} | '
                      'Idle: ${entry.idleHours}',
                    ),
                  );
                })
                .toList(growable: false),
          ),
        );
      },
    );
  }

  int? _daysForTaskInterval(String timeCategory, int value) {
    if (value < 1) {
      return null;
    }

    switch (timeCategory) {
      case 'Days':
        return value;
      case 'Weeks':
        return value * 7;
      case 'Months':
        return value * 30;
      case 'Quarters':
        return value * 91;
      case 'Semi-Annual':
        return value * 182;
      case 'Annual':
        return value * 365;
      case 'Biannual':
      case 'Bi-Annual':
        return value * 730;
      case 'Years':
        return value * 365;
      default:
        return null;
    }
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _nextRecurringDueDate({
    required DateTime baseline,
    required int intervalDays,
    DateTime? referenceDate,
  }) {
    final firstDueDate = _startOfDay(
      baseline,
    ).add(Duration(days: intervalDays));
    final onOrAfter = _startOfDay(referenceDate ?? DateTime.now());
    if (!onOrAfter.isAfter(firstDueDate)) {
      return firstDueDate;
    }

    final elapsedDays = onOrAfter.difference(firstDueDate).inDays;
    final fullIntervals = elapsedDays ~/ intervalDays;
    var candidate = firstDueDate.add(
      Duration(days: fullIntervals * intervalDays),
    );
    if (candidate.isBefore(onOrAfter)) {
      candidate = candidate.add(Duration(days: intervalDays));
    }
    return candidate;
  }

  DateTime? _projectedNextDateForSubAssembly(
    Machine machine,
    SubAssembly subAssembly, {
    DateTime? referenceDate,
  }) {
    final baseline = DateTime.tryParse(machine.lastCheckDate.trim());
    if (baseline == null) {
      return null;
    }

    DateTime? earliest;
    for (final task in subAssembly.maintenanceTasks) {
      final days = _daysForTaskInterval(task.timeCategory, task.timeValue);
      if (days == null) {
        continue;
      }
      final candidate = _nextRecurringDueDate(
        baseline: baseline,
        intervalDays: days,
        referenceDate: referenceDate,
      );
      if (earliest == null || candidate.isBefore(earliest)) {
        earliest = candidate;
      }
    }

    return earliest;
  }

  String _projectedNextDateLabel(Machine machine, SubAssembly subAssembly) {
    if (DateTime.tryParse(machine.lastCheckDate.trim()) == null) {
      return 'Unavailable (machine last check date is invalid)';
    }

    final projected = _projectedNextDateForSubAssembly(machine, subAssembly);
    if (projected == null) {
      return 'Unavailable (no date-based task intervals)';
    }

    return _formatDate(projected);
  }

  DateTime? _projectedNextDateForTask(
    Machine machine,
    MaintenanceTask task, {
    DateTime? referenceDate,
  }) {
    final baseline = DateTime.tryParse(machine.lastCheckDate.trim());
    if (baseline == null) {
      return null;
    }

    final days = _daysForTaskInterval(task.timeCategory, task.timeValue);
    if (days == null) {
      return null;
    }

    return _nextRecurringDueDate(
      baseline: baseline,
      intervalDays: days,
      referenceDate: referenceDate,
    );
  }

  String _projectedNextDateLabelForTask(Machine machine, MaintenanceTask task) {
    if (DateTime.tryParse(machine.lastCheckDate.trim()) == null) {
      return 'Unavailable (invalid machine last check date)';
    }

    final projected = _projectedNextDateForTask(machine, task);
    if (projected == null) {
      return 'Unavailable (category is not date-based)';
    }

    return _formatDate(projected);
  }

  String _maintenanceDueRequiredPartChipLabel(RequiredPart part) {
    final details = <String>[];
    if (part.oemPn.trim().isNotEmpty) {
      details.add('OEM ${part.oemPn.trim()}');
    }
    if (part.vendorPn.trim().isNotEmpty) {
      details.add('VPN ${part.vendorPn.trim()}');
    }
    if (part.vendorName.trim().isNotEmpty) {
      details.add(part.vendorName.trim());
    }
    if (part.estimatedLeadTime.trim().isNotEmpty) {
      details.add(part.estimatedLeadTime.trim());
    }
    return details.isEmpty ? 'Part details unavailable' : details.join(' • ');
  }

  Widget _buildMaintenanceTaskSummarySection(
    Machine machine,
    SubAssembly subAssembly,
  ) {
    if (subAssembly.maintenanceTasks.isEmpty) {
      return const Text('No tasks.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(subAssembly.maintenanceTasks.length, (
        taskIndex,
      ) {
        final task = subAssembly.maintenanceTasks[taskIndex];
        final requiredParts = task.requiredParts
            .where((part) => !part.isEmpty)
            .toList(growable: false);

        return Padding(
          padding: EdgeInsets.only(
            bottom: taskIndex == subAssembly.maintenanceTasks.length - 1
                ? 0
                : 8,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${taskIndex + 1}. ${task.taskType}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Interval: every ${task.timeValue} ${task.timeCategory}',
                  ),
                  Text(
                    'Next: ${_projectedNextDateLabelForTask(machine, task)}',
                  ),
                  if (requiredParts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Required Parts',
                      style: Theme.of(context).textTheme.labelMedium,
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
                                label: Text(
                                  _maintenanceDueRequiredPartChipLabel(part),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Future<void> _saveSubAssemblyDetailsFromDueTab({
    required Machine machine,
    required SubAssembly subAssembly,
  }) async {
    final machineId = machine.id;
    final subAssemblyId = subAssembly.id;
    if (machineId == null || subAssemblyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update sub-assembly without ids.'),
        ),
      );
      return;
    }

    final draft = _detailDraftForSubAssembly(subAssembly);
    if (draft == null) {
      return;
    }

    final operatingHours = draft.operatingHoursController.text.trim();
    final idleHours = draft.idleHoursController.text.trim();
    final superCategory = draft.superCategory.trim();
    final subCategory = draft.subCategory.trim();

    final operatingError = _numericRequiredValidator(operatingHours);
    if (operatingError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operating hours: $operatingError')),
      );
      return;
    }

    final idleError = _numericRequiredValidator(idleHours);
    if (idleError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Idle hours: $idleError')));
      return;
    }

    final hasChanges =
        subAssembly.operatingHours != operatingHours ||
        subAssembly.idleHours != idleHours ||
        subAssembly.superCategory.trim() != superCategory ||
        subAssembly.subCategory.trim() != subCategory;
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No detail changes to save.')),
      );
      return;
    }

    try {
      final changed = await MachineDatabase.instance
          .updateSubAssemblyDetailsWithHistory(
            subAssemblyId: subAssemblyId,
            operatingHours: operatingHours,
            idleHours: idleHours,
          );
      await MachineDatabase.instance.updateSubAssemblySuperCategory(
        subAssemblyId: subAssemblyId,
        superCategory: superCategory,
      );
      await MachineDatabase.instance.updateSubAssemblyComponentType(
        subAssemblyId: subAssemblyId,
        componentType: subCategory,
      );

      if (!mounted) {
        return;
      }

      if (changed == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sub-assembly not found.')),
        );
        return;
      }

      setState(() {
        final machineIndex = _machines.indexWhere((m) => m.id == machineId);
        if (machineIndex != -1) {
          final updatedSubAssemblies = _machines[machineIndex].subAssemblies
              .map((item) {
                if (item.id != subAssemblyId) {
                  return item;
                }
                return item.copyWith(
                  operatingHours: operatingHours,
                  idleHours: idleHours,
                  superCategory: superCategory,
                  subCategory: subCategory,
                );
              })
              .toList(growable: false);

          _machines[machineIndex] = _machines[machineIndex].copyWith(
            subAssemblies: updatedSubAssemblies,
          );
        }

        _subAssemblyDetailHistoryFutures.remove(subAssemblyId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sub-assembly details saved.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Failed to save sub-assembly details.', error);
    }
  }

  Widget _buildEditableSubAssemblyDetails({
    required Machine machine,
    required SubAssembly subAssembly,
  }) {
    final draft = _detailDraftForSubAssembly(subAssembly);
    if (draft == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Sub-assembly id is missing, so details cannot be edited.'),
      );
    }

    final subAssemblyId = subAssembly.id!;
    final superCategoryOptions = _availableSuperCategories;
    final subCategoryOptions = _availableSubCategories;
    if (!superCategoryOptions.contains(draft.superCategory)) {
      draft.superCategory = superCategoryOptions.first;
    }
    if (!subCategoryOptions.contains(draft.subCategory)) {
      draft.subCategory = subCategoryOptions.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: draft.operatingHoursController,
          decoration: const InputDecoration(
            labelText: 'Operating Hours',
            border: OutlineInputBorder(),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: draft.idleHoursController,
          decoration: const InputDecoration(
            labelText: 'Idle Hours',
            border: OutlineInputBorder(),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: draft.superCategory,
                decoration: const InputDecoration(
                  labelText: 'Super Category',
                  border: OutlineInputBorder(),
                ),
                items: superCategoryOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    draft.superCategory = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Add Super Category',
              child: IconButton.outlined(
                onPressed: () {
                  _showAddSuperCategoryDialog(
                    onSaved: (type) {
                      setState(() {
                        draft.superCategory = type;
                      });
                    },
                  );
                },
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: draft.subCategory,
                decoration: const InputDecoration(
                  labelText: 'Sub Category',
                  border: OutlineInputBorder(),
                ),
                items: subCategoryOptions
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    draft.subCategory = value;
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Add Sub Category',
              child: IconButton.outlined(
                onPressed: () {
                  _showAddSubCategoryDialog(
                    onSaved: (type) {
                      setState(() {
                        draft.subCategory = type;
                      });
                    },
                  );
                },
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Projected Next Date: ${_projectedNextDateLabel(machine, subAssembly)}',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _saveSubAssemblyDetailsFromDueTab(
              machine: machine,
              subAssembly: subAssembly,
            ),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Sub-Assembly'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Saved Detail History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        _buildSubAssemblyDetailHistory(subAssemblyId),
      ],
    );
  }

  Future<void> _saveMachineDetailsFromDueTab(Machine machine) async {
    final machineId = machine.id;
    if (machineId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update machine without id.')),
      );
      return;
    }

    final draft = _detailDraftForMachine(machine);
    if (draft == null) {
      return;
    }

    final operatingHours = draft.operatingHoursController.text.trim();
    final idleHours = draft.idleHoursController.text.trim();
    final lastCheckDate = draft.lastCheckDateController.text.trim();

    final operatingError = _numericRequiredValidator(operatingHours);
    if (operatingError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operating hours: $operatingError')),
      );
      return;
    }

    final idleError = _numericRequiredValidator(idleHours);
    if (idleError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Idle hours: $idleError')));
      return;
    }

    final checkDateError = _dateRequiredValidator(lastCheckDate);
    if (checkDateError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Last check date: $checkDateError')),
      );
      return;
    }

    final hasChanges =
        machine.operatingHours != operatingHours ||
        machine.idleHours != idleHours ||
        machine.lastCheckDate != lastCheckDate;
    final lastCheckDateChanged = machine.lastCheckDate != lastCheckDate;
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No detail changes to save.')),
      );
      return;
    }

    try {
      final changed = await MachineDatabase.instance
          .updateMachineDetailsWithHistory(
            machineId: machineId,
            operatingHours: operatingHours,
            idleHours: idleHours,
            lastCheckDate: lastCheckDate,
          );

      if (!mounted) {
        return;
      }

      if (changed == 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Machine not found.')));
        return;
      }

      setState(() {
        final index = _machines.indexWhere((m) => m.id == machineId);
        if (index != -1) {
          _machines[index] = _machines[index].copyWith(
            operatingHours: operatingHours,
            idleHours: idleHours,
            lastCheckDate: lastCheckDate,
          );
        }

        _machineDetailHistoryFutures.remove(machineId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lastCheckDateChanged
                ? 'Machine details saved. Work order statuses were reset for the next cycle.'
                : 'Machine details saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showErrorSnackBar('Failed to save machine details.', error);
    }
  }

  Widget _buildEditableMachineDetails(Machine machine) {
    final draft = _detailDraftForMachine(machine);
    if (draft == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Machine id is missing, so details cannot be edited.'),
      );
    }

    final machineId = machine.id!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: draft.operatingHoursController,
          decoration: const InputDecoration(
            labelText: 'Operating Hours',
            border: OutlineInputBorder(),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: draft.idleHoursController,
          decoration: const InputDecoration(
            labelText: 'Idle Hours',
            border: OutlineInputBorder(),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: draft.lastCheckDateController,
          decoration: const InputDecoration(
            labelText: 'Last Check Date (YYYY-MM-DD)',
            border: OutlineInputBorder(),
            isDense: false,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          textAlignVertical: TextAlignVertical.center,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _saveMachineDetailsFromDueTab(machine),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save Details'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Saved Detail History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        _buildMachineDetailHistory(machineId),
      ],
    );
  }
}
