import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class PrintModeScreen extends ConsumerWidget {
  const PrintModeScreen({required this.sermonId, super.key});

  final String sermonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(sermonProvider(sermonId))
      .when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 1)),
        ),
        error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
        data: (sermon) => sermon == null
            ? const Scaffold(
                body: Center(child: Text('Eintrag nicht gefunden.')),
              )
            : Scaffold(
                appBar: AppBar(
                  leading: IconButton(
                    tooltip: 'Print-Ansicht verlassen',
                    onPressed: () => context.go('/sermons/${sermon.id}/script'),
                    icon: const Icon(LucideIcons.x, size: 17),
                  ),
                  title: Text(sermon.title),
                ),
                body: PdfPreview(
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: '${sermon.title}.pdf',
                  build: (format) => _buildPdf(
                    format,
                    title: sermon.title,
                    subtitle: sermon.subtitle,
                    blocks: sermon.document.blocks,
                  ),
                ),
              ),
      );
}

Future<Uint8List> _buildPdf(
  PdfPageFormat format, {
  required String title,
  required String subtitle,
  required List<DocumentBlock> blocks,
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
  final document =
      pw.Document(
        theme: pw.ThemeData.withFont(
          base: literata,
          bold: dmSans,
          italic: literataItalic,
        ),
      )..addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.fromLTRB(64, 64, 64, 72),
          build: (context) => [
            pw.Text(
              title,
              style: pw.TextStyle(
                font: dmSans,
                fontSize: 30,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 4,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                subtitle,
                style: pw.TextStyle(
                  font: literataItalic,
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 32),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 24),
            for (final block in blocks)
              if (block is! NoteBlock && block is! BulletListBlock)
                _pdfBlock(block, dmSans, literata, literataItalic),
          ],
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              '${context.pageNumber}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ),
        ),
      );
  return document.save();
}

pw.Widget _pdfBlock(
  DocumentBlock block,
  pw.Font dmSans,
  pw.Font literata,
  pw.Font literataItalic,
) {
  if (block is HeadingBlock) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(
        top: block.level == 1 ? 28 : 18,
        bottom: 8,
      ),
      child: pw.Text(
        block.text,
        style: pw.TextStyle(
          font: dmSans,
          fontSize: block.level == 1 ? 20 : 15,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }
  if (block is QuoteBlock) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 12),
      padding: const pw.EdgeInsets.only(left: 16),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Text(
        block.text,
        style: pw.TextStyle(
          font: literataItalic,
          fontSize: 11.5,
          lineSpacing: 5,
          color: PdfColors.grey700,
        ),
      ),
    );
  }
  if (block is BibleQuoteBlock) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Text(
        '${block.text}\n— ${block.reference.displayText}',
        style: pw.TextStyle(
          font: literataItalic,
          fontSize: 11.5,
          lineSpacing: 5,
        ),
      ),
    );
  }
  if (block is DividerBlock) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 16),
      child: pw.Divider(color: PdfColors.grey300),
    );
  }
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 12),
    child: pw.Text(
      block.plainText,
      style: pw.TextStyle(
        font: literata,
        fontSize: 11.5,
        lineSpacing: 5.5,
      ),
    ),
  );
}
