import 'package:flutter_test/flutter_test.dart';
import 'package:schedular/main.dart';

/// Tests for the pure backup map transforms.
///
/// `_backupExportDatabaseJsonImpl` normally runs against a live database, so
/// these exercise the individual machine/employee conversions reached through
/// the `@visibleForTesting` seam on `MachineDatabase`.
///
/// The invariant that matters most: a backup must be importable into a
/// *different* database. That is why ids are stripped on export, and these
/// tests pin that behaviour.
void main() {
  final db = MachineDatabase.instance;

  Machine sampleMachine({int? id, List<SubAssembly> subAssemblies = const []}) {
    return Machine(
      id: id,
      name: 'Air Compressor 01',
      modelName: 'AC-100',
      modelNumber: 'MN-100',
      operatingHours: '1200',
      idleHours: '300',
      lastCheckDate: '2026-01-15',
      serialNumber: 'SN-100',
      location: 'Building A',
      manufacturer: 'Acme',
      maintenanceDocumentName: 'Manual',
      maintenanceDocumentNumber: 'MD-100',
      maintenancePublisher: 'Acme Docs',
      requiresHvacLicense: true,
      requiresRefrigerationLicense: true,
      requiresPlumberLicense: false,
      requiresElectricianLicense: true,
      requiresBoilerLicense: false,
      additionalRequiredLicenses: const <String>['Forklift'],
      subAssemblies: subAssemblies,
    );
  }

  group('machine backup map', () {
    test('omits the id so backups can cross databases', () {
      final map = db.machineToBackupMapForTesting(sampleMachine(id: 42));

      expect(map.containsKey('id'), isFalse);
    });

    test('round trips a machine without an id', () {
      final original = sampleMachine(id: 7);
      final restored = db.machineFromBackupMapForTesting(
        db.machineToBackupMapForTesting(original),
      );

      expect(restored.id, isNull);
      expect(restored.name, original.name);
      expect(restored.modelName, original.modelName);
      expect(restored.modelNumber, original.modelNumber);
      expect(restored.operatingHours, original.operatingHours);
      expect(restored.idleHours, original.idleHours);
      expect(restored.lastCheckDate, original.lastCheckDate);
      expect(restored.serialNumber, original.serialNumber);
      expect(restored.location, original.location);
      expect(restored.manufacturer, original.manufacturer);
      expect(
        restored.maintenanceDocumentName,
        original.maintenanceDocumentName,
      );
      expect(
        restored.maintenanceDocumentNumber,
        original.maintenanceDocumentNumber,
      );
      expect(restored.maintenancePublisher, original.maintenancePublisher);
      expect(restored.requiresHvacLicense, original.requiresHvacLicense);
      expect(
        restored.requiresRefrigerationLicense,
        original.requiresRefrigerationLicense,
      );
      expect(restored.requiresPlumberLicense, original.requiresPlumberLicense);
      expect(
        restored.requiresElectricianLicense,
        original.requiresElectricianLicense,
      );
      expect(restored.requiresBoilerLicense, original.requiresBoilerLicense);
      expect(restored.additionalRequiredLicenses, <String>['Forklift']);
    });

    test('preserves false license flags rather than defaulting them', () {
      final restored = db.machineFromBackupMapForTesting(
        db.machineToBackupMapForTesting(sampleMachine()),
      );

      expect(restored.requiresPlumberLicense, isFalse);
      expect(restored.requiresBoilerLicense, isFalse);
    });

    test('throws when subAssemblies is missing', () {
      expect(
        () => db.machineFromBackupMapForTesting(<String, Object?>{
          'name': 'Broken',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when the entry is not an object', () {
      expect(
        () => db.machineFromBackupMapForTesting('not a map'),
        throwsA(isA<FormatException>()),
      );
    });

    test('tolerates missing optional fields by defaulting them', () {
      final restored = db.machineFromBackupMapForTesting(<String, Object?>{
        'name': 'Sparse',
        'subAssemblies': <Object?>[],
      });

      expect(restored.name, 'Sparse');
      expect(restored.modelName, '');
      expect(restored.requiresHvacLicense, isFalse);
      expect(restored.additionalRequiredLicenses, isEmpty);
    });
  });

  group('machine backup map with sub-assemblies', () {
    test('round trips a sub-assembly with maintenance tasks and parts', () {
      final task = MaintenanceTask(
        id: 99,
        subAssemblyId: 5,
        taskType: 'Replace',
        timeCategory: 'Months',
        timeValue: 6,
        requiredParts: const <RequiredPart>[
          RequiredPart(
            oemPn: 'OEM-1',
            vendorPn: 'VP-1',
            vendorName: 'Acme Supply',
            vendorUrl: 'https://example.com',
            vendorPhoneNumber: '555-0100',
            estimatedLeadTime: '2 weeks',
          ),
        ],
      );

      final subAssembly = SubAssembly(
        id: 5,
        machineId: 1,
        name: 'Pump Assembly',
        modelName: 'PA-1',
        modelNumber: 'PA-MN-1',
        operatingHours: '800',
        idleHours: '100',
        serialNumber: 'PA-SN-1',
        location: 'Building A',
        manufacturer: 'Acme',
        maintenanceDocumentName: 'PA Manual',
        maintenanceDocumentNumber: 'PA-MD-1',
        maintenancePublisher: 'Acme Docs',
        subCategory: 'Pump',
        maintenanceTasks: <MaintenanceTask>[task],
      );

      final original = sampleMachine(subAssemblies: <SubAssembly>[subAssembly]);
      final restored = db.machineFromBackupMapForTesting(
        db.machineToBackupMapForTesting(original),
      );

      expect(restored.subAssemblies.length, 1);
      final restoredSub = restored.subAssemblies.single;
      expect(restoredSub.id, isNull);
      expect(restoredSub.machineId, isNull);
      expect(restoredSub.name, 'Pump Assembly');
      expect(restoredSub.subCategory, 'Pump');

      expect(restoredSub.maintenanceTasks.length, 1);
      final restoredTask = restoredSub.maintenanceTasks.single;
      expect(restoredTask.id, isNull);
      expect(restoredTask.subAssemblyId, isNull);
      expect(restoredTask.taskType, 'Replace');
      expect(restoredTask.timeCategory, 'Months');
      expect(restoredTask.timeValue, 6);

      expect(restoredTask.requiredParts.length, 1);
      final restoredPart = restoredTask.requiredParts.single;
      expect(restoredPart.oemPn, 'OEM-1');
      expect(restoredPart.vendorPn, 'VP-1');
      expect(restoredPart.vendorName, 'Acme Supply');
      expect(restoredPart.vendorUrl, 'https://example.com');
      expect(restoredPart.vendorPhoneNumber, '555-0100');
      expect(restoredPart.estimatedLeadTime, '2 weeks');
    });

    test('throws when maintenanceTasks is missing from a sub-assembly', () {
      expect(
        () => db.machineFromBackupMapForTesting(<String, Object?>{
          'name': 'Broken',
          'subAssemblies': <Object?>[
            <String, Object?>{'name': 'Orphan'},
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('employee backup map', () {
    Employee sampleEmployee({int? id}) {
      return Employee(
        id: id,
        name: 'Jane Doe',
        email: 'jane.doe@example.com',
        cellPhone: '555-0102',
        phoneNumber: '555-0123',
        phoneExtension: '456',
        skills: const <String>['Welding', 'Diagnostics'],
        licenses: const <String>['HVAC', 'Electrician'],
      );
    }

    test('omits the id so backups can cross databases', () {
      final map = db.employeeToBackupMapForTesting(sampleEmployee(id: 11));

      expect(map.containsKey('id'), isFalse);
    });

    test('round trips an employee including skills and licenses', () {
      final original = sampleEmployee(id: 3);
      final restored = db.employeeFromBackupMapForTesting(
        db.employeeToBackupMapForTesting(original),
      );

      expect(restored.id, isNull);
      expect(restored.name, 'Jane Doe');
      expect(restored.email, 'jane.doe@example.com');
      expect(restored.cellPhone, '555-0102');
      expect(restored.phoneNumber, '555-0123');
      expect(restored.phoneExtension, '456');
      expect(restored.skills, <String>['Welding', 'Diagnostics']);
      expect(restored.licenses, <String>['HVAC', 'Electrician']);
    });

    test('throws when the entry is not an object', () {
      expect(
        () => db.employeeFromBackupMapForTesting(42),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
