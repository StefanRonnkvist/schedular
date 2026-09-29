# Architecture

Schedular's `lib/` is organized into three conceptual layers. This file maps every
file to its layer so the structure is discoverable without reading the code.

> **Note:** these are conceptual layers, not physical directories. The whole app is a
> single Dart library (see "Single-library constraint" below), so the files are flat in
> `lib/src/`. Folding them into real directories with `import`/`export` is a future
> migration, tracked under "Known structural debt".

## Entry point

| File | Lines | Role |
| --- | --- | --- |
| `main.dart` | 166 | `main()`, FFI database bootstrap, shared catalog constants, all `part` declarations |
| `splash_screen.dart` | 169 | Animated splash shown before the shell mounts |

## Domain layer — pure data, no I/O

| File | Lines | Role |
| --- | --- | --- |
| `src/models.dart` | 839 | `Machine`, `SubAssembly`, `MaintenanceTask`, `RequiredPart`, `Employee`, `ContractorCompany`, `ContractorEmployeeContact`, work-order status/outcome entries, history entries |
| `src/drafts.dart` | 330 | Mutable form-state wrappers: `MachineDraft`, `SubAssemblyDraft`, `MaintenanceTaskDraft`, `RequiredPartDraft` |
| `db_registry_helpers.dart` | 1128 | Canonical `CREATE TABLE` statements, table-name constants, `dbVersion` (currently 30) |

## Data layer — `MachineDatabase` and its extensions

`MachineDatabase` (`src/machine_database.dart`) is a singleton over
`_DatabaseConnectionManager`. Its public methods are one-line forwarders into the
extension files below.

| File | Lines | Role |
| --- | --- | --- |
| `src/machine_database.dart` | 1875 | Singleton, connection manager, schema migrations, health check, public forwarders, backup serialization |
| `src/machine_database_machines.dart` | 551 | Machine / sub-assembly / task CRUD |
| `src/machine_database_employees.dart` | 564 | Employee CRUD, skills, licenses |
| `src/machine_database_contractors.dart` | 136 | Contractor companies and their contacts |
| `src/machine_database_work_orders.dart` | 248 | Work-order status and task outcomes |
| `src/machine_database_catalogs.dart` | 452 | Catalog lookups (component types, categories) |
| `src/machine_database_backup_csv.dart` | 166 | JSON backup import/export, CSV template generation and import |
| `src/machine_database_helpers.dart` | 58 | CSV serialize/parse primitives |

> Renamed from `machine_database_venders.dart`. The file holds **contractor companies**,
> not parts vendors — `vendorPn` / `vendorName` / `vendorUrl` on `RequiredPart` are a
> separate, correctly-spelled concept.

## UI layer — `_MachineEntryPageState` and its extensions

`_MachineEntryPageState` (`src/machine_entry_page.dart`) is a single large state object
owning ~40 `TextEditingController`s, theme, tab order, list caches, and database error
state. Each file below is an `extension ... on _MachineEntryPageState`.

| File | Lines | Tab / concern |
| --- | --- | --- |
| `src/machine_entry_page.dart` | 4266 | Shell state, tab routing, Help tab, Settings tab, startup and recovery logic |
| `src/app_shell.dart` | 324 | `MainApp`, `MaterialApp` wrapper, theme resolution, enums (`_AppTab`, `InitialDatabaseSetupAction`) |
| `src/machine_entry_page_forms.dart` | 2847 | Machine / sub-assembly / task entry forms and field visibility |
| `src/machine_entry_page_actions.dart` | 2029 | Shared actions, dialogs, PDF export, database actions |
| `src/machine_entry_page_work_orders.dart` | 1450 | Work Orders tab: assignment, qualification matching, outcomes |
| `src/machine_entry_page_employees.dart` | 1426 | Employees tab |
| `src/machine_entry_page_due.dart` | 1069 | Schedule (maintenance due) tab and detail drafts |
| `src/machine_entry_page_calendar.dart` | 869 | Forecast tab: bucketed workload and parts demand |
| `src/machine_entry_page_contractors.dart` | 790 | Contractors tab |
| `src/machine_entry_page_vendors.dart` | 648 | Vendors tab: parts grouped by supplier |
| `src/machine_entry_page_import_export.dart` | 275 | CSV save, import, and template export |
| `src/machine_entry_page_reports.dart` | 286 | Reports tab: status grouping and PDF output |

### Contact / submissions

| File | Lines | Role |
| --- | --- | --- |
| `contact/contact_page.dart` | 605 | Support contact form (posts to a remote endpoint) |
| `contact/submissions_csv_page.dart` | 290 | Submitted feedback rendered as CSV cards |

## Single-library constraint

`main.dart` declares all 23 `part` files. Consequences:

- They share **one** import set and **one** scope. A private name such as `_AppTab`
  (declared in `app_shell.dart`) is directly visible in `machine_entry_page.dart`.
- Extensions in `part` files can only be private to the *library*, not to the *file*.
  That is why `MachineDatabase` needs public forwarders — see below.
- No file can be analyzed, tested, or refactored in isolation.

## Known structural debt

Ordered by value, highest first.

1. **The forwarder layer.** `machine_database.dart` declares ~40 public methods that do
   nothing but call a private `*_Impl` in a sibling file. The signature and the body live
   in different files with no compiler enforcement keeping them in sync. Fix: make the
   `*_Impl` extension members public and call the extension directly, deleting the
   forwarders.

2. **One 4,300-line state object.** `_MachineEntryPageState` owns controllers, theme,
   navigation, and data caches together. Extract the form controllers and the
   theme/tab-order concerns into their own holders. Behavior-preserving and testable.

3. **Flat `lib/src/`.** The three layers above are conceptual only. A real split needs
   `import`/`export` and careful handling of the shared private scope.

4. **No tests.** `test/` is empty, so every refactor is verified only by the analyzer and
   by hand. Adding round-trip tests for backup serialization and CSV parse/serialize
   would make the rest of this list safe to execute.
