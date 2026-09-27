part of 'package:schedular/main.dart';

/// Exports the complete machine, employee, and contractor graph as JSON.
/// Database IDs are intentionally omitted so the result can be imported into
/// another database without carrying primary-key relationships across.
Future<String> _backupExportDatabaseJsonImpl() async {
  final db = MachineDatabase.instance;
  final machines = await db.getMachines();
  final employees = await db.getEmployees();
  final contractorCompanies = await db.getContractorCompanies();

  final contractorsJson = <Map<String, Object?>>[];
  for (final company in contractorCompanies) {
    final companyId = company.id;
    final employeesForCompany = companyId == null
        ? const <ContractorEmployeeContact>[]
        : await db.getContractorEmployees(companyId);
    contractorsJson.add({
      'company': company.toMap()..remove('id'),
      'employees': employeesForCompany
          .map((employee) => employee.toMap()..remove('id'))
          .toList(growable: false),
    });
  }

  final payload = <String, Object?>{
    'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'machines': machines
        .map((machine) => db._machineToBackupMap(machine))
        .toList(growable: false),
    'employees': employees
        .map((employee) => db._employeeToBackupMap(employee))
        .toList(growable: false),
    'contractors': contractorsJson,
  };

  return jsonEncode(payload);
}

Future<String?> _backupExportMachineTemplateToCsvImpl() async {
  final db = MachineDatabase.instance;
  return db._generateCsv(<List<String>>[
    db._machineCsvHeaders(),
    db._machineCsvSampleRow(),
  ]);
}

// Table name constants
const String machineTable = 'machines';
const String subAssemblyTable = 'sub_assemblies';
const String maintenanceTaskTable = 'maintenance_tasks';
const String machineRequiredLicenseTable = 'machine_required_licenses';
const String employeeSkillTable = 'employee_skills';
const String skillTypeTable = 'skill_types';
const String licenseTypeTable = 'license_types';
const String employeeRequiredLicenseTable = 'employee_required_licenses';

/// Imports a JSON backup and returns the number of machines, employees, and
/// contractor companies imported.
///
/// When [clearExisting] is true, all supported entities are deleted before the
/// payload is validated and imported. Contractor employee contacts are not
/// included in the returned count.
Future<int> _backupImportDatabaseJsonImpl(
  String backupJson, {
  bool clearExisting = true,
}) async {
  final db = MachineDatabase.instance;
  final decoded = jsonDecode(backupJson);
  if (decoded is! Map) {
    throw const FormatException('Backup payload must be an object.');
  }

  final root = decoded.cast<Object?, Object?>();
  final machinesRaw = root['machines'];
  final employeesRaw = root['employees'];
  final contractorsRaw = root['contractors'];

  if (clearExisting) {
    await db.replaceAllMachines(const <Machine>[]);
    await db.replaceAllEmployees(const <Employee>[]);
    await db.deleteAllContractors();
  }

  var importedCount = 0;

  if (machinesRaw is List) {
    final machines = machinesRaw
        .map((row) => db._machineFromBackupMap(row))
        .toList(growable: false);
    if (machines.isNotEmpty) {
      await db.replaceAllMachines(machines);
      importedCount += machines.length;
    }
  }

  if (employeesRaw is List) {
    final employees = employeesRaw
        .map((row) => db._employeeFromBackupMap(row))
        .toList(growable: false);
    if (employees.isNotEmpty) {
      await db.replaceAllEmployees(employees);
      importedCount += employees.length;
    }
  }

  if (contractorsRaw is List) {
    for (final row in contractorsRaw) {
      if (row is! Map) {
        continue;
      }
      final map = row.cast<Object?, Object?>();
      final companyRaw = map['company'];
      if (companyRaw is! Map) {
        continue;
      }

      final companyMap = <String, Object?>{};
      for (final entry in companyRaw.entries) {
        final key = entry.key;
        if (key is String) {
          companyMap[key] = entry.value;
        }
      }
      final company = ContractorCompany.fromMap(companyMap);
      final savedCompany = await db.upsertContractorCompany(company);
      importedCount += 1;

      final employeesForCompanyRaw = map['employees'];
      if (employeesForCompanyRaw is! List) {
        continue;
      }

      for (final employeeRaw in employeesForCompanyRaw) {
        if (employeeRaw is! Map) {
          continue;
        }
        final employeeMap = <String, Object?>{};
        for (final entry in employeeRaw.entries) {
          final key = entry.key;
          if (key is String) {
            employeeMap[key] = entry.value;
          }
        }

        final contact = ContractorEmployeeContact.fromMap(
          employeeMap,
        ).copyWith(contractorCompanyId: savedCompany.id ?? 0);
        await db.upsertContractorEmployee(contact);
      }
    }
  }

  return importedCount;
}

Future<String?> _backupExportEmployeeTemplateToCsvImpl() async {
  final db = MachineDatabase.instance;
  return db._generateCsv(<List<String>>[
    db._employeeCsvHeaders(),
    db._employeeCsvSampleRow(),
  ]);
}

Future<String?> _backupExportContractorTemplateToCsvImpl() async {
  final db = MachineDatabase.instance;
  return db._generateCsv(<List<String>>[
    db._contractorCsvHeaders(),
    db._contractorCsvSampleRow(),
  ]);
}

class _DatabaseConnectionManager {
  static const String _dbName = 'schedular.db';
  static const Duration _databaseOpenTimeout = Duration(seconds: 8);
  static const Duration _databaseExistsTimeout = Duration(milliseconds: 1500);
  Database? _db;
  String? _dbFilePath;
  String? _databasePathOverrideForTesting;
  bool openedExistingDatabaseFile = false;

