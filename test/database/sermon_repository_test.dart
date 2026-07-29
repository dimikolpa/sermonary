import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  late AppDatabase database;
  late DriftSermonRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftSermonRepository(database);
  });

  tearDown(() => database.close());

  test('schema version 2 creates all required tables', () async {
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
      ]),
    );
    expect(database.schemaVersion, 2);
    final sermonColumns = await database
        .customSelect('PRAGMA table_info(sermons)')
        .get();
    expect(
      sermonColumns.map((row) => row.read<String>('name')),
      contains('content_kind'),
    );
  });

  test('migration from schema 1 adds content kind non-destructively', () async {
    await database.close();
    final legacy = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDatabase) {
          rawDatabase
            ..execute(
              'CREATE TABLE sermons (id TEXT NOT NULL PRIMARY KEY)',
            )
            ..userVersion = 1;
        },
      ),
    );
    addTearDown(legacy.close);

    final columns = await legacy
        .customSelect('PRAGMA table_info(sermons)')
        .get();
    expect(
      columns.map((row) => row.read<String>('name')),
      contains('content_kind'),
    );
    expect(
      columns
          .singleWhere((row) => row.read<String>('name') == 'content_kind')
          .read<String>('dflt_value'),
      "'sermon'",
    );
  });

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

  test('duplicate and permanent delete work', () async {
    final created = await repository.create();
    final duplicate = await repository.duplicate(created.id);
    expect(duplicate.id, isNot(created.id));
    expect(duplicate.title, contains('Kopie'));

    await repository.deletePermanently(created.id);
    expect(await repository.watchById(created.id).first, isNull);
  });
}
