import 'dart:async';

import 'package:drift/drift.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

abstract interface class SermonRepository {
  Stream<List<Sermon>> watchAll();
  Stream<Sermon?> watchById(String id);
  Future<Sermon> create();
  Future<void> update(Sermon sermon);
  Future<void> moveToTrash(String id);
  Future<void> restore(String id);
  Future<void> deletePermanently(String id);
  Future<Sermon> duplicate(String id);
  Future<void> saveVersion(String id, String reason);
}

class DriftSermonRepository implements SermonRepository {
  DriftSermonRepository(this.database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();
  final AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<Sermon>> watchAll() =>
      (database.select(database.sermonRows)
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch()
          .map((rows) => rows.map(sermonFromRow).toList(growable: false));

  @override
  Stream<Sermon?> watchById(String id) =>
      (database.select(database.sermonRows)..where((row) => row.id.equals(id)))
          .watchSingleOrNull()
          .map((row) => row == null ? null : sermonFromRow(row));

  @override
  Future<Sermon> create() async {
    final now = DateTime.now().toUtc();
    final sermon = Sermon(
      id: _uuid.v4(),
      schemaVersion: 1,
      title: 'Unbenannte Predigt',
      subtitle: '',
      status: SermonStatus.draft,
      sermonType: SermonType.expository,
      additionalBibleReferences: const [],
      topics: const [],
      tags: const [],
      preachedDates: const [],
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
      isFavorite: false,
      isDeleted: false,
      revision: 1,
      document: const SermonDocument(schemaVersion: 1, blocks: []),
    );
    await database.into(database.sermonRows).insert(sermonToCompanion(sermon));
    return sermon;
  }

  @override
  Future<void> update(Sermon sermon) async {
    final next = sermon.copyWith(
      updatedAt: DateTime.now().toUtc(),
      revision: sermon.revision + 1,
    );
    await database.transaction(() async {
      await database
          .into(database.sermonRows)
          .insert(sermonToCompanion(next), mode: InsertMode.insertOrReplace);
      await (database.delete(
        database.sermonTopics,
      )..where((row) => row.sermonId.equals(next.id))).go();
      await (database.delete(
        database.sermonTags,
      )..where((row) => row.sermonId.equals(next.id))).go();
      for (final topic in next.topics) {
        await database
            .into(database.sermonTopics)
            .insert(
              SermonTopicsCompanion.insert(sermonId: next.id, topic: topic),
            );
      }
      for (final tag in next.tags) {
        await database
            .into(database.sermonTags)
            .insert(
              SermonTagsCompanion.insert(sermonId: next.id, tag: tag),
            );
      }
    });
  }

  @override
  Future<void> moveToTrash(String id) async {
    final row = await _row(id);
    await update(
      sermonFromRow(row).copyWith(
        isDeleted: true,
        deletedAt: DateTime.now().toUtc(),
      ),
    );
  }

  @override
  Future<void> restore(String id) async {
    final row = await _row(id);
    final sermon = sermonFromRow(row).copyWith(isDeleted: false);
    final restored = Sermon(
      id: sermon.id,
      schemaVersion: sermon.schemaVersion,
      title: sermon.title,
      subtitle: sermon.subtitle,
      status: sermon.status,
      sermonType: sermon.sermonType,
      primaryBibleReference: sermon.primaryBibleReference,
      additionalBibleReferences: sermon.additionalBibleReferences,
      seriesId: sermon.seriesId,
      seriesPosition: sermon.seriesPosition,
      topics: sermon.topics,
      tags: sermon.tags,
      audience: sermon.audience,
      location: sermon.location,
      scheduledAt: sermon.scheduledAt,
      preachedDates: sermon.preachedDates,
      plannedDurationMinutes: sermon.plannedDurationMinutes,
      actualDurationMinutes: sermon.actualDurationMinutes,
      createdAt: sermon.createdAt,
      updatedAt: sermon.updatedAt,
      lastOpenedAt: sermon.lastOpenedAt,
      isFavorite: sermon.isFavorite,
      isDeleted: false,
      revision: sermon.revision,
      document: sermon.document,
    );
    await update(restored);
  }

  @override
  Future<void> deletePermanently(String id) async {
    await database.transaction(() async {
      await (database.delete(
        database.documentVersions,
      )..where((row) => row.sermonId.equals(id))).go();
      await (database.delete(
        database.sermonTopics,
      )..where((row) => row.sermonId.equals(id))).go();
      await (database.delete(
        database.sermonTags,
      )..where((row) => row.sermonId.equals(id))).go();
      await (database.delete(
        database.sermonPreachedDates,
      )..where((row) => row.sermonId.equals(id))).go();
      await (database.delete(
        database.sermonRows,
      )..where((row) => row.id.equals(id))).go();
    });
  }

  @override
  Future<Sermon> duplicate(String id) async {
    final original = sermonFromRow(await _row(id));
    final now = DateTime.now().toUtc();
    final copy = Sermon(
      id: _uuid.v4(),
      schemaVersion: original.schemaVersion,
      title: '${original.title} – Kopie',
      subtitle: original.subtitle,
      status: SermonStatus.draft,
      sermonType: original.sermonType,
      primaryBibleReference: original.primaryBibleReference,
      additionalBibleReferences: original.additionalBibleReferences,
      seriesId: original.seriesId,
      seriesPosition: original.seriesPosition,
      topics: original.topics,
      tags: original.tags,
      audience: original.audience,
      location: original.location,
      scheduledAt: original.scheduledAt,
      preachedDates: const [],
      plannedDurationMinutes: original.plannedDurationMinutes,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
      isFavorite: false,
      isDeleted: false,
      revision: 1,
      document: original.document,
    );
    await database.into(database.sermonRows).insert(sermonToCompanion(copy));
    return copy;
  }

  @override
  Future<void> saveVersion(String id, String reason) async {
    final sermon = sermonFromRow(await _row(id));
    await database
        .into(database.documentVersions)
        .insert(
          DocumentVersionsCompanion.insert(
            sermonId: id,
            documentSchemaVersion: sermon.document.schemaVersion,
            documentJson: sermonToCompanion(sermon).documentJson.value,
            reason: reason,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<SermonRow> _row(String id) => (database.select(
    database.sermonRows,
  )..where((row) => row.id.equals(id))).getSingle();
}
