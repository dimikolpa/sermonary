import 'dart:async';

import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:super_clipboard/super_clipboard.dart';

enum PastedBlockKind { heading, body, quote }

class PastedInlineMark {
  const PastedInlineMark({
    required this.start,
    required this.end,
    this.bold = false,
    this.italic = false,
    this.highlighted = false,
  });

  final int start;
  final int end;
  final bool bold;
  final bool italic;
  final bool highlighted;
}

class PastedBlock {
  const PastedBlock({
    required this.kind,
    required this.text,
    required this.marks,
    this.headingLevel,
    this.noteDepth,
  });

  final PastedBlockKind kind;
  final int? headingLevel;
  final int? noteDepth;
  final String text;
  final List<PastedInlineMark> marks;
}

class RichClipboardContent {
  const RichClipboardContent({this.html, this.plainText});

  final String? html;
  final String? plainText;
}

abstract interface class RichClipboardSource {
  Future<RichClipboardContent> read();
}

abstract interface class RichClipboardSink {
  Future<void> write(RichClipboardContent content);
}

class RichClipboardWriter implements RichClipboardSink {
  const RichClipboardWriter();

  @override
  Future<void> write(RichClipboardContent content) async {
    final plainText = content.plainText ?? '';
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      await Clipboard.setData(ClipboardData(text: plainText));
      return;
    }
    final item = DataWriterItem();
    final html = content.html;
    if (html != null && html.isNotEmpty) item.add(Formats.htmlText(html));
    item.add(Formats.plainText(plainText));
    await clipboard.write([item]);
  }
}

class RichClipboardReader implements RichClipboardSource {
  static const _channel = MethodChannel('sermonary/rich_clipboard');

