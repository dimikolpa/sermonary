import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:sermonary/features/workspace/presentation/workspace_screen.dart';

void main() {
  testWidgets('navigation remains stable while earlier saves finish', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final parser = BibleReferenceParser();
    final sermons = <Sermon>[];

    for (final entry in const [
      ('Früher Abschnitt', 'Johannes 2,1'),
      ('Später Abschnitt', 'Johannes 10,1'),
      ('Bergpredigt', 'Matthäus 5,1'),
    ]) {
      final created = await repository.create();
      final sermon = created.copyWith(
        title: entry.$1,
        primaryBibleReference: parser.parse(entry.$2),
      );
      await repository.update(sermon);
      sermons.add(sermon);
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          sermonRepositoryProvider.overrideWithValue(
            _DelayedSermonRepository(repository),
          ),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SermonWorkspaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Johannes').first);
    await tester.pump();
    await tester.tap(find.text('Später Abschnitt'));
    await tester.pump();
    await tester.tap(find.text('Matthäus').first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(find.text('Bergpredigt'), findsWidgets);
    expect(find.text('Später Abschnitt'), findsNothing);

    await repository.update(
      sermons.first.copyWith(subtitle: 'Extern aktualisiert'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bergpredigt'), findsWidgets);
    expect(find.text('Später Abschnitt'), findsNothing);

    await tester.tap(find.text('Vorträge').first);
    await tester.pumpAndSettle();
    expect(find.text('Bergpredigt'), findsNothing);
    expect(find.text('Später Abschnitt'), findsNothing);
    expect(find.text('Ersten Eintrag anlegen'), findsOneWidget);

    await tester.tap(find.text('Matthäus').first);
    await tester.pumpAndSettle();
    expect(find.text('Bergpredigt'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Enter creates and focuses the next editor paragraph', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      title: 'Fokustest',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'first-paragraph',
            text: 'Erster Absatz',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            sermonId: sermon.id,
            initialView: WorkspaceView.script,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstParagraph = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.focusNode != null,
    );
    expect(firstParagraph, findsOneWidget);
    await tester.tap(firstParagraph);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final paragraphs = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.focusNode != null,
    );
    expect(paragraphs, findsNWidgets(2));
    final nextField = tester.widget<TextField>(paragraphs.last);
    expect(nextField.focusNode?.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Bible references become script quotes and note bullets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final now = DateTime.now().toUtc();
    final created = await repository.create();
    final sermon = created.copyWith(
      title: 'Bibelstellentest',
      contentKind: ContentKind.sermon,
      primaryBibleReference: BibleReferenceParser().parse('Johannes 3,16'),
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'script-paragraph',
            text: 'Skriptabsatz',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
          NoteBlock(
            id: 'existing-note',
            text: 'Bestehende Notiz',
            visibility: NoteVisibility.editorOnly,
            depth: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            sermonId: sermon.id,
            initialView: WorkspaceView.script,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Bibelstelle einfügen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bible-reference-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('insert-bible-reference')));
    await tester.pump();
    expect(
      find.text('Bitte zuerst den kopierten Bibeltext einfügen.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bible-reference-dialog')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('bible-text-field')),
      '16\u00a0Denn so sehr hat Gott[1] die Welt geliebt.\u200217\u00a0Gott sandte seinen Sohn.',
    );
    await tester.tap(find.byKey(const Key('insert-bible-reference')));
    await tester.pump(const Duration(milliseconds: 700));

    var saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<QuoteBlock>().map((block) => block.text),
      contains(
        'Denn so sehr hat Gott die Welt geliebt. '
        'Gott sandte seinen Sohn. Johannes 3: 16-17',
      ),
    );

    await tester.tap(find.byTooltip('Notizen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notizen'));
    await tester.pumpAndSettle();
    final existingNote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Bestehende Notiz',
    );
    expect(existingNote, findsOneWidget);
    await tester.tap(existingNote);
    await tester.pump();

    await tester.tap(find.byTooltip('Bibelstelle einfügen'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('bible-text-field')),
      '18\u00a0Wer an ihn glaubt[4], wird nicht gerichtet.',
    );
    await tester.tap(find.byKey(const Key('insert-bible-reference')));
    await tester.pump(const Duration(milliseconds: 700));

    saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final notes = saved.document.blocks.whereType<NoteBlock>().toList();
    const insertedText =
        'Wer an ihn glaubt, wird nicht gerichtet. Johannes 3: 18';
    expect(notes.map((block) => block.text), contains(insertedText));
    final insertedNote = notes.singleWhere(
      (block) => block.text == insertedText,
    );
    expect(insertedNote.depth, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _DelayedSermonRepository implements SermonRepository {
  _DelayedSermonRepository(this.delegate);

  final SermonRepository delegate;

  @override
  Stream<List<Sermon>> watchAll() => delegate.watchAll();

  @override
  Stream<Sermon?> watchById(String id) => delegate.watchById(id);

  @override
  Future<Sermon> create() => delegate.create();

  @override
  Future<void> update(Sermon sermon) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await delegate.update(sermon);
  }

  @override
  Future<void> moveToTrash(String id) => delegate.moveToTrash(id);

  @override
  Future<void> restore(String id) => delegate.restore(id);

  @override
  Future<void> deletePermanently(String id) => delegate.deletePermanently(id);

  @override
  Future<Sermon> duplicate(String id) => delegate.duplicate(id);

  @override
  Future<void> saveVersion(String id, String reason) =>
      delegate.saveVersion(id, reason);
}
