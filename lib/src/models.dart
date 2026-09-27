part of 'package:schedular/main.dart';

/// Coerces SQLite, JSON, and CSV-style truthy values into a boolean.
/// Unrecognized values are treated as false.
bool _asBool(Object? value) {
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is num) return value != 0;
  if (value is String) {
    final n = value.trim().toLowerCase();
    return n == '1' || n == 'true' || n == 'yes';
  }
  return false;
}

class Machine {
  const Machine({
    this.id,
    required this.name,
    required this.modelName,
    required this.modelNumber,
    required this.operatingHours,
    required this.idleHours,
    required this.lastCheckDate,
    required this.serialNumber,
    required this.location,
    required this.manufacturer,
    required this.maintenanceDocumentName,
    required this.maintenanceDocumentNumber,
    required this.maintenancePublisher,
    this.requiresHvacLicense = false,
    this.requiresRefrigerationLicense = false,
    this.requiresPlumberLicense = false,
    this.requiresElectricianLicense = false,
    this.requiresBoilerLicense = false,
    this.additionalRequiredLicenses = const [],
    this.subAssemblies = const [],
  });

  final int? id;
  final String name;
  final String modelName;
  final String modelNumber;
  final String operatingHours;
  final String idleHours;
  final String lastCheckDate;
  final String serialNumber;
  final String location;
  final String manufacturer;
  final String maintenanceDocumentName;
  final String maintenanceDocumentNumber;
  final String maintenancePublisher;
  final bool requiresHvacLicense;
  final bool requiresRefrigerationLicense;
  final bool requiresPlumberLicense;
  final bool requiresElectricianLicense;
  final bool requiresBoilerLicense;
  final List<String> additionalRequiredLicenses;
  final List<SubAssembly> subAssemblies;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'modelName': modelName,
      'modelNumber': modelNumber,
      'operatingHours': operatingHours,
      'idleHours': idleHours,
      'lastCheckDate': lastCheckDate,
      'serialNumber': serialNumber,
      'location': location,
      'manufacturer': manufacturer,
      'maintenanceDocumentName': maintenanceDocumentName,
      'maintenanceDocumentNumber': maintenanceDocumentNumber,
      'maintenancePublisher': maintenancePublisher,
      'requiresHvacLicense': requiresHvacLicense ? 1 : 0,
      'requiresRefrigerationLicense': requiresRefrigerationLicense ? 1 : 0,
      'requiresPlumberLicense': requiresPlumberLicense ? 1 : 0,
      'requiresElectricianLicense': requiresElectricianLicense ? 1 : 0,
      'requiresBoilerLicense': requiresBoilerLicense ? 1 : 0,
    };
  }

  /// Builds a machine from persisted data while accepting the legacy
  /// `idolHours` spelling used by older databases.
  factory Machine.fromMap(Map<String, Object?> map) {
    return Machine(
      id: map['id'] as int?,
      name: map['name'] as String,
      modelName: (map['modelName'] as String?) ?? '',
      modelNumber: (map['modelNumber'] as String?) ?? '',
      operatingHours: (map['operatingHours'] as String?) ?? '',
      idleHours:
          (map['idleHours'] as String?) ?? (map['idolHours'] as String?) ?? '',
      lastCheckDate: (map['lastCheckDate'] as String?) ?? '',
      serialNumber: (map['serialNumber'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      manufacturer: (map['manufacturer'] as String?) ?? '',
      maintenanceDocumentName:
          (map['maintenanceDocumentName'] as String?) ?? '',
      maintenanceDocumentNumber:
          (map['maintenanceDocumentNumber'] as String?) ?? '',
      maintenancePublisher: (map['maintenancePublisher'] as String?) ?? '',
      requiresHvacLicense: _asBool(map['requiresHvacLicense']),
      requiresRefrigerationLicense: _asBool(
        map['requiresRefrigerationLicense'],
      ),
      requiresPlumberLicense: _asBool(map['requiresPlumberLicense']),
      requiresElectricianLicense: _asBool(map['requiresElectricianLicense']),
      requiresBoilerLicense: _asBool(map['requiresBoilerLicense']),
    );
  }

  Machine copyWith({
    int? id,
    String? name,
    String? modelName,
    String? modelNumber,
    String? operatingHours,
    String? idleHours,
    String? lastCheckDate,
    String? serialNumber,
    String? location,
    String? manufacturer,
    String? maintenanceDocumentName,
    String? maintenanceDocumentNumber,
    String? maintenancePublisher,
    bool? requiresHvacLicense,
    bool? requiresRefrigerationLicense,
    bool? requiresPlumberLicense,
    bool? requiresElectricianLicense,
    bool? requiresBoilerLicense,
    List<String>? additionalRequiredLicenses,
    List<SubAssembly>? subAssemblies,
  }) {
    return Machine(
      id: id ?? this.id,
      name: name ?? this.name,
      modelName: modelName ?? this.modelName,
      modelNumber: modelNumber ?? this.modelNumber,
      operatingHours: operatingHours ?? this.operatingHours,
      idleHours: idleHours ?? this.idleHours,
      lastCheckDate: lastCheckDate ?? this.lastCheckDate,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      manufacturer: manufacturer ?? this.manufacturer,
      maintenanceDocumentName:
          maintenanceDocumentName ?? this.maintenanceDocumentName,
      maintenanceDocumentNumber:
          maintenanceDocumentNumber ?? this.maintenanceDocumentNumber,
      maintenancePublisher: maintenancePublisher ?? this.maintenancePublisher,
      requiresHvacLicense: requiresHvacLicense ?? this.requiresHvacLicense,
      requiresRefrigerationLicense:
          requiresRefrigerationLicense ?? this.requiresRefrigerationLicense,
      requiresPlumberLicense:
          requiresPlumberLicense ?? this.requiresPlumberLicense,
      requiresElectricianLicense:
          requiresElectricianLicense ?? this.requiresElectricianLicense,
      requiresBoilerLicense:
          requiresBoilerLicense ?? this.requiresBoilerLicense,
      additionalRequiredLicenses:
          additionalRequiredLicenses ?? this.additionalRequiredLicenses,
      subAssemblies: subAssemblies ?? this.subAssemblies,
    );
  }
}

class Employee {
  const Employee({
    this.id,
    required this.name,
    this.email = '',
    this.cellPhone = '',
    this.phoneNumber = '',
    this.phoneExtension = '',
    this.skills = const [],
    this.licenses = const [],
  });

  final int? id;
  final String name;
  final String email;
  final String cellPhone;
  final String phoneNumber;
  final String phoneExtension;
  final List<String> skills;
  final List<String> licenses;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'cellPhone': cellPhone,
      'phoneNumber': phoneNumber,
      'phoneExtension': phoneExtension,
    };
  }

  factory Employee.fromMap(Map<String, Object?> map) {
    return Employee(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      cellPhone: (map['cellPhone'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      phoneExtension: (map['phoneExtension'] as String?) ?? '',
    );
  }

  Employee copyWith({
    int? id,
    String? name,
    String? email,
    String? cellPhone,
    String? phoneNumber,
    String? phoneExtension,
    List<String>? skills,
    List<String>? licenses,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      cellPhone: cellPhone ?? this.cellPhone,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      phoneExtension: phoneExtension ?? this.phoneExtension,
      skills: skills ?? this.skills,
      licenses: licenses ?? this.licenses,
    );
  }
}

class SubAssembly {
  const SubAssembly({
    this.id,
    this.machineId,
    required this.name,
    required this.modelName,
    required this.modelNumber,
    required this.operatingHours,
    required this.idleHours,
    required this.serialNumber,
    required this.location,
    required this.manufacturer,
    required this.maintenanceDocumentName,
    required this.maintenanceDocumentNumber,
    required this.maintenancePublisher,
    this.superCategory = '',
    this.subCategory = '',
    this.maintenanceTasks = const [],
  });

  final int? id;
  final int? machineId;
  final String name;
  final String modelName;
  final String modelNumber;
  final String operatingHours;
  final String idleHours;
  final String serialNumber;
  final String location;
  final String manufacturer;
  final String maintenanceDocumentName;
  final String maintenanceDocumentNumber;
  final String maintenancePublisher;
  final String superCategory;
  final String subCategory;
  final List<MaintenanceTask> maintenanceTasks;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'name': name,
      'modelName': modelName,
      'modelNumber': modelNumber,
      'operatingHours': operatingHours,
      'idleHours': idleHours,
      'serialNumber': serialNumber,
      'location': location,
      'manufacturer': manufacturer,
      'maintenanceDocumentName': maintenanceDocumentName,
      'maintenanceDocumentNumber': maintenanceDocumentNumber,
      'maintenancePublisher': maintenancePublisher,
      'superCategory': superCategory,
      'componentType': subCategory,
    };
  }

  factory SubAssembly.fromMap(Map<String, Object?> map) {
    return SubAssembly(
      id: map['id'] as int?,
      machineId: map['machineId'] as int?,
      name: (map['name'] as String?) ?? '',
      modelName: (map['modelName'] as String?) ?? '',
      modelNumber: (map['modelNumber'] as String?) ?? '',
      operatingHours: (map['operatingHours'] as String?) ?? '',
      idleHours:
          (map['idleHours'] as String?) ?? (map['idolHours'] as String?) ?? '',
      serialNumber: (map['serialNumber'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      manufacturer: (map['manufacturer'] as String?) ?? '',
      maintenanceDocumentName:
          (map['maintenanceDocumentName'] as String?) ?? '',
      maintenanceDocumentNumber:
          (map['maintenanceDocumentNumber'] as String?) ?? '',
      maintenancePublisher: (map['maintenancePublisher'] as String?) ?? '',
      superCategory: (map['superCategory'] as String?) ?? '',
      subCategory: (map['componentType'] as String?) ?? '',
    );
  }

  SubAssembly copyWith({
    int? id,
    int? machineId,
    String? name,
    String? modelName,
    String? modelNumber,
    String? operatingHours,
    String? idleHours,
    String? serialNumber,
    String? location,
    String? manufacturer,
    String? maintenanceDocumentName,
    String? maintenanceDocumentNumber,
    String? maintenancePublisher,
    String? superCategory,
    String? subCategory,
    List<MaintenanceTask>? maintenanceTasks,
  }) {
    return SubAssembly(
      id: id ?? this.id,
      machineId: machineId ?? this.machineId,
      name: name ?? this.name,
      modelName: modelName ?? this.modelName,
      modelNumber: modelNumber ?? this.modelNumber,
      operatingHours: operatingHours ?? this.operatingHours,
      idleHours: idleHours ?? this.idleHours,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      manufacturer: manufacturer ?? this.manufacturer,
      maintenanceDocumentName:
          maintenanceDocumentName ?? this.maintenanceDocumentName,
      maintenanceDocumentNumber:
          maintenanceDocumentNumber ?? this.maintenanceDocumentNumber,
      maintenancePublisher: maintenancePublisher ?? this.maintenancePublisher,
      superCategory: superCategory ?? this.superCategory,
      subCategory: subCategory ?? this.subCategory,
      maintenanceTasks: maintenanceTasks ?? this.maintenanceTasks,
    );
  }
}

class MaintenanceTask {
  const MaintenanceTask({
    this.id,
    this.subAssemblyId,
    required this.taskType,
    required this.timeCategory,
    this.timeValue = 0,
    this.requiredParts = const [],
  });

  final int? id;
  final int? subAssemblyId;
  final String taskType;
  final String timeCategory;
  final int timeValue;
  final List<RequiredPart> requiredParts;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subAssemblyId': subAssemblyId,
      'taskType': taskType,
      'timeCategory': timeCategory,
      'timeValue': timeValue,
      'requiredPartsJson': jsonEncode(
        requiredParts.map((part) => part.toMap()).toList(growable: false),
      ),
    };
  }

  factory MaintenanceTask.fromMap(Map<String, Object?> map) {
    return MaintenanceTask(
      id: map['id'] as int?,
      subAssemblyId: map['subAssemblyId'] as int?,
      taskType: (map['taskType'] as String?) ?? '',
      timeCategory: (map['timeCategory'] as String?) ?? '',
      timeValue: (map['timeValue'] as int?) ?? 0,
      requiredParts: _requiredPartsFromMapValue(
        map['requiredParts'] ?? map['requiredPartsJson'],
      ),
    );
  }

  static List<RequiredPart> _requiredPartsFromMapValue(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((row) => row.cast<Object?, Object?>())
          .map((row) => RequiredPart.fromMap(row))
          .where((part) => !part.isEmpty)
          .toList(growable: false);
    }

    if (value is String) {
      final raw = value.trim();
      if (raw.isEmpty) {
        return const [];
      }

      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((row) => row.cast<Object?, Object?>())
              .map((row) => RequiredPart.fromMap(row))
              .where((part) => !part.isEmpty)
              .toList(growable: false);
        }
      } catch (_) {
        return const [];
      }
    }

    return const [];
  }

  MaintenanceTask copyWith({
    int? id,
    int? subAssemblyId,
    String? taskType,
    String? timeCategory,
    int? timeValue,
    List<RequiredPart>? requiredParts,
  }) {
    return MaintenanceTask(
      id: id ?? this.id,
      subAssemblyId: subAssemblyId ?? this.subAssemblyId,
      taskType: taskType ?? this.taskType,
      timeCategory: timeCategory ?? this.timeCategory,
      timeValue: timeValue ?? this.timeValue,
      requiredParts: requiredParts ?? this.requiredParts,
    );
  }
}

