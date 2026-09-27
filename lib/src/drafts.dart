part of 'package:schedular/main.dart';

class MachineDraft {
  MachineDraft({Machine? machine})
    : nameController = TextEditingController(text: machine?.name ?? ''),
      modelNameController = TextEditingController(
        text: machine?.modelName ?? '',
      ),
      modelNumberController = TextEditingController(
        text: machine?.modelNumber ?? '',
      ),
      operatingHoursController = TextEditingController(
        text: machine?.operatingHours ?? '',
      ),
      idleHoursController = TextEditingController(
        text: machine?.idleHours ?? '',
      ),
      lastCheckDateController = TextEditingController(
        text: machine?.lastCheckDate ?? '',
      ),
      serialNumberController = TextEditingController(
        text: machine?.serialNumber ?? '',
      ),
      locationController = TextEditingController(text: machine?.location ?? ''),
      manufacturerController = TextEditingController(
        text: machine?.manufacturer ?? '',
      ),
      maintenanceDocumentNameController = TextEditingController(
        text: machine?.maintenanceDocumentName ?? '',
      ),
      maintenanceDocumentNumberController = TextEditingController(
        text: machine?.maintenanceDocumentNumber ?? '',
      ),
      maintenancePublisherController = TextEditingController(
        text: machine?.maintenancePublisher ?? '',
      ),
      requiresHvacLicense = machine?.requiresHvacLicense ?? false,
      requiresRefrigerationLicense =
          machine?.requiresRefrigerationLicense ?? false,
      requiresPlumberLicense = machine?.requiresPlumberLicense ?? false,
      requiresElectricianLicense = machine?.requiresElectricianLicense ?? false,
      requiresBoilerLicense = machine?.requiresBoilerLicense ?? false,
      additionalRequiredLicenses = Set<String>.from(
        machine?.additionalRequiredLicenses ?? const [],
      );

  final TextEditingController nameController;
  final TextEditingController modelNameController;
  final TextEditingController modelNumberController;
  final TextEditingController operatingHoursController;
  final TextEditingController idleHoursController;
  final TextEditingController lastCheckDateController;
  final TextEditingController serialNumberController;
  final TextEditingController locationController;
  final TextEditingController manufacturerController;
  final TextEditingController maintenanceDocumentNameController;
  final TextEditingController maintenanceDocumentNumberController;
  final TextEditingController maintenancePublisherController;
  bool requiresHvacLicense;
  bool requiresRefrigerationLicense;
  bool requiresPlumberLicense;
  bool requiresElectricianLicense;
  bool requiresBoilerLicense;
  final Set<String> additionalRequiredLicenses;

  Machine toMachine({int? id, List<SubAssembly> subAssemblies = const []}) {
    return Machine(
      id: id,
      name: nameController.text.trim(),
      modelName: modelNameController.text.trim(),
      modelNumber: modelNumberController.text.trim(),
      operatingHours: operatingHoursController.text.trim(),
      idleHours: idleHoursController.text.trim(),
      lastCheckDate: lastCheckDateController.text.trim(),
      serialNumber: serialNumberController.text.trim(),
      location: locationController.text.trim(),
      manufacturer: manufacturerController.text.trim(),
      maintenanceDocumentName: maintenanceDocumentNameController.text.trim(),
      maintenanceDocumentNumber: maintenanceDocumentNumberController.text
          .trim(),
      maintenancePublisher: maintenancePublisherController.text.trim(),
      requiresHvacLicense: requiresHvacLicense,
      requiresRefrigerationLicense: requiresRefrigerationLicense,
      requiresPlumberLicense: requiresPlumberLicense,
      requiresElectricianLicense: requiresElectricianLicense,
      requiresBoilerLicense: requiresBoilerLicense,
      additionalRequiredLicenses: additionalRequiredLicenses
          .map((license) => license.trim())
          .where((license) => license.isNotEmpty)
          .toList(growable: false),
      subAssemblies: subAssemblies,
    );
  }

