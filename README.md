# Schedular

Schedular is a local-first maintenance operations app for planning, assigning, executing, and reporting machine maintenance. It connects assets, recurring tasks, qualified labor, required parts, vendors, and work-order outcomes in one responsive Flutter application.

Data lives on the device. There is no hosted maintenance service, no account requirement, and no operational telemetry — the only network call in the app is the optional **Information** tab contact form.

## Features

- Model machines, sub-assemblies, and recurring maintenance tasks with configurable intervals.
- Record required parts, OEM and vendor part numbers, skills, and license requirements.
- Manage internal employees and external contractor companies, contacts, capabilities, and qualifications.
- Review maintenance due dates and forecast workload and parts demand by time bucket.
- Assign the next five days of work with qualification-aware matching.
- Record work-order outcomes (completed, bypassed, deferred, needs follow-up, cancelled) and report on stored statuses such as pending, work complete, partial, and bypass.
- Group required parts by vendor, open saved vendor links, and export purchasing CSV files.
- Generate operational PDFs and work-order status reports.
- Customize theme (system/light/dark), tab order, and which data-entry fields are required.
- Back up and restore the local database with JSON and exchange bulk data with CSV templates and uploads.
- Diagnose database location, record counts, schema health, and recovery options in Help.
- Submit feedback and review submissions from the **Information** tab.

## Workflow

1. Define assets and maintenance tasks in **Machines**.
2. Add qualified labor in **Employees** and **Contractors**.
3. Review due work in **Schedule** and longer-term demand in **Forecast**.
4. Assign and complete work in **Work Orders**.
5. Review outcomes in **Reports** and parts demand in **Vendors**.
6. Manage exports, backups, restore, preferences, and database actions in **Settings**.
7. Use **Information** for support contact and submitted feedback, and **Help** for guidance and diagnostics.

## Tabs

| Tab | Purpose |
| --- | --- |
| Machines | Create and maintain assets, sub-assemblies, tasks, intervals, parts, and requirements. |
| Employees | Manage internal technicians, skills, licenses, search, filtering, and sorting. |
| Contractors | Manage external companies, contacts, capabilities, skills, and licenses. |
| Vendors | Consolidate required parts by supplier, review usage, open links, and export CSV. |
| Schedule | Review maintenance due and the parts required for each task. |
| Work Orders | Assign near-term work, check qualifications, update status, and record outcomes. |
| Forecast | View future workload and parts demand by time bucket and export CSV. |
| Reports | Summarize work-order status, assignments, notes, and operational output. |
| Settings | Configure appearance, navigation, required fields, exports, and local data actions. |
| Information | Contact support and review submitted feedback entries. |
| Help | Follow setup and recovery guidance and inspect database diagnostics. |

Tab order is persisted per device and can be rearranged from **Settings > Customize Tab Order**.

## Architecture

- `lib/main.dart` — app entry point, FFI database bootstrap, shared catalog constants, and the `part` declarations that assemble the app.
- `lib/splash_screen.dart` — animated splash shown before the main shell.
- `lib/src/models.dart` — domain models for machines, sub-assemblies, tasks, people, vendors, and work orders.
- `lib/src/machine_database*.dart` — SQLite schema, migrations, queries, health checks, and backup/CSV import and export.
- `lib/src/machine_entry_page*.dart` — the tabbed shell and per-tab UI, split by concern (machines, employees, contractors, vendors, schedule, work orders, forecast, reports, import/export, forms, actions).
- `lib/contact/` — the Information tab contact form and submissions view.
- `lib/db_registry_helpers.dart` — the canonical `CREATE TABLE` statements and schema version.

Two conventions are worth knowing before editing:

- **The app is one Dart library.** `main.dart` declares all 23 `part` files, so they share a single import set and scope. A private name such as `_AppTab` (declared in `app_shell.dart`) is directly visible in `machine_entry_page.dart`. The upside is a small number of top-level imports; the cost is that no file can be analyzed or edited in isolation.
- **Most feature files are extensions on one state class.** For example `machine_entry_page_work_orders.dart` declares `extension ... on _MachineEntryPageState`, which is how per-tab logic is partitioned without splitting the state object.

`machine_entry_page.dart` is a misnomer in name only — it holds the shared shell state and helpers, not just a single page.

## Data and Privacy

Schedular stores operational data in a local SQLite database at schema version 30. It does not require a hosted maintenance service or account to manage that data. Backups are user-initiated JSON files; CSV and PDF files are created only when an export action is used. Export a JSON backup before bulk imports, major edits, or resetting the local database.

The database is not encrypted at rest. Protect the device and any exported files according to your organization's data-handling requirements.

If the app cannot locate or open the database at startup, it routes to the Help tab with setup and recovery guidance instead of failing silently. Initial loads are bounded by an 8-second timeout that reconnects and retries once for 12 seconds before the app reports a failure.

## Platforms

The Flutter project contains targets for Android, iOS, Windows, web, Linux, and macOS. Release automation in this repository currently covers Android APK and App Bundle, Windows and MSIX, and web builds.

## Development

Prerequisites:

- Flutter SDK compatible with Dart `^3.11.3`
- Platform toolchains for the targets you intend to build

Install dependencies and run the app:

```sh
flutter pub get
flutter run
```

Run static analysis:

```sh
flutter analyze
```

The repository currently contains no automated tests, so `flutter test` has nothing to execute and static analysis is the only automated check in place.

Release helper scripts live in `scripts/` and `tool/`:

| Script | Purpose |
| --- | --- |
| `scripts/build-release.ps1` | Orchestrates a full platform release. |
| `scripts/build-apk-release.ps1` | Build the Android APK release. |
| `scripts/bump-version.ps1` | Bump the app version across project files. |
| `scripts/cleanup-ephemerals.ps1` | Remove generated build and lock ephemerals. |
| `tool/build_release_appbundle.ps1` | Build the Android App Bundle release. |
| `tool/build_android_release.ps1` | Android release build helper. |
| `tool/preclean_android_release_locks.ps1` | Clear Android build locks before a release build. |
| `tool/dependency_snapshot.ps1` | Capture a dependency snapshot for triage. |

You can also use the VS Code release tasks in `.vscode/tasks.json`.