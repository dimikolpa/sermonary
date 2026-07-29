import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

enum WorkspaceView { outline, notes, script }

enum _WorkspaceGroup { book, series, talk, shortTopic, introduction }

enum _InlineFormat { bold, italic, highlight }

class SermonWorkspaceScreen extends ConsumerStatefulWidget {
  const SermonWorkspaceScreen({
    super.key,
    this.sermonId,
    this.initialView = WorkspaceView.outline,
  });

  final String? sermonId;
  final WorkspaceView initialView;

  @override
  ConsumerState<SermonWorkspaceScreen> createState() =>
      _SermonWorkspaceScreenState();
}

class _SermonWorkspaceScreenState extends ConsumerState<SermonWorkspaceScreen> {
  late WorkspaceView _view = widget.initialView;
  bool _splitActive = false;
  bool _focusMode = false;
  bool _saving = false;
  bool _selectionInitialized = false;
  String? _selectedId;
  String? _navKey;
  String? _loadedSeriesId;
  Sermon? _draft;
  Timer? _saveTimer;
  late final SermonRepository _repository;
  String? _activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> _richKeys = {};

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sermonRepositoryProvider);
    _selectedId = widget.sermonId;
    _selectionInitialized = widget.sermonId != null;
  }

  @override
  void didUpdateWidget(SermonWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sermonId != widget.sermonId) {
      _selectedId = widget.sermonId;
      _selectionInitialized = widget.sermonId != null;
      _draft = null;
      _loadedSeriesId = null;
      _activeBlockId = null;
    }
    if (oldWidget.initialView != widget.initialView) {
      _view = widget.initialView;
      _splitActive = false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    final draft = _draft;
    if (draft != null && _saving) {
      unawaited(_repository.update(draft));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapProvider);
    return ref
        .watch(sermonsProvider)
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 1)),
          ),
          error: (error, stack) => const Scaffold(
            body: Center(
              child: Text('Bibliothek konnte nicht geladen werden.'),
            ),
          ),
          data: _buildWorkspace,
        );
  }

  Widget _buildWorkspace(List<Sermon> allSermons) {
    final sermons = allSermons
        .where((sermon) => !sermon.isDeleted)
        .toList(growable: false);
    if (!_selectionInitialized && sermons.isNotEmpty) {
      _selectedId = sermons.first.id;
      _selectionInitialized = true;
    } else if (_selectedId != null &&
        !sermons.any((sermon) => sermon.id == _selectedId)) {
      _selectedId = _entriesForNav(sermons).firstOrNull?.id;
      _draft = null;
      _loadedSeriesId = null;
      _activeBlockId = null;
    }
    final selectedId = _selectedId;
    final stored = sermons
        .where((sermon) => sermon.id == selectedId)
        .firstOrNull;
    if (stored != null && (_draft == null || _draft!.id != stored.id)) {
      _draft = _normalizeLegacyNotes(stored);
      _loadedSeriesId = stored.seriesId;
      _navKey ??= _navKeyFor(_draft!);
    }
    final selected = _draft;
    final visibleEntries = _entriesForNav(sermons);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
            _selectView(WorkspaceView.outline),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
            _selectView(WorkspaceView.notes),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
            _selectView(WorkspaceView.script),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                AnimatedContainer(
                  width: _focusMode ? 0 : AppSizes.sidebarWidth,
                  duration: AppMotion.normal,
                  curve: Curves.easeInOut,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: AppSizes.sidebarWidth,
                      maxWidth: AppSizes.sidebarWidth,
                      child: _NavigationColumn(
                        sermons: sermons,
                        selectedNavKey: _navKey,
                        onSelect: _selectNavigation,
                        onAddSeries: _addSeries,
                        isDark: Theme.of(context).brightness == Brightness.dark,
                        onToggleTheme: () {
                          final current = ref.read(themeModeProvider);
                          ref
                              .read(themeModeProvider.notifier)
                              .state = current == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                        },
                      ),
                    ),
                  ),
                ),
                if (!_focusMode) const VerticalDivider(width: 1),
                AnimatedContainer(
                  width: _focusMode ? 0 : AppSizes.entryListWidth,
                  duration: AppMotion.normal,
                  curve: Curves.easeInOut,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      minWidth: AppSizes.entryListWidth,
                      maxWidth: AppSizes.entryListWidth,
                      child: _EntryColumn(
                        label: _navLabel,
                        sermons: visibleEntries,
                        selectedId: selected?.id,
                        canDeleteSeries:
                            _navKey?.startsWith('series:') ?? false,
                        onDeleteSeries: _deleteCurrentSeries,
                        onCreate: _createEntry,
                        onSelect: _selectSermon,
                      ),
                    ),
                  ),
                ),
                if (!_focusMode) const VerticalDivider(width: 1),
                Expanded(
                  child: selected == null
                      ? _EmptyWorkspace(onCreate: _createEntry)
                      : Column(
                          children: [
                            _WorkspaceToolbar(
                              view: _view,
                              splitActive: _splitActive,
                              focusMode: _focusMode,
                              saving: _saving,
                              wordCount: _scriptWordCount(selected.document),
                              durationLabel: _durationLabel(
                                _scriptWordCount(selected.document),
                              ),
                              activeBlock: _activeBlock(selected.document),
                              onToggleFocus: () => setState(
                                () => _focusMode = !_focusMode,
                              ),
                              onSelectView: _selectView,
                              onChangeBlockType: _changeActiveBlockType,
                              onFormat: _applyInlineFormat,
                              onInsertBibleReference: _showBibleReferencePicker,
                              onLive: () => context.go(
                                '/sermons/${selected.id}/live',
                              ),
                              onPrint: () => context.go(
                                '/sermons/${selected.id}/print',
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.zero,
                                      child: _buildContent(selected),
                                    ),
                                  ),
                                  const _BottomFade(),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Sermon sermon) {
    if (_view == WorkspaceView.outline && !_splitActive) {
      return _OutlineView(
        sermon: sermon,
        onChanged: (next) => setState(() => _draft = next),
        onSave: _save,
      );
    }
    if (_splitActive) {
      return _SplitView(
        sermon: sermon,
        activeBlockId: _activeBlockId,
        richKeys: _richKeys,
        onActivate: _activateBlock,
        onUpdateBlock: _updateBlock,
        onInsertAfter: _insertBlockAfter,
        onDelete: _deleteBlock,
      );
    }
    if (_view == WorkspaceView.notes) {
      return _NotesView(
        sermon: sermon,
        activeBlockId: _activeBlockId,
        richKeys: _richKeys,
        onActivate: _activateBlock,
        onUpdateBlock: _updateBlock,
        onInsertAfter: _insertBlockAfter,
        onDelete: _deleteBlock,
      );
    }
    return _ScriptView(
      sermon: sermon,
      activeBlockId: _activeBlockId,
      richKeys: _richKeys,
      onActivate: _activateBlock,
      onUpdateSermon: _updateDraft,
      onUpdateBlock: _updateBlock,
      onInsertAfter: _insertBlockAfter,
      onDelete: _deleteBlock,
    );
  }

  Sermon _normalizeLegacyNotes(Sermon sermon) {
    if (!sermon.document.blocks.any((block) => block is BulletListBlock)) {
      return sermon;
    }
    final now = DateTime.now().toUtc();
    final normalized = <DocumentBlock>[];
    for (final block in sermon.document.blocks) {
      if (block is! BulletListBlock) {
        normalized.add(block);
        continue;
      }
      void append(List<BulletItem> items, int depth) {
        for (final item in items) {
          normalized.add(
            NoteBlock(
              id: item.id,
              text: item.text,
              visibility: NoteVisibility.editorOnly,
              depth: depth.clamp(0, 1),
              createdAt: block.createdAt,
              updatedAt: now,
            ),
          );
          append(item.children, depth + 1);
        }
      }

      append(block.items, 0);
    }
    return sermon.copyWith(
      document: SermonDocument(
        schemaVersion: sermon.document.schemaVersion,
        blocks: normalized,
      ),
    );
  }

  String _navKeyFor(Sermon sermon) {
    if (sermon.seriesId?.trim().isNotEmpty ?? false) {
      return 'series:${sermon.seriesId}';
    }
    return switch (sermon.contentKind) {
      ContentKind.talk => 'kind:talk',
      ContentKind.shortTopic => 'kind:short',
      ContentKind.introduction => 'kind:introduction',
      ContentKind.sermon =>
        sermon.primaryBibleReference == null
            ? 'kind:short'
            : 'book:${sermon.primaryBibleReference!.bookId}',
    };
  }

  List<Sermon> _entriesForNav(List<Sermon> sermons, {String? navigationKey}) {
    final key = navigationKey ?? _navKey;
    if (key == null) return sermons;
    if (key.startsWith('book:')) {
      final bookId = key.substring(5);
      return sermons
          .where(
            (sermon) =>
                sermon.contentKind == ContentKind.sermon &&
                sermon.seriesId == null &&
                sermon.primaryBibleReference?.bookId == bookId,
          )
          .toList(growable: false)
        ..sort(_comparePassages);
    }
    if (key.startsWith('series:')) {
      final series = key.substring(7);
      return sermons
          .where((sermon) => sermon.seriesId == series)
          .toList(growable: false);
    }
    final kind = key.substring(5);
    return sermons
        .where(
          (sermon) => switch (kind) {
            'talk' => sermon.contentKind == ContentKind.talk,
            'short' =>
              sermon.contentKind == ContentKind.shortTopic ||
                  (sermon.contentKind == ContentKind.sermon &&
                      sermon.primaryBibleReference == null &&
                      !(sermon.seriesId?.trim().isNotEmpty ?? false)),
            'introduction' => sermon.contentKind == ContentKind.introduction,
            _ => false,
          },
        )
        .toList(growable: false);
  }

  String get _navLabel {
    final key = _navKey;
    if (key == null) return 'Bibliothek';
    if (key.startsWith('book:')) {
      return BibleBookCatalog.labelFor(key.substring(5));
    }
    if (key.startsWith('series:')) return key.substring(7);
    return switch (key) {
      'kind:talk' => 'Vorträge',
      'kind:introduction' => 'Einleitungen',
      _ => 'Kurzthemen',
    };
  }

  int _comparePassages(Sermon left, Sermon right) {
    final a = left.primaryBibleReference;
    final b = right.primaryBibleReference;
    if (a == null || b == null) return left.title.compareTo(right.title);
    final chapter = a.startChapter.compareTo(b.startChapter);
    if (chapter != 0) return chapter;
    return (a.startVerse ?? 0).compareTo(b.startVerse ?? 0);
  }

  void _selectNavigation(String key) {
    final sermons = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final first = _entriesForNav(
      sermons.where((sermon) => !sermon.isDeleted).toList(),
      navigationKey: key,
    ).firstOrNull;
    unawaited(_save(reconcileNavigation: false));
    setState(() {
      _navKey = key;
      _selectedId = first?.id;
      _selectionInitialized = true;
      if (_draft?.id != first?.id) {
        _draft = null;
        _loadedSeriesId = null;
        _activeBlockId = null;
      }
      _saving = false;
    });
  }

  void _selectSermon(String id) {
    if (_selectedId == id) return;
    unawaited(_save(reconcileNavigation: false));
    setState(() {
      _selectedId = id;
      _selectionInitialized = true;
      _draft = null;
      _loadedSeriesId = null;
      _activeBlockId = null;
      _saving = false;
    });
  }

  void _selectView(WorkspaceView view) {
    setState(() {
      _activeBlockId = null;
      if (view == WorkspaceView.outline) {
        _view = view;
        _splitActive = false;
      } else if (_splitActive) {
        _view = view;
        _splitActive = false;
      } else if (_view != WorkspaceView.outline && _view != view) {
        _splitActive = true;
      } else {
        _view = view;
      }
    });
  }

  Future<void> _createEntry() async {
    final repository = ref.read(sermonRepositoryProvider);
    var sermon = await repository.create();
    final key = _navKey;
    if (key?.startsWith('book:') ?? false) {
      final bookId = key!.substring(5);
      sermon = sermon.copyWith(
        primaryBibleReference: BibleReference(
          bookId: bookId,
          startChapter: 1,
          displayText: '${BibleBookCatalog.labelFor(bookId)} 1',
        ),
      );
    } else if (key?.startsWith('series:') ?? false) {
      sermon = sermon.copyWith(seriesId: key!.substring(7));
    } else if (key == 'kind:talk') {
      sermon = sermon.copyWith(contentKind: ContentKind.talk);
    } else if (key == 'kind:introduction') {
      sermon = sermon.copyWith(contentKind: ContentKind.introduction);
    } else if (key == 'kind:short') {
      sermon = sermon.copyWith(contentKind: ContentKind.shortTopic);
    } else if (key == null) {
      sermon = sermon.copyWith(contentKind: ContentKind.shortTopic);
    }
    await repository.update(sermon);
    _selectSermon(sermon.id);
    setState(() {
      _view = WorkspaceView.outline;
      _splitActive = false;
    });
  }

  Future<void> _addSeries() async {
    final controller = TextEditingController(text: 'Neue Reihe');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Vortragsreihe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Anlegen'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    setState(() => _navKey = 'series:$name');
    await _createEntry();
  }

  Future<void> _deleteCurrentSeries() async {
    final key = _navKey;
    if (key == null || !key.startsWith('series:')) return;
    final series = key.substring(7);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vortragsreihe löschen?'),
        content: Text(
          '„$series“ und alle zugehörigen Einträge werden in den Papierkorb verschoben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final repository = ref.read(sermonRepositoryProvider);
    final sermons = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    for (final sermon in sermons.where((item) => item.seriesId == series)) {
      await repository.moveToTrash(sermon.id);
    }
    final remaining = sermons
        .where(
          (item) =>
              !item.isDeleted &&
              item.seriesId != series &&
              item.primaryBibleReference != null,
        )
        .firstOrNull;
    setState(() {
      _selectedId = remaining?.id;
      _draft = null;
      _navKey = remaining == null ? null : _navKeyFor(remaining);
    });
  }

  void _updateDraft(Sermon next) {
    setState(() {
      _draft = next;
      _saving = true;
    });
    _scheduleSave();
  }

  void _activateBlock(String id) => setState(() => _activeBlockId = id);

  DocumentBlock? _activeBlock(SermonDocument document) =>
      document.blocks.where((block) => block.id == _activeBlockId).firstOrNull;

  void _updateBlock(DocumentBlock next) {
    final draft = _draft;
    if (draft == null) return;
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          blocks: [
            for (final block in draft.document.blocks)
              if (block.id == next.id) next else block,
          ],
        ),
      ),
    );
  }

  void _insertBlockAfter(String afterId, DocumentBlock next) {
    final draft = _draft;
    if (draft == null) return;
    final blocks = [...draft.document.blocks];
    final index = blocks.indexWhere((block) => block.id == afterId);
    blocks.insert(index < 0 ? blocks.length : index + 1, next);
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          blocks: blocks,
        ),
      ),
    );
    setState(() => _activeBlockId = next.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != next.id) return;
      _richKeys[next.id]?.currentState?.requestFocus();
    });
  }

  void _deleteBlock(String id) {
    final draft = _draft;
    if (draft == null || draft.document.blocks.length <= 1) return;
    _richKeys.remove(id);
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          blocks: draft.document.blocks
              .where((block) => block.id != id)
              .toList(growable: false),
        ),
      ),
    );
    setState(() => _activeBlockId = null);
  }

  void _changeActiveBlockType(String type) {
    final draft = _draft;
    final active = draft == null ? null : _activeBlock(draft.document);
    if (active == null) return;
    final now = DateTime.now().toUtc();
    final next = switch (type) {
      'h1' => HeadingBlock(
        id: active.id,
        level: 1,
        text: active.plainText,
        collapsed: false,
        createdAt: active.createdAt,
        updatedAt: now,
      ),
      'h2' => HeadingBlock(
        id: active.id,
        level: 2,
        text: active.plainText,
        collapsed: false,
        createdAt: active.createdAt,
        updatedAt: now,
      ),
      'quote' => QuoteBlock(
        id: active.id,
        text: active.plainText,
        author: '',
        source: '',
        createdAt: active.createdAt,
        updatedAt: now,
      ),
      'li' || 'li2' => NoteBlock(
        id: active.id,
        text: active.plainText,
        visibility: NoteVisibility.editorOnly,
        depth: type == 'li2' ? 1 : 0,
        createdAt: active.createdAt,
        updatedAt: now,
      ),
      _ => ParagraphBlock(
        id: active.id,
        text: active.plainText,
        semanticRole: ParagraphRole.normal,
        createdAt: active.createdAt,
        updatedAt: now,
      ),
    };
    _updateBlock(next);
  }

  void _applyInlineFormat(_InlineFormat format) {
    final id = _activeBlockId;
    if (id == null) return;
    _richKeys[id]?.currentState?.applyFormat(format);
  }

  Future<void> _showBibleReferencePicker() async {
    final draft = _draft;
    if (draft == null || _view == WorkspaceView.outline) return;
    final request = await showGeneralDialog<_BibleReferenceRequest>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bibelstelle schließen',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 58),
          child: _BibleReferenceDialog(
            initialBookId:
                draft.primaryBibleReference?.bookId ??
                BibleBookCatalog.all.first.id,
            asNote: _view == WorkspaceView.notes && !_splitActive,
          ),
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
    );
    if (request == null || !mounted) return;
    final parsed = BibleReferenceParser().parse(
      '${BibleBookCatalog.labelFor(request.bookId)} ${request.passage}',
    );
    if (parsed == null) return;
    final now = DateTime.now().toUtc();
    final active = _activeBlock(draft.document);
    final insertAfterId =
        active?.id ?? draft.document.blocks.lastOrNull?.id ?? '';
    if (_view == WorkspaceView.notes && !_splitActive) {
      _insertBlockAfter(
        insertAfterId,
        NoteBlock(
          id: const Uuid().v4(),
          text: parsed.displayText,
          visibility: NoteVisibility.editorOnly,
          depth: active is NoteBlock ? active.depth : 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      _insertBlockAfter(
        insertAfterId,
        QuoteBlock(
          id: const Uuid().v4(),
          text: '— ${parsed.displayText}',
          author: '',
          source: '',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(AppConfig.autosaveDelay, _save);
  }

  Future<void> _save({bool reconcileNavigation = true}) async {
    _saveTimer?.cancel();
    final draft = _draft;
    if (draft == null) return;
    if (mounted) setState(() => _saving = true);
    final repository = ref.read(sermonRepositoryProvider);
    final previousSeries = _loadedSeriesId?.trim();
    final nextSeries = draft.seriesId?.trim();
    if (previousSeries?.isNotEmpty == true &&
        nextSeries?.isNotEmpty == true &&
        previousSeries != nextSeries) {
      final sermons = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
      for (final sermon in sermons.where(
        (item) => item.id != draft.id && item.seriesId == previousSeries,
      )) {
        await repository.update(sermon.copyWith(seriesId: nextSeries));
      }
    }
    await repository.update(draft);
    if (mounted && _draft?.id == draft.id && _selectedId == draft.id) {
      setState(() {
        _loadedSeriesId = draft.seriesId;
        if (reconcileNavigation) {
          _navKey = _navKeyFor(draft);
        }
        _saving = false;
      });
    }
  }

  int _scriptWordCount(SermonDocument document) => document.blocks
      .where(
        (block) =>
            block is HeadingBlock ||
            block is ParagraphBlock ||
            block is QuoteBlock ||
            block is BibleQuoteBlock,
      )
      .fold(0, (sum, block) => sum + countWords(block.plainText));

  String _durationLabel(int words) {
    if (words == 0) return '';
    final minutes = (words / 105).round();
    if (minutes < 60) return '$minutes Min.';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours Std.' : '$hours Std. $rest Min.';
  }
}

class _NavigationColumn extends StatelessWidget {
  const _NavigationColumn({
    required this.sermons,
    required this.selectedNavKey,
    required this.onSelect,
    required this.onAddSeries,
    required this.isDark,
    required this.onToggleTheme,
  });

  final List<Sermon> sermons;
  final String? selectedNavKey;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddSeries;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final books = <String, int>{};
    final series = <String, int>{};
    for (final sermon in sermons) {
      if (sermon.seriesId?.trim().isNotEmpty ?? false) {
        series.update(
          sermon.seriesId!,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      } else if (sermon.contentKind == ContentKind.sermon &&
          sermon.primaryBibleReference != null) {
        books.update(
          sermon.primaryBibleReference!.bookId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
    }
    final bookIds = books.keys.toList()
      ..sort(
        (a, b) => BibleBookCatalog.orderOf(
          a,
        ).compareTo(BibleBookCatalog.orderOf(b)),
      );
    final seriesNames = series.keys.toList()..sort();
    int count(ContentKind kind) =>
        sermons.where((sermon) => sermon.contentKind == kind).length;
    final shortTopicCount = sermons
        .where(
          (sermon) =>
              sermon.contentKind == ContentKind.shortTopic ||
              (sermon.contentKind == ContentKind.sermon &&
                  sermon.primaryBibleReference == null &&
                  !(sermon.seriesId?.trim().isNotEmpty ?? false)),
        )
        .length;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
            child: Image.asset(
              'assets/images/sermonary-logo.png',
              width: 148,
              height: 120,
              fit: BoxFit.contain,
              color: isDark ? AppColors.darkInk.withValues(alpha: 0.65) : null,
              colorBlendMode: isDark ? BlendMode.screen : null,
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const _NavHeader(label: 'BÜCHER'),
                for (final id in bookIds)
                  _NavPill(
                    label: BibleBookCatalog.labelFor(id),
                    count: books[id]!,
                    selected: selectedNavKey == 'book:$id',
                    onTap: () => onSelect('book:$id'),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 5, 3),
                  child: Row(
                    children: [
                      const Expanded(
                        child: _NavHeader(
                          label: 'VORTRAGSREIHEN',
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      _TinyIconButton(
                        icon: LucideIcons.plus,
                        tooltip: 'Neue Reihe',
                        onPressed: onAddSeries,
                        size: 11,
                      ),
                    ],
                  ),
                ),
                for (final name in seriesNames)
                  _NavPill(
                    label: name,
                    count: series[name]!,
                    selected: selectedNavKey == 'series:$name',
                    onTap: () => onSelect('series:$name'),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                  child: Divider(),
                ),
                _NavPill(
                  label: 'Kurzthemen',
                  count: shortTopicCount,
                  selected: selectedNavKey == 'kind:short',
                  onTap: () => onSelect('kind:short'),
                ),
                _NavPill(
                  label: 'Einleitungen',
                  count: count(ContentKind.introduction),
                  selected: selectedNavKey == 'kind:introduction',
                  onTap: () => onSelect('kind:introduction'),
                ),
                _NavPill(
                  label: 'Vorträge',
                  count: count(ContentKind.talk),
                  selected: selectedNavKey == 'kind:talk',
                  onTap: () => onSelect('kind:talk'),
                ),
              ],
            ),
          ),
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${sermons.length} Einträge',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                _TinyIconButton(
                  icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                  tooltip: isDark ? 'Helle Ansicht' : 'Dunkle Ansicht',
                  onPressed: onToggleTheme,
                  size: 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryColumn extends StatelessWidget {
  const _EntryColumn({
    required this.label,
    required this.sermons,
    required this.selectedId,
    required this.canDeleteSeries,
    required this.onDeleteSeries,
    required this.onCreate,
    required this.onSelect,
  });

  final String label;
  final List<Sermon> sermons;
  final String? selectedId;
  final bool canDeleteSeries;
  final VoidCallback onDeleteSeries;
  final VoidCallback onCreate;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(
      alpha: 0.4,
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ),
              if (canDeleteSeries)
                _TinyIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Reihe löschen',
                  onPressed: onDeleteSeries,
                  size: 12,
                ),
              _TinyIconButton(
                key: const Key('new-sermon'),
                icon: LucideIcons.plus,
                tooltip: 'Neuer Eintrag',
                onPressed: onCreate,
              ),
            ],
          ),
        ),
        const Divider(indent: 12, endIndent: 12),
        Expanded(
          child: sermons.isEmpty
              ? Center(
                  child: TextButton(
                    onPressed: onCreate,
                    child: const Text('Ersten anlegen'),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: sermons.length,
                  itemBuilder: (context, index) {
                    final sermon = sermons[index];
                    final selected = sermon.id == selectedId;
                    return _EntryPill(
                      sermon: sermon,
                      selected: selected,
                      onTap: () => onSelect(sermon.id),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _WorkspaceToolbar extends StatelessWidget {
  const _WorkspaceToolbar({
    required this.view,
    required this.splitActive,
    required this.focusMode,
    required this.saving,
    required this.wordCount,
    required this.durationLabel,
    required this.activeBlock,
    required this.onToggleFocus,
    required this.onSelectView,
    required this.onChangeBlockType,
    required this.onFormat,
    required this.onInsertBibleReference,
    required this.onLive,
    required this.onPrint,
  });

  final WorkspaceView view;
  final bool splitActive;
  final bool focusMode;
  final bool saving;
  final int wordCount;
  final String durationLabel;
  final DocumentBlock? activeBlock;
  final VoidCallback onToggleFocus;
  final ValueChanged<WorkspaceView> onSelectView;
  final ValueChanged<String> onChangeBlockType;
  final ValueChanged<_InlineFormat> onFormat;
  final VoidCallback onInsertBibleReference;
  final VoidCallback onLive;
  final VoidCallback onPrint;

  bool _viewActive(WorkspaceView candidate) =>
      candidate == WorkspaceView.outline
      ? view == WorkspaceView.outline && !splitActive
      : candidate == WorkspaceView.notes
      ? view == WorkspaceView.notes || splitActive
      : view == WorkspaceView.script || splitActive;

  @override
  Widget build(BuildContext context) {
    final rich =
        activeBlock is ParagraphBlock ||
        activeBlock is QuoteBlock ||
        activeBlock is NoteBlock;
    final mayHighlight =
        activeBlock is ParagraphBlock || activeBlock is NoteBlock;
    final navigationWidth = focusMode
        ? 0
        : AppSizes.sidebarWidth + AppSizes.entryListWidth + 2;
    final showMetrics =
        MediaQuery.sizeOf(context).width - navigationWidth >= 900;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Stack(
        children: [
          Row(
            children: [
              _TinyIconButton(
                icon: focusMode ? LucideIcons.minimize2 : LucideIcons.maximize2,
                tooltip: focusMode ? 'Navigation zeigen' : 'Fokusmodus',
                onPressed: onToggleFocus,
              ),
              if (activeBlock != null && view != WorkspaceView.outline) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Blocktyp',
                  onSelected: onChangeBlockType,
                  itemBuilder: (context) {
                    final notes = view == WorkspaceView.notes;
                    return [
                      const PopupMenuItem(
                        value: 'h1',
                        child: Text('Überschrift 1'),
                      ),
                      const PopupMenuItem(
                        value: 'h2',
                        child: Text('Überschrift 2'),
                      ),
                      if (notes) ...[
                        const PopupMenuItem(
                          value: 'li',
                          child: Text('Stichpunkt'),
                        ),
                        const PopupMenuItem(
                          value: 'li2',
                          child: Text('Unterpunkt'),
                        ),
                      ] else ...[
                        const PopupMenuItem(value: 'p', child: Text('Absatz')),
                        const PopupMenuItem(
                          value: 'quote',
                          child: Text('Zitat'),
                        ),
                      ],
                    ];
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _blockLabel(activeBlock!),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 11.5,
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant.withValues(
                                      alpha: 0.55,
                                    ),
                              ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronDown, size: 10),
                      ],
                    ),
                  ),
                ),
              ],
              if (rich) ...[
                const SizedBox(width: 3),
                _FormatButton(
                  label: 'B',
                  tooltip: 'Fett',
                  onPressed: () => onFormat(_InlineFormat.bold),
                ),
                _FormatButton(
                  label: 'I',
                  tooltip: 'Kursiv',
                  italic: true,
                  onPressed: () => onFormat(_InlineFormat.italic),
                ),
                if (mayHighlight)
                  _TinyIconButton(
                    icon: LucideIcons.highlighter,
                    tooltip: 'Markieren',
                    onPressed: () => onFormat(_InlineFormat.highlight),
                    size: 11,
                  ),
              ],
              const Spacer(),
              _ViewButton(
                icon: LucideIcons.layoutList,
                tooltip: 'Outline',
                selected: _viewActive(WorkspaceView.outline),
                onPressed: () => onSelectView(WorkspaceView.outline),
              ),
              _ViewButton(
                icon: LucideIcons.notebookPen,
                tooltip: 'Notizen',
                selected: _viewActive(WorkspaceView.notes),
                onPressed: () => onSelectView(WorkspaceView.notes),
              ),
              _ViewButton(
                icon: LucideIcons.scrollText,
                tooltip: 'Skript',
                selected: _viewActive(WorkspaceView.script),
                onPressed: () => onSelectView(WorkspaceView.script),
              ),
              Container(
                width: 1,
                height: 14,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              _ViewButton(
                icon: LucideIcons.monitor,
                tooltip: 'Live-Ansicht',
                selected: false,
                onPressed: onLive,
              ),
              _ViewButton(
                icon: LucideIcons.printer,
                tooltip: 'Print-Ansicht',
                selected: false,
                onPressed: onPrint,
              ),
              if (wordCount > 0 && showMetrics) ...[
                const SizedBox(width: 14),
                Text(
                  '$wordCount Wörter · $durationLabel',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                  ),
                ),
                const SizedBox(width: 16),
              ] else
                const SizedBox(width: 14),
              Text(
                saving ? 'Speichert …' : 'Gespeichert',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          if (view != WorkspaceView.outline)
            Align(
              child: _ViewButton(
                icon: LucideIcons.bookOpen,
                tooltip: 'Bibelstelle einfügen',
                selected: false,
                onPressed: onInsertBibleReference,
              ),
            ),
        ],
      ),
    );
  }

  static String _blockLabel(DocumentBlock block) => switch (block) {
    HeadingBlock(level: 1) => 'Überschrift 1',
    HeadingBlock() => 'Überschrift 2',
    ParagraphBlock() => 'Absatz',
    QuoteBlock() => 'Zitat',
    NoteBlock(depth: 1) => 'Unterpunkt',
    NoteBlock() => 'Stichpunkt',
    _ => 'Block',
  };
}

class _OutlineView extends StatelessWidget {
  const _OutlineView({
    required this.sermon,
    required this.onChanged,
    required this.onSave,
  });

  final Sermon sermon;
  final ValueChanged<Sermon> onChanged;
  final VoidCallback onSave;

  _WorkspaceGroup get group {
    if (sermon.seriesId?.isNotEmpty ?? false) return _WorkspaceGroup.series;
    return switch (sermon.contentKind) {
      ContentKind.talk => _WorkspaceGroup.talk,
      ContentKind.shortTopic => _WorkspaceGroup.shortTopic,
      ContentKind.introduction => _WorkspaceGroup.introduction,
      ContentKind.sermon => _WorkspaceGroup.book,
    };
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.outlineWidth),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _GroupChip(
                  label: 'Vortragsreihe',
                  selected: group == _WorkspaceGroup.series,
                  onTap: () => _changeGroup(_WorkspaceGroup.series),
                ),
                _GroupChip(
                  label: 'Auslegungspredigt',
                  selected: group == _WorkspaceGroup.book,
                  onTap: () => _changeGroup(_WorkspaceGroup.book),
                ),
                _GroupChip(
                  label: 'Vortrag',
                  selected: group == _WorkspaceGroup.talk,
                  onTap: () => _changeGroup(_WorkspaceGroup.talk),
                ),
                _GroupChip(
                  label: 'Kurzthema',
                  selected: group == _WorkspaceGroup.shortTopic,
                  onTap: () => _changeGroup(_WorkspaceGroup.shortTopic),
                ),
                _GroupChip(
                  label: 'Einleitung',
                  selected: group == _WorkspaceGroup.introduction,
                  onTap: () => _changeGroup(_WorkspaceGroup.introduction),
                ),
              ],
            ),
            const SizedBox(height: 48),
            if (group == _WorkspaceGroup.book)
              Row(
                children: [
                  Expanded(
                    child: _BookDropdown(
                      reference: sermon.primaryBibleReference,
                      onChanged: (reference) => onChanged(
                        sermon.copyWith(primaryBibleReference: reference),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BareTextField(
                      key: ValueKey('reference-${sermon.id}'),
                      initialValue: sermon.primaryBibleReference == null
                          ? ''
                          : _referenceWithoutBook(
                              sermon.primaryBibleReference!,
                            ),
                      hintText: '18:16–33',
                      style: _outlineReferenceStyle(context).copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.42),
                        fontWeight: FontWeight.w400,
                      ),
                      onChanged: (value) {
                        final book = sermon.primaryBibleReference?.bookId;
                        if (book == null) return;
                        final parsed = BibleReferenceParser().parse(
                          '${BibleBookCatalog.labelFor(book)} $value',
                        );
                        if (parsed != null) {
                          onChanged(
                            sermon.copyWith(primaryBibleReference: parsed),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            if (group == _WorkspaceGroup.series)
              _BareTextField(
                key: ValueKey('series-${sermon.id}'),
                initialValue: sermon.seriesId ?? '',
                hintText: 'Name der Reihe …',
                style: _headingStyle(context),
                onChanged: (value) => onChanged(
                  sermon.copyWith(seriesId: value),
                ),
              ),
            const SizedBox(height: 28),
            _BareTextField(
              key: ValueKey('title-${sermon.id}'),
              initialValue: sermon.title,
              hintText: 'Titel der Predigt',
              maxLines: null,
              style: Theme.of(context).textTheme.displaySmall!.copyWith(
                fontFamily: AppTypography.ui,
                fontSize: 38,
                fontWeight: FontWeight.w500,
                height: 1.18,
                letterSpacing: -0.76,
              ),
              onChanged: (value) => onChanged(sermon.copyWith(title: value)),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                SizedBox(
                  width: 145,
                  child: _BareTextField(
                    key: ValueKey('date-${sermon.id}'),
                    initialValue: sermon.scheduledAt == null
                        ? ''
                        : _formatDate(sermon.scheduledAt!),
                    hintText: 'Datum',
                    style: _subheadingStyle(context),
                    onChanged: (value) {
                      final date = _parseDate(value);
                      if (date != null) {
                        onChanged(sermon.copyWith(scheduledAt: date));
                      }
                    },
                  ),
                ),
                Text(
                  '·',
                  style: _subheadingStyle(context).copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BareTextField(
                    key: ValueKey('location-${sermon.id}'),
                    initialValue: sermon.location ?? '',
                    hintText: 'Ort',
                    style: _subheadingStyle(context),
                    onChanged: (value) =>
                        onChanged(sermon.copyWith(location: value)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 38),
            Divider(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 26),
            _BareTextField(
              key: ValueKey('summary-${sermon.id}'),
              initialValue: sermon.subtitle,
              hintText: 'Zusammenfassung der Predigt …',
              maxLines: null,
              minLines: 3,
              style: _bodyStyle(context).copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              onChanged: (value) => onChanged(sermon.copyWith(subtitle: value)),
            ),
            const SizedBox(height: 54),
            TextButton(
              onPressed: onSave,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                textStyle: const TextStyle(
                  fontFamily: AppTypography.ui,
                  fontSize: 11.5,
                  decoration: TextDecoration.underline,
                  decorationThickness: 0.6,
                ),
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    ),
  );

  void _changeGroup(_WorkspaceGroup next) {
    switch (next) {
      case _WorkspaceGroup.book:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.sermon,
            seriesId: '',
            primaryBibleReference:
                sermon.primaryBibleReference ??
                const BibleReference(
                  bookId: 'gen',
                  startChapter: 1,
                  displayText: '1. Mose 1',
                ),
          ),
        );
      case _WorkspaceGroup.series:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.sermon,
            seriesId: sermon.seriesId?.isNotEmpty == true
                ? sermon.seriesId
                : 'Neue Reihe',
            clearPrimaryBibleReference: true,
          ),
        );
      case _WorkspaceGroup.talk:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.talk,
            seriesId: '',
            clearPrimaryBibleReference: true,
          ),
        );
      case _WorkspaceGroup.shortTopic:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.shortTopic,
            seriesId: '',
            clearPrimaryBibleReference: true,
          ),
        );
      case _WorkspaceGroup.introduction:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.introduction,
            seriesId: '',
            clearPrimaryBibleReference: true,
          ),
        );
    }
  }
}

class _ScriptView extends StatelessWidget {
  const _ScriptView({
    required this.sermon,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateSermon,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<Sermon> onUpdateSermon;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final void Function(String, DocumentBlock) onInsertAfter;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final blocks = sermon.document.blocks
        .where((block) => block is! NoteBlock)
        .toList(growable: false);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.editorWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 54, 32, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScriptMeta(sermon: sermon, onChanged: onUpdateSermon),
              const SizedBox(height: 30),
              _BareTextField(
                key: ValueKey('script-title-${sermon.id}'),
                initialValue: sermon.title,
                hintText: 'Titel',
                maxLines: null,
                style: _titleStyle(context),
                onChanged: (value) =>
                    onUpdateSermon(sermon.copyWith(title: value)),
              ),
              const SizedBox(height: 38),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 38),
              for (var index = 0; index < blocks.length; index++)
                _DocumentBlockField(
                  block: blocks[index],
                  previous: index == 0 ? null : blocks[index - 1],
                  active: activeBlockId == blocks[index].id,
                  richKey: richKeys.putIfAbsent(
                    blocks[index].id,
                    GlobalKey.new,
                  ),
                  onActivate: onActivate,
                  onChanged: onUpdateBlock,
                  onInsertAfter: onInsertAfter,
                  onDelete: onDelete,
                  noteMode: false,
                ),
              if (blocks.isEmpty)
                _GhostAdd(
                  label: 'Absatz hinzufügen',
                  onTap: () {
                    final now = DateTime.now().toUtc();
                    onInsertAfter(
                      '',
                      ParagraphBlock(
                        id: const Uuid().v4(),
                        text: '',
                        semanticRole: ParagraphRole.normal,
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesView extends StatelessWidget {
  const _NotesView({
    required this.sermon,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final void Function(String, DocumentBlock) onInsertAfter;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final blocks = sermon.document.blocks
        .where((block) => block is HeadingBlock || block is NoteBlock)
        .toList(growable: false);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.editorWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 54, 32, 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sermon.title, style: _titleStyle(context)),
              const SizedBox(height: 38),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 38),
              for (var index = 0; index < blocks.length; index++)
                _DocumentBlockField(
                  block: blocks[index],
                  previous: index == 0 ? null : blocks[index - 1],
                  active: activeBlockId == blocks[index].id,
                  richKey: richKeys.putIfAbsent(
                    blocks[index].id,
                    GlobalKey.new,
                  ),
                  onActivate: onActivate,
                  onChanged: onUpdateBlock,
                  onInsertAfter: onInsertAfter,
                  onDelete: onDelete,
                  noteMode: true,
                ),
              if (!blocks.any((block) => block is NoteBlock))
                _GhostAdd(
                  label: 'Stichpunkt hinzufügen',
                  bullet: '—',
                  onTap: () {
                    final now = DateTime.now().toUtc();
                    onInsertAfter(
                      blocks.lastOrNull?.id ?? '',
                      NoteBlock(
                        id: const Uuid().v4(),
                        text: '',
                        visibility: NoteVisibility.editorOnly,
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.sermon,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final void Function(String, DocumentBlock) onInsertAfter;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final segments = _segments(sermon.document.blocks);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.splitWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 54, 48, 190),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sermon.title, style: _titleStyle(context)),
              const SizedBox(height: 38),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(child: _ColumnLabel('SKRIPT')),
                  Expanded(child: _ColumnLabel('NOTIZEN')),
                ],
              ),
              const SizedBox(height: 22),
              for (final segment in segments) ...[
                if (segment.heading case final heading?)
                  Padding(
                    padding: const EdgeInsets.only(top: 34, bottom: 14),
                    child: _DocumentBlockField(
                      block: heading,
                      previous: null,
                      active: activeBlockId == heading.id,
                      richKey: richKeys.putIfAbsent(
                        heading.id,
                        GlobalKey.new,
                      ),
                      onActivate: onActivate,
                      onChanged: onUpdateBlock,
                      onInsertAfter: onInsertAfter,
                      onDelete: onDelete,
                      noteMode: false,
                    ),
                  ),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < segment.script.length;
                                index++
                              )
                                _DocumentBlockField(
                                  block: segment.script[index],
                                  previous: index == 0
                                      ? segment.heading
                                      : segment.script[index - 1],
                                  active:
                                      activeBlockId == segment.script[index].id,
                                  richKey: richKeys.putIfAbsent(
                                    segment.script[index].id,
                                    GlobalKey.new,
                                  ),
                                  onActivate: onActivate,
                                  onChanged: onUpdateBlock,
                                  onInsertAfter: onInsertAfter,
                                  onDelete: onDelete,
                                  noteMode: false,
                                ),
                              if (segment.script.isEmpty)
                                _GhostAdd(
                                  label: 'Absatz hinzufügen',
                                  onTap: () => _addParagraph(segment),
                                ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (
                                var index = 0;
                                index < segment.notes.length;
                                index++
                              )
                                _DocumentBlockField(
                                  block: segment.notes[index],
                                  previous: index == 0
                                      ? segment.heading
                                      : segment.notes[index - 1],
                                  active:
                                      activeBlockId == segment.notes[index].id,
                                  richKey: richKeys.putIfAbsent(
                                    segment.notes[index].id,
                                    GlobalKey.new,
                                  ),
                                  onActivate: onActivate,
                                  onChanged: onUpdateBlock,
                                  onInsertAfter: onInsertAfter,
                                  onDelete: onDelete,
                                  noteMode: true,
                                ),
                              if (segment.notes.isEmpty)
                                _GhostAdd(
                                  label: 'Stichpunkt',
                                  bullet: '—',
                                  onTap: () => _addNote(segment),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _addParagraph(_DocumentSegment segment) {
    final now = DateTime.now().toUtc();
    onInsertAfter(
      segment.heading?.id ?? '',
      ParagraphBlock(
        id: const Uuid().v4(),
        text: '',
        semanticRole: ParagraphRole.normal,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  void _addNote(_DocumentSegment segment) {
    final now = DateTime.now().toUtc();
    onInsertAfter(
      segment.heading?.id ?? '',
      NoteBlock(
        id: const Uuid().v4(),
        text: '',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _DocumentBlockField extends StatelessWidget {
  const _DocumentBlockField({
    required this.block,
    required this.previous,
    required this.active,
    required this.richKey,
    required this.onActivate,
    required this.onChanged,
    required this.onInsertAfter,
    required this.onDelete,
    required this.noteMode,
  });

  final DocumentBlock block;
  final DocumentBlock? previous;
  final bool active;
  final GlobalKey<_RichBlockFieldState> richKey;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onChanged;
  final void Function(String, DocumentBlock) onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool noteMode;

  @override
  Widget build(BuildContext context) {
    final margin = _blockTopMargin(block, previous);
    if (block is HeadingBlock) {
      final heading = block as HeadingBlock;
      return Padding(
        padding: EdgeInsets.only(top: margin),
        child: _BareTextField(
          key: ValueKey('heading-${heading.id}-${heading.level}'),
          initialValue: heading.text,
          hintText: 'Überschrift ${heading.level}',
          style: heading.level == 1
              ? _headingStyle(context)
              : _subheadingStyle(context),
          onTap: () => onActivate(heading.id),
          onChanged: (value) => onChanged(
            HeadingBlock(
              id: heading.id,
              level: heading.level,
              text: value,
              collapsed: heading.collapsed,
              createdAt: heading.createdAt,
              updatedAt: DateTime.now().toUtc(),
            ),
          ),
          onSubmitted: (_) => _insertDefault(),
        ),
      );
    }
    if (block is DividerBlock) {
      return Padding(
        padding: EdgeInsets.only(top: margin),
        child: const Divider(),
      );
    }
    if (block is BibleQuoteBlock) {
      final quote = block as BibleQuoteBlock;
      return Padding(
        padding: EdgeInsets.only(top: margin, left: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.14),
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              quote.text,
              style: _quoteStyle(context),
            ),
          ),
        ),
      );
    }
    final text = block.plainText;
    final marks = switch (block) {
      ParagraphBlock(:final marks) => marks,
      QuoteBlock(:final marks) => marks,
      NoteBlock(:final marks) => marks,
      _ => const <InlineMark>[],
    };
    final depth = block is NoteBlock ? (block as NoteBlock).depth : 0;
    final field = _RichBlockField(
      key: richKey,
      text: text,
      marks: marks,
      style: block is QuoteBlock
          ? _quoteStyle(context)
          : block is NoteBlock && depth == 1
          ? _bodyStyle(context).copyWith(
              fontSize: 15.6,
              height: 1.7,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            )
          : _bodyStyle(context),
      hintText: block is QuoteBlock ? 'Zitat …' : '',
      onFocus: () => onActivate(block.id),
      onChanged: (value, nextMarks) =>
          onChanged(_withRichText(block, value, nextMarks)),
      onSubmitted: _insertDefault,
      onEmptyBackspace: () => onDelete(block.id),
      onIndent: block is NoteBlock
          ? (outdent) {
              final note = block as NoteBlock;
              onChanged(
                NoteBlock(
                  id: note.id,
                  text: note.text,
                  visibility: note.visibility,
                  depth: outdent ? 0 : 1,
                  marks: note.marks,
                  createdAt: note.createdAt,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          : null,
    );
    if (block is QuoteBlock) {
      return Padding(
        padding: EdgeInsets.only(top: margin),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: active ? 0.18 : 0.1),
                width: 2,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: field,
          ),
        ),
      );
    }
    if (block is NoteBlock) {
      return Padding(
        padding: EdgeInsets.only(
          top: margin,
          left: depth == 1 ? 32 : 0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: depth == 1 ? 22 : 26,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  depth == 1 ? '·' : '—',
                  style: TextStyle(
                    fontFamily: AppTypography.ui,
                    fontSize: depth == 1 ? 14 : 16,
                    color:
                        Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(
                          alpha: depth == 1 ? 0.18 : 0.28,
                        ),
                  ),
                ),
              ),
            ),
            Expanded(child: field),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: margin),
      child: field,
    );
  }

  void _insertDefault() {
    final now = DateTime.now().toUtc();
    final next = noteMode
        ? NoteBlock(
            id: const Uuid().v4(),
            text: '',
            visibility: NoteVisibility.editorOnly,
            depth: block is NoteBlock ? (block as NoteBlock).depth : 0,
            createdAt: now,
            updatedAt: now,
          )
        : ParagraphBlock(
            id: const Uuid().v4(),
            text: '',
            semanticRole: ParagraphRole.normal,
            createdAt: now,
            updatedAt: now,
          );
    onInsertAfter(block.id, next);
  }
}

class _RichBlockField extends StatefulWidget {
  const _RichBlockField({
    required this.text,
    required this.marks,
    required this.style,
    required this.hintText,
    required this.onFocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onEmptyBackspace,
    this.onIndent,
    super.key,
  });

  final String text;
  final List<InlineMark> marks;
  final TextStyle style;
  final String hintText;
  final VoidCallback onFocus;
  final void Function(String text, List<InlineMark> marks) onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onEmptyBackspace;
  final ValueChanged<bool>? onIndent;

  @override
  State<_RichBlockField> createState() => _RichBlockFieldState();
}

class _RichBlockFieldState extends State<_RichBlockField> {
  late final _MarkedTextController _controller = _MarkedTextController(
    text: widget.text,
    marks: widget.marks,
  );
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(_RichBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.text) {
      _controller
        ..text = widget.text
        ..marks = widget.marks;
    } else if (oldWidget.marks != widget.marks) {
      _controller.marks = widget.marks;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void applyFormat(_InlineFormat format) {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final mark = InlineMark(
      start: selection.start,
      end: selection.end,
      bold: format == _InlineFormat.bold,
      italic: format == _InlineFormat.italic,
      highlighted: format == _InlineFormat.highlight,
    );
    final exists = _controller.marks.any(
      (candidate) =>
          candidate.start == mark.start &&
          candidate.end == mark.end &&
          candidate.bold == mark.bold &&
          candidate.italic == mark.italic &&
          candidate.highlighted == mark.highlighted,
    );
    final next = exists
        ? _controller.marks
              .where(
                (candidate) =>
                    !(candidate.start == mark.start &&
                        candidate.end == mark.end &&
                        candidate.bold == mark.bold &&
                        candidate.italic == mark.italic &&
                        candidate.highlighted == mark.highlighted),
              )
              .toList(growable: false)
        : [..._controller.marks, mark];
    setState(() => _controller.marks = next);
    widget.onChanged(_controller.text, next);
  }

  void requestFocus() {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    widget.onFocus();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.backspace &&
            _controller.text.isEmpty) {
          widget.onEmptyBackspace();
          return KeyEventResult.handled;
        }
        if ((event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            !HardwareKeyboard.instance.isShiftPressed) {
          widget.onSubmitted();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.tab &&
            widget.onIndent != null) {
          widget.onIndent!(HardwareKeyboard.instance.isShiftPressed);
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    },
    child: TextField(
      controller: _controller,
      focusNode: _focusNode,
      minLines: 1,
      maxLines: null,
      style: widget.style,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: widget.style.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
        ),
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      onTap: widget.onFocus,
      onChanged: (value) {
        final validMarks = _controller.marks
            .where((mark) => mark.start >= 0 && mark.end <= value.length)
            .toList(growable: false);
        _controller.marks = validMarks;
        widget.onChanged(value, validMarks);
      },
      onSubmitted: (_) => widget.onSubmitted(),
    ),
  );
}

class _MarkedTextController extends TextEditingController {
  _MarkedTextController({
    required String text,
    required this._marks,
  }) : super(text: text);

  List<InlineMark> _marks;

  List<InlineMark> get marks => _marks;

  set marks(List<InlineMark> value) {
    _marks = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    if (_marks.isEmpty || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }
    final boundaries = <int>{0, text.length};
    for (final mark in _marks) {
      boundaries
        ..add(mark.start.clamp(0, text.length))
        ..add(mark.end.clamp(0, text.length));
    }
    final sorted = boundaries.toList()..sort();
    final children = <TextSpan>[];
    for (var index = 0; index < sorted.length - 1; index++) {
      final start = sorted[index];
      final end = sorted[index + 1];
      if (start == end) continue;
      final covering = _marks.where(
        (mark) => mark.start <= start && mark.end >= end,
      );
      final bold = covering.any((mark) => mark.bold);
      final italic = covering.any((mark) => mark.italic);
      final highlighted = covering.any((mark) => mark.highlighted);
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: style?.copyWith(
            fontWeight: bold ? FontWeight.w700 : style.fontWeight,
            fontStyle: italic ? FontStyle.italic : style.fontStyle,
            backgroundColor: highlighted
                ? AppColors.highlight.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.34
                        : 0.82,
                  )
                : null,
          ),
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

DocumentBlock _withRichText(
  DocumentBlock block,
  String text,
  List<InlineMark> marks,
) {
  final now = DateTime.now().toUtc();
  return switch (block) {
    ParagraphBlock() => ParagraphBlock(
      id: block.id,
      text: text,
      semanticRole: block.semanticRole,
      isBold: block.isBold,
      isItalic: block.isItalic,
      marks: marks,
      createdAt: block.createdAt,
      updatedAt: now,
    ),
    QuoteBlock() => QuoteBlock(
      id: block.id,
      text: text,
      author: block.author,
      source: block.source,
      marks: marks,
      createdAt: block.createdAt,
      updatedAt: now,
    ),
    NoteBlock() => NoteBlock(
      id: block.id,
      text: text,
      visibility: block.visibility,
      depth: block.depth,
      marks: marks,
      createdAt: block.createdAt,
      updatedAt: now,
    ),
    _ => block,
  };
}

class _ScriptMeta extends StatelessWidget {
  const _ScriptMeta({required this.sermon, required this.onChanged});

  final Sermon sermon;
  final ValueChanged<Sermon> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = sermon.seriesId?.isNotEmpty == true
        ? sermon.seriesId!
        : switch (sermon.contentKind) {
            ContentKind.talk => 'Vortrag',
            ContentKind.shortTopic => 'Kurzthema',
            ContentKind.introduction => 'Einleitung',
            ContentKind.sermon =>
              sermon.primaryBibleReference == null
                  ? 'Predigt'
                  : BibleBookCatalog.labelFor(
                      sermon.primaryBibleReference!.bookId,
                    ),
          };
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11.5,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
          ),
        ),
        if (sermon.primaryBibleReference != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '·',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _referenceWithoutBook(sermon.primaryBibleReference!),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11.5,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BibleReferenceRequest {
  const _BibleReferenceRequest({
    required this.bookId,
    required this.passage,
  });

  final String bookId;
  final String passage;
}

class _BibleReferenceDialog extends StatefulWidget {
  const _BibleReferenceDialog({
    required this.initialBookId,
    required this.asNote,
  });

  final String initialBookId;
  final bool asNote;

  @override
  State<_BibleReferenceDialog> createState() => _BibleReferenceDialogState();
}

class _BibleReferenceDialogState extends State<_BibleReferenceDialog> {
  late String _bookId = widget.initialBookId;
  final TextEditingController _passageController = TextEditingController();

  @override
  void dispose() {
    _passageController.dispose();
    super.dispose();
  }

  void _submit() {
    final passage = _passageController.text.trim();
    if (passage.isEmpty) return;
    Navigator.of(context).pop(
      _BibleReferenceRequest(bookId: _bookId, passage: passage),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    elevation: 5,
    shadowColor: Colors.black.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      key: const Key('bible-reference-dialog'),
      width: 288,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BIBELSTELLE EINFÜGEN',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('bible-book-field'),
            initialValue: _bookId,
            isExpanded: true,
            style: const TextStyle(
              fontFamily: AppTypography.ui,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            items: [
              for (final book in BibleBookCatalog.all)
                DropdownMenuItem(value: book.id, child: Text(book.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _bookId = value);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('bible-passage-field'),
            controller: _passageController,
            autofocus: true,
            style: const TextStyle(
              fontFamily: AppTypography.ui,
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            decoration: const InputDecoration(
              hintText: 'Vers, z. B. 3,16 oder 18:16–33',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton(
              key: const Key('insert-bible-reference'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainer,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: AppTypography.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: Text(
                widget.asNote
                    ? 'Als Stichpunkt einfügen'
                    : 'Als Zitat einfügen',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BookDropdown extends StatelessWidget {
  const _BookDropdown({required this.reference, required this.onChanged});

  final BibleReference? reference;
  final ValueChanged<BibleReference> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: reference?.bookId,
      hint: Text('Buch …', style: _outlineReferenceStyle(context)),
      icon: const Icon(LucideIcons.chevronDown, size: 12),
      isExpanded: true,
      style: _outlineReferenceStyle(context),
      items: [
        for (final book in BibleBookCatalog.all)
          DropdownMenuItem(
            value: book.id,
            child: Text(
              book.label,
              style: _outlineReferenceStyle(context),
            ),
          ),
      ],
      onChanged: (bookId) {
        if (bookId == null) return;
        final suffix = reference == null
            ? '1'
            : _referenceWithoutBook(reference!);
        final parsed = BibleReferenceParser().parse(
          '${BibleBookCatalog.labelFor(bookId)} $suffix',
        );
        if (parsed != null) onChanged(parsed);
      },
    ),
  );
}

class _BareTextField extends StatelessWidget {
  const _BareTextField({
    required this.initialValue,
    required this.hintText,
    required this.style,
    required this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
    super.key,
  });

  final String initialValue;
  final String hintText;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    initialValue: initialValue,
    minLines: minLines,
    maxLines: maxLines,
    style: style,
    decoration: InputDecoration(
      hintText: hintText,
      hintStyle: style.copyWith(
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
      ),
      filled: false,
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    onTap: onTap,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
  );
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.surfaceContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: selected
              ? Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.25)
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          letterSpacing: 0.3,
          color: selected
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    ),
  );
}

class _NavHeader extends StatelessWidget {
  const _NavHeader({
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(8, 4, 8, 4),
  });

  final String label;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.14,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    ),
  );
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surfaceContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color:
                    Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(
                      alpha: selected ? 0.5 : 0.28,
                    ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EntryPill extends StatelessWidget {
  const _EntryPill({
    required this.sermon,
    required this.selected,
    required this.onTap,
  });

  final Sermon sermon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: InkWell(
      key: Key('sermon-${sermon.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surfaceContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sermon.primaryBibleReference != null ||
                sermon.seriesPosition != null)
              Text(
                sermon.primaryBibleReference?.displayText ??
                    'Einheit ${sermon.seriesPosition}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(
                        alpha: selected ? 0.62 : 0.4,
                      ),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              sermon.title.isEmpty ? 'Ohne Titel' : sermon.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontSize: 12.5,
                height: 1.25,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: selected ? 1 : 0.64,
                ),
                fontStyle: sermon.title.isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _relativeDate(sermon.updatedAt),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 13,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: size),
    style: IconButton.styleFrom(
      minimumSize: const Size(28, 28),
      maximumSize: const Size(28, 28),
      padding: EdgeInsets.zero,
      foregroundColor: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 13),
    style: IconButton.styleFrom(
      minimumSize: const Size(28, 28),
      maximumSize: const Size(28, 28),
      padding: EdgeInsets.zero,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.surfaceContainer
          : Colors.transparent,
      foregroundColor: selected
          ? Theme.of(context).colorScheme.onSurface
          : Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.italic = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool italic;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: italic ? AppTypography.editor : AppTypography.ui,
              fontSize: italic ? 13 : 12,
              fontWeight: italic ? FontWeight.w400 : FontWeight.w700,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GhostAdd extends StatelessWidget {
  const _GhostAdd({
    required this.label,
    required this.onTap,
    this.bullet,
  });

  final String label;
  final String? bullet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 8),
      foregroundColor: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
      textStyle: const TextStyle(
        fontFamily: AppTypography.editor,
        fontSize: 11.5,
      ),
    ),
    child: Text('${bullet == null ? '' : '$bullet  '}$label'),
  );
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.14,
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.26),
    ),
  );
}

class _EmptyWorkspace extends StatelessWidget {
  const _EmptyWorkspace({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton(
      onPressed: onCreate,
      child: Text(
        'Ersten Eintrag anlegen',
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontStyle: FontStyle.italic,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    ),
  );
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    bottom: 0,
    height: 80,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
              Theme.of(context).colorScheme.surface.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
      ),
    ),
  );
}

class _DocumentSegment {
  _DocumentSegment({
    required this.heading,
    required this.script,
    required this.notes,
  });

  final HeadingBlock? heading;
  final List<DocumentBlock> script;
  final List<NoteBlock> notes;
}

List<_DocumentSegment> _segments(List<DocumentBlock> blocks) {
  final result = <_DocumentSegment>[
    _DocumentSegment(
      heading: null,
      script: <DocumentBlock>[],
      notes: <NoteBlock>[],
    ),
  ];
  for (final block in blocks) {
    if (block is HeadingBlock) {
      result.add(
        _DocumentSegment(
          heading: block,
          script: <DocumentBlock>[],
          notes: <NoteBlock>[],
        ),
      );
    } else if (block is NoteBlock) {
      result.last.notes.add(block);
    } else if (block is! BulletListBlock) {
      result.last.script.add(block);
    }
  }
  return result;
}

double _blockTopMargin(DocumentBlock block, DocumentBlock? previous) {
  if (previous == null) return 0;
  if (block is HeadingBlock && block.level == 1) return 48;
  if (block is HeadingBlock) return 32;
  if (block is QuoteBlock) return 24;
  if (block is ParagraphBlock && previous is HeadingBlock) return 8;
  if (block is NoteBlock && previous is HeadingBlock) return 16;
  if (block is NoteBlock && previous is NoteBlock) {
    if (block.depth == 1 && previous.depth == 0) return 6;
    if (block.depth == 1) return 4;
    if (previous.depth == 1) return 12;
    return 10;
  }
  return 20;
}

TextStyle _titleStyle(BuildContext context) =>
    Theme.of(context).textTheme.displaySmall!.copyWith(
      fontFamily: AppTypography.ui,
      fontSize: 38,
      fontWeight: FontWeight.w500,
      height: 1.18,
      letterSpacing: -0.76,
    );

TextStyle _headingStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontFamily: AppTypography.ui,
      fontSize: 28,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: -0.45,
    );

TextStyle _subheadingStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall!.copyWith(
      fontFamily: AppTypography.ui,
      fontSize: 20.5,
      fontWeight: FontWeight.w500,
      height: 1.38,
      letterSpacing: -0.2,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.76),
    );

TextStyle _outlineReferenceStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontFamily: AppTypography.ui,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.78),
    );

TextStyle _bodyStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontFamily: AppTypography.editor,
      fontSize: 16.8,
      fontWeight: FontWeight.w400,
      height: 1.95,
      letterSpacing: 0.08,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
    );

TextStyle _quoteStyle(BuildContext context) => _bodyStyle(context).copyWith(
  fontSize: 16,
  height: 1.85,
  fontStyle: FontStyle.italic,
  letterSpacing: 0.12,
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
);

String _referenceWithoutBook(BibleReference reference) {
  final full = reference.displayText;
  final book = BibleBookCatalog.labelFor(reference.bookId);
  return full.startsWith(book) ? full.substring(book.length).trim() : full;
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.'
    '${date.month.toString().padLeft(2, '0')}.'
    '${date.year}';

DateTime? _parseDate(String value) {
  final parts = value.split('.');
  if (parts.length != 3) return null;
  final day = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final year = int.tryParse(parts[2]);
  if (day == null || month == null || year == null) return null;
  return DateTime.utc(year, month, day);
}

String _relativeDate(DateTime date) {
  final difference = DateTime.now().difference(date.toLocal());
  if (difference.inMinutes < 2) return 'Gerade eben';
  if (difference.inHours < 24) return 'Heute';
  if (difference.inDays == 1) return 'Gestern';
  if (difference.inDays < 7) return 'Vor ${difference.inDays} Tagen';
  if (difference.inDays < 14) return 'Vor 1 Woche';
  return 'Vor ${(difference.inDays / 7).round()} Wochen';
}