class RequiredPart {
  const RequiredPart({
    this.oemPn = '',
    this.vendorPn = '',
    this.vendorName = '',
    this.vendorUrl = '',
    this.vendorPhoneNumber = '',
    this.estimatedLeadTime = '',
  });

  final String oemPn;
  final String vendorPn;
  final String vendorName;
  final String vendorUrl;
  final String vendorPhoneNumber;
  final String estimatedLeadTime;

  bool get isEmpty =>
      oemPn.trim().isEmpty &&
      vendorPn.trim().isEmpty &&
      vendorName.trim().isEmpty &&
      vendorUrl.trim().isEmpty &&
      vendorPhoneNumber.trim().isEmpty &&
      estimatedLeadTime.trim().isEmpty;

  bool get isComplete =>
      oemPn.trim().isNotEmpty &&
      vendorPn.trim().isNotEmpty &&
      vendorName.trim().isNotEmpty &&
      vendorUrl.trim().isNotEmpty &&
      vendorPhoneNumber.trim().isNotEmpty &&
      estimatedLeadTime.trim().isNotEmpty;

  Map<String, Object?> toMap() {
    return {
      'oemPn': oemPn,
      'vendorPn': vendorPn,
      'vendorName': vendorName,
      'vendorUrl': vendorUrl,
      'vendorPhoneNumber': vendorPhoneNumber,
      'estimatedLeadTime': estimatedLeadTime,
    };
  }

