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
