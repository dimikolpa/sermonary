import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/presentation/domain/presentation_slide_order.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  final now = DateTime.utc(2026, 8, 10);
  final document = SermonDocument(
    schemaVersion: SermonDocument.currentSchemaVersion,
    blocks: [
      ParagraphBlock(
        id: 'first',
        text: 'Erster Absatz',
        semanticRole: ParagraphRole.normal,
        createdAt: now,
        updatedAt: now,
      ),
      ParagraphBlock(
        id: 'second',
        text: 'Zweiter Absatz',
        semanticRole: ParagraphRole.normal,
        createdAt: now,
        updatedAt: now,
      ),
    ],
    modules: [
      const SermonModule(
        id: 'script',
        kind: SermonModuleKind.script,
        title: 'Skript',
        sortOrder: 0,
        blockIds: ['first', 'second'],
      ),
    ],
  );

  PresentationSlide anchored(String id, String blockId) => PresentationSlide(
    id: id,
    template: PresentationSlideTemplate.headingText,
    anchor: PresentationAnchor(
      view: PresentationAnchorView.script,
      blockId: blockId,
      moduleId: 'script',
    ),
  );

  test('anchored slides always follow their text positions', () {
    final ordered = orderPresentationSlidesByText(
      document: document,
      slides: [
        anchored('later-created-first', 'second'),
        anchored('created-later', 'first'),
        const PresentationSlide(
          id: 'unanchored',
          template: PresentationSlideTemplate.title,
        ),
      ],
    );

    expect(
      ordered.map((slide) => slide.id),
      ['created-later', 'later-created-first', 'unanchored'],
    );
  });

  test('an unanchored slide keeps its manually chosen slot', () {
    final ordered = orderPresentationSlidesByText(
      document: document,
      slides: [
        anchored('second-anchor', 'second'),
        const PresentationSlide(
          id: 'manual-between',
          template: PresentationSlideTemplate.title,
        ),
        anchored('first-anchor', 'first'),
      ],
    );

    expect(
      ordered.map((slide) => slide.id),
      ['first-anchor', 'manual-between', 'second-anchor'],
    );
  });

  test('legacy anchors without a module id are resolved by their block', () {
    final ordered = orderPresentationSlidesByText(
      document: document,
      slides: [
        const PresentationSlide(
          id: 'legacy-second',
          template: PresentationSlideTemplate.headingText,
          anchor: PresentationAnchor(
            view: PresentationAnchorView.script,
            blockId: 'second',
          ),
        ),
        const PresentationSlide(
          id: 'legacy-first',
          template: PresentationSlideTemplate.headingText,
          anchor: PresentationAnchor(
            view: PresentationAnchorView.script,
            blockId: 'first',
          ),
        ),
      ],
    );

    expect(
      ordered.map((slide) => slide.id),
      ['legacy-first', 'legacy-second'],
    );
  });
}