  /// Lazily opens the database. An open timeout triggers one destructive
  /// recovery attempt that deletes the database file before reopening it.
  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }

    final path = await _databasePath();
    openedExistingDatabaseFile = await _databaseExists(path);

    try {
      _db = await _openDatabaseWithTimeout(path);
    } on TimeoutException {
      // One best-effort recovery pass in case a stale lock/corrupt file is
      // preventing startup from ever completing.
      try {
        await databaseFactory
            .deleteDatabase(path)
            .timeout(
              _databaseOpenTimeout,
              onTimeout: () => throw TimeoutException(
                'Timed out while deleting local database during recovery. $path',
              ),
            );
        openedExistingDatabaseFile = false;
      } catch (_) {
        // If deletion fails, still attempt one final open below.
      }
      _db = await _openDatabaseWithTimeout(path);
    }

    return _db!;
  }

  Future<Database> _openDatabaseWithTimeout(String path) {
    return openRegistryDatabase(databaseFactory, path).timeout(
      _databaseOpenTimeout,
      onTimeout: () => throw TimeoutException(
        'Timed out while opening local database. $path',
      ),
    );
  }

  Future<bool> databaseFileExists() async {
    final path = await _databasePath();
    return _databaseExists(path);
  }

  Future<String> activeDatabasePath() async {
    return _databasePath();
  }

  Future<String> _databasePath() async {
    final overridePath = _databasePathOverrideForTesting;
    if (overridePath != null && overridePath.trim().isNotEmpty) {
      if (!kIsWeb) {
        await Directory(p.dirname(overridePath)).create(recursive: true);
      }
      _dbFilePath = overridePath;
      return overridePath;
    }

    if (_dbFilePath != null && _dbFilePath!.trim().isNotEmpty) {
      return _dbFilePath!;
    }

    final primaryPath = await _primaryDatabasePath();
    final primaryExists = await _databaseExists(primaryPath);
    if (primaryExists &&
        !await _shouldPreferLegacyDatabase(primaryPath: primaryPath)) {
      _dbFilePath = primaryPath;
      return _dbFilePath!;
    }

    for (final legacyPath in await _legacyDatabasePaths()) {
      if (p.equals(primaryPath, legacyPath)) {
        continue;
      }
      if (!await _databaseExists(legacyPath)) {
        continue;
      }

      await _promoteLegacyDatabaseFile(
        primaryPath: primaryPath,
        legacyPath: legacyPath,
      );
      _dbFilePath = primaryPath;
      return _dbFilePath!;
    }

    if (!kIsWeb) {
      await Directory(p.dirname(primaryPath)).create(recursive: true);
    }
    _dbFilePath = primaryPath;
    return _dbFilePath!;
  }

  Future<bool> _shouldPreferLegacyDatabase({
    required String primaryPath,
  }) async {
    final primaryLength = await _safeFileLength(primaryPath);
    if (primaryLength == null || primaryLength > 4096) {
      return false;
    }

    for (final legacyPath in await _legacyDatabasePaths()) {
      if (p.equals(primaryPath, legacyPath)) {
        continue;
      }

      final legacyLength = await _safeFileLength(legacyPath);
      if (legacyLength != null && legacyLength > primaryLength + 4096) {
        return true;
      }
    }

    return false;
  }

  Future<int?> _safeFileLength(String fullPath) async {
    try {
      final file = File(fullPath);
      if (!await file.exists()) {
        return null;
      }
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  Future<String> _primaryDatabasePath() async {
    if (kIsWeb) {
      return _dbName;
    }

    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null && localAppData.trim().isNotEmpty) {
        return p.join(
          localAppData,
          'maintenanceschedular',
          'databases',
          _dbName,
        );
      }
    }

    final basePath = await getDatabasesPath();
    return p.join(basePath, _dbName);
  }

  Future<List<String>> _legacyDatabasePaths() async {
    if (kIsWeb) {
      return [_dbName];
    }

    final candidates = <String>[];

    try {
      final basePath = await getDatabasesPath();
      if (basePath.trim().isNotEmpty) {
        candidates.add(p.join(basePath, _dbName));
      }
    } catch (_) {
      // Fall through to other candidates.
    }

    final currentDirectory = Directory.current.path;
    if (currentDirectory.trim().isNotEmpty) {
      candidates.add(p.join(currentDirectory, 'databases', _dbName));
      candidates.add(
        p.join(
          currentDirectory,
          '.dart_tool',
          'sqflite_common_ffi',
          'databases',
          _dbName,
        ),
      );
    }

    final seen = <String>{};
    return candidates.where((candidate) => seen.add(candidate)).toList();
  }

  Future<bool> _databaseExists(String fullPath) async {
    try {
      if (await File(
        fullPath,
      ).exists().timeout(_databaseExistsTimeout, onTimeout: () => false)) {
        return true;
      }
    } catch (_) {
      // Fall back to the database factory check below.
    }

    try {
      return await databaseFactory
          .databaseExists(fullPath)
          .timeout(_databaseExistsTimeout, onTimeout: () => false);
    } catch (_) {
      return false;
    }
  }

  Future<void> _promoteLegacyDatabaseFile({
    required String primaryPath,
    required String legacyPath,
  }) async {
    if (p.equals(primaryPath, legacyPath)) {
      return;
    }

    await Directory(p.dirname(primaryPath)).create(recursive: true);

    const sqliteFileSuffixes = <String>['', '-wal', '-shm', '-journal'];
    for (final suffix in sqliteFileSuffixes) {
      final sourcePath = '$legacyPath$suffix';
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        continue;
      }

      final destinationPath = '$primaryPath$suffix';
      final destinationFile = File(destinationPath);
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }
      await sourceFile.copy(destinationPath);
    }
  }

  Future<void> deleteEntireDatabaseFile() async {
    final path = await _databasePath();
    final existingDb = _db;
    if (existingDb != null) {
      await existingDb.close();
      _db = null;
    }

    await databaseFactory.deleteDatabase(path);
    openedExistingDatabaseFile = false;
  }

  /// Closes and deletes the active database, then opens a newly initialized
  /// database at the same path. Callers must treat this as data-destructive.
  Future<void> attemptDatabaseRecovery() async {
    final path = await _databasePath();
    try {
      final existingDb = _db;
      if (existingDb != null) {
        await existingDb.close().timeout(
          _databaseOpenTimeout,
          onTimeout: () => throw TimeoutException(
            'Timed out while closing database during recovery. $path',
          ),
        );
        _db = null;
      }
      await databaseFactory
          .deleteDatabase(path)
          .timeout(
            _databaseOpenTimeout,
            onTimeout: () => throw TimeoutException(
              'Timed out while deleting database during recovery. $path',
            ),
          );
    } catch (_) {
      // If the file cannot be deleted, still try reopening and migrating.
    }

    openedExistingDatabaseFile = false;
    _db = await _openDatabaseWithTimeout(path);
  }

  Future<void> reconnectDatabase() async {
    final path = await _databasePath();
    final existingDb = _db;
    if (existingDb != null) {
      try {
        await existingDb.close().timeout(
          _databaseOpenTimeout,
          onTimeout: () => throw TimeoutException(
            'Timed out while closing database during reconnect. $path',
          ),
        );
      } catch (_) {
        // Best-effort close before reopening.
      }
      _db = null;
    }

    openedExistingDatabaseFile = await _databaseExists(path);
    _db = await _openDatabaseWithTimeout(path);
  }

  Future<void> _closeOpenDatabase() async {
    final existingDb = _db;
    if (existingDb == null) {
      return;
    }
    try {
      await existingDb.close();
    } catch (_) {
      // Best effort close for tests.
    }
    _db = null;
  }

  Future<void> setDatabasePathOverrideForTesting(String? path) async {
    await _closeOpenDatabase();
    final normalized = path?.trim();
    _databasePathOverrideForTesting = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    _dbFilePath = null;
    openedExistingDatabaseFile = false;
  }

  Future<void> resetConnectionForTesting() async {
    await _closeOpenDatabase();
    _dbFilePath = null;
    openedExistingDatabaseFile = false;
  }
}

