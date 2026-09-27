part of 'package:schedular/main.dart';

enum MachineAction { edit, delete }

enum InitialDatabaseSetupAction {
  buildCompleteDb,
  buildMachineDb,
  buildEmployeeDb,
  buildVenderDb,
  uploadMachineCsv,
  uploadEmployeeCsv,
  uploadVenderCsv,
  addMachine,
}

enum _EmployeeSortMode { nameAsc, nameDesc, skillCountDesc }

enum _MachineField {
  name,
  modelName,
  modelNumber,
  serialNumber,
  location,
  manufacturer,
  operatingHours,
  idleHours,
  lastCheckDate,
  maintenanceDocumentName,
  maintenanceDocumentNumber,
  maintenancePublisher;

  String get label => switch (this) {
    _MachineField.name => 'Machine Name',
    _MachineField.modelName => 'Model Name',
    _MachineField.modelNumber => 'Model Number',
    _MachineField.serialNumber => 'Serial Number',
    _MachineField.location => 'Location',
    _MachineField.manufacturer => 'Manufacturer',
    _MachineField.operatingHours => 'Operating Hours',
    _MachineField.idleHours => 'Idle Hours',
    _MachineField.lastCheckDate => 'Last Check Date',
    _MachineField.maintenanceDocumentName => 'Maintenance Document Name',
    _MachineField.maintenanceDocumentNumber => 'Maintenance Document Number',
    _MachineField.maintenancePublisher => 'Maintenance Publisher',
  };
}

enum _SubAssemblyField {
  name,
  modelName,
  modelNumber,
  serialNumber,
  location,
  manufacturer,
  operatingHours,
  idleHours,
  maintenanceDocumentName,
  maintenanceDocumentNumber,
  maintenancePublisher;

  String get label => switch (this) {
    _SubAssemblyField.name => 'Sub-Assembly Name',
    _SubAssemblyField.modelName => 'Model Name',
    _SubAssemblyField.modelNumber => 'Model Number',
    _SubAssemblyField.serialNumber => 'Serial Number',
    _SubAssemblyField.location => 'Location',
    _SubAssemblyField.manufacturer => 'Manufacturer',
    _SubAssemblyField.operatingHours => 'Operating Hours',
    _SubAssemblyField.idleHours => 'Idle Hours',
    _SubAssemblyField.maintenanceDocumentName => 'Maintenance Document Name',
    _SubAssemblyField.maintenanceDocumentNumber =>
      'Maintenance Document Number',
    _SubAssemblyField.maintenancePublisher => 'Maintenance Publisher',
  };
}

enum _AppTab {
  addMachine,
  machinesList,
  employees,
  contractors,
  vendors,
  maintenanceDue,
  workOrders,
  calendar,
  editMachines,
  reports,
  settings,
  information,
  help,
}

class _WorkOrderItem {
  _WorkOrderItem({
    required this.machine,
    required this.subAssembly,
    DateTime? projectedNextDate,
    int? daysUntilDue,
  }) : projectedNextDate = projectedNextDate ?? DateTime(2000, 1, 1),
       daysUntilDue = daysUntilDue ?? 0;

  final Machine machine;
  final SubAssembly subAssembly;
  final DateTime projectedNextDate;
  final int daysUntilDue;
}

class _EstimatedTaskItem {
  _EstimatedTaskItem({
    required this.machine,
    required this.subAssembly,
    required this.task,
    DateTime? projectedDate,
    int? daysUntilDue,
  }) : projectedDate = projectedDate ?? DateTime(2000, 1, 1),
       daysUntilDue = daysUntilDue ?? 0;

  final Machine machine;
  final SubAssembly subAssembly;
  final MaintenanceTask task;
  final DateTime projectedDate;
  final int daysUntilDue;
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  static const String _windowsThemeRegistryKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize';
  static const String _windowsAppsUseLightThemeValue = 'AppsUseLightTheme';
  static const String _themePreferenceKey = 'themeMode';
  static const String _legacyThemePreferenceKey = 'isDarkMode';
  ThemeMode _themeMode = ThemeMode.system;
  Brightness? _windowsSystemBrightness;

  bool get _isWindowsDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows || Platform.isWindows);

  ThemeMode get _effectiveThemeMode {
    if (_themeMode != ThemeMode.system || !_isWindowsDesktop) {
      return _themeMode;
    }

    switch (_windowsSystemBrightness) {
      case Brightness.light:
        return ThemeMode.light;
      case Brightness.dark:
        return ThemeMode.dark;
      case null:
        return ThemeMode.system;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
    WidgetsBinding.instance.addObserver(this);

    if (_isWindowsDesktop) {
      unawaited(_refreshWindowsSystemBrightness());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isWindowsDesktop) {
      unawaited(_refreshWindowsSystemBrightness());
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_isWindowsDesktop) {
      unawaited(_refreshWindowsSystemBrightness());
    }
  }

  Future<void> _loadThemePreference() async {
    ThemeMode resolvedThemeMode;
    try {
      final preferences = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 8),
      );
      final savedThemeMode = preferences.getString(_themePreferenceKey);

      switch (savedThemeMode) {
        case 'light':
          resolvedThemeMode = ThemeMode.light;
        case 'dark':
          resolvedThemeMode = ThemeMode.dark;
        case 'system':
          resolvedThemeMode = ThemeMode.system;
        default:
          final legacyIsDarkMode = preferences.getBool(
            _legacyThemePreferenceKey,
          );
          resolvedThemeMode = legacyIsDarkMode == null
              ? ThemeMode.system
              : (legacyIsDarkMode ? ThemeMode.dark : ThemeMode.light);
      }
    } catch (_) {
      // Prevent permanent splash-spinner if preferences are unavailable.
      resolvedThemeMode = ThemeMode.system;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _themeMode = resolvedThemeMode;
    });

    if (_isWindowsDesktop && resolvedThemeMode == ThemeMode.system) {
      unawaited(_refreshWindowsSystemBrightness());
    }
  }

  Future<void> _refreshWindowsSystemBrightness() async {
    if (!_isWindowsDesktop) {
      return;
    }

    final brightness = await _readWindowsAppsBrightness();
    if (!mounted || brightness == null) {
      return;
    }

    if (_windowsSystemBrightness != brightness) {
      setState(() {
        _windowsSystemBrightness = brightness;
      });
    }
  }

  Future<Brightness?> _readWindowsAppsBrightness() async {
    try {
      final result = await Process.run('reg', [
        'query',
        _windowsThemeRegistryKey,
        '/v',
        _windowsAppsUseLightThemeValue,
      ]).timeout(const Duration(seconds: 2));

      if (result.exitCode != 0) {
        return null;
      }

      final output = result.stdout?.toString() ?? '';
      final regex = RegExp(r'AppsUseLightTheme\s+REG_DWORD\s+0x([0-9a-fA-F]+)');
      final match = regex.firstMatch(output);
      if (match == null) {
        return null;
      }

      final rawValue = int.tryParse(match.group(1)!, radix: 16);
      if (rawValue == null) {
        return null;
      }

      return rawValue == 0 ? Brightness.dark : Brightness.light;
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistThemePreference(ThemeMode themeMode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_themePreferenceKey, themeMode.name);
    await preferences.remove(_legacyThemePreferenceKey);
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });

    if (_isWindowsDesktop && themeMode == ThemeMode.system) {
      unawaited(_refreshWindowsSystemBrightness());
    }

    _persistThemePreference(themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Scheduler',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: _effectiveThemeMode,
      home: MachineEntryPage(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}
