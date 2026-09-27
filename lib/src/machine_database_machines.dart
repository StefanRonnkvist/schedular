
part of 'package:schedular/main.dart';

extension _MachineDatabaseMachinesExtension on MachineDatabase {
  Future<Machine> _machinesInsertMachineImpl(Machine machine) async {
    final db = await database;
    return db.transaction((txn) async {
      final machineId = await txn.insert(
        machineTable,
        machine.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await _replaceMachineRequiredLicenses(
        txn,
        machineId,
        machine.additionalRequiredLicenses,
      );

      for (final subAssembly in machine.subAssemblies) {
        final subAssemblyId = await txn.insert(
          subAssemblyTable,
          subAssembly.copyWith(machineId: machineId).toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        for (final task in subAssembly.maintenanceTasks) {
          await txn.insert(
            maintenanceTaskTable,
            task.copyWith(subAssemblyId: subAssemblyId).toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      return machine.copyWith(id: machineId);
    });
  }

  Future<void> _machinesInsertMachinesImpl(List<Machine> machines) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    await db.transaction((txn) async {
      for (final machine in machines) {
        final machineId = await txn.insert(
          machineTable,
          machine.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        if (machineId <= 0) {
          continue;
        }

        await _replaceMachineRequiredLicenses(
          txn,
          machineId,
          machine.additionalRequiredLicenses,
        );

        for (final subAssembly in machine.subAssemblies) {
          final subAssemblyId = await txn.insert(
            subAssemblyTable,
            subAssembly.copyWith(machineId: machineId).toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          if (subAssemblyId <= 0) {
            continue;
          }

          for (final task in subAssembly.maintenanceTasks) {
            await txn.insert(
              maintenanceTaskTable,
              task.copyWith(subAssemblyId: subAssemblyId).toMap()..remove('id'),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });
  }

  Future<void> _machinesReplaceAllMachinesImpl(List<Machine> machines) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(workOrderStatusTable);
      await txn.delete(workOrderTaskAssignmentTable);
      await txn.delete(workOrderTaskOutcomeTable);
      await txn.delete(machineDetailHistoryTable);
      await txn.delete(subAssemblyDetailHistoryTable);
      await txn.delete(maintenanceTaskTable);
      await txn.delete(subAssemblyTable);
      await txn.delete(machineRequiredLicenseTable);
      await txn.delete(machineTable);

      for (final machine in machines) {
        final machineId = await txn.insert(
          machineTable,
          machine.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await _replaceMachineRequiredLicenses(
          txn,
          machineId,
          machine.additionalRequiredLicenses,
        );

        for (final subAssembly in machine.subAssemblies) {
          final subAssemblyId = await txn.insert(
            subAssemblyTable,
            subAssembly.copyWith(machineId: machineId).toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );

          for (final task in subAssembly.maintenanceTasks) {
            await txn.insert(
              maintenanceTaskTable,
              task.copyWith(subAssemblyId: subAssemblyId).toMap()..remove('id'),
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
          }
        }
      }
    });
  }

  Future<bool> _machinesHasMachineDetailHistoryImpl() async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $machineDetailHistoryTable',
    );
    return rows.isNotEmpty && (rows.first['cnt'] as int? ?? 0) > 0;
  }

  Future<void> _machinesInsertSampleHistoryImpl(
    List<Machine> machines,
    Random rng,
  ) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    final now = DateTime.now().toUtc();
    await db.transaction((txn) async {
      for (final machine in machines) {
        final machineId = machine.id;
        if (machineId == null) continue;

        final baseOpHours = int.tryParse(machine.operatingHours) ?? 1200;
        final baseIdleHours = int.tryParse(machine.idleHours) ?? 150;
        final machineHistoryCount = rng.nextInt(7) + 2;
        var daysAccumulated = 0;
        for (int i = machineHistoryCount; i >= 1; i--) {
          daysAccumulated += rng.nextInt(31) + 15;
          final opHours = (baseOpHours - i * (rng.nextInt(51) + 20)).clamp(
            0,
            999999,
          );
          final idleHours = (baseIdleHours - i * (rng.nextInt(11) + 3)).clamp(
            0,
            999999,
          );
          final checkDate = DateTime.now().subtract(
            Duration(days: daysAccumulated),
          );
          final recordedAt = now.subtract(
            Duration(days: daysAccumulated, hours: rng.nextInt(24)),
          );
          await txn.insert(machineDetailHistoryTable, {
            'machineId': machineId,
            'operatingHours': '$opHours',
            'idleHours': '$idleHours',
            'lastCheckDate': MachineDatabase._isoDate(checkDate),
            'recordedAtUtc': recordedAt.toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        for (final subAssembly in machine.subAssemblies) {
          final subId = subAssembly.id;
          if (subId == null) continue;

          final baseSubOpHours =
              int.tryParse(subAssembly.operatingHours) ?? 200;
          final baseSubIdleHours = int.tryParse(subAssembly.idleHours) ?? 25;
          final subHistoryCount = rng.nextInt(5) + 1;
          var subDaysAccumulated = 0;
          for (int i = subHistoryCount; i >= 1; i--) {
            subDaysAccumulated += rng.nextInt(46) + 20;
            final opHours = (baseSubOpHours - i * (rng.nextInt(31) + 10)).clamp(
              0,
              999999,
            );
            final idleHours = (baseSubIdleHours - i * (rng.nextInt(6) + 1))
                .clamp(0, 999999);
            final recordedAt = now.subtract(
              Duration(days: subDaysAccumulated, hours: rng.nextInt(24)),
            );
            await txn.insert(
              subAssemblyDetailHistoryTable,
              {
                'subAssemblyId': subId,
                'operatingHours': '$opHours',
                'idleHours': '$idleHours',
                'recordedAtUtc': recordedAt.toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
    });
  }

  Future<int> _machinesUpdateMachineImpl(Machine machine) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return db.transaction((txn) async {
      final changed = await txn.update(
        machineTable,
        machine.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [machine.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (machine.id != null) {
        await _replaceMachineRequiredLicenses(
          txn,
          machine.id!,
          machine.additionalRequiredLicenses,
        );

        await txn.delete(
          workOrderStatusTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machine.id],
        );

        await txn.delete(
          workOrderTaskAssignmentTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machine.id],
        );

        await txn.delete(
          workOrderTaskOutcomeTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machine.id],
        );

        await txn.delete(
          subAssemblyDetailHistoryTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machine.id],
        );

        await txn.delete(
          maintenanceTaskTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machine.id],
        );

        await txn.delete(
          subAssemblyTable,
          where: 'machineId = ?',
          whereArgs: [machine.id],
        );

        for (final subAssembly in machine.subAssemblies) {
          final subAssemblyId = await txn.insert(
            subAssemblyTable,
            subAssembly.copyWith(machineId: machine.id).toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );

          for (final task in subAssembly.maintenanceTasks) {
            await txn.insert(
              maintenanceTaskTable,
              task.copyWith(subAssemblyId: subAssemblyId).toMap()..remove('id'),
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
          }
        }
      }

      return changed;
    });
  }

  Future<int> _machinesUpdateMachineLastCheckDateImpl(
    int machineId,
    String lastCheckDate,
  ) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return db.update(
      machineTable,
      {'lastCheckDate': lastCheckDate},
      where: 'id = ?',
      whereArgs: [machineId],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> _machinesUpdateMachineDetailsWithHistoryImpl({
    required int machineId,
    required String operatingHours,
    required String idleHours,
    required String lastCheckDate,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return db.transaction((txn) async {
      final currentRows = await txn.query(
        machineTable,
        columns: ['operatingHours', 'idleHours', 'lastCheckDate'],
        where: 'id = ?',
        whereArgs: [machineId],
        limit: 1,
      );

      if (currentRows.isEmpty) {
        return 0;
      }

      final current = currentRows.first;
      final currentOperatingHours =
          (current['operatingHours'] as String?) ?? '';
      final currentIdleHours =
          (current['idleHours'] as String?) ??
          (current['idolHours'] as String?) ??
          '';
      final currentLastCheckDate = (current['lastCheckDate'] as String?) ?? '';

      final hasChanges =
          currentOperatingHours != operatingHours ||
          currentIdleHours != idleHours ||
          currentLastCheckDate != lastCheckDate;
      final lastCheckDateChanged = currentLastCheckDate != lastCheckDate;

      if (hasChanges) {
        await txn.insert(machineDetailHistoryTable, {
          'machineId': machineId,
          'operatingHours': currentOperatingHours,
          'idleHours': currentIdleHours,
          'lastCheckDate': currentLastCheckDate,
          'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.abort);
      }

      if (lastCheckDateChanged) {
        await txn.delete(
          workOrderStatusTable,
          where:
              'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
          whereArgs: [machineId],
        );
      }

      return txn.update(
        machineTable,
        {
          'operatingHours': operatingHours,
          'idleHours': idleHours,
          'lastCheckDate': lastCheckDate,
        },
        where: 'id = ?',
        whereArgs: [machineId],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<List<MachineDetailHistoryEntry>> _machinesGetMachineDetailHistoryImpl(
    int machineId, {
    int limit = 10,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    final rows = await db.query(
      machineDetailHistoryTable,
      where: 'machineId = ?',
      whereArgs: [machineId],
      orderBy: 'id DESC',
      limit: limit,
    );

    return rows
        .map((row) => MachineDetailHistoryEntry.fromMap(row))
        .toList(growable: false);
  }

  Future<int> _machinesUpdateSubAssemblyDetailsWithHistoryImpl({
    required int subAssemblyId,
    required String operatingHours,
    required String idleHours,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return db.transaction((txn) async {
      final currentRows = await txn.query(
        subAssemblyTable,
        columns: ['operatingHours', 'idleHours'],
        where: 'id = ?',
        whereArgs: [subAssemblyId],
        limit: 1,
      );

      if (currentRows.isEmpty) {
        return 0;
      }

      final current = currentRows.first;
      final currentOperatingHours =
          (current['operatingHours'] as String?) ?? '';
      final currentIdleHours =
          (current['idleHours'] as String?) ??
          (current['idolHours'] as String?) ??
          '';

      final hasChanges =
          currentOperatingHours != operatingHours ||
          currentIdleHours != idleHours;

      if (hasChanges) {
        await txn.insert(
          subAssemblyDetailHistoryTable,
          {
            'subAssemblyId': subAssemblyId,
            'operatingHours': currentOperatingHours,
            'idleHours': currentIdleHours,
            'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }

      return txn.update(
        subAssemblyTable,
        {'operatingHours': operatingHours, 'idleHours': idleHours},
        where: 'id = ?',
        whereArgs: [subAssemblyId],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<List<SubAssemblyDetailHistoryEntry>>
  _machinesGetSubAssemblyDetailHistoryImpl(
    int subAssemblyId, {
    int limit = 10,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    final rows = await db.query(
      subAssemblyDetailHistoryTable,
      where: 'subAssemblyId = ?',
      whereArgs: [subAssemblyId],
      orderBy: 'id DESC',
      limit: limit,
    );

    return rows
        .map((row) => SubAssemblyDetailHistoryEntry.fromMap(row))
        .toList(growable: false);
  }

  Future<int> _machinesDeleteMachineImpl(int id) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        machineDetailHistoryTable,
        where: 'machineId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        workOrderStatusTable,
        where:
            'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        workOrderTaskAssignmentTable,
        where:
            'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        workOrderTaskOutcomeTable,
        where:
            'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        subAssemblyDetailHistoryTable,
        where:
            'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        maintenanceTaskTable,
        where:
            'subAssemblyId IN (SELECT id FROM $subAssemblyTable WHERE machineId = ?)',
        whereArgs: [id],
      );
      await txn.delete(
        machineRequiredLicenseTable,
        where: 'machineId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        subAssemblyTable,
        where: 'machineId = ?',
        whereArgs: [id],
      );
      return txn.delete(machineTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<bool> _machinesHasMachineDocumentNumberImpl(
    String documentNumber, {
    int? excludeMachineId,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return dbHasMachineDocumentNumber(
      db,
      documentNumber,
      excludeMachineId: excludeMachineId,
    );
  }

  Future<bool> _machinesHasSubAssemblyDocumentNumberImpl(
    String documentNumber, {
    int? excludeMachineId,
  }) async {
    // Web check removed: DB always enabled on supported platforms
    final db = await database;
    return dbHasSubAssemblyDocumentNumber(
      db,
      documentNumber,
      excludeMachineId: excludeMachineId,
    );
  }
}
