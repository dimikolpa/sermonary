import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/feedback/application/local_feedback_service.dart';
import 'package:sermonary/features/library/application/welcome_sermon_seeder.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/live_mode/presentation/live_mode_screen.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:sermonary/features/workspace/application/rich_clipboard_paste.dart';
import 'package:sermonary/features/workspace/presentation/workspace_screen.dart';

const _testSeriesBackgroundIds = {
  'generic2',
  'generic3',
  'generic4',
  'generic5',
  'generic6',
};

final LogicalKeyboardKey _primaryModifierKey = Platform.isMacOS
    ? LogicalKeyboardKey.metaLeft
    : LogicalKeyboardKey.controlLeft;

String _outlineAssetName(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const Key('outline-notebook-background')),
  );
  final decoration = container.decoration! as BoxDecoration;
  final resized = decoration.image!.image as ResizeImage;
  return (resized.imageProvider as AssetImage).assetName;
}

bool _workflowStageActive(WidgetTester tester, String stage) => find
    .byKey(Key('workflow-stage-$stage'))
    .evaluate()
    .map((element) => element.widget)
    .whereType<Semantics>()
    .any((widget) => widget.properties.selected ?? false);

bool _moduleTreeActive(WidgetTester tester, String module) =>
    tester
        .widget<Semantics>(find.byKey(Key('sermon-module-$module')))
        .properties
        .selected ??
    false;

Future<void> _tapPaneStage(
  WidgetTester tester,
  String stage, {
  bool last = false,
}) async {
  final matches = find.byKey(Key('workflow-stage-$stage'));
  final target = last ? matches.last : matches.first;
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
}

