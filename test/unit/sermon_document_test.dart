import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/sermon_editor/domain/outline.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  final now = DateTime.utc(2026, 7, 28);

  test('SermonDocument JSON roundtrip preserves typed blocks', () {
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'heading',
          level: 1,
          text: 'Gnade',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph',
          text: 'Gnade trägt durch jeden neuen Tag.',
          semanticRole: ParagraphRole.application,
          isBold: true,
          marks: const [
            InlineMark(start: 0, end: 5, bold: true),
            InlineMark(start: 6, end: 11, highlighted: true),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note',
          text: 'Pause',
          visibility: NoteVisibility.editorOnly,
          depth: 1,
          isQuickNote: true,
          marks: const [InlineMark(start: 0, end: 5, italic: true)],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final encoded = jsonEncode(document.toJson());
    final decoded = SermonDocument.fromJson(
      jsonDecode(encoded) as Map<String, Object?>,
    );

    expect(decoded.schemaVersion, 1);
    expect(decoded.blocks, hasLength(3));
    expect(decoded.blocks[1], isA<ParagraphBlock>());
    expect((decoded.blocks[1] as ParagraphBlock).isBold, isTrue);
    expect((decoded.blocks[1] as ParagraphBlock).marks, hasLength(2));
    expect((decoded.blocks[2] as NoteBlock).depth, 1);
    expect((decoded.blocks[2] as NoteBlock).isQuickNote, isTrue);
    expect((decoded.blocks[2] as NoteBlock).marks.single.italic, isTrue);
    expect(jsonEncode(decoded.toJson()), encoded);
  });

  test('version 1 migration is a no-op', () {
    const document = SermonDocument(schemaVersion: 1, blocks: []);
    final migrated = const V1DocumentMigrator().migrate(
      document,
      fromVersion: 1,
      toVersion: 1,
    );
    expect(identical(document, migrated), isTrue);
  });

  test('empty sermons have no content modules', () {
    const document = SermonDocument(schemaVersion: 1, blocks: []);

    expect(document.effectiveModules, isEmpty);
    expect(document.hasModule(SermonModuleKind.notes), isFalse);
    expect(document.hasModule(SermonModuleKind.script), isFalse);
    expect(document.hasModule(SermonModuleKind.presentation), isFalse);
  });

  test('legacy content is exposed as stable inferred modules', () {
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        ParagraphBlock(
          id: 'paragraph',
          text: 'Ausformulierter Text',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note',
          text: 'Stichpunkt',
          visibility: NoteVisibility.editorOnly,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      presentation: const PresentationDeck(
        slides: [
          PresentationSlide(
            id: 'slide',
            template: PresentationSlideTemplate.title,
          ),
        ],
      ),
    );

    expect(
      document.effectiveModules.map((module) => module.kind),
      SermonModuleKind.values,
    );
    expect(document.moduleFor(SermonModuleKind.notes)?.id, 'legacy-notes');
    expect(document.moduleFor(SermonModuleKind.script)?.id, 'legacy-script');
    expect(
      document.moduleFor(SermonModuleKind.presentation)?.id,
      'legacy-presentation',
    );
  });

  test('an explicitly added empty module survives JSON', () {
    const document = SermonDocument(
      schemaVersion: 1,
      blocks: [],
      modules: [
        SermonModule(
          id: 'empty-script',
          kind: SermonModuleKind.script,
          title: 'Skript',
          sortOrder: 1,
        ),
      ],
    );

    final decoded = SermonDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())) as Map<String, Object?>,
    );

    expect(decoded.hasModule(SermonModuleKind.script), isTrue);
    expect(decoded.moduleFor(SermonModuleKind.script)?.id, 'empty-script');
  });

  test('version 2 keeps multiple modules and their content independent', () {
    final document = SermonDocument(
      schemaVersion: 2,
      blocks: [
        HeadingBlock(
          id: 'shared-heading',
          level: 1,
          text: 'Gemeinsame Überschrift',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note-a',
          text: 'Notiz A',
          visibility: NoteVisibility.editorOnly,
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note-b',
          text: 'Notiz B',
          visibility: NoteVisibility.editorOnly,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      modules: [
        SermonModule(
          id: 'notes-a',
          kind: SermonModuleKind.notes,
          title: '',
          sortOrder: 0,
          blockIds: ['shared-heading', 'note-a'],
          linkGroupId: 'group-a',
          createdAt: now,
        ),
        SermonModule(
          id: 'notes-b',
          kind: SermonModuleKind.notes,
          title: 'Zweite Notizen',
          sortOrder: 1,
          blockIds: ['shared-heading', 'note-b'],
          linkGroupId: 'group-a',
          createdAt: now,
        ),
      ],
    );

    final decoded = SermonDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())) as Map<String, Object?>,
    );

    expect(decoded.modulesOfKind(SermonModuleKind.notes), hasLength(2));
    expect(
      decoded.blocksForModule('notes-a').map((block) => block.id),
      ['shared-heading', 'note-a'],
    );
    expect(
      decoded.blocksForModule('notes-b').map((block) => block.id),
      ['shared-heading', 'note-b'],
    );
    expect(decoded.modulesAreLinked('notes-a', 'notes-b'), isTrue);
    expect(decoded.validateV2(), isEmpty);
  });

  test('content version families survive JSON and sort newest first', () {
    const document = SermonDocument(
      schemaVersion: 2,
      blocks: [],
      modules: [
        SermonModule(
          id: 'script-root',
          kind: SermonModuleKind.script,
          title: 'Skript',
          sortOrder: 0,
        ),
        SermonModule(
          id: 'script-v2',
          kind: SermonModuleKind.script,
          title: 'Skript',
          sortOrder: 1,
          revision: 2,
          versionRootId: 'script-root',
        ),
      ],
    );

    final decoded = SermonDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())) as Map<String, Object?>,
    );

    expect(decoded.moduleById('script-v2')?.versionRootId, 'script-root');
    expect(
      decoded.versionsOf('script-root').map((module) => module.id),
      ['script-v2', 'script-root'],
    );
    expect(decoded.validateV2(), isEmpty);
  });

  test('legacy modules migrate to one linked version 2 group', () {
    final legacy = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'heading',
          level: 1,
          text: 'Überschrift',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph',
          text: 'Skript',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note',
          text: 'Notiz',
          visibility: NoteVisibility.editorOnly,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      presentation: const PresentationDeck(
        slides: [
          PresentationSlide(
            id: 'slide',
            template: PresentationSlideTemplate.title,
          ),
        ],
      ),
    );

    final migrated = legacy.migrateToV2(
      sermonId: 'sermon-a',
      fallbackCreatedAt: now,
    );

    expect(migrated.schemaVersion, 2);
    expect(migrated.effectiveModules, hasLength(3));
    expect(
      migrated.effectiveModules.map((module) => module.linkGroupId).toSet(),
      {'legacy-link-sermon-a'},
    );
    expect(
      migrated.moduleFor(SermonModuleKind.presentation)?.slideIds,
      ['slide'],
    );
    expect(migrated.validateV2(), isEmpty);
  });

  test('legacy migration preserves headings between their body sections', () {
    final now = DateTime.utc(2026, 8, 10);
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'heading-one',
          level: 2,
          text: 'Eins',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph-one',
          text: 'Erster Text',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
        HeadingBlock(
          id: 'heading-two',
          level: 2,
          text: 'Zwei',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph-two',
          text: 'Zweiter Text',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    ).migrateToV2(sermonId: 'ordered', fallbackCreatedAt: now);

    expect(document.moduleFor(SermonModuleKind.script)?.blockIds, [
      'heading-one',
      'paragraph-one',
      'heading-two',
      'paragraph-two',
    ]);

    final repaired = SermonDocument.fromJson({
      ...document.toJson(),
      'modules': [
        for (final module in document.modules)
          {
            ...module.toJson(),
            if (module.kind == SermonModuleKind.script)
              'blockIds': [
                'heading-one',
                'heading-two',
                'paragraph-one',
                'paragraph-two',
              ],
          },
      ],
    });
    expect(repaired.moduleFor(SermonModuleKind.script)?.blockIds, [
      'heading-one',
      'paragraph-one',
      'heading-two',
      'paragraph-two',
    ]);
  });

  test('presentation deck is optional and survives a JSON roundtrip', () {
    const document = SermonDocument(
      schemaVersion: 1,
      blocks: [],
      presentation: PresentationDeck(
        slides: [
          PresentationSlide(
            id: 'slide-1',
            template: PresentationSlideTemplate.headingBible,
            title: 'Der Weinstock',
            titleMarks: [InlineMark(start: 0, end: 3, bold: true)],
            body: 'Bleibt in mir und ich in euch.',
            bodyMarks: [
              InlineMark(
                start: 0,
                end: 6,
                italic: true,
                highlighted: true,
              ),
            ],
            reference: 'Johannes 15,4',
            continuationGroupId: 'bible-group',
            continuationCount: 2,
            anchor: PresentationAnchor(
              view: PresentationAnchorView.script,
              blockId: 'paragraph-1',
              offset: 12,
            ),
          ),
        ],
      ),
    );

    final decoded = SermonDocument.fromJson(
      jsonDecode(jsonEncode(document.toJson())) as Map<String, Object?>,
    );

    expect(decoded.presentation.slides, hasLength(1));
    expect(
      decoded.presentation.slides.single.template,
      PresentationSlideTemplate.headingBible,
    );
    expect(decoded.presentation.slides.single.anchor?.offset, 12);
    expect(decoded.presentation.slides.single.titleMarks.single.bold, isTrue);
    expect(
      decoded.presentation.slides.single.bodyMarks.single.highlighted,
      isTrue,
    );
    expect(decoded.presentation.slides.single.bodyMarks.single.italic, isTrue);
    expect(
      decoded.presentation.slides.single.continuationGroupId,
      'bible-group',
    );
    expect(decoded.presentation.slides.single.continuationCount, 2);

    final legacy = SermonDocument.fromJson({
      'schemaVersion': 1,
      'blocks': <Object?>[],
    });
    expect(legacy.presentation.slides, isEmpty);
  });

  test('legacy top-level notes remain ordinary notes', () {
    final legacyNote = NoteBlock(
      id: 'legacy-note',
      text: 'Bestehende Quicknote',
      visibility: NoteVisibility.editorOnly,
      createdAt: now,
      updatedAt: now,
    ).toJson()..remove('isQuickNote');

    final decoded = DocumentBlock.fromJson(legacyNote) as NoteBlock;

    expect(decoded.isQuickNote, isFalse);
  });

  test('word count, duration and outline use structured content', () {
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'h',
          level: 1,
          text: 'Erster Punkt',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'p',
          text: 'Eins zwei drei vier fünf sechs',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    expect(document.wordCount, 8);
    expect(document.estimatedDuration().inSeconds, 4);
    final outline = buildOutline(document);
    expect(outline.single.title, 'Erster Punkt');
    expect(outline.single.wordCount, 8);
  });
}
