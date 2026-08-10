import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/core/database/database_backup_service.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'sermonary-backup-test-',
    );
  });

  tearDown(() {
    if (temporaryDirectory.existsSync()) {
      temporaryDirectory.deleteSync(recursive: true);
    }
  });

  test('creates and verifies a backup before schema migration', () async {
    final database = File(
      p.join(temporaryDirectory.path, AppConfig.databaseFileName),
    );
    _createDatabase(database, schema: 2, value: 'vor-migration');
    final service = DatabaseBackupService(
      dataDirectory: temporaryDirectory,
      targetSchemaVersion: 5,
      now: () => DateTime.utc(2026, 8, 1, 12),
    );

    expect(await service.prepareForOpen(), database.path);

    final backups = service.backupDirectory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sermonarybackup'))
        .toList();
    expect(backups, hasLength(1));
    expect(File('${backups.single.path}.json').existsSync(), isTrue);
    expect(_readValue(backups.single), 'vor-migration');
  });

  test('manual backup is a complete, independent SQLite snapshot', () async {
    final database = File(
      p.join(temporaryDirectory.path, AppConfig.databaseFileName),
    );
    _createDatabase(database, schema: 4, value: 'vollständig');
    final service = DatabaseBackupService(
      dataDirectory: temporaryDirectory,
      targetSchemaVersion: 5,
    );
    final destination = p.join(
      temporaryDirectory.path,
      'export.sermonarybackup',
    );

    final record = await service.createManualBackup(destination);

    expect(record.schemaVersion, 4);
    expect(record.sha256, hasLength(64));
    expect(_readValue(record.file), 'vollständig');
  });

  test('keeps only the configured number of automatic backups', () async {
    final database = File(
      p.join(temporaryDirectory.path, AppConfig.databaseFileName),
    );
    _createDatabase(database, schema: 3, value: 'rotation');
    var tick = 0;
    final service = DatabaseBackupService(
      dataDirectory: temporaryDirectory,
      targetSchemaVersion: 5,
      maxAutomaticBackups: 3,
      now: () => DateTime.utc(2026, 8).add(
        Duration(seconds: tick++),
      ),
    );

    for (var index = 0; index < 6; index++) {
      await service.prepareForOpen();
    }

    final backups = service.backupDirectory.listSync().whereType<File>().where(
      (file) => file.path.endsWith('.sermonarybackup'),
    );
    expect(backups, hasLength(3));
  });

  test(
    'staged restore replaces the database only on next preparation',
    () async {
      final database = File(
        p.join(temporaryDirectory.path, AppConfig.databaseFileName),
      );
      _createDatabase(database, schema: 4, value: 'aktueller-stand');
      final selectedBackup = File(
        p.join(temporaryDirectory.path, 'auswahl.sermonarybackup'),
      );
      _createDatabase(selectedBackup, schema: 4, value: 'wiederhergestellt');
      final service = DatabaseBackupService(
        dataDirectory: temporaryDirectory,
        targetSchemaVersion: 5,
        now: () => DateTime.utc(2026, 8, 2, 12),
      );

      expect(await service.stageRestore(selectedBackup.path), 4);
      expect(_readValue(database), 'aktueller-stand');

      await service.prepareForOpen();

      expect(_readValue(database), 'wiederhergestellt');
      final rescueBackups = service.backupDirectory
          .listSync()
          .whereType<File>()
          .where(
            (file) =>
                file.path.contains('preRestore') &&
                file.path.endsWith('.sermonarybackup'),
          );
      expect(rescueBackups, hasLength(1));
      expect(_readValue(rescueBackups.single), 'aktueller-stand');
    },
  );

  test('rejects corrupt and newer backups without replacing data', () async {
    final database = File(
      p.join(temporaryDirectory.path, AppConfig.databaseFileName),
    );
    _createDatabase(database, schema: 4, value: 'sicher');
    final service = DatabaseBackupService(
      dataDirectory: temporaryDirectory,
      targetSchemaVersion: 5,
    );
    final corrupt = File(p.join(temporaryDirectory.path, 'kaputt.sqlite'))
      ..writeAsStringSync('keine sqlite datei');
    final newer = File(p.join(temporaryDirectory.path, 'neuer.sqlite'));
    _createDatabase(newer, schema: 6, value: 'zu-neu');
    final unrelated = File(p.join(temporaryDirectory.path, 'fremd.sqlite'));
    sqlite3.open(unrelated.path)
      ..execute('CREATE TABLE unrelated (value TEXT)')
      ..userVersion = 4
      ..close();

    expect(
      () => service.stageRestore(corrupt.path),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(
      () => service.stageRestore(newer.path),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(
      () => service.stageRestore(unrelated.path),
      throwsA(isA<DatabaseBackupException>()),
    );
    expect(_readValue(database), 'sicher');
  });
}

void _createDatabase(File file, {required int schema, required String value}) {
  final database = sqlite3.open(file.path);
  try {
    database
      ..execute('CREATE TABLE sample (value TEXT NOT NULL)')
      ..execute('INSERT INTO sample VALUES (?)', [value])
      ..execute(
        'CREATE TABLE sermons ( '
        'id TEXT PRIMARY KEY, '
        'title TEXT NOT NULL, '
        'document_json TEXT NOT NULL '
        ')',
      )
      ..userVersion = schema;
  } finally {
    database.close();
  }
}

String _readValue(File file) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return database.select('SELECT value FROM sample').single['value']!
        as String;
  } finally {
    database.close();
  }
}