  factory RequiredPart.fromMap(Map<Object?, Object?> map) {
    return RequiredPart(
      oemPn: (map['oemPn'] as String?) ?? '',
      vendorPn: (map['vendorPn'] as String?) ?? '',
      vendorName: (map['vendorName'] as String?) ?? '',
      vendorUrl: (map['vendorUrl'] as String?) ?? '',
      vendorPhoneNumber: (map['vendorPhoneNumber'] as String?) ?? '',
      estimatedLeadTime: (map['estimatedLeadTime'] as String?) ?? '',
    );
  }

  RequiredPart copyWith({
    String? oemPn,
    String? vendorPn,
    String? vendorName,
    String? vendorUrl,
    String? vendorPhoneNumber,
    String? estimatedLeadTime,
  }) {
    return RequiredPart(
      oemPn: oemPn ?? this.oemPn,
      vendorPn: vendorPn ?? this.vendorPn,
      vendorName: vendorName ?? this.vendorName,
      vendorUrl: vendorUrl ?? this.vendorUrl,
      vendorPhoneNumber: vendorPhoneNumber ?? this.vendorPhoneNumber,
      estimatedLeadTime: estimatedLeadTime ?? this.estimatedLeadTime,
    );
  }
}

class MachineDetailHistoryEntry {
  const MachineDetailHistoryEntry({
    this.id,
    required this.machineId,
    required this.operatingHours,
    required this.idleHours,
    required this.lastCheckDate,
    required this.recordedAtUtc,
  });

