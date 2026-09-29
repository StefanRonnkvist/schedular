import 'package:flutter_test/flutter_test.dart';
import 'package:schedular/main.dart';

/// Tests for the pure CSV helpers.
///
/// These cover `helpersGenerateCsv` / `helpersParseCsvContent` in
/// `lib/src/machine_database_helpers.dart`, reached through the
/// `@visibleForTesting` seam on `MachineDatabase` because every member of
/// the app's single `part` library is otherwise private.
void main() {
  final db = MachineDatabase.instance;

  group('generateCsv', () {
    test('joins fields with commas and terminates rows with newlines', () {
      final csv = db.generateCsvForTesting(<List<String>>[
        <String>['id', 'name'],
        <String>['1', 'Air Compressor'],
      ]);

      expect(csv, 'id,name\n1,Air Compressor\n');
    });

    test('quotes fields containing a comma', () {
      final csv = db.generateCsvForTesting(<List<String>>[
        <String>['name', 'location'],
        <String>['Press', 'Building A, Floor 2'],
      ]);

      expect(csv, contains('"Building A, Floor 2"'));
    });

    test('quotes and doubles embedded quote characters', () {
      final csv = db.generateCsvForTesting(<List<String>>[
        <String>['note'],
        <String>['5" flange'],
      ]);

      expect(csv, contains('"5"" flange"'));
    });

    test('quotes fields containing a newline', () {
      final csv = db.generateCsvForTesting(<List<String>>[
        <String>['note'],
        <String>['line one\nline two'],
      ]);

      expect(csv, contains('"line one\nline two"'));
    });

    test('leaves plain fields unquoted', () {
      final csv = db.generateCsvForTesting(<List<String>>[
        <String>['a', 'b', 'c'],
      ]);

      expect(csv, 'a,b,c\n');
    });

    test('returns an empty string for no rows', () {
      expect(db.generateCsvForTesting(<List<String>>[]), '');
    });
  });

  group('parseCsvContent', () {
    test('parses plain rows', () {
      final rows = db.parseCsvContentForTesting('a,b,c\n1,2,3');

      expect(rows, <List<String>>[
        <String>['a', 'b', 'c'],
        <String>['1', '2', '3'],
      ]);
    });

    test('preserves empty fields', () {
      final rows = db.parseCsvContentForTesting('a,,c');

      expect(rows.single, <String>['a', '', 'c']);
    });

    test('unwraps quoted fields containing commas', () {
      final rows = db.parseCsvContentForTesting('name,location\nPress,"A, B"');

      expect(rows.last, <String>['Press', 'A, B']);
    });

    test('collapses doubled quotes into a single quote', () {
      final rows = db.parseCsvContentForTesting('a,b\nx,"5"" flange"');

      expect(rows.last, <String>['x', '5" flange']);
    });

    test('skips blank lines', () {
      final rows = db.parseCsvContentForTesting('a,b\n\n\nc,d\n');

      expect(rows.length, 2);
    });

    test('returns no rows for empty or whitespace-only content', () {
      expect(db.parseCsvContentForTesting(''), isEmpty);
      expect(db.parseCsvContentForTesting('   \n  \n'), isEmpty);
    });
  });

  group('CSV round trip', () {
    test('preserves commas, quotes, and empty fields', () {
      final original = <List<String>>[
        <String>['id', 'name', 'location', 'note'],
        <String>['1', 'Air Compressor', 'Building A, Floor 2', '5" flange'],
        <String>['2', 'Press', '', 'ok'],
      ];

      final parsed = db.parseCsvContentForTesting(
        db.generateCsvForTesting(original),
      );

      expect(parsed, original);
    });
  });
}
