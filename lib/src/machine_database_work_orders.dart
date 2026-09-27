
part of 'package:schedular/main.dart';

extension _MachineDatabaseWorkOrdersExtension on MachineDatabase {
  Future<int> _workOrdersUpsertWorkOrderStatusImpl({
    required int subAssemblyId,
    required String status,
    bool isRescheduled = false,
    bool isLicensedWork = false,
    String notes = '',
    DateTime? enteredAtUtc,
  }) async {
    final db = await database;
    return db.insert(workOrderStatusTable, {
      'subAssemblyId': subAssemblyId,
      'status': status,
      'isRescheduled': isRescheduled ? 1 : 0,
      'isLicensedWork': isLicensedWork ? 1 : 0,
      'notes': notes,
      'enteredAtUtc': (enteredAtUtc ?? DateTime.now().toUtc())
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _workOrdersUpsertWorkOrderTaskAssignmentImpl({
    required int subAssemblyId,
    required int taskId,
    required String assigneeValue,
    DateTime? enteredAtUtc,
  }) async {
    final normalized = assigneeValue.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.insert(workOrderTaskAssignmentTable, {
      'subAssemblyId': subAssemblyId,
      'taskId': taskId,
      'assigneeValue': normalized,
      'enteredAtUtc': (enteredAtUtc ?? DateTime.now().toUtc())
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _workOrdersUpsertWorkOrderTaskOutcomeImpl({
    required int subAssemblyId,
    required int taskId,
    required String outcome,
    String notes = '',
    DateTime? enteredAtUtc,
  }) async {
    final normalizedOutcome = outcome.trim();
    if (normalizedOutcome.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.insert(workOrderTaskOutcomeTable, {
      'subAssemblyId': subAssemblyId,
      'taskId': taskId,
      'outcome': normalizedOutcome,
      'notes': notes.trim(),
      'enteredAtUtc': (enteredAtUtc ?? DateTime.now().toUtc())
          .toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<int, String>> _workOrdersGetWorkOrderTaskAssignmentsImpl(
    int subAssemblyId,
  ) async {
    final db = await database;
    final rows = await db.query(
      workOrderTaskAssignmentTable,
      columns: ['taskId', 'assigneeValue'],
      where: 'subAssemblyId = ?',
      whereArgs: [subAssemblyId],
      orderBy: 'taskId ASC',
    );

    final assignments = <int, String>{};
    for (final row in rows) {
      final taskId = row['taskId'] as int?;
      final assigneeValue = (row['assigneeValue'] as String?)?.trim() ?? '';
      if (taskId == null || assigneeValue.isEmpty) {
        continue;
      }
      assignments[taskId] = assigneeValue;
    }

    return assignments;
  }

  Future<int> _workOrdersDeleteWorkOrderTaskAssignmentImpl({
    required int subAssemblyId,
    required int taskId,
  }) async {
    final db = await database;
    return db.delete(
      workOrderTaskAssignmentTable,
      where: 'subAssemblyId = ? AND taskId = ?',
      whereArgs: [subAssemblyId, taskId],
    );
  }

  Future<Map<int, WorkOrderTaskOutcomeEntry>>
  _workOrdersGetWorkOrderTaskOutcomesImpl(
    int subAssemblyId,
  ) async {
    final db = await database;
    final rows = await db.query(
      workOrderTaskOutcomeTable,
      where: 'subAssemblyId = ?',
      whereArgs: [subAssemblyId],
      orderBy: 'taskId ASC',
    );

    final outcomes = <int, WorkOrderTaskOutcomeEntry>{};
    for (final row in rows) {
      final entry = WorkOrderTaskOutcomeEntry.fromMap(row);
      outcomes[entry.taskId] = entry;
    }
    return outcomes;
  }

  Future<WorkOrderStatusEntry?> _workOrdersGetWorkOrderStatusImpl(
    int subAssemblyId,
  ) async {
    final db = await database;
    final rows = await db.query(
      workOrderStatusTable,
      where: 'subAssemblyId = ?',
      whereArgs: [subAssemblyId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WorkOrderStatusEntry.fromMap(rows.first);
  }

  Future<Map<String, int>> _workOrdersGetWorkOrderStatusCountsImpl() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT status, COUNT(*) AS cnt FROM $workOrderStatusTable GROUP BY status',
    );

    final counts = <String, int>{};
    for (final row in rows) {
      final status = (row['status'] as String?)?.trim();
      if (status == null || status.isEmpty) {
        continue;
      }
      counts[status] = row['cnt'] as int? ?? 0;
    }

    return counts;
  }

  Future<List<WorkOrderReport>> _workOrdersGetAllWorkOrdersReportImpl() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        wos.id,
        wos.subAssemblyId,
        wos.status,
        wos.notes,
        wos.enteredAtUtc,
        sa.machineId,
        m.name as machineName,
        sa.name as subAssemblyName
      FROM $workOrderStatusTable wos
      LEFT JOIN $subAssemblyTable sa ON wos.subAssemblyId = sa.id
      LEFT JOIN $machineTable m ON sa.machineId = m.id
      ORDER BY wos.status, wos.enteredAtUtc DESC
    ''');

    final reports = <WorkOrderReport>[];
    for (final row in rows) {
      final id = row['id'] as int?;
      final subAssemblyId = row['subAssemblyId'] as int?;
      final status = row['status'] as String?;
      final notes = row['notes'] as String?;
      final machineName = row['machineName'] as String?;
      final subAssemblyName = row['subAssemblyName'] as String?;
      final enteredAtUtc = row['enteredAtUtc'] as String?;

      if (id == null || subAssemblyId == null || status == null) {
        continue;
      }

      final assignmentRows = await db.query(
        workOrderTaskAssignmentTable,
        where: 'subAssemblyId = ?',
        whereArgs: [subAssemblyId],
        distinct: true,
        columns: ['assigneeValue'],
      );

      final assignees = <String>[];
      for (final assignmentRow in assignmentRows) {
        final assigneeValue = assignmentRow['assigneeValue'] as String?;
        if (assigneeValue != null && assigneeValue.isNotEmpty) {
          final employeeName = _workOrdersEmployeeNameFromAssigneeValue(
            assigneeValue,
          );
          if (!assignees.contains(employeeName)) {
            assignees.add(employeeName);
          }
        }
      }

      reports.add(WorkOrderReport(
        id: id,
        subAssemblyId: subAssemblyId,
        machineName: machineName ?? 'Unknown',
        subAssemblyName: subAssemblyName ?? 'Unknown',
        status: status,
        assignedEmployees: assignees,
        notes: notes ?? '',
        enteredAtUtc: enteredAtUtc ?? '',
      ));
    }

    return reports;
  }

  String _workOrdersEmployeeNameFromAssigneeValue(String assigneeValue) {
    const contractorPrefix = '__CONTRACTOR__|';
    if (assigneeValue == '__UNASSIGNED__|Contractor Needed') {
      return 'Contractor Needed';
    }
    if (assigneeValue.startsWith(contractorPrefix)) {
      final remainder = assigneeValue.substring(contractorPrefix.length);
      final separator = remainder.indexOf('|');
      if (separator < 0 || separator + 1 >= remainder.length) {
        return remainder.trim();
      }
      return remainder.substring(separator + 1).trim();
    }

    final separator = assigneeValue.indexOf('|');
    if (separator < 0 || separator + 1 >= assigneeValue.length) {
      return assigneeValue.trim();
    }
    return assigneeValue.substring(separator + 1).trim();
  }
}
