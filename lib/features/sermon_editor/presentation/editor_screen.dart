import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/outline.dart';
import 'package:sermonary/features/sermon_editor/domain/raw_outline_logic.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

enum EditorMode { raw, script }

enum SaveStatus { saved, saving, unsaved, error }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    required this.sermonId,
    required this.mode,
    super.key,
  });
  final String sermonId;
  final EditorMode mode;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  Sermon? _draft;
  Timer? _saveTimer;
  SaveStatus _saveStatus = SaveStatus.saved;
  bool _showOutline = true;
  bool _showInspector = true;
  Future<void> _writeQueue = Future.value();
  static const _uuid = Uuid();

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) unawaited(_save(manual: true));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_draft != null && _saveStatus != SaveStatus.saved) {
      unawaited(_save(updateUi: false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sermonAsync = ref.watch(sermonProvider(widget.sermonId));
    return sermonAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Predigt konnte nicht geladen werden: $error'),
        ),
      ),
      data: (stored) {
        if (stored == null) {
          return const Scaffold(
            body: Center(child: Text('Predigt nicht gefunden.')),
          );
        }
        _draft ??= stored;
        final sermon = _draft!;
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () =>
                _save(manual: true),
            const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
                _switchMode(EditorMode.raw),
            const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
                _switchMode(EditorMode.script),
            const SingleActivator(
              LogicalKeyboardKey.digit3,
              meta: true,
            ): _openLive,
            const SingleActivator(
              LogicalKeyboardKey.backslash,
              meta: true,
            ): () =>
                setState(() => _showOutline = !_showOutline),
            const SingleActivator(
              LogicalKeyboardKey.keyB,
              meta: true,
              shift: true,
            ): _showBibleDialog,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  tooltip: 'Zur Bibliothek',
                  onPressed: () async {
                    await _save();
                    if (!context.mounted) return;
                    context.go('/library');
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(
                  sermon.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                centerTitle: false,
                actions: [
                  _SaveIndicator(status: _saveStatus),
                  const SizedBox(width: 8),
                  SegmentedButton<EditorMode>(
                    segments: const [
                      ButtonSegment(
                        value: EditorMode.raw,
                        label: Text('Raw'),
                        icon: Icon(Icons.format_list_bulleted, size: 18),
                      ),
                      ButtonSegment(
                        value: EditorMode.script,
                        label: Text('Script'),
                        icon: Icon(Icons.article_outlined, size: 18),
                      ),
                    ],
                    selected: {widget.mode},
                    onSelectionChanged: (selection) =>
                        _switchMode(selection.first),
                    showSelectedIcon: false,
                  ),
                  IconButton(
                    tooltip: 'Livemode (⌘3)',
                    onPressed: _openLive,
                    icon: const Icon(Icons.play_circle_outline),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Export',
                    icon: const Icon(Icons.ios_share_outlined),
                    onSelected: _export,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'markdown',
                        child: Text('Als Markdown exportieren'),
                      ),
                      PopupMenuItem(
                        value: 'text',
                        child: Text('Als Text exportieren'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Inspector',
                    onPressed: () =>
                        setState(() => _showInspector = !_showInspector),
                    icon: const Icon(Icons.tune),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;
                  return Row(
                    children: [
                      if (_showOutline && wide)
                        SizedBox(
                          width: 230,
                          child: _OutlinePanel(document: sermon.document),
                        ),
                      Expanded(
                        child: widget.mode == EditorMode.raw
                            ? _RawEditor(
                                document: sermon.document,
                                onChanged: _setDocument,
                              )
                            : _ScriptEditor(
                                document: sermon.document,
                                onChanged: _setDocument,
                                onInsertBible: _showBibleDialog,
                              ),
                      ),
                      if (_showInspector && wide)
                        SizedBox(
                          width: 300,
                          child: _MetadataInspector(
                            sermon: sermon,
                            onChanged: _setSermon,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _setSermon(Sermon sermon) {
    setState(() {
      _draft = sermon;
      _saveStatus = SaveStatus.unsaved;
    });
    _scheduleSave();
  }

  void _setDocument(SermonDocument document) {
    final sermon = _draft;
    if (sermon == null) return;
    _setSermon(sermon.copyWith(document: document));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(AppConfig.autosaveDelay, _save);
  }

  Future<void> _save({bool manual = false, bool updateUi = true}) async {
    _saveTimer?.cancel();
    final sermon = _draft;
    if (sermon == null || (_saveStatus == SaveStatus.saved && !manual)) return;
    if (updateUi && mounted) setState(() => _saveStatus = SaveStatus.saving);
    final repository = ref.read(sermonRepositoryProvider);
    final previousWrite = _writeQueue;
    _writeQueue = () async {
      try {
        await previousWrite;
      } on Object {
        // Der frühere Aufrufer hat diesen Fehler bereits sichtbar gemeldet.
        // Die Warteschlange darf einen expliziten Wiederholungsversuch nicht blockieren.
      }
      if (manual) await repository.saveVersion(sermon.id, 'manual-save');
      await repository.update(sermon);
    }();
    try {
      await _writeQueue;
      if (updateUi && mounted) setState(() => _saveStatus = SaveStatus.saved);
    } on Object {
      if (updateUi && mounted) {
        setState(() => _saveStatus = SaveStatus.error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Speichern fehlgeschlagen. Die Änderung bleibt im Editor erhalten.',
            ),
            action: SnackBarAction(label: 'Erneut', onPressed: _save),
          ),
        );
      }
    }
  }

  Future<void> _switchMode(EditorMode mode) async {
    if (mode == widget.mode) return;
    await _save();
    if (mounted) context.go('/sermons/${widget.sermonId}/${mode.name}');
  }

  Future<void> _openLive() async {
    await _save();
    if (mounted) context.go('/sermons/${widget.sermonId}/live');
  }

  Future<void> _export(String format) async {
    final sermon = _draft;
    if (sermon == null) return;
    final service = ref.read(exportServiceProvider);
    final content = format == 'markdown'
        ? service.exportMarkdown(sermon, includeInternalNotes: false)
        : service.exportPlainText(sermon, includeInternalNotes: false);
    final extension = format == 'markdown' ? 'md' : 'txt';
    final location = await getSaveLocation(
      suggestedName: '${_safeFileName(sermon.title)}.$extension',
      acceptedTypeGroups: [
        XTypeGroup(
          label: format == 'markdown' ? 'Markdown' : 'Text',
          extensions: [extension],
        ),
      ],
    );
    if (location == null) return;
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content)),
      mimeType: 'text/plain',
    );
    await file.saveTo(location.path);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Export gespeichert.')));
    }
  }

  String _safeFileName(String title) => title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');

  Future<void> _showBibleDialog() async {
    final referenceController = TextEditingController();
    final textController = TextEditingController();
    final provider = ref.read(bibleProviderProvider);
    final result = await showDialog<(BibleReference, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bibelstelle einfügen'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: referenceController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Stelle',
                  hintText: 'z. B. Joh 3,16–18',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Text',
                  hintText: 'Eigener Text oder Platzhalter',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Der Prototyp lädt keine urheberrechtlich geschützten Bibeltexte.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final reference = BibleReferenceParser().parse(
                referenceController.text,
              );
              if (reference != null) {
                var text = textController.text;
                if (text.trim().isEmpty) {
                  final translations = await provider.listTranslations();
                  if (translations.isNotEmpty) {
                    final passage = await provider.getPassage(
                      reference,
                      translations.first.id,
                    );
                    text = passage?.text ?? '';
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context, (reference, text));
                }
              }
            },
            child: const Text('Einfügen'),
          ),
        ],
      ),
    );
    if (result == null || _draft == null) return;
    final now = DateTime.now().toUtc();
    _setDocument(
      SermonDocument(
        schemaVersion: _draft!.document.schemaVersion,
        blocks: [
          ..._draft!.document.blocks,
          BibleQuoteBlock(
            id: _uuid.v4(),
            reference: result.$1,
            translationId: 'manual',
            translationLabel: 'Manuell',
            text: result.$2,
            showVerseNumbers: false,
            copyrightNotice: 'Manuell eingefügter Text',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      ),
    );
  }
}

class _RawEditor extends StatelessWidget {
  const _RawEditor({required this.document, required this.onChanged});
  final SermonDocument document;
  final ValueChanged<SermonDocument> onChanged;
  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final rawIndex = document.blocks.indexWhere(
      (block) => block is BulletListBlock,
    );
    final rawBlock = rawIndex < 0
        ? null
        : document.blocks[rawIndex] as BulletListBlock;
    final lines = rawBlock == null
        ? const <RawLine>[]
        : flattenBulletItems(rawBlock.items);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.editorWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gliederung',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tab einrücken · ⇧Tab ausrücken · ⌘⇧↑/↓ verschieben',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              if (lines.isEmpty)
                OutlinedButton.icon(
                  key: const Key('add-first-raw-point'),
                  onPressed: () => _replace(
                    rawIndex,
                    rawBlock,
                    [
                      RawLine(
                        id: _uuid.v4(),
                        text: '',
                        depth: 0,
                        collapsed: false,
                      ),
                    ],
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Ersten Stichpunkt anlegen'),
                )
              else
                for (var index = 0; index < lines.length; index++)
                  _RawLineField(
                    key: ValueKey(lines[index].id),
                    line: lines[index],
                    index: index,
                    onTextChanged: (text) {
                      final next = [...lines];
                      next[index] = next[index].copyWith(text: text);
                      _replace(rawIndex, rawBlock, next);
                    },
                    onEnter: () {
                      final next = [...lines]
                        ..insert(
                          index + 1,
                          RawLine(
                            id: _uuid.v4(),
                            text: '',
                            depth: lines[index].depth,
                            collapsed: false,
                          ),
                        );
                      _replace(rawIndex, rawBlock, next);
                    },
                    onIndent: () => _replace(
                      rawIndex,
                      rawBlock,
                      indentRawLine(lines, index),
                    ),
                    onOutdent: () => _replace(
                      rawIndex,
                      rawBlock,
                      outdentRawLine(lines, index),
                    ),
                    onMove: (offset) => _replace(
                      rawIndex,
                      rawBlock,
                      moveRawLine(lines, index, offset),
                    ),
                    onCollapse: () {
                      final next = [...lines];
                      next[index] = lines[index].copyWith(
                        collapsed: !lines[index].collapsed,
                      );
                      _replace(rawIndex, rawBlock, next);
                    },
                  ),
              const SizedBox(height: 24),
              Text(
                '${document.wordCount} Wörter · ca. ${document.estimatedDuration().inMinutes + 1} Min.',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _replace(
    int rawIndex,
    BulletListBlock? existing,
    List<RawLine> lines,
  ) {
    final now = DateTime.now().toUtc();
    final block = BulletListBlock(
      id: existing?.id ?? _uuid.v4(),
      ordered: existing?.ordered ?? false,
      items: buildBulletTree(lines),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final blocks = [...document.blocks];
    if (rawIndex < 0) {
      blocks.add(block);
    } else {
      blocks[rawIndex] = block;
    }
    onChanged(
      SermonDocument(schemaVersion: document.schemaVersion, blocks: blocks),
    );
  }
}

class _RawLineField extends StatefulWidget {
  const _RawLineField({
    required this.line,
    required this.index,
    required this.onTextChanged,
    required this.onEnter,
    required this.onIndent,
    required this.onOutdent,
    required this.onMove,
    required this.onCollapse,
    super.key,
  });
  final RawLine line;
  final int index;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onEnter;
  final VoidCallback onIndent;
  final VoidCallback onOutdent;
  final ValueChanged<int> onMove;
  final VoidCallback onCollapse;

  @override
  State<_RawLineField> createState() => _RawLineFieldState();
}

class _RawLineFieldState extends State<_RawLineField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.line.text,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: widget.line.depth * 28, bottom: 6),
    child: Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final keyboard = HardwareKeyboard.instance;
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          keyboard.isShiftPressed ? widget.onOutdent() : widget.onIndent();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            _controller.text.isEmpty) {
          widget.onOutdent();
          return KeyEventResult.handled;
        }
        if (keyboard.isMetaPressed && keyboard.isShiftPressed) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            widget.onMove(-1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            widget.onMove(1);
            return KeyEventResult.handled;
          }
        }
        if (keyboard.isMetaPressed &&
            keyboard.isAltPressed &&
            event.logicalKey == LogicalKeyboardKey.arrowRight) {
          widget.onCollapse();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Icon(
              widget.line.depth == 0 ? Icons.circle : Icons.circle_outlined,
              size: widget.line.depth == 0 ? 9 : 8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: Key('raw-line-${widget.line.id}'),
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
              ),
              style: TextStyle(
                fontSize: widget.line.depth == 0 ? 18 : 16,
                fontWeight: widget.line.depth == 0
                    ? FontWeight.w600
                    : FontWeight.normal,
                height: 1.5,
              ),
              textInputAction: TextInputAction.next,
              onChanged: widget.onTextChanged,
              onSubmitted: (_) => widget.onEnter(),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScriptEditor extends StatelessWidget {
  const _ScriptEditor({
    required this.document,
    required this.onChanged,
    required this.onInsertBible,
  });
  final SermonDocument document;
  final ValueChanged<SermonDocument> onChanged;
  final VoidCallback onInsertBible;
  static const _uuid = Uuid();

  @override
  Widget build(BuildContext context) {
    final blocks = document.blocks
        .where((block) => block is! BulletListBlock)
        .toList(growable: false);
    return Column(
      children: [
        _FormatBar(onAdd: _addBlock, onInsertBible: onInsertBible),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 42),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.editorWidth,
                ),
                child: Column(
                  children: [
                    if (blocks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80),
                        child: Text(
                          'Beginne mit einem Absatz oder einer Überschrift.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final block in blocks)
                      _ScriptBlockField(
                        key: ValueKey(block.id),
                        block: block,
                        onChanged: (next) => _replaceBlock(block.id, next),
                        onDelete: () => _deleteBlock(block.id),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _addBlock(String type) {
    final now = DateTime.now().toUtc();
    final block = switch (type) {
      'h1' => HeadingBlock(
        id: _uuid.v4(),
        level: 1,
        text: '',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      'h2' => HeadingBlock(
        id: _uuid.v4(),
        level: 2,
        text: '',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      'h3' => HeadingBlock(
        id: _uuid.v4(),
        level: 3,
        text: '',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      'quote' => QuoteBlock(
        id: _uuid.v4(),
        text: '',
        author: '',
        source: '',
        createdAt: now,
        updatedAt: now,
      ),
      'note' => NoteBlock(
        id: _uuid.v4(),
        text: '',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
      'divider' => DividerBlock(
        id: _uuid.v4(),
        createdAt: now,
        updatedAt: now,
      ),
      _ => ParagraphBlock(
        id: _uuid.v4(),
        text: '',
        semanticRole: ParagraphRole.normal,
        createdAt: now,
        updatedAt: now,
      ),
    };
    onChanged(
      SermonDocument(
        schemaVersion: document.schemaVersion,
        blocks: [...document.blocks, block],
      ),
    );
  }

  void _replaceBlock(String id, DocumentBlock block) => onChanged(
    SermonDocument(
      schemaVersion: document.schemaVersion,
      blocks: [
        for (final candidate in document.blocks)
          if (candidate.id == id) block else candidate,
      ],
    ),
  );

  void _deleteBlock(String id) => onChanged(
    SermonDocument(
      schemaVersion: document.schemaVersion,
      blocks: document.blocks
          .where((candidate) => candidate.id != id)
          .toList(growable: false),
    ),
  );
}

class _FormatBar extends StatelessWidget {
  const _FormatBar({required this.onAdd, required this.onInsertBible});
  final ValueChanged<String> onAdd;
  final VoidCallback onInsertBible;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Block hinzufügen',
            onSelected: onAdd,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'paragraph', child: Text('Absatz')),
              PopupMenuItem(value: 'h1', child: Text('Überschrift 1')),
              PopupMenuItem(value: 'h2', child: Text('Überschrift 2')),
              PopupMenuItem(value: 'h3', child: Text('Überschrift 3')),
              PopupMenuItem(value: 'quote', child: Text('Zitat')),
              PopupMenuItem(value: 'note', child: Text('Interne Notiz')),
              PopupMenuItem(value: 'divider', child: Text('Trenner')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Block'),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Bibelstelle einfügen (⌘⇧B)',
            onPressed: onInsertBible,
            icon: const Icon(Icons.menu_book_outlined),
          ),
        ],
      ),
    ),
  );
}

class _ScriptBlockField extends StatefulWidget {
  const _ScriptBlockField({
    required this.block,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });
  final DocumentBlock block;
  final ValueChanged<DocumentBlock> onChanged;
  final VoidCallback onDelete;

  @override
  State<_ScriptBlockField> createState() => _ScriptBlockFieldState();
}

class _ScriptBlockFieldState extends State<_ScriptBlockField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.block.plainText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final block = widget.block;
    if (block is DividerBlock) {
      return Row(
        children: [
          const Expanded(child: Divider(height: 40)),
          IconButton(
            tooltip: 'Block löschen',
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, size: 16),
          ),
        ],
      );
    }
    final style = switch (block) {
      HeadingBlock(level: 1) => Theme.of(context).textTheme.headlineLarge,
      HeadingBlock(level: 2) => Theme.of(context).textTheme.headlineMedium,
      HeadingBlock() => Theme.of(context).textTheme.headlineSmall,
      QuoteBlock() => Theme.of(
        context,
      ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
      BibleQuoteBlock() => Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontStyle: FontStyle.italic,
      ),
      NoteBlock() => Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
      ParagraphBlock(:final isBold, :final isItalic) =>
        Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      _ => Theme.of(context).textTheme.bodyLarge,
    };
    return Card(
      color: block is NoteBlock
          ? Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.5)
          : Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: Key('script-block-${block.id}'),
                controller: _controller,
                minLines: 1,
                maxLines: null,
                style: style,
                decoration: InputDecoration(
                  filled: false,
                  border: InputBorder.none,
                  hintText: _hint(block),
                ),
                onChanged: (text) => widget.onChanged(_withText(block, text)),
              ),
            ),
            if (block is ParagraphBlock) ...[
              IconButton(
                tooltip: 'Fett (ganzer Block)',
                onPressed: () => widget.onChanged(
                  ParagraphBlock(
                    id: block.id,
                    text: block.text,
                    semanticRole: block.semanticRole,
                    isBold: !block.isBold,
                    isItalic: block.isItalic,
                    createdAt: block.createdAt,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                ),
                icon: const Icon(Icons.format_bold, size: 18),
              ),
              IconButton(
                tooltip: 'Kursiv (ganzer Block)',
                onPressed: () => widget.onChanged(
                  ParagraphBlock(
                    id: block.id,
                    text: block.text,
                    semanticRole: block.semanticRole,
                    isBold: block.isBold,
                    isItalic: !block.isItalic,
                    createdAt: block.createdAt,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                ),
                icon: const Icon(Icons.format_italic, size: 18),
              ),
            ],
            IconButton(
              tooltip: 'Block löschen',
              onPressed: widget.onDelete,
              icon: const Icon(Icons.close, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _hint(DocumentBlock block) => switch (block) {
    HeadingBlock() => 'Überschrift',
    QuoteBlock() => 'Zitat',
    BibleQuoteBlock() => 'Bibeltext oder Platzhalter',
    NoteBlock() => 'Interne Notiz',
    _ => 'Schreiben …',
  };

  DocumentBlock _withText(DocumentBlock block, String text) {
    final now = DateTime.now().toUtc();
    return switch (block) {
      HeadingBlock() => HeadingBlock(
        id: block.id,
        level: block.level,
        text: text,
        collapsed: block.collapsed,
        createdAt: block.createdAt,
        updatedAt: now,
      ),
      ParagraphBlock() => ParagraphBlock(
        id: block.id,
        text: text,
        semanticRole: block.semanticRole,
        isBold: block.isBold,
        isItalic: block.isItalic,
        createdAt: block.createdAt,
        updatedAt: now,
      ),
      QuoteBlock() => QuoteBlock(
        id: block.id,
        text: text,
        author: block.author,
        source: block.source,
        createdAt: block.createdAt,
        updatedAt: now,
      ),
      BibleQuoteBlock() => BibleQuoteBlock(
        id: block.id,
        reference: block.reference,
        translationId: block.translationId,
        translationLabel: block.translationLabel,
        text: text,
        showVerseNumbers: block.showVerseNumbers,
        copyrightNotice: block.copyrightNotice,
        createdAt: block.createdAt,
        updatedAt: now,
      ),
      NoteBlock() => NoteBlock(
        id: block.id,
        text: text,
        visibility: block.visibility,
        createdAt: block.createdAt,
        updatedAt: now,
      ),
      _ => block,
    };
  }
}

class _OutlinePanel extends StatelessWidget {
  const _OutlinePanel({required this.document});
  final SermonDocument document;
  @override
  Widget build(BuildContext context) {
    final entries = buildOutline(document);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Expanded(
              child: entries.isEmpty
                  ? const Text('Überschriften erscheinen hier automatisch.')
                  : ListView(
                      children: [
                        for (final entry in entries)
                          Padding(
                            padding: EdgeInsets.only(
                              left: entry.level * 10,
                              bottom: 10,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${entry.wordCount} Wörter · ${entry.estimatedMinutes.toStringAsFixed(1)} Min.',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetadataInspector extends StatelessWidget {
  const _MetadataInspector({required this.sermon, required this.onChanged});
  final Sermon sermon;
  final ValueChanged<Sermon> onChanged;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('Details', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        TextFormField(
          key: ValueKey('title-${sermon.id}'),
          initialValue: sermon.title,
          decoration: const InputDecoration(labelText: 'Titel'),
          onChanged: (value) => onChanged(sermon.copyWith(title: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.subtitle,
          decoration: const InputDecoration(labelText: 'Untertitel'),
          onChanged: (value) => onChanged(sermon.copyWith(subtitle: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.primaryBibleReference?.displayText ?? '',
          decoration: const InputDecoration(labelText: 'Hauptbibelstelle'),
          onChanged: (value) {
            final parsed = BibleReferenceParser().parse(value);
            if (parsed != null) {
              onChanged(sermon.copyWith(primaryBibleReference: parsed));
            }
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SermonStatus>(
          initialValue: sermon.status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [
            for (final status in SermonStatus.values)
              DropdownMenuItem(value: status, child: Text(_statusName(status))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(sermon.copyWith(status: value));
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SermonType>(
          initialValue: sermon.sermonType,
          decoration: const InputDecoration(labelText: 'Predigtart'),
          items: [
            for (final type in SermonType.values)
              DropdownMenuItem(value: type, child: Text(_typeName(type))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(sermon.copyWith(sermonType: value));
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.location ?? '',
          decoration: const InputDecoration(labelText: 'Ort'),
          onChanged: (value) => onChanged(sermon.copyWith(location: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.audience ?? '',
          decoration: const InputDecoration(labelText: 'Zielgruppe'),
          onChanged: (value) => onChanged(sermon.copyWith(audience: value)),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.plannedDurationMinutes?.toString() ?? '',
          decoration: const InputDecoration(labelText: 'Geplante Minuten'),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final minutes = int.tryParse(value);
            if (minutes != null) {
              onChanged(sermon.copyWith(plannedDurationMinutes: minutes));
            }
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.topics.join(', '),
          decoration: const InputDecoration(labelText: 'Themen'),
          onChanged: (value) => onChanged(
            sermon.copyWith(topics: _commaSeparated(value)),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: sermon.tags.join(', '),
          decoration: const InputDecoration(labelText: 'Tags'),
          onChanged: (value) =>
              onChanged(sermon.copyWith(tags: _commaSeparated(value))),
        ),
      ],
    ),
  );

  List<String> _commaSeparated(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  String _statusName(SermonStatus status) => switch (status) {
    SermonStatus.draft => 'Entwurf',
    SermonStatus.inProgress => 'In Bearbeitung',
    SermonStatus.ready => 'Bereit',
    SermonStatus.preached => 'Gehalten',
    SermonStatus.archived => 'Archiviert',
  };

  String _typeName(SermonType type) => switch (type) {
    SermonType.expository => 'Auslegung',
    SermonType.topical => 'Themenpredigt',
    SermonType.evangelistic => 'Evangelistisch',
    SermonType.devotional => 'Andacht',
    SermonType.bibleStudy => 'Bibelstunde',
    SermonType.wedding => 'Trauung',
    SermonType.funeral => 'Trauerfeier',
    SermonType.children => 'Kinder',
    SermonType.seminar => 'Seminar',
    SermonType.counseling => 'Seelsorge',
    SermonType.other => 'Andere',
  };
}

class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.status});
  final SaveStatus status;
  @override
  Widget build(BuildContext context) => Semantics(
    label: switch (status) {
      SaveStatus.saved => 'Gespeichert',
      SaveStatus.saving => 'Wird gespeichert',
      SaveStatus.unsaved => 'Nicht gespeichert',
      SaveStatus.error => 'Speicherfehler',
    },
    child: Row(
      children: [
        Icon(
          switch (status) {
            SaveStatus.saved => Icons.cloud_done_outlined,
            SaveStatus.saving => Icons.sync,
            SaveStatus.unsaved => Icons.cloud_off_outlined,
            SaveStatus.error => Icons.error_outline,
          },
          size: 16,
          color: status == SaveStatus.error
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Text(
          switch (status) {
            SaveStatus.saved => 'Gespeichert',
            SaveStatus.saving => 'Wird gespeichert …',
            SaveStatus.unsaved => 'Nicht gespeichert',
            SaveStatus.error => 'Speicherfehler',
          },
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );
}