class MachineDatabase {
  MachineDatabase._();

  static final MachineDatabase instance = MachineDatabase._();

  final _connectionManager = _DatabaseConnectionManager();

  bool get openedExistingDatabaseFile =>
      _connectionManager.openedExistingDatabaseFile;

  Future<Database> get database => _connectionManager.database;

  Future<bool> databaseFileExists() => _connectionManager.databaseFileExists();

  Future<String> activeDatabasePath() =>
      _connectionManager.activeDatabasePath();

  Future<Map<String, String>> getDatabaseHealthCheck() async {
    final db = await database;
    const requiredTables = <String>[
      machineTable,
      subAssemblyTable,
      maintenanceTaskTable,
      employeeTable,
      employeeSkillTable,
      employeeRequiredLicenseTable,
      contractorCompanyTable,
      contractorEmployeeTable,
      workOrderStatusTable,
      workOrderTaskAssignmentTable,
      workOrderTaskOutcomeTable,
    ];

    final missingTables = <String>[];
    for (final tableName in requiredTables) {
      final exists = await hasTable(db, tableName);
      if (!exists) {
        missingTables.add(tableName);
      }
    }

    return <String, String>{
      'Health Status': missingTables.isEmpty ? 'OK' : 'Issues Detected',
      'Missing Tables': missingTables.isEmpty
          ? 'None'
          : missingTables.join(', '),
    };
  }

  Future<List<Employee>> getEmployees() async {
    return _employeesGetEmployeesImpl();
  }

  Future<List<String>> getSkillTypes() async {
    return _employeesGetSkillTypesImpl();
  }

  Future<void> ensureDefaultSkillTypes(List<String> defaults) async {
    await _employeesEnsureDefaultSkillTypesImpl(defaults);
  }

  Future<String?> addSkillType(String skillType) async {
    return _employeesAddSkillTypeImpl(skillType);
  }

  Future<String?> renameSkillType(String oldName, String newName) async {
    return _employeesRenameSkillTypeImpl(oldName, newName);
  }

  Future<int> getEmployeeSkillUsageCount(String skillName) async {
    return _employeesGetEmployeeSkillUsageCountImpl(skillName);
  }

  Future<int> deleteSkillType(String skillType) async {
    return _employeesDeleteSkillTypeImpl(skillType);
  }

  Future<List<String>> getLicenseTypes() async {
    return _employeesGetLicenseTypesImpl();
  }

  Future<void> ensureDefaultLicenseTypes(List<String> defaults) async {
    await _employeesEnsureDefaultLicenseTypesImpl(defaults);
  }

  Future<String?> addLicenseType(String licenseType) async {
    return _employeesAddLicenseTypeImpl(licenseType);
  }

  Future<int> getMachineRequiredLicenseUsageCount(String licenseType) async {
    return _employeesGetMachineRequiredLicenseUsageCountImpl(licenseType);
  }

  Future<String?> renameLicenseType(String oldName, String newName) async {
    return _employeesRenameLicenseTypeImpl(oldName, newName);
  }

  Future<int> deleteLicenseType(String licenseType) async {
    return _employeesDeleteLicenseTypeImpl(licenseType);
  }

  Future<List<Machine>> getMachines() async {
    final db = await database;
    final machineRows = await db.query(machineTable, orderBy: 'id DESC');
    if (machineRows.isEmpty) {
      return [];
    }

    final machineIds = machineRows
        .map((row) => row['id'])
        .whereType<int>()
        .toList(growable: false);
    final placeholders = List.filled(machineIds.length, '?').join(', ');
    final machineLicenseRows = await db.rawQuery(
      'SELECT machineId, licenseName FROM $machineRequiredLicenseTable WHERE machineId IN ($placeholders) ORDER BY licenseName COLLATE NOCASE ASC',
      machineIds,
    );

    final groupedMachineLicenses = <int, List<String>>{};
    for (final row in machineLicenseRows) {
      final machineId = row['machineId'] as int?;
      final licenseName = (row['licenseName'] as String?)?.trim() ?? '';
      if (machineId == null || licenseName.isEmpty) {
        continue;
      }

      groupedMachineLicenses.putIfAbsent(machineId, () => []).add(licenseName);
    }

    final subAssemblyRows = await db.rawQuery(
      'SELECT * FROM $subAssemblyTable WHERE machineId IN ($placeholders) ORDER BY id ASC',
      machineIds,
    );

    final subAssemblyIds = subAssemblyRows
        .map((row) => row['id'])
        .whereType<int>()
        .toList(growable: false);
    final groupedTasks = <int, List<MaintenanceTask>>{};

    if (subAssemblyIds.isNotEmpty) {
      final taskPlaceholders = List.filled(
        subAssemblyIds.length,
        '?',
      ).join(', ');
      final taskRows = await db.rawQuery(
        'SELECT * FROM $maintenanceTaskTable WHERE subAssemblyId IN ($taskPlaceholders) ORDER BY id ASC',
        subAssemblyIds,
      );

      for (final row in taskRows) {
        try {
          final task = MaintenanceTask.fromMap(row);
          final subAssemblyId = task.subAssemblyId;
          if (subAssemblyId == null) {
            continue;
          }

          groupedTasks.putIfAbsent(subAssemblyId, () => []).add(task);
        } catch (error) {
          debugPrint('Skipping malformed maintenance task row: $error');
        }
      }
    }

    final groupedSubAssemblies = <int, List<SubAssembly>>{};
    for (final row in subAssemblyRows) {
      try {
        final subAssemblyBase = SubAssembly.fromMap(row);
        final subAssembly = subAssemblyBase.copyWith(
          maintenanceTasks: groupedTasks[subAssemblyBase.id] ?? const [],
        );
        final machineId = subAssembly.machineId;
        if (machineId == null) {
          continue;
        }

        groupedSubAssemblies.putIfAbsent(machineId, () => []).add(subAssembly);
      } catch (error) {
        debugPrint('Skipping malformed sub-assembly row: $error');
      }
    }

    return machineRows
        .map((row) {
          try {
            final machine = Machine.fromMap(row);
            return machine.copyWith(
              additionalRequiredLicenses:
                  groupedMachineLicenses[machine.id] ?? const [],
              subAssemblies: groupedSubAssemblies[machine.id] ?? const [],
            );
          } catch (error) {
            debugPrint('Skipping malformed machine row: $error');
            return null;
          }
        })
        .whereType<Machine>()
        .toList(growable: false);
  }