  @override
  Future<RichClipboardContent> read() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      final plain = await Clipboard.getData(Clipboard.kTextPlain);
      return RichClipboardContent(plainText: plain?.text);
    }
    final reader = await clipboard.read();
    var html = reader.canProvide(Formats.htmlText)
        ? await reader.readValue(Formats.htmlText)
        : null;
    final plain = reader.canProvide(Formats.plainText)
        ? await reader.readValue(Formats.plainText)
        : null;

    if ((html == null || html.trim().isEmpty) &&
        reader.canProvide(Formats.rtf)) {
      final rtf = await _readRtf(reader);
      if (rtf != null) {
        try {
          html = await _channel.invokeMethod<String>('rtfToHtml', rtf);
        } on MissingPluginException {
          // Other platforms retain the plain-text fallback.
        } on PlatformException {
          // Malformed RTF should never prevent a normal plain-text paste.
        }
      }
    }
    return RichClipboardContent(html: html, plainText: plain);
  }

  Future<Uint8List?> _readRtf(ClipboardDataReader reader) {
    final completer = Completer<Uint8List?>();
    final progress = reader.getFile(
      Formats.rtf,
      (file) async {
        try {
          completer.complete(await file.readAll());
        } on Object {
          completer.complete(null);
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    if (progress == null) return Future.value();
    return completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
  }
}

class RichPasteParser {
  const RichPasteParser();

  List<PastedBlock> parse(RichClipboardContent content) {
    final html = content.html;
    if (html != null && html.trim().isNotEmpty) {
      final parsed = _parseHtml(html);
      if (parsed.isNotEmpty) return parsed;
    }
    return _parsePlainText(content.plainText ?? '');
  }

  List<PastedBlock> _parseHtml(String source) {
    final fragment = html_parser.parseFragment(source);
    var elements = fragment.querySelectorAll('h1, h2, h3, p, li, blockquote');
    final blockElements = elements.toSet();
    elements = elements
        .where((element) {
          Node? parent = element.parent;
          while (parent != null && parent != fragment) {
            if (parent is Element && blockElements.contains(parent)) {
              return false;
            }
            parent = parent.parent;
          }
          return true;
        })
        .toList(growable: false);
    if (elements.isEmpty) {
      elements = fragment
          .querySelectorAll('div')
          .where(
            (element) =>
                element.querySelector(
                  'div, p, h1, h2, h3, li, blockquote',
                ) ==
                null,
          )
          .toList(growable: false);
    }
    return [
      for (final element in elements) _blockFromElement(element),
    ];
  }

  PastedBlock _blockFromElement(Element element) {
    final level = _headingLevel(element);
    final accumulator = _InlineAccumulator();
    _appendNode(element, accumulator, const _InlineStyle());
    final value = accumulator.finish();
    final tag = element.localName?.toLowerCase();
    return PastedBlock(
      kind: level != null
          ? PastedBlockKind.heading
          : tag == 'blockquote'
          ? PastedBlockKind.quote
          : PastedBlockKind.body,
      headingLevel: level,
      noteDepth: tag == 'li'
          ? int.tryParse(element.attributes['data-sermonary-depth'] ?? '')
          : null,
      text: value.text,
      marks: value.marks,
    );
  }

  int? _headingLevel(Element element) {
    final tag = element.localName?.toLowerCase() ?? '';
    if (tag == 'h1' || tag == 'h2' || tag == 'h3') {
      return int.parse(tag.substring(1));
    }
    final descriptor = [
      element.className,
      element.attributes['style'] ?? '',
      element.attributes['data-style-name'] ?? '',
      element.attributes['role'] ?? '',
    ].join(' ').toLowerCase();
    final named = RegExp(
      '(?:mso[-_ ]*)?(?:heading|überschrift|uberschrift)[-_ ]*([123])',
    ).firstMatch(descriptor);
    if (named != null) return int.parse(named.group(1)!);
    final outline = RegExp(
      r'mso-outline-level\s*:\s*([012])',
    ).firstMatch(descriptor);
    if (outline != null) return int.parse(outline.group(1)!) + 1;
    final ariaLevel = int.tryParse(element.attributes['aria-level'] ?? '');
    if (descriptor.contains('heading') &&
        ariaLevel != null &&
        ariaLevel >= 1 &&
        ariaLevel <= 3) {
      return ariaLevel;
    }

    // RTF converted by macOS can lose named styles. Only short, explicitly
    // bold paragraphs with a clearly enlarged font are inferred as headings.
    final style = element.attributes['style']?.toLowerCase() ?? '';
    final sizeMatch = RegExp(
      r'font-size\s*:\s*([0-9.]+)\s*(pt|px)',
    ).firstMatch(style);
    final bold = RegExp(
      r'font-weight\s*:\s*(?:bold|[6-9]00)',
    ).hasMatch(style);
    if (bold && sizeMatch != null && element.text.trim().length <= 160) {
      var size = double.tryParse(sizeMatch.group(1)!) ?? 0;
      if (sizeMatch.group(2) == 'px') size *= 0.75;
      if (size >= 20) return 1;
      if (size >= 16) return 2;
      if (size >= 13.5) return 3;
    }
    return null;
  }

  void _appendNode(
    Node node,
    _InlineAccumulator accumulator,
    _InlineStyle inherited,
  ) {
    if (node is Text) {
      accumulator.append(node.data, inherited);
      return;
    }
    if (node is! Element) return;
    if (node.localName?.toLowerCase() == 'br') {
      accumulator.appendLineBreak(inherited);
      return;
    }
    final styleText = node.attributes['style']?.toLowerCase() ?? '';
    final localName = node.localName?.toLowerCase() ?? '';
    final style = _InlineStyle(
      bold:
          inherited.bold ||
          localName == 'b' ||
          localName == 'strong' ||
          RegExp(
            r'font-weight\s*:\s*(?:bold|[6-9]00)',
          ).hasMatch(styleText),
      italic:
          inherited.italic ||
          localName == 'i' ||
          localName == 'em' ||
          RegExp(r'font-style\s*:\s*italic').hasMatch(styleText),
      highlighted:
          inherited.highlighted ||
          localName == 'mark' ||
          RegExp(r'background(?:-color)?\s*:').hasMatch(styleText),
    );
    for (final child in node.nodes) {
      _appendNode(child, accumulator, style);
    }
  }

  List<PastedBlock> _parsePlainText(String source) {
    if (source.isEmpty) return const [];
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    return [
      for (final line in normalized.split('\n')) _plainBlock(line),
    ];
  }

  PastedBlock _plainBlock(String source) {
    final heading = RegExp(r'^\s*(#{1,3})\s+').firstMatch(source);
    final raw = heading == null ? source : source.substring(heading.end);
    final accumulator = _InlineAccumulator();
    var index = 0;
    while (index < raw.length) {
      if (raw.startsWith('**', index)) {
        final end = raw.indexOf('**', index + 2);
        if (end > index + 2) {
          accumulator.append(
            raw.substring(index + 2, end),
            const _InlineStyle(bold: true),
          );
          index = end + 2;
          continue;
        }
      }
      if (raw[index] == '*') {
        final end = raw.indexOf('*', index + 1);
        if (end > index + 1) {
          accumulator.append(
            raw.substring(index + 1, end),
            const _InlineStyle(italic: true),
          );
          index = end + 1;
          continue;
        }
      }
      accumulator.append(raw[index], const _InlineStyle());
      index++;
    }
    final value = accumulator.finish();
    return PastedBlock(
      kind: heading == null ? PastedBlockKind.body : PastedBlockKind.heading,
      headingLevel: heading?.group(1)!.length,
      text: value.text,
      marks: value.marks,
    );
  }
}

class _InlineStyle {
  const _InlineStyle({
    this.bold = false,
    this.italic = false,
    this.highlighted = false,
  });

  final bool bold;
  final bool italic;
  final bool highlighted;
}

class _InlineAccumulator {
  final List<String> _characters = [];
  final List<_InlineStyle> _styles = [];

  void append(String source, _InlineStyle style) {
    for (var index = 0; index < source.length; index++) {
      final character = source[index];
      if (RegExp(r'\s').hasMatch(character)) {
        if (_characters.isEmpty ||
            _characters.last == ' ' ||
            _characters.last == '\n') {
          continue;
        }
        _characters.add(' ');
        _styles.add(style);
      } else {
        _characters.add(character);
        _styles.add(style);
      }
    }
  }

  void appendLineBreak(_InlineStyle style) {
    if (_characters.isNotEmpty && _characters.last == ' ') {
      _characters.removeLast();
      _styles.removeLast();
    }
    if (_characters.isEmpty || _characters.last != '\n') {
      _characters.add('\n');
      _styles.add(style);
    }
  }

  ({String text, List<PastedInlineMark> marks}) finish() {
    while (_characters.isNotEmpty &&
        (_characters.first == ' ' || _characters.first == '\n')) {
      _characters.removeAt(0);
      _styles.removeAt(0);
    }
    while (_characters.isNotEmpty &&
        (_characters.last == ' ' || _characters.last == '\n')) {
      _characters.removeLast();
      _styles.removeLast();
    }
    final marks = <PastedInlineMark>[];
    var start = 0;
    while (start < _styles.length) {
      final style = _styles[start];
      var end = start + 1;
      while (end < _styles.length &&
          _styles[end].bold == style.bold &&
          _styles[end].italic == style.italic &&
          _styles[end].highlighted == style.highlighted) {
        end++;
      }
      if (style.bold || style.italic || style.highlighted) {
        marks.add(
          PastedInlineMark(
            start: start,
            end: end,
            bold: style.bold,
            italic: style.italic,
            highlighted: style.highlighted,
          ),
        );
      }
      start = end;
    }
    return (text: _characters.join(), marks: marks);
  }
}
