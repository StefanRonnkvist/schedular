part of 'package:schedular/main.dart';

extension _MachineDatabaseContractorsExtension on MachineDatabase {
  Future<List<ContractorCompany>>
  _contractorsGetContractorCompaniesImpl() async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    final rows = await db.query(
      contractorCompanyTable,
      orderBy: 'companyName COLLATE NOCASE ASC, id ASC',
    );
    return rows
        .map((row) {
          try {
            return ContractorCompany.fromMap(row);
          } catch (error) {
            debugPrint('Skipping malformed contractor company row: $error');
            return null;
          }
        })
        .whereType<ContractorCompany>()
        .toList(growable: false);
  }

  Future<ContractorCompany> _contractorsUpsertContractorCompanyImpl(
    ContractorCompany company,
  ) async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    return db.transaction((txn) async {
      if (company.id == null) {
        final insertedId = await txn.insert(
          contractorCompanyTable,
          company.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return company.copyWith(id: insertedId);
      }

      await txn.update(
        contractorCompanyTable,
        company.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [company.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return company;
    });
  }

  Future<int> _contractorsDeleteContractorCompanyImpl(int companyId) async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    return db.transaction((txn) async {
      await txn.delete(
        contractorEmployeeTable,
        where: 'contractorCompanyId = ?',
        whereArgs: [companyId],
      );
      return txn.delete(
        contractorCompanyTable,
        where: 'id = ?',
        whereArgs: [companyId],
      );
    });
  }

  Future<List<ContractorEmployeeContact>>
  _contractorsGetContractorEmployeesImpl(int companyId) async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    final rows = await db.query(
      contractorEmployeeTable,
      where: 'contractorCompanyId = ?',
      whereArgs: [companyId],
      orderBy: 'fullName COLLATE NOCASE ASC, id ASC',
    );
    return rows
        .map((row) {
          try {
            return ContractorEmployeeContact.fromMap(row);
          } catch (error) {
            debugPrint('Skipping malformed contractor employee row: $error');
            return null;
          }
        })
        .whereType<ContractorEmployeeContact>()
        .toList(growable: false);
  }

  Future<ContractorEmployeeContact> _contractorsUpsertContractorEmployeeImpl(
    ContractorEmployeeContact contact,
  ) async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    return db.transaction((txn) async {
      if (contact.id == null) {
        final insertedId = await txn.insert(
          contractorEmployeeTable,
          contact.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
        return contact.copyWith(id: insertedId);
      }

      await txn.update(
        contractorEmployeeTable,
        contact.toMap()..remove('id'),
        where: 'id = ?',
        whereArgs: [contact.id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      return contact;
    });
  }

  Future<int> _contractorsDeleteContractorEmployeeImpl(int id) async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    return db.delete(contractorEmployeeTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> _contractorsDeleteAllContractorsImpl() async {
    final db = await database;
    await _ensureContractorTablesReady(db);
    await db.transaction((txn) async {
      await txn.delete(contractorEmployeeTable);
      await txn.delete(contractorCompanyTable);
    });
  }
}
