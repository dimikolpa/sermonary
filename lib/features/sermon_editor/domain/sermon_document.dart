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

class InlineMark {
  const InlineMark({
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

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'bold': bold,
    'italic': italic,
    'highlighted': highlighted,
  };

  factory InlineMark.fromJson(Map<String, Object?> json) => InlineMark(
    start: json['start']! as int,
    end: json['end']! as int,
    bold: json['bold'] as bool? ?? false,
    italic: json['italic'] as bool? ?? false,
    highlighted: json['highlighted'] as bool? ?? false,
  );
}

List<InlineMark> _marksFromJson(Object? value) => value == null
    ? const []
    : (value as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(InlineMark.fromJson)
          .toList(growable: false);

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
        marks: _marksFromJson(json['marks']),
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
        marks: _marksFromJson(json['marks']),
        createdAt: createdAt,
        updatedAt: updatedAt,
      ),
      'note' => NoteBlock(
        id: id,
        text: json['text']! as String,
        visibility: NoteVisibility.values.byName(
          json['visibility']! as String,
        ),
        depth: json['depth'] as int? ?? 0,
        isQuickNote: json['isQuickNote'] as bool? ?? false,
        marks: _marksFromJson(json['marks']),
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
    this.marks = const [],
  });
  final String text;
  final ParagraphRole semanticRole;
  final bool isBold;
  final bool isItalic;
  final List<InlineMark> marks;
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
    'marks': marks.map((mark) => mark.toJson()).toList(growable: false),
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
    this.marks = const [],
  });
  final String text;
  final String author;
  final String source;
  final List<InlineMark> marks;
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
    'marks': marks.map((mark) => mark.toJson()).toList(growable: false),
  };
}