  final int? id;
  final int machineId;
  final String operatingHours;
  final String idleHours;
  final String lastCheckDate;
  final String recordedAtUtc;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'machineId': machineId,
      'operatingHours': operatingHours,
      'idleHours': idleHours,
      'lastCheckDate': lastCheckDate,
      'recordedAtUtc': recordedAtUtc,
    };
  }

  factory MachineDetailHistoryEntry.fromMap(Map<String, Object?> map) {
    return MachineDetailHistoryEntry(
      id: map['id'] as int?,
      machineId: (map['machineId'] as int?) ?? 0,
      operatingHours: (map['operatingHours'] as String?) ?? '',
      idleHours:
          (map['idleHours'] as String?) ?? (map['idolHours'] as String?) ?? '',
      lastCheckDate: (map['lastCheckDate'] as String?) ?? '',
      recordedAtUtc: (map['recordedAtUtc'] as String?) ?? '',
    );
  }
}

class SubAssemblyDetailHistoryEntry {
  const SubAssemblyDetailHistoryEntry({
    this.id,
    required this.subAssemblyId,
    required this.operatingHours,
    required this.idleHours,
    required this.recordedAtUtc,
  });

  final int? id;
  final int subAssemblyId;
  final String operatingHours;
  final String idleHours;
  final String recordedAtUtc;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subAssemblyId': subAssemblyId,
      'operatingHours': operatingHours,
      'idleHours': idleHours,
      'recordedAtUtc': recordedAtUtc,
    };
  }

  factory SubAssemblyDetailHistoryEntry.fromMap(Map<String, Object?> map) {
    return SubAssemblyDetailHistoryEntry(
      id: map['id'] as int?,
      subAssemblyId: (map['subAssemblyId'] as int?) ?? 0,
      operatingHours: (map['operatingHours'] as String?) ?? '',
      idleHours:
          (map['idleHours'] as String?) ?? (map['idolHours'] as String?) ?? '',
      recordedAtUtc: (map['recordedAtUtc'] as String?) ?? '',
    );
  }
}

