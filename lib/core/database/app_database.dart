import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
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
  TextColumn get primaryBibleReferenceJson => text().nullable()();
  TextColumn get additionalBibleReferencesJson =>
      text().withDefault(const Constant('[]'))();
  TextColumn get documentJson => text()();
  TextColumn get documentPlainText => text().withDefault(const Constant(''))();
  TextColumn get seriesId => text().nullable()();
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
    : super(executor ?? driftDatabase(name: 'sermonary'));

  @override
  int get schemaVersion => 3;

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
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
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