  void clear() {
    nameController.clear();
    modelNameController.clear();
    modelNumberController.clear();
    operatingHoursController.clear();
    idleHoursController.clear();
    lastCheckDateController.clear();
    serialNumberController.clear();
    locationController.clear();
    manufacturerController.clear();
    maintenanceDocumentNameController.clear();
    maintenanceDocumentNumberController.clear();
    maintenancePublisherController.clear();
    requiresHvacLicense = false;
    requiresRefrigerationLicense = false;
    requiresPlumberLicense = false;
    requiresElectricianLicense = false;
    requiresBoilerLicense = false;
    additionalRequiredLicenses.clear();
  }

  void dispose() {
    nameController.dispose();
    modelNameController.dispose();
    modelNumberController.dispose();
    operatingHoursController.dispose();
    idleHoursController.dispose();
    lastCheckDateController.dispose();
    serialNumberController.dispose();
    locationController.dispose();
    manufacturerController.dispose();
    maintenanceDocumentNameController.dispose();
    maintenanceDocumentNumberController.dispose();
    maintenancePublisherController.dispose();
  }
}

class MaintenanceTaskDraft {
  MaintenanceTaskDraft({MaintenanceTask? task})
    : taskType = task?.taskType ?? _maintenanceTaskTypes.first,
      timeCategory = task?.timeCategory ?? _maintenanceTimeCategories.first,
      timeValueController = TextEditingController(
        text: '${(task?.timeValue ?? 0) > 0 ? task!.timeValue : 1}',
      ),
      requiredPartDrafts = (task?.requiredParts ?? const [])
          .map((part) => RequiredPartDraft(part: part))
          .toList(growable: true) {
    if (requiredPartDrafts.isEmpty) {
      requiredPartDrafts.add(RequiredPartDraft());
    }
  }

  String taskType;
  String timeCategory;
  final TextEditingController timeValueController;
  final List<RequiredPartDraft> requiredPartDrafts;

  int get timeValue => int.tryParse(timeValueController.text.trim()) ?? 1;

  MaintenanceTask toMaintenanceTask({int? id, int? subAssemblyId}) {
    return MaintenanceTask(
      id: id,
      subAssemblyId: subAssemblyId,
      taskType: taskType,
      timeCategory: timeCategory,
      timeValue: timeValue,
      requiredParts: requiredPartDrafts
          .map((partDraft) => partDraft.toRequiredPart())
          .where((part) => !part.isEmpty)
          .toList(growable: false),
    );
  }

  void dispose() {
    timeValueController.dispose();
    for (final partDraft in requiredPartDrafts) {
      partDraft.dispose();
    }
  }
}

class RequiredPartDraft {
  RequiredPartDraft({RequiredPart? part})
    : oemPnController = TextEditingController(text: part?.oemPn ?? ''),
      vendorPnController = TextEditingController(text: part?.vendorPn ?? ''),
      vendorNameController = TextEditingController(
        text: part?.vendorName ?? '',
      ),
      vendorUrlController = TextEditingController(text: part?.vendorUrl ?? ''),
      vendorPhoneNumberController = TextEditingController(
        text: part?.vendorPhoneNumber ?? '',
      ),
      estimatedLeadTimeController = TextEditingController(
        text: part?.estimatedLeadTime ?? '',
      );

  final TextEditingController oemPnController;
  final TextEditingController vendorPnController;
  final TextEditingController vendorNameController;
  final TextEditingController vendorUrlController;
  final TextEditingController vendorPhoneNumberController;
  final TextEditingController estimatedLeadTimeController;

  bool get isEmpty =>
      oemPnController.text.trim().isEmpty &&
      vendorPnController.text.trim().isEmpty &&
      vendorNameController.text.trim().isEmpty &&
      vendorUrlController.text.trim().isEmpty &&
      vendorPhoneNumberController.text.trim().isEmpty &&
      estimatedLeadTimeController.text.trim().isEmpty;

  bool get isComplete =>
      oemPnController.text.trim().isNotEmpty &&
      vendorPnController.text.trim().isNotEmpty &&
      vendorNameController.text.trim().isNotEmpty &&
      vendorUrlController.text.trim().isNotEmpty &&
      vendorPhoneNumberController.text.trim().isNotEmpty &&
      estimatedLeadTimeController.text.trim().isNotEmpty;