class WorkOrderStatusEntry {
  const WorkOrderStatusEntry({
    this.id,
    required this.subAssemblyId,
    required this.status,
    required this.enteredAtUtc,
    this.isRescheduled = false,
    this.isLicensedWork = false,
    this.notes = '',
  });

  final int? id;
  final int subAssemblyId;
  final String status;
  final String enteredAtUtc;
  final bool isRescheduled;
  final bool isLicensedWork;
  final String notes;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subAssemblyId': subAssemblyId,
      'status': status,
      'enteredAtUtc': enteredAtUtc,
      'isRescheduled': isRescheduled ? 1 : 0,
      'isLicensedWork': isLicensedWork ? 1 : 0,
      'notes': notes,
    };
  }

  factory WorkOrderStatusEntry.fromMap(Map<String, Object?> map) {
    return WorkOrderStatusEntry(
      id: map['id'] as int?,
      subAssemblyId: (map['subAssemblyId'] as int?) ?? 0,
      status: (map['status'] as String?) ?? '',
      enteredAtUtc: (map['enteredAtUtc'] as String?) ?? '',
      isRescheduled: ((map['isRescheduled'] as num?) ?? 0) == 1,
      isLicensedWork: ((map['isLicensedWork'] as num?) ?? 0) == 1,
      notes: (map['notes'] as String?) ?? '',
    );
  }
}

class WorkOrderTaskOutcomeEntry {
  const WorkOrderTaskOutcomeEntry({
    this.id,
    required this.subAssemblyId,
    required this.taskId,
    required this.outcome,
    this.notes = '',
    required this.enteredAtUtc,
  });

