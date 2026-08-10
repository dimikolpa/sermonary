// OOXML fragments are deliberately split into adjacent literals without
// whitespace because inserted spaces can alter Word document content.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/domain/presentation_anchor_index.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

enum SermonExportContent { script, notes }

class SermonDocumentExporter {
  const SermonDocumentExporter();

  Future<Uint8List> buildPdf(
    Sermon sermon, {
    SermonExportContent content = SermonExportContent.script,
  }) async {
    final dmSans = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DMSans-Variable.ttf'),
    );
    final literata = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Literata-Variable.ttf'),
    );
    final literataItalic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Literata-Italic-Variable.ttf'),
    );
    final reference = sermon.primaryBibleReference?.displayText.trim() ?? '';
    final slideAnchors = _exportSlideAnchors(sermon, content);
    if (content == SermonExportContent.notes) {
      return _buildNotesPdf(
        sermon,
        reference,
        dmSans,
        literata,
        literataItalic,
        slideAnchors,
      );
    }
    final document =
        pw.Document(
          title: sermon.title,
          author: 'Sermonary',
          theme: pw.ThemeData.withFont(
            base: literata,
            bold: dmSans,
            italic: literataItalic,
          ),
        )..addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(
              22 * PdfPageFormat.mm,
              20 * PdfPageFormat.mm,
              22 * PdfPageFormat.mm,
              19 * PdfPageFormat.mm,
            ),
            header: (context) => pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              margin: const pw.EdgeInsets.only(bottom: 22),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      sermon.title,
                      maxLines: 2,
                      style: pw.TextStyle(
                        font: dmSans,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                  if (reference.isNotEmpty) ...[
                    pw.SizedBox(width: 18),
                    pw.Text(
                      reference,
                      style: pw.TextStyle(
                        font: literataItalic,
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            footer: (context) => pw.Container(
              padding: const pw.EdgeInsets.only(top: 8),
              margin: const pw.EdgeInsets.only(top: 14),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Seite ${context.pageNumber} von ${context.pagesCount}',
                style: pw.TextStyle(
                  font: dmSans,
                  fontSize: 8.5,
                  color: PdfColors.grey500,
                ),
              ),
            ),
            build: (context) => [
              if (sermon.subtitle.trim().isNotEmpty) ...[
                pw.RichText(
                  overflow: pw.TextOverflow.span,
                  text: pw.TextSpan(
                    text: sermon.subtitle.trim(),
                    style: pw.TextStyle(
                      font: literataItalic,
                      fontSize: 11,
                      lineSpacing: 3.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 22),
              ],
              for (final block in _exportBlocks(sermon, content)) ...[
                if (slideAnchors[block.id]?.isNotEmpty ?? false) ...[
                  _pdfSlideChangeMarker(slideAnchors[block.id]!, dmSans),
                  pw.SizedBox(height: 2),
                ],
                ...(block is NoteBlock
                    ? _pdfNoteBlock(
                        block,
                        dmSans,
                        literata,
                        literataItalic,
                      )
                    : _pdfBlock(block, dmSans, literata, literataItalic)),
              ],
            ],
          ),
        );
    return document.save();
  }

  Uint8List buildWord(
    Sermon sermon, {
    SermonExportContent content = SermonExportContent.script,
  }) {
    final reference = sermon.primaryBibleReference?.displayText.trim() ?? '';
    final body = StringBuffer();
    if (sermon.subtitle.trim().isNotEmpty) {
      body.write(
        _wordParagraph(
          _wordRuns(sermon.subtitle.trim(), const <InlineMark>[]),
          style: 'Subtitle',
        ),
      );
    }
    for (final block in _exportBlocks(sermon, content)) {
      body.write(_wordBlock(block));
    }
    body.write(
      '<w:sectPr>'
      '<w:headerReference w:type="default" r:id="rId1"/>'
      '<w:footerReference w:type="default" r:id="rId2"/>'
      '<w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="1134" w:right="1247" w:bottom="1417" '
      'w:left="1247" w:header="567" w:footer="567" w:gutter="0"/>'
      '</w:sectPr>',
    );

    final files = <String, String>{
      '[Content_Types].xml': _contentTypes,
      '_rels/.rels': _packageRelationships,
      'docProps/app.xml': _appProperties,
      'docProps/core.xml': _coreProperties(sermon.title),
      'word/document.xml': _xmlDocument(body.toString()),
      'word/styles.xml': _wordStyles,
      'word/_rels/document.xml.rels': _documentRelationships,
      'word/header1.xml': _wordHeader(sermon.title, reference),
      'word/footer1.xml': _wordFooter,
    };
    final archive = Archive();
    for (final entry in files.entries) {
      archive.add(ArchiveFile.string(entry.key, entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }
}

// Retained as an alternative paginator while PDF package updates are evaluated.
// ignore: unused_element
Future<Uint8List> _buildNotesPdfForeground(
  Sermon sermon,
  String reference,
  pw.Font dmSans,
  pw.Font literata,
  pw.Font literataItalic,
) async {
  final document =
      pw.Document(
        title: sermon.title,
        author: 'Sermonary',
        theme: pw.ThemeData.withFont(
          base: literata,
          bold: dmSans,
          italic: literataItalic,
        ),
      )..addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.fromLTRB(
              22 * PdfPageFormat.mm,
              35 * PdfPageFormat.mm,
              22 * PdfPageFormat.mm,
              28 * PdfPageFormat.mm,
            ),
            buildForeground: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Stack(
                children: [
                  pw.Positioned(
                    top: 20 * PdfPageFormat.mm,
                    right: 22 * PdfPageFormat.mm,
                    left: 22 * PdfPageFormat.mm,
                    child: _notesPdfHeader(
                      sermon.title,
                      reference,
                      dmSans,
                      literataItalic,
                    ),
                  ),
                  pw.Positioned(
                    right: 22 * PdfPageFormat.mm,
                    bottom: 19 * PdfPageFormat.mm,
                    left: 22 * PdfPageFormat.mm,
                    child: _notesPdfFooter(
                      context.pageNumber,
                      context.pagesCount,
                      dmSans,
                    ),
                  ),
                ],
              ),
            ),
          ),
          build: (context) => [
            if (sermon.subtitle.trim().isNotEmpty) ...[
              pw.RichText(
                overflow: pw.TextOverflow.span,
                text: pw.TextSpan(
                  text: sermon.subtitle.trim(),
                  style: pw.TextStyle(
                    font: literataItalic,
                    fontSize: 11,
                    lineSpacing: 3.5,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(height: 22),
            ],
            for (final block in _exportBlocks(
              sermon,
              SermonExportContent.notes,
            ))
              ...(block is NoteBlock
                  ? _pdfNoteBlock(
                      block,
                      dmSans,
                      literata,
                      literataItalic,
                    )
                  : _pdfBlock(block, dmSans, literata, literataItalic)),
          ],
        ),
      );
  return document.save();
}

Future<Uint8List> _buildNotesPdf(
  Sermon sermon,
  String reference,
  pw.Font dmSans,
  pw.Font literata,
  pw.Font literataItalic,
  Map<String, List<PresentationAnchorReference>> slideAnchors,
) async {
  // A note line uses a deliberately generous leading. Keep the logical page
  // capacity conservative so the fixed header and footer can never be pushed
  // outside the A4 content area by a densely filled page.
  const pageCapacity = 22.0;
  final pages = <List<pw.Widget Function()>>[<pw.Widget Function()>[]];
  final usedUnits = <double>[0];

  void nextPage() {
    pages.add(<pw.Widget Function()>[]);
    usedUnits.add(0);
  }

  void addWidget(pw.Widget Function() builder, double units) {
    if (usedUnits.last > 0 && usedUnits.last + units > pageCapacity) {
      nextPage();
    }
    pages.last.add(builder);
    usedUnits[usedUnits.length - 1] += units;
  }

  if (sermon.subtitle.trim().isNotEmpty) {
    addWidget(
      () => pw.RichText(
        text: pw.TextSpan(
          text: sermon.subtitle.trim(),
          style: pw.TextStyle(
            font: literataItalic,
            fontSize: 11,
            lineSpacing: 3.5,
            color: PdfColors.grey700,
          ),
        ),
      ),
      3.5,
    );
    addWidget(() => pw.SizedBox(height: 18), 1.2);
  }

  for (final block in _exportBlocks(sermon, SermonExportContent.notes)) {
    final anchors = slideAnchors[block.id] ?? const [];
    if (anchors.isNotEmpty) {
      addWidget(() => _pdfSlideChangeMarker(anchors, dmSans), 0.8);
      addWidget(() => pw.SizedBox(height: 2), 0.2);
    }
    if (block is HeadingBlock || block is TitleBlock) {
      final level = block is HeadingBlock ? block.level : 1;
      addWidget(
        () => pw.SizedBox(
          height: level == 1
              ? 22
              : level == 2
              ? 16
              : 12,
        ),
        1.4,
      );
      final estimatedLines = (block.plainText.length / 45).ceil().clamp(1, 4);
      addWidget(
        () => pw.RichText(
          text: pw.TextSpan(
            text: block.plainText,
            style: pw.TextStyle(
              font: dmSans,
              fontSize: level == 1
                  ? 18
                  : level == 2
                  ? 14.5
                  : 12.5,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 2.5,
            ),
          ),
        ),
        estimatedLines * 1.7,
      );
      addWidget(
        () => pw.SizedBox(height: level == 1 ? 8 : 5),
        0.5,
      );
      continue;
    }
    if (block is! NoteBlock) continue;
    final lines = _splitMarkedText(
      block.text,
      block.marks,
      maximumCharacters: 240,
    );
    final indentation = block.depth.clamp(0, 1) * 16.0;
    for (var index = 0; index < lines.length; index++) {
      addWidget(
        () => pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: indentation),
            pw.Expanded(
              child: pw.RichText(
                text: pw.TextSpan(
                  style: pw.TextStyle(
                    font: literata,
                    fontSize: 11.25,
                    lineSpacing: 3.5,
                    color: PdfColors.grey900,
                  ),
                  children: [
                    pw.TextSpan(
                      text: index == 0 ? '-  ' : '',
                      style: pw.TextStyle(
                        font: dmSans,
                        fontSize: 10.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                    ..._pdfSpans(
                      lines[index].text,
                      lines[index].marks,
                      literata,
                      dmSans,
                      literataItalic,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        (lines[index].text.length / 60).ceil().clamp(1, 5) * 1.25,
      );
    }
    addWidget(() => pw.SizedBox(height: 7), 0.6);
  }

  final document = pw.Document(
    title: sermon.title,
    author: 'Sermonary',
    theme: pw.ThemeData.withFont(
      base: literata,
      bold: dmSans,
      italic: literataItalic,
    ),
  );
  for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          22 * PdfPageFormat.mm,
          20 * PdfPageFormat.mm,
          22 * PdfPageFormat.mm,
          19 * PdfPageFormat.mm,
        ),
        build: (context) => pw.Stack(
          children: [
            pw.Positioned(
              top: 58,
              right: 0,
              bottom: 35,
              left: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (final builder in pages[pageIndex]) builder(),
                ],
              ),
            ),
            pw.Positioned(
              top: 0,
              right: 0,
              left: 0,
              child: _notesPdfHeader(
                sermon.title,
                reference,
                dmSans,
                literataItalic,
              ),
            ),
            pw.Positioned(
              right: 0,
              bottom: 0,
              left: 0,
              child: _notesPdfFooter(pageIndex + 1, pages.length, dmSans),
            ),
          ],
        ),
      ),
    );
  }
  return document.save();
}

pw.Widget _notesPdfHeader(
  String title,
  String reference,
  pw.Font dmSans,
  pw.Font literataItalic,
) => pw.Container(
  padding: const pw.EdgeInsets.only(bottom: 8),
  margin: const pw.EdgeInsets.only(bottom: 22),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
    ),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Expanded(
        child: pw.Text(
          title,
          maxLines: 2,
          style: pw.TextStyle(
            font: dmSans,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      ),
      if (reference.isNotEmpty) ...[
        pw.SizedBox(width: 18),
        pw.Text(
          reference,
          style: pw.TextStyle(
            font: literataItalic,
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
      ],
    ],
  ),
);

pw.Widget _notesPdfFooter(int page, int pageCount, pw.Font dmSans) =>
    pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      margin: const pw.EdgeInsets.only(top: 14),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Seite $page von $pageCount',
        style: pw.TextStyle(
          font: dmSans,
          fontSize: 8.5,
          color: PdfColors.grey500,
        ),
      ),
    );

Map<String, List<PresentationAnchorReference>> _exportSlideAnchors(
  Sermon sermon,
  SermonExportContent content,
) {
  final kind = content == SermonExportContent.notes
      ? SermonModuleKind.notes
      : SermonModuleKind.script;
  final module = sermon.document.modulesOfKind(kind).firstOrNull;
  if (module == null) return const {};
  return presentationAnchorsByBlockForModule(sermon.document, module.id);
}

pw.Widget _pdfSlideChangeMarker(
  List<PresentationAnchorReference> anchors,
  pw.Font dmSans,
) => pw.Align(
  alignment: pw.Alignment.centerRight,
  child: pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
    ),
    child: pw.Text(
      'FOLIE ${anchors.map((anchor) => anchor.number).join('·')}',
      style: pw.TextStyle(
        font: dmSans,
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
        color: PdfColors.grey600,
      ),
    ),
  ),
);

