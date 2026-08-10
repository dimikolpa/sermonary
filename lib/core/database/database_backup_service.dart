import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sermonary/app/app_config.dart';
import 'package:sqlite3/sqlite3.dart';

enum DatabaseBackupReason { preMigration, manual, preRestore }

class DatabaseBackupRecord {
  const DatabaseBackupRecord({
    required this.file,
    required this.schemaVersion,
    required this.createdAt,
    required this.sha256,
    required this.reason,
  });

  final File file;
  final int schemaVersion;
  final DateTime createdAt;
  final String sha256;
  final DatabaseBackupReason reason;
}

class DatabaseBackupException implements Exception {
  const DatabaseBackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Owns the stable on-disk database path and creates consistent SQLite
/// snapshots before Drift is allowed to run a schema migration.
class DatabaseBackupService {
  DatabaseBackupService({
    required this.dataDirectory,
    required this.targetSchemaVersion,
    DateTime Function()? now,
    this.maxAutomaticBackups = 5,
  }) : _now = now ?? DateTime.now;

  static const backupExtension = 'sermonarybackup';
  static const _backupDirectoryName = 'Backups';
  static const _pendingRestoreName = 'pending-restore.$backupExtension';
  static const _restoreRequestName = 'restore-request.json';

  final Directory dataDirectory;
  final int targetSchemaVersion;
  final int maxAutomaticBackups;
  final DateTime Function() _now;

  File get databaseFile =>
      File(p.join(dataDirectory.path, AppConfig.databaseFileName));

  Directory get backupDirectory =>
      Directory(p.join(dataDirectory.path, _backupDirectoryName));

  File get _pendingRestoreFile =>
      File(p.join(dataDirectory.path, _pendingRestoreName));

  File get _restoreRequestFile =>
      File(p.join(dataDirectory.path, _restoreRequestName));

  /// Called by drift's asynchronous path resolver before SQLite opens.
  Future<String> prepareForOpen() async {
    await dataDirectory.create(recursive: true);
    sqlite3.tempDirectory = dataDirectory.path;
    if (_restoreRequestFile.existsSync()) {
      await _applyPendingRestore();
    }
    final primary = databaseFile;
    if (!primary.existsSync()) return primary.path;

    final schema = _validate(primary);
    if (schema > targetSchemaVersion) {
      throw DatabaseBackupException(
        'Die Datenbank verwendet Schema $schema, diese App unterstützt nur '
        'Schema $targetSchemaVersion. Bitte eine neuere App-Version öffnen.',
      );
    }
    if (schema > 0 && schema < targetSchemaVersion) {
      await createSnapshot(
        destinationPath: _automaticPath(
          DatabaseBackupReason.preMigration,
          schema,
        ),
        reason: DatabaseBackupReason.preMigration,
      );
      await _rotateAutomaticBackups();
    }
    return primary.path;
  }

  Future<DatabaseBackupRecord> createManualBackup(String destinationPath) =>
      createSnapshot(
        destinationPath: destinationPath,
        reason: DatabaseBackupReason.manual,
      );

  Future<DatabaseBackupRecord> createSnapshot({
    required String destinationPath,
    required DatabaseBackupReason reason,
  }) async {
    final source = databaseFile;
    if (!source.existsSync()) {
      throw const DatabaseBackupException(
        'Es ist noch keine Datenbank vorhanden.',
      );
    }
    final schema = _validateRestoreCandidate(source);
    final destination = File(destinationPath);
    await destination.parent.create(recursive: true);
    if (destination.existsSync()) await destination.delete();

    final sourceDb = sqlite3.open(source.path);
    final destinationDb = sqlite3.open(destination.path);
    try {
      await sourceDb.backup(destinationDb, nPage: -1).drain<void>();
    } finally {
      destinationDb.close();
      sourceDb.close();
    }
    final copiedSchema = _validateRestoreCandidate(destination);
    if (copiedSchema != schema) {
      await destination.delete();
      throw const DatabaseBackupException(
        'Die Sicherung konnte nicht verifiziert werden.',
      );
    }
    final createdAt = _now().toUtc();
    final checksum = await _sha256(destination);
    final record = DatabaseBackupRecord(
      file: destination,
      schemaVersion: schema,
      createdAt: createdAt,
      sha256: checksum,
      reason: reason,
    );
    if (reason != DatabaseBackupReason.manual) {
      await _writeManifest(record);
    }
    return record;
  }

