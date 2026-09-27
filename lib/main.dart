import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, Platform, Process;
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'contact/contact_page.dart';
import 'contact/submissions_csv_page.dart';
import 'splash_screen.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'db_registry_helpers.dart';

part 'src/models.dart';
part 'src/drafts.dart';

part 'src/machine_database.dart';
part 'src/machine_database_employees.dart';
part 'src/machine_database_venders.dart';
part 'src/machine_database_catalogs.dart';
part 'src/machine_database_machines.dart';
part 'src/machine_database_helpers.dart';
part 'src/machine_database_work_orders.dart';
part 'src/machine_database_backup_csv.dart';

part 'src/machine_entry_page.dart';
part 'src/app_shell.dart';
part 'src/machine_entry_page_actions.dart';
part 'src/machine_entry_page_reports.dart';
part 'src/machine_entry_page_due.dart';
part 'src/machine_entry_page_employees.dart';
part 'src/machine_entry_page_import_export.dart';
part 'src/machine_entry_page_forms.dart';
part 'src/machine_entry_page_contractors.dart';
part 'src/machine_entry_page_vendors.dart';
part 'src/machine_entry_page_work_orders.dart';
part 'src/machine_entry_page_calendar.dart';

const List<String> _maintenanceTaskTypes = [
  'Check',
  'Align',
  'Adjust',
  'Clean',
  'Lubricate',
  'Replace',
];

const List<String> _maintenanceTimeCategories = [
  'Hours',
  'Days',
  'Weeks',
  'Months',
  'Quarters',
  'Semi-Annual',
  'Annual',
  'Biannual',
  'Years',
];

const List<String> _maintenanceSuperCategory = [
  'Assembly Brake',
  'Assembly Burner',
  'Assembly Clutch',
  'Assembly Cooling',
  'Assembly Electrical',
  'Assembly Electronic',
  'Assembly Fluid',
  'Assembly Gas',
  'Assembly Heating',
  'Assembly Hydraulic',
  'Assembly Mechanical',
  'Assembly Pneumatic',
  'Assembly Safety',
  'Assembly Ventilation',
];

const List<String> _subCategories = [
  'Automatic Tool Changer',
  'Actuator',
  'Backup Battery',
  'Bearings',
  'Belts',
  'Bushings',
  'Chains',
  'Circuit Breaker',
  'Contactor',
  'Control Board',
  'Display Unit',
  'Drainage',
  'Emergency Stop',
  'Encoder',
  'Fan',
  'Filter',
  'Firmware',
  'Fluid',
  'Fuse',
  'Gearbox',
  'Harness',
  'Lubricant',
  'Machine Control Unit',
  'Module',
  'Motor',
  'Pan',
  'Power Unit',
  'Pump',
  'Relay',
  'Seal',
  'Sensor',
  'Sprocket',
  'Switch',
  'System Parameters',
  'Thermostat',
  'Transformer',
  'Valve',
];

Duration databaseLoadInitialTimeout = const Duration(seconds: 8);
Duration databaseLoadRetryTimeout = const Duration(seconds: 12);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const _AppBootstrap());
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return const MainApp();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(
        onFinished: () {
          setState(() {
            _showSplash = false;
          });
        },
      ),
    );
  }
}
