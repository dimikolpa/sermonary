import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

abstract interface class ExportService {
  String exportMarkdown(Sermon sermon, {required bool includeInternalNotes});
  String exportPlainText(Sermon sermon, {required bool includeInternalNotes});
}

class LocalExportService implements ExportService {
  const LocalExportService();

  @override
  String exportMarkdown(
    Sermon sermon, {
    required bool includeInternalNotes,
  }) {
    final output = StringBuffer()
      ..writeln('# ${sermon.title}')
      ..writeln();
    if (sermon.subtitle.isNotEmpty) {
      output
        ..writeln(sermon.subtitle)
        ..writeln();
    }
    if (sermon.primaryBibleReference case final reference?) {
      output
        ..writeln('**Bibelstelle:** ${reference.displayText}')
        ..writeln();
    }
    for (final block in sermon.document.blocks) {
      switch (block) {
        case TitleBlock(:final text):
          output
            ..writeln('# $text')
            ..writeln();
        case HeadingBlock(:final level, :final text):
          output
            ..writeln('${'#' * level} $text')
            ..writeln();
        case ParagraphBlock(
          :final text,
          :final isBold,
          :final isItalic,
        ):
          final marker = isBold ? '**' : (isItalic ? '*' : '');
          output
            ..writeln('$marker$text$marker')
            ..writeln();
        case BulletListBlock(:final ordered, :final items):
          _writeMarkdownItems(output, items, ordered: ordered);
          output.writeln();
        case BibleQuoteBlock(:final text, :final reference):
          output
            ..writeln('> $text')
            ..writeln('>')
            ..writeln('> — ${reference.displayText}')
            ..writeln();
        case QuoteBlock(:final text, :final author, :final source):
          output
            ..writeln('> $text')
            ..writeln(
              '> — ${[author, source].where((v) => v.isNotEmpty).join(', ')}',
            )
            ..writeln();
        case NoteBlock(:final text, :final visibility):
          if (includeInternalNotes || visibility != NoteVisibility.editorOnly) {
            output
              ..writeln('> **Notiz:** $text')
              ..writeln();
          }
        case DividerBlock():
          output
            ..writeln('---')
            ..writeln();
      }
    }
    return output.toString().trimRight();
  }

  @override
  String exportPlainText(
    Sermon sermon, {
    required bool includeInternalNotes,
  }) {
    final output = StringBuffer()
      ..writeln(sermon.title)
      ..writeln('=' * sermon.title.length)
      ..writeln();
    if (sermon.subtitle.isNotEmpty) {
      output
        ..writeln(sermon.subtitle)
        ..writeln();
    }
    for (final block in sermon.document.blocks) {
      if (block case NoteBlock(
        visibility: NoteVisibility.editorOnly,
      ) when !includeInternalNotes) {
        continue;
      }
      if (block case DividerBlock()) {
        output
          ..writeln('—' * 24)
          ..writeln();
      } else if (block case BulletListBlock(:final items)) {
        _writeTextItems(output, items);
        output.writeln();
      } else if (block.plainText.isNotEmpty) {
        output
          ..writeln(block.plainText)
          ..writeln();
      }
    }
    return output.toString().trimRight();
  }

  void _writeMarkdownItems(
    StringBuffer output,
    List<BulletItem> items, {
    required bool ordered,
    int depth = 0,
  }) {
    for (var index = 0; index < items.length; index++) {
      output.writeln(
        '${'  ' * depth}${ordered ? '${index + 1}.' : '-'} ${items[index].text}',
      );
      _writeMarkdownItems(
        output,
        items[index].children,
        ordered: ordered,
        depth: depth + 1,
      );
    }
  }

  void _writeTextItems(
    StringBuffer output,
    List<BulletItem> items, [
    int depth = 0,
  ]) {
    for (final item in items) {
      output.writeln('${'  ' * depth}• ${item.text}');
      _writeTextItems(output, item.children, depth + 1);
    }
  }
}
