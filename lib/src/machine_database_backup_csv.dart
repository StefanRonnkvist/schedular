part of 'package:schedular/main.dart';

extension _MachineDatabaseBackupCsvExtension on MachineDatabase {
  /// Imports contractor companies and their employee contacts from CSV.
  ///
  /// Companies are matched case-insensitively by name. Blank company fields
  /// preserve existing values, while non-blank fields update them. Employees
  /// are matched first by ID and then by their name, email, and phone tuple.
  /// The returned count includes newly created companies, not updated companies
  /// or imported employees. Malformed input or persistence failures return zero.
  Future<int> importContractorsFromCsvImpl(String csvContent) async {
    try {
      final parsedRows = _parseCsvContent(csvContent);
      if (parsedRows.isEmpty) {
        return 0;
      }
      final headers = parsedRows.first;
      final companyNameIndex = headers.indexOf('companyName');
      final addressIndex = headers.indexOf('address');
      final phoneIndex = headers.indexOf('phoneNumber');
      final faxIndex = headers.indexOf('faxNumber');
      final urlIndex = headers.indexOf('companyUrl');
      final skillsIndex = headers.indexOf('matchedSkills');
      final licensesIndex = headers.indexOf('matchedLicenses');
      final employeeIdIndex = headers.indexOf('employeeId');
      final employeeNameIndex = headers.indexOf('employeeName');
      final employeeEmailIndex = headers.indexOf('employeeEmail');
      final employeePhoneIndex = headers.indexOf('employeePhoneNumber');
      if (companyNameIndex < 0) {
        return 0;
      }
      final existingCompanies = await getContractorCompanies();
      final companiesByName = <String, ContractorCompany>{
        for (final company in existingCompanies)
          company.companyName.trim().toUpperCase(): company,
      };
      final Map<int, List<ContractorEmployeeContact>> employeeCache =
          <int, List<ContractorEmployeeContact>>{};
      var importedCompanies = 0;

      String fieldValue(List<String> row, int index) {
        if (index < 0 || index >= row.length) {
          return '';
        }
        return row[index].trim();
      }

      for (var i = 1; i < parsedRows.length; i++) {
        final row = parsedRows[i];
        if (row.isEmpty || row.every((field) => field.trim().isEmpty)) {
          continue;
        }
        final companyName = fieldValue(row, companyNameIndex);
        if (companyName.isEmpty) {
          continue;
        }
        final companyKey = companyName.toUpperCase();
        final matchedSkills = fieldValue(row, skillsIndex)
            .split(';')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);
        final matchedLicenses = fieldValue(row, licensesIndex)
            .split(';')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false);

        final existing = companiesByName[companyKey];
        final nextCompany = ContractorCompany(
          id: existing?.id,
          companyName: companyName,
          address: fieldValue(row, addressIndex).isEmpty
              ? (existing?.address ?? '')
              : fieldValue(row, addressIndex),
          phoneNumber: fieldValue(row, phoneIndex).isEmpty
              ? (existing?.phoneNumber ?? '')
              : fieldValue(row, phoneIndex),
          faxNumber: fieldValue(row, faxIndex).isEmpty
              ? (existing?.faxNumber ?? '')
              : fieldValue(row, faxIndex),
          companyUrl: fieldValue(row, urlIndex).isEmpty
              ? (existing?.companyUrl ?? '')
              : fieldValue(row, urlIndex),
          matchedSkills: matchedSkills.isEmpty
              ? (existing?.matchedSkills ?? const <String>[])
              : matchedSkills,
          matchedLicenses: matchedLicenses.isEmpty
              ? (existing?.matchedLicenses ?? const <String>[])
              : matchedLicenses,
        );

        final savedCompany = await upsertContractorCompany(nextCompany);
        if (existing == null) {
          importedCompanies += 1;
        }
        companiesByName[companyKey] = savedCompany;

        final companyId = savedCompany.id;
        if (companyId == null) {
          continue;
        }

        final employeeName = fieldValue(row, employeeNameIndex);
        if (employeeName.isEmpty) {
          continue;
        }

        final employeeIdRaw = fieldValue(row, employeeIdIndex);
        final employeeId = int.tryParse(employeeIdRaw);
        final employeeEmail = fieldValue(row, employeeEmailIndex);
        final employeePhone = fieldValue(row, employeePhoneIndex);
        final List<ContractorEmployeeContact> cachedEmployees = employeeCache
            .putIfAbsent(companyId, () => <ContractorEmployeeContact>[]);

        if (cachedEmployees.isEmpty) {
          cachedEmployees.addAll(await getContractorEmployees(companyId));
        }

        ContractorEmployeeContact? existingEmployee;
        if (employeeId != null) {
          existingEmployee = cachedEmployees
              .where((employee) => employee.id == employeeId)
              .firstOrNull;
        }

        existingEmployee ??= cachedEmployees
            .where(
              (employee) =>
                  employee.fullName.trim().toUpperCase() ==
                      employeeName.toUpperCase() &&
                  employee.email.trim().toUpperCase() ==
                      employeeEmail.toUpperCase() &&
                  employee.phoneNumber.trim().toUpperCase() ==
                      employeePhone.toUpperCase(),
            )
            .firstOrNull;

        final savedEmployee = await upsertContractorEmployee(
          ContractorEmployeeContact(
            id: existingEmployee?.id,
            contractorCompanyId: companyId,
            fullName: employeeName,
            email: employeeEmail,
            phoneNumber: employeePhone,
          ),
        );

        if (existingEmployee == null) {
          cachedEmployees.add(savedEmployee);
        } else {
          final atIndex = cachedEmployees.indexWhere(
            (employee) => employee.id == existingEmployee!.id,
          );
          if (atIndex >= 0) {
            cachedEmployees[atIndex] = savedEmployee;
          }
        }
      }

      return importedCompanies;
    } catch (_) {
      return 0;
    }
  }
}
