import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/core/database/database_backup_service.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/domain/sermon.dart' as domain;
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

part 'app_database.g.dart';

class SermonRows extends Table {
  @override
  String get tableName => 'sermons';
  TextColumn get id => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get title => text()();
  TextColumn get subtitle => text().withDefault(const Constant(''))();
  TextColumn get status => text()();
  TextColumn get sermonType => text()();
  TextColumn get contentKind => text().withDefault(const Constant('sermon'))();
  TextColumn get backgroundImageId => text().nullable()();
  TextColumn get primaryBibleReferenceJson => text().nullable()();
  TextColumn get additionalBibleReferencesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get documentJson => text()();
  TextColumn get documentPlainText => text().withDefault(const Constant(''))();
  TextColumn get seriesId => text().nullable()();
  TextColumn get versionRootId => text().nullable()();
  IntColumn get seriesPosition => integer().nullable()();
  TextColumn get topicsJson => text().withDefault(const Constant('[]'))();
  TextColumn get tagsJson => text().withDefault(const Constant('[]'))();
  TextColumn get audience => text().nullable()();
  TextColumn get location => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  TextColumn get preachedDatesJson =>
      text().withDefault(const Constant('[]'))();
  IntColumn get plannedDurationMinutes => integer().nullable()();
  IntColumn get actualDurationMinutes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastOpenedAt => dateTime()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SermonSeriesRows extends Table {
  @override
  String get tableName => 'sermon_series';
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get primaryBibleBook => text().nullable()();
  TextColumn get colorToken => text().withDefault(const Constant('forest'))();
  TextColumn get backgroundImageId =>
      text().withDefault(const Constant('generic2'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SermonTopics extends Table {
  TextColumn get sermonId => text().references(SermonRows, #id)();
  TextColumn get topic => text()();
  @override
  Set<Column<Object>> get primaryKey => {sermonId, topic};
}

class SermonTags extends Table {
  TextColumn get sermonId => text().references(SermonRows, #id)();
  TextColumn get tag => text()();
  @override
  Set<Column<Object>> get primaryKey => {sermonId, tag};
}

class SermonPreachedDates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sermonId => text().references(SermonRows, #id)();
  DateTimeColumn get preachedAt => dateTime()();
}

class DocumentVersions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sermonId => text().references(SermonRows, #id)();
  IntColumn get documentSchemaVersion => integer()();
  TextColumn get documentJson => text()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get valueJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

class BibleTranslations extends Table {
  TextColumn get id => text()();
  TextColumn get abbreviation => text()();
  TextColumn get name => text()();
  TextColumn get language => text()();
  TextColumn get source => text()();
  TextColumn get copyrightNotice => text()();
  IntColumn get dataVersion => integer()();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class BibleVerses extends Table {
  TextColumn get translationId => text()();
  TextColumn get bookId => text()();
  IntColumn get chapter => integer()();
  IntColumn get verse => integer()();
  TextColumn get content => text().named('text')();
  TextColumn get sourceText => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    translationId,
    bookId,
    chapter,
    verse,
  };
}

@DriftDatabase(
  tables: [
    SermonRows,
    SermonSeriesRows,
    SermonTopics,
    SermonTags,
    SermonPreachedDates,
    DocumentVersions,
    AppSettings,
    BibleTranslations,
    BibleVerses,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: AppConfig.databaseName,
              native: const DriftNativeOptions(
                databasePath: _prepareProductionDatabase,
              ),
            ),
      );

  static const currentSchemaVersion = 8;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from > to) throw StateError('Datenbank-Downgrade nicht unterstützt');
      if (from < 2) {
        await migrator.addColumn(sermonRows, sermonRows.contentKind);
      }
      if (from < 3) {
        await migrator.createTable(bibleTranslations);
        await migrator.createTable(bibleVerses);
      }
      if (from < 4) {
        await migrator.addColumn(sermonRows, sermonRows.versionRootId);
      }
      if (from < 5) {
        await _separateExistingNotesAndRemoveQuickNotes();
      }
      if (from < 6) {
        await migrator.addColumn(sermonRows, sermonRows.backgroundImageId);
        await migrator.addColumn(
          sermonSeriesRows,
          sermonSeriesRows.backgroundImageId,
        );
        await _assignExistingSeriesBackgrounds();
      }
      if (from < 7) {
        await _migrateSermonModules();
      }
      if (from < 8) {
        await _migrateSermonDocumentsV2();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _separateExistingNotesAndRemoveQuickNotes() async {
    final sermons = await select(sermonRows).get();
    for (final sermon in sermons) {
      final cleaned = _removeExistingQuickNotes(sermon.documentJson);
      if (cleaned == null) continue;
      await customUpdate(
        'UPDATE sermons SET document_json = ?, document_plain_text = ? '
        'WHERE id = ?',
        variables: [
          Variable<String>(cleaned.json),
          Variable<String>(cleaned.plainText),
          Variable<String>(sermon.id),
        ],
        updates: {sermonRows},
      );
    }

    final versions = await select(documentVersions).get();
    for (final version in versions) {
      final cleaned = _removeExistingQuickNotes(version.documentJson);
      if (cleaned == null) continue;
      await customUpdate(
        'UPDATE document_versions SET document_json = ? WHERE id = ?',
        variables: [
          Variable<String>(cleaned.json),
          Variable<int>(version.id),
        ],
        updates: {documentVersions},
      );
    }
  }

  Future<void> _migrateSermonModules() async {
    final sermons = await select(sermonRows).get();
    for (final sermon in sermons) {
      final document = SermonDocument.fromJson(
        jsonDecode(sermon.documentJson) as Map<String, Object?>,
      );
      final migrated = document.copyWith(modules: document.effectiveModules);
      await customUpdate(
        'UPDATE sermons SET document_json = ?, document_plain_text = ? '
        'WHERE id = ?',
        variables: [
          Variable<String>(jsonEncode(migrated.toJson())),
          Variable<String>(migrated.plainText),
          Variable<String>(sermon.id),
        ],
        updates: {sermonRows},
      );
    }

    final versions = await select(documentVersions).get();
    for (final version in versions) {
      final document = SermonDocument.fromJson(
        jsonDecode(version.documentJson) as Map<String, Object?>,
      );
      final migrated = document.copyWith(modules: document.effectiveModules);
      await customUpdate(
        'UPDATE document_versions SET document_json = ? WHERE id = ?',
        variables: [
          Variable<String>(jsonEncode(migrated.toJson())),
          Variable<int>(version.id),
        ],
        updates: {documentVersions},
      );
    }
  }

  Future<void> _migrateSermonDocumentsV2() async {
    final sermons = await select(sermonRows).get();
    final sermonCreatedAt = <String, DateTime>{};
    for (final sermon in sermons) {
      sermonCreatedAt[sermon.id] = sermon.createdAt;
      final document = SermonDocument.fromJson(
        jsonDecode(sermon.documentJson) as Map<String, Object?>,
      );
      final migrated = document.migrateToV2(
        sermonId: sermon.id,
        fallbackCreatedAt: sermon.createdAt,
      );
      final issues = migrated.validateV2();
      if (issues.isNotEmpty) {
        throw StateError(
          'Dokumentmigration für ${sermon.id} ist ungültig: '
          '${issues.map((issue) => issue.message).join(' | ')}',
        );
      }
      await customUpdate(
        'UPDATE sermons SET document_json = ?, document_plain_text = ? '
        'WHERE id = ?',
        variables: [
          Variable<String>(jsonEncode(migrated.toJson())),
          Variable<String>(migrated.plainText),
          Variable<String>(sermon.id),
        ],
        updates: {sermonRows},
      );
    }

    final versions = await select(documentVersions).get();
    for (final version in versions) {
      final document = SermonDocument.fromJson(
        jsonDecode(version.documentJson) as Map<String, Object?>,
      );
      final migrated = document.migrateToV2(
        sermonId: '${version.sermonId}-version-${version.id}',
        fallbackCreatedAt:
            sermonCreatedAt[version.sermonId] ?? version.createdAt,
      );
      final issues = migrated.validateV2();
      if (issues.isNotEmpty) {
        throw StateError(
          'Versionsmigration für ${version.id} ist ungültig: '
          '${issues.map((issue) => issue.message).join(' | ')}',
        );
      }
      await customUpdate(
        'UPDATE document_versions SET document_schema_version = ?, '
        'document_json = ? WHERE id = ?',
        variables: [
          const Variable<int>(SermonDocument.currentSchemaVersion),
          Variable<String>(jsonEncode(migrated.toJson())),
          Variable<int>(version.id),
        ],
        updates: {documentVersions},
      );
    }
  }

  Future<void> _assignExistingSeriesBackgrounds() async {
    final rows =
        await (select(sermonSeriesRows)..orderBy([
              (row) => OrderingTerm.asc(row.createdAt),
              (row) => OrderingTerm.asc(row.title),
            ]))
            .get();
    for (var index = 0; index < rows.length; index++) {
      await (update(
        sermonSeriesRows,
      )..where((row) => row.id.equals(rows[index].id))).write(
        SermonSeriesRowsCompanion(
          backgroundImageId: Value('generic${2 + (index % 5)}'),
        ),
      );
    }
  }
}

typedef _CleanedDocument = ({String json, String plainText});

_CleanedDocument? _removeExistingQuickNotes(String source) {
  final decoded = jsonDecode(source) as Map<String, Object?>;
  final rawBlocks = (decoded['blocks']! as List<Object?>)
      .cast<Map<String, Object?>>();
  var changed = false;
  final blocks = <Map<String, Object?>>[];
  final quickNoteCutoff = DateTime.utc(2026, 8, 4, 4, 30);

  for (final rawBlock in rawBlocks) {
    final block = Map<String, Object?>.from(rawBlock);
    if (block['type'] != 'note' || block['isQuickNote'] != true) {
      blocks.add(block);
      continue;
    }

    changed = true;
    final createdAt = DateTime.tryParse(block['createdAt'] as String? ?? '');
    if (createdAt != null && !createdAt.toUtc().isBefore(quickNoteCutoff)) {
      continue;
    }

    // Notes that were only misclassified by the previous build stay intact.
    block['isQuickNote'] = false;
    blocks.add(block);
  }

  if (!changed) return null;
  decoded['blocks'] = blocks;
  final document = SermonDocument.fromJson(decoded);
  return (json: jsonEncode(decoded), plainText: document.plainText);
}

Future<String> _prepareProductionDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  return DatabaseBackupService(
    dataDirectory: directory,
    targetSchemaVersion: AppDatabase.currentSchemaVersion,
  ).prepareForOpen();
}

domain.Sermon sermonFromRow(SermonRow row) {
  final primaryJson = row.primaryBibleReferenceJson;
  return domain.Sermon(
    id: row.id,
    schemaVersion: row.schemaVersion,
    title: row.title,
    subtitle: row.subtitle,
    status: domain.SermonStatus.values.byName(row.status),
    sermonType: domain.SermonType.values.byName(row.sermonType),
    contentKind: domain.ContentKind.values.byName(row.contentKind),
    backgroundImageId: row.backgroundImageId,
    primaryBibleReference: primaryJson == null
        ? null
        : BibleReference.fromJson(
            jsonDecode(primaryJson) as Map<String, Object?>,
          ),
    additionalBibleReferences:
        (jsonDecode(row.additionalBibleReferencesJson) as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(BibleReference.fromJson)
            .toList(growable: false),
    seriesId: row.seriesId,
    versionRootId: row.versionRootId,
    seriesPosition: row.seriesPosition,
    topics: (jsonDecode(row.topicsJson) as List<Object?>).cast<String>(),
    tags: (jsonDecode(row.tagsJson) as List<Object?>).cast<String>(),
    audience: row.audience,
    location: row.location,
    scheduledAt: row.scheduledAt?.toUtc(),
    preachedDates: (jsonDecode(row.preachedDatesJson) as List<Object?>)
        .cast<String>()
        .map((value) => DateTime.parse(value).toUtc())
        .toList(growable: false),
    plannedDurationMinutes: row.plannedDurationMinutes,
    actualDurationMinutes: row.actualDurationMinutes,
    createdAt: row.createdAt.toUtc(),
    updatedAt: row.updatedAt.toUtc(),
    lastOpenedAt: row.lastOpenedAt.toUtc(),
    isFavorite: row.isFavorite,
    isDeleted: row.isDeleted,
    deletedAt: row.deletedAt?.toUtc(),
    revision: row.revision,
    document: SermonDocument.fromJson(
      jsonDecode(row.documentJson) as Map<String, Object?>,
    ),
  );
}

SermonRowsCompanion sermonToCompanion(domain.Sermon sermon) =>
    SermonRowsCompanion.insert(
      id: sermon.id,
      schemaVersion: sermon.schemaVersion,
      title: sermon.title,
      subtitle: Value(sermon.subtitle),
      status: sermon.status.name,
      sermonType: sermon.sermonType.name,
      contentKind: Value(sermon.contentKind.name),
      backgroundImageId: Value(sermon.backgroundImageId),
      primaryBibleReferenceJson: Value(
        sermon.primaryBibleReference == null
            ? null
            : jsonEncode(sermon.primaryBibleReference!.toJson()),
      ),
      additionalBibleReferencesJson: Value(
        jsonEncode(
          sermon.additionalBibleReferences
              .map((reference) => reference.toJson())
              .toList(growable: false),
        ),
      ),
      documentJson: jsonEncode(sermon.document.toJson()),
      documentPlainText: Value(sermon.document.plainText),
      seriesId: Value(sermon.seriesId),
      versionRootId: Value(sermon.versionRootId),
      seriesPosition: Value(sermon.seriesPosition),
      topicsJson: Value(jsonEncode(sermon.topics)),
      tagsJson: Value(jsonEncode(sermon.tags)),
      audience: Value(sermon.audience),
      location: Value(sermon.location),
      scheduledAt: Value(sermon.scheduledAt?.toUtc()),
      preachedDatesJson: Value(
        jsonEncode(
          sermon.preachedDates
              .map((date) => date.toUtc().toIso8601String())
              .toList(growable: false),
        ),
      ),
      plannedDurationMinutes: Value(sermon.plannedDurationMinutes),
      actualDurationMinutes: Value(sermon.actualDurationMinutes),
      createdAt: sermon.createdAt.toUtc(),
      updatedAt: sermon.updatedAt.toUtc(),
      lastOpenedAt: sermon.lastOpenedAt.toUtc(),
      isFavorite: Value(sermon.isFavorite),
      isDeleted: Value(sermon.isDeleted),
      deletedAt: Value(sermon.deletedAt?.toUtc()),
      revision: Value(sermon.revision),
    );
