import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
  testWidgets(
    'content duplication creates an independent newest linked version',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      const headingId = 'shared-heading';
      const paragraphId = 'script-paragraph';
      const secondParagraphId = 'script-paragraph-two';
      const scriptId = 'script-original';
      await repository.update(
        created.copyWith(
          title: 'Versions-Test',
          primaryBibleReference: const BibleReference(
            bookId: 'john',
            startChapter: 1,
            startVerse: 1,
            endChapter: 1,
            endVerse: 1,
            displayText: 'Johannes 1,1',
          ),
          document: SermonDocument(
            schemaVersion: SermonDocument.currentSchemaVersion,
            blocks: [
              HeadingBlock(
                id: headingId,
                level: 1,
                text: 'Gemeinsame Überschrift',
                collapsed: false,
                createdAt: now,
                updatedAt: now,
              ),
              ParagraphBlock(
                id: paragraphId,
                text: 'Eigenständiger Fließtext',
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
              ParagraphBlock(
                id: secondParagraphId,
                text: 'Zweiter Absatz',
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            modules: [
              SermonModule(
                id: 'notes-original',
                kind: SermonModuleKind.notes,
                title: 'Notizen',
                sortOrder: 0,
                blockIds: const [headingId],
                linkGroupId: 'linked-content',
                createdAt: now,
                updatedAt: now,
              ),
              SermonModule(
                id: scriptId,
                kind: SermonModuleKind.script,
                title: 'Skript',
                sortOrder: 1,
                blockIds: const [headingId, paragraphId, secondParagraphId],
                linkGroupId: 'linked-content',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ),
      );

      Future<Sermon> stored() async => sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(created.id))).getSingle(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(sermonId: created.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('duplicate-sermon-module-script')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      final sermon = await stored();
      final scripts = sermon.document.modulesOfKind(SermonModuleKind.script);
      expect(scripts, hasLength(2));
      final original = scripts.singleWhere((module) => module.id == scriptId);
      final version = scripts.singleWhere((module) => module.id != scriptId);
      expect(version.versionRootId, original.id);
      expect(version.revision, 2);
      expect(version.kind, original.kind);
      expect(version.linkGroupId, original.linkGroupId);
      expect(version.blockIds.first, headingId);
      expect(version.blockIds[1], isNot(paragraphId));
      expect(version.blockIds[2], isNot(secondParagraphId));
      expect(
        sermon.document.blocksForModule(version.id)[1].plainText,
        'Eigenständiger Fließtext',
      );
      expect(sermon.document.validateV2(), isEmpty);

      expect(
        find.byKey(Key('sermon-module-version-${version.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('sermon-module-version-${original.id}')),
        findsOneWidget,
      );
      expect(
        tester
            .getTopLeft(
              find.byKey(Key('sermon-module-drag-${version.id}')),
            )
            .dy,
        lessThan(
          tester
              .getTopLeft(
                find.byKey(Key('sermon-module-drag-${original.id}')),
              )
              .dy,
        ),
      );

      final scriptTitles = find.byKey(
        const Key('sermon-module-title-script'),
      );
      final notesTitle = find.byKey(
        const Key('sermon-module-title-notes'),
      );
      expect(scriptTitles, findsNWidgets(2));
      expect(
        tester.getTopLeft(scriptTitles.at(0)).dx,
        closeTo(tester.getTopLeft(notesTitle).dx, 0.1),
      );
      expect(
        tester.getTopLeft(scriptTitles.at(1)).dx,
        greaterThan(tester.getTopLeft(scriptTitles.at(0)).dx),
      );

      final versionFirstBlock = find.byKey(
        ValueKey('focus-fade-${version.blockIds[1]}'),
      );
      await tester.enterText(
        find.descendant(
          of: versionFirstBlock,
          matching: find.byType(EditableText),
        ),
        List.filled(
          12,
          'Dieser deutlich längere Absatz nimmt mehrere Zeilen ein.',
        ).join(' '),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-empty-workspace-pane')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('pane-picker-module-${original.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Inhalt öffnen'), findsNothing);
      expect(
        find.byKey(
          ValueKey('version-comparison-${version.id}-${original.id}'),
        ),
        findsOneWidget,
      );
      final versionSecondBlock = find.byKey(
        ValueKey('focus-fade-${version.id}-${version.blockIds[2]}'),
      );
      final originalSecondBlock = find.byKey(
        const ValueKey('focus-fade-script-original-script-paragraph-two'),
      );
      expect(versionSecondBlock, findsOneWidget);
      expect(originalSecondBlock, findsOneWidget);
      expect(
        tester.getTopLeft(versionSecondBlock).dy,
        closeTo(tester.getTopLeft(originalSecondBlock).dy, 0.1),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'multiple contents can be added, linked by drag and safely detached',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      await repository.update(
        created.copyWith(
          title: 'Modularer Test',
          primaryBibleReference: const BibleReference(
            bookId: 'john',
            startChapter: 1,
            startVerse: 1,
            endChapter: 1,
            endVerse: 1,
            displayText: 'Johannes 1,1',
          ),
        ),
      );

      Future<Sermon> stored() async => sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(created.id))).getSingle(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(sermonId: created.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('outline-add-content')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-content-notes')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      final firstNote = (await stored()).document
          .modulesOfKind(
            SermonModuleKind.notes,
          )
          .single;

      await tester.tap(find.byKey(const Key('workflow-stage-outline')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('outline-add-linked-content')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-linked-content-script')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      var sermon = await stored();
      final script = sermon.document
          .modulesOfKind(
            SermonModuleKind.script,
          )
          .single;
      expect(sermon.document.modulesAreLinked(firstNote.id, script.id), isTrue);

      await tester.tap(find.byKey(const Key('workflow-stage-outline')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('outline-add-content')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-content-notes')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      final notes = sermon.document.modulesOfKind(SermonModuleKind.notes);
      expect(notes, hasLength(2));
      final secondNote = notes.singleWhere(
        (module) => module.id != firstNote.id,
      );
      expect(secondNote.linkGroupId, isNull);
      expect(find.byKey(const Key('sermon-module-tree')), findsOneWidget);
      expect(find.byKey(const Key('sermon-module-notes')), findsOneWidget);
      expect(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('sermon-module-drop-${firstNote.id}')),
        findsOneWidget,
      );
      final linkedFirstRect = tester.getRect(
        find.byKey(Key('sermon-module-drag-${firstNote.id}')),
      );
      final linkedScriptRect = tester.getRect(
        find.byKey(Key('sermon-module-drag-${script.id}')),
      );
      final independentRect = tester.getRect(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
      );
      final linkedSpacing = linkedScriptRect.top - linkedFirstRect.bottom;
      final independentSpacing = independentRect.top - linkedScriptRect.bottom;
      expect(independentSpacing, greaterThan(linkedSpacing + 4));

      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(
              find.byKey(Key('sermon-module-drop-${firstNote.id}')),
            ) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(
        sermon.document.modulesAreLinked(secondNote.id, script.id),
        isTrue,
      );
      expect(sermon.document.validateV2(), isEmpty);

      final endPosition = find.byKey(
        const Key('sermon-module-position-end'),
      );
      await tester.ensureVisible(endPosition);
      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(endPosition) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(sermon.document.moduleById(secondNote.id)!.linkGroupId, isNull);
      expect(sermon.document.modulesAreLinked(firstNote.id, script.id), isTrue);
      expect(sermon.document.validateV2(), isEmpty);

      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(
              find.byKey(Key('sermon-module-drop-${firstNote.id}')),
            ) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(
        sermon.document.modulesAreLinked(secondNote.id, script.id),
        isTrue,
      );

      final startPosition = find.byKey(
        const Key('sermon-module-position-start'),
      );
      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(startPosition) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(sermon.document.moduleById(secondNote.id)!.linkGroupId, isNull);
      expect(sermon.document.modulesAreLinked(firstNote.id, script.id), isTrue);

      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(
              find.byKey(Key('sermon-module-drop-${firstNote.id}')),
            ) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(
        sermon.document.modulesAreLinked(secondNote.id, script.id),
        isTrue,
      );

      final firstItemRect = tester.getRect(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
      );
      final connectorRect = tester.getRect(
        find.byKey(Key('unlink-sermon-module-${firstNote.id}')),
      );
      final secondItemRect = tester.getRect(
        find.byKey(Key('sermon-module-drag-${firstNote.id}')),
      );
      expect(connectorRect.top, greaterThanOrEqualTo(firstItemRect.bottom));
      expect(connectorRect.bottom, lessThanOrEqualTo(secondItemRect.top));

      await tester.tap(
        find.byKey(Key('unlink-sermon-module-${firstNote.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(Key('confirm-unlink-sermon-module-${firstNote.id}')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      sermon = await stored();
      expect(sermon.document.moduleById(firstNote.id)!.linkGroupId, isNull);
      expect(
        sermon.document.modulesAreLinked(secondNote.id, script.id),
        isTrue,
      );
      expect(sermon.document.validateV2(), isEmpty);

      final firstNoteNavigation = find.byKey(
        Key('workflow-content-${firstNote.id}'),
      );
      await tester.ensureVisible(firstNoteNavigation.first);
      await tester.tap(firstNoteNavigation.first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      expect(find.text('Inhalt öffnen'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-empty-workspace-pane')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pane-content-picker-1')), findsOneWidget);
      await tester.tap(find.byKey(Key('pane-picker-module-${script.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Inhalt öffnen'), findsNothing);

      final rightPane = find.byKey(const Key('workspace-pane-drop-1'));
      await tester.drag(
        find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        tester.getCenter(rightPane) -
            tester.getCenter(
              find.byKey(Key('sermon-module-drag-${secondNote.id}')),
            ),
      );
      await tester.pumpAndSettle();
      final selectedSecondNote = find.descendant(
        of: find.byKey(Key('sermon-module-drag-${secondNote.id}')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected != null,
        ),
      );
      final secondNoteSemantics = tester.widget<Semantics>(
        selectedSecondNote.first,
      );
      expect(secondNoteSemantics.properties.selected, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
}
