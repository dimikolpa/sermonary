// OOXML fragments intentionally use adjacent strings without whitespace.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/domain/presentation_text_formatting.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class PresentationExporter {
  const PresentationExporter();

  Future<Uint8List> buildPdf(Sermon sermon) async {
    final dmSans = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DMSans-Variable.ttf'),
    );
    final literata = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Literata-Variable.ttf'),
    );
    final literataItalic = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Literata-Italic-Variable.ttf'),
    );
    final document = pw.Document(title: '${sermon.title} – Präsentation');
    for (final slide in sermon.document.presentation.slides) {
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(
            13.333 * PdfPageFormat.inch,
            7.5 * PdfPageFormat.inch,
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => _pdfSlide(slide, dmSans, literata, literataItalic),
        ),
      );
    }
    return document.save();
  }

  Future<Uint8List> buildPowerPoint(Sermon sermon) async {
    final slides = sermon.document.presentation.slides;
    final templateData = await rootBundle.load(
      'assets/presentation/blank_widescreen.pptx',
    );
    final template = ZipDecoder().decodeBytes(
      templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      ),
    );
    final archive = Archive();
    final imageParts = <int, _PptxImage>{};
    for (var index = 0; index < slides.length; index++) {
      final path = slides[index].imagePath;
      if (path == null || !File(path).existsSync()) continue;
      final extension = path.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
      imageParts[index + 1] = _PptxImage(
        extension: extension,
        bytes: File(path).readAsBytesSync(),
      );
    }
    for (final file in template.files.where((file) => file.isFile)) {
      final name = file.name;
      if (RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(name) ||
          RegExp(r'^ppt/slides/_rels/slide\d+\.xml\.rels$').hasMatch(name)) {
        continue;
      }
      final source = file.readBytes()!;
      final bytes = switch (name) {
        'ppt/presentation.xml' => utf8.encode(
          _patchPresentationXml(utf8.decode(source), slides.length),
        ),
        'ppt/_rels/presentation.xml.rels' => utf8.encode(
          _patchPresentationRelationships(utf8.decode(source), slides.length),
        ),
        '[Content_Types].xml' => utf8.encode(
          _ensureImageContentTypes(
            _patchContentTypes(utf8.decode(source), slides.length),
          ),
        ),
        'docProps/app.xml' => utf8.encode(
          _patchAppProperties(utf8.decode(source), slides.length),
        ),
        'docProps/core.xml' => utf8.encode(
          _patchCoreProperties(utf8.decode(source), sermon.title),
        ),
        _ => source,
      };
      archive.add(ArchiveFile(name, bytes.length, bytes));
    }
    for (var index = 0; index < slides.length; index++) {
      final number = index + 1;
      archive
        ..add(
          ArchiveFile.string(
            'ppt/slides/slide$number.xml',
            _slideXml(slides[index], imageParts.containsKey(number)),
          ),
        )
        ..add(
          ArchiveFile.string(
            'ppt/slides/_rels/slide$number.xml.rels',
            _slideRels(
              number,
              imageParts.containsKey(number),
              imageParts[number]?.extension,
            ),
          ),
        );
    }
    for (final entry in imageParts.entries) {
      archive.add(
        ArchiveFile(
          'ppt/media/image${entry.key}.${entry.value.extension == 'png' ? 'png' : 'jpg'}',
          entry.value.bytes.length,
          entry.value.bytes,
        ),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  Future<Uint8List> buildImagePowerPoint(
    Sermon sermon,
    List<Uint8List> renderedSlides,
  ) async {
    final slides = sermon.document.presentation.slides;
    if (renderedSlides.length != slides.length) {
      throw ArgumentError(
        'Für jede Folie muss genau ein gerendertes Bild vorhanden sein.',
      );
    }
    final templateData = await rootBundle.load(
      'assets/presentation/blank_widescreen.pptx',
    );
    final template = ZipDecoder().decodeBytes(
      templateData.buffer.asUint8List(
        templateData.offsetInBytes,
        templateData.lengthInBytes,
      ),
    );
    final archive = Archive();
    for (final file in template.files.where((file) => file.isFile)) {
      final name = file.name;
      if (RegExp(r'^ppt/slides/slide\d+\.xml$').hasMatch(name) ||
          RegExp(r'^ppt/slides/_rels/slide\d+\.xml\.rels$').hasMatch(name)) {
        continue;
      }
      final source = file.readBytes()!;
      final bytes = switch (name) {
        'ppt/presentation.xml' => utf8.encode(
          _patchPresentationXml(utf8.decode(source), slides.length),
        ),
        'ppt/_rels/presentation.xml.rels' => utf8.encode(
          _patchPresentationRelationships(utf8.decode(source), slides.length),
        ),
        '[Content_Types].xml' => utf8.encode(
          _ensureImageContentTypes(
            _patchContentTypes(utf8.decode(source), slides.length),
          ),
        ),
        'docProps/app.xml' => utf8.encode(
          _patchAppProperties(utf8.decode(source), slides.length),
        ),
        'docProps/core.xml' => utf8.encode(
          _patchCoreProperties(utf8.decode(source), sermon.title),
        ),
        _ => source,
      };
      archive.add(ArchiveFile(name, bytes.length, bytes));
    }
    for (var index = 0; index < slides.length; index++) {
      final number = index + 1;
      archive
        ..add(
          ArchiveFile.string(
            'ppt/slides/slide$number.xml',
            _slideXml(
              PresentationSlide(
                id: 'rendered-$number',
                template: PresentationSlideTemplate.image,
              ),
              true,
            ),
          ),
        )
        ..add(
          ArchiveFile.string(
            'ppt/slides/_rels/slide$number.xml.rels',
            _slideRels(number, true, 'png'),
          ),
        )
        ..add(
          ArchiveFile(
            'ppt/media/image$number.png',
            renderedSlides[index].length,
            renderedSlides[index],
          ),
        );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  pw.Widget _pdfSlide(
    PresentationSlide slide,
    pw.Font sans,
    pw.Font serif,
    pw.Font italic,
  ) {
    final image = slide.imagePath != null && File(slide.imagePath!).existsSync()
        ? pw.MemoryImage(File(slide.imagePath!).readAsBytesSync())
        : null;
    const foreground = PdfColor.fromInt(0xFF23221F);
    return pw.Container(
      // Transparent image pixels reveal Sermonary's warm slide background.
      // Opaque photographs continue to cover it completely.
      color: const PdfColor.fromInt(0xFFFDFCF9),
      child: pw.Stack(
        fit: pw.StackFit.expand,
        children: [
          if (image != null &&
              slide.template == PresentationSlideTemplate.image)
            pw.Image(image, fit: pw.BoxFit.cover),
          pw.Padding(
            padding: const pw.EdgeInsets.all(54),
            child: _pdfContent(
              slide,
              sans,
              serif,
              italic,
              foreground,
              image,
            ),
          ),
          if (slide.continuationCount > 1)
            pw.Positioned(
              right: 34,
              bottom: 25,
              child: pw.Text(
                '${slide.continuationIndex}/${slide.continuationCount}',
                style: pw.TextStyle(
                  font: sans,
                  fontSize: 10,
                  color: foreground.shade(.45),
                ),
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _pdfContent(
    PresentationSlide slide,
    pw.Font sans,
    pw.Font serif,
    pw.Font italic,
    PdfColor color,
    pw.MemoryImage? image,
  ) => switch (slide.template) {
    PresentationSlideTemplate.title => pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (slide.title.trim().isNotEmpty)
            _pdfMarkedText(
              slide.title,
              slide.titleMarks,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: sans,
                fontSize: 38,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 3,
                color: color,
              ),
            ),
          if (slide.title.trim().isNotEmpty && slide.subtitle.trim().isNotEmpty)
            pw.SizedBox(height: 20),
          if (slide.subtitle.trim().isNotEmpty)
            pw.Row(
              children: [
                pw.Expanded(child: pw.Divider(color: color.shade(.25))),
                pw.SizedBox(width: 16),
                _pdfMarkedText(
                  slide.subtitle,
                  slide.subtitleMarks,
                  style: pw.TextStyle(
                    font: italic,
                    fontSize: 17,
                    lineSpacing: 4,
                    color: color.shade(.68),
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(child: pw.Divider(color: color.shade(.25))),
              ],
            ),
        ],
      ),
    ),
    PresentationSlideTemplate.headingText => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _pdfMarkedText(
            slide.title,
            slide.titleMarks,
            style: pw.TextStyle(
              font: sans,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 3,
              color: color,
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Divider(color: color.shade(.25)),
          pw.SizedBox(height: 22),
        ],
        if (slide.body.trim().isNotEmpty)
          _pdfMarkedText(
            slide.body,
            slide.bodyMarks,
            style: pw.TextStyle(
              font: serif,
              fontSize: 18,
              lineSpacing: 7,
              color: color.shade(.82),
            ),
          ),
      ],
    ),
    PresentationSlideTemplate.headingBible => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _pdfMarkedText(
            slide.title,
            slide.titleMarks,
            style: pw.TextStyle(
              font: sans,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 3,
              color: color,
            ),
          ),
          pw.SizedBox(height: 28),
        ],
        pw.Container(
          padding: const pw.EdgeInsets.only(left: 22),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: color.shade(.32), width: 2),
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (slide.body.trim().isNotEmpty)
                _pdfMarkedText(
                  slide.body,
                  slide.bodyMarks,
                  style: pw.TextStyle(
                    font: italic,
                    fontSize: 19,
                    lineSpacing: 8,
                    color: color.shade(.82),
                  ),
                ),
              if (slide.body.trim().isNotEmpty &&
                  slide.reference.trim().isNotEmpty)
                pw.SizedBox(height: 16),
              if (slide.reference.trim().isNotEmpty)
                _pdfMarkedText(
                  slide.reference,
                  slide.referenceMarks,
                  style: pw.TextStyle(
                    font: sans,
                    fontSize: 12,
                    lineSpacing: 3,
                    color: color.shade(.58),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    PresentationSlideTemplate.contents => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _pdfMarkedText(
            slide.title,
            slide.titleMarks,
            style: pw.TextStyle(
              font: sans,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 3,
              color: color,
            ),
          ),
          pw.SizedBox(height: 28),
        ],
        for (
          var index = 0;
          index < presentationVisibleItems(slide.items, slide.itemMarks).length;
          index++
        )
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 15),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 45,
                  child: pw.Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: pw.TextStyle(
                      font: sans,
                      fontSize: 12,
                      color: color.shade(.42),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: _pdfMarkedText(
                    presentationVisibleItems(
                      slide.items,
                      slide.itemMarks,
                    )[index].text,
                    presentationVisibleItems(
                      slide.items,
                      slide.itemMarks,
                    )[index].marks,
                    style: pw.TextStyle(
                      font: serif,
                      fontSize: 18,
                      lineSpacing: 5,
                      color: color.shade(.82),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    PresentationSlideTemplate.largeContents => pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (
            var index = 0;
            index <
                    presentationVisibleItems(
                      slide.items,
                      slide.itemMarks,
                    ).length &&
                index < 5;
            index++
          )
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 48,
                    child: pw.Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: pw.TextStyle(
                        font: sans,
                        fontSize: 14,
                        color: color.shade(.42),
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: _pdfMarkedText(
                      presentationVisibleItems(
                        slide.items,
                        slide.itemMarks,
                      )[index].text,
                      presentationVisibleItems(
                        slide.items,
                        slide.itemMarks,
                      )[index].marks,
                      style: pw.TextStyle(
                        font: sans,
                        fontSize: 27,
                        fontWeight: pw.FontWeight.bold,
                        lineSpacing: 4,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    PresentationSlideTemplate.headingImage => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _pdfMarkedText(
            slide.title,
            slide.titleMarks,
            style: pw.TextStyle(
              font: sans,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 3,
              color: color,
            ),
          ),
          pw.SizedBox(height: 22),
        ],
        pw.Expanded(child: _pdfImageFrame(image, color)),
      ],
    ),
    PresentationSlideTemplate.headingImageBible => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _pdfMarkedText(
            slide.title,
            slide.titleMarks,
            style: pw.TextStyle(
              font: sans,
              fontSize: 30,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 3,
              color: color,
            ),
          ),
          pw.SizedBox(height: 26),
        ],
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: _pdfImageFrame(image, color)),
              pw.SizedBox(width: 28),
              pw.Expanded(
                flex: 2,
                child: pw.Container(
                  padding: const pw.EdgeInsets.only(left: 20),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(
                      left: pw.BorderSide(color: color.shade(.32), width: 2),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (slide.body.trim().isNotEmpty)
                        _pdfMarkedText(
                          slide.body,
                          slide.bodyMarks,
                          style: pw.TextStyle(
                            font: italic,
                            fontSize: 17,
                            lineSpacing: 8,
                            color: color.shade(.82),
                          ),
                        ),
                      if (slide.body.trim().isNotEmpty &&
                          slide.reference.trim().isNotEmpty)
                        pw.SizedBox(height: 15),
                      if (slide.reference.trim().isNotEmpty)
                        _pdfMarkedText(
                          slide.reference,
                          slide.referenceMarks,
                          style: pw.TextStyle(
                            font: sans,
                            fontSize: 11,
                            lineSpacing: 3,
                            color: color.shade(.58),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    PresentationSlideTemplate.image => pw.Align(
      alignment: pw.Alignment.bottomLeft,
      child: slide.caption.trim().isEmpty
          ? pw.SizedBox()
          : pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              color: PdfColors.black.shade(.45),
              child: _pdfMarkedText(
                slide.caption,
                slide.captionMarks,
                style: pw.TextStyle(
                  font: sans,
                  fontSize: 16,
                  lineSpacing: 4,
                  color: PdfColors.white,
                ),
              ),
            ),
    ),
  };
}

pw.Widget _pdfImageFrame(pw.MemoryImage? image, PdfColor color) => pw.Container(
  decoration: pw.BoxDecoration(
    color: const PdfColor.fromInt(0xFFF4F2EC),
    border: pw.Border.all(color: color.shade(.14), width: .6),
  ),
  child: image == null ? pw.SizedBox() : pw.Image(image, fit: pw.BoxFit.cover),
);

pw.Widget _pdfMarkedText(
  String text,
  List<InlineMark> marks, {
  required pw.TextStyle style,
  pw.TextAlign? textAlign,
  int? maxLines,
}) => pw.RichText(
  textAlign: textAlign,
  maxLines: maxLines,
  text: pw.TextSpan(
    style: style,
    children: [
      for (final segment in presentationTextSegments(text, marks))
        pw.TextSpan(
          text: segment.text,
          style: style.copyWith(
            fontWeight: segment.bold ? pw.FontWeight.bold : null,
            fontStyle: segment.italic ? pw.FontStyle.italic : null,
            background: segment.highlighted
                ? const pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFFFFE36A),
                  )
                : null,
          ),
        ),
    ],
  ),
);

class _PptxImage {
  const _PptxImage({required this.extension, required this.bytes});
  final String extension;
  final Uint8List bytes;
}

String _x(String value) =>
    const HtmlEscape().convert(value).replaceAll('\n', '&#10;');

String _textShape(
  String text,
  List<InlineMark> marks,
  int id,
  int x,
  int y,
  int cx,
  int cy, {
  int size = 2400,
  bool bold = false,
  bool italic = false,
  String color = '23221F',
  String align = 'l',
}) {
  if (text.trim().isEmpty) return '';
  final runs = presentationTextSegments(text, marks).map((segment) {
    final runBold = bold || segment.bold;
    final runItalic = italic || segment.italic;
    final highlight = segment.highlighted
        ? '<a:highlight><a:srgbClr val="FFE36A"/></a:highlight>'
        : '';
    return '<a:r><a:rPr lang="de-DE" sz="$size" b="${runBold ? 1 : 0}" i="${runItalic ? 1 : 0}"><a:solidFill><a:srgbClr val="$color"/></a:solidFill>$highlight<a:latin typeface="DM Sans"/></a:rPr><a:t>${_x(segment.text)}</a:t></a:r>';
  }).join();
  return '<p:sp><p:nvSpPr><p:cNvPr id="$id" name="Text $id"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>'
      '<p:spPr><a:xfrm><a:off x="$x" y="$y"/><a:ext cx="$cx" cy="$cy"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:noFill/></p:spPr>'
      '<p:txBody><a:bodyPr wrap="square"/><a:lstStyle/><a:p><a:pPr algn="$align"><a:lnSpc><a:spcPct val="115000"/></a:lnSpc></a:pPr>$runs<a:endParaRPr lang="de-DE"/></a:p></p:txBody></p:sp>';
}

String _slideXml(PresentationSlide slide, bool hasImage) {
  final shapes = StringBuffer();
  if (hasImage) {
    final imageGeometry = switch (slide.template) {
      PresentationSlideTemplate.headingImage => (
        x: 850000,
        y: 1750000,
        cx: 10492000,
        cy: 4350000,
      ),
      PresentationSlideTemplate.headingImageBible => (
        x: 850000,
        y: 1800000,
        cx: 3300000,
        cy: 3900000,
      ),
      _ => (x: 0, y: 0, cx: 12192000, cy: 6858000),
    };
    shapes.write(
      '<p:pic><p:nvPicPr><p:cNvPr id="2" name="Bild"/><p:cNvPicPr/><p:nvPr/></p:nvPicPr><p:blipFill><a:blip r:embed="rId2"/><a:stretch><a:fillRect/></a:stretch></p:blipFill><p:spPr><a:xfrm><a:off x="${imageGeometry.x}" y="${imageGeometry.y}"/><a:ext cx="${imageGeometry.cx}" cy="${imageGeometry.cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></p:spPr></p:pic>',
    );
  }
  var id = hasImage ? 3 : 2;
  switch (slide.template) {
    case PresentationSlideTemplate.title:
      shapes
        ..write(
          _textShape(
            slide.title,
            slide.titleMarks,
            id++,
            900000,
            2200000,
            10392000,
            1100000,
            size: 3400,
            bold: true,
            align: 'ctr',
          ),
        )
        ..write(
          _textShape(
            slide.subtitle,
            slide.subtitleMarks,
            id++,
            2500000,
            3550000,
            7192000,
            600000,
            size: 1500,
            italic: true,
            color: '77736B',
            align: 'ctr',
          ),
        );
    case PresentationSlideTemplate.headingText:
      shapes
        ..write(
          _textShape(
            slide.title,
            slide.titleMarks,
            id++,
            850000,
            700000,
            10492000,
            900000,
            size: 2800,
            bold: true,
          ),
        )
        ..write(
          _textShape(
            slide.body,
            slide.bodyMarks,
            id++,
            850000,
            1900000,
            10492000,
            3800000,
            size: 1700,
            color: '56534D',
          ),
        );
    case PresentationSlideTemplate.headingBible:
      shapes
        ..write(
          _textShape(
            slide.title,
            slide.titleMarks,
            id++,
            850000,
            700000,
            10492000,
            900000,
            size: 2800,
            bold: true,
          ),
        )
        ..write(
          _textShape(
            slide.body,
            slide.bodyMarks,
            id++,
            1150000,
            1900000,
            9800000,
            3000000,
            size: 1800,
            italic: true,
            color: '56534D',
          ),
        )
        ..write(
          _textShape(
            slide.reference,
            slide.referenceMarks,
            id++,
            1150000,
            5050000,
            9800000,
            500000,
            size: 1100,
            color: '77736B',
          ),
        );
    case PresentationSlideTemplate.contents:
      shapes.write(
        _textShape(
          slide.title,
          slide.titleMarks,
          id++,
          850000,
          700000,
          10492000,
          900000,
          size: 2800,
          bold: true,
        ),
      );
      final items = presentationVisibleItems(slide.items, slide.itemMarks);
      for (var index = 0; index < items.length && index < 6; index++) {
        shapes
          ..write(
            _textShape(
              '${index + 1}'.padLeft(2, '0'),
              const [],
              id++,
              1000000,
              1850000 + index * 620000,
              600000,
              450000,
              size: 1100,
              color: '9A968E',
            ),
          )
          ..write(
            _textShape(
              items[index].text,
              items[index].marks,
              id++,
              1750000,
              1800000 + index * 620000,
              9000000,
              520000,
              size: 1700,
              color: '56534D',
            ),
          );
      }
    case PresentationSlideTemplate.largeContents:
      final largeItems = presentationVisibleItems(
        slide.items,
        slide.itemMarks,
      ).take(5).toList(growable: false);
      final startY = 1300000 + (5 - largeItems.length) * 300000;
      for (var index = 0; index < largeItems.length; index++) {
        shapes
          ..write(
            _textShape(
              '${index + 1}'.padLeft(2, '0'),
              const [],
              id++,
              850000,
              startY + index * 900000,
              650000,
              650000,
              size: 1400,
              color: '9A968E',
            ),
          )
          ..write(
            _textShape(
              largeItems[index].text,
              largeItems[index].marks,
              id++,
              1550000,
              startY - 50000 + index * 900000,
              9600000,
              750000,
              size: 2500,
              bold: true,
            ),
          );
      }
    case PresentationSlideTemplate.headingImage:
      shapes.write(
        _textShape(
          slide.title,
          slide.titleMarks,
          id++,
          850000,
          700000,
          10492000,
          900000,
          size: 2800,
          bold: true,
        ),
      );
    case PresentationSlideTemplate.headingImageBible:
      shapes
        ..write(
          _textShape(
            slide.title,
            slide.titleMarks,
            id++,
            850000,
            700000,
            10492000,
            900000,
            size: 2800,
            bold: true,
          ),
        )
        ..write(
          _textShape(
            slide.body,
            slide.bodyMarks,
            id++,
            4600000,
            1850000,
            6500000,
            2900000,
            size: 1650,
            italic: true,
            color: '56534D',
          ),
        )
        ..write(
          _textShape(
            slide.reference,
            slide.referenceMarks,
            id++,
            4600000,
            4900000,
            6500000,
            500000,
            size: 1050,
            color: '77736B',
          ),
        );
    case PresentationSlideTemplate.image:
      if (slide.caption.isNotEmpty) {
        shapes.write(
          _textShape(
            slide.caption,
            slide.captionMarks,
            id++,
            650000,
            5900000,
            10892000,
            500000,
            size: 1400,
            bold: true,
            color: 'FFFFFF',
          ),
        );
      }
  }
  if (slide.continuationCount > 1) {
    shapes.write(
      _textShape(
        '${slide.continuationIndex}/${slide.continuationCount}',
        const [],
        id++,
        11200000,
        6250000,
        500000,
        300000,
        size: 900,
        color: '99958D',
        align: 'r',
      ),
    );
  }
  return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">'
      '<p:cSld><p:bg><p:bgPr><a:solidFill><a:srgbClr val="FDFCF9"/></a:solidFill><a:effectLst/></p:bgPr></p:bg>'
      '<p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>$shapes</p:spTree></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sld>';
}

String _slideRels(int slideNumber, bool hasImage, String? extension) =>
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/>${hasImage ? '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/image$slideNumber.${extension == 'png' ? 'png' : 'jpg'}"/>' : ''}</Relationships>';

String _patchPresentationXml(String source, int count) {
  final slideIds =
      '<p:sldIdLst>${[
        for (var index = 0; index < count; index++) '<p:sldId id="${256 + index}" r:id="Rsermonary${index + 1}" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" />',
      ].join()}</p:sldIdLst>';
  return source.replaceFirst(
    RegExp('<p:sldIdLst>.*?</p:sldIdLst>', dotAll: true),
    slideIds,
  );
}

String _patchPresentationRelationships(String source, int count) {
  final withoutSlides = source.replaceAll(
    RegExp(
      r'<Relationship\b(?=[^>]*Type="http://schemas\.openxmlformats\.org/officeDocument/2006/relationships/slide")[^>]*/>',
    ),
    '',
  );
  final slideRelationships = [
    for (var index = 0; index < count; index++)
      '<Relationship Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="/ppt/slides/slide${index + 1}.xml" Id="Rsermonary${index + 1}" />',
  ].join();
  return withoutSlides.replaceFirst(
    '</Relationships>',
    '$slideRelationships</Relationships>',
  );
}

String _patchContentTypes(String source, int count) {
  final withoutSlides = source.replaceAll(
    RegExp(r'<Override\b(?=[^>]*PartName="/ppt/slides/slide\d+\.xml")[^>]*/>'),
    '',
  );
  final overrides = [
    for (var index = 1; index <= count; index++)
      '<Override PartName="/ppt/slides/slide$index.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml" />',
  ].join();
  return withoutSlides.replaceFirst('</Types>', '$overrides</Types>');
}

String _ensureImageContentTypes(String source) {
  var result = source;
  if (!RegExp(
    r'<Default\b[^>]*Extension="png"',
    caseSensitive: false,
  ).hasMatch(result)) {
    result = result.replaceFirst(
      '</Types>',
      '<Default Extension="png" ContentType="image/png" /></Types>',
    );
  }
  if (!RegExp(
    r'<Default\b[^>]*Extension="(?:jpg|jpeg)"',
    caseSensitive: false,
  ).hasMatch(result)) {
    result = result.replaceFirst(
      '</Types>',
      '<Default Extension="jpg" ContentType="image/jpeg" /></Types>',
    );
  }
  return result;
}

String _patchAppProperties(String source, int count) => source.replaceFirst(
  RegExp(r'<Slides>\d+</Slides>'),
  '<Slides>$count</Slides>',
);

String _patchCoreProperties(String source, String title) {
  final safeTitle = _x(title);
  if (source.contains('<dc:title>')) {
    return source.replaceFirst(
      RegExp('<dc:title>.*?</dc:title>', dotAll: true),
      '<dc:title>$safeTitle</dc:title>',
    );
  }
  return source.replaceFirst(
    '</cp:coreProperties>',
    '<dc:title>$safeTitle</dc:title></cp:coreProperties>',
  );
}
