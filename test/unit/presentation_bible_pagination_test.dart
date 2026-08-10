import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/presentation/domain/presentation_bible_pagination.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  test('long Bible text is split into consecutive anchored slides', () {
    final text = List.generate(
      180,
      (index) => 'Wort${index + 1}',
    ).join(' ');
    var nextId = 0;
    const anchor = PresentationAnchor(
      view: PresentationAnchorView.script,
      blockId: 'quote-1',
      offset: 14,
    );
    final slides = paginatePresentationBibleSlide(
      PresentationSlide(
        id: 'first',
        template: PresentationSlideTemplate.headingBible,
        title: 'Gottes Zusage',
        body: text,
        reference: 'Johannes 15,4–11',
        anchor: anchor,
      ),
      createId: () => 'part-${++nextId}',
    );

    expect(slides.length, greaterThan(1));
    expect(slides.map((slide) => slide.body).join(' '), text);
    expect(slides.map((slide) => slide.anchor), everyElement(same(anchor)));
    expect(
      slides.map((slide) => slide.continuationIndex),
      List.generate(slides.length, (index) => index + 1),
    );
    expect(
      slides.map((slide) => slide.continuationCount),
      everyElement(slides.length),
    );
    expect(
      slides.map((slide) => slide.continuationGroupId).toSet(),
      {'first'},
    );
  });

  test(
    'editing one continuation keeps the group consecutive and renumbered',
    () {
      final original = List.generate(
        170,
        (index) => 'Abschnitt$index',
      ).join(' ');
      var nextId = 0;
      final initial = paginatePresentationBibleSlide(
        PresentationSlide(
          id: 'bible',
          template: PresentationSlideTemplate.headingBible,
          body: original,
        ),
        createId: () => 'generated-${++nextId}',
      );
      final deck = [
        const PresentationSlide(
          id: 'before',
          template: PresentationSlideTemplate.title,
        ),
        ...initial,
        const PresentationSlide(
          id: 'after',
          template: PresentationSlideTemplate.title,
        ),
      ];
      final changed = initial[1].copyWith(title: 'Gemeinsame Überschrift');
      final updated = replaceAndPaginatePresentationBibleSlide(
        deck,
        changed,
        createId: () => 'new-${++nextId}',
      );
      final group = updated
          .where((slide) => slide.continuationGroupId == 'bible')
          .toList();

      expect(updated.first.id, 'before');
      expect(updated.last.id, 'after');
      expect(group, isNotEmpty);
      expect(
        group.map((slide) => slide.title),
        everyElement('Gemeinsame Überschrift'),
      );
      expect(
        group.map((slide) => slide.continuationIndex),
        List.generate(group.length, (index) => index + 1),
      );
    },
  );

  test('inline formatting is retained across Bible slide boundaries', () {
    final text = List.generate(120, (index) => 'Vers$index').join(' ');
    final parts = splitPresentationBibleText(
      text,
      [
        InlineMark(
          start: 0,
          end: text.length,
          italic: true,
          highlighted: true,
        ),
      ],
      maxCharacters: 180,
    );

    expect(parts.length, greaterThan(1));
    for (final part in parts) {
      expect(part.marks, isNotEmpty);
      expect(part.marks.single.start, 0);
      expect(part.marks.single.end, part.text.length);
      expect(part.marks.single.italic, isTrue);
      expect(part.marks.single.highlighted, isTrue);
    }
  });
}
