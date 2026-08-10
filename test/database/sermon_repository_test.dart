import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase database;
  late DriftSermonRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftSermonRepository(database);
  });

  tearDown(() => database.close());

  test('schema version 8 creates all required tables', () async {
    final rows = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table'",
        )
        .get();
    final names = rows.map((row) => row.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'sermons',
        'sermon_series',
        'sermon_topics',
        'sermon_tags',
        'sermon_preached_dates',
        'document_versions',
        'app_settings',
        'bible_translations',
        'bible_verses',
      ]),
    );
    expect(database.schemaVersion, 8);
    final sermonColumns = await database
        .customSelect('PRAGMA table_info(sermons)')
        .get();
    expect(
      sermonColumns.map((row) => row.read<String>('name')),
      contains('content_kind'),
    );
    expect(
      sermonColumns.map((row) => row.read<String>('name')),
      contains('version_root_id'),
    );
    expect(
      sermonColumns.map((row) => row.read<String>('name')),
      contains('background_image_id'),
    );
    final seriesColumns = await database
        .customSelect('PRAGMA table_info(sermon_series)')
        .get();
    expect(
      seriesColumns.map((row) => row.read<String>('name')),
      contains('background_image_id'),
    );
  });

  for (final oldSchema in [1, 2, 3, 4, 5]) {
    test('migration from schema $oldSchema preserves sermon data', () async {
      await database.close();
      final directory = Directory.systemTemp.createTempSync(
        'sermonary-migration-$oldSchema-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File(p.join(directory.path, 'fixture.sqlite'));
      final fixtureDatabase = AppDatabase(NativeDatabase(file));
      final fixtureRepository = DriftSermonRepository(fixtureDatabase);
      final created = await fixtureRepository.create();
      await fixtureRepository.update(
        created.copyWith(
          title: 'Bleibt erhalten',
          subtitle: 'Schema $oldSchema',
        ),
      );
      await fixtureDatabase.close();

      final raw = sqlite.sqlite3.open(file.path)
        ..execute('ALTER TABLE sermons DROP COLUMN background_image_id')
        ..execute(
          'ALTER TABLE sermon_series DROP COLUMN background_image_id',
        );
      if (oldSchema < 4) {
        raw.execute('ALTER TABLE sermons DROP COLUMN version_root_id');
      }
      if (oldSchema < 3) {
        raw
          ..execute('DROP TABLE bible_verses')
          ..execute('DROP TABLE bible_translations');
      }
      if (oldSchema < 2) {
        raw.execute('ALTER TABLE sermons DROP COLUMN content_kind');
      }
      raw
        ..userVersion = oldSchema
        ..close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final loaded = await DriftSermonRepository(
        migrated,
      ).watchById(created.id).first;
      final columns = await migrated
          .customSelect('PRAGMA table_info(sermons)')
          .get();
      final tables = await migrated
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();

      expect(loaded?.title, 'Bleibt erhalten');
      expect(loaded?.subtitle, 'Schema $oldSchema');
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll([
          'content_kind',
          'version_root_id',
          'background_image_id',
        ]),
      );
      expect(
        tables.map((row) => row.read<String>('name')),
        containsAll(['bible_translations', 'bible_verses']),
      );
    });
  }

  test('schema 6 assigns backgrounds to existing series', () async {
    await database.close();
    final directory = Directory.systemTemp.createTempSync(
      'sermonary-series-background-migration-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final file = File(p.join(directory.path, 'fixture.sqlite'));
    final fixtureDatabase = AppDatabase(NativeDatabase(file));
    final now = DateTime.utc(2026, 8, 4);
    await fixtureDatabase.batch((batch) {
      batch.insertAll(fixtureDatabase.sermonSeriesRows, [
        SermonSeriesRowsCompanion.insert(
          id: 'series-a',
          title: 'Erste Reihe',
          createdAt: now,
          updatedAt: now,
        ),
        SermonSeriesRowsCompanion.insert(
          id: 'series-b',
          title: 'Zweite Reihe',
          createdAt: now.add(const Duration(seconds: 1)),
          updatedAt: now,
        ),
      ]);
    });
    await fixtureDatabase.close();

    sqlite.sqlite3.open(file.path)
      ..execute('ALTER TABLE sermons DROP COLUMN background_image_id')
      ..execute(
        'ALTER TABLE sermon_series DROP COLUMN background_image_id',
      )
      ..userVersion = 5
      ..close();

    final migrated = AppDatabase(NativeDatabase(file));
    addTearDown(migrated.close);
    final rows = await migrated.select(migrated.sermonSeriesRows).get()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));

    expect(rows.map((row) => row.backgroundImageId), [
      'generic2',
      'generic3',
    ]);
  });

  test(
    'schema 7 and 8 migrate legacy content into linked v2 modules',
    () async {
      await database.close();
      final directory = Directory.systemTemp.createTempSync(
        'sermonary-module-migration-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File(p.join(directory.path, 'fixture.sqlite'));
      final fixtureDatabase = AppDatabase(NativeDatabase(file));
      final repository = DriftSermonRepository(fixtureDatabase);
      final created = await repository.create();
      await fixtureDatabase.close();

      final now = DateTime.utc(2026, 8, 10);
      final legacyJson = jsonEncode({
        'schemaVersion': 1,
        'blocks': [
          ParagraphBlock(
            id: 'paragraph',
            text: 'Bestehendes Skript',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
          NoteBlock(
            id: 'note',
            text: 'Bestehende Notiz',
            visibility: NoteVisibility.editorOnly,
            createdAt: now,
            updatedAt: now,
          ).toJson(),
        ],
        'presentation': const PresentationDeck().toJson(),
      });
      sqlite.sqlite3.open(file.path)
        ..execute(
          'UPDATE sermons SET document_json = ? WHERE id = ?',
          [legacyJson, created.id],
        )
        ..userVersion = 6
        ..close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final loaded = await DriftSermonRepository(
        migrated,
      ).watchById(created.id).first;

      expect(loaded!.document.hasModule(SermonModuleKind.notes), isTrue);
      expect(loaded.document.hasModule(SermonModuleKind.script), isTrue);
      expect(loaded.document.modules, hasLength(2));
      expect(loaded.document.schemaVersion, 2);
      expect(
        loaded.document.modules.map((module) => module.linkGroupId).toSet(),
        {'legacy-link-${created.id}'},
      );
      expect(loaded.document.validateV2(), isEmpty);
    },
  );

  test(
    'schema 5 removes quicknotes and restores misclassified old notes',
    () async {
      await database.close();
      final directory = Directory.systemTemp.createTempSync(
        'sermonary-quicknote-migration-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File(p.join(directory.path, 'fixture.sqlite'));
      final fixtureDatabase = AppDatabase(NativeDatabase(file));
      final fixtureRepository = DriftSermonRepository(fixtureDatabase);
      final created = await fixtureRepository.create();
      final oldDate = DateTime.utc(2026, 8);
      final quickNoteDate = DateTime.utc(2026, 8, 4, 5);
      await fixtureRepository.update(
        created.copyWith(
          document: SermonDocument(
            schemaVersion: 1,
            blocks: [
              NoteBlock(
                id: 'old-note',
                text: 'Bleibt als Note erhalten',
                visibility: NoteVisibility.editorOnly,
                isQuickNote: true,
                createdAt: oldDate,
                updatedAt: quickNoteDate,
              ),
              NoteBlock(
                id: 'quicknote',
                text: 'Wird entfernt',
                visibility: NoteVisibility.editorOnly,
                isQuickNote: true,
                createdAt: quickNoteDate,
                updatedAt: quickNoteDate,
              ),
              NoteBlock(
                id: 'regular-note',
                text: 'Normale Note',
                visibility: NoteVisibility.editorOnly,
                createdAt: quickNoteDate,
                updatedAt: quickNoteDate,
              ),
            ],
          ),
        ),
      );
      await fixtureDatabase.close();

      sqlite.sqlite3.open(file.path)
        ..execute('ALTER TABLE sermons DROP COLUMN background_image_id')
        ..execute(
          'ALTER TABLE sermon_series DROP COLUMN background_image_id',
        )
        ..userVersion = 4
        ..close();

      final migrated = AppDatabase(NativeDatabase(file));
      addTearDown(migrated.close);
      final loaded = await DriftSermonRepository(
        migrated,
      ).watchById(created.id).first;
      final notes = loaded!.document.blocks.whereType<NoteBlock>().toList();

      expect(notes.map((note) => note.id), ['old-note', 'regular-note']);
      expect(notes.every((note) => !note.isQuickNote), isTrue);
    },
  );

  test('create, update, trash, restore and version snapshot', () async {
    final created = await repository.create();
    await repository.update(
      created.copyWith(
        title: 'Gespeicherte Predigt',
        status: SermonStatus.ready,
        contentKind: ContentKind.shortTopic,
        document: const SermonDocument(schemaVersion: 1, blocks: []),
      ),
    );
    var loaded = await repository.watchById(created.id).first;
    expect(loaded!.title, 'Gespeicherte Predigt');
    expect(loaded.status, SermonStatus.ready);
    expect(loaded.contentKind, ContentKind.shortTopic);

    await repository.saveVersion(created.id, 'test');
    expect(
      await database.select(database.documentVersions).get(),
      hasLength(1),
    );

    await repository.moveToTrash(created.id);
    loaded = await repository.watchById(created.id).first;
    expect(loaded!.isDeleted, isTrue);

    await repository.restore(created.id);
    loaded = await repository.watchById(created.id).first;
    expect(loaded!.isDeleted, isFalse);
  });

  test(
    'duplicates are linked versions and survive deleting the original',
    () async {
      final created = await repository.create();
      final duplicate = await repository.duplicate(created.id);
      expect(duplicate.id, isNot(created.id));
      expect(duplicate.title, created.title);
      expect(duplicate.versionRootId, created.id);
      expect(duplicate.backgroundImageId, created.backgroundImageId);

      await repository.deletePermanently(created.id);
      expect(await repository.watchById(created.id).first, isNull);
      final detached = await repository.watchById(duplicate.id).first;
      expect(detached, isNotNull);
      expect(detached!.versionRootId, isNull);
    },
  );
}