  RequiredPart toRequiredPart() {
    return RequiredPart(
      oemPn: oemPnController.text.trim(),
      vendorPn: vendorPnController.text.trim(),
      vendorName: vendorNameController.text.trim(),
      vendorUrl: vendorUrlController.text.trim(),
      vendorPhoneNumber: vendorPhoneNumberController.text.trim(),
      estimatedLeadTime: estimatedLeadTimeController.text.trim(),
    );
  }

  void dispose() {
    oemPnController.dispose();
    vendorPnController.dispose();
    vendorNameController.dispose();
    vendorUrlController.dispose();
    vendorPhoneNumberController.dispose();
    estimatedLeadTimeController.dispose();
  }
}

class SubAssemblyDraft {
  SubAssemblyDraft({SubAssembly? subAssembly})
    : nameController = TextEditingController(text: subAssembly?.name ?? ''),
      modelNameController = TextEditingController(
        text: subAssembly?.modelName ?? '',
      ),
      modelNumberController = TextEditingController(
        text: subAssembly?.modelNumber ?? '',
      ),
      operatingHoursController = TextEditingController(
        text: subAssembly?.operatingHours ?? '',
      ),
      idleHoursController = TextEditingController(
        text: subAssembly?.idleHours ?? '',
      ),
      serialNumberController = TextEditingController(
        text: subAssembly?.serialNumber ?? '',
      ),
      locationController = TextEditingController(
        text: subAssembly?.location ?? '',
      ),
      manufacturerController = TextEditingController(
        text: subAssembly?.manufacturer ?? '',
      ),
      maintenanceDocumentNameController = TextEditingController(
        text: subAssembly?.maintenanceDocumentName ?? '',
      ),
      maintenanceDocumentNumberController = TextEditingController(
        text: subAssembly?.maintenanceDocumentNumber ?? '',
      ),
      maintenancePublisherController = TextEditingController(
        text: subAssembly?.maintenancePublisher ?? '',
      ),
      superCategory = subAssembly?.superCategory ?? '',
      subCategory = subAssembly?.subCategory ?? '',
      maintenanceTaskDrafts = (subAssembly?.maintenanceTasks ?? const [])
          .map((task) => MaintenanceTaskDraft(task: task))
          .toList(growable: true);

  final TextEditingController nameController;
  final TextEditingController modelNameController;
  final TextEditingController modelNumberController;
  final TextEditingController operatingHoursController;
  final TextEditingController idleHoursController;
  final TextEditingController serialNumberController;
  final TextEditingController locationController;
  final TextEditingController manufacturerController;
  final TextEditingController maintenanceDocumentNameController;
  final TextEditingController maintenanceDocumentNumberController;
  final TextEditingController maintenancePublisherController;
  String superCategory;
  String subCategory;
  bool importDocFromParent = false;
  final List<MaintenanceTaskDraft> maintenanceTaskDrafts;

  SubAssembly toSubAssembly({int? id, int? machineId}) {
    return SubAssembly(
      id: id,
      machineId: machineId,
      name: nameController.text.trim(),
      modelName: modelNameController.text.trim(),
      modelNumber: modelNumberController.text.trim(),
      operatingHours: operatingHoursController.text.trim(),
      idleHours: idleHoursController.text.trim(),
      serialNumber: serialNumberController.text.trim(),
      location: locationController.text.trim(),
      manufacturer: manufacturerController.text.trim(),
      maintenanceDocumentName: maintenanceDocumentNameController.text.trim(),
      maintenanceDocumentNumber: maintenanceDocumentNumberController.text
          .trim(),
      maintenancePublisher: maintenancePublisherController.text.trim(),
      superCategory: superCategory,
      subCategory: subCategory,
      maintenanceTasks: maintenanceTaskDrafts
          .map((draft) => draft.toMaintenanceTask())
          .toList(growable: false),
    );
  }

  void dispose() {
    nameController.dispose();
    modelNameController.dispose();
    modelNumberController.dispose();
    operatingHoursController.dispose();
    idleHoursController.dispose();
    serialNumberController.dispose();
    locationController.dispose();
    manufacturerController.dispose();
    maintenanceDocumentNameController.dispose();
    maintenanceDocumentNumberController.dispose();
    maintenancePublisherController.dispose();
    for (final taskDraft in maintenanceTaskDrafts) {
      taskDraft.dispose();
    }
  }
}
