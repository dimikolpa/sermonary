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
  Future<void> attachAsVersion(String draggedId, String targetId);
  Future<void> detachVersion(String id);
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
      document: const SermonDocument(
        schemaVersion: SermonDocument.currentSchemaVersion,
        blocks: [],
      ),
    );
    await database.into(database.sermonRows).insert(sermonToCompanion(sermon));
    return sermon;
  }

  @override
  Future<void> update(Sermon sermon) async {
    final document = sermon.document.migrateToV2(
      sermonId: sermon.id,
      fallbackCreatedAt: sermon.createdAt,
    );
    final integrityIssues = document.validateV2();
    if (integrityIssues.isNotEmpty) {
      throw StateError(
        'Das Predigtdokument ist inkonsistent: '
        '${integrityIssues.map((issue) => issue.message).join(' | ')}',
      );
    }
    final next = sermon.copyWith(
      document: document,
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
    final sermon = sermonFromRow(row);
    await database.transaction(() async {
      if (sermon.versionRootId == null) {
        await _detachVersions(id);
      }
      await update(
        sermon.copyWith(
          isDeleted: true,
          deletedAt: DateTime.now().toUtc(),
        ),
      );
    });
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
      contentKind: sermon.contentKind,
      backgroundImageId: sermon.backgroundImageId,
      primaryBibleReference: sermon.primaryBibleReference,
      additionalBibleReferences: sermon.additionalBibleReferences,
      seriesId: sermon.seriesId,
      versionRootId: sermon.versionRootId,
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
      await _detachVersions(id);
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
    final rootId = original.versionRootId ?? original.id;
    final copy = Sermon(
      id: _uuid.v4(),
      schemaVersion: original.schemaVersion,
      title: original.title,
      subtitle: original.subtitle,
      status: original.status,
      sermonType: original.sermonType,
      contentKind: original.contentKind,
      backgroundImageId: original.backgroundImageId,
      primaryBibleReference: original.primaryBibleReference,
      additionalBibleReferences: original.additionalBibleReferences,
      seriesId: original.seriesId,
      versionRootId: rootId,
      seriesPosition: original.seriesPosition,
      topics: original.topics,
      tags: original.tags,
      audience: original.audience,
      location: original.location,
      scheduledAt: original.scheduledAt,
      preachedDates: original.preachedDates,
      plannedDurationMinutes: original.plannedDurationMinutes,
      actualDurationMinutes: original.actualDurationMinutes,
      createdAt: now,
      updatedAt: now,
      lastOpenedAt: now,
      isFavorite: original.isFavorite,
      isDeleted: false,
      revision: 1,
      document: original.document,
    );
    await database.into(database.sermonRows).insert(sermonToCompanion(copy));
    return copy;
  }

  @override
  Future<void> attachAsVersion(String draggedId, String targetId) async {
    if (draggedId == targetId) return;
    await database.transaction(() async {
      final dragged = await _row(draggedId);
      final target = await _row(targetId);
      final requestedRootId = target.versionRootId ?? target.id;
      final rootExists = await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(requestedRootId))).getSingleOrNull();
      final rootId = rootExists == null ? target.id : requestedRootId;

      // Dropping an original onto one of its own versions must never create
      // a cycle. It is already the root of that family, so there is no change.
      if (rootId == dragged.id || dragged.versionRootId == rootId) return;

      final previousChildren = await (database.select(
        database.sermonRows,
      )..where((row) => row.versionRootId.equals(dragged.id))).get();
      final now = DateTime.now().toUtc();
      await _writeVersionRoot(dragged, rootId, now);
      for (final child in previousChildren) {
        await _writeVersionRoot(child, rootId, now);
      }
    });
  }

  @override
  Future<void> detachVersion(String id) async {
    await database.transaction(() async {
      final sermon = await _row(id);
      if (sermon.versionRootId == null) return;
      await _writeVersionRoot(sermon, null, DateTime.now().toUtc());
    });
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

  Future<void> _writeVersionRoot(
    SermonRow sermon,
    String? rootId,
    DateTime now,
  ) =>
      (database.update(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).write(
        SermonRowsCompanion(
          versionRootId: Value(rootId),
          updatedAt: Value(now),
          revision: Value(sermon.revision + 1),
        ),
      );

  Future<void> _detachVersions(String rootId) async {
    await (database.update(
      database.sermonRows,
    )..where((row) => row.versionRootId.equals(rootId))).write(
      const SermonRowsCompanion(versionRootId: Value(null)),
    );
  }
}