  Future<void> _replaceMachineRequiredLicenses(
    Transaction txn,
    int machineId,
    Iterable<String> licenseNames,
  ) async {
    await txn.delete(
      machineRequiredLicenseTable,
      where: 'machineId = ?',
      whereArgs: [machineId],
    );

    final uniqueNames = <String>{
      for (final name in licenseNames)
        if (name.trim().isNotEmpty) name.trim(),
    };

    for (final licenseName in uniqueNames) {
      final existingType = await txn.query(
        licenseTypeTable,
        columns: ['id'],
        where: 'UPPER(name) = ?',
        whereArgs: [licenseName.toUpperCase()],
        limit: 1,
      );
      if (existingType.isEmpty) {
        await txn.insert(licenseTypeTable, {
          'name': licenseName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.insert(machineRequiredLicenseTable, {
        'machineId': machineId,
        'licenseName': licenseName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _replaceEmployeeSkills(
    Transaction txn,
    int employeeId,
    Iterable<String> skills,
  ) async {
    await txn.delete(
      employeeSkillTable,
      where: 'employeeId = ?',
      whereArgs: [employeeId],
    );

    final uniqueSkills = <String>{
      for (final skill in skills)
        if (skill.trim().isNotEmpty) skill.trim(),
    };

    for (final skillName in uniqueSkills) {
      final existingType = await txn.query(
        skillTypeTable,
        columns: ['id'],
        where: 'UPPER(name) = ?',
        whereArgs: [skillName.toUpperCase()],
        limit: 1,
      );
      if (existingType.isEmpty) {
        await txn.insert(skillTypeTable, {
          'name': skillName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.insert(employeeSkillTable, {
        'employeeId': employeeId,
        'skillName': skillName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _replaceEmployeeRequiredLicenses(
    Transaction txn,
    int employeeId,
    Iterable<String> licenseNames,
  ) async {
    await txn.delete(
      employeeRequiredLicenseTable,
      where: 'employeeId = ?',
      whereArgs: [employeeId],
    );

    final uniqueNames = <String>{
      for (final name in licenseNames)
        if (name.trim().isNotEmpty) name.trim(),
    };

    for (final licenseName in uniqueNames) {
      final existingType = await txn.query(
        licenseTypeTable,
        columns: ['id'],
        where: 'UPPER(name) = ?',
        whereArgs: [licenseName.toUpperCase()],
        limit: 1,
      );
      if (existingType.isEmpty) {
        await txn.insert(licenseTypeTable, {
          'name': licenseName,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      await txn.insert(employeeRequiredLicenseTable, {
        'employeeId': employeeId,
        'licenseName': licenseName,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<Employee> insertEmployee(Employee employee) async {
    return _employeesInsertEmployeeImpl(employee);
  }

  Future<void> insertEmployees(List<Employee> employees) async {
    await _employeesInsertEmployeesImpl(employees);
  }

  Future<void> replaceAllEmployees(List<Employee> employees) async {
    await _employeesReplaceAllEmployeesImpl(employees);
  }

  Future<int> updateEmployee(Employee employee) async {
    return _employeesUpdateEmployeeImpl(employee);
  }

  Future<int> deleteEmployee(int id) async {
    return _employeesDeleteEmployeeImpl(id);
  }

  Future<void> _ensureContractorTablesReady(Database db) async {
    await ensureContractorCompanyTable(db);
    await ensureContractorEmployeeTable(db);
  }

  Future<List<ContractorCompany>> getContractorCompanies() async {
    return _vendersGetContractorCompaniesImpl();
  }

  Future<ContractorCompany> upsertContractorCompany(
    ContractorCompany company,
  ) async {
    return _vendersUpsertContractorCompanyImpl(company);
  }

  Future<int> deleteContractorCompany(int companyId) async {
    return _vendersDeleteContractorCompanyImpl(companyId);
  }

  Future<List<ContractorEmployeeContact>> getContractorEmployees(
    int companyId,
  ) async {
    return _vendersGetContractorEmployeesImpl(companyId);
  }

  Future<ContractorEmployeeContact> upsertContractorEmployee(
    ContractorEmployeeContact contact,
  ) async {
    return _vendersUpsertContractorEmployeeImpl(contact);
  }

  Future<int> deleteContractorEmployee(int id) async {
    return _vendersDeleteContractorEmployeeImpl(id);
  }

  Future<void> deleteAllContractors() async {
    await _vendersDeleteAllContractorsImpl();
  }

  Future<List<String>> getComponentTypes() async {
    return _catalogGetComponentTypesImpl();
  }

  Future<void> ensureDefaultComponentTypes(List<String> defaults) async {
    await _catalogEnsureDefaultComponentTypesImpl(defaults);
  }

  Future<String?> addComponentType(String componentType) async {
    return _catalogAddComponentTypeImpl(componentType);
  }

  Future<List<String>> getSuperCategoryTypes() async {
    return _catalogGetSuperCategoryTypesImpl();
  }

  Future<void> ensureDefaultSuperCategoryTypes(List<String> defaults) async {
    await _catalogEnsureDefaultSuperCategoryTypesImpl(defaults);
  }

  Future<String?> addSuperCategoryType(String superCategory) async {
    return _catalogAddSuperCategoryTypeImpl(superCategory);
  }

  Future<int> updateSubAssemblySuperCategory({
    required int subAssemblyId,
    required String superCategory,
  }) async {
    return _catalogUpdateSubAssemblySuperCategoryImpl(
      subAssemblyId: subAssemblyId,
      superCategory: superCategory,
    );
  }

  Future<int> getSubAssemblySuperCategoryUsageCount(
    String superCategory,
  ) async {
    return _catalogGetSubAssemblySuperCategoryUsageCountImpl(superCategory);
  }

  Future<int> deleteSuperCategoryType(String superCategory) async {
    return _catalogDeleteSuperCategoryTypeImpl(superCategory);
  }

  Future<void> syncSuperCategoryTypesFromSubAssemblies() async {
    await _catalogSyncSuperCategoryTypesFromSubAssembliesImpl();
  }

  Future<List<String>> getMaintenanceTaskTypes() async {
    return _catalogGetMaintenanceTaskTypesImpl();
  }

  Future<void> ensureDefaultMaintenanceTaskTypes(List<String> defaults) async {
    await _catalogEnsureDefaultMaintenanceTaskTypesImpl(defaults);
  }

  Future<String?> addMaintenanceTaskType(String taskType) async {
    return _catalogAddMaintenanceTaskTypeImpl(taskType);
  }

  Future<int> getMaintenanceTaskTypeUsageCount(String taskType) async {
    return _catalogGetMaintenanceTaskTypeUsageCountImpl(taskType);
  }

  Future<int> deleteMaintenanceTaskType(String taskType) async {
    return _catalogDeleteMaintenanceTaskTypeImpl(taskType);
  }

  Future<void> syncMaintenanceTaskTypesFromTasks() async {
    await _catalogSyncMaintenanceTaskTypesFromTasksImpl();
  }

  Future<int> updateSubAssemblyComponentType({
    required int subAssemblyId,
    required String componentType,
  }) async {
    return _catalogUpdateSubAssemblyComponentTypeImpl(
      subAssemblyId: subAssemblyId,
      componentType: componentType,
    );
  }

  Future<int> getSubAssemblyComponentTypeUsageCount(
    String componentType,
  ) async {
    return _catalogGetSubAssemblyComponentTypeUsageCountImpl(componentType);
  }

  Future<int> deleteComponentType(String componentType) async {
    return _catalogDeleteComponentTypeImpl(componentType);
  }

  Future<void> syncComponentTypesFromSubAssemblies() async {
    await _catalogSyncComponentTypesFromSubAssembliesImpl();
  }

  Future<Machine> insertMachine(Machine machine) async {
    return _machinesInsertMachineImpl(machine);
  }

  Future<void> insertMachines(List<Machine> machines) async {
    await _machinesInsertMachinesImpl(machines);
  }

  Future<void> replaceAllMachines(List<Machine> machines) async {
    await _machinesReplaceAllMachinesImpl(machines);
  }

  Future<bool> hasMachineDetailHistory() async {
    return _machinesHasMachineDetailHistoryImpl();
  }

  static String _isoDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// Inserts randomly generated historical detail entries for [machines] and
  /// all of their sub-assemblies. Designed to be called once on first launch
  /// to populate plausible back-dated history for sample/demo data.
  Future<void> insertSampleHistory(List<Machine> machines, Random rng) async {
    await _machinesInsertSampleHistoryImpl(machines, rng);
  }

  Future<int> updateMachine(Machine machine) async {
    return _machinesUpdateMachineImpl(machine);
  }

  Future<int> updateMachineLastCheckDate(
    int machineId,
    String lastCheckDate,
  ) async {
    return _machinesUpdateMachineLastCheckDateImpl(machineId, lastCheckDate);
  }

  Future<int> updateMachineDetailsWithHistory({
    required int machineId,
    required String operatingHours,
    required String idleHours,
    required String lastCheckDate,
  }) async {
    return _machinesUpdateMachineDetailsWithHistoryImpl(
      machineId: machineId,
      operatingHours: operatingHours,
      idleHours: idleHours,
      lastCheckDate: lastCheckDate,
    );
  }

  Future<List<MachineDetailHistoryEntry>> getMachineDetailHistory(
    int machineId, {
    int limit = 10,
  }) async {
    return _machinesGetMachineDetailHistoryImpl(machineId, limit: limit);
  }

  Future<int> updateSubAssemblyDetailsWithHistory({
    required int subAssemblyId,
    required String operatingHours,
    required String idleHours,
  }) async {
    return _machinesUpdateSubAssemblyDetailsWithHistoryImpl(
      subAssemblyId: subAssemblyId,
      operatingHours: operatingHours,
      idleHours: idleHours,
    );
  }

  Future<List<SubAssemblyDetailHistoryEntry>> getSubAssemblyDetailHistory(
    int subAssemblyId, {
    int limit = 10,
  }) async {
    return _machinesGetSubAssemblyDetailHistoryImpl(
      subAssemblyId,
      limit: limit,
    );
  }

  Future<int> upsertWorkOrderStatus({
    required int subAssemblyId,
    required String status,
    bool isRescheduled = false,
    bool isLicensedWork = false,
    String notes = '',
    DateTime? enteredAtUtc,
  }) async {
    return _workOrdersUpsertWorkOrderStatusImpl(
      subAssemblyId: subAssemblyId,
      status: status,
      isRescheduled: isRescheduled,
      isLicensedWork: isLicensedWork,
      notes: notes,
      enteredAtUtc: enteredAtUtc,
    );
  }

  Future<int> upsertWorkOrderTaskAssignment({
    required int subAssemblyId,
    required int taskId,
    required String assigneeValue,
    DateTime? enteredAtUtc,
  }) async {
    return _workOrdersUpsertWorkOrderTaskAssignmentImpl(
      subAssemblyId: subAssemblyId,
      taskId: taskId,
      assigneeValue: assigneeValue,
      enteredAtUtc: enteredAtUtc,
    );
  }

  Future<Map<int, String>> getWorkOrderTaskAssignments(
    int subAssemblyId,
  ) async {
    return _workOrdersGetWorkOrderTaskAssignmentsImpl(subAssemblyId);
  }

  Future<int> upsertWorkOrderTaskOutcome({
    required int subAssemblyId,
    required int taskId,
    required String outcome,
    String notes = '',
    DateTime? enteredAtUtc,
  }) async {
    return _workOrdersUpsertWorkOrderTaskOutcomeImpl(
      subAssemblyId: subAssemblyId,
      taskId: taskId,
      outcome: outcome,
      notes: notes,
      enteredAtUtc: enteredAtUtc,
    );
  }

  Future<Map<int, WorkOrderTaskOutcomeEntry>> getWorkOrderTaskOutcomes(
    int subAssemblyId,
  ) async {
    return _workOrdersGetWorkOrderTaskOutcomesImpl(subAssemblyId);
  }

  Future<int> deleteWorkOrderTaskAssignment({
    required int subAssemblyId,
    required int taskId,
  }) async {
    return _workOrdersDeleteWorkOrderTaskAssignmentImpl(
      subAssemblyId: subAssemblyId,
      taskId: taskId,
    );
  }

  Future<WorkOrderStatusEntry?> getWorkOrderStatus(int subAssemblyId) async {
    return _workOrdersGetWorkOrderStatusImpl(subAssemblyId);
  }

  Future<Map<String, int>> getWorkOrderStatusCounts() async {
    return _workOrdersGetWorkOrderStatusCountsImpl();
  }

  Future<List<WorkOrderReport>> getAllWorkOrdersReport() async {
    return _workOrdersGetAllWorkOrdersReportImpl();
  }

  Future<int> deleteMachine(int id) async {
    return _machinesDeleteMachineImpl(id);
  }

  Future<bool> hasMachineDocumentNumber(
    String documentNumber, {
    int? excludeMachineId,
  }) async {
    return _machinesHasMachineDocumentNumberImpl(
      documentNumber,
      excludeMachineId: excludeMachineId,
    );
  }

  Future<bool> hasSubAssemblyDocumentNumber(
    String documentNumber, {
    int? excludeMachineId,
  }) async {
    return _machinesHasSubAssemblyDocumentNumberImpl(
      documentNumber,
      excludeMachineId: excludeMachineId,
    );
  }

  Future<int> importDatabaseJson(
    String backupJson, {
    bool clearExisting = true,
  }) async {
    return _backupImportDatabaseJsonImpl(
      backupJson,
      clearExisting: clearExisting,
    );
  }

  Future<void> deleteEntireDatabaseFile() async {
    await _connectionManager.deleteEntireDatabaseFile();
  }

  Future<void> attemptDatabaseRecovery() async {
    await _connectionManager.attemptDatabaseRecovery();
  }

  Future<void> reconnectDatabase() async {
    await _connectionManager.reconnectDatabase();
  }

  @visibleForTesting
  Future<void> setDatabasePathOverrideForTesting(String? path) async {
    await _connectionManager.setDatabasePathOverrideForTesting(path);
  }

  @visibleForTesting
  Future<void> resetConnectionForTesting() async {
    await _connectionManager.resetConnectionForTesting();
  }

  Map<String, Object?> _machineToBackupMap(Machine machine) {
    return {
      ...machine.toMap()..remove('id'),
      'additionalRequiredLicenses': machine.additionalRequiredLicenses,
      'subAssemblies': machine.subAssemblies
          .map((subAssembly) => _subAssemblyToBackupMap(subAssembly))
          .toList(growable: false),
    };
  }

  Map<String, Object?> _employeeToBackupMap(Employee employee) {
    return {
      ...employee.toMap()..remove('id'),
      'skills': employee.skills,
      'licenses': employee.licenses,
    };
  }

  Map<String, Object?> _subAssemblyToBackupMap(SubAssembly subAssembly) {
    return {
      ...subAssembly.toMap()
        ..remove('id')
        ..remove('machineId'),
      'maintenanceTasks': subAssembly.maintenanceTasks
          .map((task) => _taskToBackupMap(task))
          .toList(growable: false),
    };
  }

  Map<String, Object?> _taskToBackupMap(MaintenanceTask task) {
    final row = task.toMap()
      ..remove('id')
      ..remove('subAssemblyId');
    row.remove('requiredPartsJson');

    return {
      ...row,
      'requiredParts': task.requiredParts
          .map((part) => part.toMap())
          .toList(growable: false),
    };
  }

  Machine _machineFromBackupMap(Object? row) {
    if (row is! Map) {
      throw const FormatException('Machine entry must be an object.');
    }

    final map = row.cast<Object?, Object?>();
    final rawSubAssemblies = map['subAssemblies'];
    if (rawSubAssemblies is! List) {
      throw const FormatException('Machine entry is missing subAssemblies.');
    }

    return Machine(
      name: _asString(map['name']),
      modelName: _asString(map['modelName']),
      modelNumber: _asString(map['modelNumber']),
      operatingHours: _asString(map['operatingHours']),
      idleHours: _asString(map['idleHours']),
      lastCheckDate: _asString(map['lastCheckDate']),
      serialNumber: _asString(map['serialNumber']),
      location: _asString(map['location']),
      manufacturer: _asString(map['manufacturer']),
      maintenanceDocumentName: _asString(map['maintenanceDocumentName']),
      maintenanceDocumentNumber: _asString(map['maintenanceDocumentNumber']),
      maintenancePublisher: _asString(map['maintenancePublisher']),
      requiresHvacLicense: _asBool(map['requiresHvacLicense']),
      requiresRefrigerationLicense: _asBool(
        map['requiresRefrigerationLicense'],
      ),
      requiresPlumberLicense: _asBool(map['requiresPlumberLicense']),
      requiresElectricianLicense: _asBool(map['requiresElectricianLicense']),
      requiresBoilerLicense: _asBool(map['requiresBoilerLicense']),
      additionalRequiredLicenses: _asStringList(
        map['additionalRequiredLicenses'],
      ),
      subAssemblies: rawSubAssemblies
          .map((entry) => _subAssemblyFromBackupMap(entry))
          .toList(growable: false),
    );
  }

  SubAssembly _subAssemblyFromBackupMap(Object? row) {
    if (row is! Map) {
      throw const FormatException('Sub-assembly entry must be an object.');
    }

    final map = row.cast<Object?, Object?>();
    final rawTasks = map['maintenanceTasks'];
    if (rawTasks is! List) {
      throw const FormatException(
        'Sub-assembly entry is missing maintenanceTasks.',
      );
    }

    return SubAssembly(
      name: _asString(map['name']),
      modelName: _asString(map['modelName']),
      modelNumber: _asString(map['modelNumber']),
      operatingHours: _asString(map['operatingHours']),
      idleHours: _asString(map['idleHours']),
      serialNumber: _asString(map['serialNumber']),
      location: _asString(map['location']),
      manufacturer: _asString(map['manufacturer']),
      maintenanceDocumentName: _asString(map['maintenanceDocumentName']),
      maintenanceDocumentNumber: _asString(map['maintenanceDocumentNumber']),
      maintenancePublisher: _asString(map['maintenancePublisher']),
      subCategory: _asString(map['componentType']),
      maintenanceTasks: rawTasks
          .map((entry) => _taskFromBackupMap(entry))
          .toList(growable: false),
    );
  }

  MaintenanceTask _taskFromBackupMap(Object? row) {
    if (row is! Map) {
      throw const FormatException('Task entry must be an object.');
    }

    final map = row.cast<Object?, Object?>();

    return MaintenanceTask(
      taskType: _asString(map['taskType']),
      timeCategory: _asString(map['timeCategory']),
      timeValue: _asInt(map['timeValue']),
      requiredParts: _requiredPartsFromBackupValue(
        map['requiredParts'] ?? map['requiredPartsJson'],
      ),
    );
  }

  List<RequiredPart> _requiredPartsFromBackupValue(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return const [];
      }

      try {
        final decoded = jsonDecode(trimmed);
        return _requiredPartsFromBackupValue(decoded);
      } catch (_) {
        return const [];
      }
    }

    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((entry) => entry.cast<Object?, Object?>())
        .map((entry) => RequiredPart.fromMap(entry))
        .where((part) => !part.isEmpty)
        .toList(growable: false);
  }

  Employee _employeeFromBackupMap(Object? row) {
    if (row is! Map) {
      throw const FormatException('Employee entry must be an object.');
    }

    final map = row.cast<Object?, Object?>();
    return Employee(
      name: _asString(map['name']),
      skills: _asStringList(map['skills']),
      licenses: _asStringList(map['licenses']),
    );
  }

  String _asString(Object? value) {
    if (value is String) {
      return value;
    }
    if (value == null) {
      return '';
    }
    return '$value';
  }

  int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  List<String> _asStringList(Object? value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((entry) => _asString(entry).trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  // ============================================================================
  // CSV IMPORT/EXPORT OPERATIONS
  // ============================================================================

  List<String> _employeeCsvHeaders() {
    return const [
      'id',
      'name',
      'email',
      'cellPhone',
      'phoneNumber',
      'phoneExtension',
      'skills',
      'licenses',
    ];
  }

  List<String> _employeeCsvSampleRow() {
    return const [
      '',
      'Jane Doe',
      'jane.doe@example.com',
      '555-0102',
      '555-0123',
      '456',
      'Welding;Diagnostics',
      'HVAC;Electrician',
    ];
  }

  List<String> _machineCsvHeaders() {
    return const [
      'id',
      'name',
      'modelName',
      'modelNumber',
      'operatingHours',
      'idleHours',
      'lastCheckDate',
      'serialNumber',
      'location',
      'manufacturer',
      'maintenanceDocumentName',
      'maintenanceDocumentNumber',
      'maintenancePublisher',
      'requiresHvacLicense',
      'requiresRefrigerationLicense',
      'requiresPlumberLicense',
      'requiresElectricianLicense',
      'requiresBoilerLicense',
    ];
  }

  List<String> _machineCsvSampleRow() {
    return const [
      '',
      'Air Compressor 01',
      'Atlas Copco GA',
      'GA75VSD',
      '1250',
      '80',
      '2026-03-01',
      'AC-001',
      'Plant Room A',
      'Atlas Copco',
      'Compressor Manual',
      'DOC-AC-001',
      'Atlas Copco',
      '1',
      '0',
      '0',
      '1',
      '0',
    ];
  }

  List<String> _contractorCsvHeaders() {
    return const [
      'id',
      'companyName',
      'address',
      'phoneNumber',
      'faxNumber',
      'companyUrl',
      'matchedSkills',
      'matchedLicenses',
      'employeeId',
      'employeeName',
      'employeeEmail',
      'employeePhoneNumber',
    ];
  }

  List<String> _contractorCsvSampleRow() {
    return const [
      '',
      'Acme Industrial Services',
      '100 Main Street, Springfield',
      '+1-555-0100',
      '+1-555-0101',
      'https://acme.example.com',
      'Welding;Diagnostics',
      'HVAC;Electrician',
      '',
      'Pat Morgan',
      'pat.morgan@acme.example.com',
      '+1-555-0102',
    ];
  }

  Future<String?> exportEmployeeTemplateToCsv() async {
    return _backupExportEmployeeTemplateToCsvImpl();
  }

  Future<String?> exportMachineTemplateToCsv() async {
    return _backupExportMachineTemplateToCsvImpl();
  }

  Future<String?> exportContractorTemplateToCsv() async {
    return _backupExportContractorTemplateToCsvImpl();
  }

  /// Exported employees to CSV file with headers.
  /// User selects file location via file picker.
  /// CSV format: id,name,skills,licenses
  Future<String> exportDatabaseJson() async {
    return _backupExportDatabaseJsonImpl();
  }

  Future<String> exportEmployeesToCsv() async {
    final employees = await getEmployees();
    if (employees.isEmpty) {
      return '';
    }

    final rows = <List<String>>[_employeeCsvHeaders()];
    for (final employee in employees) {
      rows.add([
        employee.id?.toString() ?? '',
        employee.name,
        employee.skills.join(';'),
        employee.licenses.join(';'),
      ]);
    }

    return _generateCsv(rows);
  }

  Future<String> exportMachinesToCsv() async {
    final machines = await getMachines();
    if (machines.isEmpty) {
      return '';
    }

    final rows = <List<String>>[_machineCsvHeaders()];
    for (final machine in machines) {
      rows.add([
        machine.id?.toString() ?? '',
        machine.name,
        machine.modelName,
        machine.modelNumber,
        machine.operatingHours,
        machine.idleHours,
        machine.lastCheckDate,
        machine.serialNumber,
        machine.location,
        machine.manufacturer,
        machine.maintenanceDocumentName,
        machine.maintenanceDocumentNumber,
        machine.maintenancePublisher,
        machine.requiresHvacLicense ? '1' : '0',
        machine.requiresRefrigerationLicense ? '1' : '0',
        machine.requiresPlumberLicense ? '1' : '0',
        machine.requiresElectricianLicense ? '1' : '0',
        machine.requiresBoilerLicense ? '1' : '0',
      ]);
    }

    return _generateCsv(rows);
  }

  Future<String> exportContractorsToCsv() async {
    final companies = await getContractorCompanies();
    if (companies.isEmpty) {
      return '';
    }

    final rows = <List<String>>[_contractorCsvHeaders()];
    for (final company in companies) {
      final companyId = company.id;
      final contacts = companyId == null
          ? const <ContractorEmployeeContact>[]
          : await getContractorEmployees(companyId);

      if (contacts.isEmpty) {
        rows.add([
          companyId?.toString() ?? '',
          company.companyName,
          company.address,
          company.phoneNumber,
          company.faxNumber,
          company.companyUrl,
          company.matchedSkills.join(';'),
          company.matchedLicenses.join(';'),
          '',
          '',
          '',
          '',
        ]);
        continue;
      }

      for (final contact in contacts) {
        rows.add([
          companyId?.toString() ?? '',
          company.companyName,
          company.address,
          company.phoneNumber,
          company.faxNumber,
          company.companyUrl,
          company.matchedSkills.join(';'),
          company.matchedLicenses.join(';'),
          contact.id?.toString() ?? '',
          contact.fullName,
          contact.email,
          contact.phoneNumber,
        ]);
      }
    }

    return _generateCsv(rows);
  }

  Future<int> importEmployeesFromCsv(String csvContent) async {
    try {
      final rows = _parseCsvContent(csvContent);
      if (rows.length <= 1) {
        return 0;
      }

      final headers = rows.first;
      final idIndex = headers.indexOf('id');
      final nameIndex = headers.indexOf('name');
      final emailIndex = headers.indexOf('email');
      final cellPhoneIndex = headers.indexOf('cellPhone');
      final phoneNumberIndex = headers.indexOf('phoneNumber');
      final phoneExtensionIndex = headers.indexOf('phoneExtension');
      final skillsIndex = headers.indexOf('skills');
      final licensesIndex = headers.indexOf('licenses');

      if (nameIndex < 0) {
        return 0;
      }

      String fieldValue(List<String> row, int index) {
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      final existing = await getEmployees();
      final existingById = <int, Employee>{
        for (final employee in existing)
          if (employee.id != null) employee.id!: employee,
      };
      final existingByName = <String, Employee>{
        for (final employee in existing)
          employee.name.trim().toUpperCase(): employee,
      };

      var importedCount = 0;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((value) => value.trim().isEmpty)) {
          continue;
        }

        final name = fieldValue(row, nameIndex);
        if (name.isEmpty) {
          continue;
        }

        final id = int.tryParse(fieldValue(row, idIndex));
        final matched =
            (id != null ? existingById[id] : null) ??
            existingByName[name.toUpperCase()];

        final employee = Employee(
          id: matched?.id,
          name: name,
          email: fieldValue(row, emailIndex).isNotEmpty
              ? fieldValue(row, emailIndex)
              : (matched?.email ?? ''),
          cellPhone: fieldValue(row, cellPhoneIndex).isNotEmpty
              ? fieldValue(row, cellPhoneIndex)
              : (matched?.cellPhone ?? ''),
          phoneNumber: fieldValue(row, phoneNumberIndex).isNotEmpty
              ? fieldValue(row, phoneNumberIndex)
              : (matched?.phoneNumber ?? ''),
          phoneExtension: fieldValue(row, phoneExtensionIndex).isNotEmpty
              ? fieldValue(row, phoneExtensionIndex)
              : (matched?.phoneExtension ?? ''),
          skills: fieldValue(row, skillsIndex)
              .split(';')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
          licenses: fieldValue(row, licensesIndex)
              .split(';')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
        );

        if (matched?.id != null) {
          await updateEmployee(employee.copyWith(id: matched!.id));
        } else {
          await insertEmployee(employee.copyWith(id: null));
        }
        importedCount += 1;
      }

      return importedCount;
    } catch (_) {
      return 0;
    }
  }

  Future<int> importMachinesFromCsv(String csvContent) async {
    try {
      final rows = _parseCsvContent(csvContent);
      if (rows.length <= 1) {
        return 0;
      }

      final headers = rows.first;
      final idIndex = headers.indexOf('id');
      final nameIndex = headers.indexOf('name');
      final modelNameIndex = headers.indexOf('modelName');
      final modelNumberIndex = headers.indexOf('modelNumber');
      final operatingHoursIndex = headers.indexOf('operatingHours');
      final idleHoursIndex = headers.indexOf('idleHours');
      final lastCheckDateIndex = headers.indexOf('lastCheckDate');
      final serialNumberIndex = headers.indexOf('serialNumber');
      final locationIndex = headers.indexOf('location');
      final manufacturerIndex = headers.indexOf('manufacturer');
      final maintenanceDocumentNameIndex = headers.indexOf(
        'maintenanceDocumentName',
      );
      final maintenanceDocumentNumberIndex = headers.indexOf(
        'maintenanceDocumentNumber',
      );
      final maintenancePublisherIndex = headers.indexOf('maintenancePublisher');
      final requiresHvacLicenseIndex = headers.indexOf('requiresHvacLicense');
      final requiresRefrigerationLicenseIndex = headers.indexOf(
        'requiresRefrigerationLicense',
      );
      final requiresPlumberLicenseIndex = headers.indexOf(
        'requiresPlumberLicense',
      );
      final requiresElectricianLicenseIndex = headers.indexOf(
        'requiresElectricianLicense',
      );
      final requiresBoilerLicenseIndex = headers.indexOf(
        'requiresBoilerLicense',
      );

      if (nameIndex < 0 || modelNameIndex < 0 || modelNumberIndex < 0) {
        return 0;
      }

      String fieldValue(List<String> row, int index) {
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      bool fieldBool(List<String> row, int index) {
        return _asBool(fieldValue(row, index));
      }

      final existing = await getMachines();
      final existingById = <int, Machine>{
        for (final machine in existing)
          if (machine.id != null) machine.id!: machine,
      };

      var importedCount = 0;
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((value) => value.trim().isEmpty)) {
          continue;
        }

        final name = fieldValue(row, nameIndex);
        final modelName = fieldValue(row, modelNameIndex);
        final modelNumber = fieldValue(row, modelNumberIndex);
        if (name.isEmpty || modelName.isEmpty || modelNumber.isEmpty) {
          continue;
        }

        final id = int.tryParse(fieldValue(row, idIndex));
        final matched = id == null ? null : existingById[id];

        final machine = Machine(
          id: matched?.id,
          name: name,
          modelName: modelName,
          modelNumber: modelNumber,
          operatingHours: fieldValue(row, operatingHoursIndex),
          idleHours: fieldValue(row, idleHoursIndex),
          lastCheckDate: fieldValue(row, lastCheckDateIndex),
          serialNumber: fieldValue(row, serialNumberIndex),
          location: fieldValue(row, locationIndex),
          manufacturer: fieldValue(row, manufacturerIndex),
          maintenanceDocumentName: fieldValue(
            row,
            maintenanceDocumentNameIndex,
          ),
          maintenanceDocumentNumber: fieldValue(
            row,
            maintenanceDocumentNumberIndex,
          ),
          maintenancePublisher: fieldValue(row, maintenancePublisherIndex),
          requiresHvacLicense: fieldBool(row, requiresHvacLicenseIndex),
          requiresRefrigerationLicense: fieldBool(
            row,
            requiresRefrigerationLicenseIndex,
          ),
          requiresPlumberLicense: fieldBool(row, requiresPlumberLicenseIndex),
          requiresElectricianLicense: fieldBool(
            row,
            requiresElectricianLicenseIndex,
          ),
          requiresBoilerLicense: fieldBool(row, requiresBoilerLicenseIndex),
          subAssemblies: matched?.subAssemblies ?? const <SubAssembly>[],
          additionalRequiredLicenses:
              matched?.additionalRequiredLicenses ?? const <String>[],
        );

        if (matched?.id != null) {
          await updateMachine(machine.copyWith(id: matched!.id));
        } else {
          await insertMachine(machine.copyWith(id: null));
        }
        importedCount += 1;
      }

      return importedCount;
    } catch (_) {
      return 0;
    }
  }

  /// Imports contractor companies and employees from CSV content.
  Future<int> importContractorsFromCsv(String csvContent) async {
    return await importContractorsFromCsvImpl(csvContent);
  }

  /// Generates CSV content from rows and saves to file via file picker.
  /// Returns file path if successful, null if cancelled or failed.
  String _generateCsv(List<List<String>> rows) {
    return helpersGenerateCsv(rows);
  }

  /// Parses CSV content into rows.
  /// Handles quoted fields with escaped quotes.
  List<List<String>> _parseCsvContent(String csvContent) {
    return helpersParseCsvContent(csvContent);
  }
}
