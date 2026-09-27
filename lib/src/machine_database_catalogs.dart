
part of 'package:schedular/main.dart';

extension _MachineDatabaseCatalogsExtension on MachineDatabase {
  Future<List<String>> _catalogGetComponentTypesImpl() async {
    final db = await database;
    final rows = await db.query(
      componentTypeTable,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _catalogEnsureDefaultComponentTypesImpl(List<String> defaults) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final candidate in defaults) {
        final normalized = candidate.trim();
        if (normalized.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          componentTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(componentTypeTable, {
          'name': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<String?> _catalogAddComponentTypeImpl(String componentType) async {
    final normalized = componentType.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        componentTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [normalized.toUpperCase()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return (existing.first['name'] as String?)?.trim() ?? normalized;
      }

      await txn.insert(componentTypeTable, {
        'name': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return normalized;
    });
  }

  Future<List<String>> _catalogGetSuperCategoryTypesImpl() async {
    final db = await database;
    final rows = await db.query(
      superCategoryTypeTable,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _catalogEnsureDefaultSuperCategoryTypesImpl(List<String> defaults) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final candidate in defaults) {
        final normalized = candidate.trim();
        if (normalized.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          superCategoryTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(superCategoryTypeTable, {
          'name': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<String?> _catalogAddSuperCategoryTypeImpl(String superCategory) async {
    final normalized = superCategory.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        superCategoryTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [normalized.toUpperCase()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return (existing.first['name'] as String?)?.trim() ?? normalized;
      }

      await txn.insert(superCategoryTypeTable, {
        'name': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return normalized;
    });
  }

  Future<int> _catalogUpdateSubAssemblySuperCategoryImpl({
    required int subAssemblyId,
    required String superCategory,
  }) async {
    final normalized = superCategory.trim();
    final db = await database;
    return db.transaction((txn) async {
      if (normalized.isNotEmpty) {
        final existing = await txn.query(
          superCategoryTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(superCategoryTypeTable, {
            'name': normalized,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      return txn.update(
        subAssemblyTable,
        {'superCategory': normalized},
        where: 'id = ?',
        whereArgs: [subAssemblyId],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<int> _catalogGetSubAssemblySuperCategoryUsageCountImpl(
    String superCategory,
  ) async {
    final normalized = superCategory.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $subAssemblyTable WHERE UPPER(superCategory) = ?',
      [normalized.toUpperCase()],
    );
    return (rows.firstOrNull?['cnt'] as int?) ?? 0;
  }

  Future<int> _catalogDeleteSuperCategoryTypeImpl(String superCategory) async {
    final normalized = superCategory.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.delete(
      superCategoryTypeTable,
      where: 'UPPER(name) = ?',
      whereArgs: [normalized.toUpperCase()],
    );
  }

  Future<void> _catalogSyncSuperCategoryTypesFromSubAssembliesImpl() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT TRIM(superCategory) AS name FROM $subAssemblyTable WHERE TRIM(superCategory) != ''",
    );

    await db.transaction((txn) async {
      for (final row in rows) {
        final candidate = (row['name'] as String?)?.trim() ?? '';
        if (candidate.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          superCategoryTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [candidate.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(superCategoryTypeTable, {
          'name': candidate,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<String>> _catalogGetMaintenanceTaskTypesImpl() async {
    final db = await database;
    final rows = await db.query(
      maintenanceTaskTypeTable,
      columns: ['name'],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map((row) => (row['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _catalogEnsureDefaultMaintenanceTaskTypesImpl(
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
          maintenanceTaskTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(maintenanceTaskTypeTable, {
          'name': normalized,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<String?> _catalogAddMaintenanceTaskTypeImpl(String taskType) async {
    final normalized = taskType.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final db = await database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        maintenanceTaskTypeTable,
        columns: ['name'],
        where: 'UPPER(name) = ?',
        whereArgs: [normalized.toUpperCase()],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        return (existing.first['name'] as String?)?.trim() ?? normalized;
      }

      await txn.insert(maintenanceTaskTypeTable, {
        'name': normalized,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return normalized;
    });
  }

  Future<int> _catalogGetMaintenanceTaskTypeUsageCountImpl(String taskType) async {
    final normalized = taskType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $maintenanceTaskTable WHERE UPPER(taskType) = ?',
      [normalized.toUpperCase()],
    );
    return (rows.firstOrNull?['cnt'] as int?) ?? 0;
  }

  Future<int> _catalogDeleteMaintenanceTaskTypeImpl(String taskType) async {
    final normalized = taskType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.delete(
      maintenanceTaskTypeTable,
      where: 'UPPER(name) = ?',
      whereArgs: [normalized.toUpperCase()],
    );
  }

  Future<void> _catalogSyncMaintenanceTaskTypesFromTasksImpl() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT TRIM(taskType) AS name FROM $maintenanceTaskTable WHERE TRIM(taskType) != ''",
    );

    await db.transaction((txn) async {
      for (final row in rows) {
        final candidate = (row['name'] as String?)?.trim() ?? '';
        if (candidate.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          maintenanceTaskTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [candidate.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(maintenanceTaskTypeTable, {
          'name': candidate,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<int> _catalogUpdateSubAssemblyComponentTypeImpl({
    required int subAssemblyId,
    required String componentType,
  }) async {
    final normalized = componentType.trim();
    final db = await database;
    return db.transaction((txn) async {
      if (normalized.isNotEmpty) {
        final existing = await txn.query(
          componentTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [normalized.toUpperCase()],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert(componentTypeTable, {
            'name': normalized,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }

      return txn.update(
        subAssemblyTable,
        {'componentType': normalized},
        where: 'id = ?',
        whereArgs: [subAssemblyId],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    });
  }

  Future<int> _catalogGetSubAssemblyComponentTypeUsageCountImpl(
    String componentType,
  ) async {
    final normalized = componentType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM $subAssemblyTable WHERE UPPER(componentType) = ?',
      [normalized.toUpperCase()],
    );
    return (rows.firstOrNull?['cnt'] as int?) ?? 0;
  }

  Future<int> _catalogDeleteComponentTypeImpl(String componentType) async {
    final normalized = componentType.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    final db = await database;
    return db.delete(
      componentTypeTable,
      where: 'UPPER(name) = ?',
      whereArgs: [normalized.toUpperCase()],
    );
  }

  Future<void> _catalogSyncComponentTypesFromSubAssembliesImpl() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT DISTINCT TRIM(componentType) AS name FROM $subAssemblyTable WHERE TRIM(componentType) != ''",
    );

    await db.transaction((txn) async {
      for (final row in rows) {
        final candidate = (row['name'] as String?)?.trim() ?? '';
        if (candidate.isEmpty) {
          continue;
        }

        final existing = await txn.query(
          componentTypeTable,
          columns: ['id'],
          where: 'UPPER(name) = ?',
          whereArgs: [candidate.toUpperCase()],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }

        await txn.insert(componentTypeTable, {
          'name': candidate,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }
}