  final int? id;
  final int subAssemblyId;
  final int taskId;
  final String outcome;
  final String notes;
  final String enteredAtUtc;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subAssemblyId': subAssemblyId,
      'taskId': taskId,
      'outcome': outcome,
      'notes': notes,
      'enteredAtUtc': enteredAtUtc,
    };
  }

  factory WorkOrderTaskOutcomeEntry.fromMap(Map<String, Object?> map) {
    return WorkOrderTaskOutcomeEntry(
      id: map['id'] as int?,
      subAssemblyId: (map['subAssemblyId'] as int?) ?? 0,
      taskId: (map['taskId'] as int?) ?? 0,
      outcome: (map['outcome'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      enteredAtUtc: (map['enteredAtUtc'] as String?) ?? '',
    );
  }
}

class WorkOrderReport {
  const WorkOrderReport({
    required this.id,
    required this.subAssemblyId,
    required this.machineName,
    required this.subAssemblyName,
    required this.status,
    required this.assignedEmployees,
    required this.notes,
    required this.enteredAtUtc,
  });

  final int id;
  final int subAssemblyId;
  final String machineName;
  final String subAssemblyName;
  final String status;
  final List<String> assignedEmployees;
  final String notes;
  final String enteredAtUtc;
}

class ContractorCompany {
  const ContractorCompany({
    this.id,
    required this.companyName,
    this.address = '',
    this.phoneNumber = '',
    this.faxNumber = '',
    this.companyUrl = '',
    this.matchedSkills = const [],
    this.matchedLicenses = const [],
  });

  final int? id;
  final String companyName;
  final String address;
  final String phoneNumber;
  final String faxNumber;
  final String companyUrl;
  final List<String> matchedSkills;
  final List<String> matchedLicenses;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'companyName': companyName,
      'address': address,
      'phoneNumber': phoneNumber,
      'faxNumber': faxNumber,
      'companyUrl': companyUrl,
      'matchedSkills': matchedSkills.join('|'),
      'matchedLicenses': matchedLicenses.join('|'),
    };
  }

  factory ContractorCompany.fromMap(Map<String, Object?> map) {
    final skillsRaw = (map['matchedSkills'] as String?) ?? '';
    final licensesRaw = (map['matchedLicenses'] as String?) ?? '';
    return ContractorCompany(
      id: map['id'] as int?,
      companyName: (map['companyName'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
      faxNumber: (map['faxNumber'] as String?) ?? '',
      companyUrl: (map['companyUrl'] as String?) ?? '',
      matchedSkills: skillsRaw
          .split('|')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      matchedLicenses: licensesRaw
          .split('|')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
    );
  }

  ContractorCompany copyWith({
    int? id,
    String? companyName,
    String? address,
    String? phoneNumber,
    String? faxNumber,
    String? companyUrl,
    List<String>? matchedSkills,
    List<String>? matchedLicenses,
  }) {
    return ContractorCompany(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      faxNumber: faxNumber ?? this.faxNumber,
      companyUrl: companyUrl ?? this.companyUrl,
      matchedSkills: matchedSkills ?? this.matchedSkills,
      matchedLicenses: matchedLicenses ?? this.matchedLicenses,
    );
  }
}

class ContractorEmployeeContact {
  const ContractorEmployeeContact({
    this.id,
    required this.contractorCompanyId,
    required this.fullName,
    this.email = '',
    this.phoneNumber = '',
  });

  final int? id;
  final int contractorCompanyId;
  final String fullName;
  final String email;
  final String phoneNumber;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'contractorCompanyId': contractorCompanyId,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
    };
  }

  factory ContractorEmployeeContact.fromMap(Map<String, Object?> map) {
    return ContractorEmployeeContact(
      id: map['id'] as int?,
      contractorCompanyId: (map['contractorCompanyId'] as int?) ?? 0,
      fullName: (map['fullName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phoneNumber: (map['phoneNumber'] as String?) ?? '',
    );
  }

  ContractorEmployeeContact copyWith({
    int? id,
    int? contractorCompanyId,
    String? fullName,
    String? email,
    String? phoneNumber,
  }) {
    return ContractorEmployeeContact(
      id: id ?? this.id,
      contractorCompanyId: contractorCompanyId ?? this.contractorCompanyId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
