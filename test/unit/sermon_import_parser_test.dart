import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/import/application/sermon_import_parser.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  final parser = SermonImportParser();

  test('imports metadata, blocks and inline formatting', () {
    final imported = parser.parse(
      '''
<title>Kommt her zu mir</title>
<subtitle>Ruhe für Müde</subtitle>
<bible>Matthäus 11,28–30</bible>
<series>Einladungen Jesu</series>
<kind>Predigt</kind>
<status>Fertig</status>
<topics>Ruhe, Gnade</topics>
<tags>Matthäus; Einladung</tags>
<date>15.06.2025</date>
<duration>25</duration>

<h1>Die Einladung</h1>

Jesus spricht zu den **Müden** und den *Beladenen*.

<quote>Kommt ***her zu mir***.</quote>
''',
      fileName: 'predigt.md',
      target: SermonImportTarget.script,
    );

    expect(imported.title, 'Kommt her zu mir');
    expect(imported.subtitle, 'Ruhe für Müde');
    expect(imported.primaryBibleReference?.bookId, 'matt');
    expect(imported.series, 'Einladungen Jesu');
    expect(imported.contentKind, ContentKind.sermon);
    expect(imported.status, SermonStatus.ready);
    expect(imported.topics, ['Ruhe', 'Gnade']);
    expect(imported.tags, ['Matthäus', 'Einladung']);
    expect(imported.scheduledAt, DateTime.utc(2025, 6, 15));
    expect(imported.plannedDurationMinutes, 25);

    final blocks = imported.document.blocks;
    expect(imported.document.hasModule(SermonModuleKind.script), isTrue);
    expect(imported.document.hasModule(SermonModuleKind.notes), isFalse);
    expect(blocks.whereType<HeadingBlock>().single.level, 1);
    final paragraph = blocks.whereType<ParagraphBlock>().single;
    expect(
      paragraph.text,
      'Jesus spricht zu den Müden und den Beladenen.',
    );
    expect(paragraph.marks, hasLength(2));
    expect(paragraph.marks.first.bold, isTrue);
    expect(paragraph.marks.last.italic, isTrue);
    final quote = blocks.whereType<QuoteBlock>().single;
    expect(quote.text, 'Kommt her zu mir.');
    expect(quote.marks.single.bold, isTrue);
    expect(quote.marks.single.italic, isTrue);
    expect(blocks.whereType<NoteBlock>(), isEmpty);
  });

  test('uses filename and supports one-line shorthand tags', () {
    final imported = parser.parse(
      '''
<kind>Kurzthema
<h1>Eine Überschrift

Ein normaler Absatz.
''',
      fileName: 'Mein Thema.txt',
      target: SermonImportTarget.script,
    );

    expect(imported.title, 'Mein Thema');
    expect(imported.contentKind, ContentKind.shortTopic);
    expect(imported.document.blocks.whereType<HeadingBlock>(), hasLength(1));
    expect(imported.document.blocks.whereType<ParagraphBlock>(), hasLength(1));
    expect(imported.corrections, hasLength(2));
  });

  test('accepts Bible chapter shorthand for normalization on Save', () {
    final imported = parser.parse(
      '<bible>1. Mose 16–17</bible>\n\nEin Absatz.',
      fileName: 'Kapitelbereich.txt',
      target: SermonImportTarget.script,
    );

    expect(imported.primaryBibleReference?.bookId, 'gen');
    expect(imported.primaryBibleReference?.displayText, '1. Mose 16–17');
  });

  test(
    'keeps a real multiline block that starts with text on its first line',
    () {
      final imported = parser.parse(
        '''
<quote>1 Darauf wurde Jesus in die Wüste geführt.
2 Und als er gefastet hatte, war er hungrig.
3 Der Versucher trat zu ihm.</quote>
''',
        fileName: 'mehrzeilig.txt',
        target: SermonImportTarget.script,
      );

      expect(
        imported.document.blocks.whereType<QuoteBlock>().single.text,
        '1 Darauf wurde Jesus in die Wüste geführt. '
        '2 Und als er gefastet hatte, war er hungrig. '
        '3 Der Versucher trat zu ihm.',
      );
      expect(imported.corrections, isEmpty);
    },
  );

  test('repairs unambiguous tag and mark syntax errors', () {
    final imported = parser.parse(
      '\uFEFF< title >Robuster Import</ title >\n'
      '< p >Ein < mark >wichtiger Text</ p >\n'
      '</quote>\n'
      '<h1>\n'
      'Offene Überschrift\n',
      fileName: 'reparatur.txt',
      target: SermonImportTarget.script,
    );

    expect(imported.title, 'Robuster Import');
    final paragraph = imported.document.blocks
        .whereType<ParagraphBlock>()
        .single;
    expect(paragraph.text, 'Ein wichtiger Text');
    expect(paragraph.marks.single.highlighted, isTrue);
    expect(
      imported.document.blocks.whereType<HeadingBlock>().single.text,
      'Offene Überschrift',
    );
    expect(imported.corrections, isNotEmpty);

    final mismatched = parser.parse(
      '<p>Absatz mit falschem Ende</quote>',
      fileName: 'falsches-ende.txt',
      target: SermonImportTarget.script,
    );
    expect(
      mismatched.document.blocks.whereType<ParagraphBlock>().single.text,
      'Absatz mit falschem Ende',
    );
    expect(
      mismatched.corrections,
      contains('Falsches </quote> durch </p> ersetzt.'),
    );
  });

  test('imports shared h3 headings and highlighted inline text', () {
    final script = parser.parse(
      '''
<title>Markierter Text</title>
<h3>Feine Gliederung</h3>
<p>Das ist <mark>wichtig</mark> und <mark>**besonders wichtig**</mark>.</p>
''',
      fileName: 'markiert.md',
      target: SermonImportTarget.script,
    );

    final heading = script.document.blocks.whereType<HeadingBlock>().single;
    expect(heading.level, 3);
    final paragraph = script.document.blocks.whereType<ParagraphBlock>().single;
    expect(
      paragraph.text,
      'Das ist wichtig und besonders wichtig.',
    );
    expect(
      paragraph.marks.where((mark) => mark.highlighted),
      hasLength(2),
    );
    expect(
      paragraph.marks.singleWhere((mark) => mark.bold).highlighted,
      isFalse,
    );

    final notes = parser.parse(
      '''
<h3>Gemeinsame Zwischenüberschrift</h3>
<li1>Ein <mark>*markierter Gedanke*</mark>.</li1>
''',
      fileName: 'notizen.txt',
      target: SermonImportTarget.notes,
    );
    expect(notes.document.blocks.whereType<HeadingBlock>().single.level, 3);
    final note = notes.document.blocks.whereType<NoteBlock>().single;
    expect(note.text, 'Ein markierter Gedanke.');
    expect(note.marks.any((mark) => mark.highlighted), isTrue);
    expect(note.marks.any((mark) => mark.italic), isTrue);
  });

  test('keeps notes and script imports strictly separate', () {
    final script = parser.parse(
      '''
<title>Zielbereiche</title>
<p>Nur im Script</p>
<quote>Auch nur im Script</quote>
''',
      fileName: 'script.md',
      target: SermonImportTarget.script,
    );
    expect(
      script.document.blocks.whereType<ParagraphBlock>().map(
        (block) => block.text,
      ),
      ['Nur im Script'],
    );
    expect(
      script.document.blocks.whereType<QuoteBlock>().map(
        (block) => block.text,
      ),
      ['Auch nur im Script'],
    );
    expect(script.document.blocks.whereType<NoteBlock>(), isEmpty);

    final notes = parser.parse(
      '''
<title>Zielbereiche</title>
<h1>Gemeinsame Überschrift</h1>
<li1>Nur in Notes</li1>
<li2>Unterpunkt</li2>
''',
      fileName: 'notes.md',
      target: SermonImportTarget.notes,
    );
    expect(notes.document.blocks.whereType<ParagraphBlock>(), isEmpty);
    expect(notes.document.blocks.whereType<QuoteBlock>(), isEmpty);
    expect(notes.document.blocks.whereType<HeadingBlock>(), hasLength(1));
    expect(
      notes.document.blocks.whereType<NoteBlock>().map((block) => block.depth),
      [0, 1],
    );

    expect(
      () => parser.parse(
        '<li1>Falscher Bereich</li1>',
        fileName: 'script.md',
        target: SermonImportTarget.script,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        '<both>Nicht mehr zulässig</both>',
        fileName: 'notes.md',
        target: SermonImportTarget.notes,
      ),
      throwsFormatException,
    );
  });

  test('rejects unsupported files and ambiguous nested block tags', () {
    expect(
      () => parser.parse(
        'Text',
        fileName: 'predigt.docx',
        target: SermonImportTarget.script,
      ),
      throwsFormatException,
    );
    expect(
      () => parser.parse(
        '<p>Äußerer Block <h1>Verschachtelt</h1></p>',
        fileName: 'predigt.md',
        target: SermonImportTarget.script,
      ),
      throwsFormatException,
    );
  });

  test('accepts ISO dates and rejects invalid calendar dates', () {
    final imported = parser.parse(
      '<date>2026-07-30</date>',
      fileName: 'predigt.txt',
      target: SermonImportTarget.script,
    );
    expect(imported.scheduledAt, DateTime.utc(2026, 7, 30));

    expect(
      () => parser.parse(
        '<date>31.02.2026</date>',
        fileName: 'predigt.txt',
        target: SermonImportTarget.script,
      ),
      throwsFormatException,
    );
  });
}
