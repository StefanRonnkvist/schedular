// ignore_for_file: invalid_use_of_protected_member

part of 'package:schedular/main.dart';

extension _MachineEntryPageImportExportExtension on _MachineEntryPageState {
  Future<void> _saveCsvFile({
    required String dialogTitle,
    required String fileName,
    required String successMessage,
    required String csvContent,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(csvContent));

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );
    if (result == null) {
      return;
    }
    final savedPath = result.isScheme('file')
        ? result.toFilePath()
        : result.toString();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successMessage: $savedPath'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> exportEmployeeCsvTemplate() async {
    try {
      final csvContent = await MachineDatabase.instance
          .exportEmployeeTemplateToCsv();
      if (csvContent == null || csvContent.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create employee CSV template.'),
          ),
        );
        return;
      }

      await _saveCsvFile(
        dialogTitle: 'Save Employee CSV Template',
        fileName: 'employee_template.csv',
        successMessage: 'Employee CSV template saved to',
        csvContent: csvContent,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to create employee CSV template.', error);
    }
  }

  Future<void> exportMachineCsvTemplate() async {
    try {
      final csvContent = await MachineDatabase.instance
          .exportMachineTemplateToCsv();
      if (csvContent == null || csvContent.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create machine CSV template.'),
          ),
        );
        return;
      }

      await _saveCsvFile(
        dialogTitle: 'Save Machine CSV Template',
        fileName: 'machine_template.csv',
        successMessage: 'Machine CSV template saved to',
        csvContent: csvContent,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to create machine CSV template.', error);
    }
  }

  Future<void> exportContractorCsvTemplate() async {
    try {
      final csvContent = await MachineDatabase.instance
          .exportContractorTemplateToCsv();
      if (csvContent == null || csvContent.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create contractor CSV template.'),
          ),
        );
        return;
      }

      await _saveCsvFile(
        dialogTitle: 'Save Contractor CSV Template',
        fileName: 'contractor_template.csv',
        successMessage: 'Contractor CSV template saved to',
        csvContent: csvContent,
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to create contractor CSV template.', error);
    }
  }

  /// Imports employees from CSV file.
  /// Opens file picker to select the CSV file.
  Future<void> importEmployeesFromCsv() async {
    try {
      // Open file picker to select CSV
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Employees CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (file == null) {
        return; // User cancelled
      }

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        return;
      }

      final csvContent = utf8.decode(fileBytes);

      // Import employees
      final importedCount = await MachineDatabase.instance
          .importEmployeesFromCsv(csvContent);

      if (!mounted) return;

      if (importedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No employees were imported.')),
        );
        return;
      }

      // Reload employees data
      await _reloadEmployeeData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$importedCount employees imported successfully.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to import employees.', error);
    }
  }

  /// Imports machines from CSV file.
  /// Opens file picker to select the CSV file.
  Future<void> importMachinesFromCsv() async {
    try {
      // Open file picker to select CSV
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Machines CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (file == null) {
        return; // User cancelled
      }

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        return;
      }

      final csvContent = utf8.decode(fileBytes);

      // Import machines
      final importedCount = await MachineDatabase.instance
          .importMachinesFromCsv(csvContent);

      if (!mounted) return;

      if (importedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No machines were imported.')),
        );
        return;
      }

      // Reload machines data
      await _loadMachines(seedSampleData: false);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$importedCount machines imported successfully.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to import machines.', error);
    }
  }

  Future<void> importContractorsFromCsv() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Select Contractors CSV',
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (file == null) {
        return;
      }

      final fileBytes = await file.readAsBytes();
      if (fileBytes.isEmpty) {
        return;
      }

      final csvContent = utf8.decode(fileBytes);
      final importedCount = await MachineDatabase.instance
          .importContractorsFromCsv(csvContent);

      if (!mounted) return;

      if (importedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No contractors were imported.')),
        );
        return;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$importedCount contractor companies imported successfully.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to import contractors.', error);
    }
  }

  /// Helper method to reload employee data.
  Future<void> _reloadEmployeeData() async {
    try {
      await _loadEmployees();
      await _refreshSkillTypes();
    } catch (error) {
      if (!mounted) return;
      _showErrorSnackBar('Failed to reload employees.', error);
    }
  }
}
