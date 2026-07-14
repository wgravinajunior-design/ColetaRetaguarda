import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_retaguarda/core/database/migration.dart';

void main() {
  group('Migration', () {
    test('Migration001 has correct version and description', () {
      final migration = Migration001CreateInitialTables();

      expect(migration.version, equals(1));
      expect(migration.description, isNotEmpty);
      expect(migration.description, contains('initial'));
    });

    test('Migration002 has correct version and description', () {
      final migration = Migration002AddIndexes();

      expect(migration.version, equals(2));
      expect(migration.description, isNotEmpty);
      expect(migration.description, contains('index'));
    });
  });

  group('MigrationManager', () {
    test('returns correct target version', () {
      final targetVersion = MigrationManager.getTargetVersion();

      expect(targetVersion, greaterThan(0));
      expect(targetVersion, equals(2));
    });

    test('migrations are in correct order', () {
      final migrations = [
        Migration001CreateInitialTables(),
        Migration002AddIndexes(),
      ];

      for (int i = 0; i < migrations.length - 1; i++) {
        expect(
          migrations[i].version < migrations[i + 1].version,
          true,
          reason:
              'Migration ${migrations[i].version} should have lower version than ${migrations[i + 1].version}',
        );
      }
    });
  });
}
