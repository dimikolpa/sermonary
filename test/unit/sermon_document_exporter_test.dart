import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/export/application/sermon_document_exporter.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/domain/presentation_anchor_index.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates an A4 PDF and a structured Word document', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    final sermon = created.copyWith(
      title: 'Gnade & Wahrheit',
      subtitle: 'Eine Predigt über den Weg Jesu.',
      contentKind: ContentKind.sermon,
      primaryBibleReference: const BibleReference(
        bookId: 'john',
        startChapter: 1,
        startVerse: 14,
        endVerse: 18,
        displayText: 'Johannes 1,14–18',
      ),
      document: SermonDocument(
        schemaVersion: 1,
        blocks: [
          HeadingBlock(
            id: 'heading',
            level: 1,
            text: 'Gott kommt uns nahe',
            collapsed: false,
            createdAt: now,
            updatedAt: now,
          ),
          ParagraphBlock(
            id: 'paragraph',
            text: 'Das Wort wurde Fleisch und wohnte unter uns.',
            semanticRole: ParagraphRole.explanation,
            marks: const [
              InlineMark(start: 4, end: 8, bold: true, highlighted: true),
            ],
            createdAt: now,
            updatedAt: now,
          ),
          for (var index = 0; index < 24; index++)
            ParagraphBlock(
              id: 'long-paragraph-$index',
              text:
                  'Jesus Christus begegnet Menschen mit Wahrheit und Gnade. '
                  'Dieser Beispielabsatz prüft den zuverlässigen Seitenumbruch, '
                  'die ruhigen Abstände und die wiederkehrenden Kopf- und '
                  'Fußzeilen in einer längeren Predigt.',
              semanticRole: ParagraphRole.explanation,
              createdAt: now,
              updatedAt: now,
            ),
          ParagraphBlock(
            id: 'oversized-paragraph',
            text: List.filled(
              55,
              'Auch ein einzelner sehr langer Absatz muss über mehrere '
              'A4-Seiten hinweg zuverlässig umbrochen werden.',
            ).join(' '),
            semanticRole: ParagraphRole.explanation,
            createdAt: now,
            updatedAt: now,
          ),
          QuoteBlock(
            id: 'oversized-quote',
            text: List.filled(
              55,
              'Dieses lange Zitat prüft den sicheren Seitenumbruch innerhalb '
              'eines einzigen Zitatblocks.',
            ).join(' '),
            author: 'Testautor',
            source: 'Testquelle',
            createdAt: now,
            updatedAt: now,
          ),
          NoteBlock(
            id: 'private-note',
            text: 'Diese interne Notiz gehört nur in den Notizen-Export.',
            visibility: NoteVisibility.editorOnly,
            depth: 1,
            marks: const [InlineMark(start: 6, end: 14, bold: true)],
            createdAt: now,
            updatedAt: now,
          ),
          for (var index = 0; index < 70; index++)
            NoteBlock(
              id: 'long-note-$index',
              text:
                  'Auch viele aufeinanderfolgende Notizen müssen mit ruhigen '
                  'Einzügen und zuverlässigen Seitenumbrüchen ausgegeben werden.',
              visibility: NoteVisibility.editorOnly,
              depth: index.isOdd ? 1 : 0,
              createdAt: now,
              updatedAt: now,
            ),
          NoteBlock(
            id: 'quick-note',
            text: 'Diese Quicknote darf nicht exportiert werden.',
            visibility: NoteVisibility.editorOnly,
            isQuickNote: true,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        presentation: const PresentationDeck(
          slides: [
            PresentationSlide(
              id: 'slide-1',
              template: PresentationSlideTemplate.headingText,
              title: 'Erste Folie',
              anchor: PresentationAnchor(
                view: PresentationAnchorView.script,
                blockId: 'paragraph',
                moduleId: 'legacy-script',
              ),
            ),
            PresentationSlide(
              id: 'slide-2',
              template: PresentationSlideTemplate.headingText,
              title: 'Zweite Folie',
              anchor: PresentationAnchor(
                view: PresentationAnchorView.script,
                blockId: 'heading',
                moduleId: 'legacy-script',
              ),
            ),
          ],
        ),
      ),
    );

    const exporter = SermonDocumentExporter();
    final scriptModule = sermon.document
        .modulesOfKind(SermonModuleKind.script)
        .first;
    final scriptAnchors = presentationAnchorsByBlockForModule(
      sermon.document,
      scriptModule.id,
    );
    expect(scriptAnchors['paragraph']!.single.number, 1);
    expect(scriptAnchors['heading']!.single.number, 2);
    final pdf = await exporter.buildPdf(sermon);
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');
    expect(pdf.length, greaterThan(10000));

    final word = exporter.buildWord(sermon);
    final archive = ZipDecoder().decodeBytes(word);
    String xml(String path) => utf8.decode(
      archive.findFile(path)!.readBytes()!,
    );
    final documentXml = xml('word/document.xml');
    final headerXml = xml('word/header1.xml');
    final footerXml = xml('word/footer1.xml');

    expect(documentXml, contains('<w:pgSz w:w="11906" w:h="16838"/>'));
    expect(documentXml, contains('w:bottom="1417"'));
    expect(documentXml, contains('Gott kommt uns nahe'));
    expect(documentXml, contains('<w:highlight w:val="yellow"/>'));
    expect(documentXml, isNot(contains('FOLIE 1')));
    expect(documentXml, isNot(contains('FOLIE 2')));
    expect(documentXml, isNot(contains('Diese interne Notiz')));
    expect(headerXml, contains('Gnade &amp; Wahrheit'));
    expect(headerXml, contains('Johannes 1,14–18'));
    expect(footerXml, contains(' PAGE '));
    expect(footerXml, contains(' NUMPAGES '));

    final notesPdf = await exporter.buildPdf(
      sermon,
      content: SermonExportContent.notes,
    );
    expect(ascii.decode(notesPdf.take(5).toList()), '%PDF-');
    expect(notesPdf.length, greaterThan(5000));

    final notesWord = exporter.buildWord(
      sermon,
      content: SermonExportContent.notes,
    );
    final notesArchive = ZipDecoder().decodeBytes(notesWord);
    final notesDocumentXml = utf8.decode(
      notesArchive.findFile('word/document.xml')!.readBytes()!,
    );
    final notesStylesXml = utf8.decode(
      notesArchive.findFile('word/styles.xml')!.readBytes()!,
    );
    expect(notesDocumentXml, contains('Gott kommt uns nahe'));
    expect(notesDocumentXml, contains('Notizen-Export'));
    expect(notesDocumentXml, contains('<w:pStyle w:val="Note2"/>'));
    expect(notesDocumentXml, contains('<w:b/>'));
    expect(notesDocumentXml, isNot(contains('Das Wort wurde Fleisch')));
    expect(notesDocumentXml, isNot(contains('Diese Quicknote')));
    expect(notesStylesXml, contains('w:styleId="Note1"'));
    expect(notesStylesXml, contains('w:styleId="Note2"'));
  });
}
