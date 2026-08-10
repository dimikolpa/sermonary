import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/application/welcome_sermon_seeder.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  test(
    'creates the example once and never restores it after deletion',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);

      await WelcomeSermonSeeder.ensureSeeded(database, repository);

      final rows = await database.select(database.sermonRows).get();
      expect(rows, hasLength(1));
      final sermon = sermonFromRow(rows.single);
      expect(sermon.title, 'Bleibt in mir');
      expect(sermon.primaryBibleReference?.bookId, 'john');
      expect(sermon.subtitle, isNotEmpty);
      expect(
        sermon.document.blocks.whereType<NoteBlock>().where(
          (note) => note.isQuickNote,
        ),
        hasLength(2),
      );
      expect(sermon.document.blocks.whereType<HeadingBlock>(), isNotEmpty);
      expect(sermon.document.blocks.whereType<ParagraphBlock>(), isNotEmpty);
      expect(
        sermon.document.blocks.whereType<NoteBlock>().where(
          (note) => !note.isQuickNote,
        ),
        isNotEmpty,
      );
      expect(
        sermon.document.schemaVersion,
        SermonDocument.currentSchemaVersion,
      );
      expect(sermon.document.validateV2(), isEmpty);
      expect(sermon.document.modules, hasLength(5));
      final linkedModules = sermon.document.modules
          .where((module) => module.linkGroupId != null)
          .toList(growable: false);
      expect(linkedModules, hasLength(3));
      expect(
        linkedModules.map((module) => module.linkGroupId).toSet(),
        hasLength(1),
      );
      expect(
        linkedModules.map((module) => module.kind).toSet(),
        {
          SermonModuleKind.notes,
          SermonModuleKind.script,
          SermonModuleKind.presentation,
        },
      );
      final independentModules = sermon.document.modules
          .where((module) => module.linkGroupId == null)
          .toList(growable: false);
      expect(independentModules, hasLength(2));
      for (final module in sermon.document.modules) {
        if (module.kind == SermonModuleKind.presentation) {
          expect(sermon.document.slidesForModule(module.id), isNotEmpty);
        } else {
          expect(sermon.document.blocksForModule(module.id), isNotEmpty);
        }
      }
      expect(sermon.document.presentation.slides, hasLength(3));
      expect(
        sermon.document.presentation.slides.every(
          (slide) => slide.anchor?.moduleId != null,
        ),
        isTrue,
      );

      await repository.deletePermanently(sermon.id);
      await WelcomeSermonSeeder.ensureSeeded(database, repository);

      expect(await database.select(database.sermonRows).get(), isEmpty);
      expect(
        await database.select(database.appSettings).get(),
        hasLength(1),
      );
    },
  );

  test('marks an existing archive without adding an example', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final existing = await repository.create();
    await repository.update(existing.copyWith(title: 'Eigene Predigt'));

    await WelcomeSermonSeeder.ensureSeeded(database, repository);

    final rows = await database.select(database.sermonRows).get();
    expect(rows, hasLength(1));
    expect(rows.single.title, 'Eigene Predigt');
    expect(await database.select(database.appSettings).get(), hasLength(1));
  });
}