  /// Validates and copies a user-selected backup into a private staging file.
  /// It is applied on the next launch before the database connection starts.
  Future<int> stageRestore(String sourcePath) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const DatabaseBackupException(
        'Die ausgewählte Sicherung wurde nicht gefunden.',
      );
    }
    final schema = _validateRestoreCandidate(source);
    if (schema > targetSchemaVersion) {
      throw DatabaseBackupException(
        'Die Sicherung benötigt Schema $schema. Installiert ist nur '
        'Schema $targetSchemaVersion.',
      );
    }
    if (_pendingRestoreFile.existsSync()) {
      await _pendingRestoreFile.delete();
    }
    final sourceDb = sqlite3.open(source.path, mode: OpenMode.readOnly);
    final stagedDb = sqlite3.open(_pendingRestoreFile.path);
    try {
      await sourceDb.backup(stagedDb, nPage: -1).drain<void>();
    } finally {
      stagedDb.close();
      sourceDb.close();
    }
    _validateRestoreCandidate(_pendingRestoreFile);
    await _restoreRequestFile.writeAsString(
      jsonEncode({
        'requestedAt': _now().toUtc().toIso8601String(),
        'sourceSchemaVersion': schema,
        'bundleIdentifier': AppConfig.bundleIdentifier,
      }),
      flush: true,
    );
    return schema;
  }

  int _validate(File file) {
    Database? database;
    try {
      database = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final result = database.select('PRAGMA integrity_check(1)');
      final status = result.isEmpty ? null : result.first.values.first;
      if (status != 'ok') {
        throw const DatabaseBackupException(
          'Die Datenbank ist beschädigt und kann nicht sicher verwendet werden.',
        );
      }
      return database.userVersion;
    } on DatabaseBackupException {
      rethrow;
    } on Object {
      throw const DatabaseBackupException(
        'Die Datei ist keine gültige Sermonary-Sicherung.',
      );
    } finally {
      database?.close();
    }
  }

  int _validateRestoreCandidate(File file) {
    final schema = _validate(file);
    if (schema < 1) {
      throw const DatabaseBackupException(
        'Die Datei enthält keine Sermonary-Datenbank.',
      );
    }

    Database? database;
    try {
      database = sqlite3.open(file.path, mode: OpenMode.readOnly);
      final tables = database.select(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        ['sermons'],
      );
      if (tables.isEmpty) {
        throw const DatabaseBackupException(
          'Die Datei enthält keine Sermonary-Datenbank.',
        );
      }
      final columns = database
          .select('PRAGMA table_info(sermons)')
          .map((row) => row['name'])
          .whereType<String>()
          .toSet();
      if (!columns.containsAll(const {'id', 'title', 'document_json'})) {
        throw const DatabaseBackupException(
          'Die Sermonary-Sicherung hat ein unbekanntes Datenformat.',
        );
      }
      return schema;
    } on DatabaseBackupException {
      rethrow;
    } on Object {
      throw const DatabaseBackupException(
        'Die Datei ist keine gültige Sermonary-Sicherung.',
      );
    } finally {
      database?.close();
    }
  }

  Future<void> _applyPendingRestore() async {
    if (!_pendingRestoreFile.existsSync()) {
      await _restoreRequestFile.delete();
      throw const DatabaseBackupException(
        'Die vorgemerkte Sicherung wurde nicht gefunden.',
      );
    }
    _validateRestoreCandidate(_pendingRestoreFile);
    final primary = databaseFile;
    if (primary.existsSync()) {
      final schema = _validate(primary);
      await createSnapshot(
        destinationPath: _automaticPath(
          DatabaseBackupReason.preRestore,
          schema,
        ),
        reason: DatabaseBackupReason.preRestore,
      );
    }

    final replacement = File('${primary.path}.restore-new');
    final previous = File('${primary.path}.restore-previous');
    if (replacement.existsSync()) await replacement.delete();
    if (previous.existsSync()) await previous.delete();
    await _pendingRestoreFile.copy(replacement.path);
    _validateRestoreCandidate(replacement);

    await _deleteSidecars(primary);
    if (primary.existsSync()) await primary.rename(previous.path);
    try {
      await replacement.rename(primary.path);
      _validate(primary);
      if (previous.existsSync()) await previous.delete();
      await _pendingRestoreFile.delete();
      await _restoreRequestFile.delete();
      await _rotateAutomaticBackups();
    } on Object {
      if (primary.existsSync()) await primary.delete();
      if (previous.existsSync()) await previous.rename(primary.path);
      rethrow;
    }
  }

  Future<void> _deleteSidecars(File primary) async {
    for (final suffix in const ['-wal', '-shm']) {
      final sidecar = File('${primary.path}$suffix');
      if (sidecar.existsSync()) await sidecar.delete();
    }
  }

  String _automaticPath(DatabaseBackupReason reason, int schema) {
    final timestamp = _now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    return p.join(
      backupDirectory.path,
      '${reason.name}-schema-$schema-$timestamp.$backupExtension',
    );
  }

  Future<void> _writeManifest(DatabaseBackupRecord record) async {
    final manifest = File('${record.file.path}.json');
    await manifest.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'formatVersion': 1,
        'bundleIdentifier': AppConfig.bundleIdentifier,
        'databaseFileName': AppConfig.databaseFileName,
        'schemaVersion': record.schemaVersion,
        'createdAt': record.createdAt.toIso8601String(),
        'reason': record.reason.name,
        'sha256': record.sha256,
      }),
      flush: true,
    );
  }

  Future<void> _rotateAutomaticBackups() async {
    if (!backupDirectory.existsSync()) return;
    final backups =
        backupDirectory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.$backupExtension'))
            .toList()
          ..sort(
            (left, right) =>
                right.lastModifiedSync().compareTo(left.lastModifiedSync()),
          );
    for (final expired in backups.skip(maxAutomaticBackups)) {
      await expired.delete();
      final manifest = File('${expired.path}.json');
      if (manifest.existsSync()) await manifest.delete();
    }
  }

  Future<String> _sha256(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();
}