Iterable<DocumentBlock> _exportBlocks(
  Sermon sermon,
  SermonExportContent content,
) => switch (content) {
  SermonExportContent.script => sermon.document.blocks.where(
    (block) => block is! NoteBlock && block is! BulletListBlock,
  ),
  SermonExportContent.notes => sermon.document.blocks.where(
    (block) =>
        block is HeadingBlock || (block is NoteBlock && !block.isQuickNote),
  ),
};

List<InlineMark> _marksOf(DocumentBlock block) => switch (block) {
  ParagraphBlock(:final marks) => marks,
  QuoteBlock(:final marks) => marks,
  NoteBlock(:final marks) => marks,
  _ => const <InlineMark>[],
};

List<pw.Widget> _pdfNoteBlock(
  NoteBlock block,
  pw.Font dmSans,
  pw.Font literata,
  pw.Font literataItalic,
) {
  final chunks = _splitMarkedText(
    block.text,
    block.marks,
    maximumCharacters: 300,
  );
  return [
    for (var index = 0; index < chunks.length; index++)
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(
                  font: literata,
                  fontSize: 11.25,
                  lineSpacing: 3.5,
                  color: PdfColors.grey900,
                ),
                children: [
                  pw.TextSpan(
                    text: index == 0
                        ? block.depth == 0
                              ? '–  '
                              : '      –  '
                        : '',
                    style: pw.TextStyle(
                      font: dmSans,
                      fontSize: 10.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                  ..._pdfSpans(
                    chunks[index].text,
                    chunks[index].marks,
                    literata,
                    dmSans,
                    literataItalic,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    pw.SizedBox(height: 7),
  ];
}

List<pw.Widget> _pdfBlock(
  DocumentBlock block,
  pw.Font dmSans,
  pw.Font literata,
  pw.Font literataItalic,
) {
  if (block is HeadingBlock || block is TitleBlock) {
    final level = block is HeadingBlock ? block.level : 1;
    return [
      pw.SizedBox(
        height: level == 1
            ? 22
            : level == 2
            ? 16
            : 12,
      ),
      pw.RichText(
        overflow: pw.TextOverflow.span,
        text: pw.TextSpan(
          text: block.plainText,
          style: pw.TextStyle(
            font: dmSans,
            fontSize: level == 1
                ? 18
                : level == 2
                ? 14.5
                : 12.5,
            fontWeight: pw.FontWeight.bold,
            lineSpacing: 2.5,
          ),
        ),
      ),
      pw.SizedBox(height: level == 1 ? 8 : 5),
    ];
  }
  if (block is DividerBlock) {
    return [
      pw.SizedBox(height: 14),
      pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      pw.SizedBox(height: 14),
    ];
  }
  if (block is BibleQuoteBlock) {
    return _pdfQuote(
      '${block.text}\n${block.reference.displayText}',
      const <InlineMark>[],
      literata,
      dmSans,
      literataItalic,
    );
  }
  if (block is QuoteBlock) {
    final attribution = [
      block.author.trim(),
      block.source.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    return _pdfQuote(
      attribution.isEmpty ? block.text : '${block.text}\n$attribution',
      block.marks,
      literata,
      dmSans,
      literataItalic,
    );
  }
  return [
    pw.RichText(
      overflow: pw.TextOverflow.span,
      text: pw.TextSpan(
        style: pw.TextStyle(
          font: literata,
          fontSize: 11.5,
          lineSpacing: 4,
          color: PdfColors.grey900,
        ),
        children: _pdfSpans(
          block.plainText,
          _marksOf(block),
          literata,
          dmSans,
          literataItalic,
        ),
      ),
      textAlign: pw.TextAlign.left,
    ),
    pw.SizedBox(height: 9),
  ];
}

List<pw.Widget> _pdfQuote(
  String text,
  List<InlineMark> marks,
  pw.Font literata,
  pw.Font dmSans,
  pw.Font literataItalic,
) {
  final chunks = _splitMarkedText(text, marks);
  return [
    pw.SizedBox(height: 8),
    for (final chunk in chunks)
      pw.Container(
        padding: const pw.EdgeInsets.only(left: 13),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: PdfColors.grey400, width: 1.2),
          ),
        ),
        child: pw.RichText(
          text: pw.TextSpan(
            style: pw.TextStyle(
              font: literataItalic,
              fontSize: 11,
              lineSpacing: 4,
              color: PdfColors.grey700,
            ),
            children: _pdfSpans(
              chunk.text,
              chunk.marks,
              literata,
              dmSans,
              literataItalic,
              forceItalic: true,
            ),
          ),
        ),
      ),
    pw.SizedBox(height: 13),
  ];
}

List<_MarkedTextChunk> _splitMarkedText(
  String text,
  List<InlineMark> marks, {
  int maximumCharacters = 1200,
}) {
  if (text.isEmpty) {
    return const [_MarkedTextChunk('', <InlineMark>[])];
  }
  final chunks = <_MarkedTextChunk>[];
  var start = 0;
  while (start < text.length) {
    var end = (start + maximumCharacters).clamp(0, text.length);
    if (end < text.length) {
      final candidate = text.substring(start, end);
      final sentenceBreaks = RegExp(
        r'[.!?](?:\s|$)',
      ).allMatches(candidate).toList();
      final sentenceBreak = sentenceBreaks.isEmpty ? null : sentenceBreaks.last;
      final whitespace = candidate.lastIndexOf(RegExp(r'\s'));
      if (sentenceBreak != null &&
          sentenceBreak.end >= maximumCharacters ~/ 2) {
        end = start + sentenceBreak.end;
      } else if (whitespace >= maximumCharacters ~/ 2) {
        end = start + whitespace + 1;
      }
    }
    chunks.add(
      _MarkedTextChunk(
        text.substring(start, end),
        [
          for (final mark in marks)
            if (mark.end > start && mark.start < end)
              InlineMark(
                start: mark.start.clamp(start, end) - start,
                end: mark.end.clamp(start, end) - start,
                bold: mark.bold,
                italic: mark.italic,
                highlighted: mark.highlighted,
              ),
        ],
      ),
    );
    start = end;
  }
  return chunks;
}

class _MarkedTextChunk {
  const _MarkedTextChunk(this.text, this.marks);

  final String text;
  final List<InlineMark> marks;
}

List<pw.InlineSpan> _pdfSpans(
  String text,
  List<InlineMark> marks,
  pw.Font literata,
  pw.Font dmSans,
  pw.Font literataItalic, {
  bool forceItalic = false,
}) => [
  for (final segment in _segments(text, marks))
    pw.TextSpan(
      text: segment.text,
      style: pw.TextStyle(
        font: segment.bold
            ? dmSans
            : forceItalic || segment.italic
            ? literataItalic
            : literata,
        fontWeight: segment.bold ? pw.FontWeight.bold : null,
        fontStyle: forceItalic || segment.italic ? pw.FontStyle.italic : null,
        background: segment.highlighted
            ? const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFFE879))
            : null,
      ),
    ),
];

