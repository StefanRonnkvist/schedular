part of 'package:schedular/main.dart';

extension _MachineDatabaseEmployeesExtension on MachineDatabase {
  /// Loads employees and attaches their skills and licenses in two batched
  /// relationship queries, avoiding a query for every employee.
  /// Malformed employee rows are logged and omitted from the result.
  Future<List<Employee>> _employeesGetEmployeesImpl() async {
    final db = await database;
    final employeeRows = await db.query(
      employeeTable,
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    if (employeeRows.isEmpty) {
      return const [];
    }

    final employeeIds = employeeRows
        .map((row) => row['id'])
        .whereType<int>()
        .toList(growable: false);
    final placeholders = List.filled(employeeIds.length, '?').join(', ');
    final skillRows = await db.rawQuery(
      'SELECT employeeId, skillName FROM $employeeSkillTable WHERE employeeId IN ($placeholders) ORDER BY skillName COLLATE NOCASE ASC',
      employeeIds,
    );
    final licenseRows = await db.rawQuery(
      'SELECT employeeId, licenseName FROM $employeeRequiredLicenseTable WHERE employeeId IN ($placeholders) ORDER BY licenseName COLLATE NOCASE ASC',
      employeeIds,
    );

    final groupedSkills = <int, List<String>>{};
    for (final row in skillRows) {
      final employeeId = row['employeeId'] as int?;
      final skillName = (row['skillName'] as String?)?.trim() ?? '';
      if (employeeId == null || skillName.isEmpty) {
        continue;
      }
      groupedSkills.putIfAbsent(employeeId, () => []).add(skillName);
    }

    final groupedLicenses = <int, List<String>>{};
    for (final row in licenseRows) {
      final employeeId = row['employeeId'] as int?;
      final licenseName = (row['licenseName'] as String?)?.trim() ?? '';
      if (employeeId == null || licenseName.isEmpty) {
        continue;
      }
      groupedLicenses.putIfAbsent(employeeId, () => []).add(licenseName);
    }

    return employeeRows
        .map((row) {
          try {
            final employee = Employee.fromMap(row);
            return employee.copyWith(
              skills: groupedSkills[employee.id] ?? const [],
              licenses: groupedLicenses[employee.id] ?? const [],
            );
          } catch (error) {
            debugPrint('Skipping malformed employee row: $error');
            return null;
          }
        })
        .whereType<Employee>()
        .toList(growable: false);
  }

  Future<List<String>> _employeesGetSkillTypesImpl() async {
    final db = await database;
    final rows = await db.query(
      skillTypeTable,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  /// Inserts missing defaults without changing existing spelling or casing.
  Future<void> _employeesEnsureDefaultSkillTypesImpl(
    List<String> defaults,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final candidate in defaults) {
        final normalized = candidate.trim();
        if (normalized.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          skillTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(skillTypeTable, {
          'name': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<String?> _employeesAddSkillTypeImpl(String skillType) async {
    final normalized = skillType.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        skillTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [normalized.toUpperCase()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return (existing.first['name'] as String?)?.trim() ?? normalized;
      }

      await txn.insert(skillTypeTable, {
        'name': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return normalized;
    });
  }

  /// Renames or merges a skill type and rewrites every employee assignment in
  /// the same transaction. Matching is case-insensitive.
  Future<String?> _employeesRenameSkillTypeImpl(
    String oldName,
    String newName,
  ) async {
    final oldNormalized = oldName.trim();
    final newNormalized = newName.trim();
    if (oldNormalized.isEmpty || newNormalized.isEmpty) {
      return null;
    }

    final oldUpper = oldNormalized.toUpperCase();
    final newUpper = newNormalized.toUpperCase();

    final db = await database;
    return db.transaction((txn) async {
      final existingOldType = await txn.query(
        skillTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [oldUpper],
        limit: 1,
      );
      final existingNewType = await txn.query(
        skillTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [newUpper],
        limit: 1,
      );

      final canonicalNewName = existingNewType.isNotEmpty
          ? ((existingNewType.first['name'] as String?)?.trim() ??
                newNormalized)
          : newNormalized;

      final oldEmployeeRows = await txn.query(
        employeeSkillTable,
        columns: ['employeeId'],
        where: 'UPPER(skillName) = ?',
        whereArgs: [oldUpper],
      );

      for (final row in oldEmployeeRows) {
        final employeeId = row['employeeId'] as int?;
        if (employeeId == null) {
          continue;
        }

        await txn.insert(employeeSkillTable, {
          'employeeId': employeeId,
          'skillName': canonicalNewName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.delete(
        employeeSkillTable,
        where: 'UPPER(skillName) = ?',
        whereArgs: [oldUpper],
      );

      if (existingOldType.isNotEmpty) {
        if (existingNewType.isEmpty) {
          await txn.update(
            skillTypeTable,
            {'name': canonicalNewName},
            where: 'UPPER(name) = ?',
            whereArgs: [oldUpper],
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else {
          await txn.delete(
            skillTypeTable,
            where: 'UPPER(name) = ?',
            whereArgs: [oldUpper],
          );
        }
      } else if (existingNewType.isEmpty) {
        await txn.insert(skillTypeTable, {
          'name': canonicalNewName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      return canonicalNewName;
    });
  }

  Future<int> _employeesGetEmployeeSkillUsageCountImpl(String skillType) async {
    final normalized = skillType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT employeeId) AS cnt FROM $employeeSkillTable WHERE UPPER(skillName) = ?',
      [normalized.toUpperCase()],
    );
    return (rows.firstOrNull?['cnt'] as int?) ?? 0;
  }

  Future<int> _employeesDeleteSkillTypeImpl(String skillType) async {
    final normalized = skillType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final upper = normalized.toUpperCase();
    final db = await database;
    return db.transaction((txn) async {
      final removedMappings = await txn.delete(
        employeeSkillTable,
        where: 'UPPER(skillName) = ?',
        whereArgs: [upper],
      );
      await txn.delete(
        skillTypeTable,
        where: 'UPPER(name) = ?',
        whereArgs: [upper],
      );
      return removedMappings;
    });
  }

  Future<List<String>> _employeesGetLicenseTypesImpl() async {
    final db = await database;
    final rows = await db.query(
      licenseTypeTable,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _employeesEnsureDefaultLicenseTypesImpl(
    List<String> defaults,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final candidate in defaults) {
        final normalized = candidate.trim();
        if (normalized.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          licenseTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(licenseTypeTable, {
          'name': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<String?> _employeesAddLicenseTypeImpl(String licenseType) async {
    final normalized = licenseType.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        licenseTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [normalized.toUpperCase()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return (existing.first['name'] as String?)?.trim() ?? normalized;
      }

      await txn.insert(licenseTypeTable, {
        'name': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return normalized;
    });
  }

  Future<int> _employeesGetMachineRequiredLicenseUsageCountImpl(
    String licenseType,
  ) async {
    final normalized = licenseType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(DISTINCT machineId) AS cnt FROM $machineRequiredLicenseTable WHERE UPPER(licenseName) = ?',
      [normalized.toUpperCase()],
    );
    return (rows.firstOrNull?['cnt'] as int?) ?? 0;
  }

  Future<String?> _employeesRenameLicenseTypeImpl(
    String oldName,
    String newName,
  ) async {
    final oldNormalized = oldName.trim();
    final newNormalized = newName.trim();
    if (oldNormalized.isEmpty || newNormalized.isEmpty) {
      return null;
    }

    final oldUpper = oldNormalized.toUpperCase();
    final newUpper = newNormalized.toUpperCase();

    final db = await database;
    return db.transaction((txn) async {
      final existingOldType = await txn.query(
        licenseTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [oldUpper],
        limit: 1,
      );
      final existingNewType = await txn.query(
        licenseTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [newUpper],
        limit: 1,
      );

      final canonicalNewName = existingNewType.isNotEmpty
          ? ((existingNewType.first['name'] as String?)?.trim() ??
                newNormalized)
          : newNormalized;

      final oldMachineRows = await txn.query(
        machineRequiredLicenseTable,
        columns: ['machineId'],
        where: 'UPPER(licenseName) = ?',
        whereArgs: [oldUpper],
      );

      for (final row in oldMachineRows) {
        final machineId = row['machineId'] as int?;
        if (machineId == null) {
          continue;
        }

        await txn.insert(machineRequiredLicenseTable, {
          'machineId': machineId,
          'licenseName': canonicalNewName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.delete(
        machineRequiredLicenseTable,
        where: 'UPPER(licenseName) = ?',
        whereArgs: [oldUpper],
      );

      if (existingOldType.isNotEmpty) {
        if (existingNewType.isEmpty) {
          await txn.update(
            licenseTypeTable,
            {'name': canonicalNewName},
            where: 'UPPER(name) = ?',
            whereArgs: [oldUpper],
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        } else {
          await txn.delete(
            licenseTypeTable,
            where: 'UPPER(name) = ?',
            whereArgs: [oldUpper],
          );
        }
      } else if (existingNewType.isEmpty) {
        await txn.insert(licenseTypeTable, {
          'name': canonicalNewName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      return canonicalNewName;
    });
  }

  Future<int> _employeesDeleteLicenseTypeImpl(String licenseType) async {
    final normalized = licenseType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final upper = normalized.toUpperCase();
    final db = await database;
    return db.transaction((txn) async {
      final removedMappings = await txn.delete(
        machineRequiredLicenseTable,
        where: 'UPPER(licenseName) = ?',
        whereArgs: [upper],
      );
      await txn.delete(
        licenseTypeTable,
        where: 'UPPER(name) = ?',
        whereArgs: [upper],
      );
      return removedMappings;
    });
  }

  Future<Employee> _employeesInsertEmployeeImpl(Employee employee) async {
    final db = await database;
    return db.transaction((txn) async {
      final employeeId = await txn.insert(
        employeeTable,
        employee.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await _replaceEmployeeSkills(txn, employeeId, employee.skills);
      await _replaceEmployeeRequiredLicenses(
        txn,
        employeeId,
        employee.licenses,
      );
      return employee.copyWith(id: employeeId);
    });
  }

  Future<void> _employeesInsertEmployeesImpl(List<Employee> employees) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final employee in employees) {
        final employeeId = await txn.insert(
          employeeTable,
          employee.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await _replaceEmployeeSkills(txn, employeeId, employee.skills);
        await _replaceEmployeeRequiredLicenses(
          txn,
          employeeId,
          employee.licenses,
        );
      }
    });
  }

  Future<void> _employeesReplaceAllEmployeesImpl(
    List<Employee> employees,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(employeeRequiredLicenseTable);
      await txn.delete(employeeSkillTable);
      await txn.delete(employeeTable);

      for (final employee in employees) {
        final employeeId = await txn.insert(
          employeeTable,
          employee.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        await _replaceEmployeeSkills(txn, employeeId, employee.skills);
        await _replaceEmployeeRequiredLicenses(
          txn,
          employeeId,
          employee.licenses,
        );
      }
    });
  }

  Future<int> _employeesUpdateEmployeeImpl(Employee employee) async {
    final db = await database;
    return db.transaction((txn) async {
      final changed = await txn.update(
        employeeTable,
        employee.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [employee.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      if (employee.id != null) {
        await _replaceEmployeeSkills(txn, employee.id!, employee.skills);
        await _replaceEmployeeRequiredLicenses(
          txn,
          employee.id!,
          employee.licenses,
        );
      }

      return changed;
    });
  }

  Future<int> _employeesDeleteEmployeeImpl(int id) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        employeeSkillTable,
        where: 'employeeId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        employeeRequiredLicenseTable,
        where: 'employeeId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        workOrderTaskAssignmentTable,
        where: 'assigneeValue LIKE ?',
        whereArgs: ['$id|%'],
      );
      return txn.delete(employeeTable, where: 'id = ?', whereArgs: [id]);
    });
  }
}