class NoteBlock extends DocumentBlock {
  const NoteBlock({
    required super.id,
    required this.text,
    required this.visibility,
    required super.createdAt,
    required super.updatedAt,
    this.depth = 0,
    this.isQuickNote = false,
    this.marks = const [],
  });
  final String text;
  final NoteVisibility visibility;
  final int depth;
  final bool isQuickNote;
  final List<InlineMark> marks;
  @override
  String get type => 'note';
  @override
  String get plainText => text;
  @override
  Map<String, Object?> toJson() => {
    ...baseJson(),
    'text': text,
    'visibility': visibility.name,
    'depth': depth,
    'isQuickNote': isQuickNote,
    'marks': marks.map((mark) => mark.toJson()).toList(growable: false),
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

enum PresentationSlideTemplate {
  title,
  headingText,
  headingBible,
  contents,
  largeContents,
  headingImage,
  headingImageBible,
  image,
}

enum PresentationAnchorView { script, notes }

class PresentationAnchor {
  const PresentationAnchor({
    required this.view,
    required this.blockId,
    this.offset = 0,
    this.moduleId,
  });

  final PresentationAnchorView view;
  final String blockId;
  final int offset;
  final String? moduleId;

  Map<String, Object?> toJson() => {
    'view': view.name,
    'blockId': blockId,
    'offset': offset,
    'moduleId': moduleId,
  };

  factory PresentationAnchor.fromJson(Map<String, Object?> json) =>
      PresentationAnchor(
        view: PresentationAnchorView.values.firstWhere(
          (value) => value.name == json['view'],
          orElse: () => PresentationAnchorView.script,
        ),
        blockId: json['blockId'] as String? ?? '',
        offset: json['offset'] as int? ?? 0,
        moduleId: json['moduleId'] as String?,
      );
}

class PresentationSlide {
  const PresentationSlide({
    required this.id,
    required this.template,
    this.title = '',
    this.subtitle = '',
    this.body = '',
    this.reference = '',
    this.items = const [],
    this.imagePath,
    this.caption = '',
    this.anchor,
    this.titleMarks = const [],
    this.subtitleMarks = const [],
    this.bodyMarks = const [],
    this.referenceMarks = const [],
    this.itemMarks = const [],
    this.captionMarks = const [],
    this.continuationGroupId,
    this.continuationIndex = 1,
    this.continuationCount = 1,
  });

  final String id;
  final PresentationSlideTemplate template;
  final String title;
  final String subtitle;
  final String body;
  final String reference;
  final List<String> items;
  final String? imagePath;
  final String caption;
  final PresentationAnchor? anchor;
  final List<InlineMark> titleMarks;
  final List<InlineMark> subtitleMarks;
  final List<InlineMark> bodyMarks;
  final List<InlineMark> referenceMarks;
  final List<List<InlineMark>> itemMarks;
  final List<InlineMark> captionMarks;
  final String? continuationGroupId;
  final int continuationIndex;
  final int continuationCount;

  PresentationSlide copyWith({
    PresentationSlideTemplate? template,
    String? title,
    String? subtitle,
    String? body,
    String? reference,
    List<String>? items,
    String? imagePath,
    bool clearImagePath = false,
    String? caption,
    PresentationAnchor? anchor,
    bool clearAnchor = false,
    List<InlineMark>? titleMarks,
    List<InlineMark>? subtitleMarks,
    List<InlineMark>? bodyMarks,
    List<InlineMark>? referenceMarks,
    List<List<InlineMark>>? itemMarks,
    List<InlineMark>? captionMarks,
    String? continuationGroupId,
    bool clearContinuationGroupId = false,
    int? continuationIndex,
    int? continuationCount,
  }) => PresentationSlide(
    id: id,
    template: template ?? this.template,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    reference: reference ?? this.reference,
    items: items ?? this.items,
    imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
    caption: caption ?? this.caption,
    anchor: clearAnchor ? null : anchor ?? this.anchor,
    titleMarks: titleMarks ?? this.titleMarks,
    subtitleMarks: subtitleMarks ?? this.subtitleMarks,
    bodyMarks: bodyMarks ?? this.bodyMarks,
    referenceMarks: referenceMarks ?? this.referenceMarks,
    itemMarks: itemMarks ?? this.itemMarks,
    captionMarks: captionMarks ?? this.captionMarks,
    continuationGroupId: clearContinuationGroupId
        ? null
        : continuationGroupId ?? this.continuationGroupId,
    continuationIndex: continuationIndex ?? this.continuationIndex,
    continuationCount: continuationCount ?? this.continuationCount,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'template': template.name,
    'title': title,
    'subtitle': subtitle,
    'body': body,
    'reference': reference,
    'items': items,
    'imagePath': imagePath,
    'caption': caption,
    'anchor': anchor?.toJson(),
    'titleMarks': titleMarks.map((mark) => mark.toJson()).toList(),
    'subtitleMarks': subtitleMarks.map((mark) => mark.toJson()).toList(),
    'bodyMarks': bodyMarks.map((mark) => mark.toJson()).toList(),
    'referenceMarks': referenceMarks.map((mark) => mark.toJson()).toList(),
    'itemMarks': [
      for (final marks in itemMarks)
        marks.map((mark) => mark.toJson()).toList(),
    ],
    'captionMarks': captionMarks.map((mark) => mark.toJson()).toList(),
    'continuationGroupId': continuationGroupId,
    'continuationIndex': continuationIndex,
    'continuationCount': continuationCount,
  };

  factory PresentationSlide.fromJson(Map<String, Object?> json) =>
      PresentationSlide(
        id: json['id'] as String? ?? '',
        template: PresentationSlideTemplate.values.firstWhere(
          (value) => value.name == json['template'],
          orElse: () => PresentationSlideTemplate.title,
        ),
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        body: json['body'] as String? ?? '',
        reference: json['reference'] as String? ?? '',
        items: (json['items'] as List<Object?>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
        imagePath: json['imagePath'] as String?,
        caption: json['caption'] as String? ?? '',
        anchor: json['anchor'] is Map<String, Object?>
            ? PresentationAnchor.fromJson(
                json['anchor']! as Map<String, Object?>,
              )
            : null,
        titleMarks: _marksFromJson(json['titleMarks']),
        subtitleMarks: _marksFromJson(json['subtitleMarks']),
        bodyMarks: _marksFromJson(json['bodyMarks']),
        referenceMarks: _marksFromJson(json['referenceMarks']),
        itemMarks: (json['itemMarks'] as List<Object?>? ?? const [])
            .map(_marksFromJson)
            .toList(growable: false),
        captionMarks: _marksFromJson(json['captionMarks']),
        continuationGroupId: json['continuationGroupId'] as String?,
        continuationIndex: json['continuationIndex'] as int? ?? 1,
        continuationCount: json['continuationCount'] as int? ?? 1,
      );
}

class PresentationDeck {
  const PresentationDeck({this.slides = const []});

  final List<PresentationSlide> slides;

  Map<String, Object?> toJson() => {
    'slides': slides.map((slide) => slide.toJson()).toList(growable: false),
  };

  factory PresentationDeck.fromJson(Map<String, Object?> json) =>
      PresentationDeck(
        slides: (json['slides'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(PresentationSlide.fromJson)
            .toList(growable: false),
      );
}

enum SermonModuleKind { notes, script, presentation }

class SermonModule {
  const SermonModule({
    required this.id,
    required this.kind,
    required this.title,
    required this.sortOrder,
    this.revision = 1,
    this.blockIds = const [],
    this.slideIds = const [],
    this.linkGroupId,
    this.versionRootId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final SermonModuleKind kind;
  final String title;
  final int sortOrder;
  final int revision;
  final List<String> blockIds;
  final List<String> slideIds;
  final String? linkGroupId;
  final String? versionRootId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SermonModule copyWith({
    String? title,
    int? sortOrder,
    int? revision,
    List<String>? blockIds,
    List<String>? slideIds,
    String? linkGroupId,
    bool clearLinkGroupId = false,
    String? versionRootId,
    bool clearVersionRootId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SermonModule(
    id: id,
    kind: kind,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    revision: revision ?? this.revision,
    blockIds: blockIds ?? this.blockIds,
    slideIds: slideIds ?? this.slideIds,
    linkGroupId: clearLinkGroupId ? null : linkGroupId ?? this.linkGroupId,
    versionRootId: clearVersionRootId
        ? null
        : versionRootId ?? this.versionRootId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'sortOrder': sortOrder,
    'revision': revision,
    'blockIds': blockIds,
    'slideIds': slideIds,
    'linkGroupId': linkGroupId,
    'versionRootId': versionRootId,
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };

  factory SermonModule.fromJson(Map<String, Object?> json) => SermonModule(
    id: json['id']! as String,
    kind: SermonModuleKind.values.byName(json['kind']! as String),
    title:
        json['title'] as String? ??
        _moduleTitle(
          SermonModuleKind.values.byName(json['kind']! as String),
        ),
    sortOrder: json['sortOrder'] as int? ?? 0,
    revision: json['revision'] as int? ?? 1,
    blockIds: (json['blockIds'] as List<Object?>? ?? const []).cast<String>(),
    slideIds: (json['slideIds'] as List<Object?>? ?? const []).cast<String>(),
    linkGroupId: json['linkGroupId'] as String?,
    versionRootId: json['versionRootId'] as String?,
    createdAt: json['createdAt'] is String
        ? DateTime.tryParse(json['createdAt']! as String)?.toUtc()
        : null,
    updatedAt: json['updatedAt'] is String
        ? DateTime.tryParse(json['updatedAt']! as String)?.toUtc()
        : null,
  );
}

String _moduleTitle(SermonModuleKind kind) => switch (kind) {
  SermonModuleKind.notes => 'Notizen',
  SermonModuleKind.script => 'Skript',
  SermonModuleKind.presentation => 'Präsentation',
};

int _moduleSortOrder(SermonModuleKind kind) => switch (kind) {
  SermonModuleKind.notes => 0,
  SermonModuleKind.script => 1,
  SermonModuleKind.presentation => 2,
};

class SermonDocument {
  const SermonDocument({
    required this.schemaVersion,
    required this.blocks,
    this.presentation = const PresentationDeck(),
    this.modules = const [],
  });
  static const currentSchemaVersion = 2;
  final int schemaVersion;
  final List<DocumentBlock> blocks;
  final PresentationDeck presentation;
  final List<SermonModule> modules;

  bool hasModule(SermonModuleKind kind) => effectiveModules.any(
    (module) => module.kind == kind,
  );

  SermonModule? moduleFor(SermonModuleKind kind) =>
      effectiveModules.where((module) => module.kind == kind).firstOrNull;

  SermonModule? moduleById(String id) =>
      effectiveModules.where((module) => module.id == id).firstOrNull;

  List<SermonModule> modulesOfKind(SermonModuleKind kind) => effectiveModules
      .where((module) => module.kind == kind)
      .toList(growable: false);

  String versionRootIdFor(SermonModule module) =>
      module.versionRootId ?? module.id;

  List<SermonModule> versionsOf(String moduleId) {
    final module = moduleById(moduleId);
    if (module == null) return const [];
    final rootId = versionRootIdFor(module);
    final versions =
        effectiveModules
            .where(
              (candidate) =>
                  candidate.id == rootId || candidate.versionRootId == rootId,
            )
            .toList(growable: false)
          ..sort((left, right) {
            final byRevision = right.revision.compareTo(left.revision);
            return byRevision != 0
                ? byRevision
                : right.sortOrder.compareTo(left.sortOrder);
          });
    return List.unmodifiable(versions);
  }

  List<DocumentBlock> blocksForModule(String moduleId) {
    final module = moduleById(moduleId);
    if (module == null || module.kind == SermonModuleKind.presentation) {
      return const [];
    }
    final byId = {for (final block in blocks) block.id: block};
    return module.blockIds
        .map((id) => byId[id])
        .whereType<DocumentBlock>()
        .toList(growable: false);
  }

  List<PresentationSlide> slidesForModule(String moduleId) {
    final module = moduleById(moduleId);
    if (module == null || module.kind != SermonModuleKind.presentation) {
      return const [];
    }
    final byId = {for (final slide in presentation.slides) slide.id: slide};
    return module.slideIds
        .map((id) => byId[id])
        .whereType<PresentationSlide>()
        .toList(growable: false);
  }

  bool modulesAreLinked(String leftId, String rightId) {
    final left = moduleById(leftId);
    final right = moduleById(rightId);
    return left != null &&
        right != null &&
        left.linkGroupId != null &&
        left.linkGroupId == right.linkGroupId;
  }

  List<SermonModule> get effectiveModules {
    if (schemaVersion >= 2) {
      final sorted = [...modules]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      return List.unmodifiable(sorted);
    }
    final result = <SermonModule>[...modules];
    void infer(SermonModuleKind kind, Iterable<String> blockIds) {
      if (result.any((module) => module.kind == kind)) return;
      result.add(
        SermonModule(
          id: 'legacy-${kind.name}',
          kind: kind,
          title: _moduleTitle(kind),
          sortOrder: _moduleSortOrder(kind),
          blockIds: blockIds.toList(growable: false),
        ),
      );
    }

    final headings = blocks.whereType<HeadingBlock>().map((block) => block.id);
    final notes = blocks
        .where(
          (block) =>
              block is HeadingBlock ||
              (block is NoteBlock && !block.isQuickNote),
        )
        .map((block) => block.id);
    final hasNotes = blocks.whereType<NoteBlock>().any(
      (block) => !block.isQuickNote,
    );
    if (hasNotes) {
      infer(SermonModuleKind.notes, notes);
    }
    final script = blocks
        .where(
          (block) =>
              block is HeadingBlock ||
              (block is! NoteBlock &&
                  block is! TitleBlock &&
                  block is! DividerBlock),
        )
        .map((block) => block.id);
    final hasScript = blocks.any(
      (block) =>
          block is! HeadingBlock &&
          block is! NoteBlock &&
          block is! TitleBlock &&
          block is! DividerBlock,
    );
    if (hasScript) {
      infer(SermonModuleKind.script, script);
    }
    if (headings.isNotEmpty && !hasNotes && !hasScript) {
      // In the legacy document model headings were shared by Notes and Script.
      // A heading-only sermon therefore belongs to both editors.
      infer(SermonModuleKind.notes, headings);
      infer(SermonModuleKind.script, headings);
    }
    if (presentation.slides.isNotEmpty) {
      infer(SermonModuleKind.presentation, const <String>[]);
    }
    final noteIds = notes.toList(growable: false);
    final scriptIds = script.toList(growable: false);
    final synchronized = [
      for (final module in result)
        module.copyWith(
          blockIds: switch (module.kind) {
            SermonModuleKind.notes => noteIds,
            SermonModuleKind.script => scriptIds,
            SermonModuleKind.presentation => const [],
          },
        ),
    ]..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
    return List.unmodifiable(synchronized);
  }

  SermonDocument copyWith({
    int? schemaVersion,
    List<DocumentBlock>? blocks,
    PresentationDeck? presentation,
    List<SermonModule>? modules,
  }) => SermonDocument(
    schemaVersion: schemaVersion ?? this.schemaVersion,
    blocks: blocks ?? this.blocks,
    presentation: presentation ?? this.presentation,
    modules: modules ?? this.modules,
  );

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
    'presentation': presentation.toJson(),
    'modules': effectiveModules
        .map((module) => module.toJson())
        .toList(growable: false),
  };

  factory SermonDocument.fromJson(Map<String, Object?> json) {
    final blocks = (json['blocks']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .map(DocumentBlock.fromJson)
        .toList(growable: false);
    final modules = (json['modules'] as List<Object?>? ?? const [])
        .whereType<Map<String, Object?>>()
        .map(SermonModule.fromJson)
        .toList(growable: false);
    final blockOrder = {
      for (var index = 0; index < blocks.length; index++)
        blocks[index].id: index,
    };
    return SermonDocument(
      schemaVersion: json['schemaVersion']! as int,
      blocks: blocks,
      presentation: json['presentation'] is Map<String, Object?>
          ? PresentationDeck.fromJson(
              json['presentation']! as Map<String, Object?>,
            )
          : const PresentationDeck(),
      modules: [
        for (final module in modules)
          if (module.id.startsWith('legacy-'))
            module.copyWith(
              blockIds: [...module.blockIds]
                ..sort(
                  (left, right) => (blockOrder[left] ?? 1 << 30).compareTo(
                    blockOrder[right] ?? 1 << 30,
                  ),
                ),
            )
          else
            module,
      ],
    );
  }

  String get plainText => blocks.map((block) => block.plainText).join('\n');
  int get wordCount => countWords(plainText);
  Duration estimatedDuration({int wordsPerMinute = 120}) => Duration(
    seconds: wordCount == 0 ? 0 : (wordCount * 60 / wordsPerMinute).ceil(),
  );
}

class SermonDocumentIntegrityIssue {
  const SermonDocumentIntegrityIssue(this.code, this.message);

  final String code;
  final String message;
}

extension SermonDocumentV2 on SermonDocument {
  SermonDocument migrateToV2({
    required String sermonId,
    required DateTime fallbackCreatedAt,
  }) {
    if (schemaVersion >= 2) {
      final ownedSlideIds = modules.expand((module) => module.slideIds).toSet();
      final orphanSlideIds = presentation.slides
          .map((slide) => slide.id)
          .where((id) => !ownedSlideIds.contains(id))
          .toList(growable: false);
      if (orphanSlideIds.isEmpty) return this;
      final presentationModule = modules
          .where((module) => module.kind == SermonModuleKind.presentation)
          .firstOrNull;
      if (presentationModule != null) {
        return copyWith(
          modules: [
            for (final module in modules)
              if (module.id == presentationModule.id)
                module.copyWith(
                  slideIds: [...module.slideIds, ...orphanSlideIds],
                )
              else
                module,
          ],
        );
      }
      return copyWith(
        modules: [
          ...modules,
          SermonModule(
            id: 'recovered-presentation-$sermonId',
            kind: SermonModuleKind.presentation,
            title: '',
            sortOrder: modules.length,
            slideIds: orphanSlideIds,
            createdAt: fallbackCreatedAt,
            updatedAt: fallbackCreatedAt,
          ),
        ],
      );
    }
    final legacyModules = effectiveModules;
    if (legacyModules.isEmpty) {
      return copyWith(schemaVersion: SermonDocument.currentSchemaVersion);
    }
    final linkedGroupId = legacyModules.length > 1
        ? 'legacy-link-$sermonId'
        : null;
    final allSlideIds = presentation.slides
        .map((slide) => slide.id)
        .toList(growable: false);
    var assignedPresentationSlides = false;
    final migratedModules = <SermonModule>[];
    for (var index = 0; index < legacyModules.length; index++) {
      final module = legacyModules[index];
      final ownedBlocks = blocks
          .where((block) => module.blockIds.contains(block.id))
          .toList(growable: false);
      final createdAt =
          module.createdAt ??
          ownedBlocks
              .map((block) => block.createdAt)
              .fold<DateTime?>(
                null,
                (oldest, date) =>
                    oldest == null || date.isBefore(oldest) ? date : oldest,
              ) ??
          fallbackCreatedAt;
      final genericTitle = module.title.trim().toLowerCase();
      final title =
          {
            'notizen',
            'notes',
            'skript',
            'script',
            'präsentation',
            'presentation',
          }.contains(genericTitle)
          ? ''
          : module.title;
      final slideIds =
          module.kind == SermonModuleKind.presentation &&
              !assignedPresentationSlides
          ? allSlideIds
          : module.slideIds;
      if (module.kind == SermonModuleKind.presentation) {
        assignedPresentationSlides = true;
      }
      migratedModules.add(
        module.copyWith(
          title: title,
          sortOrder: index,
          blockIds: module.blockIds,
          slideIds: slideIds,
          linkGroupId: linkedGroupId,
          createdAt: createdAt,
          updatedAt: module.updatedAt ?? createdAt,
        ),
      );
    }
    return SermonDocument(
      schemaVersion: SermonDocument.currentSchemaVersion,
      blocks: blocks,
      presentation: presentation,
      modules: migratedModules,
    );
  }

  List<SermonDocumentIntegrityIssue> validateV2() {
    if (schemaVersion < 2) return const [];
    final issues = <SermonDocumentIntegrityIssue>[];
    final moduleIds = <String>{};
    final blockIds = blocks.map((block) => block.id).toSet();
    final slideIds = presentation.slides.map((slide) => slide.id).toSet();
    final blockOwners = <String, List<SermonModule>>{};
    final slideOwners = <String, List<SermonModule>>{};
    for (final module in modules) {
      if (!moduleIds.add(module.id)) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'duplicate-module',
            'Die Inhalts-ID ${module.id} ist mehrfach vorhanden.',
          ),
        );
      }
      for (final id in module.blockIds) {
        if (!blockIds.contains(id)) {
          issues.add(
            SermonDocumentIntegrityIssue(
              'missing-block',
              'Der Inhalt ${module.id} verweist auf den fehlenden Block $id.',
            ),
          );
          continue;
        }
        blockOwners.putIfAbsent(id, () => []).add(module);
      }
      for (final id in module.slideIds) {
        if (!slideIds.contains(id)) {
          issues.add(
            SermonDocumentIntegrityIssue(
              'missing-slide',
              'Der Inhalt ${module.id} verweist auf die fehlende Folie $id.',
            ),
          );
          continue;
        }
        slideOwners.putIfAbsent(id, () => []).add(module);
      }
    }
    for (final module in modules) {
      final rootId = module.versionRootId;
      if (rootId == null) continue;
      final root = modules
          .where((candidate) => candidate.id == rootId)
          .firstOrNull;
      if (root == null) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'missing-version-root',
            'Die Inhaltsversion ${module.id} verweist auf den fehlenden Ursprung $rootId.',
          ),
        );
      } else if (root.kind != module.kind) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'version-kind-mismatch',
            'Die Inhaltsversion ${module.id} hat einen anderen Typ als ihr Ursprung $rootId.',
          ),
        );
      }
    }
    final blocksById = {for (final block in blocks) block.id: block};
    for (final entry in blockOwners.entries) {
      final owners = entry.value;
      if (owners.length < 2) continue;
      final block = blocksById[entry.key];
      final groupIds = owners.map((module) => module.linkGroupId).toSet();
      if (block is! HeadingBlock ||
          groupIds.length != 1 ||
          groupIds.single == null) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'invalid-shared-block',
            'Nur Überschriften derselben Verknüpfungsgruppe dürfen geteilt werden (${entry.key}).',
          ),
        );
      }
    }
    for (final entry in slideOwners.entries) {
      if (entry.value.length != 1) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'shared-slide',
            'Die Folie ${entry.key} gehört zu mehreren Präsentationen.',
          ),
        );
      }
    }
    for (final slide in presentation.slides) {
      final anchor = slide.anchor;
      if (anchor == null || anchor.moduleId == null) continue;
      final source = modules
          .where((module) => module.id == anchor.moduleId)
          .firstOrNull;
      if (source == null || !source.blockIds.contains(anchor.blockId)) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'invalid-slide-anchor',
            'Der Folienanker ${slide.id} verweist nicht auf einen gültigen Inhaltsblock.',
          ),
        );
        continue;
      }
      final owners = slideOwners[slide.id] ?? const <SermonModule>[];
      final presentationModule = owners.length == 1 ? owners.single : null;
      if (presentationModule == null ||
          !modulesAreLinked(presentationModule.id, source.id)) {
        issues.add(
          SermonDocumentIntegrityIssue(
            'unlinked-slide-anchor',
            'Die Folie ${slide.id} ist mit einem unverknüpften Inhalt verankert.',
          ),
        );
      }
    }
    return List.unmodifiable(issues);
  }
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
