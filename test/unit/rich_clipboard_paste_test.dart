import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/workspace/application/rich_clipboard_paste.dart';

void main() {
  const parser = RichPasteParser();

  test('parses Word headings, paragraphs, blank lines and inline styles', () {
    final blocks = parser.parse(
      const RichClipboardContent(
        html: '''
          <h1>Erste Überschrift</h1>
          <p class="MsoHeading2">Zweite Überschrift</p>
          <p style="mso-outline-level:2">Dritte Überschrift</p>
          <p>Ein <strong>fetter</strong> und <em>kursiver</em> Absatz.</p>
          <p>&nbsp;</p>
          <p>Letzter Absatz.</p>
        ''',
      ),
    );

    expect(blocks, hasLength(6));
    expect(blocks[0].headingLevel, 1);
    expect(blocks[1].headingLevel, 2);
    expect(blocks[2].headingLevel, 3);
    expect(blocks[3].kind, PastedBlockKind.body);
    expect(blocks[3].text, 'Ein fetter und kursiver Absatz.');
    expect(
      blocks[3].marks,
      contains(
        isA<PastedInlineMark>()
            .having((mark) => mark.bold, 'bold', isTrue)
            .having(
              (mark) => blocks[3].text.substring(mark.start, mark.end),
              'text',
              'fetter',
            ),
      ),
    );
    expect(
      blocks[3].marks,
      contains(
        isA<PastedInlineMark>()
            .having((mark) => mark.italic, 'italic', isTrue)
            .having(
              (mark) => blocks[3].text.substring(mark.start, mark.end),
              'text',
              'kursiver',
            ),
      ),
    );
    expect(blocks[4].text, isEmpty);
    expect(blocks[5].text, 'Letzter Absatz.');
  });

  test('plain text keeps lines and recognizes Markdown formatting', () {
    final blocks = parser.parse(
      const RichClipboardContent(
        plainText: '# Titel\nEin **fetter** Absatz\n\n*kursiv*',
      ),
    );

    expect(blocks, hasLength(4));
    expect(blocks[0].headingLevel, 1);
    expect(blocks[0].text, 'Titel');
    expect(blocks[1].text, 'Ein fetter Absatz');
    expect(blocks[1].marks.single.bold, isTrue);
    expect(blocks[2].text, isEmpty);
    expect(blocks[3].text, 'kursiv');
    expect(blocks[3].marks.single.italic, isTrue);
  });

  test('parses Sermonary quotes, note depth and highlights', () {
    final blocks = parser.parse(
      const RichClipboardContent(
        html: '''
          <blockquote><mark>Ein Zitat</mark></blockquote>
          <li data-sermonary-depth="1"><strong>Unterpunkt</strong></li>
        ''',
      ),
    );

    expect(blocks, hasLength(2));
    expect(blocks.first.kind, PastedBlockKind.quote);
    expect(blocks.first.marks.single.highlighted, isTrue);
    expect(blocks.last.kind, PastedBlockKind.body);
    expect(blocks.last.noteDepth, 1);
    expect(blocks.last.marks.single.bold, isTrue);
  });
}