String _wordBlock(DocumentBlock block) {
  if (block is HeadingBlock || block is TitleBlock) {
    final level = block is HeadingBlock ? block.level.clamp(1, 3) : 1;
    return _wordParagraph(
      _wordRuns(block.plainText, const <InlineMark>[]),
      style: 'Heading$level',
    );
  }
  if (block is DividerBlock) {
    return '<w:p><w:pPr><w:spacing w:before="180" w:after="180"/>'
        '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="1" '
        'w:color="D6D3D1"/></w:pBdr></w:pPr></w:p>';
  }
  if (block is BibleQuoteBlock) {
    return _wordParagraph(
      _wordRuns(
        '${block.text}\n${block.reference.displayText}',
        const <InlineMark>[],
        italic: true,
      ),
      style: 'Quote',
    );
  }
  if (block is QuoteBlock) {
    final attribution = [
      block.author.trim(),
      block.source.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
    return _wordParagraph(
      _wordRuns(
        attribution.isEmpty ? block.text : '${block.text}\n$attribution',
        block.marks,
        italic: true,
      ),
      style: 'Quote',
    );
  }
  if (block is NoteBlock) {
    return _wordParagraph(
      '<w:r><w:rPr><w:color w:val="78716C"/></w:rPr><w:t>-</w:t></w:r>'
      '${_wordRuns(' ${block.text}', block.marks)}',
      style: block.depth == 0 ? 'Note1' : 'Note2',
    );
  }
  return _wordParagraph(_wordRuns(block.plainText, _marksOf(block)));
}

String _wordParagraph(String runs, {String? style}) =>
    '<w:p><w:pPr>${style == null ? '' : '<w:pStyle w:val="$style"/>'}'
    '</w:pPr>$runs</w:p>';

String _wordRuns(
  String text,
  List<InlineMark> marks, {
  bool italic = false,
}) => _segments(text, marks).map((segment) {
  final properties = StringBuffer();
  if (segment.bold) properties.write('<w:b/>');
  if (italic || segment.italic) properties.write('<w:i/>');
  if (segment.highlighted) properties.write('<w:highlight w:val="yellow"/>');
  final parts = segment.text.split('\n');
  final content = <String>[];
  for (var index = 0; index < parts.length; index++) {
    if (index > 0) content.add('<w:br/>');
    if (parts[index].isNotEmpty) {
      content.add('<w:t xml:space="preserve">${_xml(parts[index])}</w:t>');
    }
  }
  return '<w:r><w:rPr>$properties</w:rPr>${content.join()}</w:r>';
}).join();

List<_TextSegment> _segments(String text, List<InlineMark> marks) {
  if (text.isEmpty) return const <_TextSegment>[];
  final boundaries = <int>{0, text.length};
  for (final mark in marks) {
    boundaries
      ..add(mark.start.clamp(0, text.length))
      ..add(mark.end.clamp(0, text.length));
  }
  final sorted = boundaries.toList()..sort();
  return [
    for (var index = 0; index < sorted.length - 1; index++)
      if (sorted[index] < sorted[index + 1])
        _TextSegment(
          text.substring(sorted[index], sorted[index + 1]),
          bold: marks.any(
            (mark) =>
                mark.bold &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
          italic: marks.any(
            (mark) =>
                mark.italic &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
          highlighted: marks.any(
            (mark) =>
                mark.highlighted &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
        ),
  ];
}

class _TextSegment {
  const _TextSegment(
    this.text, {
    required this.bold,
    required this.italic,
    required this.highlighted,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool highlighted;
}

String _xml(String value) =>
    const HtmlEscape(HtmlEscapeMode.element).convert(value);

String _xmlDocument(String body) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
    'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
    '<w:body>$body</w:body></w:document>';

String _wordHeader(String title, String reference) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:p><w:pPr><w:tabs><w:tab w:val="right" w:pos="9412"/></w:tabs>'
    '<w:pBdr><w:bottom w:val="single" w:sz="4" w:space="6" w:color="D6D3D1"/>'
    '</w:pBdr></w:pPr>'
    '<w:r><w:rPr><w:b/><w:sz w:val="19"/><w:color w:val="44403C"/></w:rPr>'
    '<w:t>${_xml(title)}</w:t></w:r>'
    '${reference.isEmpty ? '' : '<w:r><w:tab/></w:r><w:r><w:rPr><w:i/><w:sz w:val="18"/><w:color w:val="78716C"/></w:rPr><w:t>${_xml(reference)}</w:t></w:r>'}'
    '</w:p></w:hdr>';

const _wordFooter =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:p><w:pPr><w:jc w:val="right"/><w:pBdr><w:top w:val="single" '
    'w:sz="4" w:space="6" w:color="D6D3D1"/></w:pBdr></w:pPr>'
    '<w:r><w:rPr><w:sz w:val="17"/><w:color w:val="A8A29E"/></w:rPr>'
    '<w:t xml:space="preserve">Seite </w:t></w:r>'
    '<w:fldSimple w:instr=" PAGE "><w:r><w:rPr><w:sz w:val="17"/></w:rPr>'
    '<w:t>1</w:t></w:r></w:fldSimple>'
    '<w:r><w:rPr><w:sz w:val="17"/><w:color w:val="A8A29E"/></w:rPr>'
    '<w:t xml:space="preserve"> von </w:t></w:r>'
    '<w:fldSimple w:instr=" NUMPAGES "><w:r><w:rPr><w:sz w:val="17"/></w:rPr>'
    '<w:t>1</w:t></w:r></w:fldSimple></w:p></w:ftr>';

const _wordStyles =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
    '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
    '<w:name w:val="Normal"/><w:pPr><w:spacing w:after="120" w:line="300" '
    'w:lineRule="auto"/></w:pPr><w:rPr><w:rFonts w:ascii="Georgia" '
    'w:hAnsi="Georgia"/><w:sz w:val="23"/><w:color w:val="292524"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/>'
    '<w:basedOn w:val="Normal"/><w:pPr><w:spacing w:after="300"/></w:pPr>'
    '<w:rPr><w:i/><w:sz w:val="22"/><w:color w:val="78716C"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/>'
    '<w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="360" w:after="180"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="36"/>'
    '<w:color w:val="1C1917"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading2"><w:name w:val="heading 2"/>'
    '<w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="280" w:after="120"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="29"/>'
    '<w:color w:val="292524"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Heading3"><w:name w:val="heading 3"/>'
    '<w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/>'
    '<w:pPr><w:keepNext/><w:spacing w:before="220" w:after="100"/></w:pPr>'
    '<w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial"/><w:b/><w:sz w:val="25"/>'
    '<w:color w:val="44403C"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/>'
    '<w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="360"/>'
    '<w:spacing w:before="120" w:after="180"/><w:pBdr><w:left w:val="single" '
    'w:sz="12" w:space="10" w:color="A8A29E"/></w:pBdr></w:pPr>'
    '<w:rPr><w:i/><w:color w:val="57534E"/></w:rPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Note1"><w:name w:val="Note 1"/>'
    '<w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="360" w:hanging="240"/>'
    '<w:spacing w:after="90"/></w:pPr></w:style>'
    '<w:style w:type="paragraph" w:styleId="Note2"><w:name w:val="Note 2"/>'
    '<w:basedOn w:val="Normal"/><w:pPr><w:ind w:left="720" w:hanging="240"/>'
    '<w:spacing w:after="90"/></w:pPr></w:style>'
    '</w:styles>';

const _contentTypes =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
    '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
    '<Default Extension="xml" ContentType="application/xml"/>'
    '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
    '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
    '<Override PartName="/word/header1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml"/>'
    '<Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>'
    '<Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
    '<Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
    '</Types>';

const _packageRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>'
    '</Relationships>';

const _documentRelationships =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
    '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/header" Target="header1.xml"/>'
    '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>'
    '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
    '</Relationships>';

const _appProperties =
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
    'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
    '<Application>Sermonary</Application></Properties>';

String _coreProperties(String title) {
  final timestamp = DateTime.now().toUtc().toIso8601String();
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>${_xml(title)}</dc:title><dc:creator>Sermonary</dc:creator>'
      '<cp:lastModifiedBy>Sermonary</cp:lastModifiedBy>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">$timestamp</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">$timestamp</dcterms:modified>'
      '</cp:coreProperties>';
}
