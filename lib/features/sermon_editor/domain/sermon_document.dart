import 'package:sermonary/features/bible/domain/bible_reference.dart';

enum ParagraphRole {
  normal,
  introduction,
  explanation,
  illustration,
  application,
  transition,
  conclusion,
}

enum NoteVisibility { editorOnly, liveMode, always }

sealed class DocumentBlock {
  const DocumentBlock({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get type;
  String get plainText;

  Map<String, Object?> toJson();

  static DocumentBlock fromJson(Map<String, Object?> json) {
    final createdAt = DateTime.parse(json['createdAt']! as String).toUtc();
    final updatedAt = DateTime.parse(json['updatedAt']! as String).toUtc();
    final id = json['id']! as String;
    return switch (json['type']) {
      'title' => TitleBlock(
        id: id,
        text: json['text']! as String,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'heading' => HeadingBlock(
        id: id,
        level: json['level']! as int,
        text: json['text']! as String,
        collapsed: json['collapsed']! as bool,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'paragraph' => ParagraphBlock(
        id: id,
        text: json['text']! as String,
        semanticRole: ParagraphRole.values.byName(
          json['semanticRole']! as String,
        ),
        isBold: json['isBold'] as bool? ?? false,
        isItalic: json['isItalic'] as bool? ?? false,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'bulletList' => BulletListBlock(
        id: id,
        ordered: json['ordered']! as bool,
        items: (json['items']! as List<Object?>)
            .cast<Map<String, Object?>>()
            .map(BulletItem.fromJson)
            .toList(growable: false),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'bibleQuote' => BibleQuoteBlock(
        id: id,
        reference: BibleReference.fromJson(
          json['reference']! as Map<String, Object?>,
        ),
        translationId: json['translationId']! as String,
        translationLabel: json['translationLabel']! as String,
        text: json['text']! as String,
        showVerseNumbers: json['showVerseNumbers']! as bool,
        copyrightNotice: json['copyrightNotice']! as String,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'quote' => QuoteBlock(
        id: id,
        text: json['text']! as String,
        author: json['author']! as String,
        source: json['source']! as String,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'note' => NoteBlock(
        id: id,
        text: json['text']! as String,
        visibility: NoteVisibility.values.byName(
          json['visibility']! as String,
        ),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'divider' => DividerBlock(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      _ => throw FormatException('Unbekannter Blocktyp: ${json['type']}'),
    };
  }

  Map<String, Object?> baseJson() => {
    'id': id,
    'type': type,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}

class TitleBlock extends DocumentBlock {
  const TitleBlock({
    required super.id,
    required this.text,
    required super.createdAt,
    required super.updatedAt,
  });
  final String text;
  @override
  String get type => 'title';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {...baseJson(), 'text': text};
}

class HeadingBlock extends DocumentBlock {
  const HeadingBlock({
    required super.id,
    required this.level,
    required this.text,
    required this.collapsed,
    required super.createdAt,
    required super.updatedAt,
  });
  final int level;
  final String text;
  final bool collapsed;
  @override
  String get type => 'heading';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'level': level,
    'text': text,
    'collapsed': collapsed,
  };
}

class ParagraphBlock extends DocumentBlock {
  const ParagraphBlock({
    required super.id,
    required this.text,
    required this.semanticRole,
    required super.createdAt,
    required super.updatedAt,
    this.isBold = false,
    this.isItalic = false,
  });
  final String text;
  final ParagraphRole semanticRole;
  final bool isBold;
  final bool isItalic;
  @override
  String get type => 'paragraph';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'text': text,
    'semanticRole': semanticRole.name,
    'isBold': isBold,
    'isItalic': isItalic,
  };
}

class BulletItem {
  const BulletItem({
    required this.id,
    required this.text,
    required this.semanticRole,
    required this.collapsed,
    required this.children,
  });
  final String id;
  final String text;
  final ParagraphRole? semanticRole;
  final bool collapsed;
  final List<BulletItem> children;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    'semanticRole': semanticRole?.name,
    'collapsed': collapsed,
    'children': children.map((item) => item.toJson()).toList(growable: false),
  };

  factory BulletItem.fromJson(Map<String, Object?> json) => BulletItem(
    id: json['id']! as String,
    text: json['text']! as String,
    semanticRole: json['semanticRole'] == null
        ? null
        : ParagraphRole.values.byName(json['semanticRole']! as String),
    collapsed: json['collapsed']! as bool,
    children: (json['children']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(BulletItem.fromJson)
        .toList(growable: false),
  );

  int get wordCount =>
      countWords(text) + children.fold(0, (sum, item) => sum + item.wordCount);
}

class BulletListBlock extends DocumentBlock {
  const BulletListBlock({
    required super.id,
    required this.ordered,
    required this.items,
    required super.createdAt,
    required super.updatedAt,
  });
  final bool ordered;
  final List<BulletItem> items;
  @override
  String get type => 'bulletList';
  @override
  String get plainText => items.map(_flattenItem).join('\n');
  String _flattenItem(BulletItem item) =>
      [item.text, ...item.children.map(_flattenItem)].join('\n');
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'ordered': ordered,
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

class BibleQuoteBlock extends DocumentBlock {
  const BibleQuoteBlock({
    required super.id,
    required this.reference,
    required this.translationId,
    required this.translationLabel,
    required this.text,
    required this.showVerseNumbers,
    required this.copyrightNotice,
    required super.createdAt,
    required super.updatedAt,
  });
  final BibleReference reference;
  final String translationId;
  final String translationLabel;
  final String text;
  final bool showVerseNumbers;
  final String copyrightNotice;
  @override
  String get type => 'bibleQuote';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'reference': reference.toJson(),
    'translationId': translationId,
    'translationLabel': translationLabel,
    'text': text,
    'showVerseNumbers': showVerseNumbers,
    'copyrightNotice': copyrightNotice,
  };
}

class QuoteBlock extends DocumentBlock {
  const QuoteBlock({
    required super.id,
    required this.text,
    required this.author,
    required this.source,
    required super.createdAt,
    required super.updatedAt,
  });
  final String text;
  final String author;
  final String source;
  @override
  String get type => 'quote';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'text': text,
    'author': author,
    'source': source,
  };
}

class NoteBlock extends DocumentBlock {
  const NoteBlock({
    required super.id,
    required this.text,
    required this.visibility,
    required super.createdAt,
    required super.updatedAt,
  });
  final String text;
  final NoteVisibility visibility;
  @override
  String get type => 'note';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'text': text,
    'visibility': visibility.name,
  };
}

class DividerBlock extends DocumentBlock {
  const DividerBlock({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
  });
  @override
  String get type => 'divider';
  @override
  String get plainText => '';
  @override
  Map<String, Object?> toJson() => baseJson();
}

class SermonDocument {
  const SermonDocument({required this.schemaVersion, required this.blocks});
  static const currentSchemaVersion = 1;
  final int schemaVersion;
  final List<DocumentBlock> blocks;

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
  };

  factory SermonDocument.fromJson(Map<String, Object?> json) => SermonDocument(
    schemaVersion: json['schemaVersion']! as int,
    blocks: (json['blocks']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(DocumentBlock.fromJson)
        .toList(growable: false),
  );

  String get plainText => blocks.map((block) => block.plainText).join('\n');
  int get wordCount => countWords(plainText);
  Duration estimatedDuration({int wordsPerMinute = 120}) => Duration(
    seconds: wordCount == 0 ? 0 : (wordCount * 60 / wordsPerMinute).ceil(),
  );
}

int countWords(String text) => RegExp(
  r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)?",
  unicode: true,
).allMatches(text).length;

abstract interface class DocumentMigrator {
  SermonDocument migrate(
    SermonDocument document, {
    required int fromVersion,
    required int toVersion,
  });
}

class V1DocumentMigrator implements DocumentMigrator {
  const V1DocumentMigrator();
  @override
  SermonDocument migrate(
    SermonDocument document, {
    required int fromVersion,
    required int toVersion,
  }) {
    if (fromVersion != 1 || toVersion != 1) {
      throw UnsupportedError('Dokumentmigration $fromVersion → $toVersion');
    }
    return document;
  }
}
