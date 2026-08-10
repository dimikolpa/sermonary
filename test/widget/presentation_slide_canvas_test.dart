import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/presentation/presentation/presentation_editor_view.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  testWidgets('title subtitle stays centered between equal dividers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'title',
                template: PresentationSlideTemplate.title,
                title: 'Komme ich um, so komme ich um',
                subtitle: 'Apostelgeschichte 20,22–25',
              ),
            ),
          ),
        ),
      ),
    );

    final canvasCenter = tester.getCenter(
      find.byKey(const Key('presentation-slide-background')),
    );
    final subtitleCenter = tester.getCenter(
      find.byKey(const Key('presentation-title-subtitle')),
    );
    expect(subtitleCenter.dx, closeTo(canvasCenter.dx, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('small slide previews scale the complete canvas', (tester) async {
    const bibleText =
        'So geh hin und versammle alle, die hören sollen, und richte ihre Gedanken auf Gottes Wort.';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'preview',
                template: PresentationSlideTemplate.headingBible,
                body: bibleText,
                reference: 'Ester 4,16',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(FittedBox), findsOneWidget);
    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(renderedText, contains(bibleText));
    expect(renderedText, contains('Ester 4,16'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty presentation fields do not render placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'empty',
                template: PresentationSlideTemplate.headingBible,
              ),
            ),
          ),
        ),
      ),
    );

    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(renderedText, isNot(contains('Überschrift')));
    expect(renderedText, isNot(contains('Bibeltext')));
    expect(renderedText, isNot(contains('Bibelstelle')));
  });

  testWidgets('continued Bible slides show their part number', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'part-two',
                template: PresentationSlideTemplate.headingBible,
                body: 'Fortsetzung des Bibeltextes',
                continuationGroupId: 'group',
                continuationIndex: 2,
                continuationCount: 3,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('transparent presentation images use the warm slide background', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'transparent-image',
                template: PresentationSlideTemplate.image,
              ),
            ),
          ),
        ),
      ),
    );

    final background = tester.widget<Container>(
      find.byKey(const Key('presentation-slide-background')),
    );
    expect(
      (background.decoration! as BoxDecoration).color,
      const Color(0xFFFDFCF9),
    );
  });

  testWidgets('large contents shows only numbered heading-style points', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'large-contents',
                template: PresentationSlideTemplate.largeContents,
                title: 'Diese Überschrift darf nicht erscheinen',
                items: ['Erster großer Punkt', 'Zweiter großer Punkt'],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(renderedText, contains('Erster großer Punkt'));
    expect(renderedText, contains('Zweiter großer Punkt'));
    expect(
      renderedText,
      isNot(contains('Diese Überschrift darf nicht erscheinen')),
    );
    final point = tester
        .widgetList<RichText>(find.byType(RichText))
        .singleWhere(
          (widget) => widget.text.toPlainText() == 'Erster großer Punkt',
        );
    expect((point.text as TextSpan).style?.fontWeight, FontWeight.w600);
  });

  testWidgets('image and Bible template renders its complete 1/3–2/3 content', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: SlideCanvas(
              slide: PresentationSlide(
                id: 'image-bible',
                template: PresentationSlideTemplate.headingImageBible,
                title: 'Der Weinstock',
                body: 'Bleibt in mir und ich in euch.',
                reference: 'Johannes 15,4',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('presentation-image-placeholder')), findsOne);
    final renderedText = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((widget) => widget.text.toPlainText())
        .join('\n');
    expect(renderedText, contains('Der Weinstock'));
    expect(renderedText, contains('Bleibt in mir und ich in euch.'));
    expect(renderedText, contains('Johannes 15,4'));
    expect(tester.takeException(), isNull);
  });
}
