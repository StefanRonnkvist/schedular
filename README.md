# Schedular

Schedular is a local-first maintenance operations app for planning, assigning, executing, and reporting machine maintenance. It connects assets, recurring tasks, qualified labor, required parts, vendors, and work-order outcomes in one responsive Flutter application.

## Features

- Model machines, sub-assemblies, and recurring maintenance tasks.
- Record required parts, OEM and vendor part numbers, skills, and licenses.
- Manage internal employees and external contractor companies and contacts.
- Review maintenance due dates and forecast workload and parts demand.
- Assign the next five days of work with qualification-aware matching.
- Track work-order status, notes, assignments, and outcomes.
- Group required parts by vendor, open vendor links, and export purchasing CSV files.
- Generate operational PDFs and work-order status reports.
- Customize theme, tab order, and required data-entry fields.
- Back up and restore the local database with JSON and exchange bulk data with CSV.
- Diagnose database location, record counts, schema health, and recovery options in Help.

## Workflow

1. Define assets and maintenance tasks in **Machines**.
2. Add qualified labor in **Employees** and **Contractors**.
3. Review due work in **Schedule** and longer-term demand in **Forecast**.
4. Assign and complete work in **Work Orders**.
5. Review outcomes in **Reports** and parts demand in **Vendors**.
6. Manage exports, backups, restore, preferences, and database actions in **Settings**.

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
| Help | Follow setup and recovery guidance and inspect database diagnostics. |

## Data and Privacy

Schedular stores operational data in a local SQLite database. It does not require a hosted maintenance service or account to manage that data. Backups are user-initiated JSON files; CSV and PDF files are created only when an export action is used. Export a JSON backup before bulk imports, major edits, or resetting the local database.

The database is not described as encrypted at rest. Protect the device and any exported files according to your organization's data-handling requirements.

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

Create a platform release with the corresponding Flutter build command, or use the VS Code release tasks included in the workspace.