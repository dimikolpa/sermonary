import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

enum SermonImportTarget { notes, script }

class ImportedSermon {
  const ImportedSermon({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.contentKind,
    required this.topics,
    required this.tags,
    required this.document,
    this.primaryBibleReference,
    this.series,
    this.audience,
    this.location,
    this.scheduledAt,
    this.plannedDurationMinutes,
    this.corrections = const [],
  });

  final String title;
  final String subtitle;
  final SermonStatus status;
  final ContentKind contentKind;
  final BibleReference? primaryBibleReference;
  final String? series;
  final List<String> topics;
  final List<String> tags;
  final String? audience;
  final String? location;
  final DateTime? scheduledAt;
  final int? plannedDurationMinutes;
  final SermonDocument document;
  final List<String> corrections;
}

class SermonImportParser {
  SermonImportParser({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const supportedExtensions = {'txt', 'md', 'markdown'};
  static const _tagNames =
      'title|subtitle|bible|reference|series|kind|type|status|topics|tags|'
      'audience|location|date|duration|h1|h2|h3|p|quote|li1|li2|both';
  static const _metadataTags = {
    'title',
    'subtitle',
    'bible',
    'reference',
    'series',
    'kind',
    'type',
    'status',
    'topics',
    'tags',
    'audience',
    'location',
    'date',
    'duration',
  };
  final Uuid _uuid;

  ImportedSermon parse(
    String source, {
    required String fileName,
    required SermonImportTarget target,
  }) {
    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    if (!supportedExtensions.contains(extension)) {
      throw const FormatException(
        'Zulässig sind UTF-8-Dateien mit .txt, .md oder .markdown.',
      );
    }
    final prepared = _prepareSource(source);
    final normalized = prepared.source;
    final corrections = prepared.corrections;
    final tagPattern = RegExp(
      '<($_tagNames)>\\s*([\\s\\S]*?)\\s*</\\1>',
      caseSensitive: false,
    );
    final metadata = <String, String>{};
    final blocks = <DocumentBlock>[];
    var cursor = 0;
    final now = DateTime.now().toUtc();

    for (final match in tagPattern.allMatches(normalized)) {
      _appendParagraphs(
        normalized.substring(cursor, match.start),
        blocks,
        now,
        target,
        corrections,
      );
      final tag = match.group(1)!.toLowerCase();
      final value = _repairInlineMarks(
        match.group(2)!.trim(),
        corrections,
      );
      if (_metadataTags.contains(tag)) {
        metadata[tag] = value;
      } else if (value.isNotEmpty) {
        blocks.addAll(_contentBlocks(tag, value, now, target));
      }
      cursor = match.end;
    }
    _appendParagraphs(
      normalized.substring(cursor),
      blocks,
      now,
      target,
      corrections,
    );

    final unmatched = RegExp(
      '</?($_tagNames)>',
      caseSensitive: false,
    ).firstMatch(normalized.replaceAll(tagPattern, ''));
    if (unmatched != null) {
      throw FormatException(
        'Tag „${unmatched.group(0)}“ ist nicht vollständig geschlossen.',
      );
    }

    final title = _plainInline(
      metadata['title']?.trim().isNotEmpty == true
          ? metadata['title']!
          : _fileTitle(fileName),
    );
    final referenceText = metadata['bible'] ?? metadata['reference'];
    BibleReference? reference;
    if (referenceText?.trim().isNotEmpty == true) {
      reference = BibleReferenceParser().parse(referenceText!.trim());
      if (reference == null) {
        throw FormatException(
          'Bibelstelle „$referenceText“ wurde nicht erkannt, zum Beispiel '
          'Johannes 3, Johannes 2–4 oder Johannes 2,4–5.',
        );
      }
    }

    return ImportedSermon(
      title: title,
      subtitle: _plainInline(metadata['subtitle'] ?? ''),
      status: _status(metadata['status']),
      contentKind: _kind(metadata['kind'] ?? metadata['type']),
      primaryBibleReference: reference,
      series: _nullablePlain(metadata['series']),
      topics: _list(metadata['topics']),
      tags: _list(metadata['tags']),
      audience: _nullablePlain(metadata['audience']),
      location: _nullablePlain(metadata['location']),
      scheduledAt: _date(metadata['date']),
      plannedDurationMinutes: _duration(metadata['duration']),
      document: SermonDocument(
        schemaVersion: SermonDocument.currentSchemaVersion,
        blocks: blocks,
        modules: [
          SermonModule(
            id: 'import-${target.name}',
            kind: target == SermonImportTarget.notes
                ? SermonModuleKind.notes
                : SermonModuleKind.script,
            title: '',
            sortOrder: target == SermonImportTarget.notes ? 0 : 1,
            blockIds: blocks.map((block) => block.id).toList(growable: false),
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
      corrections: List.unmodifiable(corrections),
    );
  }

  _PreparedImportSource _prepareSource(String source) {
    final corrections = <String>[];
    var normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.startsWith('\uFEFF')) {
      normalized = normalized.substring(1);
      corrections.add('UTF-8-BOM am Dateianfang entfernt.');
    }
    normalized = normalized.replaceAllMapped(
      RegExp(
        '<\\s*(/?)\\s*($_tagNames)\\s*>',
        caseSensitive: false,
      ),
      (match) {
        final canonical = '<${match.group(1)}${match.group(2)!.toLowerCase()}>';
        if (match.group(0) != canonical) {
          corrections.add(
            'Tag-Schreibweise „${match.group(0)}“ normalisiert.',
          );
        }
        return canonical;
      },
    );
    normalized = _expandUnambiguousShorthand(normalized, corrections);
    normalized = _repairBlockTags(normalized, corrections);
    return _PreparedImportSource(normalized, corrections);
  }

  String _expandUnambiguousShorthand(
    String source,
    List<String> corrections,
  ) {
    final lines = source.split('\n');
    final remainingClosings = <String, int>{};
    final closingPattern = RegExp(
      '</($_tagNames)>',
      caseSensitive: false,
    );
    for (final match in closingPattern.allMatches(source)) {
      remainingClosings.update(
        match.group(1)!.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final openingWithText = RegExp(
      '^\\s*<($_tagNames)>\\s*(.+?)\\s*\$',
      caseSensitive: false,
    );
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      for (final close in closingPattern.allMatches(line)) {
        remainingClosings.update(
          close.group(1)!.toLowerCase(),
          (count) => count - 1,
        );
      }
      final match = openingWithText.firstMatch(line);
      if (match == null || line.contains('</')) continue;
      final tag = match.group(1)!.toLowerCase();
      if ((remainingClosings[tag] ?? 0) > 0) continue;
      lines[index] = '$line</$tag>';
      corrections.add('Kurzform <$tag> in Zeile ${index + 1} geschlossen.');
    }
    return lines.join('\n');
  }

  String _repairBlockTags(String source, List<String> corrections) {
    final tokenPattern = RegExp(
      '</?($_tagNames)>',
      caseSensitive: false,
    );
    final result = StringBuffer();
    final remainingClosings = <String, int>{};
    for (final match in tokenPattern.allMatches(source)) {
      if (!match.group(0)!.startsWith('</')) continue;
      remainingClosings.update(
        match.group(1)!.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    String? openTag;
    var cursor = 0;
    for (final match in tokenPattern.allMatches(source)) {
      result.write(source.substring(cursor, match.start));
      final token = match.group(0)!;
      final tag = match.group(1)!.toLowerCase();
      final closing = token.startsWith('</');
      if (closing) {
        remainingClosings.update(tag, (count) => count - 1);
      }
      if (!closing) {
        if (openTag != null) {
          final hasLaterClose = (remainingClosings[openTag] ?? 0) > 0;
          if (hasLaterClose) {
            throw FormatException(
              'Block-Tags dürfen nicht verschachtelt werden: '
              '<$openTag> enthält <$tag>.',
            );
          }
          result.write('</$openTag>\n');
          corrections.add(
            'Fehlendes </$openTag> vor <$tag> ergänzt.',
          );
        }
        result.write('<$tag>');
        openTag = tag;
      } else if (openTag == null) {
        corrections.add('Überzähliges </$tag> entfernt.');
      } else if (tag == openTag) {
        result.write('</$tag>');
        openTag = null;
      } else {
        final hasLaterClose = (remainingClosings[openTag] ?? 0) > 0;
        if (hasLaterClose) {
          throw FormatException(
            'Block-Tags sind widersprüchlich verschachtelt: '
            '<$openTag> wurde mit </$tag> geschlossen.',
          );
        }
        result.write('</$openTag>');
        corrections.add(
          'Falsches </$tag> durch </$openTag> ersetzt.',
        );
        openTag = null;
      }
      cursor = match.end;
    }
    result.write(source.substring(cursor));
    if (openTag != null) {
      result.write('</$openTag>');
      corrections.add('Fehlendes </$openTag> am Dateiende ergänzt.');
    }
    return result.toString();
  }

  String _repairInlineMarks(String source, List<String> corrections) {
    final tokenPattern = RegExp(
      r'<\s*(/?)\s*mark\s*>',
      caseSensitive: false,
    );
    final result = StringBuffer();
    var open = false;
    var cursor = 0;
    for (final match in tokenPattern.allMatches(source)) {
      result.write(source.substring(cursor, match.start));
      final closing = match.group(1)!.isNotEmpty;
      if (!closing && !open) {
        result.write('<mark>');
        open = true;
      } else if (!closing) {
        corrections.add('Doppeltes <mark> entfernt.');
      } else if (open) {
        result.write('</mark>');
        open = false;
      } else {
        corrections.add('Überzähliges </mark> entfernt.');
      }
      cursor = match.end;
    }
    result.write(source.substring(cursor));
    if (open) {
      result.write('</mark>');
      corrections.add('Fehlendes </mark> ergänzt.');
    }
    return result.toString();
  }

  void _appendParagraphs(
    String source,
    List<DocumentBlock> blocks,
    DateTime now,
    SermonImportTarget target,
    List<String> corrections,
  ) {
    for (final part in source.split(RegExp(r'\n\s*\n'))) {
      final value = _cleanBlockText(
        _repairInlineMarks(part, corrections),
      );
      if (value.isEmpty) continue;
      final inline = _inline(value);
      blocks.add(
        target == SermonImportTarget.script
            ? ParagraphBlock(
                id: _uuid.v4(),
                text: inline.text,
                semanticRole: ParagraphRole.normal,
                marks: inline.marks,
                createdAt: now,
                updatedAt: now,
              )
            : NoteBlock(
                id: _uuid.v4(),
                text: inline.text,
                visibility: NoteVisibility.editorOnly,
                marks: inline.marks,
                createdAt: now,
                updatedAt: now,
              ),
      );
    }
  }

  List<DocumentBlock> _contentBlocks(
    String tag,
    String value,
    DateTime now,
    SermonImportTarget target,
  ) {
    final cleaned = _cleanBlockText(value);
    final inline = _inline(cleaned);
    return switch (tag) {
      'h1' => [
        HeadingBlock(
          id: _uuid.v4(),
          level: 1,
          text: inline.text,
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'h2' => [
        HeadingBlock(
          id: _uuid.v4(),
          level: 2,
          text: inline.text,
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'h3' => [
        HeadingBlock(
          id: _uuid.v4(),
          level: 3,
          text: inline.text,
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'p' when target == SermonImportTarget.script => [
        ParagraphBlock(
          id: _uuid.v4(),
          text: inline.text,
          semanticRole: ParagraphRole.normal,
          marks: inline.marks,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'quote' when target == SermonImportTarget.script => [
        QuoteBlock(
          id: _uuid.v4(),
          text: inline.text,
          author: '',
          source: '',
          marks: inline.marks,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'li1' || 'li2' when target == SermonImportTarget.notes => [
        NoteBlock(
          id: _uuid.v4(),
          text: inline.text,
          visibility: NoteVisibility.editorOnly,
          depth: tag == 'li2' ? 1 : 0,
          marks: inline.marks,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      'p' || 'quote' => throw const FormatException(
        'Script-Blöcke sind bei einem Notes-Import nicht zulässig.',
      ),
      'li1' || 'li2' => throw const FormatException(
        'Notes-Blöcke sind bei einem Script-Import nicht zulässig.',
      ),
      'both' => throw const FormatException(
        'Ein gleichzeitiger Import in Notes und Script ist nicht zulässig.',
      ),
      _ => throw FormatException('Unbekannter Inhalts-Tag: $tag'),
    };
  }

  _InlineContent _inline(String source) {
    final text = StringBuffer();
    final marks = <InlineMark>[];
    var index = 0;
    while (index < source.length) {
      if (source[index] == r'\' &&
          index + 1 < source.length &&
          source[index + 1] == '*') {
        text.write('*');
        index += 2;
        continue;
      }
      final highlightOpen = RegExp(
        '<mark>',
        caseSensitive: false,
      ).matchAsPrefix(source, index);
      if (highlightOpen != null) {
        final contentStart = highlightOpen.end;
        final highlightClose = RegExp(
          '</mark>',
          caseSensitive: false,
        ).firstMatch(source.substring(contentStart));
        if (highlightClose == null) {
          throw const FormatException(
            'Eine <mark>-Markierung ist nicht vollständig geschlossen.',
          );
        }
        final contentEnd = contentStart + highlightClose.start;
        final nested = _inline(source.substring(contentStart, contentEnd));
        final startOffset = text.length;
        text.write(nested.text);
        final endOffset = text.length;
        marks.addAll(
          nested.marks.map(
            (mark) => InlineMark(
              start: mark.start + startOffset,
              end: mark.end + startOffset,
              bold: mark.bold,
              italic: mark.italic,
              highlighted: mark.highlighted,
            ),
          ),
        );
        if (endOffset > startOffset) {
          marks.add(
            InlineMark(
              start: startOffset,
              end: endOffset,
              highlighted: true,
            ),
          );
        }
        index = contentEnd + highlightClose.group(0)!.length;
        continue;
      }
      if (RegExp(
            '</mark>',
            caseSensitive: false,
          ).matchAsPrefix(source, index) !=
          null) {
        throw const FormatException(
          'Eine </mark>-Markierung hat keinen öffnenden <mark>-Tag.',
        );
      }
      final delimiter = source.startsWith('***', index)
          ? '***'
          : source.startsWith('**', index)
          ? '**'
          : source[index] == '*'
          ? '*'
          : null;
      if (delimiter == null) {
        text.write(source[index]);
        index++;
        continue;
      }
      final end = source.indexOf(delimiter, index + delimiter.length);
      if (end < 0) {
        text.write(delimiter);
        index += delimiter.length;
        continue;
      }
      final startOffset = text.length;
      final nested = _inline(
        source.substring(index + delimiter.length, end),
      );
      text.write(nested.text);
      final endOffset = text.length;
      marks.addAll(
        nested.marks.map(
          (mark) => InlineMark(
            start: mark.start + startOffset,
            end: mark.end + startOffset,
            bold: mark.bold,
            italic: mark.italic,
            highlighted: mark.highlighted,
          ),
        ),
      );
      if (endOffset > startOffset) {
        marks.add(
          InlineMark(
            start: startOffset,
            end: endOffset,
            bold: delimiter.length >= 2,
            italic: delimiter.length == 1 || delimiter.length == 3,
          ),
        );
      }
      index = end + delimiter.length;
    }
    return _InlineContent(text.toString(), marks);
  }

  String _cleanBlockText(String value) =>
      value.trim().replaceAll(RegExp(r'[ \t]*\n[ \t]*'), ' ');

  String _plainInline(String value) => _inline(value.trim()).text;

  String? _nullablePlain(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return _plainInline(value);
  }

  List<String> _list(String? value) => value == null
      ? const []
      : value
            .split(RegExp('[,;]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);

  int? _duration(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final minutes = int.tryParse(value.replaceAll(RegExp('[^0-9]'), ''));
    if (minutes == null || minutes <= 0) {
      throw FormatException('Dauer „$value“ ist keine gültige Minutenzahl.');
    }
    return minutes;
  }

  DateTime? _date(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim();
    final german = RegExp(
      r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$',
    ).firstMatch(normalized);
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    final day = int.tryParse(german?.group(1) ?? iso?.group(3) ?? '');
    final month = int.tryParse(german?.group(2) ?? iso?.group(2) ?? '');
    final year = int.tryParse(german?.group(3) ?? iso?.group(1) ?? '');
    if (day == null || month == null || year == null) {
      throw FormatException(
        'Datum „$value“ konnte nicht erkannt werden. '
        'Verwende TT.MM.JJJJ oder JJJJ-MM-TT.',
      );
    }
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException(
        'Datum „$value“ ist kein gültiges Kalenderdatum.',
      );
    }
    return date;
  }

  SermonStatus _status(String? value) => switch (value?.trim().toLowerCase()) {
    null || '' || 'entwurf' || 'draft' => SermonStatus.draft,
    'in arbeit' || 'in_arbeit' || 'in-progress' => SermonStatus.inProgress,
    'fertig' || 'bereit' || 'ready' => SermonStatus.ready,
    'gehalten' || 'preached' => SermonStatus.preached,
    'archiviert' || 'archived' => SermonStatus.archived,
    final invalid => throw FormatException('Unbekannter Status: „$invalid“.'),
  };

  ContentKind _kind(String? value) => switch (value?.trim().toLowerCase()) {
    null || '' || 'predigt' || 'sermon' => ContentKind.sermon,
    'vortrag' || 'talk' => ContentKind.talk,
    'kurzthema' || 'shorttopic' || 'short-topic' => ContentKind.shortTopic,
    'einleitung' || 'introduction' => ContentKind.introduction,
    final invalid => throw FormatException(
      'Unbekannter Inhaltstyp: „$invalid“.',
    ),
  };

  String _fileTitle(String fileName) {
    final name = fileName.replaceAll(r'\', '/').split('/').last;
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }
}

class _InlineContent {
  const _InlineContent(this.text, this.marks);

  final String text;
  final List<InlineMark> marks;
}

class _PreparedImportSource {
  const _PreparedImportSource(this.source, this.corrections);

  final String source;
  final List<String> corrections;
}
