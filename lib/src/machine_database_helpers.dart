part of 'package:schedular/main.dart';

extension _MachineDatabaseHelpersExtension on MachineDatabase {
  /// Serializes [rows] as CSV, quoting fields that contain CSV delimiters and
  /// escaping embedded quotes by doubling them.
  String helpersGenerateCsv(List<List<String>> rows) {
    final buffer = StringBuffer();
    for (final row in rows) {
      final escapedRow = row.map((field) {
        if (field.contains(',') ||
            field.contains('\n') ||
            field.contains('"')) {
          return '"${field.replaceAll('"', '""')}"';
        }
        return field;
      }).toList();
      buffer.writeln(escapedRow.join(','));
    }
    return buffer.toString();
  }

  /// Parses line-oriented CSV content into rows and fields.
  ///
  /// Quoted commas and doubled quotes are supported. Records containing a
  /// quoted newline are not supported because input is split into lines first.
  List<List<String>> helpersParseCsvContent(String csvContent) {
    final rows = <List<String>>[];
    final lines = csvContent.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final row = <String>[];
      var currentField = StringBuffer();
      var inQuotes = false;
      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        final nextChar = i + 1 < line.length ? line[i + 1] : null;
        if (char == '"') {
          if (inQuotes && nextChar == '"') {
            currentField.write('"');
            i++;
          } else {
            inQuotes = !inQuotes;
          }
        } else if (char == ',' && !inQuotes) {
          row.add(currentField.toString());
          currentField.clear();
        } else {
          currentField.write(char);
        }
      }
      row.add(currentField.toString());
      if (row.isNotEmpty) {
        rows.add(row);
      }
    }
    return rows;
  }
}