void main() {
  testWidgets('empty sermon grows modular navigation from the Outline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final sermon = await repository.create();
    await repository.update(
      sermon.copyWith(
        title: 'Modulare Predigt',
        primaryBibleReference: BibleReferenceParser().parsePassage(
          'Johannes 3,16',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Outline'), findsNothing);
    expect(find.byTooltip('Notizen'), findsNothing);
    expect(find.byTooltip('Skript'), findsNothing);
    expect(find.byKey(const Key('presentation-view-button')), findsNothing);
    expect(_workflowStageActive(tester, 'outline'), isTrue);
    expect(find.byKey(const Key('workflow-stage-notes')), findsNothing);
    expect(find.byKey(const Key('workflow-stage-script')), findsNothing);
    expect(find.byKey(const Key('sermon-module-tree')), findsOneWidget);
    expect(find.byKey(const Key('sermon-module-add')), findsOneWidget);

    await tester.tap(find.byKey(const Key('outline-add-content')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-content-dialog')), findsOneWidget);
    expect(find.byKey(const Key('add-content-notes')), findsOneWidget);
    expect(find.byKey(const Key('add-content-script')), findsOneWidget);
    expect(find.byKey(const Key('add-content-presentation')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-content-notes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sermon-module-tree')), findsOneWidget);
    expect(find.byKey(const Key('sermon-module-notes')), findsOneWidget);
    expect(find.byTooltip('Notizen'), findsOneWidget);
    expect(_workflowStageActive(tester, 'notes'), isTrue);
    expect(find.byKey(const Key('workflow-stage-script')), findsNothing);

    await tester.tap(find.byTooltip('Live-Ansicht'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live-content-dialog')), findsOneWidget);
    expect(find.byKey(const Key('live-content-notes')), findsOneWidget);
    expect(find.byKey(const Key('live-content-script')), findsNothing);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('workflow-stage-outline')));
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'outline'), isTrue);

    final stored = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(stored.document.hasModule(SermonModuleKind.notes), isTrue);
    expect(stored.document.hasModule(SermonModuleKind.script), isFalse);

    await tester.tap(
      find.byKey(const Key('delete-sermon-module-notes')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Notizen löschen?'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sermon-module-notes')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('delete-sermon-module-notes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-sermon-module')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
    expect(_workflowStageActive(tester, 'outline'), isTrue);
    expect(find.byKey(const Key('sermon-module-notes')), findsNothing);
    expect(find.byKey(const Key('sermon-module-add')), findsOneWidget);
    final storedAfterDelete = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      storedAfterDelete.document.hasModule(SermonModuleKind.notes),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('bottom workflow navigation reflects single and split views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final sermon = created.copyWith(
      title: 'Der gute Hirte',
      primaryBibleReference: BibleReferenceParser().parsePassage(
        'Johannes 10,11',
      ),
      document: const SermonDocument(
        schemaVersion: SermonDocument.currentSchemaVersion,
        blocks: [],
        modules: [
          SermonModule(
            id: 'notes',
            kind: SermonModuleKind.notes,
            title: 'Notizen',
            sortOrder: 0,
          ),
          SermonModule(
            id: 'script',
            kind: SermonModuleKind.script,
            title: 'Skript',
            sortOrder: 1,
          ),
          SermonModule(
            id: 'presentation',
            kind: SermonModuleKind.presentation,
            title: 'Präsentation',
            sortOrder: 2,
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
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sermon-workflow-navigation')), findsOneWidget);
    expect(find.text('Der gute Hirte'), findsWidgets);
    expect(
      find.byKey(const Key('workflow-content-icon-notes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workflow-content-icon-script')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workflow-content-icon-presentation')),
      findsOneWidget,
    );
    expect(_workflowStageActive(tester, 'outline'), isTrue);
    expect(_workflowStageActive(tester, 'notes'), isFalse);
    final presentationTitle = tester.renderObject<RenderParagraph>(
      find.byKey(const Key('sermon-module-title-presentation')),
    );
    expect(presentationTitle.didExceedMaxLines, isFalse);

    await tester.tap(find.byKey(const Key('workflow-stage-notes')));
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'notes'), isTrue);
    expect(_workflowStageActive(tester, 'script'), isFalse);
    expect(_moduleTreeActive(tester, 'notes'), isTrue);
    expect(_moduleTreeActive(tester, 'script'), isFalse);

    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('sermon-workflow-navigation')),
      findsNWidgets(2),
    );
    expect(find.text('Inhalt öffnen'), findsOneWidget);

    await _tapPaneStage(tester, 'script', last: true);
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'notes'), isTrue);
    expect(_workflowStageActive(tester, 'script'), isTrue);
    expect(_moduleTreeActive(tester, 'notes'), isTrue);
    expect(_moduleTreeActive(tester, 'script'), isTrue);

    await _tapPaneStage(tester, 'presentation');
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'notes'), isFalse);
    expect(_workflowStageActive(tester, 'script'), isTrue);
    expect(_workflowStageActive(tester, 'presentation'), isTrue);
    expect(_moduleTreeActive(tester, 'notes'), isFalse);
    expect(_moduleTreeActive(tester, 'script'), isTrue);
    expect(_moduleTreeActive(tester, 'presentation'), isTrue);

    // Opening the same content in the other pane moves it and empties its
    // previous pane instead of rendering it twice.
    await _tapPaneStage(tester, 'presentation', last: true);
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'script'), isFalse);
    expect(_workflowStageActive(tester, 'presentation'), isTrue);
    expect(_moduleTreeActive(tester, 'script'), isFalse);
    expect(_moduleTreeActive(tester, 'presentation'), isTrue);

    expect(find.text('Inhalt öffnen'), findsOneWidget);

    await _tapPaneStage(tester, 'notes');
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'notes'), isTrue);
    expect(_workflowStageActive(tester, 'presentation'), isTrue);

    await _tapPaneStage(tester, 'script');
    await tester.pumpAndSettle();
    expect(_workflowStageActive(tester, 'notes'), isFalse);
    expect(_workflowStageActive(tester, 'script'), isTrue);
    expect(_workflowStageActive(tester, 'presentation'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'split word count follows the edited content and otherwise the left pane',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      await repository.update(
        created.copyWith(
          title: 'Getrennte Wortzählung',
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
              ParagraphBlock(
                id: 'left-words',
                text: 'zwei Wörter',
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
              ParagraphBlock(
                id: 'right-words',
                text: 'hier stehen genau vier Wörter',
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
            ],
            modules: [
              SermonModule(
                id: 'left-script',
                kind: SermonModuleKind.script,
                title: 'Links',
                sortOrder: 0,
                blockIds: const ['left-words'],
                createdAt: now,
                updatedAt: now,
              ),
              SermonModule(
                id: 'right-script',
                kind: SermonModuleKind.script,
                title: 'Rechts',
                sortOrder: 1,
                blockIds: const ['right-words'],
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(
              sermonId: created.id,
              initialView: WorkspaceView.script,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.controller?.text == 'zwei Wörter',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('toolbar-word-count-value-2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-empty-workspace-pane')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('pane-picker-module-right-script')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('toolbar-word-count-value-2')),
        findsOneWidget,
      );

      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.controller?.text == 'hier stehen genau vier Wörter',
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('toolbar-word-count-value-5')),
        findsOneWidget,
      );

      tester
          .widget<GestureDetector>(
            find.byKey(const Key('editor-page-dismiss-focus')),
          )
          .onTap!();
      await tester.pump();
      expect(
        find.byKey(const Key('toolbar-word-count-value-2')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('live mode highlights Live in the workflow navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      document: SermonDocument(
        schemaVersion: SermonDocument.currentSchemaVersion,
        modules: const [
          SermonModule(
            id: 'live-notes',
            kind: SermonModuleKind.notes,
            title: 'Notizen',
            sortOrder: 0,
            blockIds: ['live-note'],
            linkGroupId: 'live-group',
          ),
          SermonModule(
            id: 'live-script',
            kind: SermonModuleKind.script,
            title: 'Skript',
            sortOrder: 1,
            blockIds: ['live-script-paragraph'],
            linkGroupId: 'live-group',
          ),
          SermonModule(
            id: 'live-presentation',
            kind: SermonModuleKind.presentation,
            title: 'Präsentation',
            sortOrder: 2,
            slideIds: ['live-slide'],
            linkGroupId: 'live-group',
          ),
        ],
        blocks: [
          NoteBlock(
            id: 'live-note',
            text: 'Nur in Notizen',
            visibility: NoteVisibility.editorOnly,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'live-script-paragraph',
            text: 'Nur im Skript',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        presentation: const PresentationDeck(
          slides: [
            PresentationSlide(
              id: 'live-slide',
              template: PresentationSlideTemplate.headingText,
              title: 'Folie im Live-Modus',
              body: 'Der Folienwechsel ist am Text sichtbar.',
              anchor: PresentationAnchor(
                view: PresentationAnchorView.notes,
                blockId: 'live-note',
                moduleId: 'live-notes',
              ),
            ),
          ],
        ),
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
          home: LiveModeScreen(
            sermonId: sermon.id,
            contentSource: LiveContentSource.notes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sermon-workflow-navigation')), findsOneWidget);
    expect(_workflowStageActive(tester, 'live'), isTrue);
    expect(_workflowStageActive(tester, 'outline'), isFalse);
    expect(find.text('Nur in Notizen'), findsOneWidget);
    expect(find.text('Nur im Skript'), findsNothing);
    expect(find.byKey(const Key('live-slide-marker-1')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('script slide markers include their presentation number', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    await repository.update(
      created.copyWith(
        document: SermonDocument(
          schemaVersion: SermonDocument.currentSchemaVersion,
          blocks: [
            ParagraphBlock(
              id: 'numbered-anchor',
              text: 'An dieser Stelle wechselt die Folie.',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          modules: const [
            SermonModule(
              id: 'numbered-script',
              kind: SermonModuleKind.script,
              title: 'Skript',
              sortOrder: 0,
              blockIds: ['numbered-anchor'],
              linkGroupId: 'numbered-group',
            ),
            SermonModule(
              id: 'numbered-presentation',
              kind: SermonModuleKind.presentation,
              title: 'Präsentation',
              sortOrder: 1,
              slideIds: ['numbered-slide'],
              linkGroupId: 'numbered-group',
            ),
          ],
          presentation: const PresentationDeck(
            slides: [
              PresentationSlide(
                id: 'numbered-slide',
                template: PresentationSlideTemplate.headingText,
                title: 'Nummerierte Folie',
                anchor: PresentationAnchor(
                  view: PresentationAnchorView.script,
                  blockId: 'numbered-anchor',
                  moduleId: 'numbered-script',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            sermonId: created.id,
            initialView: WorkspaceView.script,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('slide-anchor-marker-1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('presentation mode creates and persists a Figma title slide', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    await repository.update(created.copyWith(title: 'Bleibt in mir'));

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
    await tester.tap(find.byKey(const Key('add-content-presentation')));
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Folien'), findsOneWidget);

    await tester.tap(find.byKey(const Key('presentation-add-slide')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('presentation-template-title')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Bleibt in mir'), findsWidgets);
    expect(
      find.byTooltip('PowerPoint bearbeitbar exportieren'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('presentation-add-slide')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('presentation-template-headingBible')),
    );
    await tester.pump();
    final bibleTextField = find.byKey(
      const Key('presentation-field-bibeltext'),
    );
    await tester.enterText(bibleTextField, 'Bleibt in mir und ich in euch.');
    tester.widget<TextField>(bibleTextField).controller!.selection =
        const TextSelection(baseOffset: 0, extentOffset: 6);
    await tester.pump();
    final boldButton = find.byKey(
      const Key('presentation-format-bibeltext-bold'),
    );
    await tester.ensureVisible(boldButton);
    await tester.pumpAndSettle();
    await tester.tap(boldButton);
    await tester.tap(
      find.byKey(const Key('presentation-format-bibeltext-italic')),
    );
    await tester.tap(
      find.byKey(const Key('presentation-format-bibeltext-highlight')),
    );
    await tester.pump();
    final referenceField = find.byKey(
      const Key('presentation-field-bibelstelle'),
    );
    await tester.ensureVisible(referenceField);
    await tester.pumpAndSettle();
    await tester.tap(referenceField);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Bleibt in mir und ich in euch.'), findsWidgets);

    final stored = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(created.id))).getSingle(),
    );
    expect(stored.document.presentation.slides, hasLength(2));
    expect(
      stored.document.presentation.slides.first.template,
      PresentationSlideTemplate.title,
    );
    expect(
      stored.document.presentation.slides.last.body,
      'Bleibt in mir und ich in euch.',
    );
    final bodyMark = stored.document.presentation.slides.last.bodyMarks.single;
    expect(bodyMark.bold, isTrue);
    expect(bodyMark.italic, isTrue);
    expect(bodyMark.highlighted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('long Bible slide text is paginated without losing content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    const anchor = PresentationAnchor(
      view: PresentationAnchorView.script,
      blockId: 'quote-1',
      offset: 8,
    );
    await repository.update(
      created.copyWith(
        document: created.document.copyWith(
          presentation: const PresentationDeck(
            slides: [
              PresentationSlide(
                id: 'long-bible-slide',
                template: PresentationSlideTemplate.headingBible,
                title: 'Gottes Wort',
                reference: 'Psalm 119,1–8',
                anchor: PresentationAnchor(
                  view: PresentationAnchorView.script,
                  blockId: 'quote-1',
                  offset: 8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final text = List.generate(
      180,
      (index) => 'Verswort${index + 1}',
    ).join(' ');

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
    await tester.tap(find.byKey(const Key('presentation-view-button')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('presentation-field-bibeltext'));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
    await tester.pump(const Duration(milliseconds: 900));

    final stored = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(created.id))).getSingle(),
    );
    final slides = stored.document.presentation.slides;
    expect(slides.length, greaterThan(1));
    expect(slides.map((slide) => slide.body).join(' '), text);
    expect(
      slides.map((slide) => slide.anchor?.blockId),
      everyElement(anchor.blockId),
    );
    expect(
      slides.map((slide) => slide.anchor?.offset),
      everyElement(anchor.offset),
    );
    expect(
      slides.map((slide) => slide.continuationCount),
      everyElement(slides.length),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'smart slide uses the selected text, surrounding heading and anchor',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(2000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      await repository.update(
        created.copyWith(
          title: 'Intelligente Predigt',
          document: SermonDocument(
            schemaVersion: 1,
            modules: const [
              SermonModule(
                id: 'smart-presentation',
                kind: SermonModuleKind.presentation,
                title: 'Präsentation',
                sortOrder: 2,
              ),
            ],
            blocks: [
              HeadingBlock(
                id: 'smart-heading',
                level: 2,
                text: 'Abschnittstitel',
                collapsed: false,
                createdAt: now,
                updatedAt: now,
              ),
              ParagraphBlock(
                id: 'smart-paragraph',
                text: 'So geh hin und versammle alle Juden. Ester 4:16',
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(
              sermonId: created.id,
              initialView: WorkspaceView.script,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();

      final paragraphField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text ==
                'So geh hin und versammle alle Juden. Ester 4:16',
      );
      await tester.tap(paragraphField);
      final field = tester.widget<TextField>(paragraphField);
      field.controller!.selection = TextSelection(
        baseOffset: 0,
        extentOffset: field.controller!.text.length,
      );
      await tester.pump();

      await _tapPaneStage(tester, 'presentation', last: true);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('presentation-smart-add-slide')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('presentation-smart-add-slide')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('presentation-template-headingBible')),
      );
      await tester.pump(const Duration(milliseconds: 700));

      final stored = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(created.id))).getSingle(),
      );
      final slide = stored.document.presentation.slides.single;
      expect(slide.title, 'Abschnittstitel');
      expect(slide.body, 'So geh hin und versammle alle Juden.');
      expect(slide.reference, 'Ester 4,16');
      expect(slide.anchor?.blockId, 'smart-paragraph');
      expect(slide.anchor?.offset, 0);
      expect(slide.anchor?.view, PresentationAnchorView.script);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('beta feedback is validated and stored locally', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final feedbackService = _FakeLocalFeedbackService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            feedbackService: feedbackService,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('feedback-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feedback-dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pump();
    expect(
      find.text('Bitte eine kurze Beschreibung eingeben.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      'Die Sortierung ist für mich nicht nachvollziehbar.',
    );
    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feedback-success-dialog')), findsOneWidget);
    expect(feedbackService.savedCategory, FeedbackCategory.bug);
    expect(feedbackService.savedDescription, contains('nicht nachvollziehbar'));
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('question-mark onboarding explains navigation and all views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    await WelcomeSermonSeeder.ensureSeeded(database, repository);
    final sermon = sermonFromRow(
      (await database.select(database.sermonRows).get()).single,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('onboarding-help-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-card')), findsOneWidget);
    expect(find.text('Dein Archiv'), findsOneWidget);
    expect(
      find.textContaining('nach Bibelbuch, Vortragsreihe'),
      findsOneWidget,
    );

    const expectedTitles = [
      'Predigt und Inhalte',
      'Outline',
      'Modular schreiben',
      'Splitscreen',
      'Präsentation',
      'Live-Ansicht',
      'Export',
    ];
    for (final title in expectedTitles) {
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-card')),
          matching: find.text(title),
        ),
        findsOneWidget,
      );
      if (title == 'Präsentation') {
        expect(
          find.textContaining('bearbeitbare oder pixelgetreue'),
          findsNothing,
        );
        expect(find.textContaining('verankere sie'), findsOneWidget);
      }
      if (title == 'Export') {
        expect(
          find.textContaining('bearbeitbare oder pixelgetreue PowerPoint'),
          findsOneWidget,
        );
      }
      if (title == 'Predigt und Inhalte') {
        final entryColumn = tester.getRect(
          find.byKey(const Key('entry-column-shell')),
        );
        final highlight = tester.getRect(
          find.byKey(const Key('onboarding-highlight')),
        );
        expect(highlight.left, closeTo(entryColumn.left - 5, 0.1));
        expect(highlight.top, closeTo(entryColumn.top - 5, 0.1));
        expect(highlight.width, closeTo(entryColumn.width + 10, 0.1));
        expect(highlight.height, closeTo(entryColumn.height + 10, 0.1));
      }
      if (title == 'Splitscreen') {
        final splitButton = tester.getRect(
          find.byKey(const Key('toggle-workspace-split')),
        );
        final highlight = tester.getRect(
          find.byKey(const Key('onboarding-highlight')),
        );
        expect(highlight.center, splitButton.center);
      }
    }
    expect(find.text('8 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding-card')), findsNothing);
    expect(find.byKey(const Key('onboarding-help-button')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('footer new-sermon action opens the new sermon Outline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final existing = await repository.create();
    await repository.update(
      existing.copyWith(
        title: 'Bestehende Predigt',
        contentKind: ContentKind.shortTopic,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            sermonId: existing.id,
            initialView: WorkspaceView.script,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('quick-new-sermon')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);
    expect(find.byKey(const Key('entry-column-shell')), findsNothing);
    expect(find.text('Unbenannte Predigt'), findsWidgets);
    expect(await database.select(database.sermonRows).get(), hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('import opens the imported sermon directly in Outline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final previous = await repository.create();
    await repository.update(
      previous.copyWith(
        title: 'Vorherige Predigt',
        contentKind: ContentKind.shortTopic,
      ),
    );
    final importFile = XFile.fromData(
      Uint8List.fromList(
        utf8.encode('''
<title>Importierte Predigt</title>
<bible>Johannes 15,4–11</bible>
<h1>Der Weinstock</h1>
<p>Bleibt in mir.</p>
'''),
      ),
      path: '/virtual/Importierte_Predigt.md',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            sermonId: previous.id,
            initialView: WorkspaceView.script,
            importFilePicker: () async => importFile,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Script'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);
    expect(find.text('Importierte Predigt'), findsWidgets);
    final sermons = await database.select(database.sermonRows).get();
    expect(sermons, hasLength(2));
    final imported = sermons.singleWhere(
      (row) => row.title == 'Importierte Predigt',
    );
    expect(imported.id, isNot(previous.id));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('export menu separates Notes, Script and presentation actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final sermon = await repository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Exportieren und drucken'));
    await tester.pumpAndSettle();
    expect(find.text('Notizen'), findsOneWidget);
    expect(find.text('Script'), findsOneWidget);
    expect(find.text('Präsentation'), findsOneWidget);
    expect(find.text('PDF'), findsNWidgets(3));
    expect(find.text('Word'), findsNWidgets(2));
    expect(find.text('Print'), findsNWidgets(2));
    expect(find.text('PowerPoint · bearbeitbar'), findsOneWidget);
    expect(find.text('PowerPoint · pixelgetreu'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dark mode switches to the assigned background asset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final sermon = created.copyWith(
      contentKind: ContentKind.shortTopic,
      backgroundImageId: 'generic4',
    );
    await repository.update(sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: Consumer(
          builder: (context, ref, child) => MaterialApp(
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: ref.watch(themeModeProvider),
            home: SermonWorkspaceScreen(sermonId: sermon.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_outlineAssetName(tester), endsWith('background/generic4.jpg'));
    await tester.tap(find.byTooltip('Dunkle Ansicht'));
    await tester.pumpAndSettle();
    expect(
      _outlineAssetName(tester),
      endsWith('background_dark/generic4-dark.jpg'),
    );
    expect(find.byTooltip('Helle Ansicht'), findsOneWidget);
    expect(find.byKey(const Key('navigation-logo-filter')), findsOneWidget);
    final card = tester.widget<Container>(
      find.byKey(const Key('outline-notebook-card')),
    );
    expect(
      (card.decoration! as BoxDecoration).color,
      const Color(0xFF11110F),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a Bible sermon uses its dedicated image in both themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final sermon = created.copyWith(
      primaryBibleReference: const BibleReference(
        bookId: 'gen',
        startChapter: 1,
        displayText: '1. Mose 1',
      ),
    );
    await repository.update(sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: Consumer(
          builder: (context, ref, child) => MaterialApp(
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: ref.watch(themeModeProvider),
            home: SermonWorkspaceScreen(sermonId: sermon.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_outlineAssetName(tester), endsWith('1_1Mose/1mose.jpg'));
    await tester.tap(find.byTooltip('Dunkle Ansicht'));
    await tester.pumpAndSettle();
    expect(
      _outlineAssetName(tester),
      endsWith('background_dark/1_1Mose/1mose-dark.jpg'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dark start screen inverts the new-sermon action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.dark),
          home: const SermonWorkspaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final actionBackground = tester.widget<DecoratedBox>(
      find.byKey(const Key('start-screen-action-background')),
    );
    expect(
      (actionBackground.decoration as BoxDecoration).color,
      const Color(0xFF11110F).withValues(alpha: 0.94),
    );
    final actionText = tester.widget<Text>(find.text('Neue Predigt anlegen'));
    expect(actionText.style!.color!.computeLuminance(), greaterThan(0.5));
    expect(find.byKey(const Key('navigation-logo-filter')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a sermon opens in outline view by default', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final sermon = await repository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('title-${sermon.id}')), findsOneWidget);
    expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);
    expect(find.byKey(const Key('outline-background-button')), findsOneWidget);
    final backgroundRect = tester.getRect(
      find.byKey(const Key('outline-notebook-background')),
    );
    final cardRect = tester.getRect(
      find.byKey(const Key('outline-notebook-card')),
    );
    expect(cardRect.width, 460);
    expect(cardRect.center.dx, closeTo(backgroundRect.center.dx, 0.5));
    expect(cardRect.top - backgroundRect.top, greaterThanOrEqualTo(32));
    expect(backgroundRect.bottom - cardRect.bottom, greaterThanOrEqualTo(32));
    final addContentRect = tester.getRect(
      find.byKey(const Key('outline-add-content')),
    );
    expect(addContentRect.top, greaterThan(cardRect.bottom));
    expect(
      backgroundRect.bottom - addContentRect.bottom,
      greaterThanOrEqualTo(100),
    );
    final backgroundButtonRect = tester.getRect(
      find.byKey(const Key('outline-background-button')),
    );
    expect(backgroundButtonRect.center.dx, lessThan(cardRect.left));
    await tester.tap(find.byTooltip('Hintergrund wechseln'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outline-background-picker')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('outline-background-generic6')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('outline-background-picker')), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.backgroundImageId, 'generic6');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Outline scrolls only description and quicknotes while overview and Save stay visible',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Feststehende Übersicht',
        contentKind: ContentKind.shortTopic,
        subtitle: List.filled(8, 'Eine ausführliche Beschreibung.').join(' '),
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            for (var index = 0; index < 16; index++)
              NoteBlock(
                id: 'quicknote-$index',
                text: 'Quicknote Nummer $index mit etwas mehr Inhalt',
                visibility: NoteVisibility.editorOnly,
                isQuickNote: true,
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
            home: SermonWorkspaceScreen(sermonId: sermon.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final details = find.byKey(const Key('outline-details-scroll'));
      final scrollable = find
          .descendant(
            of: details,
            matching: find.byType(Scrollable),
          )
          .first;
      final scrollableWidget = tester.widget<Scrollable>(scrollable);
      expect(
        scrollableWidget.controller!.position.maxScrollExtent,
        greaterThan(0),
      );
      expect(
        find.byKey(ValueKey('title-${sermon.id}')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('SPEICHERN').hitTestable(), findsOneWidget);

      final detailsRect = tester.getRect(details);
      await tester.dragFrom(
        Offset(detailsRect.center.dx, detailsRect.bottom - 12),
        const Offset(0, -280),
      );
      await tester.pumpAndSettle();

      expect(scrollableWidget.controller!.position.pixels, greaterThan(0));
      expect(
        find.byKey(ValueKey('title-${sermon.id}')).hitTestable(),
        findsOneWidget,
      );
      expect(find.text('SPEICHERN').hitTestable(), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Outline quicknotes are top-level notes and sync to Notes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final sermon = await repository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: sermon.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('QUICKNOTES'), findsNothing);
    final addQuicknote = find.text('—  Quicknote einfügen');
    await tester.ensureVisible(addQuicknote);
    await tester.pumpAndSettle();
    await tester.tap(addQuicknote);
    await tester.pumpAndSettle();
    final quicknoteContainer = find.byWidgetPredicate(
      (widget) =>
          widget is AnimatedOpacity &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('focus-fade-'),
    );
    final quicknote = find.descendant(
      of: quicknoteContainer,
      matching: find.byType(TextField),
    );
    expect(quicknote, findsOneWidget);
    final quicknoteEditable = tester.widget<EditableText>(
      find.descendant(
        of: quicknoteContainer,
        matching: find.byType(EditableText),
      ),
    );
    final summaryEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(ValueKey('summary-${sermon.id}')),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      quicknoteEditable.style.fontSize,
      lessThan(summaryEditable.style.fontSize!),
    );
    await tester.enterText(quicknote, 'Schneller Gedanke');
    await tester.pump();

    await tester.tap(find.byKey(const Key('outline-add-content')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-content-notes')));
    await tester.pumpAndSettle();
    expect(find.text('Schneller Gedanke'), findsOneWidget);

    await tester.enterText(
      find.byKey(ValueKey('notes-summary-${sermon.id}')),
      'Gemeinsam bearbeitete Predigtübersicht',
    );
    await tester.pump();
    final notesQuicknote = find.descendant(
      of: quicknoteContainer,
      matching: find.byType(TextField),
    );
    await tester.enterText(notesQuicknote, 'In Notes geändert');
    await tester.pump();

    await tester.tap(find.byKey(const Key('workflow-stage-outline')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('outline-add-content')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-content-script')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('script-summary-${sermon.id}')),
      findsOneWidget,
    );
    expect(find.text('Gemeinsam bearbeitete Predigtübersicht'), findsOneWidget);
    expect(find.text('In Notes geändert'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Outline placement changes wait for Save while content autosaves',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final sermon = created.copyWith(
        title: 'Ausgangstitel',
        primaryBibleReference: const BibleReference(
          bookId: '1kgs',
          startChapter: 19,
          displayText: '1. Könige 19',
        ),
      );
      await repository.update(sermon);

      Future<Sermon> storedSermon() async => sermonFromRow(
        (await database.select(database.sermonRows).get()).single,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(sermonId: sermon.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(ValueKey('reference-${sermon.id}')),
        '20,1–2',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      var stored = await storedSermon();
      expect(stored.primaryBibleReference?.bookId, '1kgs');
      expect(stored.primaryBibleReference?.startChapter, 20);

      await tester.tap(find.byTooltip('Buch auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. Mose').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('title-${sermon.id}')),
        'Titel wird live gespeichert',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      stored = await storedSermon();
      expect(stored.title, 'Titel wird live gespeichert');
      expect(stored.primaryBibleReference?.bookId, '1kgs');
      expect(stored.primaryBibleReference?.startChapter, 20);

      await tester.ensureVisible(find.text('SPEICHERN'));
      await tester.tap(find.text('SPEICHERN'));
      await tester.pumpAndSettle();
      stored = await storedSermon();
      expect(stored.primaryBibleReference?.bookId, 'gen');
      expect(find.text('Titel wird live gespeichert'), findsAtLeastNWidgets(2));

      await tester.ensureVisible(find.text('VORTRAG'));
      await tester.tap(find.text('VORTRAG'));
      await tester.pump();
      await tester.enterText(
        find.byKey(ValueKey('title-${sermon.id}')),
        'Auch dieser Titel wird live gespeichert',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      stored = await storedSermon();
      expect(stored.title, 'Auch dieser Titel wird live gespeichert');
      expect(stored.contentKind, ContentKind.sermon);
      expect(stored.primaryBibleReference?.bookId, 'gen');

      await tester.ensureVisible(find.text('SPEICHERN'));
      await tester.tap(find.text('SPEICHERN'));
      await tester.pumpAndSettle();
      stored = await storedSermon();
      expect(stored.contentKind, ContentKind.talk);
      expect(stored.primaryBibleReference?.bookId, 'gen');
      expect(stored.primaryBibleReference?.hasCompleteRange, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('search is debounced and ranks title hits before body hits', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final now = DateTime.now().toUtc();
    final titleCreated = await repository.create();
    final titleHit = titleCreated.copyWith(
      title: 'Gnade im Alltag',
      contentKind: ContentKind.shortTopic,
    );
    await repository.update(titleHit);
    final bodyCreated = await repository.create();
    final bodyHit = bodyCreated.copyWith(
      title: 'Der verlorene Sohn',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'grace-body',
            text: 'Gnade trägt uns und Gnade verändert unser Leben.',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(bodyHit);
    final unrelated = await repository.create();
    await repository.update(
      unrelated.copyWith(
        title: 'Gebet und Geduld',
        contentKind: ContentKind.shortTopic,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SermonWorkspaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchField = find.byKey(const Key('library-search-field'));
    await tester.enterText(searchField, 'Gnade');
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('search-results-list')), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));

    final titleResult = find.byKey(Key('search-result-${titleHit.id}'));
    final bodyResult = find.byKey(Key('search-result-${bodyHit.id}'));
    expect(titleResult, findsOneWidget);
    expect(bodyResult, findsOneWidget);
    expect(
      tester.getTopLeft(titleResult).dy,
      lessThan(tester.getTopLeft(bodyResult).dy),
    );
    expect(find.text('SCRIPT'), findsOneWidget);
    expect(find.text('Gebet und Geduld'), findsNothing);

    await tester.tap(bodyResult);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('title-${bodyHit.id}')), findsOneWidget);
    expect(find.byKey(const Key('search-results-list')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('reference and editable title stay in sync across all views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final sermon = created.copyWith(
      title: 'Ursprünglicher Titel',
      document: created.document.copyWith(
        modules: const [
          SermonModule(
            id: 'notes',
            kind: SermonModuleKind.notes,
            title: 'Notizen',
            sortOrder: 0,
          ),
          SermonModule(
            id: 'script',
            kind: SermonModuleKind.script,
            title: 'Skript',
            sortOrder: 1,
          ),
        ],
      ),
      primaryBibleReference: const BibleReference(
        bookId: '1kgs',
        startChapter: 19,
        startVerse: 1,
        endChapter: 19,
        endVerse: 18,
        displayText: '1. Könige 19,1-18',
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

    final scriptTitle = find.byKey(ValueKey('script-title-${sermon.id}'));
    await tester.enterText(scriptTitle, 'Titel aus Script');
    await tester.pump();

    await tester.tap(find.byKey(const Key('workflow-stage-outline')));
    await tester.pumpAndSettle();
    final outlineTitle = find.byKey(ValueKey('title-${sermon.id}'));
    expect(outlineTitle, findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: outlineTitle,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Titel aus Script',
    );
    await tester.enterText(outlineTitle, 'Titel aus Outline');
    await tester.pump();

    await tester.tap(find.byTooltip('Notizen'));
    await tester.pumpAndSettle();
    final notesTitle = find.byKey(ValueKey('notes-title-${sermon.id}'));
    expect(notesTitle, findsOneWidget);
    expect(find.text('1. Könige'), findsAtLeastNWidgets(1));
    expect(find.text('19,1-18'), findsOneWidget);
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: notesTitle,
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Titel aus Outline',
    );
    await tester.enterText(notesTitle, 'Titel aus Notes');
    await tester.pump();

    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await tester.pumpAndSettle();
    await _tapPaneStage(tester, 'script', last: true);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('module-split-notes-script')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(ValueKey('script-title-${sermon.id}')),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      'Titel aus Notes',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('start stays empty and a new series has no automatic sermon', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    await repository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SermonWorkspaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Neue Predigt anlegen'), findsOneWidget);
    expect(find.text('Neue Predigt'), findsOneWidget);
    expect(find.byKey(const Key('start-screen-background')), findsOneWidget);
    expect(find.byKey(const Key('entry-column-shell')), findsNothing);
    expect(find.text('Unbenannte Predigt'), findsNothing);
    expect(find.text('Import'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(find.text('In Notes'), findsOneWidget);
    expect(find.text('In Script'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Datensicherung'));
    await tester.pumpAndSettle();
    expect(find.text('Sicherung erstellen'), findsOneWidget);
    expect(find.text('Wiederherstellen'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Neue Reihe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Testreihe');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(find.text('Testreihe'), findsWidgets);
    expect(find.text('Erste Predigt anlegen'), findsNWidgets(2));
    expect(await database.select(database.sermonRows).get(), hasLength(1));
    expect(
      (await database.select(database.sermonSeriesRows).get())
          .single
          .backgroundImageId,
      isIn(_testSeriesBackgroundIds),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'navigation keeps categories fixed and splits books and series scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final now = DateTime.now().toUtc();

      for (final book in BibleBookCatalog.all.take(15)) {
        final created = await repository.create();
        await repository.update(
          created.copyWith(
            title: 'Predigt zu ${book.label}',
            primaryBibleReference: BibleReference(
              bookId: book.id,
              startChapter: 1,
              displayText: '${book.label} 1',
            ),
          ),
        );
      }
      for (var index = 1; index <= 12; index++) {
        await database
            .into(database.sermonSeriesRows)
            .insert(
              SermonSeriesRowsCompanion.insert(
                id: 'scroll-series-$index',
                title: 'Reihe $index',
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const SermonWorkspaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigationArea = find.byKey(
        const Key('navigation-scroll-area'),
      );
      final seriesShell = find.byKey(const Key('series-scroll-shell'));
      final booksScroll = find.byKey(const Key('books-scroll-region'));
      final seriesScroll = find.byKey(const Key('series-scroll-region'));
      expect(navigationArea, findsOneWidget);
      expect(booksScroll, findsOneWidget);
      expect(seriesScroll, findsOneWidget);
      expect(
        tester.getSize(seriesShell).height,
        lessThanOrEqualTo(tester.getSize(navigationArea).height / 3 + 0.1),
      );
      expect(
        find.descendant(of: booksScroll, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: seriesScroll, matching: find.byType(Scrollable)),
        findsOneWidget,
      );
      expect(find.text('Kurzthemen').hitTestable(), findsOneWidget);
      expect(find.text('Einleitungen').hitTestable(), findsOneWidget);
      expect(find.text('Vorträge').hitTestable(), findsOneWidget);

      final fixedTop = tester
          .getTopLeft(find.byKey(const Key('fixed-navigation-categories')))
          .dy;
      await tester.drag(booksScroll, const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('fixed-navigation-categories')))
            .dy,
        fixedTop,
      );
      await tester.drag(seriesScroll, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(
        tester
            .getTopLeft(find.byKey(const Key('fixed-navigation-categories')))
            .dy,
        fixedTop,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'navigation keeps series directly below books when content fits',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final sermon = await repository.create();
      await repository.update(
        sermon.copyWith(
          title: 'Kompakte Navigation',
          primaryBibleReference: const BibleReference(
            bookId: 'gen',
            startChapter: 1,
            displayText: '1. Mose 1',
          ),
        ),
      );
      final now = DateTime.now().toUtc();
      await database
          .into(database.sermonSeriesRows)
          .insert(
            SermonSeriesRowsCompanion.insert(
              id: 'compact-series',
              title: 'Kompakte Reihe',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const SermonWorkspaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final booksShell = find.byKey(const Key('books-scroll-shell'));
      final booksSeriesDivider = find.byKey(
        const Key('books-series-divider'),
      );
      final seriesShell = find.byKey(const Key('series-scroll-shell'));
      final seriesCategoriesDivider = find.byKey(
        const Key('series-categories-divider'),
      );

      expect(tester.getSize(booksShell).height, 56);
      expect(
        tester.getTopLeft(booksSeriesDivider).dy,
        tester.getBottomLeft(booksShell).dy,
      );
      expect(
        tester.getTopLeft(seriesShell).dy,
        tester.getBottomLeft(booksSeriesDivider).dy,
      );
      expect(
        tester.getSize(booksSeriesDivider).height,
        tester.getSize(seriesCategoriesDivider).height,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'navigation sorts sermon series alphabetically with German characters',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.now().toUtc();
      for (final (index, title) in <String>[
        'Zukunft',
        'Älteste',
        'abend',
      ].indexed) {
        await database
            .into(database.sermonSeriesRows)
            .insert(
              SermonSeriesRowsCompanion.insert(
                id: 'alphabetical-series-$index',
                title: title,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const SermonWorkspaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final abendTop = tester
          .getTopLeft(find.byKey(const ValueKey('series-nav-abend')))
          .dy;
      final aeltesteTop = tester
          .getTopLeft(find.byKey(const ValueKey('series-nav-Älteste')))
          .dy;
      final zukunftTop = tester
          .getTopLeft(find.byKey(const ValueKey('series-nav-Zukunft')))
          .dy;
      expect(abendTop, lessThan(aeltesteTop));
      expect(aeltesteTop, lessThan(zukunftTop));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'quick new sermon requires placement and adopts its series background on Save',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final now = DateTime.now().toUtc();
      await database
          .into(database.sermonSeriesRows)
          .insert(
            SermonSeriesRowsCompanion.insert(
              id: 'series-background-test',
              title: 'Testreihe',
              backgroundImageId: const Value('generic4'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const SermonWorkspaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick-new-sermon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('outline-notebook-card')), findsOneWidget);
      expect(find.byKey(const Key('entry-column-shell')), findsNothing);
      expect(_outlineAssetName(tester), endsWith('generic1.jpg'));

      await tester.tap(find.text('SPEICHERN'));
      await tester.pump();
      expect(
        find.textContaining('Bitte wähle bei einer Auslegungspredigt'),
        findsOneWidget,
      );

      await tester.tap(find.text('VORTRAGSREIHE'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Vortragsreihe auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testreihe').last);
      await tester.pumpAndSettle();
      expect(_outlineAssetName(tester), endsWith('generic1.jpg'));

      await tester.tap(find.text('SPEICHERN'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_outlineAssetName(tester), endsWith('generic4.jpg'));
      expect(find.byKey(const Key('entry-column-shell')), findsOneWidget);
      final sermons = await database.select(database.sermonRows).get();
      expect(sermons.single.seriesId, 'Testreihe');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'series sermons can additionally belong to a Bible book',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final now = DateTime.now().toUtc();
      await database
          .into(database.sermonSeriesRows)
          .insert(
            SermonSeriesRowsCompanion.insert(
              id: 'series-with-reference',
              title: 'Sein oder Nichtsein',
              backgroundImageId: const Value('generic4'),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final created = await repository.create();
      final sermon = created.copyWith(
        title: 'Sein, oder nicht Sein – das ist hier die Frage!',
        seriesId: 'Sein oder Nichtsein',
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
            home: SermonWorkspaceScreen(sermonId: sermon.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MEHRERE'), findsOneWidget);
      expect(_outlineAssetName(tester), endsWith('generic4.jpg'));

      await tester.tap(find.byTooltip('Buch auswählen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Johannes').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Johannes').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('reference-${sermon.id}')),
        '15,4–11',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      var stored = sermonFromRow(
        (await database.select(database.sermonRows).get()).single,
      );
      expect(stored.seriesId, 'Sein oder Nichtsein');
      expect(stored.primaryBibleReference, isNull);
      expect(_outlineAssetName(tester), endsWith('generic4.jpg'));

      await tester.ensureVisible(find.text('SPEICHERN'));
      await tester.tap(find.text('SPEICHERN'));
      await tester.pumpAndSettle();
      stored = sermonFromRow(
        (await database.select(database.sermonRows).get()).single,
      );
      expect(stored.seriesId, 'Sein oder Nichtsein');
      expect(stored.primaryBibleReference?.bookId, 'john');
      expect(stored.primaryBibleReference?.startChapter, 15);
      expect(stored.primaryBibleReference?.startVerse, 4);
      expect(stored.primaryBibleReference?.endChapter, 15);
      expect(stored.primaryBibleReference?.endVerse, 11);
      expect(stored.primaryBibleReference?.displayText, 'Johannes 15,4-11');
      expect(
        _outlineAssetName(tester),
        endsWith('43_Johannes/johannes.jpg'),
      );

      await tester.tap(find.text('Johannes').first);
      await tester.pumpAndSettle();
      final entry = find.byKey(Key('sermon-${sermon.id}'));
      expect(entry, findsOneWidget);
      expect(
        find.descendant(
          of: entry,
          matching: find.text('Sein oder Nichtsein'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('book navigation includes talks and sorts them by passage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final later = await repository.create();
    await repository.update(
      later.copyWith(
        title: 'Spätere Auslegung',
        primaryBibleReference: const BibleReference(
          bookId: 'gen',
          startChapter: 1,
          startVerse: 10,
          endChapter: 1,
          endVerse: 11,
          displayText: '1. Mose 1,10-11',
        ),
      ),
    );
    final talk = await repository.create();
    await repository.update(
      talk.copyWith(
        title: 'Früher Vortrag',
        contentKind: ContentKind.talk,
        primaryBibleReference: const BibleReference(
          bookId: 'gen',
          startChapter: 1,
          startVerse: 2,
          endChapter: 1,
          endVerse: 3,
          displayText: '1. Mose 1,2-3',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: const SermonWorkspaceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('1. Mose').first);
    await tester.pumpAndSettle();

    final talkEntry = find.byKey(Key('sermon-${talk.id}'));
    final laterEntry = find.byKey(Key('sermon-${later.id}'));
    expect(talkEntry, findsOneWidget);
    expect(laterEntry, findsOneWidget);
    expect(
      tester.getTopLeft(talkEntry).dy,
      lessThan(tester.getTopLeft(laterEntry).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'saving a moved series sermon keeps its entered Bible passage',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final now = DateTime.now().toUtc();
      for (final title in ['Alte Reihe', 'Neue Reihe']) {
        await database
            .into(database.sermonSeriesRows)
            .insert(
              SermonSeriesRowsCompanion.insert(
                id: title,
                title: title,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      final moved = await repository.create();
      await repository.update(
        moved.copyWith(title: 'Importierte Predigt', seriesId: 'Alte Reihe'),
      );
      final sibling = await repository.create();
      await repository.update(
        sibling.copyWith(title: 'Andere Predigt', seriesId: 'Alte Reihe'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: SermonWorkspaceScreen(sermonId: moved.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Vortragsreihe auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Reihe').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Buch auswählen'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('1. Thessalonicher').last);
      await tester.tap(find.text('1. Thessalonicher').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('reference-${moved.id}')),
        '2:1-12',
      );
      await tester.ensureVisible(find.text('SPEICHERN'));
      await tester.tap(find.text('SPEICHERN'));
      await tester.pumpAndSettle();

      final stored = (await database.select(database.sermonRows).get())
          .map(sermonFromRow)
          .toList(growable: false);
      final storedMoved = stored.singleWhere((item) => item.id == moved.id);
      final storedSibling = stored.singleWhere((item) => item.id == sibling.id);
      expect(storedMoved.seriesId, 'Neue Reihe');
      expect(storedMoved.primaryBibleReference?.bookId, '1thess');
      expect(storedMoved.primaryBibleReference?.startChapter, 2);
      expect(storedMoved.primaryBibleReference?.startVerse, 1);
      expect(storedMoved.primaryBibleReference?.endChapter, 2);
      expect(storedMoved.primaryBibleReference?.endVerse, 12);
      expect(
        storedMoved.primaryBibleReference?.displayText,
        '1. Thessalonicher 2,1-12',
      );
      expect(storedSibling.seriesId, 'Alte Reihe');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'series names can be renamed and positions control their order',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final now = DateTime.now().toUtc();
      await database
          .into(database.sermonSeriesRows)
          .insert(
            SermonSeriesRowsCompanion.insert(
              id: 'renameable-series',
              title: 'Alte Reihe',
              backgroundImageId: const Value('generic3'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      Future<Sermon> createSeriesSermon(
        String title,
        int? position,
      ) async {
        final created = await repository.create();
        final sermon = created.copyWith(
          title: title,
          seriesId: 'Alte Reihe',
          seriesPosition: position,
        );
        await repository.update(sermon);
        return sermon;
      }

      final third = await createSeriesSermon('Dritter Teil', 3);
      final first = await createSeriesSermon('Erster Teil', 1);
      final unnumbered = await createSeriesSermon('Ohne Nummer', null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            bootstrapProvider.overrideWith((ref) async {}),
          ],
          child: MaterialApp(
            theme: buildTheme(Brightness.light),
            home: const SermonWorkspaceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('series-nav-Alte Reihe')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byKey(Key('sermon-${first.id}'))).dy,
        lessThan(tester.getTopLeft(find.byKey(Key('sermon-${third.id}'))).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(Key('sermon-${third.id}'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(Key('sermon-${unnumbered.id}'))).dy,
        ),
      );

      await tester.tap(find.byKey(Key('sermon-${unnumbered.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(ValueKey('series-position-${unnumbered.id}')),
        '2',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      final storedUnnumbered = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(unnumbered.id))).getSingle(),
      );
      expect(storedUnnumbered.seriesPosition, 2);
      expect(
        tester.getTopLeft(find.byKey(Key('sermon-${unnumbered.id}'))).dy,
        lessThan(tester.getTopLeft(find.byKey(Key('sermon-${third.id}'))).dy),
      );

      final seriesNav = find.byKey(
        const ValueKey('series-nav-Alte Reihe'),
      );
      await tester.tap(seriesNav);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(seriesNav);
      await tester.pumpAndSettle();
      expect(find.text('Vortragsreihe umbenennen'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('rename-series-field')),
        'Neue Reihe',
      );
      await tester.tap(find.text('Umbenennen'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('series-nav-Neue Reihe')),
        findsOneWidget,
      );
      expect(
        (await database.select(database.sermonSeriesRows).get()).single.title,
        'Neue Reihe',
      );
      final storedSermons = await database.select(database.sermonRows).get();
      expect(
        storedSermons.map((row) => row.seriesId).toSet(),
        {'Neue Reihe'},
      );

      await tester.tap(
        find.byKey(const ValueKey('entry-series-title-Neue Reihe')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vortragsreihe umbenennen'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('rename-series-field')),
        'Finale Reihe',
      );
      await tester.tap(find.text('Umbenennen'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('entry-series-title-Finale Reihe')),
        findsOneWidget,
      );
      expect(
        (await database.select(database.sermonSeriesRows).get()).single.title,
        'Finale Reihe',
      );
      expect(
        (await database
                .select(
                  database.sermonRows,
                )
                .get())
            .map((row) => row.seriesId)
            .toSet(),
        {'Finale Reihe'},
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('toolbar duplicate creates a visibly grouped version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    await repository.update(
      created.copyWith(
        title: 'Versionstest',
        contentKind: ContentKind.shortTopic,
      ),
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

    await tester.tap(find.byTooltip('Duplizieren').last);
    await tester.pumpAndSettle();

    final rows = await database.select(database.sermonRows).get();
    expect(rows, hasLength(2));
    final version = rows.singleWhere((row) => row.id != created.id);
    expect(version.versionRootId, created.id);
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('dragging entry pills attaches and detaches sermon versions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final target = await repository.create();
    await repository.update(
      target.copyWith(
        title: 'Zielpredigt',
        contentKind: ContentKind.shortTopic,
      ),
    );
    final dragged = await repository.create();
    await repository.update(
      dragged.copyWith(
        title: 'Gezogene Predigt',
        contentKind: ContentKind.shortTopic,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(sermonId: target.id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    var draggedFinder = find.byKey(Key('sermon-drag-${dragged.id}'));
    await tester.drag(
      draggedFinder,
      tester.getCenter(find.byKey(Key('sermon-drop-${target.id}'))) -
          tester.getCenter(draggedFinder),
    );
    await tester.pumpAndSettle();

    var draggedRow = await (database.select(
      database.sermonRows,
    )..where((row) => row.id.equals(dragged.id))).getSingle();
    expect(draggedRow.versionRootId, target.id);
    expect(find.text('VERSION 2'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);

    final detachZone = tester.getRect(
      find.byKey(const Key('entry-version-detach-zone')),
    );
    draggedFinder = find.byKey(Key('sermon-drag-${dragged.id}'));
    await tester.drag(
      draggedFinder,
      Offset(detachZone.center.dx, detachZone.bottom - 20) -
          tester.getCenter(draggedFinder),
    );
    await tester.pumpAndSettle();

    draggedRow = await (database.select(
      database.sermonRows,
    )..where((row) => row.id.equals(dragged.id))).getSingle();
    expect(draggedRow.versionRootId, isNull);
    expect(find.text('VERSION 2'), findsNothing);
    expect(find.text('×2'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

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
    expect(find.text('Ersten Eintrag anlegen'), findsNWidgets(2));

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
      (widget) =>
          widget is TextField &&
          widget.key != const Key('library-search-field') &&
          widget.focusNode != null,
    );
    expect(firstParagraph, findsOneWidget);
    await tester.tap(firstParagraph);
    tester.widget<TextField>(firstParagraph).controller!.selection =
        const TextSelection.collapsed(offset: 6);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 800));

    final paragraphs = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.key != const Key('library-search-field') &&
          widget.focusNode != null,
    );
    expect(paragraphs, findsNWidgets(2));
    final nextField = tester.widget<TextField>(paragraphs.last);
    expect(nextField.focusNode?.hasFocus, isTrue);
    expect(
      nextField.controller?.selection,
      const TextSelection.collapsed(offset: 0),
    );
    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<ParagraphBlock>().map(
        (block) => block.text,
      ),
      ['Erster', ' Absatz'],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Backspace at a paragraph start joins it with the previous paragraph',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Absätze verbinden',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'join-first',
              text: 'Wir schauen uns an, ',
              semanticRole: ParagraphRole.normal,
              marks: const [InlineMark(start: 0, end: 3, bold: true)],
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'join-second',
              text: 'wie das aussieht.',
              semanticRole: ParagraphRole.normal,
              marks: const [InlineMark(start: 0, end: 3, italic: true)],
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

      final second = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'wie das aussieht.',
      );
      await tester.tap(second);
      tester.widget<TextField>(second).controller!.selection =
          const TextSelection.collapsed(offset: 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 800));

      final saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      final paragraph = saved.document.blocks.single as ParagraphBlock;
      expect(paragraph.text, 'Wir schauen uns an, wie das aussieht.');
      expect(paragraph.marks, hasLength(2));
      expect(paragraph.marks.first.bold, isTrue);
      expect(paragraph.marks.last.italic, isTrue);
      expect(paragraph.marks.last.start, 'Wir schauen uns an, '.length);

      final mergedField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.controller?.text ==
                  'Wir schauen uns an, wie das aussieht.',
        ),
      );
      expect(mergedField.focusNode?.hasFocus, isTrue);
      expect(
        mergedField.controller?.selection,
        const TextSelection.collapsed(offset: 'Wir schauen uns an, '.length),
      );

      await _sendCommandKey(tester, LogicalKeyboardKey.keyZ);
      await tester.pump();
      expect(find.text('Wir schauen uns an, '), findsOneWidget);
      expect(find.text('wie das aussieht.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('an empty heading can be deleted without changing its type', (
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
      title: 'Leere Überschrift',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          HeadingBlock(
            id: 'empty-heading',
            level: 3,
            text: '',
            collapsed: false,
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

    final emptyHeading = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.hintText == 'Überschrift 3',
    );
    expect(emptyHeading, findsOneWidget);
    await tester.tap(emptyHeading);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 800));

    expect(emptyHeading, findsNothing);
    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Markdown syntax is converted when a block is submitted', (
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
      title: 'Markdown-Test',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'markdown-heading',
            text: '#Neue Überschrift',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'markdown-inline',
            text: '**Fett** und *kursiv* und ==markiert==',
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

    Finder richField(String text) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == text,
    );
    final headingField = richField('#Neue Überschrift');
    await tester.tap(headingField);
    final headingController = tester
        .widget<TextField>(headingField)
        .controller!;
    headingController.selection = TextSelection.collapsed(
      offset: headingController.text.length,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    final inlineField = richField(
      '**Fett** und *kursiv* und ==markiert==',
    );
    await tester.tap(inlineField);
    final inlineController = tester.widget<TextField>(inlineField).controller!;
    inlineController.selection = TextSelection.collapsed(
      offset: inlineController.text.length,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final heading = saved.document.blocks.whereType<HeadingBlock>().singleWhere(
      (block) => block.id == 'markdown-heading',
    );
    expect((heading.level, heading.text), (1, 'Neue Überschrift'));
    final formatted = saved.document.blocks
        .whereType<ParagraphBlock>()
        .singleWhere((block) => block.id == 'markdown-inline');
    expect(formatted.text, 'Fett und kursiv und markiert');
    expect(formatted.marks.any((mark) => mark.bold), isTrue);
    expect(formatted.marks.any((mark) => mark.italic), isTrue);
    expect(formatted.marks.any((mark) => mark.highlighted), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Word paste creates script blocks and is one undo step', (
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
      title: 'Word-Paste Script',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'paste-script',
            text: 'Einfügepunkt',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);
    const clipboard = _FakeRichClipboardSource(
      RichClipboardContent(
        html:
            '<h1>Hauptteil</h1><p>Erster <b>Absatz</b></p><p></p> '
            '<h3>Unterpunkt</h3><p><i>Letzter Absatz</i></p>',
      ),
    );

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
            clipboardSource: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final insertionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Einfügepunkt',
    );
    await tester.tap(insertionField);
    await tester.sendKeyDownEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(_primaryModifierKey);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
    await tester.pump(const Duration(milliseconds: 800));

    var saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(5));
    expect(saved.document.blocks[0], isA<HeadingBlock>());
    expect((saved.document.blocks[0] as HeadingBlock).level, 1);
    expect(saved.document.blocks[1], isA<ParagraphBlock>());
    expect(
      (saved.document.blocks[1] as ParagraphBlock).marks.single.bold,
      isTrue,
    );
    expect(saved.document.blocks[2].plainText, isEmpty);
    expect((saved.document.blocks[3] as HeadingBlock).level, 3);
    expect(
      (saved.document.blocks[4] as ParagraphBlock).marks.single.italic,
      isTrue,
    );

    await _sendCommandKey(tester, LogicalKeyboardKey.keyZ);
    await tester.pump(const Duration(milliseconds: 800));
    saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(1));
    expect(saved.document.blocks.single.plainText, 'Einfügepunkt');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Word paste maps body paragraphs to notes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      title: 'Word-Paste Notes',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          NoteBlock(
            id: 'paste-note',
            text: 'Einfügepunkt',
            visibility: NoteVisibility.editorOnly,
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
            initialView: WorkspaceView.notes,
            clipboardSource: const _FakeRichClipboardSource(
              RichClipboardContent(
                html: '<h2>Gliederung</h2><p>Punkt eins</p><p>Punkt zwei</p>',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final insertionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Einfügepunkt',
    );
    await tester.tap(insertionField);
    await tester.sendKeyDownEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(_primaryModifierKey);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(3));
    expect((saved.document.blocks.first as HeadingBlock).level, 2);
    expect(saved.document.blocks.skip(1), everyElement(isA<NoteBlock>()));
    expect(saved.document.blocks[1].plainText, 'Punkt eins');
    expect(saved.document.blocks[2].plainText, 'Punkt zwei');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Command-Shift-V pastes literal text into the current block', (
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
      title: 'Unformatiert einfügen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'plain-paste',
            text: 'Ersetzen',
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
            clipboardSource: const _FakeRichClipboardSource(
              RichClipboardContent(
                html: '<h1>Wird nicht zur Überschrift</h1><p><b>Fett</b></p>',
                plainText: '# Wird nicht zur Überschrift\n**Nicht fett**',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Ersetzen',
    );
    await tester.tap(field);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(
      tester,
      LogicalKeyboardKey.keyV,
      shift: true,
    );
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(1));
    final paragraph = saved.document.blocks.single as ParagraphBlock;
    expect(paragraph.text, '# Wird nicht zur Überschrift\n**Nicht fett**');
    expect(paragraph.marks, isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Backspace deletes a selection across multiple paragraphs', (
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
      title: 'Mehrfach löschen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final entry in const [
            ('delete-first', 'Erster Absatz'),
            ('delete-second', 'Zweiter Absatz'),
          ])
            ParagraphBlock(
              id: entry.$1,
              text: entry.$2,
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

    final first = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Erster Absatz',
    );
    await tester.tap(first);
    final firstController = tester.widget<TextField>(first).controller!;
    await tester.sendKeyDownEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(firstController.text, isEmpty);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final paragraphs = saved.document.blocks.whereType<ParagraphBlock>();
    expect(paragraphs, hasLength(1));
    expect(paragraphs.single.text, isEmpty);

    await _sendCommandKey(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(find.text('Erster Absatz'), findsOneWidget);
    expect(find.text('Zweiter Absatz'), findsOneWidget);

    await _sendCommandKey(
      tester,
      LogicalKeyboardKey.keyZ,
      shift: true,
    );
    await tester.pump();
    expect(find.text('Erster Absatz'), findsNothing);
    expect(find.text('Zweiter Absatz'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Command-C copies a selection across multiple paragraphs', (
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
      title: 'Mehrfach kopieren',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final entry in const [
            ('copy-first', 'Erster Absatz'),
            ('copy-second', 'Zweiter Absatz'),
          ])
            ParagraphBlock(
              id: entry.$1,
              text: entry.$2,
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      ),
    );
    await repository.update(sermon);
    final clipboard = _MemoryRichClipboard();
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
            clipboardSink: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Erster Absatz',
    );
    await tester.tap(first);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyC);
    await tester.pump();

    expect(clipboard.content?.plainText, 'Erster Absatz\nZweiter Absatz');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Command-X cuts all selected blocks and is undoable', (
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
      title: 'Mehrfach ausschneiden',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          HeadingBlock(
            id: 'cut-heading',
            level: 2,
            text: 'Überschrift',
            collapsed: false,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'cut-paragraph',
            text: 'Absatz',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);
    final clipboard = _MemoryRichClipboard();
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
            clipboardSink: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heading = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Überschrift',
    );
    await tester.tap(heading);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyX);
    await tester.pump(const Duration(milliseconds: 800));

    var saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, isEmpty);
    expect(clipboard.content?.plainText, 'Überschrift\nAbsatz');
    expect(clipboard.content?.html, contains('<h2>Überschrift</h2>'));

    await _sendCommandKey(tester, LogicalKeyboardKey.keyZ);
    await tester.pump(const Duration(milliseconds: 800));
    saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('a single pasted paragraph stays inside the current paragraph', (
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
      title: 'Inline einfügen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'inline-target',
            text: 'Vorher Nachher',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);
    final clipboard = _MemoryRichClipboard()
      ..content = const RichClipboardContent(
        plainText: 'Eingefügt',
        html: '<p><strong>Eingefügt</strong></p>',
      );
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
            clipboardSource: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Vorher Nachher',
    );
    await tester.tap(field);
    tester.widget<TextField>(field).controller!.selection =
        const TextSelection.collapsed(offset: 7);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final paragraph = saved.document.blocks.single as ParagraphBlock;
    expect(paragraph.text, 'Vorher EingefügtNachher');
    expect(
      paragraph.marks.single,
      isA<InlineMark>()
          .having((mark) => mark.start, 'start', 7)
          .having((mark) => mark.end, 'end', 16)
          .having((mark) => mark.bold, 'bold', isTrue),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Sermonary rich copy and paste preserves block formats', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final now = DateTime.now().toUtc();
    final source = (await repository.create()).copyWith(
      title: 'Kopierquelle',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          HeadingBlock(
            id: 'rich-heading',
            level: 2,
            text: 'Gliederung',
            collapsed: false,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'rich-paragraph',
            text: 'Fetter Absatz',
            semanticRole: ParagraphRole.normal,
            marks: const [InlineMark(start: 0, end: 6, bold: true)],
            createdAt: now,
            updatedAt: now,
          ),
          QuoteBlock(
            id: 'rich-quote',
            text: 'Markiertes Zitat',
            author: '',
            source: '',
            marks: const [
              InlineMark(start: 0, end: 10, highlighted: true),
            ],
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(source);
    final target = (await repository.create()).copyWith(
      title: 'Kopierziel',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'rich-target',
            text: '',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(target);
    final clipboard = _MemoryRichClipboard();

    Widget app(String sermonId) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        bootstrapProvider.overrideWith((ref) async {}),
      ],
      child: MaterialApp(
        theme: buildTheme(Brightness.light),
        home: SermonWorkspaceScreen(
          key: ValueKey(sermonId),
          sermonId: sermonId,
          initialView: WorkspaceView.script,
          clipboardSource: clipboard,
          clipboardSink: clipboard,
        ),
      ),
    );

    await tester.pumpWidget(app(source.id));
    await tester.pumpAndSettle();
    final sourceHeading = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Gliederung',
    );
    await tester.tap(sourceHeading);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyC);
    await tester.pump();

    await tester.pumpWidget(app(target.id));
    await tester.pumpAndSettle();
    final emptyTarget = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.key != const Key('library-search-field') &&
          widget.focusNode != null &&
          widget.controller?.text.isEmpty == true,
    );
    await tester.tap(emptyTarget);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(target.id))).getSingle(),
    );
    expect(saved.document.blocks.map((block) => block.runtimeType), [
      HeadingBlock,
      ParagraphBlock,
      QuoteBlock,
    ]);
    expect((saved.document.blocks[0] as HeadingBlock).level, 2);
    expect(
      (saved.document.blocks[1] as ParagraphBlock).marks.single.bold,
      isTrue,
    );
    expect(
      (saved.document.blocks[2] as QuoteBlock).marks.single.highlighted,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('paste replaces a selection across multiple paragraphs', (
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
      title: 'Mehrfach ersetzen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final entry in const [
            ('replace-first', 'Erster Absatz'),
            ('replace-second', 'Zweiter Absatz'),
          ])
            ParagraphBlock(
              id: entry.$1,
              text: entry.$2,
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
        ],
      ),
    );
    await repository.update(sermon);
    final clipboard = _MemoryRichClipboard()
      ..content = const RichClipboardContent(
        plainText: 'Ersatz',
        html: '<p>Ersatz</p>',
      );
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
            clipboardSource: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Erster Absatz',
    );
    await tester.tap(first);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(1));
    expect(saved.document.blocks.single.plainText, 'Ersatz');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'a note pasted into the script keeps script block controls in split view',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Zielmodus beim Einfügen',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            NoteBlock(
              id: 'source-note',
              text: 'Aus den Notes',
              visibility: NoteVisibility.editorOnly,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'script-paste-target',
              text: 'Script: ',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      await repository.update(sermon);
      final clipboard = _MemoryRichClipboard();
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
              initialView: WorkspaceView.notes,
              clipboardSource: clipboard,
              clipboardSink: clipboard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final note = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Aus den Notes',
      );
      await tester.tap(note);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyC);
      await tester.tap(find.byTooltip('Skript'));
      await tester.pumpAndSettle();

      final target = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Script: ',
      );
      await tester.tap(target);
      tester.widget<TextField>(target).controller!.selection =
          const TextSelection.collapsed(offset: 8);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.byTooltip('Blocktyp'));
      await tester.pumpAndSettle();
      expect(find.text('Absatz'), findsWidgets);
      expect(find.text('Zitat'), findsOneWidget);
      expect(find.text('Stichpunkt'), findsNothing);
      await tester.tap(find.text('Zitat'));
      await tester.pump(const Duration(milliseconds: 800));

      final saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      final pasted = saved.document.blocks.singleWhere(
        (block) => block.id == 'script-paste-target',
      );
      expect(pasted, isA<QuoteBlock>());
      expect(pasted.plainText, 'Script: Aus den Notes');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('editor fields keep the caret above the bottom fade', (
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
      title: 'Früher scrollen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'scroll-padding-paragraph',
            text: 'Langer Schreibtext',
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

    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Langer Schreibtext',
      ),
    );
    expect(field.scrollPadding.bottom, greaterThanOrEqualTo(160));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('partial mixed-block deletion preserves both block types', (
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
      title: 'Gemischte Auswahl',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          HeadingBlock(
            id: 'mixed-heading',
            level: 2,
            text: 'Titel Ende',
            collapsed: false,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'mixed-paragraph',
            text: 'Anfang Absatz',
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

    final heading = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Titel Ende',
    );
    final paragraph = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Anfang Absatz',
    );
    final drag = await tester.startGesture(
      _caretGlobalPosition(tester, paragraph, 7),
    );
    await drag.moveTo(_caretGlobalPosition(tester, heading, 5));
    await drag.up();
    final headingSelection = tester
        .widget<TextField>(heading)
        .controller!
        .selection;
    final paragraphSelection = tester
        .widget<TextField>(paragraph)
        .controller!
        .selection;
    expect(
      (headingSelection.start, headingSelection.end),
      (5, 'Titel Ende'.length),
    );
    expect((paragraphSelection.start, paragraphSelection.end), (0, 7));
    tester.widget<TextField>(paragraph).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(saved.document.blocks, hasLength(2));
    expect(saved.document.blocks.first, isA<HeadingBlock>());
    expect(saved.document.blocks.first.plainText, 'Titel');
    expect(saved.document.blocks.last, isA<ParagraphBlock>());
    expect(saved.document.blocks.last.plainText, 'Absatz');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Bible quote blocks can be selected and copied', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      title: 'Bibelzitat kopieren',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          BibleQuoteBlock(
            id: 'copy-bible-quote',
            reference: const BibleReference(
              bookId: 'john',
              startChapter: 3,
              startVerse: 16,
              endChapter: 3,
              endVerse: 16,
              displayText: 'Johannes 3,16-16',
            ),
            translationId: 'elb85',
            translationLabel: 'ELB85',
            text: 'Denn so sehr hat Gott die Welt geliebt.',
            showVerseNumbers: false,
            copyrightNotice: 'Test',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
    await repository.update(sermon);
    final clipboard = _MemoryRichClipboard();
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
            clipboardSink: clipboard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final quote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text == 'Denn so sehr hat Gott die Welt geliebt.',
    );
    await tester.tap(quote);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyC);
    await tester.pump();

    expect(
      clipboard.content?.plainText,
      'Denn so sehr hat Gott die Welt geliebt.',
    );
    expect(clipboard.content?.html, contains('data-sermonary-bible="1"'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'structured paste focuses the last inserted block before suffix',
    (
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
        title: 'Cursor nach Einfügen',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'focus-paste-target',
              text: 'Vorher Nachher',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      );
      await repository.update(sermon);
      final clipboard = _MemoryRichClipboard()
        ..content = const RichClipboardContent(
          plainText: 'Titel\nText',
          html: '<h2>Titel</h2><p>Text</p>',
        );
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
              clipboardSource: clipboard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Vorher Nachher',
      );
      await tester.tap(target);
      tester.widget<TextField>(target).controller!.selection =
          const TextSelection.collapsed(offset: 7);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyV);
      await tester.pump(const Duration(milliseconds: 800));

      final inserted = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'Text',
      );
      expect(tester.widget<TextField>(inserted).focusNode?.hasFocus, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('editing clears stale multi-block selection highlights', (
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
      title: 'Auswahl bereinigen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final entry in const [
            ('selection-first', 'Erster Absatz'),
            ('selection-second', 'Zweiter Absatz'),
          ])
            ParagraphBlock(
              id: entry.$1,
              text: entry.$2,
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

    final first = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Erster Absatz',
    );
    await tester.tap(first);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
    await tester.enterText(first, 'Neu');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<ParagraphBlock>().map(
        (block) => block.text,
      ),
      ['Ne', 'Zweiter Absatz'],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('inline marks follow text inserted before them', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      title: 'Stabile Markierungen',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'stable-mark',
            text: 'Vor markiert Ende',
            semanticRole: ParagraphRole.normal,
            marks: const [
              InlineMark(start: 4, end: 12, highlighted: true),
            ],
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

    final field = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Vor markiert Ende',
    );
    await tester.tap(field);
    tester.widget<TextField>(field).controller!.selection =
        const TextSelection.collapsed(offset: 0);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Neu Vor markiert Ende',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final paragraph = saved.document.blocks.single as ParagraphBlock;
    expect(paragraph.text, 'Neu Vor markiert Ende');
    expect(
      (paragraph.marks.single.start, paragraph.marks.single.end),
      (8, 16),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Notes headings and Quicknotes support isolated multi-block selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Notes-Auswahl',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            for (final entry in const [
              ('quick-one', 'Erste Quicknote'),
              ('quick-two', 'Zweite Quicknote'),
            ])
              NoteBlock(
                id: entry.$1,
                text: entry.$2,
                visibility: NoteVisibility.editorOnly,
                isQuickNote: true,
                createdAt: now,
                updatedAt: now,
              ),
            HeadingBlock(
              id: 'notes-heading',
              level: 2,
              text: 'Notes-Überschrift',
              collapsed: false,
              createdAt: now,
              updatedAt: now,
            ),
            for (final entry in const [
              ('note-one', 'Erste normale Note'),
              ('note-two', 'Zweite normale Note'),
            ])
              NoteBlock(
                id: entry.$1,
                text: entry.$2,
                visibility: NoteVisibility.editorOnly,
                createdAt: now,
                updatedAt: now,
              ),
            ParagraphBlock(
              id: 'script-kept',
              text: 'Skript bleibt erhalten',
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
              initialView: WorkspaceView.notes,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder richField(String text) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == text,
      );

      await tester.tap(richField('Erste Quicknote'));
      await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyM);
      await tester.pump(const Duration(milliseconds: 800));

      var saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      final quickNotes = saved.document.blocks.whereType<NoteBlock>().where(
        (note) => note.isQuickNote,
      );
      expect(
        quickNotes.every(
          (note) => note.marks.any((mark) => mark.highlighted),
        ),
        isTrue,
      );
      expect(
        saved.document.blocks
            .whereType<NoteBlock>()
            .where((note) => !note.isQuickNote)
            .every((note) => note.marks.isEmpty),
        isTrue,
      );

      await tester.tap(richField('Erste normale Note'));
      await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyB);
      await tester.pump(const Duration(milliseconds: 800));
      saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      expect(
        saved.document.blocks
            .whereType<NoteBlock>()
            .where((note) => !note.isQuickNote)
            .every((note) => note.marks.any((mark) => mark.bold)),
        isTrue,
      );

      await tester.tap(richField('Erste normale Note'));
      await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 800));

      saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      expect(saved.document.blocks.whereType<HeadingBlock>(), isEmpty);
      expect(
        saved.document.blocks.whereType<NoteBlock>().where(
          (note) => !note.isQuickNote,
        ),
        isEmpty,
      );
      expect(
        saved.document.blocks.whereType<ParagraphBlock>().single.text,
        'Skript bleibt erhalten',
      );

      await tester.tap(richField('Erste Quicknote'));
      await _sendCommandKey(tester, LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump(const Duration(milliseconds: 800));

      saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      expect(saved.document.blocks.whereType<NoteBlock>(), isEmpty);
      expect(saved.document.blocks.whereType<ParagraphBlock>(), hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Command-Z and Command-Shift-Z undo and redo editor changes', (
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
      title: 'Undo-Test',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'undo-paragraph',
            text: 'Ursprünglich',
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

    Finder richField(String text) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == text,
    );
    await tester.enterText(richField('Ursprünglich'), 'Verändert');
    await tester.pump(const Duration(milliseconds: 800));

    await _sendCommandKey(tester, LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(richField('Ursprünglich'), findsOneWidget);

    await _sendCommandKey(
      tester,
      LogicalKeyboardKey.keyZ,
      shift: true,
    );
    await tester.pump();
    expect(richField('Verändert'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('h3 typography and content stay synchronized across views', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    const longHeading =
        'Hauptteil: Das schönste Kapitel, das niemand kennt und das dennoch '
        'für die ganze Predigt entscheidend ist';
    const longScriptText =
        'Dieser längere Scriptabsatz läuft in der geteilten Ansicht über '
        'zahlreiche Zeilen. Seine vollständige Höhe muss den Beginn des '
        'nächsten Abschnitts bestimmen, damit nachfolgende Überschriften '
        'niemals in den Text hineinrutschen. Deshalb enthält der Test genug '
        'Wörter für mehrere deutliche Zeilenumbrüche in der linken Spalte.';
    final sermon = created.copyWith(
      title: 'Überschriftentest',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final heading in const [
            ('heading-1', 1, longHeading),
            ('heading-2', 2, 'Unterüberschrift'),
            ('heading-3', 3, 'Zwischenüberschrift'),
          ])
            HeadingBlock(
              id: heading.$1,
              level: heading.$2,
              text: heading.$3,
              collapsed: false,
              createdAt: now,
              updatedAt: now,
            ),
          ParagraphBlock(
            id: 'paragraph',
            text: longScriptText,
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          ),
          NoteBlock(
            id: 'note',
            text: 'Notiztext',
            visibility: NoteVisibility.editorOnly,
            createdAt: now,
            updatedAt: now,
          ),
          HeadingBlock(
            id: 'heading-after-long-text',
            level: 3,
            text: 'Nachfolgende Zwischenüberschrift',
            collapsed: false,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'following-paragraph',
            text: 'Text des nächsten Abschnitts.',
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

    EditableText headingField(String value) => tester.widget<EditableText>(
      find.byWidgetPredicate(
        (widget) => widget is EditableText && widget.controller.text == value,
      ),
    );

    expect(headingField(longHeading).style.fontSize, 28.48);
    expect(headingField(longHeading).maxLines, isNull);
    expect(
      tester
          .getSize(
            find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.controller?.text == longHeading,
            ),
          )
          .height,
      greaterThan(55),
    );
    expect(headingField('Unterüberschrift').style.fontSize, 21.12);
    final h3 = headingField('Zwischenüberschrift');
    expect(h3.style.fontFamily, AppTypography.editor);
    expect(h3.style.fontSize, 18.08);
    expect(h3.style.fontWeight, FontWeight.w500);

    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await tester.pumpAndSettle();
    await _tapPaneStage(tester, 'notes', last: true);
    await tester.pumpAndSettle();
    expect(find.text('Absatz hinzufügen'), findsNothing);
    expect(find.text('—  Stichpunkt'), findsOneWidget);
    final longParagraph = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == longScriptText,
    );
    final followingHeading = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text == 'Nachfolgende Zwischenüberschrift',
    );
    // Linked contents share one heading row across both columns. Rendering a
    // copy in each editor would let differently sized body blocks drift apart.
    expect(followingHeading, findsOneWidget);
    expect(tester.getSize(longParagraph).height, greaterThan(100));
    final paragraphCenterX = tester.getCenter(longParagraph).dx;
    var headingInScript = followingHeading.first;
    for (var index = 1; index < followingHeading.evaluate().length; index++) {
      final candidate = followingHeading.at(index);
      if ((tester.getCenter(candidate).dx - paragraphCenterX).abs() <
          (tester.getCenter(headingInScript).dx - paragraphCenterX).abs()) {
        headingInScript = candidate;
      }
    }
    expect(
      tester.getTopLeft(headingInScript).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(longParagraph).dy),
    );
    final notesH3 = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text == 'Zwischenüberschrift',
    );
    expect(notesH3, findsOneWidget);
    await tester.enterText(notesH3, 'Synchronisierte Zwischenüberschrift');
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Skript'));
    await tester.pumpAndSettle();
    expect(find.text('Synchronisierte Zwischenüberschrift'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('eraser clears a selected quote and preserves other marks', (
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
      title: 'Markierungstest',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          QuoteBlock(
            id: 'marked-quote',
            text: 'Gelb fett kursiv',
            author: '',
            source: '',
            marks: const [
              InlineMark(start: 0, end: 4, highlighted: true),
              InlineMark(
                start: 5,
                end: 9,
                bold: true,
                highlighted: true,
              ),
              InlineMark(start: 10, end: 16, italic: true),
            ],
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

    final quote = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.controller?.text == 'Gelb fett kursiv',
    );
    await tester.tap(quote);
    await tester.sendKeyDownEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(_primaryModifierKey);
    await tester.pump();
    expect(find.byTooltip('Markieren'), findsOneWidget);
    expect(find.byTooltip('Markierungen entfernen'), findsOneWidget);

    await tester.tap(find.byTooltip('Markierungen entfernen'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      tester.widget<TextField>(quote).controller?.selection.isCollapsed,
      isTrue,
    );

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final marks = saved.document.blocks.whereType<QuoteBlock>().single.marks;
    expect(marks.any((mark) => mark.highlighted), isFalse);
    expect(marks.any((mark) => mark.bold), isTrue);
    expect(marks.any((mark) => mark.italic), isTrue);

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

    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'Skriptabsatz',
      ),
    );
    await tester.pump();
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

  testWidgets(
    'Bible quote replaces an empty active block instead of jumping to the end',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Zitatposition',
        contentKind: ContentKind.shortTopic,
        primaryBibleReference: BibleReferenceParser().parse('Johannes 3,16'),
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'before-quote',
              text: 'Davor',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'empty-for-quote',
              text: '',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'after-quote',
              text: 'Danach',
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

      final emptyField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text.isEmpty == true &&
            widget.decoration?.hintText == '',
      );
      await tester.tap(emptyField);
      await tester.pump();
      await tester.tap(find.byTooltip('Bibelstelle einfügen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('bible-text-field')),
        '16\u00a0Denn so sehr hat Gott die Welt geliebt.',
      );
      await tester.tap(find.byKey(const Key('insert-bible-reference')));
      await tester.pump(const Duration(milliseconds: 800));

      final saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      expect(saved.document.blocks, hasLength(3));
      expect(saved.document.blocks[0].plainText, 'Davor');
      expect(saved.document.blocks[1], isA<QuoteBlock>());
      expect(saved.document.blocks[1].plainText, contains('Denn so sehr'));
      expect(saved.document.blocks[2].plainText, 'Danach');
      expect(
        saved.document.blocks.whereType<ParagraphBlock>().any(
          (block) => block.text.isEmpty,
        ),
        isFalse,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('ELB85 selection inserts a local Bible passage', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final sermon = created.copyWith(
      title: 'Lokaler Bibeltext',
      primaryBibleReference: BibleReferenceParser().parse('Johannes 3,16'),
      document: created.document.copyWith(
        modules: const [
          SermonModule(
            id: 'script',
            kind: SermonModuleKind.script,
            title: 'Skript',
            sortOrder: 1,
          ),
        ],
      ),
    );
    await repository.update(sermon);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bibleProviderProvider.overrideWithValue(_FakeElb85Provider()),
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

    await tester.tap(find.text('Absatz hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text.isEmpty == true &&
            widget.decoration?.hintText == '',
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Bibelstelle einfügen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bible-text-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('elb85-mode')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bible-text-field')), findsNothing);
    expect(find.byKey(const Key('bible-book-field')), findsOneWidget);
    expect(find.byKey(const Key('bible-chapter-field')), findsOneWidget);
    expect(find.byKey(const Key('bible-verse-from-field')), findsOneWidget);
    expect(find.byKey(const Key('bible-verse-to-field')), findsOneWidget);

    await tester.tap(find.byKey(const Key('bible-book-field')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('bible-book-field')),
          )
          .initialValue,
      'ps',
    );

    await tester.tap(find.byKey(const Key('bible-book-field')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyO);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byKey(const Key('bible-book-field')),
          )
          .initialValue,
      'john',
    );

    await tester.tap(find.byKey(const Key('bible-verse-to-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('17').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('insert-bible-reference')));
    await tester.pump(const Duration(milliseconds: 700));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<QuoteBlock>().map((block) => block.text),
      contains(
        'Denn so sehr hat Gott die Welt geliebt. '
        'Denn Gott hat seinen Sohn gesandt. Johannes 3: 16-17',
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('long Outline metadata wraps instead of being clipped', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    const longLocation =
        'Bibelgemeinde Von Herz zu Herz, Fulda und zusätzlicher '
        'Veranstaltungsort im Gemeindezentrum';
    final sermon = created.copyWith(
      title: 'Outline-Umbruch',
      contentKind: ContentKind.shortTopic,
      location: longLocation,
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final location = find.byWidgetPredicate(
      (widget) =>
          widget is TextFormField && widget.initialValue == longLocation,
    );
    expect(location, findsOneWidget);
    final editable = tester.widget<EditableText>(
      find.descendant(of: location, matching: find.byType(EditableText)),
    );
    expect(editable.maxLines, isNull);
    expect(tester.getSize(location).height, greaterThan(35));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('editor shortcuts change block types and inline formatting', (
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
      title: 'Shortcut-Test',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          for (final entry in const [
            ('h1-shortcut', 'Wird H1'),
            ('h2-shortcut', 'Wird H2'),
            ('h3-shortcut', 'Wird H3'),
            ('quote-shortcut', 'Wird Zitat'),
            ('format-shortcut', 'Fett Kursiv Markiert'),
          ])
            ParagraphBlock(
              id: entry.$1,
              text: entry.$2,
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

    Finder richField(String text) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == text,
    );

    await tester.tap(richField('Wird H1'));
    await _sendCommandKey(tester, LogicalKeyboardKey.digit1);
    await tester.tap(richField('Wird H2'));
    await _sendCommandKey(tester, LogicalKeyboardKey.digit2);
    await tester.tap(richField('Wird H3'));
    await _sendCommandKey(tester, LogicalKeyboardKey.digit3);
    await tester.tap(richField('Wird Zitat'));
    await _sendCommandKey(tester, LogicalKeyboardKey.keyQ);

    final h1Field = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Wird H1',
    );
    await tester.tap(h1Field);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text.isEmpty == true &&
            widget.focusNode?.hasFocus == true,
      ),
      findsOneWidget,
    );

    final formatField = tester.widget<TextField>(
      richField('Fett Kursiv Markiert'),
    );
    await tester.tap(richField('Fett Kursiv Markiert'));
    formatField.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await _sendCommandKey(tester, LogicalKeyboardKey.keyB);
    formatField.controller!.selection = const TextSelection(
      baseOffset: 5,
      extentOffset: 11,
    );
    await _sendCommandKey(tester, LogicalKeyboardKey.keyI);
    formatField.controller!.selection = const TextSelection(
      baseOffset: 12,
      extentOffset: 20,
    );
    await _sendCommandKey(tester, LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<HeadingBlock>().map(
        (block) => (block.text, block.level),
      ),
      [('Wird H1', 1), ('Wird H2', 2), ('Wird H3', 3)],
    );
    expect(
      saved.document.blocks.whereType<QuoteBlock>().single.text,
      'Wird Zitat',
    );
    final marks = saved.document.blocks
        .whereType<ParagraphBlock>()
        .singleWhere((block) => block.text == 'Fett Kursiv Markiert')
        .marks;
    expect(marks, hasLength(3));
    expect(marks[0].bold, isTrue);
    expect(marks[1].italic, isTrue);
    expect(marks[2].highlighted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'Backspace inherits inline formats and toolbar reflects caret and selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Formatstatus',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'formatted-backspace',
              text: 'Normal formatiert',
              semanticRole: ParagraphRole.normal,
              marks: const [
                InlineMark(
                  start: 7,
                  end: 17,
                  italic: true,
                  highlighted: true,
                ),
              ],
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

      final fieldFinder = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.controller?.text == 'Normal formatiert',
      );
      await tester.tap(fieldFinder);
      final field = tester.widget<TextField>(fieldFinder);
      field.controller!.selection = const TextSelection.collapsed(offset: 17);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(const Key('format-italic')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('format-highlight')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Normal formatier',
          selection: TextSelection.collapsed(offset: 16),
        ),
      );
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Normal formatierX',
          selection: TextSelection.collapsed(offset: 17),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      final saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      final paragraph = saved.document.blocks.single as ParagraphBlock;
      expect(paragraph.text, 'Normal formatierX');
      expect(
        paragraph.marks.any(
          (mark) => mark.start <= 16 && mark.end > 16 && mark.italic,
        ),
        isTrue,
      );
      expect(
        paragraph.marks.any(
          (mark) => mark.start <= 16 && mark.end > 16 && mark.highlighted,
        ),
        isTrue,
      );

      final currentField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == paragraph.text,
      );
      tester.widget<TextField>(currentField).controller!.selection =
          const TextSelection(baseOffset: 7, extentOffset: 16);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(const Key('format-italic')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(const Key('format-highlight')))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('trailing spaces keep a visible downstream caret position', (
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
      title: 'Leerzeichen-Cursor',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          ParagraphBlock(
            id: 'space-caret',
            text: 'Wort',
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

    final finder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == 'Wort',
    );
    await tester.tap(finder);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Wort ',
        selection: TextSelection.collapsed(
          offset: 5,
          affinity: TextAffinity.upstream,
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'Wort ',
      ),
    );
    expect(field.controller!.text.endsWith(' '), isTrue);
    expect(field.controller!.selection.extentOffset, 5);
    expect(field.controller!.selection.affinity, TextAffinity.downstream);
    expect(field.cursorWidth, greaterThanOrEqualTo(1.8));
    expect(field.cursorColor, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'collapsed shortcuts toggle formatting for subsequently typed text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Schreibformatierung',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'typing-format-paragraph',
              text: 'Start',
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

      final fieldFinder = find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == 'Start',
      );
      await tester.tap(fieldFinder);
      final field = tester.widget<TextField>(fieldFinder);
      field.controller!.selection = const TextSelection.collapsed(offset: 5);

      Future<void> type(String text) async {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        );
        await tester.pump();
      }

      await _sendCommandKey(tester, LogicalKeyboardKey.keyI);
      await type('Start kursiv');
      await _sendCommandKey(tester, LogicalKeyboardKey.keyB);
      await type('Start kursiv beides');
      await _sendCommandKey(tester, LogicalKeyboardKey.keyI);
      await type('Start kursiv beides fett');
      await _sendCommandKey(tester, LogicalKeyboardKey.keyB);
      await _sendCommandKey(tester, LogicalKeyboardKey.keyM);
      await type('Start kursiv beides fett mark');
      await _sendCommandKey(tester, LogicalKeyboardKey.keyM);
      await type('Start kursiv beides fett mark normal');
      await tester.pump(const Duration(milliseconds: 800));

      final saved = sermonFromRow(
        await (database.select(
          database.sermonRows,
        )..where((row) => row.id.equals(sermon.id))).getSingle(),
      );
      final paragraph = saved.document.blocks.single as ParagraphBlock;
      bool formattedAt(
        int offset, {
        bool bold = false,
        bool italic = false,
        bool highlighted = false,
      }) => paragraph.marks.any(
        (mark) =>
            mark.start <= offset &&
            mark.end > offset &&
            (!bold || mark.bold) &&
            (!italic || mark.italic) &&
            (!highlighted || mark.highlighted),
      );

      expect(paragraph.text, 'Start kursiv beides fett mark normal');
      expect(formattedAt(7, italic: true), isTrue);
      expect(formattedAt(15, italic: true), isTrue);
      expect(formattedAt(15, bold: true), isTrue);
      expect(formattedAt(22, bold: true), isTrue);
      expect(formattedAt(27, highlighted: true), isTrue);
      expect(formattedAt(33, bold: true), isFalse);
      expect(formattedAt(33, italic: true), isFalse);
      expect(formattedAt(33, highlighted: true), isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'writing enters focus mode and fades only the active editor column',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Fokus-Test',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            ParagraphBlock(
              id: 'script-one',
              text: 'Erster Absatz',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'script-two',
              text: 'Zweiter Absatz',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
            NoteBlock(
              id: 'note-one',
              text: 'Erster Stichpunkt',
              visibility: NoteVisibility.editorOnly,
              createdAt: now,
              updatedAt: now,
            ),
            NoteBlock(
              id: 'note-two',
              text: 'Zweiter Stichpunkt',
              visibility: NoteVisibility.editorOnly,
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

      double opacity(String id) => tester
          .widget<AnimatedOpacity>(
            find.byKey(ValueKey('focus-fade-$id')),
          )
          .opacity;
      double splitOpacity(String moduleId, String id) => tester
          .widget<AnimatedOpacity>(
            find.byKey(ValueKey('focus-fade-$moduleId-$id')),
          )
          .opacity;
      Finder richField(String text) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == text,
      );

      expect(find.byKey(const Key('bible-toolbar-action')), findsNothing);

      await tester.tap(richField('Erster Absatz'));
      await tester.enterText(
        richField('Erster Absatz'),
        'Erster Absatz ergänzt',
      );
      await tester.pumpAndSettle();

      final bibleAction = find.byKey(const Key('bible-toolbar-action'));
      expect(bibleAction, findsOneWidget);
      expect(
        tester.getCenter(bibleAction).dy,
        closeTo(tester.getCenter(find.byTooltip('Navigation zeigen')).dy, 0.5),
      );
      expect(find.byTooltip('Navigation zeigen'), findsOneWidget);
      expect(
        tester.getCenter(bibleAction).dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('workspace-toolbar'))).dx,
        ),
      );
      expect(opacity('script-one'), 1);
      expect(opacity('script-two'), 0.5);

      final editorPage = find.byKey(
        const Key('editor-page-dismiss-focus'),
      );
      await tester.tapAt(
        tester.getTopRight(editorPage) + const Offset(-12, 90),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bible-toolbar-action')), findsNothing);
      expect(opacity('script-one'), 1);
      expect(opacity('script-two'), 1);

      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      await _tapPaneStage(tester, 'notes', last: true);
      await tester.pumpAndSettle();
      expect(_workflowStageActive(tester, 'notes'), isTrue);
      expect(_workflowStageActive(tester, 'script'), isTrue);
      expect(find.byTooltip('Outline'), findsNothing);
      expect(splitOpacity('legacy-script', 'script-one'), 1);
      expect(splitOpacity('legacy-script', 'script-two'), 1);
      expect(splitOpacity('legacy-notes', 'note-one'), 1);
      expect(splitOpacity('legacy-notes', 'note-two'), 1);

      await tester.tap(richField('Erster Stichpunkt'));
      await tester.pump();
      expect(splitOpacity('legacy-notes', 'note-one'), 1);
      expect(splitOpacity('legacy-notes', 'note-two'), 0.5);
      expect(splitOpacity('legacy-script', 'script-one'), 1);
      expect(splitOpacity('legacy-script', 'script-two'), 1);

      await tester.tap(richField('Erster Absatz ergänzt'));
      await tester.pump();
      expect(splitOpacity('legacy-script', 'script-one'), 1);
      expect(splitOpacity('legacy-script', 'script-two'), 0.5);
      expect(splitOpacity('legacy-notes', 'note-one'), 1);
      expect(splitOpacity('legacy-notes', 'note-two'), 1);

      final firstScript = tester.widget<TextField>(
        richField('Erster Absatz ergänzt'),
      );
      firstScript.controller!.selection = TextSelection.collapsed(
        offset: firstScript.controller!.text.length,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final secondScript = tester.widget<TextField>(
        richField('Zweiter Absatz'),
      );
      expect(secondScript.focusNode?.hasFocus, isTrue);
      expect(secondScript.controller?.selection.extentOffset, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(firstScript.focusNode?.hasFocus, isTrue);
      expect(
        firstScript.controller?.selection.extentOffset,
        firstScript.controller?.text.length,
      );

      await tester.tap(richField('Erster Stichpunkt'));
      final firstNote = tester.widget<TextField>(
        richField('Erster Stichpunkt'),
      );
      firstNote.controller!.selection = TextSelection.collapsed(
        offset: firstNote.controller!.text.length,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      final secondNote = tester.widget<TextField>(
        richField('Zweiter Stichpunkt'),
      );
      expect(secondNote.focusNode?.hasFocus, isTrue);
      expect(secondNote.controller?.selection.extentOffset, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(firstNote.focusNode?.hasFocus, isTrue);
      expect(
        firstNote.controller?.selection.extentOffset,
        firstNote.controller?.text.length,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets(
    'headings fade peers and split focus keeps only the opposite section',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Abschnittsfokus',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            for (final section in const [
              ('one', 'Erste Überschrift', 'Erster Text', 'Erste Notiz'),
              ('two', 'Zweite Überschrift', 'Zweiter Text', 'Zweite Notiz'),
            ]) ...[
              HeadingBlock(
                id: 'heading-${section.$1}',
                level: 2,
                text: section.$2,
                collapsed: false,
                createdAt: now,
                updatedAt: now,
              ),
              ParagraphBlock(
                id: 'script-${section.$1}',
                text: section.$3,
                semanticRole: ParagraphRole.normal,
                createdAt: now,
                updatedAt: now,
              ),
              NoteBlock(
                id: 'note-${section.$1}',
                text: section.$4,
                visibility: NoteVisibility.editorOnly,
                createdAt: now,
                updatedAt: now,
              ),
            ],
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

      double opacity(String moduleId, String id) => tester
          .widget<AnimatedOpacity>(
            find.byKey(ValueKey('focus-fade-$moduleId-$id')),
          )
          .opacity;
      double singleOpacity(String id) => tester
          .widget<AnimatedOpacity>(
            find.byKey(ValueKey('focus-fade-$id')),
          )
          .opacity;
      Finder richField(String text) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == text,
      );

      await tester.tap(richField('Erste Überschrift'));
      await tester.pump();
      expect(singleOpacity('heading-one'), 1);
      expect(singleOpacity('script-one'), 0.5);
      expect(singleOpacity('heading-two'), 0.5);
      expect(singleOpacity('script-two'), 0.5);

      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      await _tapPaneStage(tester, 'notes', last: true);
      await tester.pumpAndSettle();
      await tester.tap(richField('Erster Text'));
      await tester.pump();
      expect(opacity('legacy-script', 'script-one'), 1);
      expect(opacity('legacy-notes', 'note-one'), 1);
      expect(opacity('linked', 'heading-one'), 0.5);
      expect(opacity('legacy-script', 'script-two'), 0.5);
      expect(opacity('legacy-notes', 'note-two'), 0.5);
      expect(opacity('linked', 'heading-two'), 0.5);

      await tester.tap(richField('Erste Notiz'));
      await tester.pump();
      expect(opacity('legacy-notes', 'note-one'), 1);
      expect(opacity('legacy-script', 'script-one'), 1);
      expect(opacity('linked', 'heading-one'), 0.5);
      expect(opacity('legacy-script', 'script-two'), 0.5);
      expect(opacity('legacy-notes', 'note-two'), 0.5);

      await tester.tap(
        find.descendant(
          of: find.byKey(
            const ValueKey('focus-fade-linked-heading-one'),
          ),
          matching: richField('Erste Überschrift'),
        ),
      );
      await tester.pump();
      expect(opacity('linked', 'heading-one'), 1);
      expect(opacity('legacy-script', 'script-one'), 0.5);
      expect(opacity('legacy-notes', 'note-one'), 0.5);
      expect(opacity('linked', 'heading-two'), 0.5);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('Command-A formats all paragraphs in the active editor column', (
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
      title: 'Mehrfachauswahl',
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
          ParagraphBlock(
            id: 'second-paragraph',
            text: 'Zweiter Absatz',
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

    Finder richField(String text) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == text,
    );

    final firstBounds = tester.getRect(richField('Erster Absatz'));
    final secondBounds = tester.getRect(richField('Zweiter Absatz'));
    final drag = await tester.startGesture(
      Offset(secondBounds.right - 4, secondBounds.center.dy),
    );
    await drag.moveTo(Offset(firstBounds.left + 4, firstBounds.center.dy));
    await drag.up();
    await _sendCommandKey(tester, LogicalKeyboardKey.keyB);

    await tester.tap(richField('Erster Absatz'));
    await tester.sendKeyDownEvent(_primaryModifierKey);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(_primaryModifierKey);
    await _sendCommandKey(tester, LogicalKeyboardKey.keyM);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    final paragraphs = saved.document.blocks.whereType<ParagraphBlock>();
    expect(paragraphs, hasLength(2));
    for (final paragraph in paragraphs) {
      expect(paragraph.marks.any((mark) => mark.bold), isTrue);
      expect(
        paragraph.marks,
        contains(
          isA<InlineMark>()
              .having((mark) => mark.start, 'start', 0)
              .having((mark) => mark.end, 'end', paragraph.text.length)
              .having((mark) => mark.highlighted, 'highlighted', isTrue),
        ),
      );
    }

    await tester.tap(find.byTooltip('Markierungen entfernen'));
    await tester.pump(const Duration(milliseconds: 800));
    final cleared = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    for (final paragraph
        in cleared.document.blocks.whereType<ParagraphBlock>()) {
      expect(paragraph.marks.any((mark) => mark.highlighted), isFalse);
      expect(paragraph.marks.any((mark) => mark.bold), isTrue);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
    'split Notes multi-block drag starts immediately in both directions',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftSermonRepository(database);
      final created = await repository.create();
      final now = DateTime.now().toUtc();
      final sermon = created.copyWith(
        title: 'Split-Auswahl',
        contentKind: ContentKind.shortTopic,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            HeadingBlock(
              id: 'split-heading',
              level: 2,
              text: 'Gemeinsame Überschrift',
              collapsed: false,
              createdAt: now,
              updatedAt: now,
            ),
            for (final entry in const [
              ('split-note-one', 'Erste Split-Notiz'),
              ('split-note-two', 'Zweite Split-Notiz'),
            ])
              NoteBlock(
                id: entry.$1,
                text: entry.$2,
                visibility: NoteVisibility.editorOnly,
                createdAt: now,
                updatedAt: now,
              ),
            ParagraphBlock(
              id: 'split-script',
              text: 'Aktiver Scriptabsatz',
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
      await tester.tap(find.byKey(const Key('toggle-workspace-split')));
      await tester.pumpAndSettle();
      await _tapPaneStage(tester, 'notes', last: true);
      await tester.pumpAndSettle();

      Finder field(String text) => find.byWidgetPredicate(
        (widget) => widget is TextField && widget.controller?.text == text,
      );
      final first = field('Erste Split-Notiz');
      final second = field('Zweite Split-Notiz');
      final script = field('Aktiver Scriptabsatz');
      await tester.tap(script);
      await tester.pump();

      var drag = await tester.startGesture(
        _caretGlobalPosition(tester, first, 2),
      );
      await drag.moveTo(_caretGlobalPosition(tester, second, 8));
      await drag.up();
      var firstSelection = tester
          .widget<TextField>(first)
          .controller!
          .selection;
      var secondSelection = tester
          .widget<TextField>(second)
          .controller!
          .selection;
      expect((firstSelection.start, firstSelection.end), (2, 17));
      expect((secondSelection.start, secondSelection.end), (0, 8));

      await tester.tap(script);
      await tester.pump();
      drag = await tester.startGesture(
        _caretGlobalPosition(tester, second, 8),
      );
      await drag.moveTo(_caretGlobalPosition(tester, first, 2));
      await drag.up();
      firstSelection = tester.widget<TextField>(first).controller!.selection;
      secondSelection = tester.widget<TextField>(second).controller!.selection;
      expect((firstSelection.start, firstSelection.end), (2, 17));
      expect((secondSelection.start, secondSelection.end), (0, 8));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('notes Tab toggles hierarchy and Enter keeps it', (
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
      title: 'Notes-Shortcut-Test',
      contentKind: ContentKind.shortTopic,
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          NoteBlock(
            id: 'parent-note',
            text: 'Hauptpunkt',
            visibility: NoteVisibility.editorOnly,
            createdAt: now,
            updatedAt: now,
          ),
          NoteBlock(
            id: 'child-note',
            text: 'Unterpunkt',
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
            initialView: WorkspaceView.notes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder richField(String text) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == text,
    );

    await tester.tap(richField('Hauptpunkt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.tap(richField('Unterpunkt'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    final emptyFields = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.controller?.text.isEmpty == true &&
          widget.focusNode?.hasFocus == true,
    );
    expect(emptyFields, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));

    final saved = sermonFromRow(
      await (database.select(
        database.sermonRows,
      )..where((row) => row.id.equals(sermon.id))).getSingle(),
    );
    expect(
      saved.document.blocks.whereType<NoteBlock>().map((block) => block.depth),
      [0, 1, 1],
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

Future<void> _sendCommandKey(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool option = false,
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(_primaryModifierKey);
  if (option) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  }
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  if (option) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  }
  await tester.sendKeyUpEvent(_primaryModifierKey);
  await tester.pump();
}

Offset _caretGlobalPosition(
  WidgetTester tester,
  Finder textField,
  int offset,
) {
  final editable = find.descendant(
    of: textField,
    matching: find.byElementPredicate(
      (element) => element.renderObject is RenderEditable,
    ),
  );
  final renderEditable = tester.renderObject<RenderEditable>(editable);
  final localPosition = renderEditable
      .getLocalRectForCaret(TextPosition(offset: offset))
      .center;
  return renderEditable.localToGlobal(localPosition);
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
  Future<void> attachAsVersion(String draggedId, String targetId) =>
      delegate.attachAsVersion(draggedId, targetId);

  @override
  Future<void> detachVersion(String id) => delegate.detachVersion(id);

  @override
  Future<void> saveVersion(String id, String reason) =>
      delegate.saveVersion(id, reason);
}

class _FakeRichClipboardSource implements RichClipboardSource {
  const _FakeRichClipboardSource(this.content);

  final RichClipboardContent content;

  @override
  Future<RichClipboardContent> read() async => content;
}

class _MemoryRichClipboard implements RichClipboardSource, RichClipboardSink {
  RichClipboardContent? content;

  @override
  Future<RichClipboardContent> read() async =>
      content ?? const RichClipboardContent();

  @override
  Future<void> write(RichClipboardContent content) async {
    this.content = content;
  }
}

class _FakeElb85Provider implements BibleProvider {
  @override
  Future<void> prepare() async {}

  @override
  Future<List<BibleTranslationInfo>> listTranslations() async => const [
    BibleTranslationInfo(id: 'elb85', label: 'ELB85', isOffline: true),
  ];

  @override
  Future<List<int>> listChapters(String translationId, String bookId) async => [
    3,
  ];

  @override
  Future<List<int>> listVerses(
    String translationId,
    String bookId,
    int chapter,
  ) async => [16, 17];

  @override
  Future<BiblePassage?> getPassage(
    BibleReference reference,
    String translationId,
  ) async => BiblePassage(
    reference: reference,
    translationId: translationId,
    text:
        'Denn so sehr hat Gott die Welt geliebt. '
        'Denn Gott hat seinen Sohn gesandt.',
    copyrightNotice: 'Test',
  );

  @override
  Future<List<BibleSearchResult>> search(String query) async => const [];
}

class _FakeLocalFeedbackService extends LocalFeedbackService {
  _FakeLocalFeedbackService()
    : super(directoryResolver: () async => Directory.systemTemp);

  FeedbackCategory? savedCategory;
  String? savedDescription;

  @override
  Future<LocalFeedbackReceipt> save({
    required FeedbackCategory category,
    required String description,
    String? sermonTitle,
    String? screenshotPath,
    DateTime? createdAt,
  }) async {
    savedCategory = category;
    savedDescription = description;
    final directory = Directory('/tmp/Sermonary Feedback/feedback-test');
    return LocalFeedbackReceipt(
      id: 'feedback-test',
      directory: directory,
      textFile: File('${directory.path}/feedback.txt'),
    );
  }
}
