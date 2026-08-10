import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/sermon_editor/domain/module_linking.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);

  HeadingBlock heading(String id, String text, {int level = 1}) => HeadingBlock(
    id: id,
    level: level,
    text: text,
    collapsed: false,
    createdAt: now,
    updatedAt: now,
  );

  test('links compatible filled modules without losing body blocks', () {
    final document = SermonDocument(
      schemaVersion: 2,
      blocks: [
        heading('h-a', 'Anfang'),
        heading('h-b', 'Schluss'),
        NoteBlock(
          id: 'note',
          text: 'Notiz bleibt',
          visibility: NoteVisibility.editorOnly,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph',
          text: 'Skript bleibt',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      modules: [
        const SermonModule(
          id: 'notes',
          kind: SermonModuleKind.notes,
          title: '',
          sortOrder: 0,
          blockIds: ['h-a', 'note'],
        ),
        const SermonModule(
          id: 'script',
          kind: SermonModuleKind.script,
          title: '',
          sortOrder: 1,
          blockIds: ['h-b', 'paragraph'],
        ),
      ],
    );

    final linked = const ModuleLinkingService().link(
      document: document,
      sourceModuleId: 'notes',
      targetModuleId: 'script',
      createGroupId: () => 'group',
      now: now,
    );

    expect(linked.modulesAreLinked('notes', 'script'), isTrue);
    expect(linked.moduleById('notes')!.blockIds, ['h-a', 'note', 'h-b']);
    expect(linked.moduleById('script')!.blockIds, [
      'h-a',
      'h-b',
      'paragraph',
    ]);
    expect(
      linked.blocks.map((block) => block.id),
      containsAll(['note', 'paragraph']),
    );
    expect(linked.validateV2(), isEmpty);
  });

  test('rejects heading order conflicts without changing the document', () {
    final document = SermonDocument(
      schemaVersion: 2,
      blocks: [heading('a', 'A'), heading('b', 'B')],
      modules: const [
        SermonModule(
          id: 'one',
          kind: SermonModuleKind.notes,
          title: '',
          sortOrder: 0,
          blockIds: ['a', 'b'],
        ),
        SermonModule(
          id: 'two',
          kind: SermonModuleKind.script,
          title: '',
          sortOrder: 1,
          blockIds: ['b', 'a'],
        ),
      ],
    );

    expect(
      () => const ModuleLinkingService().link(
        document: document,
        sourceModuleId: 'one',
        targetModuleId: 'two',
        createGroupId: () => 'group',
        now: now,
      ),
      throwsA(isA<ModuleLinkConflict>()),
    );
    expect(
      document.modules.every((module) => module.linkGroupId == null),
      isTrue,
    );
  });

  test('unlink clones shared headings and clears presentation anchors', () {
    final document = SermonDocument(
      schemaVersion: 2,
      blocks: [heading('shared', 'Gemeinsam')],
      presentation: const PresentationDeck(
        slides: [
          PresentationSlide(
            id: 'slide',
            template: PresentationSlideTemplate.title,
            anchor: PresentationAnchor(
              view: PresentationAnchorView.script,
              blockId: 'shared',
              moduleId: 'script',
            ),
          ),
        ],
      ),
      modules: const [
        SermonModule(
          id: 'script',
          kind: SermonModuleKind.script,
          title: '',
          sortOrder: 0,
          blockIds: ['shared'],
          linkGroupId: 'group',
        ),
        SermonModule(
          id: 'presentation',
          kind: SermonModuleKind.presentation,
          title: '',
          sortOrder: 1,
          slideIds: ['slide'],
          linkGroupId: 'group',
        ),
      ],
    );

    final unlinked = const ModuleLinkingService().unlink(
      document: document,
      moduleId: 'script',
      createBlockId: () => 'cloned',
      now: now,
    );

    expect(unlinked.moduleById('script')!.blockIds, ['cloned']);
    expect(
      unlinked.effectiveModules.every((module) => module.linkGroupId == null),
      isTrue,
    );
    expect(unlinked.presentation.slides.single.anchor, isNull);
    expect(unlinked.validateV2(), isEmpty);
  });

  test('rejects anchors between unlinked presentation and text modules', () {
    final document = SermonDocument(
      schemaVersion: 2,
      blocks: [heading('heading', 'Anfang')],
      presentation: const PresentationDeck(
        slides: [
          PresentationSlide(
            id: 'slide',
            template: PresentationSlideTemplate.title,
            anchor: PresentationAnchor(
              view: PresentationAnchorView.script,
              blockId: 'heading',
              moduleId: 'script',
            ),
          ),
        ],
      ),
      modules: const [
        SermonModule(
          id: 'script',
          kind: SermonModuleKind.script,
          title: '',
          sortOrder: 0,
          blockIds: ['heading'],
        ),
        SermonModule(
          id: 'presentation',
          kind: SermonModuleKind.presentation,
          title: '',
          sortOrder: 1,
          slideIds: ['slide'],
        ),
      ],
    );

    expect(
      document.validateV2().map((issue) => issue.code),
      contains('unlinked-slide-anchor'),
    );
  });
}
