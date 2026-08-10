import 'dart:async';
import 'dart:convert' show HtmlEscape;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:printing/printing.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/core/database/database_backup_service.dart';
import 'package:sermonary/core/platform/keyboard_shortcuts.dart';
import 'package:sermonary/core/widgets/sermon_workflow_navigation.dart';
import 'package:sermonary/core/widgets/typeahead_menu_region.dart';
import 'package:sermonary/features/bible/application/bible_passage_normalizer.dart';
import 'package:sermonary/features/bible/domain/bible_book_background_catalog.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/bible/domain/bible_text_importer.dart';
import 'package:sermonary/features/export/application/sermon_document_exporter.dart';
import 'package:sermonary/features/feedback/application/local_feedback_service.dart';
import 'package:sermonary/features/import/application/sermon_import_parser.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/application/presentation_exporter.dart';
import 'package:sermonary/features/presentation/application/presentation_media_service.dart';
import 'package:sermonary/features/presentation/domain/presentation_bible_pagination.dart';
import 'package:sermonary/features/presentation/domain/presentation_slide_order.dart';
import 'package:sermonary/features/presentation/presentation/presentation_editor_view.dart';
import 'package:sermonary/features/sermon_editor/domain/module_linking.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:sermonary/features/workspace/application/rich_clipboard_paste.dart';
import 'package:sermonary/features/workspace/application/workspace_session_store.dart';
import 'package:uuid/uuid.dart';

enum WorkspaceView { outline, notes, script, presentation }

enum _WorkspacePaneKind { empty, outline, module }

class _WorkspacePaneState {
  const _WorkspacePaneState._(this.kind, this.moduleId);

  const _WorkspacePaneState.empty() : this._(_WorkspacePaneKind.empty, null);

  const _WorkspacePaneState.outline()
    : this._(_WorkspacePaneKind.outline, null);

  const _WorkspacePaneState.module(String moduleId)
    : this._(_WorkspacePaneKind.module, moduleId);

  final _WorkspacePaneKind kind;
  final String? moduleId;

  bool get isEmpty => kind == _WorkspacePaneKind.empty;
}

enum _WorkspaceGroup { book, series, talk, shortTopic, introduction }

enum _InlineFormat { bold, italic, highlight }

enum _SermonExportFormat { pdf, word, print }

enum _PresentationExportFormat { pdf, powerPointEditable, powerPointImages }

enum _SermonExportAction {
  notesPdf(SermonExportContent.notes, _SermonExportFormat.pdf, null),
  notesWord(SermonExportContent.notes, _SermonExportFormat.word, null),
  notesPrint(SermonExportContent.notes, _SermonExportFormat.print, null),
  scriptPdf(SermonExportContent.script, _SermonExportFormat.pdf, null),
  scriptWord(SermonExportContent.script, _SermonExportFormat.word, null),
  scriptPrint(SermonExportContent.script, _SermonExportFormat.print, null),
  presentationPdf(null, null, _PresentationExportFormat.pdf),
  presentationPowerPoint(
    null,
    null,
    _PresentationExportFormat.powerPointEditable,
  ),
  presentationPowerPointImages(
    null,
    null,
    _PresentationExportFormat.powerPointImages,
  );

  const _SermonExportAction(
    this.content,
    this.format,
    this.presentationFormat,
  );

  final SermonExportContent? content;
  final _SermonExportFormat? format;
  final _PresentationExportFormat? presentationFormat;

  String get searchableLabel {
    final presentation = presentationFormat;
    if (presentation != null) {
      return switch (presentation) {
        _PresentationExportFormat.pdf => 'Präsentation PDF',
        _PresentationExportFormat.powerPointEditable =>
          'Präsentation PowerPoint bearbeitbar',
        _PresentationExportFormat.powerPointImages =>
          'Präsentation PowerPoint 1:1 Bilder',
      };
    }
    return '${content == SermonExportContent.notes ? 'Notizen' : 'Script'} '
        '${switch (format!) {
          _SermonExportFormat.pdf => 'PDF',
          _SermonExportFormat.word => 'Word',
          _SermonExportFormat.print => 'Print',
        }}';
  }
}

int _compareNavigationLabels(String first, String second) {
  String sortKey(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('ä', 'ae')
      .replaceAll('ö', 'oe')
      .replaceAll('ü', 'ue')
      .replaceAll('ß', 'ss');

  final comparison = sortKey(first).compareTo(sortKey(second));
  return comparison == 0 ? first.compareTo(second) : comparison;
}

enum _OnboardingTarget {
  archive,
  books,
  series,
  categories,
  sermons,
  outline,
  notes,
  script,
  presentation,
  splitScreen,
  live,
  export,
  darkMode,
}

class _OnboardingStep {
  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.target,
  });

  final String title;
  final String description;
  final _OnboardingTarget target;
}

const _onboardingSteps = <_OnboardingStep>[
  _OnboardingStep(
    title: 'Dein Archiv',
    description:
        'Suche deine Predigten oder öffne sie nach Bibelbuch, Vortragsreihe und weiteren Kategorien.',
    target: _OnboardingTarget.archive,
  ),
  _OnboardingStep(
    title: 'Predigt und Inhalte',
    description:
        'Wähle eine Predigt und öffne darunter ihre Notizen, Skripte und Präsentationen. Das Verknüpfungszeichen zeigt zusammengehörige Inhalte.',
    target: _OnboardingTarget.sermons,
  ),
  _OnboardingStep(
    title: 'Outline',
    description:
        'Hier pflegst du Einordnung, Bibelstelle, Beschreibung und Quicknotes. Du kannst unabhängige oder verknüpfte Inhalte hinzufügen.',
    target: _OnboardingTarget.outline,
  ),
  _OnboardingStep(
    title: 'Modular schreiben',
    description:
        'Notizen, Skripte und Präsentationen sind frei kombinierbar. Verknüpfte Inhalte teilen Überschriften; unverknüpfte bleiben eigenständig.',
    target: _OnboardingTarget.notes,
  ),
  _OnboardingStep(
    title: 'Splitscreen',
    description:
        'Öffne zwei beliebige Inhalte nebeneinander. Verknüpfte Inhalte richten Abschnitte aus und scrollen gemeinsam.',
    target: _OnboardingTarget.splitScreen,
  ),
  _OnboardingStep(
    title: 'Präsentation',
    description:
        'Erstelle Folien aus Vorlagen und verankere sie an passenden Stellen in einem verknüpften Notiz- oder Skriptinhalt.',
    target: _OnboardingTarget.presentation,
  ),
  _OnboardingStep(
    title: 'Live-Ansicht',
    description:
        'Wähle den gewünschten Inhalt für eine ruhige Predigtansicht. Verknüpfte Folien erscheinen passend zum aktuellen Abschnitt.',
    target: _OnboardingTarget.live,
  ),
  _OnboardingStep(
    title: 'Export',
    description:
        'Exportiere Notizen und Skripte als PDF oder Word und Präsentationen als PDF, bearbeitbare oder pixelgetreue PowerPoint.',
    target: _OnboardingTarget.export,
  ),
];

typedef _RichPasteCallback =
    Future<void> Function(
      String blockId,
      TextSelection selection, {
      required bool noteMode,
      required bool plainTextOnly,
    });

typedef _InsertBlockCallback =
    void Function(
      String afterId,
      DocumentBlock block, {
      bool focusAtEnd,
    });

typedef _AnchorSlideCallback =
    void Function(
      PresentationSlide slide,
      String blockId,
      PresentationAnchorView view,
      int offset,
    );

class _SmartSlidePart {
  const _SmartSlidePart({
    required this.block,
    required this.text,
    required this.start,
  });

  final DocumentBlock block;
  final String text;
  final int start;
}

class _SmartSlideSelection {
  const _SmartSlideSelection({
    required this.parts,
    required this.anchor,
    required this.contextTitle,
    required this.reference,
  });

  final List<_SmartSlidePart> parts;
  final PresentationAnchor anchor;
  final String contextTitle;
  final String reference;

  String get text => parts.map((part) => part.text.trim()).join('\n\n').trim();

  _SmartSlidePart? get firstHeading =>
      parts.where((part) => part.block is HeadingBlock).firstOrNull;

  String get bodyWithoutFirstHeading {
    final heading = firstHeading;
    return parts
        .where((part) => !identical(part, heading))
        .map((part) => part.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n\n');
  }
}

class _DetectedSmartBibleReference {
  const _DetectedSmartBibleReference({
    required this.body,
    required this.reference,
  });

  final String body;
  final String reference;
}

String _smartBibleBookPattern() {
  final names =
      BibleBookCatalog.all
          .expand((book) => [book.label, ...book.aliases])
          .toSet()
          .toList()
        ..sort((left, right) => right.length.compareTo(left.length));
  return names
      .map(
        (book) => RegExp.escape(
          book,
        ).replaceAll(' ', r'\s*').replaceAll(r'\.', r'\.?\s*'),
      )
      .join('|');
}

final RegExp _smartBibleReferencePattern = RegExp(
  '(^|[\\s(\\[])(${_smartBibleBookPattern()})(?:\\s+|(?<=\\.))'
  r'(\d+\s*[:,]\s*\d+(?:\s*[-–—]\s*(?:(?:\d+\s*[:,]\s*)?\d+))?)'
  r'(?=\s*[)\],.;!?]*\s*$)',
  caseSensitive: false,
);
final RegExp _smartBibleReferenceAtStartPattern = RegExp(
  '^\\s*(${_smartBibleBookPattern()})(?:\\s+|(?<=\\.))'
  r'(\d+\s*[:,]\s*\d+(?:\s*[-–—]\s*(?:(?:\d+\s*[:,]\s*)?\d+))?)'
  r'(?=\s+)',
  caseSensitive: false,
);

_DetectedSmartBibleReference? _detectSmartBibleReference(String input) {
  var match = _smartBibleReferencePattern.firstMatch(input);
  var bookGroup = 2;
  var passageGroup = 3;
  match ??= _smartBibleReferenceAtStartPattern.firstMatch(input);
  if (match != null && match.groupCount == 2) {
    bookGroup = 1;
    passageGroup = 2;
  }
  if (match == null) return null;
  final rawReference = '${match.group(bookGroup)} ${match.group(passageGroup)}';
  final parsed = BibleReferenceParser().parsePassage(rawReference);
  if (parsed == null) return null;
  final before = input.substring(0, match.start).trimRight();
  final after = input.substring(match.end).trimLeft();
  final body =
      '$before${before.isNotEmpty && after.isNotEmpty ? ' ' : ''}$after'
          .trim()
          .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1');
  final singleVerse =
      parsed.startChapter == (parsed.endChapter ?? parsed.startChapter) &&
      parsed.startVerse == parsed.endVerse;
  final reference = singleVerse
      ? '${BibleBookCatalog.labelFor(parsed.bookId)} '
            '${parsed.startChapter},${parsed.startVerse}'
      : formatBibleReference(parsed);
  return _DetectedSmartBibleReference(body: body, reference: reference);
}

typedef SermonImportFilePicker = Future<XFile?> Function();
typedef FeedbackScreenshotPicker = Future<XFile?> Function();

const _outlineBackgroundIds = <String>[
  'generic1',
  'generic2',
  'generic3',
  'generic4',
  'generic5',
  'generic6',
];
const _unselectedSeriesId = '__unselected_series__';
const _multipleBooksId = '__multiple_books__';

String _effectiveBackgroundImageId(
  Sermon sermon,
  List<SermonSeries> series,
) {
  final override = sermon.backgroundImageId;
  if (override != null && _outlineBackgroundIds.contains(override)) {
    return override;
  }
  final bookId = sermon.primaryBibleReference?.bookId;
  if (bookId != null &&
      BibleBookBackgroundCatalog.lightAssetFor(bookId) != null) {
    return 'book:$bookId';
  }
  final seriesId = sermon.seriesId;
  if (seriesId != null && seriesId.isNotEmpty) {
    final inherited = series
        .where((item) => item.id == seriesId || item.title == seriesId)
        .firstOrNull
        ?.backgroundImageId;
    if (inherited != null && _outlineBackgroundIds.contains(inherited)) {
      return inherited;
    }
  }
  return 'generic1';
}

String _randomSeriesBackgroundImageId() =>
    'generic${2 + math.Random.secure().nextInt(5)}';

class _SermonPlacement {
  const _SermonPlacement({
    required this.contentKind,
    required this.seriesId,
    required this.primaryBibleReference,
  });

  factory _SermonPlacement.fromSermon(Sermon sermon) => _SermonPlacement(
    contentKind: sermon.contentKind,
    seriesId: sermon.seriesId,
    primaryBibleReference: sermon.primaryBibleReference,
  );

  final ContentKind contentKind;
  final String? seriesId;
  final BibleReference? primaryBibleReference;

  Sermon applyTo(Sermon draft) {
    final committedReference = primaryBibleReference;
    BibleReference? reference;
    if (committedReference != null) {
      final editedReference = draft.primaryBibleReference;
      reference = editedReference == null
          ? committedReference
          : BibleReference(
              bookId: committedReference.bookId,
              startChapter: editedReference.startChapter,
              startVerse: editedReference.startVerse,
              endChapter: editedReference.endChapter,
              endVerse: editedReference.endVerse,
              displayText: formatBibleReference(
                BibleReference(
                  bookId: committedReference.bookId,
                  startChapter: editedReference.startChapter,
                  startVerse: editedReference.startVerse,
                  endChapter: editedReference.endChapter,
                  endVerse: editedReference.endVerse,
                  displayText: editedReference.displayText,
                ),
              ),
            );
    }
    return draft.copyWith(
      contentKind: contentKind,
      seriesId: seriesId ?? '',
      primaryBibleReference: reference,
      clearPrimaryBibleReference: reference == null,
    );
  }
}

class SermonWorkspaceScreen extends ConsumerStatefulWidget {
  const SermonWorkspaceScreen({
    super.key,
    this.sermonId,
    this.initialView = WorkspaceView.outline,
    this.clipboardSource,
    this.clipboardSink,
    this.importFilePicker,
    this.feedbackScreenshotPicker,
    this.feedbackService,
    this.restoreLastSession = false,
    this.persistSession = false,
    this.sessionStore,
  });

  final String? sermonId;
  final WorkspaceView initialView;
  final RichClipboardSource? clipboardSource;
  final RichClipboardSink? clipboardSink;
  final SermonImportFilePicker? importFilePicker;
  final FeedbackScreenshotPicker? feedbackScreenshotPicker;
  final LocalFeedbackService? feedbackService;
  final bool restoreLastSession;
  final bool persistSession;
  final WorkspaceSessionStore? sessionStore;

  @override
  ConsumerState<SermonWorkspaceScreen> createState() =>
      _SermonWorkspaceScreenState();
}

class _SermonWorkspaceScreenState extends ConsumerState<SermonWorkspaceScreen>
    with WidgetsBindingObserver {
  late WorkspaceView _view = widget.initialView;
  bool _splitActive = false;
  final List<_WorkspacePaneState> _panes = <_WorkspacePaneState>[
    const _WorkspacePaneState.outline(),
    const _WorkspacePaneState.empty(),
  ];
  int _activePaneIndex = 0;
  String? _activeModuleId;
  String? _selectedPresentationSlideId;
  bool _focusMode = false;
  bool _saving = false;
  String? _selectedId;
  String? _pendingRepositorySelectionId;
  int? _onboardingStep;
  String? _navKey;
  _SermonPlacement? _committedPlacement;
  Sermon? _draft;
  Timer? _saveTimer;
  Timer? _historyGroupTimer;
  Timer? _searchTimer;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  final List<Sermon> _undoStack = [];
  final List<Sermon> _redoStack = [];
  bool _historyGroupOpen = false;
  bool _applyingHistory = false;
  bool _backgroundPickerOpen = false;
  late final SermonRepository _repository;
  String? _activeBlockId;
  String? _activeBlockModuleId;
  final Map<String, Map<String, GlobalKey<_RichBlockFieldState>>>
  _richKeysByModule = {};
  final Map<String, TextSelection> _blockSelections = {};
  final Map<String, String> _pendingBibleReferenceTexts = {};
  final Map<_OnboardingTarget, GlobalKey> _onboardingTargetKeys = {
    for (final target in _OnboardingTarget.values)
      target: GlobalKey(debugLabel: 'onboarding-${target.name}'),
  };
  late final RichClipboardSource _clipboardReader;
  late final RichClipboardSink _clipboardWriter;
  late final LocalFeedbackService _feedbackService;
  final RichPasteParser _pasteParser = const RichPasteParser();
  String? _selectionAnchorId;
  int? _selectionAnchorOffset;
  Future<void> _saveQueue = Future<void>.value();
  Future<void> _sessionSaveQueue = Future<void>.value();
  late final WorkspaceSessionStore _sessionStore;
  WorkspaceSession? _pendingRestoredSession;
  bool _sessionReady = false;

  Map<String, GlobalKey<_RichBlockFieldState>> _richKeysForModule(
    String? moduleId,
  ) => _richKeysByModule.putIfAbsent(moduleId ?? 'outline', () => {});

  Map<String, GlobalKey<_RichBlockFieldState>> get _richKeys =>
      _richKeysForModule(_activeBlockModuleId ?? _activeModuleId);

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sermonRepositoryProvider);
    _clipboardReader = widget.clipboardSource ?? RichClipboardReader();
    _clipboardWriter = widget.clipboardSink ?? const RichClipboardWriter();
    _feedbackService = widget.feedbackService ?? LocalFeedbackService();
    _sessionStore = widget.sessionStore ?? const LocalWorkspaceSessionStore();
    _selectedId = widget.sermonId;
    WidgetsBinding.instance.addObserver(this);
    if (widget.restoreLastSession && widget.sermonId == null) {
      unawaited(_restoreWorkspaceSession());
    } else {
      _sessionReady = true;
    }
  }

  @override
  void didUpdateWidget(SermonWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sermonId != widget.sermonId) {
      _resetHistory();
      _selectedId = widget.sermonId;
      _draft = null;
      _activeBlockId = null;
      _activeModuleId = null;
      _selectedPresentationSlideId = null;
      _view = widget.initialView;
      _splitActive = false;
      _activePaneIndex = 0;
      _panes
        ..[0] = const _WorkspacePaneState.outline()
        ..[1] = const _WorkspacePaneState.empty();
    }
    if (oldWidget.initialView != widget.initialView) {
      _view = widget.initialView;
      _splitActive = false;
      _activePaneIndex = 0;
      _panes
        ..[0] = const _WorkspacePaneState.outline()
        ..[1] = const _WorkspacePaneState.empty();
    }
  }

  @override
  void dispose() {
    _persistWorkspaceSession();
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _historyGroupTimer?.cancel();
    _searchTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    final draft = _draft;
    if (draft != null && _saving) {
      unawaited(_save(reconcileNavigation: false));
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _persistWorkspaceSession();
    }
  }

  Future<void> _restoreWorkspaceSession() async {
    final session = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _pendingRestoredSession = session;
      _selectedId = session?.sermonId;
      _sessionReady = true;
    });
  }

  void _persistWorkspaceSession() {
    if ((!widget.persistSession && !widget.restoreLastSession) ||
        !_sessionReady) {
      return;
    }
    final session = WorkspaceSession(
      sermonId: _selectedId,
      splitActive: _splitActive,
      activePaneIndex: _activePaneIndex,
      focusMode: _focusMode,
      panes: [
        for (final pane in _panes)
          WorkspaceSessionPane(
            kind: switch (pane.kind) {
              _WorkspacePaneKind.empty => WorkspaceSessionPaneKind.empty,
              _WorkspacePaneKind.outline => WorkspaceSessionPaneKind.outline,
              _WorkspacePaneKind.module => WorkspaceSessionPaneKind.module,
            },
            moduleId: pane.moduleId,
          ),
      ],
    );
    _sessionSaveQueue = _sessionSaveQueue.then((_) async {
      try {
        await _sessionStore.save(session);
      } on Object {
        // The editor must remain usable if macOS temporarily rejects a write.
      }
    });
  }

  bool _applyRestoredWorkspaceSession(Sermon sermon) {
    final session = _pendingRestoredSession;
    if (session == null || session.sermonId != sermon.id) return false;

    _WorkspacePaneState restorePane(int index) {
      if (index >= session.panes.length) {
        return const _WorkspacePaneState.empty();
      }
      final saved = session.panes[index];
      return switch (saved.kind) {
        WorkspaceSessionPaneKind.empty => const _WorkspacePaneState.empty(),
        WorkspaceSessionPaneKind.outline => const _WorkspacePaneState.outline(),
        WorkspaceSessionPaneKind.module =>
          saved.moduleId != null &&
                  sermon.document.moduleById(saved.moduleId!) != null
              ? _WorkspacePaneState.module(saved.moduleId!)
              : const _WorkspacePaneState.empty(),
      };
    }

    _panes
      ..[0] = restorePane(0)
      ..[1] = restorePane(1);
    _splitActive = session.splitActive;
    if (!_splitActive) {
      if (_panes[0].isEmpty) {
        _panes[0] = _panes[1].isEmpty
            ? const _WorkspacePaneState.outline()
            : _panes[1];
      }
      _panes[1] = const _WorkspacePaneState.empty();
      _activePaneIndex = 0;
    } else {
      _activePaneIndex = session.activePaneIndex.clamp(0, 1);
      if (_panes[0].isEmpty && _panes[1].isEmpty) {
        _panes[0] = const _WorkspacePaneState.outline();
        _activePaneIndex = 0;
      } else if (_panes[_activePaneIndex].isEmpty) {
        _activePaneIndex = _activePaneIndex == 0 ? 1 : 0;
      }
    }
    _focusMode = session.focusMode;
    _applyActivePaneSelection();
    final activeModule = _activeModuleId == null
        ? null
        : sermon.document.moduleById(_activeModuleId!);
    if (activeModule?.kind == SermonModuleKind.presentation) {
      _selectedPresentationSlideId = sermon.document
          .slidesForModule(activeModule!.id)
          .firstOrNull
          ?.id;
    }
    _pendingRestoredSession = null;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapProvider);
    if (widget.restoreLastSession && !_sessionReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 1)),
      );
    }
    return ref
        .watch(sermonsProvider)
        .when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 1)),
          ),
          error: (error, stack) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error is DatabaseBackupException
                      ? error.message
                      : 'Bibliothek konnte nicht geladen werden.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          data: _buildWorkspace,
        );
  }

  Widget _buildWorkspace(List<Sermon> allSermons) {
    final sermons = allSermons
        .where((sermon) => !sermon.isDeleted)
        .toList(growable: false);
    if (_selectedId != null &&
        !sermons.any((sermon) => sermon.id == _selectedId)) {
      final selectionIsPending =
          _pendingRepositorySelectionId == _selectedId &&
          _draft?.id == _selectedId;
      if (!selectionIsPending) {
        _selectedId = null;
        _draft = null;
        _activeBlockId = null;
        _activeModuleId = null;
        _resetPanesToOutline();
        _selectedPresentationSlideId = null;
        _pendingRestoredSession = null;
      }
    } else if (_pendingRepositorySelectionId == _selectedId) {
      _pendingRepositorySelectionId = null;
    }
    final selectedId = _selectedId;
    final stored = sermons
        .where((sermon) => sermon.id == selectedId)
        .firstOrNull;
    if (stored != null && (_draft == null || _draft!.id != stored.id)) {
      _resetHistory();
      final legacyNormalized = _normalizeLegacyNotes(stored);
      final presentationNormalized = _paginateExistingBibleSlides(
        legacyNormalized,
      );
      final migratedDocument = presentationNormalized.document.migrateToV2(
        sermonId: presentationNormalized.id,
        fallbackCreatedAt: presentationNormalized.createdAt,
      );
      final moduleMigrationNeeded =
          migratedDocument.schemaVersion !=
              presentationNormalized.document.schemaVersion ||
          presentationNormalized.document.modules.length !=
              presentationNormalized.document.effectiveModules.length;
      final moduleNormalized = moduleMigrationNeeded
          ? presentationNormalized.copyWith(
              document: migratedDocument,
            )
          : presentationNormalized;
      final slideOrderNormalized = _normalizePresentationSlideOrder(
        moduleNormalized,
      );
      final slideOrderChanged = _presentationModuleOrderDiffers(
        moduleNormalized.document,
        slideOrderNormalized.document,
      );
      _draft = slideOrderNormalized;
      _committedPlacement = _SermonPlacement.fromSermon(stored);
      _navKey ??= _navKeyFor(_draft!);
      if (presentationNormalized.document.presentation.slides.length !=
              legacyNormalized.document.presentation.slides.length ||
          moduleMigrationNeeded ||
          slideOrderChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _draft?.id != slideOrderNormalized.id) return;
          _saving = true;
          _scheduleSave();
        });
      }
      if (!_applyRestoredWorkspaceSession(slideOrderNormalized)) {
        _restoreInitialModuleSelection(slideOrderNormalized);
      }
    }
    final selected = _draft;
    if (selected != null && _view != WorkspaceView.outline) {
      if (_activeModuleId == null ||
          selected.document.moduleById(_activeModuleId!) == null) {
        _view = WorkspaceView.outline;
        _splitActive = false;
        _resetPanesToOutline();
      }
    }
    final navigationSermons = [
      for (final sermon in sermons)
        if (_draft?.id == sermon.id) _draft! else sermon,
    ];
    final visibleEntries = _groupVersions(_entriesForNav(navigationSermons));
    final searchResults = _searchQuery.isEmpty
        ? const <_SermonSearchResult>[]
        : _searchSermons(sermons, _searchQuery);
    final explicitSeries =
        ref.watch(sermonSeriesProvider).valueOrNull ?? const <SermonSeries>[];
    final emptyActionLabel = _navKey == null
        ? 'Neue Predigt anlegen'
        : (_navKey!.startsWith('series:')
              ? 'Erste Predigt anlegen'
              : 'Ersten Eintrag anlegen');
    final showEntryColumn =
        !_focusMode && (_navKey != null || _searchQuery.isNotEmpty);
    final activeWordCount = selected == null
        ? 0
        : _activeContentWordCount(selected.document);

    return CallbackShortcuts(
      bindings: {
        primaryShortcut(LogicalKeyboardKey.keyS): () =>
            _save(commitPlacement: true),
        primaryShortcut(LogicalKeyboardKey.keyF): () {
          if (_focusMode) setState(() => _focusMode = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _searchFocusNode.requestFocus();
          });
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_searchFocusNode.hasFocus) return;
          _clearSearch();
          _searchFocusNode.unfocus();
        },
        primaryShortcut(LogicalKeyboardKey.keyZ): _undo,
        primaryShortcut(LogicalKeyboardKey.keyZ, shift: true): _redo,
        primaryShortcut(LogicalKeyboardKey.digit1, alt: true): () =>
            _selectView(WorkspaceView.outline),
        primaryShortcut(LogicalKeyboardKey.digit2, alt: true): () =>
            _selectView(WorkspaceView.notes),
        primaryShortcut(LogicalKeyboardKey.digit3, alt: true): () =>
            _selectView(WorkspaceView.script),
        primaryShortcut(LogicalKeyboardKey.digit1): () =>
            _changeActiveBlockType('h1'),
        primaryShortcut(LogicalKeyboardKey.digit2): () =>
            _changeActiveBlockType('h2'),
        primaryShortcut(LogicalKeyboardKey.digit3): () =>
            _changeActiveBlockType('h3'),
        primaryShortcut(LogicalKeyboardKey.keyQ): _changeActiveBlockToQuote,
        primaryShortcut(LogicalKeyboardKey.keyB): () =>
            _applyInlineFormat(_InlineFormat.bold),
        primaryShortcut(LogicalKeyboardKey.keyI): () =>
            _applyInlineFormat(_InlineFormat.italic),
        primaryShortcut(LogicalKeyboardKey.keyM): () =>
            _applyInlineFormat(_InlineFormat.highlight),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        key: _onboardingTargetKeys[_OnboardingTarget.archive],
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
                              explicitSeries: explicitSeries,
                              selectedNavKey: _navKey,
                              searchController: _searchController,
                              searchFocusNode: _searchFocusNode,
                              onSearchChanged: _queueSearch,
                              onClearSearch: _clearSearch,
                              onSelect: (key) {
                                _clearSearch();
                                _selectNavigation(key);
                              },
                              onAddSeries: _addSeries,
                              onRenameSeries: _renameSeries,
                              onCreate: _createUnassignedEntry,
                              onImport: _importSermon,
                              onBackup: _showBackupDialog,
                              booksOnboardingKey:
                                  _onboardingTargetKeys[_OnboardingTarget
                                      .books]!,
                              seriesOnboardingKey:
                                  _onboardingTargetKeys[_OnboardingTarget
                                      .series]!,
                              categoriesOnboardingKey:
                                  _onboardingTargetKeys[_OnboardingTarget
                                      .categories]!,
                              darkModeOnboardingKey:
                                  _onboardingTargetKeys[_OnboardingTarget
                                      .darkMode]!,
                              isDark:
                                  Theme.of(context).brightness ==
                                  Brightness.dark,
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
                      if (showEntryColumn)
                        KeyedSubtree(
                          key: _onboardingTargetKeys[_OnboardingTarget.sermons],
                          child: SizedBox(
                            key: const Key('entry-column-shell'),
                            width: AppSizes.entryListWidth,
                            child: _searchQuery.isNotEmpty
                                ? _SearchResultColumn(
                                    query: _searchQuery,
                                    results: searchResults,
                                    selectedId: selected?.id,
                                    onSelect: _selectSermon,
                                  )
                                : _EntryColumn(
                                    label: _navLabel,
                                    sermons: visibleEntries,
                                    allSermons: sermons,
                                    selectedId: selected?.id,
                                    showSeriesSubtitle:
                                        _navKey?.startsWith('book:') ?? false,
                                    canDeleteSeries:
                                        _navKey?.startsWith('series:') ?? false,
                                    onRenameSeries:
                                        _navKey?.startsWith('series:') ?? false
                                        ? () => _renameSeries(
                                            _navKey!.substring(7),
                                          )
                                        : null,
                                    onDeleteSeries: _deleteCurrentSeries,
                                    onCreate: _createEntry,
                                    onSelect: _selectSermon,
                                    activeModuleIds: _visibleModuleIds,
                                    onSelectModule: _selectModule,
                                    onAddModule: _addContentModule,
                                    onDuplicateModule: _duplicateContentModule,
                                    onDeleteModule: _deleteContentModule,
                                    onRenameModule: _renameContentModule,
                                    onLinkModules: _linkContentModules,
                                    onMoveModule: _moveContentModule,
                                    onUnlinkModule: _unlinkContentModule,
                                    onDuplicate: _duplicateSermon,
                                    onDelete: _deleteSermon,
                                    onAttachVersion: _attachSermonAsVersion,
                                    onDetachVersion: _detachSermonVersion,
                                    emptyActionLabel: emptyActionLabel,
                                  ),
                          ),
                        ),
                      if (showEntryColumn) const VerticalDivider(width: 1),
                      Expanded(
                        child: selected == null
                            ? _EmptyWorkspace(
                                onCreate: _createUnassignedEntry,
                                label: emptyActionLabel,
                                showBackground: _navKey == null,
                              )
                            : Column(
                                children: [
                                  _WorkspaceToolbar(
                                    view: _view,
                                    splitActive: _splitActive,
                                    focusMode: _focusMode,
                                    saving: _saving,
                                    wordCount: activeWordCount,
                                    durationLabel: _durationLabel(
                                      activeWordCount,
                                    ),
                                    activeBlock: _activeBlock(
                                      selected.document,
                                    ),
                                    activeFormats: _activeBlockId == null
                                        ? const <_InlineFormat>{}
                                        : _richKeys[_activeBlockId]
                                                  ?.currentState
                                                  ?.activeFormats ??
                                              const <_InlineFormat>{},
                                    onToggleFocus: () => setState(
                                      () => _focusMode = !_focusMode,
                                    ),
                                    onToggleSplit: _toggleSplitMode,
                                    splitOnboardingKey:
                                        _onboardingTargetKeys[_OnboardingTarget
                                            .splitScreen]!,
                                    onChangeBlockType: _changeActiveBlockType,
                                    onFormat: _applyInlineFormat,
                                    onClearHighlights: _clearActiveHighlights,
                                    onInsertBibleReference:
                                        _showBibleReferencePicker,
                                    onLive: () => unawaited(
                                      _showLiveModeDialog(selected),
                                    ),
                                    onExport: _exportSermon,
                                    onDuplicate: () =>
                                        _duplicateSermon(selected.id),
                                    onDelete: () => _deleteSermon(selected.id),
                                    liveOnboardingKey:
                                        _onboardingTargetKeys[_OnboardingTarget
                                            .live]!,
                                    exportOnboardingKey:
                                        _onboardingTargetKeys[_OnboardingTarget
                                            .export]!,
                                  ),
                                  Expanded(
                                    child: _buildWorkspaceCanvas(selected),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
                if (_onboardingStep == null)
                  Positioned(
                    right: 18,
                    bottom: selected == null ? 16 : 92,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FeedbackButton(onPressed: _showFeedbackForm),
                        const SizedBox(width: 8),
                        _OnboardingHelpButton(onPressed: _startOnboarding),
                      ],
                    ),
                  ),
                if (_onboardingStep case final stepIndex?)
                  Positioned.fill(
                    child: _OnboardingOverlay(
                      step: _onboardingSteps[stepIndex],
                      stepIndex: stepIndex,
                      stepCount: _onboardingSteps.length,
                      targetKey:
                          _onboardingTargetKeys[_onboardingSteps[stepIndex]
                              .target]!,
                      onClose: _closeOnboarding,
                      onNext: _advanceOnboarding,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Iterable<_WorkspacePaneState> get _visiblePanes =>
      _splitActive ? _panes : _panes.take(1);

  Set<WorkspaceView> get _visibleWorkspaceViews {
    final views = <WorkspaceView>{};
    for (final pane in _visiblePanes) {
      if (pane.kind == _WorkspacePaneKind.outline) {
        views.add(WorkspaceView.outline);
      } else if (pane.moduleId case final moduleId?) {
        final module = _draft?.document.moduleById(moduleId);
        if (module != null) views.add(_workspaceViewForModule(module.kind));
      }
    }
    return views;
  }

  Set<String> get _visibleModuleIds {
    final ids = <String>{};
    for (final pane in _visiblePanes) {
      final moduleId = pane.moduleId;
      if (moduleId != null) ids.add(moduleId);
    }
    return ids;
  }

  void _resetPanesToOutline() {
    _panes
      ..[0] = const _WorkspacePaneState.outline()
      ..[1] = const _WorkspacePaneState.empty();
    _activePaneIndex = 0;
  }

  void _restoreInitialModuleSelection(Sermon sermon) {
    if (_view == WorkspaceView.outline) {
      _activeModuleId = null;
      _resetPanesToOutline();
      return;
    }
    final kind = _moduleKindForView(_view);
    final module = kind == null
        ? null
        : sermon.document.modulesOfKind(kind).firstOrNull;
    if (module == null) {
      _view = WorkspaceView.outline;
      _activeModuleId = null;
      _resetPanesToOutline();
      return;
    }
    _activeModuleId = module.id;
    _panes[0] = _WorkspacePaneState.module(module.id);
    _panes[1] = const _WorkspacePaneState.empty();
    _activePaneIndex = 0;
  }

  bool get _presentationVisible =>
      _visibleWorkspaceViews.contains(WorkspaceView.presentation);

  WorkspaceView get _presentationCompanion => _visibleWorkspaceViews.firstWhere(
    (view) => view == WorkspaceView.notes || view == WorkspaceView.script,
    orElse: () => WorkspaceView.script,
  );

  Sermon _scopedSermon(Sermon sermon, String moduleId) {
    final module = sermon.document.moduleById(moduleId);
    if (module == null) return sermon;
    final quickNotes = sermon.document.blocks.whereType<NoteBlock>().where(
      (note) => note.isQuickNote,
    );
    final moduleBlocks = sermon.document.blocksForModule(moduleId);
    final slides = module.kind == SermonModuleKind.presentation
        ? sermon.document.slidesForModule(moduleId)
        : _slidesLinkedToModule(sermon.document, module);
    return sermon.copyWith(
      document: SermonDocument(
        schemaVersion: sermon.document.schemaVersion,
        blocks: [...quickNotes, ...moduleBlocks],
        presentation: PresentationDeck(slides: slides),
        modules: [module],
      ),
    );
  }

  List<PresentationSlide> _slidesLinkedToModule(
    SermonDocument document,
    SermonModule module,
  ) {
    final groupId = module.linkGroupId;
    if (groupId == null) return const [];
    final slideIds = document.effectiveModules
        .where(
          (candidate) =>
              candidate.kind == SermonModuleKind.presentation &&
              candidate.linkGroupId == groupId,
        )
        .expand((candidate) => candidate.slideIds)
        .toSet();
    return document.presentation.slides
        .where((slide) => slideIds.contains(slide.id))
        .map((slide) => _slideAnchorForModule(document, slide, module))
        .toList(growable: false);
  }

  PresentationSlide _slideAnchorForModule(
    SermonDocument document,
    PresentationSlide slide,
    SermonModule target,
  ) {
    final anchor = slide.anchor;
    if (anchor == null || anchor.moduleId == target.id) return slide;
    final source = anchor.moduleId == null
        ? null
        : document.moduleById(anchor.moduleId!);
    if (source == null || !document.modulesAreLinked(source.id, target.id)) {
      return slide.copyWith(clearAnchor: true);
    }
    final anchorIndex = source.blockIds.indexOf(anchor.blockId);
    if (anchorIndex < 0) return slide.copyWith(clearAnchor: true);
    String? sharedHeadingId;
    for (var index = anchorIndex; index >= 0; index--) {
      final id = source.blockIds[index];
      final heading = document.blocks
          .where((block) => block.id == id)
          .firstOrNull;
      if (heading is HeadingBlock && target.blockIds.contains(id)) {
        sharedHeadingId = id;
        break;
      }
    }
    final targetBlockId = sharedHeadingId ?? target.blockIds.firstOrNull;
    if (targetBlockId == null) return slide.copyWith(clearAnchor: true);
    final targetBlock = document.blocks
        .where((block) => block.id == targetBlockId)
        .firstOrNull;
    return slide.copyWith(
      anchor: PresentationAnchor(
        view: target.kind == SermonModuleKind.notes
            ? PresentationAnchorView.notes
            : PresentationAnchorView.script,
        blockId: targetBlockId,
        offset: sharedHeadingId == null
            ? 0
            : targetBlock?.plainText.length ?? 0,
        moduleId: target.id,
      ),
    );
  }

  void _updateScopedSermonMetadata(Sermon next) {
    final draft = _draft;
    if (draft == null) return;
    _updateEditorDraft(
      draft.copyWith(title: next.title, subtitle: next.subtitle),
    );
  }

  Set<SermonWorkflowStage> _availableWorkflowStages(Sermon sermon) => {
    SermonWorkflowStage.outline,
    if (sermon.document.hasModule(SermonModuleKind.notes))
      SermonWorkflowStage.notes,
    if (sermon.document.hasModule(SermonModuleKind.script))
      SermonWorkflowStage.script,
    if (sermon.document.hasModule(SermonModuleKind.presentation))
      SermonWorkflowStage.presentation,
    SermonWorkflowStage.live,
  };

  void _queueSearch(String value) {
    _searchTimer?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      if (_searchQuery.isNotEmpty) setState(() => _searchQuery = '');
      return;
    }
    _searchTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() => _searchQuery = query);
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _searchController.clear();
    if (_searchQuery.isNotEmpty) setState(() => _searchQuery = '');
  }

  void _startOnboarding() {
    _clearSearch();
    setState(() {
      _focusMode = false;
      _backgroundPickerOpen = false;
      _onboardingStep = 0;
    });
  }

  void _advanceOnboarding() {
    final current = _onboardingStep;
    if (current == null) return;
    if (current >= _onboardingSteps.length - 1) {
      setState(() => _onboardingStep = null);
      return;
    }
    final next = current + 1;
    setState(() {
      if (next == 1) {
        _splitActive = false;
        _view = WorkspaceView.outline;
        if (_selectedId == null) {
          final sermons = ref
              .read(sermonsProvider)
              .valueOrNull
              ?.where((sermon) => !sermon.isDeleted)
              .toList(growable: false);
          final sermon = sermons?.firstOrNull;
          if (sermon != null) {
            _selectedId = sermon.id;
            _draft = sermon;
            _committedPlacement = _SermonPlacement.fromSermon(sermon);
            _navKey = _navKeyFor(sermon);
          }
        }
      }
      _onboardingStep = next;
    });
  }

  void _closeOnboarding() {
    if (_onboardingStep != null) setState(() => _onboardingStep = null);
  }

  Future<void> _showFeedbackForm() async {
    final receipt = await showDialog<LocalFeedbackReceipt>(
      context: context,
      builder: (context) => _FeedbackDialog(
        service: _feedbackService,
        sermonTitle: _draft?.title,
        screenshotPicker:
            widget.feedbackScreenshotPicker ?? _pickFeedbackScreenshot,
      ),
    );
    if (!mounted || receipt == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('feedback-success-dialog'),
        title: const Text('Feedback lokal gespeichert'),
        content: SizedBox(
          width: 430,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dein Feedback wurde nicht versendet. Es liegt zusammen mit '
                'dem Screenshot in diesem Ordner:',
              ),
              const SizedBox(height: 12),
              SelectableText(
                receipt.directory.path,
                key: const Key('feedback-saved-path'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Zum Verschicken einfach den Ordner „Sermonary Feedback“ '
                'aus Downloads komprimieren.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('feedback-reveal-folder'),
            onPressed: () => _revealFeedbackFolder(receipt.directory.path),
            child: const Text('Im Finder zeigen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fertig'),
          ),
        ],
      ),
    );
  }

  Future<XFile?> _pickFeedbackScreenshot() => openFile(
    confirmButtonText: 'Screenshot anhängen',
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Screenshot',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
      ),
    ],
  );

  Future<void> _revealFeedbackFolder(String path) async {
    try {
      await const MethodChannel(
        'sermonary/file_reveal',
      ).invokeMethod<void>('reveal', {'path': path});
    } on Object {
      await Clipboard.setData(ClipboardData(text: path));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Der Ordnerpfad wurde in die Zwischenablage kopiert.'),
        ),
      );
    }
  }

  Widget _buildWorkspaceCanvas(Sermon sermon) => _BlockSelectionScope(
    onStart: _startBlockSelection,
    onUpdate: _updateBlockSelection,
    onSelectAll: _selectAllActiveBlocks,
    onCopySelection: _copySelectedText,
    onCutSelection: _cutSelectedText,
    onDeleteSelection: _deleteSelectedText,
    onClearSelection: _clearBlockSelections,
    onUndo: _undo,
    onRedo: _redo,
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: const Key('editor-page-dismiss-focus'),
            behavior: HitTestBehavior.opaque,
            onTap: _clearEditorActiveBlock,
            child: _splitActive
                ? _SplitWorkspaceDropTarget(
                    onActivatePane: _activatePane,
                    onDrop: _openModuleInPane,
                    child: _buildContentBody(sermon),
                  )
                : _buildContentBody(sermon),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _splitActive
              ? Row(
                  children: [
                    Expanded(child: _buildPaneNavigation(sermon, 0)),
                    const SizedBox(width: 1),
                    Expanded(child: _buildPaneNavigation(sermon, 1)),
                  ],
                )
              : _buildPaneNavigation(sermon, 0),
        ),
      ],
    ),
  );

  Widget _buildPaneNavigation(Sermon sermon, int paneIndex) {
    final pane = _panes[paneIndex];
    final moduleId = pane.moduleId;
    return SermonWorkflowNavigation(
      key: ValueKey('pane-workflow-$paneIndex'),
      sermonTitle: sermon.title,
      activeStages: {
        if (pane.kind == _WorkspacePaneKind.outline)
          SermonWorkflowStage.outline,
        if (moduleId case final id?)
          switch (sermon.document.moduleById(id)?.kind) {
            SermonModuleKind.notes => SermonWorkflowStage.notes,
            SermonModuleKind.script => SermonWorkflowStage.script,
            SermonModuleKind.presentation => SermonWorkflowStage.presentation,
            null => SermonWorkflowStage.outline,
          },
      },
      availableStages: _availableWorkflowStages(sermon),
      contentItems: [
        for (final module in sermon.document.effectiveModules)
          SermonWorkflowContentItem(
            id: module.id,
            label: _moduleDisplayTitle(module),
            onboardingKey:
                paneIndex == 0 &&
                    sermon.document.modulesOfKind(module.kind).first.id ==
                        module.id
                ? switch (module.kind) {
                    SermonModuleKind.notes =>
                      _onboardingTargetKeys[_OnboardingTarget.notes],
                    SermonModuleKind.script =>
                      _onboardingTargetKeys[_OnboardingTarget.script],
                    SermonModuleKind.presentation =>
                      _onboardingTargetKeys[_OnboardingTarget.presentation],
                  }
                : null,
            stage: switch (module.kind) {
              SermonModuleKind.notes => SermonWorkflowStage.notes,
              SermonModuleKind.script => SermonWorkflowStage.script,
              SermonModuleKind.presentation => SermonWorkflowStage.presentation,
            },
            linked: module.linkGroupId != null,
          ),
      ],
      activeContentIds: moduleId == null ? const {} : {moduleId},
      onContentSelected: (id) => _openModuleInPane(id, paneIndex),
      onSelected: (stage) {
        if (stage == SermonWorkflowStage.live) {
          unawaited(_showLiveModeDialog(sermon));
        } else if (stage == SermonWorkflowStage.outline) {
          _openOutlineInPane(paneIndex);
        }
      },
    );
  }

  Widget _buildContentBody(Sermon sermon) {
    if (!_splitActive) return _buildPaneContent(sermon, _panes[0], 0);
    final leftModule = _panes[0].moduleId == null
        ? null
        : sermon.document.moduleById(_panes[0].moduleId!);
    final rightModule = _panes[1].moduleId == null
        ? null
        : sermon.document.moduleById(_panes[1].moduleId!);
    if (leftModule != null && rightModule != null) {
      final comparesVersions =
          leftModule.id != rightModule.id &&
          leftModule.kind == rightModule.kind &&
          leftModule.kind != SermonModuleKind.presentation &&
          _moduleVersionRoot(leftModule) == _moduleVersionRoot(rightModule);
      if (comparesVersions) {
        return KeyedSubtree(
          key: ValueKey(
            'version-comparison-${leftModule.id}-${rightModule.id}',
          ),
          child: _buildLinkedTextModuleSplit(
            sermon,
            leftModule,
            rightModule,
            alignContentBlocks: true,
          ),
        );
      }
      final linked = sermon.document.modulesAreLinked(
        leftModule.id,
        rightModule.id,
      );
      if (linked &&
          leftModule.kind != SermonModuleKind.presentation &&
          rightModule.kind != SermonModuleKind.presentation) {
        return KeyedSubtree(
          key: ValueKey('split-title-${sermon.id}'),
          child: _buildLinkedTextModuleSplit(sermon, leftModule, rightModule),
        );
      }
      if (leftModule.kind != SermonModuleKind.presentation &&
          rightModule.kind != SermonModuleKind.presentation) {
        final sharedHeadingIds = leftModule.blockIds
            .where(rightModule.blockIds.contains)
            .where(
              (id) => sermon.document.blocks.any(
                (block) => block.id == id && block is HeadingBlock,
              ),
            )
            .toList(growable: false);
        return _ModuleSplitView(
          key: ValueKey('module-split-${leftModule.id}-${rightModule.id}'),
          leftModuleId: leftModule.id,
          rightModuleId: rightModule.id,
          linked: false,
          sharedHeadingIds: sharedHeadingIds,
          leftKeys: _richKeysForModule(leftModule.id),
          rightKeys: _richKeysForModule(rightModule.id),
          left: _buildModuleEditor(sermon, leftModule.id),
          right: _buildModuleEditor(sermon, rightModule.id),
        );
      }
    }
    return Row(
      children: [
        Expanded(child: _buildPaneFrame(sermon, 0)),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(child: _buildPaneFrame(sermon, 1)),
      ],
    );
  }

  Widget _buildPaneFrame(
    Sermon sermon,
    int paneIndex,
  ) => DragTarget<_ModuleDragData>(
    key: Key('workspace-pane-frame-$paneIndex'),
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) =>
        _openModuleInPane(details.data.moduleId, paneIndex),
    builder: (context, candidates, rejected) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => _activatePane(paneIndex),
      child: AnimatedContainer(
        duration: AppMotion.quick,
        decoration: BoxDecoration(
          border: Border.all(
            color: candidates.isNotEmpty
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .55)
                : _activePaneIndex == paneIndex
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .06)
                : Colors.transparent,
          ),
        ),
        child: _buildPaneContent(sermon, _panes[paneIndex], paneIndex),
      ),
    ),
  );

  Widget _buildPaneContent(
    Sermon sermon,
    _WorkspacePaneState pane,
    int paneIndex,
  ) {
    if (pane.kind == _WorkspacePaneKind.empty) {
      return _EmptyWorkspacePane(
        onOpen: () => _showPaneContentPicker(paneIndex),
      );
    }
    if (pane.kind == _WorkspacePaneKind.outline) {
      return SingleChildScrollView(child: _buildOutlineContent(sermon));
    }
    final module = sermon.document.moduleById(pane.moduleId!);
    if (module == null) return const SizedBox.shrink();
    if (module.kind == SermonModuleKind.presentation) {
      return _buildPresentationEditor(sermon, module);
    }
    return SingleChildScrollView(
      child: _buildModuleEditor(sermon, module.id),
    );
  }

  Widget _buildPresentationEditor(Sermon sermon, SermonModule module) =>
      PresentationEditorView(
        sermon: _scopedSermon(sermon, module.id),
        selectedSlideId: _selectedPresentationSlideId,
        onSelectSlide: (id) =>
            setState(() => _selectedPresentationSlideId = id),
        onDeckChanged: (deck) =>
            _updatePresentationDeckForModule(module.id, deck),
        onPickImage: () =>
            const PresentationMediaService().pickAndStoreImage(sermon.id),
        onExportPdf: () => _exportPresentation(
          _PresentationExportFormat.pdf,
          moduleId: module.id,
        ),
        onExportPowerPoint: () => _exportPresentation(
          _PresentationExportFormat.powerPointEditable,
          moduleId: module.id,
        ),
        onExportImagePowerPoint: () => _exportPresentation(
          _PresentationExportFormat.powerPointImages,
          moduleId: module.id,
        ),
        smartAddAvailable: _smartSlideSelection(sermon) != null,
        onSmartAdd: _addSmartPresentationSlide,
        compact: _splitActive,
      );

  Widget _buildOutlineContent(Sermon sermon) {
    final series =
        ref.watch(sermonSeriesProvider).valueOrNull ?? const <SermonSeries>[];
    final backgroundSermon = _committedPlacement?.applyTo(sermon) ?? sermon;
    final backgroundImageId = _effectiveBackgroundImageId(
      backgroundSermon,
      series,
    );
    return _OutlineView(
      sermon: sermon,
      onboardingKey: _onboardingTargetKeys[_OnboardingTarget.outline]!,
      onChanged: _updateDraft,
      onShowAddModuleDialog: _showAddContentDialog,
      onShowAddLinkedModuleDialog: _showAddLinkedContentDialog,
      onBibleReferenceTextChanged: (value) {
        _pendingBibleReferenceTexts[sermon.id] = value;
      },
      onSave: () => _save(commitPlacement: true),
      backgroundImageId: backgroundImageId,
      backgroundPickerOpen: _backgroundPickerOpen,
      onToggleBackgroundPicker: () => setState(
        () => _backgroundPickerOpen = !_backgroundPickerOpen,
      ),
      onSelectBackground: (backgroundImageId) {
        _updateDraft(sermon.copyWith(backgroundImageId: backgroundImageId));
        setState(() => _backgroundPickerOpen = false);
      },
      activeBlockId: _activeBlockId,
      richKeys: _richKeys,
      onActivate: _activateBlock,
      onUpdateBlock: _updateBlock,
      onInsertAfter: _insertBlockAfter,
      onDelete: _deleteBlock,
      onNavigate: _navigateFromBlock,
      onPaste: _pasteRichClipboard,
    );
  }

  Widget _buildLinkedTextModuleSplit(
    Sermon sermon,
    SermonModule leftModule,
    SermonModule rightModule, {
    bool alignContentBlocks = false,
  }) {
    final document = sermon.document;
    final segments = _linkedTextSegments(document, leftModule, rightModule);
    final headingModule = _activeModuleId == rightModule.id
        ? rightModule
        : leftModule;
    final headingKeys = _richKeysForModule(headingModule.id);
    final leftKeys = _richKeysForModule(leftModule.id);
    final rightKeys = _richKeysForModule(rightModule.id);
    final leftFocus = _focusedBlockIdsForModule(document, leftModule.id);
    final rightFocus = _focusedBlockIdsForModule(document, rightModule.id);
    final headingFocus = _activeBlockId == null
        ? null
        : <String>{_activeBlockId!};

    void insertFor(
      String moduleId,
      String afterId,
      DocumentBlock next, {
      bool focusAtEnd = true,
    }) => _insertBlockAfterInModule(
      moduleId,
      afterId,
      next,
      focusAtEnd: focusAtEnd,
    );

    Widget contentBlock(
      SermonModule module,
      DocumentBlock block,
      DocumentBlock? previous,
      Set<String>? focusedIds,
      Map<String, GlobalKey<_RichBlockFieldState>> keys,
    ) {
      final scoped = _scopedSermon(sermon, module.id);
      final noteMode = module.kind == SermonModuleKind.notes;
      return _DocumentBlockField(
        block: block,
        previous: previous,
        active: _activeBlockModuleId == module.id && _activeBlockId == block.id,
        dimmed: focusedIds != null && !focusedIds.contains(block.id),
        richKey: keys.putIfAbsent(block.id, GlobalKey.new),
        onActivate: (id) => _activateBlockInModule(module.id, id),
        onChanged: _updateBlock,
        onInsertAfter: (afterId, next, {focusAtEnd = true}) => insertFor(
          module.id,
          afterId,
          next,
          focusAtEnd: focusAtEnd,
        ),
        onDelete: _deleteBlock,
        onNavigate: (id, direction) =>
            _navigateFromBlockInModule(module.id, id, direction),
        onPaste: _pasteRichClipboard,
        noteMode: noteMode,
        slides: scoped.document.presentation.slides,
        anchorView: noteMode
            ? PresentationAnchorView.notes
            : PresentationAnchorView.script,
        onAnchorSlide: (slide, blockId, view, offset) =>
            _anchorPresentationSlide(
              slide,
              blockId,
              view,
              offset,
              sourceModuleId: module.id,
            ),
        focusKeyPrefix: module.id,
      );
    }

    Widget emptyContent(SermonModule module, _LinkedTextSegment segment) {
      final notes = module.kind == SermonModuleKind.notes;
      return _GhostAdd(
        label: notes ? 'Stichpunkt' : 'Absatz hinzufügen',
        bullet: notes ? '—' : null,
        onTap: () {
          final now = DateTime.now().toUtc();
          final next = notes
              ? NoteBlock(
                  id: const Uuid().v4(),
                  text: '',
                  visibility: NoteVisibility.editorOnly,
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
          insertFor(module.id, segment.heading?.id ?? '', next);
        },
      );
    }

    final overviewKeys = _richKeysForModule('linked-overview');
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.splitWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48, 54, 48, 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScriptMeta(
                  sermon: sermon,
                  onChanged: _updateScopedSermonMetadata,
                ),
                const SizedBox(height: 30),
                _BareTextField(
                  initialValue: sermon.title,
                  hintText: 'Titel',
                  maxLines: null,
                  style: _titleStyle(context),
                  onChanged: (value) => _updateScopedSermonMetadata(
                    sermon.copyWith(title: value),
                  ),
                ),
                const SizedBox(height: 28),
                _SermonOverviewEditor(
                  keyPrefix: 'split',
                  sermon: sermon,
                  activeBlockId: _activeBlockId,
                  richKeys: overviewKeys,
                  onActivate: _activateBlock,
                  onUpdateSermon: _updateScopedSermonMetadata,
                  onUpdateBlock: _updateBlock,
                  onInsertAfter: _insertBlockAfter,
                  onDelete: _deleteBlock,
                  onNavigate: _navigateFromBlock,
                  onPaste: _pasteRichClipboard,
                ),
                const SizedBox(height: 38),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ColumnLabel(
                        '${_moduleLabel(leftModule.kind).toUpperCase()} · ${_moduleDisplayTitle(leftModule)}',
                      ),
                    ),
                    Expanded(
                      child: _ColumnLabel(
                        '${_moduleLabel(rightModule.kind).toUpperCase()} · ${_moduleDisplayTitle(rightModule)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                for (final segment in segments) ...[
                  if (segment.headings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 34, bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < segment.headings.length;
                            index++
                          )
                            _DocumentBlockField(
                              block: segment.headings[index],
                              previous: index == 0
                                  ? null
                                  : segment.headings[index - 1],
                              active:
                                  _activeBlockId == segment.headings[index].id,
                              dimmed:
                                  headingFocus != null &&
                                  !headingFocus.contains(
                                    segment.headings[index].id,
                                  ),
                              richKey: headingKeys.putIfAbsent(
                                segment.headings[index].id,
                                GlobalKey.new,
                              ),
                              onActivate: (id) => _activateBlockInModule(
                                headingModule.id,
                                id,
                              ),
                              onChanged: _updateBlock,
                              onInsertAfter:
                                  (afterId, next, {focusAtEnd = true}) =>
                                      insertFor(
                                        headingModule.id,
                                        afterId,
                                        next,
                                        focusAtEnd: focusAtEnd,
                                      ),
                              onDelete: _deleteBlock,
                              onNavigate: (id, direction) =>
                                  _navigateFromBlockInModule(
                                    headingModule.id,
                                    id,
                                    direction,
                                  ),
                              onPaste: _pasteRichClipboard,
                              noteMode:
                                  headingModule.kind == SermonModuleKind.notes,
                              focusKeyPrefix: 'linked',
                            ),
                        ],
                      ),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        if (alignContentBlocks)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (segment.left.isEmpty && segment.right.isEmpty)
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 40,
                                        ),
                                        child: emptyContent(
                                          leftModule,
                                          segment,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 40,
                                        ),
                                        child: emptyContent(
                                          rightModule,
                                          segment,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              for (
                                var index = 0;
                                index <
                                    math.max(
                                      segment.left.length,
                                      segment.right.length,
                                    );
                                index++
                              )
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 40,
                                        ),
                                        child: index < segment.left.length
                                            ? contentBlock(
                                                leftModule,
                                                segment.left[index],
                                                index == 0
                                                    ? segment.heading
                                                    : segment.left[index - 1],
                                                leftFocus,
                                                leftKeys,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 40,
                                        ),
                                        child: index < segment.right.length
                                            ? contentBlock(
                                                rightModule,
                                                segment.right[index],
                                                index == 0
                                                    ? segment.heading
                                                    : segment.right[index - 1],
                                                rightFocus,
                                                rightKeys,
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 40),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < segment.left.length;
                                        index++
                                      )
                                        contentBlock(
                                          leftModule,
                                          segment.left[index],
                                          index == 0
                                              ? segment.heading
                                              : segment.left[index - 1],
                                          leftFocus,
                                          leftKeys,
                                        ),
                                      if (segment.left.isEmpty)
                                        emptyContent(leftModule, segment),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 1),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 40),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      for (
                                        var index = 0;
                                        index < segment.right.length;
                                        index++
                                      )
                                        contentBlock(
                                          rightModule,
                                          segment.right[index],
                                          index == 0
                                              ? segment.heading
                                              : segment.right[index - 1],
                                          rightFocus,
                                          rightKeys,
                                        ),
                                      if (segment.right.isEmpty)
                                        emptyContent(rightModule, segment),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          left: constraints.maxWidth / 2,
                          child: ColoredBox(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            child: const SizedBox(width: 1),
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
      ),
    );
  }

  Widget _buildModuleEditor(Sermon sermon, String moduleId) {
    final module = sermon.document.moduleById(moduleId);
    if (module == null) return const SizedBox.shrink();
    final scoped = _scopedSermon(sermon, moduleId);
    final richKeys = _richKeysForModule(moduleId);
    final focusedBlockIds = _focusedBlockIdsForModule(
      sermon.document,
      moduleId,
    );
    void insert(
      String afterId,
      DocumentBlock next, {
      bool focusAtEnd = true,
    }) => _insertBlockAfterInModule(
      moduleId,
      afterId,
      next,
      focusAtEnd: focusAtEnd,
    );
    bool navigate(String id, int direction) =>
        _navigateFromBlockInModule(moduleId, id, direction);
    return switch (module.kind) {
      SermonModuleKind.notes => _NotesView(
        sermon: scoped,
        activeBlockId: _activeBlockId,
        focusedBlockIds: focusedBlockIds,
        focusKeyPrefix: _splitActive ? moduleId : null,
        richKeys: richKeys,
        onActivate: (id) => _activateBlockInModule(moduleId, id),
        onUpdateSermon: _updateScopedSermonMetadata,
        onUpdateBlock: _updateBlock,
        onInsertAfter: insert,
        onDelete: _deleteBlock,
        onNavigate: navigate,
        onPaste: _pasteRichClipboard,
        slides: scoped.document.presentation.slides,
        onAnchorSlide: (slide, blockId, view, offset) =>
            _anchorPresentationSlide(
              slide,
              blockId,
              view,
              offset,
              sourceModuleId: moduleId,
            ),
      ),
      SermonModuleKind.script => _ScriptView(
        sermon: scoped,
        activeBlockId: _activeBlockId,
        focusedBlockIds: focusedBlockIds,
        focusKeyPrefix: _splitActive ? moduleId : null,
        richKeys: richKeys,
        onActivate: (id) => _activateBlockInModule(moduleId, id),
        onUpdateSermon: _updateScopedSermonMetadata,
        onUpdateBlock: _updateBlock,
        onInsertAfter: insert,
        onDelete: _deleteBlock,
        onNavigate: navigate,
        onPaste: _pasteRichClipboard,
        slides: scoped.document.presentation.slides,
        onAnchorSlide: (slide, blockId, view, offset) =>
            _anchorPresentationSlide(
              slide,
              blockId,
              view,
              offset,
              sourceModuleId: moduleId,
            ),
      ),
      SermonModuleKind.presentation => const SizedBox.shrink(),
    };
  }

  Set<String>? _focusedBlockIdsForModule(
    SermonDocument document,
    String targetModuleId,
  ) {
    final activeId = _activeBlockId;
    if (activeId == null) return null;
    final target = document.moduleById(targetModuleId);
    final source = _activeBlockModuleId == null
        ? document.effectiveModules
              .where((module) => module.blockIds.contains(activeId))
              .firstOrNull
        : document.moduleById(_activeBlockModuleId!);
    if (target == null || source == null) return <String>{};
    if (target.id == source.id) return {activeId};
    if (!document.modulesAreLinked(target.id, source.id)) return <String>{};
    final activeBlock = document.blocks
        .where((block) => block.id == activeId)
        .firstOrNull;
    if (activeBlock is HeadingBlock) {
      return target.blockIds.contains(activeId) ? {activeId} : <String>{};
    }
    final activeIndex = source.blockIds.indexOf(activeId);
    if (activeIndex < 0) return <String>{};
    String? sectionHeadingId;
    for (var index = activeIndex; index >= 0; index--) {
      final id = source.blockIds[index];
      if (document.blocks.any(
        (block) => block.id == id && block is HeadingBlock,
      )) {
        sectionHeadingId = id;
        break;
      }
    }
    final targetIds = target.blockIds;
    final start = sectionHeadingId == null
        ? 0
        : targetIds.indexOf(sectionHeadingId);
    if (start < 0) return <String>{};
    var end = targetIds.length;
    for (var index = start + 1; index < targetIds.length; index++) {
      if (document.blocks.any(
        (block) => block.id == targetIds[index] && block is HeadingBlock,
      )) {
        end = index;
        break;
      }
    }
    return targetIds.sublist(start, end).toSet();
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
        modules: sermon.document.effectiveModules,
        presentation: sermon.document.presentation,
        blocks: normalized,
      ),
    );
  }

  Sermon _paginateExistingBibleSlides(Sermon sermon) {
    var changed = false;
    final slides = <PresentationSlide>[];
    for (final slide in sermon.document.presentation.slides) {
      if (slide.template != PresentationSlideTemplate.headingBible ||
          slide.continuationGroupId != null) {
        slides.add(slide);
        continue;
      }
      final parts = paginatePresentationBibleSlide(
        slide,
        createId: () => const Uuid().v4(),
      );
      changed = changed || parts.length > 1;
      slides.addAll(parts);
    }
    if (!changed) return sermon;
    return sermon.copyWith(
      document: sermon.document.copyWith(
        presentation: PresentationDeck(slides: slides),
      ),
    );
  }

  Sermon _normalizePresentationSlideOrder(Sermon sermon) {
    var changed = false;
    final modules = <SermonModule>[];
    for (final module in sermon.document.effectiveModules) {
      if (module.kind != SermonModuleKind.presentation) {
        modules.add(module);
        continue;
      }
      final orderedIds = orderPresentationSlidesByText(
        document: sermon.document,
        slides: sermon.document.slidesForModule(module.id),
      ).map((slide) => slide.id).toList(growable: false);
      final differs = !_sameStringOrder(orderedIds, module.slideIds);
      changed = changed || differs;
      modules.add(differs ? module.copyWith(slideIds: orderedIds) : module);
    }
    if (!changed) return sermon;
    return sermon.copyWith(
      document: sermon.document.copyWith(modules: modules),
    );
  }

  bool _presentationModuleOrderDiffers(
    SermonDocument before,
    SermonDocument after,
  ) => after.modulesOfKind(SermonModuleKind.presentation).any((module) {
    final previous = before.moduleById(module.id);
    return previous == null ||
        !_sameStringOrder(previous.slideIds, module.slideIds);
  });

  bool _sameStringOrder(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  String? _navKeyFor(Sermon sermon) {
    if (sermon.seriesId?.trim().isNotEmpty ?? false) {
      return 'series:${sermon.seriesId}';
    }
    return switch (sermon.contentKind) {
      ContentKind.talk => 'kind:talk',
      ContentKind.shortTopic => 'kind:short',
      ContentKind.introduction => 'kind:introduction',
      ContentKind.sermon =>
        sermon.primaryBibleReference == null
            ? null
            : 'book:${sermon.primaryBibleReference!.bookId}',
    };
  }

  List<Sermon> _entriesForNav(List<Sermon> sermons, {String? navigationKey}) {
    final key = navigationKey ?? _navKey;
    if (key == null) return const [];
    if (key.startsWith('book:')) {
      final bookId = key.substring(5);
      return sermons
          .where(
            (sermon) => sermon.primaryBibleReference?.bookId == bookId,
          )
          .toList(growable: false)
        ..sort(_comparePassages);
    }
    if (key.startsWith('series:')) {
      final series = key.substring(7);
      return sermons
          .where((sermon) => sermon.seriesId == series)
          .toList(growable: false)
        ..sort(_compareSeriesPositions);
    }
    final kind = key.substring(5);
    return sermons
        .where(
          (sermon) => switch (kind) {
            'talk' => sermon.contentKind == ContentKind.talk,
            'short' => sermon.contentKind == ContentKind.shortTopic,
            'introduction' => sermon.contentKind == ContentKind.introduction,
            _ => false,
          },
        )
        .toList(growable: false);
  }

  List<Sermon> _groupVersions(List<Sermon> sermons) {
    final byId = {for (final sermon in sermons) sermon.id: sermon};
    final children = <String, List<Sermon>>{};
    final roots = <Sermon>[];
    for (final sermon in sermons) {
      final rootId = sermon.versionRootId;
      if (rootId != null && byId.containsKey(rootId)) {
        children.putIfAbsent(rootId, () => []).add(sermon);
      } else {
        roots.add(sermon);
      }
    }
    final ordered = <Sermon>[];
    for (final root in roots) {
      ordered.add(root);
      final versions = (children[root.id] ?? <Sermon>[])
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      ordered.addAll(versions);
    }
    return ordered;
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

  int _compareSeriesPositions(Sermon left, Sermon right) {
    final leftPosition = left.seriesPosition;
    final rightPosition = right.seriesPosition;
    if (leftPosition != null && rightPosition != null) {
      final position = leftPosition.compareTo(rightPosition);
      if (position != 0) return position;
    } else if (leftPosition != null) {
      return -1;
    } else if (rightPosition != null) {
      return 1;
    }
    final title = left.title.compareTo(right.title);
    if (title != 0) return title;
    final created = left.createdAt.compareTo(right.createdAt);
    if (created != 0) return created;
    return left.id.compareTo(right.id);
  }

  void _selectNavigation(String key) {
    final sermons = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final first = _entriesForNav(
      sermons.where((sermon) => !sermon.isDeleted).toList(),
      navigationKey: key,
    ).firstOrNull;
    unawaited(_save(reconcileNavigation: false));
    _resetHistory();
    setState(() {
      _navKey = key;
      _selectedId = first?.id;
      if (_draft?.id != first?.id) {
        _draft = null;
        _activeBlockId = null;
        _activeModuleId = null;
        _resetPanesToOutline();
        _view = WorkspaceView.outline;
        _splitActive = false;
      }
      _saving = false;
    });
    _persistWorkspaceSession();
  }

  void _selectSermon(String id) {
    if (_selectedId == id) {
      _selectView(WorkspaceView.outline);
      return;
    }
    unawaited(_save(reconcileNavigation: false));
    _resetHistory();
    setState(() {
      _selectedId = id;
      _draft = null;
      _activeBlockId = null;
      _activeModuleId = null;
      _resetPanesToOutline();
      _selectedPresentationSlideId = null;
      _saving = false;
      _view = WorkspaceView.outline;
      _splitActive = false;
    });
    _persistWorkspaceSession();
  }

  void _selectView(WorkspaceView view) {
    if (view == WorkspaceView.outline) {
      _clearBlockSelections();
      setState(() {
        _activeBlockId = null;
        _activeModuleId = null;
        _view = WorkspaceView.outline;
        _splitActive = false;
        _resetPanesToOutline();
      });
      _persistWorkspaceSession();
      return;
    }
    final draft = _draft;
    final moduleKind = _moduleKindForView(view);
    if (draft == null || moduleKind == null) return;
    final current = _activeModuleId == null
        ? null
        : draft.document.moduleById(_activeModuleId!);
    final module = current?.kind == moduleKind
        ? current
        : draft.document.modulesOfKind(moduleKind).firstOrNull;
    if (module == null) return;
    _selectModule(module.id);
  }

  void _selectModule(String moduleId) {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module == null) return;
    if (!_splitActive) _clearBlockSelections();
    setState(() {
      if (!_splitActive) _activeBlockId = null;
      final view = _workspaceViewForModule(module.kind);
      if (module.kind == SermonModuleKind.presentation) {
        _selectedPresentationSlideId ??= draft.document
            .slidesForModule(module.id)
            .firstOrNull
            ?.id;
      }

      if (_splitActive) {
        final otherPaneIndex = _activePaneIndex == 0 ? 1 : 0;
        if (_panes[otherPaneIndex].moduleId == moduleId) {
          _panes[otherPaneIndex] = const _WorkspacePaneState.empty();
        }
        _panes[_activePaneIndex] = _WorkspacePaneState.module(moduleId);
        _activeModuleId = moduleId;
        _view = view;
        return;
      }

      _activeModuleId = moduleId;
      _view = view;
      _panes[0] = _WorkspacePaneState.module(moduleId);
      _panes[1] = const _WorkspacePaneState.empty();
      _activePaneIndex = 0;
    });
    _persistWorkspaceSession();
  }

  void _openModuleInPane(String moduleId, int paneIndex) {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module == null || paneIndex < 0 || paneIndex > 1) {
      return;
    }
    if (!_splitActive) _clearBlockSelections();
    setState(() {
      final otherPaneIndex = paneIndex == 0 ? 1 : 0;
      if (_panes[otherPaneIndex].moduleId == moduleId) {
        _panes[otherPaneIndex] = const _WorkspacePaneState.empty();
      }
      _panes[paneIndex] = _WorkspacePaneState.module(moduleId);
      _activePaneIndex = paneIndex;
      if (!_splitActive) _activeBlockId = null;
      _activeModuleId = moduleId;
      _view = _workspaceViewForModule(module.kind);
      if (module.kind == SermonModuleKind.presentation) {
        _selectedPresentationSlideId = draft.document
            .slidesForModule(module.id)
            .firstOrNull
            ?.id;
      }
    });
    _persistWorkspaceSession();
  }

  void _openOutlineInPane(int paneIndex) {
    _clearBlockSelections();
    setState(() {
      final otherPaneIndex = paneIndex == 0 ? 1 : 0;
      if (_panes[otherPaneIndex].kind == _WorkspacePaneKind.outline) {
        _panes[otherPaneIndex] = const _WorkspacePaneState.empty();
      }
      _panes[paneIndex] = const _WorkspacePaneState.outline();
      _activePaneIndex = paneIndex;
      _activeBlockId = null;
      _activeModuleId = null;
      _view = WorkspaceView.outline;
    });
    _persistWorkspaceSession();
  }

  Future<void> _showPaneContentPicker(int paneIndex) async {
    final draft = _draft;
    if (draft == null) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('pane-content-picker-$paneIndex'),
        title: const Text('Inhalt öffnen'),
        content: SizedBox(
          width: 380,
          height: math.min(
            440,
            64.0 * (draft.document.effectiveModules.length + 1),
          ),
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(LucideIcons.layoutTemplate, size: 17),
                title: const Text('Outline'),
                onTap: () => Navigator.pop(context, '__outline__'),
              ),
              for (final module in draft.document.effectiveModules)
                ListTile(
                  key: Key('pane-picker-module-${module.id}'),
                  leading: Icon(
                    switch (module.kind) {
                      SermonModuleKind.notes => LucideIcons.notebookPen,
                      SermonModuleKind.script => LucideIcons.scrollText,
                      SermonModuleKind.presentation =>
                        LucideIcons.galleryHorizontal,
                    },
                    size: 17,
                  ),
                  title: Text(_moduleDisplayTitle(module)),
                  subtitle: Text(_moduleLabel(module.kind)),
                  onTap: () => Navigator.pop(context, module.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    if (selected == '__outline__') {
      _openOutlineInPane(paneIndex);
    } else {
      _openModuleInPane(selected, paneIndex);
    }
  }

  void _toggleSplitMode() {
    _clearBlockSelections();
    setState(() {
      _activeBlockId = null;
      if (_splitActive) {
        var retained = _panes[_activePaneIndex];
        if (retained.isEmpty) retained = _panes[_activePaneIndex == 0 ? 1 : 0];
        if (retained.isEmpty) retained = const _WorkspacePaneState.outline();
        _panes[0] = retained;
        _panes[1] = const _WorkspacePaneState.empty();
        _activePaneIndex = 0;
        _splitActive = false;
        _applyActivePaneSelection();
        return;
      }
      _panes[0] = _currentPaneState();
      _panes[1] = const _WorkspacePaneState.empty();
      _activePaneIndex = 1;
      _splitActive = true;
    });
    _persistWorkspaceSession();
  }

  _WorkspacePaneState _currentPaneState() => _activeModuleId == null
      ? const _WorkspacePaneState.outline()
      : _WorkspacePaneState.module(_activeModuleId!);

  void _activatePane(int index) {
    if (!_splitActive || index == _activePaneIndex) return;
    setState(() {
      _activePaneIndex = index;
      _applyActivePaneSelection();
    });
    _persistWorkspaceSession();
  }

  void _applyActivePaneSelection() {
    final pane = _panes[_activePaneIndex];
    final module = pane.moduleId == null
        ? null
        : _draft?.document.moduleById(pane.moduleId!);
    _activeModuleId = module?.id;
    _view = module == null
        ? WorkspaceView.outline
        : _workspaceViewForModule(module.kind);
  }

  void _addContentModule(
    SermonModuleKind kind, {
    String? linkTargetModuleId,
  }) {
    final draft = _draft;
    if (draft == null) return;
    final now = DateTime.now().toUtc();
    final existing = draft.document.effectiveModules;
    final module = SermonModule(
      id: const Uuid().v4(),
      kind: kind,
      title: '',
      sortOrder:
          existing.fold<int>(-1, (max, item) => math.max(max, item.sortOrder)) +
          1,
      createdAt: now,
      updatedAt: now,
    );
    var document = SermonDocument(
      schemaVersion: SermonDocument.currentSchemaVersion,
      blocks: draft.document.blocks,
      presentation: draft.document.presentation,
      modules: [...existing, module],
    );
    if (linkTargetModuleId != null) {
      document = const ModuleLinkingService().link(
        document: document,
        sourceModuleId: module.id,
        targetModuleId: linkTargetModuleId,
        createGroupId: () => const Uuid().v4(),
        now: now,
      );
    }
    _updateDraft(
      draft.copyWith(
        document: document,
      ),
      startNewHistoryGroup: true,
    );
    _selectModule(module.id);
  }

  void _linkContentModules(String sourceModuleId, String targetModuleId) {
    final draft = _draft;
    if (draft == null || sourceModuleId == targetModuleId) return;
    try {
      final document = const ModuleLinkingService().link(
        document: draft.document,
        sourceModuleId: sourceModuleId,
        targetModuleId: targetModuleId,
        createGroupId: () => const Uuid().v4(),
        now: DateTime.now().toUtc(),
      );
      if (identical(document, draft.document)) return;
      _updateDraft(
        draft.copyWith(document: document),
        startNewHistoryGroup: true,
      );
    } on ModuleLinkConflict catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${error.message} Die Inhalte wurden nicht verändert.',
            ),
          ),
        );
    }
  }

  void _moveContentModule(String moduleId, int targetIndex) {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module == null) return;
    final ordered = _orderModulesForTree(draft.document.effectiveModules);
    final sourceIndex = ordered.indexWhere(
      (candidate) => candidate.id == moduleId,
    );
    if (sourceIndex < 0) return;
    final ids = ordered.map((candidate) => candidate.id).toList(growable: true);
    final adjustedTarget = (targetIndex - (sourceIndex < targetIndex ? 1 : 0))
        .clamp(0, ids.length - 1);
    if (module.linkGroupId == null && adjustedTarget == sourceIndex) return;
    ids
      ..removeAt(sourceIndex)
      ..insert(adjustedTarget, moduleId);

    final now = DateTime.now().toUtc();
    var document = draft.document;
    if (module.linkGroupId != null) {
      document = const ModuleLinkingService().unlink(
        document: document,
        moduleId: moduleId,
        createBlockId: () => const Uuid().v4(),
        now: now,
      );
    }
    final orderById = {
      for (var index = 0; index < ids.length; index++) ids[index]: index,
    };
    document = document.copyWith(
      modules: [
        for (final candidate in document.effectiveModules)
          candidate.copyWith(
            sortOrder: orderById[candidate.id] ?? candidate.sortOrder,
            updatedAt: candidate.id == moduleId ? now : candidate.updatedAt,
          ),
      ],
    );
    _updateDraft(
      draft.copyWith(document: document),
      startNewHistoryGroup: true,
    );
    _persistWorkspaceSession();
  }

  Future<void> _unlinkContentModule(String moduleId) async {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module?.linkGroupId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('unlink-sermon-module-$moduleId'),
        title: const Text('Verknüpfung aufheben?'),
        content: Text(
          '„${_moduleDisplayTitle(module!)}“ wird eigenständig. '
          'Gemeinsame Überschriften bleiben als eigene Kopien erhalten. '
          'Folienanker dieses Inhalts werden entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            key: Key('confirm-unlink-sermon-module-$moduleId'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verknüpfung aufheben'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _draft?.id != draft.id) return;
    final document = const ModuleLinkingService().unlink(
      document: draft.document,
      moduleId: moduleId,
      createBlockId: () => const Uuid().v4(),
      now: DateTime.now().toUtc(),
    );
    _updateDraft(
      draft.copyWith(document: document),
      startNewHistoryGroup: true,
    );
    _persistWorkspaceSession();
  }

  Future<void> _showAddContentDialog() async {
    final draft = _draft;
    if (draft == null) return;
    final selected = await showDialog<SermonModuleKind>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('add-content-dialog'),
        title: const Text('Inhalt hinzufügen'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Welche Ansicht möchtest du anlegen?'),
              ),
              const SizedBox(height: 14),
              for (final kind in SermonModuleKind.values)
                _DialogChoiceTile(
                  key: Key('add-content-${kind.name}'),
                  icon: _moduleIcon(kind),
                  title: _moduleLabel(kind),
                  onTap: () => Navigator.pop(context, kind),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted || _draft?.id != draft.id) return;
    _addContentModule(selected);
  }

  Future<void> _showAddLinkedContentDialog() async {
    final draft = _draft;
    final modules = draft?.document.effectiveModules ?? const <SermonModule>[];
    if (draft == null || modules.isEmpty) return;
    var targetId = modules.first.id;
    final selected = await showDialog<({SermonModuleKind kind, String targetId})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('add-linked-content-dialog'),
          title: const Text('Verknüpften Inhalt hinzufügen'),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verknüpfen mit'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: const Key('linked-content-target'),
                  initialValue: targetId,
                  isExpanded: true,
                  items: [
                    for (final module in modules)
                      DropdownMenuItem(
                        value: module.id,
                        child: Text(
                          '${_moduleLabel(module.kind)} · ${_moduleDisplayTitle(module)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => targetId = value);
                    }
                  },
                ),
                const SizedBox(height: 18),
                const Text('Neuer Inhalt'),
                const SizedBox(height: 8),
                for (final kind in SermonModuleKind.values)
                  _DialogChoiceTile(
                    key: Key('add-linked-content-${kind.name}'),
                    icon: _moduleIcon(kind),
                    title: _moduleLabel(kind),
                    onTap: () => Navigator.pop(
                      context,
                      (kind: kind, targetId: targetId),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted || _draft?.id != draft.id) return;
    _addContentModule(
      selected.kind,
      linkTargetModuleId: selected.targetId,
    );
  }

  Future<void> _showLiveModeDialog(Sermon sermon) async {
    final sources = sermon.document.effectiveModules
        .where(
          (module) =>
              module.kind == SermonModuleKind.notes ||
              module.kind == SermonModuleKind.script,
        )
        .toList(growable: false);
    if (sources.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Live-Ansicht'),
          content: const Text(
            'Füge zuerst Notizen oder ein Skript hinzu, um den Live-Modus '
            'zu starten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<SermonModule>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('live-content-dialog'),
        title: const Text('Live-Ansicht starten'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Welchen Inhalt möchtest du vortragen?'),
              ),
              const SizedBox(height: 14),
              for (final source in sources)
                _DialogChoiceTile(
                  key: Key(
                    sources
                            .takeWhile((module) => module.id != source.id)
                            .every((module) => module.kind != source.kind)
                        ? 'live-content-${source.kind.name}'
                        : 'live-content-${source.id}',
                  ),
                  icon: _moduleIcon(source.kind),
                  title:
                      '${_moduleLabel(source.kind)} · ${_moduleDisplayTitle(source)}',
                  onTap: () => Navigator.pop(context, source),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    final source = selected.kind == SermonModuleKind.notes ? 'notes' : 'script';
    context.go(
      '/sermons/${sermon.id}/live?source=$source&module=${selected.id}',
    );
  }

  void _duplicateContentModule(String moduleId) {
    final draft = _draft;
    final source = draft?.document.moduleById(moduleId);
    if (draft == null || source == null) return;

    final document = draft.document;
    final now = DateTime.now().toUtc();
    const uuid = Uuid();
    final rootId = document.versionRootIdFor(source);
    final nextRevision =
        document
            .versionsOf(source.id)
            .fold<int>(0, (value, module) => math.max(value, module.revision)) +
        1;
    final clonedBlocks = <DocumentBlock>[];
    final clonedBlockIds = <String>[];
    final blocksById = {for (final block in document.blocks) block.id: block};
    for (final blockId in source.blockIds) {
      final block = blocksById[blockId];
      if (block == null) continue;
      if (block is HeadingBlock && source.linkGroupId != null) {
        clonedBlockIds.add(block.id);
        continue;
      }
      final clone = _cloneDocumentBlock(
        block,
        id: uuid.v4(),
        now: now,
        createNestedId: uuid.v4,
      );
      clonedBlocks.add(clone);
      clonedBlockIds.add(clone.id);
    }

    final continuationGroups = <String, String>{};
    final clonedSlides = <PresentationSlide>[];
    for (final slide in document.slidesForModule(source.id)) {
      clonedSlides.add(
        _clonePresentationSlide(
          slide,
          id: uuid.v4(),
          continuationGroupId: slide.continuationGroupId == null
              ? null
              : continuationGroups.putIfAbsent(
                  slide.continuationGroupId!,
                  uuid.v4,
                ),
        ),
      );
    }

    final highestSortOrder = document.effectiveModules.fold<int>(
      -1,
      (value, module) => math.max(value, module.sortOrder),
    );
    final duplicate = SermonModule(
      id: uuid.v4(),
      kind: source.kind,
      title: source.title,
      sortOrder: highestSortOrder + 1,
      revision: nextRevision,
      blockIds: clonedBlockIds,
      slideIds: clonedSlides.map((slide) => slide.id).toList(growable: false),
      linkGroupId: source.linkGroupId,
      versionRootId: rootId,
      createdAt: now,
      updatedAt: now,
    );
    _updateDraft(
      draft.copyWith(
        document: document.copyWith(
          blocks: [...document.blocks, ...clonedBlocks],
          presentation: PresentationDeck(
            slides: [...document.presentation.slides, ...clonedSlides],
          ),
          modules: [...document.effectiveModules, duplicate],
        ),
      ),
      startNewHistoryGroup: true,
    );
    _selectModule(duplicate.id);
  }

  Future<void> _deleteContentModule(String moduleId) async {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module == null) return;
    final label = _moduleLabel(module.kind);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label löschen?'),
        content: Text(
          'Der gesamte Inhalt „${_moduleDisplayTitle(module)}“ wird aus dieser Predigt '
          'entfernt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            key: const Key('confirm-delete-sermon-module'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ansicht löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _draft?.id != draft.id) return;

    var remainingModules = draft.document.effectiveModules
        .where((candidate) => candidate.id != module.id)
        .toList(growable: false);
    final versionRootId = draft.document.versionRootIdFor(module);
    if (module.id == versionRootId) {
      final remainingVersions =
          remainingModules
              .where((candidate) => candidate.versionRootId == versionRootId)
              .toList(growable: false)
            ..sort((left, right) => left.revision.compareTo(right.revision));
      if (remainingVersions.isNotEmpty) {
        final promoted = remainingVersions.first;
        remainingModules = [
          for (final candidate in remainingModules)
            if (candidate.id == promoted.id)
              candidate.copyWith(clearVersionRootId: true)
            else if (candidate.versionRootId == versionRootId)
              candidate.copyWith(versionRootId: promoted.id)
            else
              candidate,
        ];
      }
    }
    final groupId = module.linkGroupId;
    if (groupId != null) {
      final groupMembers = remainingModules
          .where((candidate) => candidate.linkGroupId == groupId)
          .toList(growable: false);
      if (groupMembers.length == 1) {
        remainingModules = [
          for (final candidate in remainingModules)
            if (candidate.id == groupMembers.single.id)
              candidate.copyWith(clearLinkGroupId: true)
            else
              candidate,
        ];
      }
    }
    final retainedBlockIds = remainingModules
        .expand((candidate) => candidate.blockIds)
        .toSet();
    final blocks = draft.document.blocks
        .where(
          (block) =>
              retainedBlockIds.contains(block.id) ||
              (block is NoteBlock && block.isQuickNote),
        )
        .toList(growable: false);
    final deletedSlideIds = module.slideIds.toSet();
    final presentation = PresentationDeck(
      slides: [
        for (final slide in draft.document.presentation.slides)
          if (!deletedSlideIds.contains(slide.id))
            if (slide.anchor?.moduleId == module.id)
              slide.copyWith(clearAnchor: true)
            else
              slide,
      ],
    );

    setState(() {
      _view = WorkspaceView.outline;
      _splitActive = false;
      _activeModuleId = null;
      _resetPanesToOutline();
      _activeBlockId = null;
      _blockSelections.clear();
    });
    _updateDraft(
      draft.copyWith(
        document: draft.document.copyWith(
          blocks: blocks,
          presentation: presentation,
          modules: remainingModules,
        ),
      ),
      startNewHistoryGroup: true,
    );
    _persistWorkspaceSession();
  }

  void _renameContentModule(String moduleId, String title) {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null || module == null || module.title == title) return;
    _updateDraft(
      draft.copyWith(
        document: draft.document.copyWith(
          modules: [
            for (final candidate in draft.document.effectiveModules)
              if (candidate.id == moduleId)
                candidate.copyWith(
                  title: title,
                  updatedAt: DateTime.now().toUtc(),
                )
              else
                candidate,
          ],
        ),
      ),
      startNewHistoryGroup: true,
    );
  }

  void _updatePresentationDeckForModule(
    String moduleId,
    PresentationDeck deck,
  ) {
    final draft = _draft;
    final module = draft?.document.moduleById(moduleId);
    if (draft == null ||
        module == null ||
        module.kind != SermonModuleKind.presentation) {
      return;
    }
    final orderedSlides = orderPresentationSlidesByText(
      document: draft.document,
      slides: deck.slides,
    );
    final replacedIds = module.slideIds.toSet();
    final slides = [
      for (final slide in draft.document.presentation.slides)
        if (!replacedIds.contains(slide.id)) slide,
      ...orderedSlides,
    ];
    final now = DateTime.now().toUtc();
    _updateDraft(
      draft.copyWith(
        document: draft.document.copyWith(
          presentation: PresentationDeck(slides: slides),
          modules: [
            for (final candidate in draft.document.effectiveModules)
              if (candidate.id == moduleId)
                candidate.copyWith(
                  slideIds: orderedSlides
                      .map((slide) => slide.id)
                      .toList(growable: false),
                  updatedAt: now,
                )
              else
                candidate,
          ],
        ),
      ),
      startNewHistoryGroup: true,
    );
  }

  _SmartSlideSelection? _smartSlideSelection(Sermon sermon) {
    if (!_presentationVisible || !_splitActive) return null;
    final sourceModule = _visiblePanes
        .map((pane) => pane.moduleId)
        .whereType<String>()
        .map(sermon.document.moduleById)
        .whereType<SermonModule>()
        .where((module) => module.kind != SermonModuleKind.presentation)
        .lastOrNull;
    if (sourceModule == null) return null;
    final sourceBlocks = sermon.document.blocksForModule(sourceModule.id);
    final selections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere(
        (_, selection) => !selection.isValid || selection.isCollapsed,
      );
    if (selections.isEmpty) {
      final activeId = _activeBlockId;
      if (activeId != null) {
        final selection = _richKeys[activeId]?.currentState?.externalSelection;
        if (selection != null && selection.isValid && !selection.isCollapsed) {
          selections[activeId] = selection;
        }
      }
    }
    if (selections.isEmpty) return null;

    final parts = <_SmartSlidePart>[];
    var firstBlockIndex = -1;
    for (var index = 0; index < sourceBlocks.length; index++) {
      final block = sourceBlocks[index];
      final selection = selections[block.id];
      if (selection == null || block.plainText.isEmpty) continue;
      final start = selection.start.clamp(0, block.plainText.length);
      final end = selection.end.clamp(start, block.plainText.length);
      final text = block.plainText.substring(start, end).trim();
      if (text.isEmpty) continue;
      firstBlockIndex = firstBlockIndex < 0 ? index : firstBlockIndex;
      parts.add(_SmartSlidePart(block: block, text: text, start: start));
    }
    if (parts.isEmpty || firstBlockIndex < 0) return null;

    var contextTitle = '';
    for (var index = firstBlockIndex - 1; index >= 0; index--) {
      final candidate = sourceBlocks[index];
      if (candidate is HeadingBlock && candidate.text.trim().isNotEmpty) {
        contextTitle = candidate.text.trim();
        break;
      }
    }
    final selectedBibleQuote = parts
        .map((part) => part.block)
        .whereType<BibleQuoteBlock>()
        .firstOrNull;
    return _SmartSlideSelection(
      parts: parts,
      anchor: PresentationAnchor(
        view: _presentationCompanion == WorkspaceView.notes
            ? PresentationAnchorView.notes
            : PresentationAnchorView.script,
        blockId: parts.first.block.id,
        offset: parts.first.start,
        moduleId: sourceModule.id,
      ),
      contextTitle: contextTitle,
      reference:
          selectedBibleQuote?.reference.displayText ??
          sermon.primaryBibleReference?.displayText ??
          '',
    );
  }

  void _addSmartPresentationSlide(PresentationSlideTemplate template) {
    final draft = _draft;
    if (draft == null) return;
    final selection = _smartSlideSelection(draft);
    if (selection == null) return;
    final selectedHeading = selection.firstHeading;
    final contextualTitle = selectedHeading?.text.trim().isNotEmpty == true
        ? selectedHeading!.text.trim()
        : selection.contextTitle.isNotEmpty
        ? selection.contextTitle
        : draft.title;
    final body = selectedHeading == null
        ? selection.text
        : selection.bodyWithoutFirstHeading;
    final detectedBibleReference = _detectSmartBibleReference(body);
    final contentItems = selection.parts
        .where((part) => !identical(part, selectedHeading))
        .expand(
          (part) => part.text
              .split(RegExp(r'[\r\n]+'))
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty),
        )
        .toList(growable: false);
    final slide = switch (template) {
      PresentationSlideTemplate.title => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: selection.text,
        subtitle: draft.primaryBibleReference?.displayText ?? draft.subtitle,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.headingText => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: contextualTitle,
        body: body,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.headingBible => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: contextualTitle,
        body: detectedBibleReference?.body ?? body,
        reference: detectedBibleReference?.reference ?? selection.reference,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.contents => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: contextualTitle,
        items: contentItems.isEmpty ? [selection.text] : contentItems,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.largeContents => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        items: contentItems.isEmpty ? [selection.text] : contentItems,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.headingImage => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: contextualTitle,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.headingImageBible => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        title: contextualTitle,
        body: detectedBibleReference?.body ?? body,
        reference: detectedBibleReference?.reference ?? selection.reference,
        anchor: selection.anchor,
      ),
      PresentationSlideTemplate.image => PresentationSlide(
        id: const Uuid().v4(),
        template: template,
        caption: selection.text,
        anchor: selection.anchor,
      ),
    };
    final slides = paginatePresentationBibleSlide(
      slide,
      createId: () => const Uuid().v4(),
    );
    final presentationModule = _visibleModuleIds
        .map(draft.document.moduleById)
        .whereType<SermonModule>()
        .where((module) => module.kind == SermonModuleKind.presentation)
        .lastOrNull;
    final sourceModuleId = selection.anchor.moduleId;
    if (presentationModule == null || sourceModuleId == null) return;
    if (!draft.document.modulesAreLinked(
      presentationModule.id,
      sourceModuleId,
    )) {
      try {
        final linked = const ModuleLinkingService().link(
          document: draft.document,
          sourceModuleId: sourceModuleId,
          targetModuleId: presentationModule.id,
          createGroupId: () => const Uuid().v4(),
          now: DateTime.now().toUtc(),
        );
        _updateDraft(
          draft.copyWith(document: linked),
          startNewHistoryGroup: true,
        );
      } on ModuleLinkConflict catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        return;
      }
    }
    final current = _draft!;
    _updatePresentationDeckForModule(
      presentationModule.id,
      PresentationDeck(
        slides: [
          ...current.document.slidesForModule(presentationModule.id),
          ...slides,
        ],
      ),
    );
    setState(() => _selectedPresentationSlideId = slide.id);
  }

  void _anchorPresentationSlide(
    PresentationSlide slide,
    String blockId,
    PresentationAnchorView view,
    int offset, {
    required String sourceModuleId,
  }) {
    final draft = _draft;
    if (draft == null) return;
    final sourceModule = draft.document.moduleById(sourceModuleId);
    final presentationModule = _visibleModuleIds
        .map(draft.document.moduleById)
        .whereType<SermonModule>()
        .where((module) => module.kind == SermonModuleKind.presentation)
        .where(
          (module) =>
              module.slideIds.contains(slide.id) ||
              module.id == _activeModuleId,
        )
        .firstOrNull;
    if (sourceModule == null || presentationModule == null) return;
    var document = draft.document;
    if (!document.modulesAreLinked(sourceModule.id, presentationModule.id)) {
      try {
        document = const ModuleLinkingService().link(
          document: document,
          sourceModuleId: sourceModule.id,
          targetModuleId: presentationModule.id,
          createGroupId: () => const Uuid().v4(),
          now: DateTime.now().toUtc(),
        );
      } on ModuleLinkConflict catch (error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Die Folie kann hier nicht verankert werden: ${error.message}',
              ),
            ),
          );
        return;
      }
    }
    final block = document.blocks
        .where((item) => item.id == blockId)
        .firstOrNull;
    final normalizedView = sourceModule.kind == SermonModuleKind.notes
        ? PresentationAnchorView.notes
        : PresentationAnchorView.script;
    final anchored = slide.copyWith(
      title: block is HeadingBlock ? block.text : slide.title,
      anchor: PresentationAnchor(
        view: normalizedView,
        blockId: blockId,
        offset: offset.clamp(0, block?.plainText.length ?? 0),
        moduleId: sourceModule.id,
      ),
    );
    final groupId = anchored.continuationGroupId;
    var updatedDocument = document.copyWith(
      presentation: PresentationDeck(
        slides: [
          for (final item in document.presentation.slides)
            if (item.id == anchored.id)
              anchored
            else if (groupId != null && item.continuationGroupId == groupId)
              item.copyWith(
                title: block is HeadingBlock ? block.text : item.title,
                anchor: anchored.anchor,
              )
            else
              item,
        ],
      ),
    );
    final orderedSlideIds = orderPresentationSlidesByText(
      document: updatedDocument,
      slides: updatedDocument.slidesForModule(presentationModule.id),
    ).map((item) => item.id).toList(growable: false);
    updatedDocument = updatedDocument.copyWith(
      modules: [
        for (final module in updatedDocument.effectiveModules)
          if (module.id == presentationModule.id)
            module.copyWith(slideIds: orderedSlideIds)
          else
            module,
      ],
    );
    _updateDraft(
      draft.copyWith(
        document: updatedDocument,
      ),
      startNewHistoryGroup: true,
    );
    setState(() => _selectedPresentationSlideId = anchored.id);
  }

  Future<void> _createUnassignedEntry() async {
    await _save(reconcileNavigation: false);
    _clearSearch();
    final sermon = await _repository.create();
    _resetHistory();
    if (!mounted) return;
    setState(() {
      _pendingRepositorySelectionId = sermon.id;
      _navKey = null;
      _selectedId = sermon.id;
      _draft = sermon;
      _committedPlacement = _SermonPlacement.fromSermon(sermon);
      _activeBlockId = null;
      _saving = false;
      _view = WorkspaceView.outline;
      _splitActive = false;
      _focusMode = false;
      _backgroundPickerOpen = false;
    });
    _persistWorkspaceSession();
  }

  Future<void> _createEntry() async {
    final repository = _repository;
    var sermon = await repository.create();
    final key = _navKey;
    if (key?.startsWith('book:') ?? false) {
      final bookId = key!.substring(5);
      sermon = sermon.copyWith(
        primaryBibleReference: BibleReference(
          bookId: bookId,
          startChapter: 1,
          startVerse: 1,
          endChapter: 1,
          endVerse: 1,
          displayText: '${BibleBookCatalog.labelFor(bookId)} 1,1-1',
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
    // The dialog still paints its closing transition after its Future resolves.
    // Dispose only once that route can no longer rebuild the text field.
    Timer(const Duration(milliseconds: 300), controller.dispose);
    if (name == null || name.isEmpty) return;
    await _ensureSeriesExists(name);
    unawaited(_save(reconcileNavigation: false));
    setState(() {
      _navKey = 'series:$name';
      _selectedId = null;
      _draft = null;
      _activeBlockId = null;
    });
  }

  Future<void> _renameSeries(String currentName) async {
    await _save(reconcileNavigation: false);
    if (!mounted) return;
    final controller = TextEditingController(text: currentName);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vortragsreihe umbenennen'),
        content: TextField(
          key: const Key('rename-series-field'),
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
            child: const Text('Umbenennen'),
          ),
        ],
      ),
    );
    Timer(const Duration(milliseconds: 300), controller.dispose);
    final normalized = nextName?.trim();
    if (normalized == null || normalized.isEmpty || normalized == currentName) {
      return;
    }

    final database = ref.read(databaseProvider);
    final duplicateSeries = await (database.select(
      database.sermonSeriesRows,
    )..where((row) => row.title.equals(normalized))).get();
    final duplicateSermon = await (database.select(
      database.sermonRows,
    )..where((row) => row.seriesId.equals(normalized))).get();
    if (duplicateSeries.isNotEmpty || duplicateSermon.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eine Vortragsreihe mit diesem Namen existiert schon.'),
        ),
      );
      return;
    }

    final seriesRows = await (database.select(
      database.sermonSeriesRows,
    )..where((row) => row.title.equals(currentName))).get();
    final sermonRows = await (database.select(
      database.sermonRows,
    )..where((row) => row.seriesId.equals(currentName))).get();
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      for (final row in seriesRows) {
        await (database.update(
          database.sermonSeriesRows,
        )..where((item) => item.id.equals(row.id))).write(
          SermonSeriesRowsCompanion(
            title: Value(normalized),
            updatedAt: Value(now),
            revision: Value(row.revision + 1),
          ),
        );
      }
      for (final row in sermonRows) {
        await (database.update(
          database.sermonRows,
        )..where((item) => item.id.equals(row.id))).write(
          SermonRowsCompanion(
            seriesId: Value(normalized),
            updatedAt: Value(now),
            revision: Value(row.revision + 1),
          ),
        );
      }
    });
    if (!mounted) return;
    setState(() {
      if (_navKey == 'series:$currentName') {
        _navKey = 'series:$normalized';
      }
      final draft = _draft;
      if (draft?.seriesId == currentName) {
        final renamed = draft!.copyWith(seriesId: normalized);
        _draft = renamed;
        _committedPlacement = _SermonPlacement.fromSermon(renamed);
      }
    });
  }

  Future<void> _importSermon() async {
    final target = await showDialog<SermonImportTarget>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Predigt importieren'),
        content: const Text(
          'In welchen Bereich soll der Inhalt importiert werden?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, SermonImportTarget.notes),
            child: const Text('In Notes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, SermonImportTarget.script),
            child: const Text('In Script'),
          ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    // Let the Flutter modal finish closing before macOS presents NSOpenPanel.
    // Presenting two modal panels during the same transition is silently
    // cancelled on some macOS versions.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    XFile? file;
    try {
      file =
          await (widget.importFilePicker?.call() ??
              openFile(
                confirmButtonText: 'Importieren',
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'Sermonary-Import',
                    extensions: ['txt', 'md', 'markdown'],
                  ),
                ],
              ));
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die Dateiauswahl konnte nicht geöffnet werden. Bitte die App neu starten.',
          ),
        ),
      );
      return;
    }
    if (file == null) return;
    try {
      final imported = SermonImportParser().parse(
        await file.readAsString(),
        fileName: file.name,
        target: target,
      );
      if (imported.series != null) {
        await _ensureSeriesExists(imported.series!);
      }
      var sermon = await _repository.create();
      sermon = sermon.copyWith(
        title: imported.title,
        subtitle: imported.subtitle,
        status: imported.status,
        contentKind: imported.contentKind,
        primaryBibleReference: imported.primaryBibleReference,
        seriesId: imported.series,
        topics: imported.topics,
        tags: imported.tags,
        audience: imported.audience,
        location: imported.location,
        scheduledAt: imported.scheduledAt,
        plannedDurationMinutes: imported.plannedDurationMinutes,
        document: imported.document,
      );
      await _repository.update(sermon);
      if (!mounted) return;
      setState(() {
        _pendingRepositorySelectionId = sermon.id;
        _navKey = _navKeyFor(sermon);
        _selectedId = sermon.id;
        // Keep the parsed document as the active draft immediately. The
        // repository emits the initial empty row from create() before the
        // subsequent update on slower machines; loading that intermediate row
        // would otherwise leave the editor looking almost empty even though
        // the complete import is already stored in SQLite.
        _draft = sermon;
        _committedPlacement = _SermonPlacement.fromSermon(sermon);
        _activeBlockId = null;
        _view = WorkspaceView.outline;
        _splitActive = false;
      });
      final correctionCount = imported.corrections.length;
      final correctionNotice = correctionCount == 0
          ? ''
          : ' $correctionCount '
                '${correctionCount == 1 ? 'Syntaxkorrektur wurde' : 'Syntaxkorrekturen wurden'} '
                'automatisch vorgenommen.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '„${sermon.title}“ wurde importiert.$correctionNotice',
          ),
          duration: correctionCount == 0
              ? const Duration(seconds: 4)
              : const Duration(seconds: 7),
        ),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import nicht möglich: ${error.message}')),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Import nicht möglich. Bitte Dateiformat und UTF-8-Codierung prüfen.',
          ),
        ),
      );
    }
  }

  Future<void> _exportSermon(_SermonExportAction action) async {
    final draft = _draft;
    if (draft == null) return;
    final presentationFormat = action.presentationFormat;
    if (presentationFormat != null) {
      await _exportPresentation(presentationFormat);
      return;
    }
    final content = action.content!;
    final kind = content == SermonExportContent.notes
        ? SermonModuleKind.notes
        : SermonModuleKind.script;
    final module = await _chooseContentModule(
      draft,
      kind: kind,
      purpose: 'exportieren',
    );
    if (module == null || !mounted || _draft?.id != draft.id) return;
    final sermon = _scopedSermon(_draft!, module.id);
    await _save(reconcileNavigation: false);
    try {
      const exporter = SermonDocumentExporter();
      final format = action.format!;
      final exportName = _safeExportFileName(
        '${sermon.title}-${_moduleDisplayTitle(module)}',
      );
      if (format == _SermonExportFormat.print) {
        final bytes = await exporter.buildPdf(
          sermon,
          content: content,
        );
        await Printing.layoutPdf(
          name: exportName,
          dynamicLayout: false,
          onLayout: (_) async => bytes,
        );
        return;
      }

      final pdf = format == _SermonExportFormat.pdf;
      final extension = pdf ? 'pdf' : 'docx';
      final location = await getSaveLocation(
        suggestedName: '$exportName.$extension',
        acceptedTypeGroups: [
          XTypeGroup(
            label: pdf ? 'PDF-Dokument' : 'Word-Dokument',
            extensions: [extension],
          ),
        ],
      );
      if (location == null) return;
      final bytes = pdf
          ? await exporter.buildPdf(sermon, content: content)
          : exporter.buildWord(sermon, content: content);
      await XFile.fromData(
        bytes,
        mimeType: pdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ).saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pdf ? 'PDF gespeichert.' : 'Word-Datei gespeichert.'),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export fehlgeschlagen: $error')),
      );
    }
  }

  Future<SermonModule?> _chooseContentModule(
    Sermon sermon, {
    required SermonModuleKind kind,
    required String purpose,
  }) async {
    final modules = sermon.document.modulesOfKind(kind);
    if (modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Es ist kein Inhalt vom Typ ${_moduleLabel(kind)} vorhanden.',
          ),
        ),
      );
      return null;
    }
    if (modules.length == 1) return modules.single;
    return showDialog<SermonModule>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('choose-${kind.name}-module-dialog'),
        title: Text('${_moduleLabel(kind)} auswählen'),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Welchen Inhalt möchtest du $purpose?'),
              ),
              const SizedBox(height: 14),
              for (final module in modules)
                _DialogChoiceTile(
                  key: Key('choose-module-${module.id}'),
                  icon: _moduleIcon(module.kind),
                  title: _moduleDisplayTitle(module),
                  onTap: () => Navigator.pop(context, module),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPresentation(
    _PresentationExportFormat format, {
    String? moduleId,
  }) async {
    final draft = _draft;
    if (draft == null) return;
    final module = moduleId == null
        ? await _chooseContentModule(
            draft,
            kind: SermonModuleKind.presentation,
            purpose: 'exportieren',
          )
        : draft.document.moduleById(moduleId);
    if (module == null || !mounted || _draft?.id != draft.id) return;
    final sermon = _scopedSermon(_draft!, module.id);
    if (sermon.document.presentation.slides.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lege zuerst mindestens eine Folie an.')),
      );
      return;
    }
    await _save(reconcileNavigation: false);
    try {
      const exporter = PresentationExporter();
      final pdf = format == _PresentationExportFormat.pdf;
      final imagePowerPoint =
          format == _PresentationExportFormat.powerPointImages;
      final extension = pdf ? 'pdf' : 'pptx';
      final suffix = imagePowerPoint ? '-Präsentation-1zu1' : '-Präsentation';
      final location = await getSaveLocation(
        suggestedName:
            '${_safeExportFileName('${sermon.title}$suffix')}.$extension',
        acceptedTypeGroups: [
          XTypeGroup(
            label: pdf ? 'PDF-Präsentation' : 'PowerPoint-Präsentation',
            extensions: [extension],
          ),
        ],
      );
      if (location == null) return;
      final bytes = switch (format) {
        _PresentationExportFormat.pdf => await exporter.buildPdf(sermon),
        _PresentationExportFormat.powerPointEditable =>
          await exporter.buildPowerPoint(sermon),
        _PresentationExportFormat.powerPointImages =>
          await exporter.buildImagePowerPoint(
            sermon,
            await _renderPresentationSlides(sermon),
          ),
      };
      await XFile.fromData(
        bytes,
        mimeType: pdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ).saveTo(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pdf
                ? 'Präsentations-PDF gespeichert.'
                : imagePowerPoint
                ? 'Pixelgetreue PowerPoint gespeichert.'
                : 'Bearbeitbare PowerPoint gespeichert.',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Präsentationsexport fehlgeschlagen: $error')),
      );
    }
  }

  Future<List<Uint8List>> _renderPresentationSlides(Sermon sermon) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final result = <Uint8List>[];
    for (
      var index = 0;
      index < sermon.document.presentation.slides.length;
      index++
    ) {
      final slide = sermon.document.presentation.slides[index];
      if (slide.imagePath case final path?) {
        final file = File(path);
        if (file.existsSync()) {
          if (!mounted) {
            throw StateError('Präsentationsexport wurde abgebrochen.');
          }
          await precacheImage(FileImage(file), context);
        }
      }
      final repaintKey = GlobalKey();
      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) => Material(
          color: Theme.of(overlayContext).colorScheme.surface,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: 1280,
                height: 720,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SlideCanvas(slide: slide, large: true),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(overlayContext).colorScheme.surface,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Folie ${index + 1} von ${sermon.document.presentation.slides.length} wird gerendert …',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      overlay.insert(entry);
      try {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 24));
        final boundary = repaintKey.currentContext?.findRenderObject();
        if (boundary is! RenderRepaintBoundary) {
          throw StateError('Folie konnte nicht gerendert werden.');
        }
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (data == null) {
          throw StateError('Folie konnte nicht als Bild gespeichert werden.');
        }
        result.add(data.buffer.asUint8List());
      } finally {
        entry
          ..remove()
          ..dispose();
      }
    }
    return result;
  }

  Future<void> _ensureSeriesExists(String name) async {
    final database = ref.read(databaseProvider);
    final existing = await (database.select(
      database.sermonSeriesRows,
    )..where((row) => row.title.equals(name))).getSingleOrNull();
    if (existing != null) return;
    final now = DateTime.now().toUtc();
    await database
        .into(database.sermonSeriesRows)
        .insert(
          SermonSeriesRowsCompanion.insert(
            id: const Uuid().v4(),
            title: name,
            backgroundImageId: Value(_randomSeriesBackgroundImageId()),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> _showBackupDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datensicherung'),
        content: const Text(
          'Eine vollständige Sicherung enthält alle Predigten, Reihen, '
          'Versionen und Einstellungen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'restore'),
            child: const Text('Wiederherstellen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'backup'),
            child: const Text('Sicherung erstellen'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (action == 'backup') {
      await _createDatabaseBackup();
    } else {
      await _stageDatabaseRestore();
    }
  }

  Future<void> _createDatabaseBackup() async {
    await _save();
    if (!mounted) return;
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final location = await getSaveLocation(
      suggestedName: 'Sermonary-Sicherung-$date.sermonarybackup',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Sermonary-Sicherung',
          extensions: ['sermonarybackup'],
        ),
      ],
    );
    if (location == null) return;
    try {
      final service = await ref.read(databaseBackupServiceProvider.future);
      final record = await service.createManualBackup(location.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sicherung erstellt (Schema ${record.schemaVersion}).',
          ),
        ),
      );
    } on DatabaseBackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _stageDatabaseRestore() async {
    final file = await openFile(
      confirmButtonText: 'Sicherung auswählen',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Sermonary-Sicherung',
          extensions: ['sermonarybackup'],
        ),
      ],
    );
    if (file == null) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sicherung wiederherstellen?'),
        content: const Text(
          'Beim nächsten Start ersetzt diese Sicherung den aktuellen Stand. '
          'Vom jetzigen Stand wird vorher automatisch eine Rettungskopie '
          'erstellt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vormerken'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final service = await ref.read(databaseBackupServiceProvider.future);
      await service.stageRestore(file.path);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Wiederherstellung vorgemerkt'),
          content: const Text(
            'Bitte Sermonary jetzt vollständig schließen und neu starten. '
            'Die Sicherung wird vor dem Öffnen der Datenbank eingesetzt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Verstanden'),
            ),
          ],
        ),
      );
    } on DatabaseBackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
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
    await (ref
            .read(databaseProvider)
            .delete(
              ref.read(databaseProvider).sermonSeriesRows,
            )
          ..where((row) => row.title.equals(series)))
        .go();
    setState(() {
      _selectedId = null;
      _draft = null;
      _navKey = null;
    });
  }

  Future<void> _duplicateSermon(String id) async {
    if (_draft?.id == id) await _save(reconcileNavigation: false);
    final copy = await _repository.duplicate(id);
    if (!mounted) return;
    setState(() {
      _selectedId = copy.id;
      _draft = null;
      _activeBlockId = null;
    });
  }

  Future<void> _attachSermonAsVersion(
    String draggedId,
    String targetId,
  ) async {
    if (draggedId == targetId) return;
    if (_draft?.id == draggedId) {
      await _save(reconcileNavigation: false);
    }
    await _repository.attachAsVersion(draggedId, targetId);
    if (!mounted) return;
    if (_selectedId == draggedId) {
      setState(() => _draft = null);
    }
  }

  Future<void> _detachSermonVersion(String id) async {
    if (_draft?.id == id) await _save(reconcileNavigation: false);
    await _repository.detachVersion(id);
    if (!mounted) return;
    if (_selectedId == id) {
      setState(() => _draft = null);
    }
  }

  Future<void> _deleteSermon(String id) async {
    final sermons = ref.read(sermonsProvider).valueOrNull ?? const <Sermon>[];
    final sermon = sermons.where((item) => item.id == id).firstOrNull;
    if (sermon == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Predigt löschen?'),
        content: Text(
          '„${sermon.title.isEmpty ? 'Ohne Titel' : sermon.title}“ wird in den Papierkorb verschoben.',
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
    if (_draft?.id == id) await _save(reconcileNavigation: false);
    await _repository.moveToTrash(id);
    if (!mounted || _selectedId != id) return;
    setState(() {
      _selectedId = null;
      _draft = null;
      _activeBlockId = null;
    });
  }

  void _resetHistory() {
    _historyGroupTimer?.cancel();
    _historyGroupOpen = false;
    _undoStack.clear();
    _redoStack.clear();
  }

  void _recordHistory(Sermon current, {bool startNewGroup = false}) {
    if (_applyingHistory) return;
    if (startNewGroup || !_historyGroupOpen) {
      _undoStack.add(current);
      if (_undoStack.length > 100) _undoStack.removeAt(0);
    }
    _redoStack.clear();
    _historyGroupOpen = true;
    _historyGroupTimer?.cancel();
    _historyGroupTimer = Timer(const Duration(milliseconds: 700), () {
      _historyGroupOpen = false;
    });
  }

  void _updateDraft(Sermon next, {bool startNewHistoryGroup = false}) {
    final current = _draft;
    if (current != null && current != next) {
      _recordHistory(current, startNewGroup: startNewHistoryGroup);
    }
    setState(() {
      _draft = next;
      _saving = true;
    });
    _scheduleSave();
  }

  void _undo() {
    final current = _draft;
    if (current == null || _undoStack.isEmpty) return;
    _historyGroupTimer?.cancel();
    _historyGroupOpen = false;
    final previous = _undoStack.removeLast();
    _redoStack.add(current);
    _applyHistory(previous);
  }

  void _redo() {
    final current = _draft;
    if (current == null || _redoStack.isEmpty) return;
    _historyGroupTimer?.cancel();
    _historyGroupOpen = false;
    final next = _redoStack.removeLast();
    _undoStack.add(current);
    _applyHistory(next);
  }

  void _applyHistory(Sermon sermon) {
    _applyingHistory = true;
    _clearBlockSelections();
    setState(() {
      _draft = sermon;
      _activeBlockId = null;
      _saving = true;
    });
    _applyingHistory = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _draft?.id != sermon.id) return;
      for (final block in sermon.document.blocks) {
        for (final keys in _richKeysByModule.values) {
          keys[block.id]?.currentState?.syncContent(
            block.plainText,
            _inlineMarksOf(block),
          );
        }
      }
    });
    _scheduleSave();
  }

  void _updateEditorDraft(Sermon next) {
    _enterFocusMode();
    final previous = _draft;
    if (previous != null && previous.title != next.title) {
      _updateDraft(
        next.copyWith(
          document: next.document.copyWith(
            presentation: PresentationDeck(
              slides: [
                for (final slide in next.document.presentation.slides)
                  if (slide.template == PresentationSlideTemplate.title &&
                      (slide.title == previous.title || slide.title.isEmpty))
                    slide.copyWith(title: next.title)
                  else
                    slide,
              ],
            ),
          ),
        ),
      );
      return;
    }
    _updateDraft(next);
  }

  void _enterFocusMode() {
    if (!_focusMode) setState(() => _focusMode = true);
  }

  void _activateBlock(String id) => setState(() {
    _activeBlockId = id;
    _activeBlockModuleId = null;
  });

  void _activateBlockInModule(String moduleId, String id) => setState(() {
    _activeBlockId = id;
    _activeBlockModuleId = moduleId;
  });

  void _clearEditorActiveBlock() {
    _clearBlockSelections();
    FocusScope.of(context).unfocus();
    if (_activeBlockId != null) {
      setState(() {
        _activeBlockId = null;
        _activeBlockModuleId = null;
      });
    }
  }

  DocumentBlock? _activeBlock(SermonDocument document) =>
      document.blocks.where((block) => block.id == _activeBlockId).firstOrNull;

  bool _navigateFromBlock(String id, int direction) {
    final moduleId = _activeModuleId;
    if (moduleId != null) {
      return _navigateFromBlockInModule(moduleId, id, direction);
    }
    final draft = _draft;
    if (draft == null || direction == 0) return false;
    final current = draft.document.blocks
        .where((block) => block.id == id)
        .firstOrNull;
    if (current == null) return false;
    final candidates = current is NoteBlock
        ? draft.document.blocks.whereType<NoteBlock>().toList(growable: false)
        : draft.document.blocks
              .where(_isScriptEditorBlock)
              .toList(growable: false);
    final index = candidates.indexWhere((block) => block.id == id);
    final nextIndex = index + direction;
    if (index < 0 || nextIndex < 0 || nextIndex >= candidates.length) {
      return false;
    }
    final nextState = _richKeys[candidates[nextIndex].id]?.currentState;
    if (nextState == null) return false;
    nextState.requestFocus(atEnd: direction < 0);
    return true;
  }

  bool _navigateFromBlockInModule(
    String moduleId,
    String id,
    int direction,
  ) {
    final draft = _draft;
    if (draft == null || direction == 0) return false;
    final current = draft.document.blocks
        .where((block) => block.id == id)
        .firstOrNull;
    if (current == null) return false;
    final source = current is NoteBlock && current.isQuickNote
        ? draft.document.blocks
              .whereType<NoteBlock>()
              .where((block) => block.isQuickNote)
              .cast<DocumentBlock>()
              .toList(growable: false)
        : draft.document.blocksForModule(moduleId);
    final candidates = current is NoteBlock
        ? source.whereType<NoteBlock>().toList(growable: false)
        : source.where(_isScriptEditorBlock).toList(growable: false);
    final index = candidates.indexWhere((block) => block.id == id);
    final nextIndex = index + direction;
    if (index < 0 || nextIndex < 0 || nextIndex >= candidates.length) {
      return false;
    }
    final nextState = _richKeys[candidates[nextIndex].id]?.currentState;
    if (nextState == null) return false;
    nextState.requestFocus(atEnd: direction < 0);
    return true;
  }

  void _updateBlock(
    DocumentBlock next, {
    bool startNewHistoryGroup = false,
  }) {
    final draft = _draft;
    if (draft == null) return;
    final current = draft.document.blocks
        .where((block) => block.id == next.id)
        .firstOrNull;
    final modules = current == null
        ? draft.document.effectiveModules
        : _modulesForBlockTypeChange(
            draft.document,
            current: current,
            next: next,
          );
    _enterFocusMode();
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: modules,
          presentation: next is HeadingBlock
              ? PresentationDeck(
                  slides: [
                    for (final slide in draft.document.presentation.slides)
                      if (slide.anchor?.blockId == next.id)
                        slide.copyWith(title: next.text)
                      else
                        slide,
                  ],
                )
              : draft.document.presentation,
          blocks: [
            for (final block in draft.document.blocks)
              if (block.id == next.id) next else block,
          ],
        ),
      ),
      startNewHistoryGroup: startNewHistoryGroup,
    );
  }

  List<SermonModule> _modulesForBlockTypeChange(
    SermonDocument document, {
    required DocumentBlock current,
    required DocumentBlock next,
  }) {
    final wasHeading = current is HeadingBlock;
    final isHeading = next is HeadingBlock;
    if (wasHeading == isHeading) return document.effectiveModules;
    final requestedId = _activeBlockModuleId ?? _activeModuleId;
    final primary = requestedId == null
        ? document.effectiveModules
              .where((module) => module.blockIds.contains(current.id))
              .firstOrNull
        : document.moduleById(requestedId);
    if (primary == null || primary.linkGroupId == null) {
      return document.effectiveModules;
    }
    final now = DateTime.now().toUtc();
    if (!isHeading) {
      return [
        for (final module in document.effectiveModules)
          if (module.id != primary.id &&
              module.linkGroupId == primary.linkGroupId &&
              module.blockIds.contains(current.id))
            module.copyWith(
              blockIds: module.blockIds
                  .where((id) => id != current.id)
                  .toList(growable: false),
              updatedAt: now,
            )
          else
            module,
      ];
    }
    final primaryIndex = primary.blockIds.indexOf(current.id);
    final precedingHeadingId = primary.blockIds
        .take(math.max(0, primaryIndex))
        .toList(growable: false)
        .reversed
        .where(
          (id) => document.blocks.any(
            (block) => block.id == id && block is HeadingBlock,
          ),
        )
        .firstOrNull;
    return [
      for (final module in document.effectiveModules)
        if (module.id != primary.id &&
            module.linkGroupId == primary.linkGroupId &&
            module.kind != SermonModuleKind.presentation &&
            !module.blockIds.contains(current.id))
          module.copyWith(
            blockIds: _insertSharedHeadingId(
              document,
              module.blockIds,
              current.id,
              precedingHeadingId,
            ),
            updatedAt: now,
          )
        else
          module,
    ];
  }

  List<String> _insertSharedHeadingId(
    SermonDocument document,
    List<String> source,
    String headingId,
    String? precedingHeadingId,
  ) {
    final ids = [...source];
    var insertionIndex = 0;
    if (precedingHeadingId != null) {
      final previousIndex = ids.indexOf(precedingHeadingId);
      insertionIndex = previousIndex < 0 ? ids.length : previousIndex + 1;
      while (insertionIndex < ids.length) {
        final candidate = document.blocks
            .where((block) => block.id == ids[insertionIndex])
            .firstOrNull;
        if (candidate is HeadingBlock) break;
        insertionIndex++;
      }
    } else {
      final firstHeading = ids.indexWhere(
        (id) => document.blocks.any(
          (block) => block.id == id && block is HeadingBlock,
        ),
      );
      insertionIndex = firstHeading < 0 ? 0 : firstHeading;
    }
    ids.insert(insertionIndex, headingId);
    return ids;
  }

  void _insertBlockAfter(
    String afterId,
    DocumentBlock next, {
    bool focusAtEnd = true,
  }) {
    final moduleId = _activeModuleId;
    if (moduleId != null && !(next is NoteBlock && next.isQuickNote)) {
      _insertBlockAfterInModule(
        moduleId,
        afterId,
        next,
        focusAtEnd: focusAtEnd,
      );
      return;
    }
    final draft = _draft;
    if (draft == null) return;
    _enterFocusMode();
    final blocks = [...draft.document.blocks];
    final index = blocks.indexWhere((block) => block.id == afterId);
    blocks.insert(index < 0 ? blocks.length : index + 1, next);
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: draft.document.effectiveModules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    setState(() => _activeBlockId = next.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != next.id) return;
      _richKeys[next.id]?.currentState?.requestFocus(atEnd: focusAtEnd);
    });
  }

  void _insertBlockAfterInModule(
    String moduleId,
    String afterId,
    DocumentBlock next, {
    bool focusAtEnd = true,
  }) {
    if (next is NoteBlock && next.isQuickNote) {
      _insertBlockAfter(afterId, next, focusAtEnd: focusAtEnd);
      return;
    }
    final draft = _draft;
    final activeModule = draft?.document.moduleById(moduleId);
    if (draft == null || activeModule == null) return;
    _enterFocusMode();
    final blocks = [...draft.document.blocks, next];
    final activeIds = [...activeModule.blockIds];
    final activeIndex = activeIds.indexOf(afterId);
    activeIds.insert(
      activeIndex < 0 ? activeIds.length : activeIndex + 1,
      next.id,
    );
    final modules = <SermonModule>[];
    for (final module in draft.document.effectiveModules) {
      if (module.id == activeModule.id) {
        modules.add(
          module.copyWith(
            blockIds: activeIds,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
        continue;
      }
      if (next is! HeadingBlock ||
          activeModule.linkGroupId == null ||
          module.linkGroupId != activeModule.linkGroupId ||
          module.kind == SermonModuleKind.presentation) {
        modules.add(module);
        continue;
      }
      final precedingHeadingId = activeIds
          .take(activeIds.indexOf(next.id))
          .toList()
          .reversed
          .where(
            (id) =>
                draft.document.blocks
                        .where((block) => block.id == id)
                        .firstOrNull
                    is HeadingBlock,
          )
          .firstOrNull;
      final siblingIds = [...module.blockIds];
      var insertionIndex = siblingIds.length;
      if (precedingHeadingId != null) {
        final previousIndex = siblingIds.indexOf(precedingHeadingId);
        if (previousIndex >= 0) {
          insertionIndex = siblingIds.length;
          for (
            var index = previousIndex + 1;
            index < siblingIds.length;
            index++
          ) {
            final candidate = draft.document.blocks
                .where((block) => block.id == siblingIds[index])
                .firstOrNull;
            if (candidate is HeadingBlock) {
              insertionIndex = index;
              break;
            }
          }
        }
      } else {
        insertionIndex = siblingIds.indexWhere(
          (id) =>
              draft.document.blocks.where((block) => block.id == id).firstOrNull
                  is HeadingBlock,
        );
        if (insertionIndex < 0) insertionIndex = 0;
      }
      siblingIds.insert(insertionIndex, next.id);
      modules.add(module.copyWith(blockIds: siblingIds));
    }
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: SermonDocument.currentSchemaVersion,
          modules: modules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    setState(() {
      _activeModuleId = moduleId;
      _activeBlockId = next.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != next.id) return;
      _richKeys[next.id]?.currentState?.requestFocus(atEnd: focusAtEnd);
    });
  }

  Future<void> _pasteRichClipboard(
    String blockId,
    TextSelection selection, {
    required bool noteMode,
    required bool plainTextOnly,
  }) async {
    final content = await _clipboardReader.read();
    if (plainTextOnly) {
      _pastePlainText(blockId, selection, content);
      return;
    }
    final pasted = _pasteParser.parse(content);
    if (!mounted || pasted.isEmpty) return;
    final draft = _draft;
    if (draft == null) return;
    final blockIndex = draft.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (blockIndex < 0) return;
    final original = draft.document.blocks[blockIndex];
    final targetNoteMode = switch (original) {
      NoteBlock() => true,
      HeadingBlock() => noteMode,
      _ => false,
    };
    final text = original.plainText;
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, text.length)
        : text.length;
    final blockSelections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere((_, selection) => selection.isCollapsed);
    if (blockSelections.length > 1) {
      _pasteOverBlockSelection(
        draft: draft,
        selections: blockSelections,
        pasted: pasted,
        noteMode: targetNoteMode,
      );
      return;
    }
    if (pasted.length == 1 && pasted.single.kind == PastedBlockKind.body) {
      _pasteInlineRichBlock(
        draft: draft,
        blockIndex: blockIndex,
        original: original,
        pasted: pasted.single,
        start: start,
        end: end,
      );
      return;
    }
    final now = DateTime.now().toUtc();
    final replacement = <DocumentBlock>[];
    final prefix = text.substring(0, start);
    if (prefix.isNotEmpty) {
      replacement.add(
        _copyPastedBoundaryBlock(
          original,
          id: const Uuid().v4(),
          text: prefix,
          marks: _marksWithin(
            _inlineMarksOf(original),
            sourceStart: 0,
            sourceEnd: start,
          ),
          now: now,
        ),
      );
    }
    final quickNote = original is NoteBlock && original.isQuickNote;
    DocumentBlock? focusBlock;
    for (final item in pasted) {
      focusBlock = _documentBlockFromPaste(
        item,
        noteMode: targetNoteMode,
        quickNote: quickNote,
        now: now,
      );
      replacement.add(focusBlock);
    }
    final suffix = text.substring(end);
    if (suffix.isNotEmpty) {
      replacement.add(
        _copyPastedBoundaryBlock(
          original,
          id: const Uuid().v4(),
          text: suffix,
          marks: _marksWithin(
            _inlineMarksOf(original),
            sourceStart: end,
            sourceEnd: text.length,
          ),
          now: now,
        ),
      );
    }
    if (replacement.isEmpty) return;

    final modules = _replaceModuleBlockReferences(
      draft.document,
      selectedIds: {blockId},
      replacement: replacement,
    );
    final nextBlocks = _replaceDocumentBlocks(
      draft.document,
      modules: modules,
      selectedIds: {blockId},
      replacement: replacement,
    );
    _clearBlockSelections();
    _richKeys.remove(blockId);
    final focusTarget = focusBlock ?? replacement.last;
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: modules,
          presentation: draft.document.presentation,
          blocks: nextBlocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    setState(() => _activeBlockId = focusTarget.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != focusTarget.id) return;
      _richKeys[focusTarget.id]?.currentState?.requestFocusAt(
        focusTarget.plainText.length,
      );
    });
  }

  void _pasteOverBlockSelection({
    required Sermon draft,
    required Map<String, TextSelection> selections,
    required List<PastedBlock> pasted,
    required bool noteMode,
  }) {
    final selectionModuleId = _activeBlockModuleId ?? _activeModuleId;
    final orderedSource = selectionModuleId == null
        ? draft.document.blocks
        : draft.document.blocksForModule(selectionModuleId);
    final selected = orderedSource
        .where((block) => selections.containsKey(block.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    final first = selected.first;
    final last = selected.last;
    final firstSelection = selections[first.id]!;
    final lastSelection = selections[last.id]!;
    final firstStart = firstSelection.start.clamp(0, first.plainText.length);
    final lastEnd = lastSelection.end.clamp(0, last.plainText.length);
    final prefix = first.plainText.substring(0, firstStart);
    final suffix = last.plainText.substring(lastEnd);
    final prefixMarks = _marksWithin(
      _inlineMarksOf(first),
      sourceStart: 0,
      sourceEnd: firstStart,
    );
    final suffixMarks = _marksWithin(
      _inlineMarksOf(last),
      sourceStart: lastEnd,
      sourceEnd: last.plainText.length,
    );
    final now = DateTime.now().toUtc();
    final quickNote = first is NoteBlock && first.isQuickNote;
    final replacement = <DocumentBlock>[];
    String? focusId;
    var focusOffset = 0;

    final canMergeBody =
        pasted.length == 1 &&
        pasted.single.kind == PastedBlockKind.body &&
        _canMergeSelectedBoundaries(first, last);
    if (canMergeBody) {
      final item = pasted.single;
      final mergedMarks = <InlineMark>[
        ...prefixMarks,
        for (final mark in item.marks)
          InlineMark(
            start: prefix.length + mark.start,
            end: prefix.length + mark.end,
            bold: mark.bold,
            italic: mark.italic,
            highlighted: mark.highlighted,
          ),
        ...[
          for (final mark in suffixMarks)
            InlineMark(
              start: prefix.length + item.text.length + mark.start,
              end: prefix.length + item.text.length + mark.end,
              bold: mark.bold,
              italic: mark.italic,
              highlighted: mark.highlighted,
            ),
        ],
      ];
      final merged = _withRichText(
        first,
        '$prefix${item.text}$suffix',
        mergedMarks,
      );
      replacement.add(merged);
      focusId = merged.id;
      focusOffset = prefix.length + item.text.length;
    } else {
      if (prefix.isNotEmpty) {
        replacement.add(_withRichText(first, prefix, prefixMarks));
      }
      for (final item in pasted) {
        final inserted = _documentBlockFromPaste(
          item,
          noteMode: noteMode,
          quickNote: quickNote,
          now: now,
        );
        replacement.add(inserted);
        focusId = inserted.id;
        focusOffset = inserted.plainText.length;
      }
      if (suffix.isNotEmpty) {
        replacement.add(_withRichText(last, suffix, suffixMarks));
      }
    }

    final selectedIds = selections.keys.toSet();
    final modules = _replaceModuleBlockReferences(
      draft.document,
      selectedIds: selectedIds,
      replacement: replacement,
    );
    final blocks = _replaceDocumentBlocks(
      draft.document,
      modules: modules,
      selectedIds: selectedIds,
      replacement: replacement,
    );
    _clearBlockSelections();
    for (final id in selectedIds) {
      if (!replacement.any((block) => block.id == id)) _richKeys.remove(id);
    }
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: modules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    setState(() => _activeBlockId = focusId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || focusId == null || _activeBlockId != focusId) return;
      _richKeys[focusId]?.currentState?.requestFocusAt(focusOffset);
    });
  }

  List<SermonModule> _replaceModuleBlockReferences(
    SermonDocument document, {
    required Set<String> selectedIds,
    required List<DocumentBlock> replacement,
  }) {
    final requestedModuleId = _activeBlockModuleId ?? _activeModuleId;
    final primary = requestedModuleId == null
        ? document.effectiveModules
              .where(
                (module) => module.blockIds.any(selectedIds.contains),
              )
              .firstOrNull
        : document.moduleById(requestedModuleId);
    if (primary == null) return document.effectiveModules;
    final selectedHeadingIds = document.blocks
        .whereType<HeadingBlock>()
        .where((block) => selectedIds.contains(block.id))
        .map((block) => block.id)
        .toSet();
    final replacementHeadingIds = replacement
        .whereType<HeadingBlock>()
        .map((block) => block.id)
        .toList(growable: false);
    final now = DateTime.now().toUtc();

    List<String> replaceIds(
      List<String> source,
      Set<String> targets,
      List<String> replacements,
    ) {
      final result = <String>[];
      var inserted = false;
      for (final id in source) {
        if (!targets.contains(id)) {
          result.add(id);
        } else if (!inserted) {
          result.addAll(replacements);
          inserted = true;
        }
      }
      return result;
    }

    return [
      for (final module in document.effectiveModules)
        if (module.id == primary.id)
          module.copyWith(
            blockIds: replaceIds(
              module.blockIds,
              selectedIds,
              replacement.map((block) => block.id).toList(growable: false),
            ),
            updatedAt: now,
          )
        else if (primary.linkGroupId != null &&
            module.linkGroupId == primary.linkGroupId &&
            module.kind != SermonModuleKind.presentation &&
            module.blockIds.any(selectedHeadingIds.contains))
          module.copyWith(
            blockIds: replaceIds(
              module.blockIds,
              selectedHeadingIds,
              replacementHeadingIds,
            ),
            updatedAt: now,
          )
        else
          module,
    ];
  }

  List<DocumentBlock> _replaceDocumentBlocks(
    SermonDocument document, {
    required List<SermonModule> modules,
    required Set<String> selectedIds,
    required List<DocumentBlock> replacement,
  }) {
    final replacementIds = replacement.map((block) => block.id).toSet();
    final stillReferenced = modules.expand((module) => module.blockIds).toSet();
    final firstIndex = document.blocks.indexWhere(
      (block) => selectedIds.contains(block.id),
    );
    final insertionIndex = firstIndex < 0
        ? document.blocks.length
        : document.blocks
              .take(firstIndex)
              .where(
                (block) =>
                    !replacementIds.contains(block.id) &&
                    (!selectedIds.contains(block.id) ||
                        stillReferenced.contains(block.id)),
              )
              .length;
    final blocks = [
      for (final block in document.blocks)
        if (!replacementIds.contains(block.id) &&
            (!selectedIds.contains(block.id) ||
                stillReferenced.contains(block.id)))
          block,
    ];
    blocks.insertAll(insertionIndex.clamp(0, blocks.length), replacement);
    return blocks;
  }

  void _pasteInlineRichBlock({
    required Sermon draft,
    required int blockIndex,
    required DocumentBlock original,
    required PastedBlock pasted,
    required int start,
    required int end,
  }) {
    final source = original.plainText;
    final prefix = source.substring(0, start);
    final suffix = source.substring(end);
    final nextText = '$prefix${pasted.text}$suffix';
    final nextMarks = <InlineMark>[
      ..._marksWithin(
        _inlineMarksOf(original),
        sourceStart: 0,
        sourceEnd: start,
      ),
      for (final mark in pasted.marks)
        InlineMark(
          start: prefix.length + mark.start,
          end: prefix.length + mark.end,
          bold: mark.bold,
          italic: mark.italic,
          highlighted: mark.highlighted,
        ),
      ..._marksWithin(
        _inlineMarksOf(original),
        sourceStart: end,
        sourceEnd: source.length,
        targetOffset: prefix.length + pasted.text.length,
      ),
    ];
    final nextBlock = _withRichText(original, nextText, nextMarks);
    final blocks = [...draft.document.blocks]..[blockIndex] = nextBlock;
    _clearBlockSelections();
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: draft.document.effectiveModules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    final cursorOffset = prefix.length + pasted.text.length;
    setState(() => _activeBlockId = original.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != original.id) return;
      final state = _richKeys[original.id]?.currentState;
      state?.syncContent(nextText, nextMarks);
      state?.requestFocusAt(cursorOffset);
    });
  }

  void _pastePlainText(
    String blockId,
    TextSelection selection,
    RichClipboardContent content,
  ) {
    final draft = _draft;
    if (!mounted || draft == null) return;
    final index = draft.document.blocks.indexWhere(
      (block) => block.id == blockId,
    );
    if (index < 0) return;
    final original = draft.document.blocks[index];
    final source = original.plainText;
    final start = selection.isValid
        ? selection.start.clamp(0, source.length)
        : source.length;
    final end = selection.isValid
        ? selection.end.clamp(start, source.length)
        : source.length;
    final plain =
        (content.plainText ??
                _pasteParser
                    .parse(content)
                    .map((block) => block.text)
                    .join('\n'))
            .replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n');
    if (plain.isEmpty) return;
    final prefix = source.substring(0, start);
    final suffix = source.substring(end);
    final nextText = '$prefix$plain$suffix';
    final nextMarks = <InlineMark>[
      ..._marksWithin(
        _inlineMarksOf(original),
        sourceStart: 0,
        sourceEnd: start,
      ),
      ..._marksWithin(
        _inlineMarksOf(original),
        sourceStart: end,
        sourceEnd: source.length,
        targetOffset: prefix.length + plain.length,
      ),
    ];
    final nextBlock = _withRichText(original, nextText, nextMarks);
    final blocks = [...draft.document.blocks]..[index] = nextBlock;
    _clearBlockSelections();
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: draft.document.effectiveModules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    final cursorOffset = prefix.length + plain.length;
    setState(() => _activeBlockId = blockId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != blockId) return;
      final state = _richKeys[blockId]?.currentState;
      state?.syncContent(nextText, nextMarks);
      state?.requestFocusAt(cursorOffset);
    });
  }

  void _deleteBlock(String id) {
    final draft = _draft;
    if (draft == null) return;
    final blocks = draft.document.blocks;
    final current = blocks.where((block) => block.id == id).firstOrNull;
    if (current == null) return;
    final editingModuleId = _activeBlockModuleId ?? _activeModuleId;
    final module = editingModuleId == null
        ? null
        : draft.document.moduleById(editingModuleId);
    final owner = module?.blockIds.contains(id) == true
        ? module
        : draft.document.effectiveModules
              .where((candidate) => candidate.blockIds.contains(id))
              .firstOrNull;
    final orderedBlocks = current is NoteBlock && current.isQuickNote
        ? blocks
              .whereType<NoteBlock>()
              .where((block) => block.isQuickNote)
              .cast<DocumentBlock>()
              .toList(growable: false)
        : owner == null
        ? blocks
        : draft.document.blocksForModule(owner.id);
    final currentIndex = orderedBlocks.indexWhere((block) => block.id == id);
    if (currentIndex < 0) return;
    DocumentBlock? previous;
    if (current is! HeadingBlock && current is! BibleQuoteBlock) {
      for (var index = currentIndex - 1; index >= 0; index--) {
        final candidate = orderedBlocks[index];
        if (candidate is HeadingBlock) break;
        if (current is NoteBlock) {
          if (candidate is NoteBlock &&
              candidate.isQuickNote == current.isQuickNote) {
            previous = candidate;
            break;
          }
        } else if (candidate is! NoteBlock) {
          previous = candidate;
          break;
        }
      }
    }
    if (previous != null && _canMergeSelectedBoundaries(previous, current)) {
      final mergeTarget = previous;
      final seam = mergeTarget.plainText.length;
      final mergedMarks = <InlineMark>[
        ..._inlineMarksOf(mergeTarget),
        ..._marksWithin(
          _inlineMarksOf(current),
          sourceStart: 0,
          sourceEnd: current.plainText.length,
          targetOffset: seam,
        ),
      ];
      final merged = _withRichText(
        mergeTarget,
        '${mergeTarget.plainText}${current.plainText}',
        mergedMarks,
      );
      _clearBlockSelections();
      _richKeys.remove(id);
      final nextBlocks = [
        for (final block in blocks)
          if (block.id == mergeTarget.id) merged else if (block.id != id) block,
      ];
      final nextModules = [
        for (final candidate in draft.document.effectiveModules)
          if (candidate.blockIds.contains(id))
            candidate.copyWith(
              blockIds: candidate.blockIds
                  .where((blockId) => blockId != id)
                  .toList(growable: false),
            )
          else
            candidate,
      ];
      _updateDraft(
        draft.copyWith(
          document: SermonDocument(
            schemaVersion: draft.document.schemaVersion,
            modules: nextModules,
            presentation: draft.document.presentation,
            blocks: nextBlocks,
          ),
        ),
        startNewHistoryGroup: true,
      );
      setState(() => _activeBlockId = mergeTarget.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _activeBlockId != mergeTarget.id) return;
        final state = _richKeys[mergeTarget.id]?.currentState;
        state?.syncContent(merged.plainText, mergedMarks);
        state?.requestFocusAt(seam);
      });
      return;
    }
    if (current.plainText.isNotEmpty) return;
    _richKeys.remove(id);
    final nextModules = [
      for (final candidate in draft.document.effectiveModules)
        if (candidate.blockIds.contains(id))
          candidate.copyWith(
            blockIds: candidate.blockIds
                .where((blockId) => blockId != id)
                .toList(growable: false),
          )
        else
          candidate,
    ];
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: nextModules,
          presentation: draft.document.presentation,
          blocks: draft.document.blocks
              .where((block) => block.id != id)
              .toList(growable: false),
        ),
      ),
      startNewHistoryGroup: true,
    );
    setState(() => _activeBlockId = null);
  }

  void _changeActiveBlockType(String type) {
    final draft = _draft;
    final active = draft == null ? null : _activeBlock(draft.document);
    if (active == null) return;
    final targetsNotes = _activeBlockTargetsNotes(active);
    final normalizedType = switch ((targetsNotes, type)) {
      (true, 'p' || 'quote') => 'li',
      (false, 'li' || 'li2') => 'p',
      _ => type,
    };
    final now = DateTime.now().toUtc();
    final next = switch (normalizedType) {
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
      'h3' => HeadingBlock(
        id: active.id,
        level: 3,
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
        depth: normalizedType == 'li2' ? 1 : 0,
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
    _updateBlock(next, startNewHistoryGroup: true);
  }

  void _changeActiveBlockToQuote() {
    final draft = _draft;
    final active = draft == null ? null : _activeBlock(draft.document);
    if (active == null || _activeBlockTargetsNotes(active)) return;
    _changeActiveBlockType('quote');
  }

  bool _activeBlockTargetsNotes(DocumentBlock active) {
    if (active is NoteBlock) return true;
    if (_splitActive) {
      final moduleId = _activeBlockModuleId;
      if (moduleId != null) {
        return _draft?.document.moduleById(moduleId)?.kind ==
            SermonModuleKind.notes;
      }
    }
    return _view == WorkspaceView.notes;
  }

  List<DocumentBlock> _selectableBlocks({String? anchorId}) {
    final draft = _draft;
    if (draft == null) {
      return const <DocumentBlock>[];
    }
    final active = anchorId == null
        ? _activeBlock(draft.document)
        : draft.document.blocks
              .where((block) => block.id == anchorId)
              .firstOrNull;
    if (active is NoteBlock && active.isQuickNote) {
      return draft.document.blocks
          .where(
            (block) =>
                block is NoteBlock &&
                block.isQuickNote &&
                (_richKeys[block.id]?.currentState?.mounted ?? false),
          )
          .toList(growable: false);
    }
    if (_view == WorkspaceView.outline) return const <DocumentBlock>[];
    final notesColumn =
        active is NoteBlock || (!_splitActive && _view == WorkspaceView.notes);
    return draft.document.blocks
        .where(
          (block) =>
              (block is ParagraphBlock ||
                  block is QuoteBlock ||
                  block is BibleQuoteBlock ||
                  block is NoteBlock ||
                  block is HeadingBlock) &&
              (notesColumn
                  ? block is HeadingBlock ||
                        (block is NoteBlock && !block.isQuickNote)
                  : block is HeadingBlock || block is! NoteBlock) &&
              (_richKeys[block.id]?.currentState?.mounted ?? false),
        )
        .toList(growable: false);
  }

  void _startBlockSelection(String id, int offset) {
    final matchingScope = _richKeysByModule.entries
        .where((entry) => entry.value[id]?.currentState?.mounted ?? false)
        .where(
          (entry) =>
              entry.value[id]?.currentState?._focusNode.hasFocus ?? false,
        )
        .firstOrNull;
    final fallbackScope =
        matchingScope ??
        _richKeysByModule.entries
            .where((entry) => entry.value[id]?.currentState?.mounted ?? false)
            .firstOrNull;
    if (fallbackScope != null && fallbackScope.key != 'outline') {
      _activeBlockModuleId = fallbackScope.key;
    }
    final state = _richKeys[id]?.currentState;
    if (state == null) return;
    _selectionAnchorId = id;
    _selectionAnchorOffset = offset.clamp(0, state.textLength);
    _setBlockSelections({
      id: TextSelection.collapsed(offset: _selectionAnchorOffset!),
    });
  }

  void _updateBlockSelection(Offset globalPosition) {
    final anchorId = _selectionAnchorId;
    final anchorOffset = _selectionAnchorOffset;
    if (anchorId == null || anchorOffset == null) return;
    final blocks = _selectableBlocks(anchorId: anchorId);
    final anchorIndex = blocks.indexWhere((block) => block.id == anchorId);
    if (anchorIndex < 0) return;

    var targetIndex = -1;
    var shortestDistance = double.infinity;
    for (var index = 0; index < blocks.length; index++) {
      final state = _richKeys[blocks[index].id]?.currentState;
      final bounds = state?.globalBounds;
      if (bounds == null) continue;
      final verticalDistance = globalPosition.dy < bounds.top
          ? bounds.top - globalPosition.dy
          : globalPosition.dy > bounds.bottom
          ? globalPosition.dy - bounds.bottom
          : 0.0;
      if (verticalDistance < shortestDistance) {
        shortestDistance = verticalDistance;
        targetIndex = index;
      }
    }
    if (targetIndex < 0) return;
    final targetState = _richKeys[blocks[targetIndex].id]!.currentState!;
    final targetOffset = targetState.offsetForGlobalPosition(globalPosition);
    final first = math.min(anchorIndex, targetIndex);
    final last = math.max(anchorIndex, targetIndex);
    final next = <String, TextSelection>{};
    for (var index = first; index <= last; index++) {
      final id = blocks[index].id;
      final state = _richKeys[id]?.currentState;
      if (state == null) continue;
      final selection = switch ((index == anchorIndex, index == targetIndex)) {
        (true, true) => TextSelection(
          baseOffset: anchorOffset,
          extentOffset: targetOffset,
        ),
        (true, false) =>
          targetIndex > anchorIndex
              ? TextSelection(
                  baseOffset: anchorOffset,
                  extentOffset: state.textLength,
                )
              : TextSelection(baseOffset: 0, extentOffset: anchorOffset),
        (false, true) =>
          targetIndex > anchorIndex
              ? TextSelection(baseOffset: 0, extentOffset: targetOffset)
              : TextSelection(
                  baseOffset: targetOffset,
                  extentOffset: state.textLength,
                ),
        _ => TextSelection(baseOffset: 0, extentOffset: state.textLength),
      };
      next[id] = selection;
    }
    _setBlockSelections(next);
  }

  void _selectAllActiveBlocks() {
    final blocks = _selectableBlocks();
    if (blocks.isEmpty) return;
    final next = <String, TextSelection>{};
    for (final block in blocks) {
      final state = _richKeys[block.id]?.currentState;
      if (state == null || state.textLength == 0) continue;
      next[block.id] = TextSelection(
        baseOffset: 0,
        extentOffset: state.textLength,
      );
    }
    if (next.isEmpty) return;
    _selectionAnchorId = blocks.first.id;
    _selectionAnchorOffset = 0;
    _setBlockSelections(next);
  }

  void _setBlockSelections(Map<String, TextSelection> next) {
    _clearBlockSelections(except: next.keys);
    _blockSelections
      ..clear()
      ..addAll(next);
    for (final entry in next.entries) {
      final state = _richKeys[entry.key]?.currentState;
      if (state != null) state.externalSelection = entry.value;
    }
  }

  void _clearBlockSelections({Object? except}) {
    final retained = switch (except) {
      final String id => <String>{id},
      final Iterable<String> ids => ids.toSet(),
      _ => const <String>{},
    };
    for (final id in _blockSelections.keys.where(
      (id) => !retained.contains(id),
    )) {
      _richKeys[id]?.currentState?.clearExternalSelection();
    }
    if (retained.isEmpty) {
      _blockSelections.clear();
      _selectionAnchorId = null;
      _selectionAnchorOffset = null;
    }
  }

  bool _copySelectedText() {
    final draft = _draft;
    if (draft == null) return false;
    final selections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere((_, selection) => selection.isCollapsed);
    if (selections.isEmpty) return false;
    final selectedBlocks =
        <({DocumentBlock block, String text, List<InlineMark> marks})>[];
    for (final block in draft.document.blocks) {
      final selection = selections[block.id];
      if (selection == null) continue;
      final text = block.plainText;
      final start = selection.start.clamp(0, text.length);
      final end = selection.end.clamp(start, text.length);
      if (start < end) {
        selectedBlocks.add((
          block: block,
          text: text.substring(start, end),
          marks: _marksWithin(
            _inlineMarksOf(block),
            sourceStart: start,
            sourceEnd: end,
          ),
        ));
      }
    }
    if (selectedBlocks.isEmpty) return false;
    unawaited(_clipboardWriter.write(_clipboardContent(selectedBlocks)));
    return true;
  }

  bool _cutSelectedText() {
    if (!_copySelectedText()) return false;
    return _deleteSelectedText();
  }

  bool _deleteSelectedText() {
    final draft = _draft;
    if (draft == null) return false;
    final selections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere((_, selection) => selection.isCollapsed);
    if (selections.isEmpty) return false;
    final selectedBlocks = draft.document.blocks
        .where((block) => selections.containsKey(block.id))
        .toList(growable: false);
    if (selectedBlocks.isEmpty) return false;

    final selectsWholeBlocks = selectedBlocks.every((block) {
      final selection = selections[block.id]!;
      return selection.start == 0 && selection.end == block.plainText.length;
    });
    if (selectsWholeBlocks &&
        selectedBlocks.any(
          (block) =>
              block is HeadingBlock ||
              block is NoteBlock ||
              block is BibleQuoteBlock,
        )) {
      final selectedIds = selections.keys.toSet();
      final modules = _replaceModuleBlockReferences(
        draft.document,
        selectedIds: selectedIds,
        replacement: const [],
      );
      final blocks = _replaceDocumentBlocks(
        draft.document,
        modules: modules,
        selectedIds: selectedIds,
        replacement: const [],
      );
      _clearBlockSelections();
      _updateDraft(
        draft.copyWith(
          document: SermonDocument(
            schemaVersion: draft.document.schemaVersion,
            modules: modules,
            presentation: draft.document.presentation,
            blocks: blocks,
          ),
        ),
        startNewHistoryGroup: true,
      );
      setState(() => _activeBlockId = null);
      return true;
    }

    final first = selectedBlocks.first;
    final last = selectedBlocks.last;
    final firstSelection = selections[first.id]!;
    final lastSelection = selections[last.id]!;
    final prefix = first.plainText.substring(0, firstSelection.start);
    final suffix = last.plainText.substring(lastSelection.end);
    if (first.id != last.id && !_canMergeSelectedBoundaries(first, last)) {
      final replacement = <DocumentBlock>[];
      if (prefix.isNotEmpty) {
        replacement.add(
          _withRichText(
            first,
            prefix,
            _marksWithin(
              _inlineMarksOf(first),
              sourceStart: 0,
              sourceEnd: firstSelection.start,
            ),
          ),
        );
      }
      if (suffix.isNotEmpty) {
        replacement.add(
          _withRichText(
            last,
            suffix,
            _marksWithin(
              _inlineMarksOf(last),
              sourceStart: lastSelection.end,
              sourceEnd: last.plainText.length,
            ),
          ),
        );
      }
      final selectedIds = selections.keys.toSet();
      final modules = _replaceModuleBlockReferences(
        draft.document,
        selectedIds: selectedIds,
        replacement: replacement,
      );
      final blocks = _replaceDocumentBlocks(
        draft.document,
        modules: modules,
        selectedIds: selectedIds,
        replacement: replacement,
      );
      _clearBlockSelections();
      _updateDraft(
        draft.copyWith(
          document: SermonDocument(
            schemaVersion: draft.document.schemaVersion,
            modules: modules,
            presentation: draft.document.presentation,
            blocks: blocks,
          ),
        ),
        startNewHistoryGroup: true,
      );
      final focus = replacement.firstOrNull;
      setState(() => _activeBlockId = focus?.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || focus == null || _activeBlockId != focus.id) return;
        _richKeys[focus.id]?.currentState?.requestFocusAt(prefix.length);
      });
      return true;
    }
    final mergedMarks = <InlineMark>[
      ..._marksWithin(
        _inlineMarksOf(first),
        sourceStart: 0,
        sourceEnd: firstSelection.start,
      ),
      ..._marksWithin(
        _inlineMarksOf(last),
        sourceStart: lastSelection.end,
        sourceEnd: last.plainText.length,
        targetOffset: prefix.length,
      ),
    ];
    final merged = _withRichText(first, '$prefix$suffix', mergedMarks);
    final selectedIds = selections.keys.toSet();
    final modules = _replaceModuleBlockReferences(
      draft.document,
      selectedIds: selectedIds,
      replacement: [merged],
    );
    final blocks = _replaceDocumentBlocks(
      draft.document,
      modules: modules,
      selectedIds: selectedIds,
      replacement: [merged],
    );
    _clearBlockSelections();
    _updateDraft(
      draft.copyWith(
        document: SermonDocument(
          schemaVersion: draft.document.schemaVersion,
          modules: modules,
          presentation: draft.document.presentation,
          blocks: blocks,
        ),
      ),
      startNewHistoryGroup: true,
    );
    _richKeys[first.id]?.currentState?.syncContent(
      merged.plainText,
      _inlineMarksOf(merged),
    );
    setState(() => _activeBlockId = first.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != first.id) return;
      _richKeys[first.id]?.currentState?.requestFocusAt(prefix.length);
    });
    return true;
  }

  void _applyInlineFormat(_InlineFormat format) {
    final draft = _draft;
    bool supportsFormatting(String id) {
      final block = draft?.document.blocks
          .where((block) => block.id == id)
          .firstOrNull;
      return block is ParagraphBlock ||
          block is QuoteBlock ||
          block is NoteBlock;
    }

    final selections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere((_, selection) => selection.isCollapsed);
    if (selections.isNotEmpty) {
      for (final entry in selections.entries) {
        if (supportsFormatting(entry.key)) {
          _richKeys[entry.key]?.currentState?.applyFormat(
            format,
            selection: entry.value,
          );
        }
      }
      return;
    }
    final id = _activeBlockId;
    if (id == null || !supportsFormatting(id)) return;
    _richKeys[id]?.currentState?.applyFormat(format);
  }

  void _clearActiveHighlights() {
    final selections = Map<String, TextSelection>.from(_blockSelections)
      ..removeWhere((_, selection) => selection.isCollapsed);
    if (selections.isNotEmpty) {
      for (final entry in selections.entries) {
        _richKeys[entry.key]?.currentState?.clearHighlights(
          selection: entry.value,
        );
      }
      _clearBlockSelections();
      return;
    }
    final id = _activeBlockId;
    if (id == null) return;
    _richKeys[id]?.currentState?.clearHighlights();
  }

  Future<void> _showBibleReferencePicker() async {
    final draft = _draft;
    if (draft == null || _view == WorkspaceView.outline) return;
    final activeBeforeDialog = _activeBlock(draft.document);
    final insertAsNote = activeBeforeDialog == null
        ? _view == WorkspaceView.notes
        : _activeBlockTargetsNotes(activeBeforeDialog);
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
            provider: ref.read(bibleProviderProvider),
            initialBookId:
                draft.primaryBibleReference?.bookId ??
                BibleBookCatalog.all.first.id,
            initialChapter: draft.primaryBibleReference?.startChapter ?? 1,
            asNote: insertAsNote,
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
    final currentDraft = _draft;
    if (currentDraft == null) return;
    final now = DateTime.now().toUtc();
    final active = _activeBlock(currentDraft.document);
    final insertAfterId =
        active?.id ?? currentDraft.document.blocks.lastOrNull?.id ?? '';
    final replacementId =
        active != null &&
            (active is ParagraphBlock ||
                active is QuoteBlock ||
                active is NoteBlock) &&
            active.plainText.trim().isEmpty
        ? active.id
        : null;
    final next = insertAsNote
        ? NoteBlock(
            id: replacementId ?? const Uuid().v4(),
            text: request.text,
            visibility: NoteVisibility.editorOnly,
            depth: active is NoteBlock ? active.depth : 0,
            isQuickNote: active is NoteBlock && active.isQuickNote,
            createdAt: replacementId == null ? now : active!.createdAt,
            updatedAt: now,
          )
        : QuoteBlock(
            id: replacementId ?? const Uuid().v4(),
            text: request.text,
            author: '',
            source: '',
            createdAt: replacementId == null ? now : active!.createdAt,
            updatedAt: now,
          );
    if (replacementId == null) {
      _insertBlockAfter(insertAfterId, next);
      return;
    }
    _updateBlock(next, startNewHistoryGroup: true);
    setState(() => _activeBlockId = next.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeBlockId != next.id) return;
      final state = _richKeys[next.id]?.currentState;
      state?.syncContent(next.plainText, _inlineMarksOf(next));
      state?.requestFocus();
    });
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(AppConfig.autosaveDelay, _save);
  }

  Future<void> _save({
    bool reconcileNavigation = true,
    bool commitPlacement = false,
  }) async {
    _saveTimer?.cancel();
    final currentDraft = _draft;
    if (currentDraft == null) return Future<void>.value();
    var draft = currentDraft;
    if (commitPlacement) {
      final pendingReferenceText = _pendingBibleReferenceTexts[draft.id]
          ?.trim();
      final currentReference = draft.primaryBibleReference;
      if (currentReference != null) {
        final referenceText =
            pendingReferenceText ??
            formatBibleReference(currentReference, includeBook: false);
        final parsedReference =
            await BiblePassageNormalizer(
              ref.read(bibleProviderProvider),
            ).normalize(
              bookId: currentReference.bookId,
              passage: referenceText,
            );
        if (parsedReference == null) {
          if (mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text(
                    'Speichern nicht möglich: Bitte prüfe die Bibelstelle '
                    '(zum Beispiel 3, 3–5 oder 2,1–12).',
                  ),
                ),
              );
          }
          return Future<void>.value();
        }
        if (parsedReference != currentReference) {
          draft = draft.copyWith(primaryBibleReference: parsedReference);
          if (mounted && _draft?.id == draft.id) {
            setState(() => _draft = draft);
          }
        }
      }
      final validationMessage = _placementValidationMessage(draft);
      if (validationMessage != null) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(validationMessage)));
        }
        return Future<void>.value();
      }
      _committedPlacement = _SermonPlacement.fromSermon(draft);
    }
    final placement = _committedPlacement ?? _SermonPlacement.fromSermon(draft);
    final toPersist = placement.applyTo(draft);
    await (_saveQueue = _saveQueue.then(
      (_) => _performSave(
        draft: draft,
        toPersist: toPersist,
        reconcileNavigation: reconcileNavigation && commitPlacement,
        commitPlacement: commitPlacement,
      ),
    ));
  }

  String? _placementValidationMessage(Sermon sermon) {
    final reference = sermon.primaryBibleReference;
    if (reference != null && !reference.hasCompleteRange) {
      return 'Speichern nicht möglich: Bitte gib die Bibelstelle mit Kapitel '
          'und Vers an (zum Beispiel 2,4–5).';
    }
    if (sermon.contentKind != ContentKind.sermon) return null;
    final seriesId = sermon.seriesId?.trim();
    if (seriesId?.isNotEmpty ?? false) {
      final series =
          ref.read(sermonSeriesProvider).valueOrNull ?? const <SermonSeries>[];
      final exists = series.any(
        (item) => item.id == seriesId || item.title == seriesId,
      );
      return exists
          ? null
          : 'Speichern nicht möglich: Bitte wähle eine vorhandene '
                'Vortragsreihe aus.';
    }
    if (sermon.primaryBibleReference == null) {
      return 'Speichern nicht möglich: Bitte wähle bei einer '
          'Auslegungspredigt zuerst ein Bibelbuch aus.';
    }
    return null;
  }

  Future<void> _performSave({
    required Sermon draft,
    required Sermon toPersist,
    required bool reconcileNavigation,
    required bool commitPlacement,
  }) async {
    if (mounted) setState(() => _saving = true);
    final repository = _repository;
    await repository.update(toPersist);
    if (mounted && _draft?.id == draft.id && _selectedId == draft.id) {
      setState(() {
        if (commitPlacement) {
          _pendingBibleReferenceTexts.remove(draft.id);
        }
        if (reconcileNavigation) {
          _navKey = _navKeyFor(toPersist);
        }
        _saving = false;
      });
    }
  }

  int _activeContentWordCount(SermonDocument document) {
    String? moduleId;
    if (_splitActive) {
      if (_activeBlockId != null && _activeBlockModuleId != null) {
        moduleId = _activeBlockModuleId;
      } else {
        moduleId = _panes.first.moduleId;
      }
    } else {
      moduleId =
          _activeBlockModuleId ?? _activeModuleId ?? _panes.first.moduleId;
    }
    final module = moduleId == null ? null : document.moduleById(moduleId);
    if (module == null) return 0;
    if (module.kind == SermonModuleKind.presentation) {
      return document.slidesForModule(module.id).fold<int>(0, (sum, slide) {
        final text = [
          slide.title,
          slide.subtitle,
          slide.body,
          slide.reference,
          ...slide.items,
          slide.caption,
        ].join(' ');
        return sum + countWords(text);
      });
    }
    return document
        .blocksForModule(module.id)
        .fold<int>(0, (sum, block) => sum + countWords(block.plainText));
  }

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
    required this.explicitSeries,
    required this.selectedNavKey,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelect,
    required this.onAddSeries,
    required this.onRenameSeries,
    required this.onCreate,
    required this.onImport,
    required this.onBackup,
    required this.booksOnboardingKey,
    required this.seriesOnboardingKey,
    required this.categoriesOnboardingKey,
    required this.darkModeOnboardingKey,
    required this.isDark,
    required this.onToggleTheme,
  });

  final List<Sermon> sermons;
  final List<SermonSeries> explicitSeries;
  final String? selectedNavKey;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelect;
  final VoidCallback onAddSeries;
  final ValueChanged<String> onRenameSeries;
  final VoidCallback onCreate;
  final VoidCallback onImport;
  final VoidCallback onBackup;
  final GlobalKey booksOnboardingKey;
  final GlobalKey seriesOnboardingKey;
  final GlobalKey categoriesOnboardingKey;
  final GlobalKey darkModeOnboardingKey;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final books = <String, int>{};
    final series = <String, int>{};
    for (final item in explicitSeries) {
      series[item.title] = 0;
    }
    for (final sermon in sermons) {
      if (sermon.seriesId?.trim().isNotEmpty ?? false) {
        series.update(
          sermon.seriesId!,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      if (sermon.primaryBibleReference != null) {
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
    final seriesNames = series.keys.toList()..sort(_compareNavigationLabels);
    int count(ContentKind kind) =>
        sermons.where((sermon) => sermon.contentKind == kind).length;
    final shortTopicCount = sermons
        .where((sermon) => sermon.contentKind == ContentKind.shortTopic)
        .length;

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 10),
            child: ColorFiltered(
              key: const Key('navigation-logo-filter'),
              colorFilter: isDark
                  ? const ColorFilter.matrix(<double>[
                      -1,
                      0,
                      0,
                      0,
                      255,
                      0,
                      -1,
                      0,
                      0,
                      255,
                      0,
                      0,
                      -1,
                      0,
                      255,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.dst,
                    ),
              child: Image.asset(
                'assets/images/sermonary-logo-compact.png',
                width: 148,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
            child: AnimatedBuilder(
              animation: Listenable.merge([
                searchFocusNode,
                searchController,
              ]),
              builder: (context, child) {
                final scheme = Theme.of(context).colorScheme;
                final focused = searchFocusNode.hasFocus;
                return AnimatedContainer(
                  height: 25,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: focused
                        ? scheme.surfaceContainer
                        : Color.alphaBlend(
                            scheme.surfaceContainer.withValues(alpha: 0.6),
                            scheme.surfaceContainerLow,
                          ),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: focused
                        ? [
                            BoxShadow(
                              color: scheme.onSurface.withValues(alpha: 0.08),
                              spreadRadius: 1,
                            ),
                          ]
                        : const [],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.search,
                        size: 10,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.28),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          key: const Key('library-search-field'),
                          controller: searchController,
                          focusNode: searchFocusNode,
                          onChanged: onSearchChanged,
                          onSubmitted: onSearchChanged,
                          cursorHeight: 13,
                          cursorWidth: 1,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontFamily: AppTypography.ui,
                                fontSize: 11.5,
                                height: 1,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurface,
                              ),
                          decoration: InputDecoration(
                            hintText: 'Suchen …',
                            hintStyle: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  fontFamily: AppTypography.ui,
                                  fontSize: 11.5,
                                  height: 1,
                                  fontWeight: FontWeight.w400,
                                  color: scheme.onSurfaceVariant.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (searchController.text.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Suche löschen',
                          child: IconButton(
                            onPressed: onClearSearch,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 14,
                              height: 14,
                            ),
                            visualDensity: VisualDensity.compact,
                            splashRadius: 8,
                            icon: Icon(
                              LucideIcons.x,
                              size: 9,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.32,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          Expanded(
            key: const Key('navigation-scroll-area'),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const bookHeaderHeight = 27.0;
                      const seriesHeaderHeight = 35.0;
                      const navigationPillHeight = 29.0;
                      const sectionDividerHeight = 21.0;
                      final naturalBooksHeight =
                          bookHeaderHeight +
                          bookIds.length * navigationPillHeight;
                      final naturalSeriesHeight =
                          seriesHeaderHeight +
                          seriesNames.length * navigationPillHeight;
                      final hasNaturalSpace =
                          naturalBooksHeight +
                              sectionDividerHeight +
                              naturalSeriesHeight <=
                          constraints.maxHeight;
                      final seriesHeight = hasNaturalSpace
                          ? naturalSeriesHeight
                          : math.min(
                              constraints.maxHeight / 3,
                              naturalSeriesHeight,
                            );

                      Widget booksRegion() => KeyedSubtree(
                        key: booksOnboardingKey,
                        child: SizedBox(
                          key: const Key('books-scroll-shell'),
                          height: hasNaturalSpace ? naturalBooksHeight : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(
                                height: bookHeaderHeight,
                                child: _NavHeader(
                                  label: 'BÜCHER',
                                  padding: EdgeInsets.fromLTRB(16, 4, 8, 4),
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  key: const Key('books-scroll-region'),
                                  primary: false,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  children: [
                                    for (final id in bookIds)
                                      _NavPill(
                                        label: BibleBookCatalog.labelFor(id),
                                        count: books[id]!,
                                        selected: selectedNavKey == 'book:$id',
                                        onTap: () => onSelect('book:$id'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );

                      return Column(
                        children: [
                          if (hasNaturalSpace)
                            booksRegion()
                          else
                            Expanded(child: booksRegion()),
                          const SizedBox(
                            key: Key('books-series-divider'),
                            height: sectionDividerHeight,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(8, 5, 8, 0),
                              child: Divider(),
                            ),
                          ),
                          KeyedSubtree(
                            key: seriesOnboardingKey,
                            child: SizedBox(
                              key: const Key('series-scroll-shell'),
                              height: seriesHeight,
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: seriesHeaderHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        3,
                                        13,
                                        3,
                                      ),
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
                                  ),
                                  Expanded(
                                    child: ListView(
                                      key: const Key('series-scroll-region'),
                                      primary: false,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      children: [
                                        for (final name in seriesNames)
                                          _NavPill(
                                            key: ValueKey('series-nav-$name'),
                                            label: name,
                                            count: series[name]!,
                                            selected:
                                                selectedNavKey ==
                                                'series:$name',
                                            onTap: () =>
                                                onSelect('series:$name'),
                                            onDoubleTap: () =>
                                                onRenameSeries(name),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasNaturalSpace) const Spacer(),
                        ],
                      );
                    },
                  ),
                ),
                KeyedSubtree(
                  key: categoriesOnboardingKey,
                  child: Column(
                    key: const Key('fixed-navigation-categories'),
                    children: [
                      const SizedBox(
                        key: Key('series-categories-divider'),
                        height: 21,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(8, 5, 8, 0),
                          child: Divider(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                        child: Column(
                          children: [
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 66,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 3),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 28,
                  child: TextButton(
                    key: const Key('quick-new-sermon'),
                    onPressed: onCreate,
                    style: _navigationFooterButtonStyle(
                      context,
                      emphasized: true,
                    ),
                    child: const Text('Neue Predigt'),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: onImport,
                        style: _navigationFooterButtonStyle(context),
                        child: const Text('Import'),
                      ),
                      const Spacer(),
                      _TinyIconButton(
                        icon: LucideIcons.databaseBackup,
                        tooltip: 'Datensicherung',
                        onPressed: onBackup,
                        size: 11,
                      ),
                      KeyedSubtree(
                        key: darkModeOnboardingKey,
                        child: _TinyIconButton(
                          icon: isDark ? LucideIcons.sun : LucideIcons.moon,
                          tooltip: isDark ? 'Helle Ansicht' : 'Dunkle Ansicht',
                          onPressed: onToggleTheme,
                          size: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ButtonStyle _navigationFooterButtonStyle(
    BuildContext context, {
    bool emphasized = false,
  }) => TextButton.styleFrom(
    minimumSize: const Size(0, 28),
    padding: const EdgeInsets.symmetric(horizontal: 2),
    foregroundColor: Theme.of(context).colorScheme.onSurface.withValues(
      alpha: emphasized ? 0.58 : 0.34,
    ),
    textStyle: TextStyle(
      fontSize: emphasized ? 10.5 : 10,
      fontWeight: emphasized ? FontWeight.w500 : FontWeight.w400,
      letterSpacing: 0.2,
    ),
  );
}

class _EntryColumn extends StatelessWidget {
  const _EntryColumn({
    required this.label,
    required this.sermons,
    required this.allSermons,
    required this.selectedId,
    required this.showSeriesSubtitle,
    required this.canDeleteSeries,
    required this.onRenameSeries,
    required this.onDeleteSeries,
    required this.onCreate,
    required this.onSelect,
    required this.activeModuleIds,
    required this.onSelectModule,
    required this.onAddModule,
    required this.onDuplicateModule,
    required this.onDeleteModule,
    required this.onRenameModule,
    required this.onLinkModules,
    required this.onMoveModule,
    required this.onUnlinkModule,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAttachVersion,
    required this.onDetachVersion,
    required this.emptyActionLabel,
  });

  final String label;
  final List<Sermon> sermons;
  final List<Sermon> allSermons;
  final String? selectedId;
  final bool showSeriesSubtitle;
  final bool canDeleteSeries;
  final VoidCallback? onRenameSeries;
  final VoidCallback onDeleteSeries;
  final VoidCallback onCreate;
  final ValueChanged<String> onSelect;
  final Set<String> activeModuleIds;
  final ValueChanged<String> onSelectModule;
  final ValueChanged<SermonModuleKind> onAddModule;
  final ValueChanged<String> onDuplicateModule;
  final ValueChanged<String> onDeleteModule;
  final void Function(String moduleId, String title) onRenameModule;
  final void Function(String sourceModuleId, String targetModuleId)
  onLinkModules;
  final void Function(String moduleId, int targetIndex) onMoveModule;
  final ValueChanged<String> onUnlinkModule;
  final ValueChanged<String> onDuplicate;
  final ValueChanged<String> onDelete;
  final void Function(String draggedId, String targetId) onAttachVersion;
  final ValueChanged<String> onDetachVersion;
  final String emptyActionLabel;

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
                child: Tooltip(
                  message: onRenameSeries == null
                      ? label
                      : 'Vortragsreihe umbenennen',
                  child: InkWell(
                    key: onRenameSeries == null
                        ? null
                        : ValueKey('entry-series-title-$label'),
                    onTap: onRenameSeries,
                    borderRadius: BorderRadius.circular(3),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.58),
                            ),
                      ),
                    ),
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
          child: DragTarget<String>(
            key: const Key('entry-version-detach-zone'),
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) => onDetachVersion(details.data),
            builder: (context, candidateData, rejectedData) => ColoredBox(
              color: candidateData.isEmpty
                  ? Colors.transparent
                  : Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withValues(alpha: 0.22),
              child: sermons.isEmpty
                  ? Center(
                      child: TextButton(
                        onPressed: onCreate,
                        child: Text(emptyActionLabel),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                      itemCount: sermons.length,
                      itemBuilder: (context, index) {
                        final sermon = sermons[index];
                        final selected = sermon.id == selectedId;
                        final rootId = sermon.versionRootId ?? sermon.id;
                        final versions =
                            allSermons
                                .where(
                                  (item) =>
                                      item.id == rootId ||
                                      item.versionRootId == rootId,
                                )
                                .toList(growable: false)
                              ..sort(
                                (a, b) {
                                  if (a.id == rootId) return -1;
                                  if (b.id == rootId) return 1;
                                  final created = a.createdAt.compareTo(
                                    b.createdAt,
                                  );
                                  return created != 0
                                      ? created
                                      : a.id.compareTo(b.id);
                                },
                              );
                        final versionIndex = sermon.versionRootId == null
                            ? null
                            : versions.indexWhere(
                                    (item) => item.id == sermon.id,
                                  ) +
                                  1;
                        return _EntryPill(
                          sermon: sermon,
                          selected: selected,
                          showSeriesSubtitle: showSeriesSubtitle,
                          versionCount: versions.length,
                          versionIndex: versionIndex,
                          onTap: () => onSelect(sermon.id),
                          activeModuleIds: selected
                              ? activeModuleIds
                              : const <String>{},
                          onSelectModule: onSelectModule,
                          onAddModule: onAddModule,
                          onDuplicateModule: onDuplicateModule,
                          onDeleteModule: onDeleteModule,
                          onRenameModule: onRenameModule,
                          onLinkModules: onLinkModules,
                          onMoveModule: onMoveModule,
                          onUnlinkModule: onUnlinkModule,
                          onDuplicate: () => onDuplicate(sermon.id),
                          onDelete: () => onDelete(sermon.id),
                          onAttachVersion: (draggedId) =>
                              onAttachVersion(draggedId, sermon.id),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SearchResultColumn extends StatelessWidget {
  const _SearchResultColumn({
    required this.query,
    required this.results,
    required this.selectedId,
    required this.onSelect,
  });

  final String query;
  final List<_SermonSearchResult> results;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(
      context,
    ).colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  query,
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
              Text(
                '${results.length}',
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
        const Divider(indent: 12, endIndent: 12),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Keine Treffer',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 11.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.34),
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  key: const Key('search-results-list'),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    final selected = result.sermon.id == selectedId;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: InkWell(
                        key: Key('search-result-${result.sermon.id}'),
                        onTap: () => onSelect(result.sermon.id),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      result.contextLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.35,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withValues(alpha: 0.36),
                                          ),
                                    ),
                                  ),
                                  Text(
                                    result.sourceLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.65,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.25),
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                result.sermon.title.isEmpty
                                    ? 'Ohne Titel'
                                    : result.sermon.title,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      fontSize: 12.5,
                                      height: 1.25,
                                      fontWeight: selected
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(
                                            alpha: selected ? 1 : 0.68,
                                          ),
                                    ),
                              ),
                              if (result.snippet.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  result.snippet,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        fontFamily: AppTypography.editor,
                                        fontSize: 10.5,
                                        height: 1.35,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.42),
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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
    required this.activeFormats,
    required this.onToggleFocus,
    required this.onToggleSplit,
    required this.splitOnboardingKey,
    required this.onChangeBlockType,
    required this.onFormat,
    required this.onClearHighlights,
    required this.onInsertBibleReference,
    required this.onLive,
    required this.onExport,
    required this.onDuplicate,
    required this.onDelete,
    required this.liveOnboardingKey,
    required this.exportOnboardingKey,
  });

  final WorkspaceView view;
  final bool splitActive;
  final bool focusMode;
  final bool saving;
  final int wordCount;
  final String durationLabel;
  final DocumentBlock? activeBlock;
  final Set<_InlineFormat> activeFormats;
  final VoidCallback onToggleFocus;
  final VoidCallback onToggleSplit;
  final GlobalKey splitOnboardingKey;
  final ValueChanged<String> onChangeBlockType;
  final ValueChanged<_InlineFormat> onFormat;
  final VoidCallback onClearHighlights;
  final VoidCallback onInsertBibleReference;
  final VoidCallback onLive;
  final ValueChanged<_SermonExportAction> onExport;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final GlobalKey liveOnboardingKey;
  final GlobalKey exportOnboardingKey;

  @override
  Widget build(BuildContext context) {
    final rich =
        activeBlock is ParagraphBlock ||
        activeBlock is QuoteBlock ||
        activeBlock is NoteBlock;
    final mayHighlight =
        activeBlock is ParagraphBlock ||
        activeBlock is QuoteBlock ||
        activeBlock is NoteBlock;
    final activeTargetsNotes =
        activeBlock is NoteBlock ||
        (activeBlock is HeadingBlock && view == WorkspaceView.notes);
    final blockTypeOptions = <String>[
      'h1',
      'h2',
      'h3',
      if (activeTargetsNotes) ...['li', 'li2'] else ...['p', 'quote'],
    ];
    String blockTypeLabel(String type) => switch (type) {
      'h1' => 'Überschrift 1',
      'h2' => 'Überschrift 2',
      'h3' => 'Überschrift 3',
      'li' => 'Stichpunkt',
      'li2' => 'Unterpunkt',
      'quote' => 'Zitat',
      _ => 'Absatz',
    };
    final navigationWidth = focusMode
        ? 0
        : AppSizes.sidebarWidth + AppSizes.entryListWidth + 2;
    final showMetrics =
        MediaQuery.sizeOf(context).width - navigationWidth >= 900;
    return Container(
      key: const Key('workspace-toolbar'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox.shrink(
            key: ValueKey('toolbar-word-count-value-$wordCount'),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TinyIconButton(
                    icon: focusMode
                        ? LucideIcons.minimize2
                        : LucideIcons.maximize2,
                    tooltip: focusMode ? 'Navigation zeigen' : 'Fokusmodus',
                    onPressed: onToggleFocus,
                  ),
                  KeyedSubtree(
                    key: splitOnboardingKey,
                    child: _TinyIconButton(
                      key: const Key('toggle-workspace-split'),
                      icon: LucideIcons.columns2,
                      tooltip: splitActive
                          ? 'Splitscreen schließen'
                          : 'Splitscreen öffnen',
                      selected: splitActive,
                      onPressed: onToggleSplit,
                    ),
                  ),
                  if (activeBlock != null && view != WorkspaceView.outline) ...[
                    const SizedBox(width: 8),
                    TypeaheadMenuRegion<String>(
                      options: blockTypeOptions,
                      labelFor: blockTypeLabel,
                      onSelected: onChangeBlockType,
                      builder: (context, typeahead) => PopupMenuButton<String>(
                        tooltip: 'Blocktyp',
                        onOpened: typeahead.open,
                        onCanceled: typeahead.close,
                        onSelected: (value) {
                          typeahead.close();
                          onChangeBlockType(value);
                        },
                        itemBuilder: (context) => [
                          for (final type in blockTypeOptions)
                            PopupMenuItem(
                              value: type,
                              child: Text(blockTypeLabel(type)),
                            ),
                        ],
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
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.55),
                                    ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.chevronDown, size: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (rich) ...[
                    const SizedBox(width: 3),
                    _FormatButton(
                      key: const Key('format-bold'),
                      label: 'B',
                      tooltip: 'Fett',
                      selected: activeFormats.contains(_InlineFormat.bold),
                      onPressed: () => onFormat(_InlineFormat.bold),
                    ),
                    _FormatButton(
                      key: const Key('format-italic'),
                      label: 'I',
                      tooltip: 'Kursiv',
                      italic: true,
                      selected: activeFormats.contains(_InlineFormat.italic),
                      onPressed: () => onFormat(_InlineFormat.italic),
                    ),
                    if (mayHighlight) ...[
                      _TinyIconButton(
                        key: const Key('format-highlight'),
                        icon: LucideIcons.highlighter,
                        tooltip: 'Markieren',
                        onPressed: () => onFormat(_InlineFormat.highlight),
                        size: 11,
                        selected: activeFormats.contains(
                          _InlineFormat.highlight,
                        ),
                      ),
                      _TinyIconButton(
                        icon: LucideIcons.eraser,
                        tooltip: 'Markierungen entfernen',
                        onPressed: onClearHighlights,
                        size: 11,
                      ),
                    ],
                  ],
                  if (rich) ...[
                    const SizedBox(width: 4),
                    _TinyIconButton(
                      key: const Key('bible-toolbar-action'),
                      icon: LucideIcons.bookOpen,
                      tooltip: 'Bibelstelle einfügen',
                      onPressed: onInsertBibleReference,
                      size: 12,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ViewButton(
                  key: liveOnboardingKey,
                  icon: LucideIcons.radio,
                  tooltip: 'Live-Ansicht',
                  selected: false,
                  onPressed: onLive,
                ),
                KeyedSubtree(
                  key: exportOnboardingKey,
                  child: TypeaheadMenuRegion<_SermonExportAction>(
                    options: _SermonExportAction.values,
                    labelFor: (value) => value.searchableLabel,
                    onSelected: onExport,
                    builder: (context, typeahead) =>
                        PopupMenuButton<_SermonExportAction>(
                          key: const Key('export-menu'),
                          tooltip: 'Exportieren und drucken',
                          onOpened: typeahead.open,
                          onCanceled: typeahead.close,
                          onSelected: (value) {
                            typeahead.close();
                            onExport(value);
                          },
                          position: PopupMenuPosition.under,
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              enabled: false,
                              height: 30,
                              child: _ExportMenuSectionLabel('Notizen'),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.notesPdf,
                              child: _ExportMenuItem(
                                icon: LucideIcons.fileText,
                                label: 'PDF',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.notesWord,
                              child: _ExportMenuItem(
                                icon: LucideIcons.fileType2,
                                label: 'Word',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.notesPrint,
                              child: _ExportMenuItem(
                                icon: LucideIcons.printer,
                                label: 'Print',
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              enabled: false,
                              height: 30,
                              child: _ExportMenuSectionLabel('Script'),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.scriptPdf,
                              child: _ExportMenuItem(
                                icon: LucideIcons.fileText,
                                label: 'PDF',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.scriptWord,
                              child: _ExportMenuItem(
                                icon: LucideIcons.fileType2,
                                label: 'Word',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.scriptPrint,
                              child: _ExportMenuItem(
                                icon: LucideIcons.printer,
                                label: 'Print',
                              ),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              enabled: false,
                              height: 30,
                              child: _ExportMenuSectionLabel('Präsentation'),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.presentationPdf,
                              child: _ExportMenuItem(
                                icon: LucideIcons.fileText,
                                label: 'PDF',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction.presentationPowerPoint,
                              child: _ExportMenuItem(
                                icon: LucideIcons.presentation,
                                label: 'PowerPoint · bearbeitbar',
                              ),
                            ),
                            PopupMenuItem(
                              value: _SermonExportAction
                                  .presentationPowerPointImages,
                              child: _ExportMenuItem(
                                icon: LucideIcons.images,
                                label: 'PowerPoint · pixelgetreu',
                              ),
                            ),
                          ],
                          icon: Icon(
                            LucideIcons.printer,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          padding: EdgeInsets.zero,
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(28),
                            maximumSize: const Size.square(28),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                  ),
                ),
                if (showMetrics) ...[
                  const SizedBox(width: 14),
                  if (wordCount > 0) ...[
                    Text(
                      '$wordCount Wörter · $durationLabel',
                      key: const Key('toolbar-word-count'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 11.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
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
                const SizedBox(width: 6),
                _TinyIconButton(
                  icon: LucideIcons.copyPlus,
                  tooltip: 'Duplizieren',
                  onPressed: onDuplicate,
                  size: 12,
                ),
                _TinyIconButton(
                  icon: LucideIcons.trash2,
                  tooltip: 'Predigt löschen',
                  onPressed: onDelete,
                  size: 12,
                  destructive: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _blockLabel(DocumentBlock block) => switch (block) {
    HeadingBlock(level: 1) => 'Überschrift 1',
    HeadingBlock(level: 2) => 'Überschrift 2',
    HeadingBlock() => 'Überschrift 3',
    ParagraphBlock() => 'Absatz',
    QuoteBlock() => 'Zitat',
    NoteBlock(depth: 1) => 'Unterpunkt',
    NoteBlock() => 'Stichpunkt',
    _ => 'Block',
  };
}

class _OutlineView extends ConsumerWidget {
  const _OutlineView({
    required this.sermon,
    required this.onboardingKey,
    required this.onChanged,
    required this.onShowAddModuleDialog,
    required this.onShowAddLinkedModuleDialog,
    required this.onBibleReferenceTextChanged,
    required this.onSave,
    required this.backgroundImageId,
    required this.backgroundPickerOpen,
    required this.onToggleBackgroundPicker,
    required this.onSelectBackground,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
  });

  final Sermon sermon;
  final GlobalKey onboardingKey;
  final ValueChanged<Sermon> onChanged;
  final VoidCallback onShowAddModuleDialog;
  final VoidCallback onShowAddLinkedModuleDialog;
  final ValueChanged<String> onBibleReferenceTextChanged;
  final VoidCallback onSave;
  final String backgroundImageId;
  final bool backgroundPickerOpen;
  final VoidCallback onToggleBackgroundPicker;
  final ValueChanged<String> onSelectBackground;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;

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
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final series =
        ref.watch(sermonSeriesProvider).valueOrNull ?? const <SermonSeries>[];
    final quickNotes = sermon.document.blocks
        .whereType<NoteBlock>()
        .where((note) => note.isQuickNote)
        .toList(growable: false);
    final minimumHeight = math
        .max(
          760,
          MediaQuery.sizeOf(context).height - 48,
        )
        .toDouble();
    const workflowClearance = 84.0;
    final usableHeight = math.max(0, minimumHeight - workflowClearance);
    const actionSpace = 124.0;
    final maximumCardHeight = math
        .max(300, usableHeight - 64 - actionSpace)
        .toDouble();
    final compactLayout = maximumCardHeight < 480;
    int estimatedLines(String value, int charactersPerLine) =>
        math.max(1, (value.characters.length / charactersPerLine).ceil());
    final metadataGrowth =
        (estimatedLines(sermon.title, 24) - 1) * 32.0 +
        (estimatedLines(sermon.location ?? '', 34) - 1) * 19.0;
    final summaryGrowth =
        math.max(0, estimatedLines(sermon.subtitle, 42) - 3) * 27.0;
    final quickNotesGrowth = quickNotes.fold<double>(0, (height, note) {
      return height +
          38 +
          math.max(0, estimatedLines(note.text, 42) - 1) * 24.0;
    });
    final minimumCardHeight = math.min(520, maximumCardHeight).toDouble();
    final desiredCardHeight =
        560.0 + metadataGrowth + summaryGrowth + quickNotesGrowth;
    final cardHeight = math.min(
      maximumCardHeight,
      math.max(minimumCardHeight, desiredCardHeight),
    );
    return KeyedSubtree(
      key: onboardingKey,
      child: Container(
        key: const Key('outline-notebook-background'),
        width: double.infinity,
        height: minimumHeight,
        padding: EdgeInsets.zero,
        decoration: _outlineBackgroundDecoration(
          backgroundImageId,
          dark: dark,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              bottom: workflowClearance,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        key: const Key('outline-notebook-card'),
                        width: 460,
                        height: cardHeight,
                        padding: EdgeInsets.fromLTRB(
                          48,
                          compactLayout ? 14 : 32,
                          48,
                          compactLayout ? 14 : 32,
                        ),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF11110F) : Colors.white,
                          border: Border.all(
                            color: dark
                                ? scheme.onSurface.withValues(alpha: 0.1)
                                : const Color(
                                    0xFFC8C4BA,
                                  ).withValues(alpha: 0.6),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A000000),
                              offset: Offset(0, 2),
                              blurRadius: 8,
                            ),
                            BoxShadow(
                              color: Color(0x29000000),
                              offset: Offset(0, 16),
                              blurRadius: 48,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                _GroupChip(
                                  label: 'Vortragsreihe',
                                  selected: group == _WorkspaceGroup.series,
                                  onTap: () =>
                                      _changeGroup(_WorkspaceGroup.series),
                                ),
                                _GroupChip(
                                  label: 'Auslegungspredigt',
                                  selected: group == _WorkspaceGroup.book,
                                  onTap: () =>
                                      _changeGroup(_WorkspaceGroup.book),
                                ),
                                _GroupChip(
                                  label: 'Vortrag',
                                  selected: group == _WorkspaceGroup.talk,
                                  onTap: () =>
                                      _changeGroup(_WorkspaceGroup.talk),
                                ),
                                _GroupChip(
                                  label: 'Kurzthema',
                                  selected: group == _WorkspaceGroup.shortTopic,
                                  onTap: () =>
                                      _changeGroup(_WorkspaceGroup.shortTopic),
                                ),
                                _GroupChip(
                                  label: 'Einleitung',
                                  selected:
                                      group == _WorkspaceGroup.introduction,
                                  onTap: () => _changeGroup(
                                    _WorkspaceGroup.introduction,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: compactLayout ? 4 : 20,
                            ),
                            if (group == _WorkspaceGroup.book)
                              _OutlineBibleReferenceFields(
                                sermon: sermon,
                                allowMultiple: false,
                                onChanged: onChanged,
                                onReferenceTextChanged:
                                    onBibleReferenceTextChanged,
                              ),
                            if (group == _WorkspaceGroup.talk)
                              _OutlineBibleReferenceFields(
                                sermon: sermon,
                                allowMultiple: true,
                                onChanged: onChanged,
                                onReferenceTextChanged:
                                    onBibleReferenceTextChanged,
                              ),
                            if (group == _WorkspaceGroup.series)
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: _OutlineSeriesDropdown(
                                          current: sermon.seriesId,
                                          series: series,
                                          onChanged: (value) => onChanged(
                                            sermon.copyWith(seriesId: value),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 42,
                                        child: _BareTextField(
                                          key: ValueKey(
                                            'series-position-${sermon.id}',
                                          ),
                                          initialValue:
                                              sermon.seriesPosition
                                                  ?.toString() ??
                                              '',
                                          hintText: 'Nr.',
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          textAlign: TextAlign.center,
                                          style: _outlineContextStyle(context),
                                          onChanged: (value) {
                                            final trimmed = value.trim();
                                            if (trimmed.isEmpty) {
                                              onChanged(
                                                sermon.copyWith(
                                                  clearSeriesPosition: true,
                                                ),
                                              );
                                              return;
                                            }
                                            final position = int.tryParse(
                                              trimmed,
                                            );
                                            if (position != null &&
                                                position > 0) {
                                              onChanged(
                                                sermon.copyWith(
                                                  seriesPosition: position,
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _OutlineBibleReferenceFields(
                                    sermon: sermon,
                                    allowMultiple: true,
                                    onChanged: onChanged,
                                    onReferenceTextChanged:
                                        onBibleReferenceTextChanged,
                                  ),
                                ],
                              ),
                            SizedBox(height: compactLayout ? 4 : 20),
                            const _OutlineHairline(),
                            SizedBox(height: compactLayout ? 4 : 28),
                            _BareTextField(
                              key: ValueKey('title-${sermon.id}'),
                              initialValue: sermon.title,
                              hintText: 'Titel der Predigt',
                              maxLines: null,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.94),
                                fontFamily: AppTypography.ui,
                                fontSize: 26.4,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                letterSpacing: -0.528,
                              ),
                              onChanged: (value) =>
                                  onChanged(sermon.copyWith(title: value)),
                            ),
                            SizedBox(height: compactLayout ? 4 : 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                SizedBox(
                                  width: 104,
                                  child: _BareTextField(
                                    key: ValueKey('date-${sermon.id}'),
                                    initialValue: sermon.scheduledAt == null
                                        ? ''
                                        : _formatDate(sermon.scheduledAt!),
                                    hintText: 'Datum',
                                    textAlign: TextAlign.center,
                                    style: _outlineAnnotationStyle(context),
                                    onChanged: (value) {
                                      final date = _parseDate(value);
                                      if (date != null) {
                                        onChanged(
                                          sermon.copyWith(scheduledAt: date),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '·',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant.withValues(
                                      alpha: 0.38,
                                    ),
                                    fontFamily: AppTypography.ui,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _BareTextField(
                                    key: ValueKey('location-${sermon.id}'),
                                    initialValue: sermon.location ?? '',
                                    hintText: 'Ort',
                                    maxLines: null,
                                    textAlign: TextAlign.center,
                                    style: _outlineAnnotationStyle(context),
                                    onChanged: (value) => onChanged(
                                      sermon.copyWith(location: value),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compactLayout ? 4 : 24),
                            const _OutlineHairline(),
                            Flexible(
                              child: _OutlineDetailsSection(
                                sermon: sermon,
                                quickNotes: quickNotes,
                                compactLayout: compactLayout,
                                activeBlockId: activeBlockId,
                                richKeys: richKeys,
                                onChanged: onChanged,
                                onActivate: onActivate,
                                onUpdateBlock: onUpdateBlock,
                                onInsertAfter: onInsertAfter,
                                onDelete: onDelete,
                                onNavigate: onNavigate,
                                onPaste: onPaste,
                              ),
                            ),
                            SizedBox(height: compactLayout ? 4 : 20),
                            TextButton(
                              onPressed: onSave,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                foregroundColor: scheme.onSurfaceVariant
                                    .withValues(
                                      alpha: 0.56,
                                    ),
                                textStyle: const TextStyle(
                                  fontFamily: AppTypography.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                              child: const Text('SPEICHERN'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ProminentWorkspaceActionSurface(
                        child: SizedBox(
                          key: const Key('outline-add-content'),
                          height: 36,
                          child: TextButton(
                            onPressed: onShowAddModuleDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Inhalt hinzufügen',
                              style: _prominentWorkspaceActionTextStyle(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      _ProminentWorkspaceActionSurface(
                        child: SizedBox(
                          key: const Key('outline-add-linked-content'),
                          height: 36,
                          child: TextButton(
                            onPressed: sermon.document.effectiveModules.isEmpty
                                ? null
                                : onShowAddLinkedModuleDialog,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Verknüpften Inhalt hinzufügen',
                              style: _prominentWorkspaceActionTextStyle(
                                context,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              bottom: workflowClearance + 24,
              child: _OutlineBackgroundControl(
                selected: backgroundImageId,
                open: backgroundPickerOpen,
                onToggle: onToggleBackgroundPicker,
                onSelect: onSelectBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changeGroup(_WorkspaceGroup next) {
    switch (next) {
      case _WorkspaceGroup.book:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.sermon,
            seriesId: '',
          ),
        );
      case _WorkspaceGroup.series:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.sermon,
            seriesId: sermon.seriesId?.isNotEmpty == true
                ? sermon.seriesId
                : _unselectedSeriesId,
          ),
        );
      case _WorkspaceGroup.talk:
        onChanged(
          sermon.copyWith(
            contentKind: ContentKind.talk,
            seriesId: '',
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

class _OutlineDetailsSection extends StatefulWidget {
  const _OutlineDetailsSection({
    required this.sermon,
    required this.quickNotes,
    required this.compactLayout,
    required this.activeBlockId,
    required this.richKeys,
    required this.onChanged,
    required this.onActivate,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
  });

  final Sermon sermon;
  final List<NoteBlock> quickNotes;
  final bool compactLayout;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<Sermon> onChanged;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;

  @override
  State<_OutlineDetailsSection> createState() => _OutlineDetailsSectionState();
}

class _OutlineDetailsSectionState extends State<_OutlineDetailsSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      thickness: 3,
      radius: const Radius.circular(2),
      child: SingleChildScrollView(
        key: const Key('outline-details-scroll'),
        controller: _scrollController,
        padding: EdgeInsets.only(
          top: widget.compactLayout ? 0 : 28,
          right: 14,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BareTextField(
              key: ValueKey('summary-${widget.sermon.id}'),
              initialValue: widget.sermon.subtitle,
              hintText: 'Worum geht es in dieser Predigt?',
              maxLines: null,
              minLines: 3,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.74),
                fontFamily: AppTypography.editor,
                fontSize: 14.4,
                fontWeight: FontWeight.w400,
                height: 1.85,
                letterSpacing: 0.072,
              ),
              onChanged: (value) => widget.onChanged(
                widget.sermon.copyWith(subtitle: value),
              ),
            ),
            const SizedBox(height: 24),
            const _OutlineHairline(),
            const SizedBox(height: 24),
            for (var index = 0; index < widget.quickNotes.length; index++)
              _DocumentBlockField(
                block: widget.quickNotes[index],
                previous: index == 0 ? null : widget.quickNotes[index - 1],
                active: widget.activeBlockId == widget.quickNotes[index].id,
                dimmed:
                    widget.activeBlockId != null &&
                    widget.activeBlockId != widget.quickNotes[index].id,
                richKey: widget.richKeys.putIfAbsent(
                  widget.quickNotes[index].id,
                  GlobalKey.new,
                ),
                onActivate: widget.onActivate,
                onChanged: widget.onUpdateBlock,
                onInsertAfter: widget.onInsertAfter,
                onDelete: widget.onDelete,
                onNavigate: widget.onNavigate,
                onPaste: widget.onPaste,
                noteMode: true,
                allowNoteIndent: false,
              ),
            Padding(
              padding: EdgeInsets.only(
                top: widget.quickNotes.isEmpty ? 0 : 10,
              ),
              child: _GhostAdd(
                label: 'Quicknote einfügen',
                bullet: '—',
                onTap: () {
                  final now = DateTime.now().toUtc();
                  widget.onInsertAfter(
                    widget.quickNotes.lastOrNull?.id ??
                        widget.sermon.document.blocks.lastOrNull?.id ??
                        '',
                    NoteBlock(
                      id: const Uuid().v4(),
                      text: '',
                      visibility: NoteVisibility.editorOnly,
                      isQuickNote: true,
                      createdAt: now,
                      updatedAt: now,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _outlineBackgroundAsset(
  String backgroundImageId, {
  required bool dark,
}) {
  if (backgroundImageId.startsWith('book:')) {
    final bookId = backgroundImageId.substring('book:'.length);
    if (dark) return BibleBookBackgroundCatalog.darkAssetFor(bookId);
    return BibleBookBackgroundCatalog.lightAssetFor(bookId) ??
        'assets/images/background/generic1.jpg';
  }
  return dark
      ? 'assets/images/background_dark/$backgroundImageId-dark.jpg'
      : 'assets/images/background/$backgroundImageId.jpg';
}

ImageProvider<Object> _outlineBackgroundProvider(
  String backgroundImageId, {
  required bool thumbnail,
  required bool dark,
}) => ResizeImage.resizeIfNeeded(
  thumbnail ? 160 : 1600,
  null,
  AssetImage(_outlineBackgroundAsset(backgroundImageId, dark: dark)),
);

BoxDecoration _outlineBackgroundDecoration(
  String backgroundImageId, {
  required bool dark,
}) => BoxDecoration(
  image: DecorationImage(
    image: _outlineBackgroundProvider(
      backgroundImageId,
      thumbnail: false,
      dark: dark,
    ),
    fit: BoxFit.cover,
  ),
);

class _OutlineBackgroundControl extends StatelessWidget {
  const _OutlineBackgroundControl({
    required this.selected,
    required this.open,
    required this.onToggle,
    required this.onSelect,
  });

  final String selected;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (open) ...[
        Container(
          key: const Key('outline-background-picker'),
          width: 184,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E000000),
                offset: Offset(0, 4),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  'HINTERGRUND',
                  style: TextStyle(
                    color: Color(0xFFA8A29E),
                    fontFamily: AppTypography.ui,
                    fontSize: 9,
                    height: 1.5,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final backgroundImageId in _outlineBackgroundIds)
                    _OutlineBackgroundTile(
                      backgroundImageId: backgroundImageId,
                      selected: selected == backgroundImageId,
                      onTap: onSelect,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      Tooltip(
        message: 'Hintergrund wechseln',
        child: Material(
          color: Colors.black.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('outline-background-button'),
            onTap: onToggle,
            child: const SizedBox.square(
              dimension: 28,
              child: Icon(
                LucideIcons.image,
                size: 12,
                color: Color(0x8CFFFFFF),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _OutlineBackgroundTile extends StatelessWidget {
  const _OutlineBackgroundTile({
    required this.backgroundImageId,
    required this.selected,
    required this.onTap,
  });

  final String backgroundImageId;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('outline-background-$backgroundImageId'),
    onTap: () => onTap(backgroundImageId),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 76,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? const Color(0xFF44403C) : Colors.transparent,
          width: 2,
        ),
        image: DecorationImage(
          image: _outlineBackgroundProvider(
            backgroundImageId,
            thumbnail: true,
            dark: Theme.of(context).brightness == Brightness.dark,
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Color(0x33000000), blurRadius: 3),
                  ],
                ),
              ),
            )
          : null,
    ),
  );
}

class _SermonOverviewEditor extends StatelessWidget {
  const _SermonOverviewEditor({
    required this.keyPrefix,
    required this.sermon,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateSermon,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
  });

  final String keyPrefix;
  final Sermon sermon;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<Sermon> onUpdateSermon;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final quickNotes = sermon.document.blocks
        .whereType<NoteBlock>()
        .where((note) => note.isQuickNote)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BareTextField(
          key: ValueKey('$keyPrefix-summary-${sermon.id}'),
          initialValue: sermon.subtitle,
          hintText: 'Worum geht es in dieser Predigt?',
          maxLines: null,
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.58),
            fontFamily: AppTypography.editor,
            fontSize: 14.4,
            fontWeight: FontWeight.w400,
            height: 1.75,
          ),
          onChanged: (value) =>
              onUpdateSermon(sermon.copyWith(subtitle: value)),
        ),
        const SizedBox(height: 18),
        for (var index = 0; index < quickNotes.length; index++)
          _DocumentBlockField(
            block: quickNotes[index],
            previous: index == 0 ? null : quickNotes[index - 1],
            active: activeBlockId == quickNotes[index].id,
            dimmed:
                activeBlockId != null && activeBlockId != quickNotes[index].id,
            richKey: richKeys.putIfAbsent(
              quickNotes[index].id,
              GlobalKey.new,
            ),
            onActivate: onActivate,
            onChanged: onUpdateBlock,
            onInsertAfter: onInsertAfter,
            onDelete: onDelete,
            onNavigate: onNavigate,
            onPaste: onPaste,
            noteMode: true,
            allowNoteIndent: false,
          ),
        Padding(
          padding: EdgeInsets.only(top: quickNotes.isEmpty ? 0 : 10),
          child: _GhostAdd(
            label: 'Quicknote einfügen',
            bullet: '—',
            onTap: () {
              final now = DateTime.now().toUtc();
              onInsertAfter(
                quickNotes.lastOrNull?.id ??
                    sermon.document.blocks.lastOrNull?.id ??
                    '',
                NoteBlock(
                  id: const Uuid().v4(),
                  text: '',
                  visibility: NoteVisibility.editorOnly,
                  isQuickNote: true,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ScriptView extends StatelessWidget {
  const _ScriptView({
    required this.sermon,
    required this.activeBlockId,
    required this.focusedBlockIds,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateSermon,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
    this.focusKeyPrefix,
    this.slides = const [],
    this.onAnchorSlide,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Set<String>? focusedBlockIds;
  final String? focusKeyPrefix;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<Sermon> onUpdateSermon;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;
  final List<PresentationSlide> slides;
  final _AnchorSlideCallback? onAnchorSlide;

  @override
  Widget build(BuildContext context) {
    final blocks = sermon.document.blocks
        .where((block) => block is! NoteBlock)
        .toList(growable: false);
    final counterpartSlides = slides
        .where((slide) {
          final anchor = slide.anchor;
          if (anchor == null || anchor.view != PresentationAnchorView.notes) {
            return false;
          }
          return sermon.document.blocks
                  .where((block) => block.id == anchor.blockId)
                  .firstOrNull
              is! HeadingBlock;
        })
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
              const SizedBox(height: 28),
              _SermonOverviewEditor(
                keyPrefix: 'script',
                sermon: sermon,
                activeBlockId: activeBlockId,
                richKeys: richKeys,
                onActivate: onActivate,
                onUpdateSermon: onUpdateSermon,
                onUpdateBlock: onUpdateBlock,
                onInsertAfter: onInsertAfter,
                onDelete: onDelete,
                onNavigate: onNavigate,
                onPaste: onPaste,
              ),
              const SizedBox(height: 38),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 38),
              if (counterpartSlides.isNotEmpty) ...[
                _CounterpartSlideMarker(
                  slides: counterpartSlides,
                  slideNumbers: [
                    for (final slide in counterpartSlides)
                      slides.indexOf(slide) + 1,
                  ],
                ),
                const SizedBox(height: 22),
              ],
              for (var index = 0; index < blocks.length; index++)
                _DocumentBlockField(
                  block: blocks[index],
                  previous: index == 0 ? null : blocks[index - 1],
                  active: activeBlockId == blocks[index].id,
                  dimmed:
                      focusedBlockIds != null &&
                      !focusedBlockIds!.contains(blocks[index].id),
                  richKey: richKeys.putIfAbsent(
                    blocks[index].id,
                    GlobalKey.new,
                  ),
                  onActivate: onActivate,
                  onChanged: onUpdateBlock,
                  onInsertAfter: onInsertAfter,
                  onDelete: onDelete,
                  onNavigate: onNavigate,
                  onPaste: onPaste,
                  noteMode: false,
                  slides: slides,
                  onAnchorSlide: onAnchorSlide,
                  focusKeyPrefix: focusKeyPrefix,
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
    required this.focusedBlockIds,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateSermon,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
    this.focusKeyPrefix,
    this.slides = const [],
    this.onAnchorSlide,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Set<String>? focusedBlockIds;
  final String? focusKeyPrefix;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<Sermon> onUpdateSermon;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;
  final List<PresentationSlide> slides;
  final _AnchorSlideCallback? onAnchorSlide;

  @override
  Widget build(BuildContext context) {
    final blocks = sermon.document.blocks
        .where(
          (block) =>
              block is HeadingBlock ||
              (block is NoteBlock && !block.isQuickNote),
        )
        .toList(growable: false);
    final counterpartSlides = slides
        .where((slide) {
          final anchor = slide.anchor;
          if (anchor == null || anchor.view != PresentationAnchorView.script) {
            return false;
          }
          return sermon.document.blocks
                  .where((block) => block.id == anchor.blockId)
                  .firstOrNull
              is! HeadingBlock;
        })
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
                key: ValueKey('notes-title-${sermon.id}'),
                initialValue: sermon.title,
                hintText: 'Titel',
                maxLines: null,
                style: _titleStyle(context),
                onChanged: (value) =>
                    onUpdateSermon(sermon.copyWith(title: value)),
              ),
              const SizedBox(height: 28),
              _SermonOverviewEditor(
                keyPrefix: 'notes',
                sermon: sermon,
                activeBlockId: activeBlockId,
                richKeys: richKeys,
                onActivate: onActivate,
                onUpdateSermon: onUpdateSermon,
                onUpdateBlock: onUpdateBlock,
                onInsertAfter: onInsertAfter,
                onDelete: onDelete,
                onNavigate: onNavigate,
                onPaste: onPaste,
              ),
              const SizedBox(height: 38),
              Divider(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              const SizedBox(height: 38),
              if (counterpartSlides.isNotEmpty) ...[
                _CounterpartSlideMarker(
                  slides: counterpartSlides,
                  slideNumbers: [
                    for (final slide in counterpartSlides)
                      slides.indexOf(slide) + 1,
                  ],
                ),
                const SizedBox(height: 22),
              ],
              for (var index = 0; index < blocks.length; index++)
                _DocumentBlockField(
                  block: blocks[index],
                  previous: index == 0 ? null : blocks[index - 1],
                  active: activeBlockId == blocks[index].id,
                  dimmed:
                      focusedBlockIds != null &&
                      !focusedBlockIds!.contains(blocks[index].id),
                  richKey: richKeys.putIfAbsent(
                    blocks[index].id,
                    GlobalKey.new,
                  ),
                  onActivate: onActivate,
                  onChanged: onUpdateBlock,
                  onInsertAfter: onInsertAfter,
                  onDelete: onDelete,
                  onNavigate: onNavigate,
                  onPaste: onPaste,
                  noteMode: true,
                  slides: slides,
                  anchorView: PresentationAnchorView.notes,
                  onAnchorSlide: onAnchorSlide,
                  focusKeyPrefix: focusKeyPrefix,
                ),
              _GhostAdd(
                label: 'Stichpunkt',
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

// Kept temporarily as the legacy renderer for migrated documents while the
// module-aware split renderer is exercised by the migration test suite.
// ignore: unused_element
class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.sermon,
    required this.activeBlockId,
    required this.richKeys,
    required this.onActivate,
    required this.onUpdateSermon,
    required this.onUpdateBlock,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
    // Kept only for the legacy split widget while old saved views migrate.
    // ignore: unused_element_parameter
    this.slides = const [],
    // Kept only for the legacy split widget while old saved views migrate.
    // ignore: unused_element_parameter
    this.onAnchorSlide,
  });

  final Sermon sermon;
  final String? activeBlockId;
  final Map<String, GlobalKey<_RichBlockFieldState>> richKeys;
  final ValueChanged<String> onActivate;
  final ValueChanged<Sermon> onUpdateSermon;
  final ValueChanged<DocumentBlock> onUpdateBlock;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;
  final List<PresentationSlide> slides;
  final _AnchorSlideCallback? onAnchorSlide;

  @override
  Widget build(BuildContext context) {
    final segments = _segments(
      sermon.document.blocks
          .where(
            (block) => block is! NoteBlock || !block.isQuickNote,
          )
          .toList(growable: false),
    );
    final activeBlock = sermon.document.blocks
        .where((block) => block.id == activeBlockId)
        .firstOrNull;
    final activeSegmentIndex = segments.indexWhere(
      (segment) => segment.contains(activeBlockId),
    );
    final hasDocumentFocus = activeBlock != null;

    bool dimHeading(HeadingBlock heading) =>
        hasDocumentFocus && heading.id != activeBlockId;

    bool dimScriptBlock(int segmentIndex, DocumentBlock block) {
      if (!hasDocumentFocus) return false;
      if (activeBlock is HeadingBlock || activeBlock is NoteBlock) {
        return activeBlock is HeadingBlock ||
            segmentIndex != activeSegmentIndex;
      }
      return block.id != activeBlockId;
    }

    bool dimNoteBlock(int segmentIndex, NoteBlock block) {
      if (!hasDocumentFocus) return false;
      if (activeBlock is HeadingBlock || activeBlock is! NoteBlock) {
        return activeBlock is HeadingBlock ||
            segmentIndex != activeSegmentIndex;
      }
      return block.id != activeBlockId;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.splitWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(48, 54, 48, 190),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScriptMeta(sermon: sermon, onChanged: onUpdateSermon),
              const SizedBox(height: 30),
              _BareTextField(
                key: ValueKey('split-title-${sermon.id}'),
                initialValue: sermon.title,
                hintText: 'Titel',
                maxLines: null,
                style: _titleStyle(context),
                onChanged: (value) =>
                    onUpdateSermon(sermon.copyWith(title: value)),
              ),
              const SizedBox(height: 28),
              _SermonOverviewEditor(
                keyPrefix: 'split',
                sermon: sermon,
                activeBlockId: activeBlockId,
                richKeys: richKeys,
                onActivate: onActivate,
                onUpdateSermon: onUpdateSermon,
                onUpdateBlock: onUpdateBlock,
                onInsertAfter: onInsertAfter,
                onDelete: onDelete,
                onNavigate: onNavigate,
                onPaste: onPaste,
              ),
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
              for (
                var segmentIndex = 0;
                segmentIndex < segments.length;
                segmentIndex++
              ) ...[
                Builder(
                  builder: (context) {
                    final segment = segments[segmentIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (segment.headings.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 34, bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var index = 0;
                                  index < segment.headings.length;
                                  index++
                                )
                                  _DocumentBlockField(
                                    block: segment.headings[index],
                                    previous: index == 0
                                        ? null
                                        : segment.headings[index - 1],
                                    active:
                                        activeBlockId ==
                                        segment.headings[index].id,
                                    dimmed: dimHeading(segment.headings[index]),
                                    richKey: richKeys.putIfAbsent(
                                      segment.headings[index].id,
                                      GlobalKey.new,
                                    ),
                                    onActivate: onActivate,
                                    onChanged: onUpdateBlock,
                                    onInsertAfter: onInsertAfter,
                                    onDelete: onDelete,
                                    onNavigate: onNavigate,
                                    onPaste: onPaste,
                                    noteMode: false,
                                    slides: slides,
                                    onAnchorSlide: onAnchorSlide,
                                  ),
                              ],
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) => Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 40),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  activeBlockId ==
                                                  segment.script[index].id,
                                              dimmed: dimScriptBlock(
                                                segmentIndex,
                                                segment.script[index],
                                              ),
                                              richKey: richKeys.putIfAbsent(
                                                segment.script[index].id,
                                                GlobalKey.new,
                                              ),
                                              onActivate: onActivate,
                                              onChanged: onUpdateBlock,
                                              onInsertAfter: onInsertAfter,
                                              onDelete: onDelete,
                                              onNavigate: onNavigate,
                                              onPaste: onPaste,
                                              noteMode: false,
                                              slides: slides,
                                              onAnchorSlide: onAnchorSlide,
                                            ),
                                          if (segment.script.isEmpty)
                                            _GhostAdd(
                                              label: 'Absatz hinzufügen',
                                              onTap: () =>
                                                  _addParagraph(segment),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 1),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 40),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                  activeBlockId ==
                                                  segment.notes[index].id,
                                              dimmed: dimNoteBlock(
                                                segmentIndex,
                                                segment.notes[index],
                                              ),
                                              richKey: richKeys.putIfAbsent(
                                                segment.notes[index].id,
                                                GlobalKey.new,
                                              ),
                                              onActivate: onActivate,
                                              onChanged: onUpdateBlock,
                                              onInsertAfter: onInsertAfter,
                                              onDelete: onDelete,
                                              onNavigate: onNavigate,
                                              onPaste: onPaste,
                                              noteMode: true,
                                              slides: slides,
                                              anchorView:
                                                  PresentationAnchorView.notes,
                                              onAnchorSlide: onAnchorSlide,
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
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: constraints.maxWidth / 2,
                                child: ColoredBox(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                  child: const SizedBox(width: 1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
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
    required this.dimmed,
    required this.richKey,
    required this.onActivate,
    required this.onChanged,
    required this.onInsertAfter,
    required this.onDelete,
    required this.onNavigate,
    required this.onPaste,
    required this.noteMode,
    this.allowNoteIndent = true,
    this.slides = const [],
    this.anchorView = PresentationAnchorView.script,
    this.onAnchorSlide,
    this.focusKeyPrefix,
  });

  final DocumentBlock block;
  final DocumentBlock? previous;
  final bool active;
  final bool dimmed;
  final GlobalKey<_RichBlockFieldState> richKey;
  final ValueChanged<String> onActivate;
  final ValueChanged<DocumentBlock> onChanged;
  final _InsertBlockCallback onInsertAfter;
  final ValueChanged<String> onDelete;
  final bool Function(String, int) onNavigate;
  final _RichPasteCallback onPaste;
  final bool noteMode;
  final bool allowNoteIndent;
  final List<PresentationSlide> slides;
  final PresentationAnchorView anchorView;
  final _AnchorSlideCallback? onAnchorSlide;
  final String? focusKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final anchored = slides
        .where((slide) => slide.anchor?.blockId == block.id)
        .toList(growable: false);
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        _buildField(context),
        if (anchored.isNotEmpty)
          Positioned(
            right: -42,
            top: 2,
            child: _SlideAnchorMarker(
              slides: anchored,
              slideNumbers: [
                for (final slide in anchored) slides.indexOf(slide) + 1,
              ],
            ),
          ),
      ],
    );
    return DragTarget<PresentationSlide>(
      onWillAcceptWithDetails: (_) => onAnchorSlide != null,
      onAcceptWithDetails: (details) {
        final offset =
            richKey.currentState?.offsetForGlobalPosition(details.offset) ?? 0;
        onAnchorSlide?.call(details.data, block.id, anchorView, offset);
      },
      builder: (context, candidates, _) => AnimatedContainer(
        duration: AppMotion.quick,
        decoration: BoxDecoration(
          border: candidates.isEmpty
              ? null
              : Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
        ),
        child: AnimatedOpacity(
          key: ValueKey(
            focusKeyPrefix == null
                ? 'focus-fade-${block.id}'
                : 'focus-fade-$focusKeyPrefix-${block.id}',
          ),
          opacity: dimmed ? 0.5 : 1,
          duration: AppMotion.quick,
          curve: Curves.easeOut,
          child: content,
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    final margin = _blockTopMargin(block, previous);
    if (block is HeadingBlock) {
      final heading = block as HeadingBlock;
      return Padding(
        padding: EdgeInsets.only(top: margin),
        child: _RichBlockField(
          key: richKey,
          blockId: heading.id,
          text: heading.text,
          marks: const <InlineMark>[],
          hintText: 'Überschrift ${heading.level}',
          style: switch (heading.level) {
            1 => _headingStyle(context),
            2 => _subheadingStyle(context),
            _ => _tertiaryHeadingStyle(context),
          },
          onFocus: () => onActivate(heading.id),
          onChanged: (value, _) => onChanged(
            HeadingBlock(
              id: heading.id,
              level: heading.level,
              text: value,
              collapsed: heading.collapsed,
              createdAt: heading.createdAt,
              updatedAt: DateTime.now().toUtc(),
            ),
          ),
          onSubmitted: _submitAndInsert,
          onEmptyBackspace: () => onDelete(heading.id),
          onNavigate: (direction) => onNavigate(heading.id, direction),
          onPaste: (selection, {required plainTextOnly}) => onPaste(
            heading.id,
            selection,
            noteMode: noteMode,
            plainTextOnly: plainTextOnly,
          ),
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
            child: _RichBlockField(
              key: richKey,
              blockId: quote.id,
              text: quote.text,
              marks: const <InlineMark>[],
              style: _quoteStyle(context),
              hintText: '',
              readOnly: true,
              onFocus: () => onActivate(quote.id),
              onChanged: (_, _) {},
              onSubmitted: (_) {},
              onEmptyBackspace: () {},
              onNavigate: (direction) => onNavigate(quote.id, direction),
              onPaste: (_, {required plainTextOnly}) async {},
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
    final isQuickNote = switch (block) {
      NoteBlock(:final isQuickNote) => isQuickNote,
      _ => false,
    };
    final field = _RichBlockField(
      key: richKey,
      blockId: block.id,
      text: text,
      marks: marks,
      style: block is QuoteBlock
          ? _quoteStyle(context)
          : isQuickNote
          ? _bodyStyle(context).copyWith(
              fontSize: 12.8,
              height: 1.6,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
            )
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
      onSubmitted: _submitAndInsert,
      onEmptyBackspace: () => onDelete(block.id),
      onNavigate: (direction) => onNavigate(block.id, direction),
      onPaste: (selection, {required plainTextOnly}) => onPaste(
        block.id,
        selection,
        noteMode: noteMode,
        plainTextOnly: plainTextOnly,
      ),
      onIndent: block is NoteBlock && allowNoteIndent
          ? (_) {
              final note = block as NoteBlock;
              onChanged(
                NoteBlock(
                  id: note.id,
                  text: note.text,
                  visibility: note.visibility,
                  depth: note.depth == 0 ? 1 : 0,
                  isQuickNote: note.isQuickNote,
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
                    fontSize: isQuickNote
                        ? 12
                        : depth == 1
                        ? 14
                        : 16,
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

  void _submitAndInsert(TextSelection selection) {
    final source = block.plainText;
    final start = selection.isValid
        ? selection.start.clamp(0, source.length)
        : source.length;
    final end = selection.isValid
        ? selection.end.clamp(start, source.length)
        : source.length;
    final originalMarks = _inlineMarksOf(block);
    final current = _withRichText(
      block,
      source.substring(0, start),
      _marksWithin(
        originalMarks,
        sourceStart: 0,
        sourceEnd: start,
      ),
    );
    final normalized = _normalizeMarkdownBlock(current);
    onChanged(normalized);

    final now = DateTime.now().toUtc();
    final currentNote = block is NoteBlock ? block as NoteBlock : null;
    final remainingText = source.substring(end);
    final remainingMarks = _marksWithin(
      originalMarks,
      sourceStart: end,
      sourceEnd: source.length,
    );
    final next = noteMode
        ? NoteBlock(
            id: const Uuid().v4(),
            text: remainingText,
            visibility: NoteVisibility.editorOnly,
            depth: currentNote?.depth ?? 0,
            isQuickNote: currentNote?.isQuickNote ?? false,
            marks: remainingMarks,
            createdAt: now,
            updatedAt: now,
          )
        : ParagraphBlock(
            id: const Uuid().v4(),
            text: remainingText,
            semanticRole: ParagraphRole.normal,
            marks: remainingMarks,
            createdAt: now,
            updatedAt: now,
          );
    onInsertAfter(block.id, next, focusAtEnd: false);
  }
}

class _SlideAnchorMarker extends StatefulWidget {
  const _SlideAnchorMarker({
    required this.slides,
    required this.slideNumbers,
  });

  final List<PresentationSlide> slides;
  final List<int> slideNumbers;

  @override
  State<_SlideAnchorMarker> createState() => _SlideAnchorMarkerState();
}

class _CounterpartSlideMarker extends StatelessWidget {
  const _CounterpartSlideMarker({
    required this.slides,
    required this.slideNumbers,
  });

  final List<PresentationSlide> slides;
  final List<int> slideNumbers;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _SlideAnchorMarker(
        slides: slides,
        slideNumbers: slideNumbers,
      ),
      const SizedBox(width: 9),
      Text(
        slides.length == 1
            ? '1 Folie aus der anderen Ansicht'
            : '${slides.length} Folien aus der anderen Ansicht',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 9.5,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: .42),
        ),
      ),
    ],
  );
}

class _SlideAnchorMarkerState extends State<_SlideAnchorMarker> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) => CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topRight,
        offset: const Offset(8, -8),
        child: IgnorePointer(
          child: Material(
            elevation: 10,
            color: Colors.transparent,
            child: Container(
              width: 250,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final slide in widget.slides.take(3)) ...[
                    SlideCanvas(slide: slide),
                    if (slide != widget.slides.take(3).last)
                      const SizedBox(height: 7),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      child: MouseRegion(
        onEnter: (_) => _controller.show(),
        onExit: (_) => _controller.hide(),
        child: Container(
          key: Key(
            'slide-anchor-marker-${widget.slideNumbers.join('-')}',
          ),
          height: 19,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.galleryHorizontal,
                size: 9,
                color: Theme.of(context).colorScheme.surface,
              ),
              const SizedBox(width: 3),
              Text(
                _slideNumberLabel(widget.slideNumbers),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 8.5,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.surface,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String _slideNumberLabel(List<int> numbers) {
  if (numbers.isEmpty) return '';
  if (numbers.length <= 3) return numbers.join('·');
  return '${numbers.take(2).join('·')}…';
}

class _BlockSelectionScope extends InheritedWidget {
  const _BlockSelectionScope({
    required this.onStart,
    required this.onUpdate,
    required this.onSelectAll,
    required this.onCopySelection,
    required this.onCutSelection,
    required this.onDeleteSelection,
    required this.onClearSelection,
    required this.onUndo,
    required this.onRedo,
    required super.child,
  });

  final void Function(String id, int offset) onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onSelectAll;
  final bool Function() onCopySelection;
  final bool Function() onCutSelection;
  final bool Function() onDeleteSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  static _BlockSelectionScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BlockSelectionScope>();

  @override
  bool updateShouldNotify(_BlockSelectionScope oldWidget) =>
      onStart != oldWidget.onStart ||
      onUpdate != oldWidget.onUpdate ||
      onSelectAll != oldWidget.onSelectAll ||
      onCopySelection != oldWidget.onCopySelection ||
      onCutSelection != oldWidget.onCutSelection ||
      onDeleteSelection != oldWidget.onDeleteSelection ||
      onClearSelection != oldWidget.onClearSelection ||
      onUndo != oldWidget.onUndo ||
      onRedo != oldWidget.onRedo;
}

class _RichBlockField extends StatefulWidget {
  const _RichBlockField({
    required this.blockId,
    required this.text,
    required this.marks,
    required this.style,
    required this.hintText,
    required this.onFocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onEmptyBackspace,
    required this.onNavigate,
    required this.onPaste,
    this.onIndent,
    this.readOnly = false,
    super.key,
  });

  final String blockId;
  final String text;
  final List<InlineMark> marks;
  final TextStyle style;
  final String hintText;
  final VoidCallback onFocus;
  final void Function(String text, List<InlineMark> marks) onChanged;
  final ValueChanged<TextSelection> onSubmitted;
  final VoidCallback onEmptyBackspace;
  final ValueChanged<int> onNavigate;
  final Future<void> Function(
    TextSelection selection, {
    required bool plainTextOnly,
  })
  onPaste;
  final ValueChanged<bool>? onIndent;
  final bool readOnly;

  @override
  State<_RichBlockField> createState() => _RichBlockFieldState();
}

class _RichBlockFieldState extends State<_RichBlockField> {
  late final _MarkedTextController _controller = _MarkedTextController(
    text: widget.text,
    marks: widget.marks,
  );
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
  late String _lastText = widget.text;
  _BlockSelectionScope? _selectionScope;
  final Map<_InlineFormat, bool> _typingFormats = {};
  TextSelection _lastReportedSelection = const TextSelection.collapsed(
    offset: -1,
  );
  bool _selectionReportScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportSelectionChange);
  }

  void _reportSelectionChange() {
    final selection = _controller.selection;
    if (!_focusNode.hasFocus || selection == _lastReportedSelection) return;
    _lastReportedSelection = selection;
    if (!selection.isCollapsed) _typingFormats.clear();
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      widget.onFocus();
      return;
    }
    if (_selectionReportScheduled) return;
    _selectionReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _selectionReportScheduled = false;
      if (!mounted || !_focusNode.hasFocus) return;
      widget.onFocus();
    });
  }

  @override
  void didUpdateWidget(_RichBlockField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && _controller.text != widget.text) {
      _controller
        ..text = widget.text
        ..marks = widget.marks;
      _lastText = widget.text;
    } else if (oldWidget.marks != widget.marks) {
      _controller.marks = widget.marks;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_reportSelectionChange)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get textLength => _controller.text.length;

  Set<_InlineFormat> get activeFormats {
    final selection = _controller.selection;
    if (!selection.isValid) return const <_InlineFormat>{};
    return {
      for (final format in _InlineFormat.values)
        if (_typingFormats[format] ??
            (selection.isCollapsed
                ? _inlineFormatAtCaret(
                    _controller.marks,
                    format,
                    selection.extentOffset.clamp(0, _controller.text.length),
                  )
                : _inlineFormatCoversRange(
                    _controller.marks,
                    format,
                    selection.start,
                    selection.end,
                  )))
          format,
    };
  }

  Rect? get globalBounds {
    final editable = _renderEditable;
    if (editable == null || !editable.attached) return null;
    return editable.localToGlobal(Offset.zero) & editable.size;
  }

  int offsetForGlobalPosition(Offset globalPosition) {
    final editable = _renderEditable;
    if (editable == null) return 0;
    return editable
        .getPositionForPoint(globalPosition)
        .offset
        .clamp(0, _controller.text.length);
  }

  RenderEditable? get _renderEditable {
    RenderEditable? result;
    void visit(RenderObject object) {
      if (result != null) return;
      if (object is RenderEditable) {
        result = object;
        return;
      }
      object.visitChildren(visit);
    }

    final root = context.findRenderObject();
    if (root != null) visit(root);
    return result;
  }

  TextSelection get externalSelection => _controller.selection;

  set externalSelection(TextSelection selection) {
    _controller.externalSelection = selection;
    _controller.selection = selection;
  }

  void clearExternalSelection() {
    _controller.externalSelection = null;
    if (!_controller.selection.isValid || _controller.selection.isCollapsed) {
      return;
    }
    _controller.selection = TextSelection.collapsed(
      offset: _controller.selection.extentOffset.clamp(
        0,
        _controller.text.length,
      ),
    );
  }

  void applyFormat(
    _InlineFormat format, {
    TextSelection? selection,
  }) {
    selection ??= _controller.selection;
    if (!selection.isValid) return;
    if (selection.isCollapsed) {
      final offset = selection.extentOffset.clamp(0, _controller.text.length);
      final current =
          _typingFormats[format] ??
          _inlineFormatAtCaret(_controller.marks, format, offset);
      setState(() => _typingFormats[format] = !current);
      widget.onFocus();
      return;
    }
    final enabled = !_inlineFormatCoversRange(
      _controller.marks,
      format,
      selection.start,
      selection.end,
    );
    final next = _setInlineFormatInRange(
      _controller.marks,
      format: format,
      start: selection.start,
      end: selection.end,
      enabled: enabled,
    );
    setState(() => _controller.marks = next);
    widget.onChanged(_controller.text, next);
    widget.onFocus();
  }

  void clearHighlights({TextSelection? selection}) {
    if (!_controller.marks.any((mark) => mark.highlighted)) return;
    final next = <InlineMark>[];
    for (final mark in _controller.marks) {
      if (!mark.highlighted) {
        next.add(mark);
        continue;
      }
      if (selection == null) {
        if (mark.bold || mark.italic) {
          next.add(
            InlineMark(
              start: mark.start,
              end: mark.end,
              bold: mark.bold,
              italic: mark.italic,
            ),
          );
        }
        continue;
      }
      final removalStart = selection.start;
      final removalEnd = selection.end;
      if (mark.end <= removalStart || mark.start >= removalEnd) {
        next.add(mark);
        continue;
      }
      if (mark.start < removalStart) {
        next.add(
          InlineMark(
            start: mark.start,
            end: removalStart,
            bold: mark.bold,
            italic: mark.italic,
            highlighted: true,
          ),
        );
      }
      final overlapStart = math.max(mark.start, removalStart);
      final overlapEnd = math.min(mark.end, removalEnd);
      if ((mark.bold || mark.italic) && overlapStart < overlapEnd) {
        next.add(
          InlineMark(
            start: overlapStart,
            end: overlapEnd,
            bold: mark.bold,
            italic: mark.italic,
          ),
        );
      }
      if (mark.end > removalEnd) {
        next.add(
          InlineMark(
            start: removalEnd,
            end: mark.end,
            bold: mark.bold,
            italic: mark.italic,
            highlighted: true,
          ),
        );
      }
    }
    setState(() => _controller.marks = next);
    widget.onChanged(_controller.text, next);
  }

  void requestFocus({bool atEnd = true}) {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: atEnd ? _controller.text.length : 0,
    );
    widget.onFocus();
  }

  void requestFocusAt(int offset) {
    _focusNode.requestFocus();
    _controller.selection = TextSelection.collapsed(
      offset: offset.clamp(0, _controller.text.length),
    );
    widget.onFocus();
  }

  void syncContent(String text, List<InlineMark> marks) {
    final offset = _controller.selection.extentOffset.clamp(0, text.length);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
    _controller.marks = marks;
    _lastText = text;
  }

  void _submitCurrentBlock() {
    final source = _controller.text;
    final selection = _controller.selection.isValid
        ? _controller.selection
        : TextSelection.collapsed(offset: source.length);
    final start = selection.start.clamp(0, source.length);
    final prefixMarks = _marksWithin(
      _controller.marks,
      sourceStart: 0,
      sourceEnd: start,
    );
    _selectionScope?.onClearSelection();
    _controller.value = TextEditingValue(
      text: source.substring(0, start),
      selection: TextSelection.collapsed(offset: start),
    );
    _controller.marks = prefixMarks;
    _lastText = _controller.text;
    widget.onSubmitted(selection);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.keyZ &&
        isPrimaryShortcutPressed) {
      if (HardwareKeyboard.instance.isShiftPressed) {
        _selectionScope?.onRedo();
      } else {
        _selectionScope?.onUndo();
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyA &&
        isPrimaryShortcutPressed) {
      _selectionScope?.onSelectAll();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        isPrimaryShortcutPressed) {
      unawaited(
        widget.onPaste(
          _controller.selection,
          plainTextOnly: HardwareKeyboard.instance.isShiftPressed,
        ),
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyC &&
        isPrimaryShortcutPressed &&
        (_selectionScope?.onCopySelection() ?? false)) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyX &&
        isPrimaryShortcutPressed &&
        (_selectionScope?.onCutSelection() ?? false)) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        (_selectionScope?.onDeleteSelection() ?? false)) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controller.selection.isValid &&
        _controller.selection.isCollapsed &&
        _controller.selection.extentOffset == 0) {
      widget.onEmptyBackspace();
      return KeyEventResult.handled;
    }
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submitCurrentBlock();
      return KeyEventResult.handled;
    }
    final selection = _controller.selection;
    if (selection.isValid && selection.isCollapsed) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          selection.extentOffset == _controller.text.length) {
        _typingFormats.clear();
        widget.onNavigate(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          selection.extentOffset == 0) {
        _typingFormats.clear();
        widget.onNavigate(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.home ||
          event.logicalKey == LogicalKeyboardKey.end) {
        _typingFormats.clear();
      }
    }
    if (event.logicalKey == LogicalKeyboardKey.tab && widget.onIndent != null) {
      widget.onIndent!(HardwareKeyboard.instance.isShiftPressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final selectionScope = _BlockSelectionScope.maybeOf(context);
    _selectionScope = selectionScope;
    return Listener(
      onPointerDown: (event) => selectionScope?.onStart(
        widget.blockId,
        offsetForGlobalPosition(event.position),
      ),
      onPointerMove: (event) => selectionScope?.onUpdate(event.position),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        minLines: 1,
        maxLines: null,
        scrollPadding: const EdgeInsets.fromLTRB(20, 72, 20, 180),
        style: widget.style,
        cursorWidth: 1.8,
        cursorRadius: const Radius.circular(1),
        cursorColor: Theme.of(context).colorScheme.onSurface,
        textInputAction: TextInputAction.newline,
        readOnly: widget.readOnly,
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
        onTap: () {
          _typingFormats.clear();
          widget.onFocus();
        },
        onChanged: (value) {
          _selectionScope?.onClearSelection();
          final previousMarks = _controller.marks;
          var adjustedMarks = _adjustMarksForTextChange(
            previousMarks,
            oldText: _lastText,
            newText: value,
          );
          final change = _changedTextRange(_lastText, value);
          final deletedText = change.oldEnd > change.newEnd;
          if (deletedText) {
            for (final format in _InlineFormat.values) {
              _typingFormats[format] = _inlineFormatAtCaret(
                previousMarks,
                format,
                change.oldEnd,
              );
            }
          }
          if (change.start < change.newEnd && _typingFormats.isNotEmpty) {
            for (final entry in _typingFormats.entries) {
              adjustedMarks = _setInlineFormatInRange(
                adjustedMarks,
                format: entry.key,
                start: change.start,
                end: change.newEnd,
                enabled: entry.value,
              );
            }
          }
          _lastText = value;
          _controller.marks = adjustedMarks;
          final selection = _controller.selection;
          if (selection.isValid &&
              selection.isCollapsed &&
              selection.affinity != TextAffinity.downstream) {
            _controller.selection = TextSelection.collapsed(
              offset: selection.extentOffset.clamp(0, value.length),
            );
          }
          widget.onChanged(value, adjustedMarks);
        },
        onSubmitted: (_) => _submitCurrentBlock(),
      ),
    );
  }
}

class _MarkedTextController extends TextEditingController {
  _MarkedTextController({
    required String text,
    required this._marks,
  }) : super(text: text);

  List<InlineMark> _marks;
  TextSelection? _externalSelection;

  List<InlineMark> get marks => _marks;

  set marks(List<InlineMark> value) {
    _marks = value;
    notifyListeners();
  }

  TextSelection? get externalSelection => _externalSelection;

  set externalSelection(TextSelection? value) {
    _externalSelection = value;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final externalSelection = _externalSelection;
    final hasExternalSelection =
        externalSelection != null &&
        externalSelection.isValid &&
        !externalSelection.isCollapsed;
    if ((_marks.isEmpty && !hasExternalSelection) || text.isEmpty) {
      return TextSpan(text: text, style: style);
    }
    final boundaries = <int>{0, text.length};
    for (final mark in _marks) {
      boundaries
        ..add(mark.start.clamp(0, text.length))
        ..add(mark.end.clamp(0, text.length));
    }
    if (hasExternalSelection) {
      boundaries
        ..add(externalSelection.start.clamp(0, text.length))
        ..add(externalSelection.end.clamp(0, text.length));
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
      final externallySelected =
          hasExternalSelection &&
          externalSelection.start <= start &&
          externalSelection.end >= end;
      final markerPaint = highlighted && !externallySelected
          ? (Paint()
              ..color = AppColors.highlight.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.28 + (index.isEven ? 0.025 : 0)
                    : 0.64 + (index.isEven ? 0.045 : 0),
              )
              ..style = PaintingStyle.fill
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.55))
          : null;
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: style?.copyWith(
            fontWeight: bold ? FontWeight.w700 : style.fontWeight,
            fontStyle: italic ? FontStyle.italic : style.fontStyle,
            background: markerPaint,
            backgroundColor: externallySelected
                ? Theme.of(context).textSelectionTheme.selectionColor ??
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.22)
                : null,
          ),
        ),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

DocumentBlock _normalizeMarkdownBlock(DocumentBlock block) {
  final originalMarks = _inlineMarksOf(block);
  final source = block.plainText;
  final headingMatch = block is ParagraphBlock
      ? RegExp(r'^(#{1,3})\s*(.+)$').firstMatch(source)
      : null;
  if (headingMatch != null) {
    final parsed = _parseInlineMarkdown(
      headingMatch.group(2)!,
      const <InlineMark>[],
    );
    return HeadingBlock(
      id: block.id,
      level: headingMatch.group(1)!.length,
      text: parsed.text,
      collapsed: false,
      createdAt: block.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
  final quoteMatch = block is ParagraphBlock
      ? RegExp(r'^>\s?(.*)$').firstMatch(source)
      : null;
  if (quoteMatch != null) {
    final parsed = _parseInlineMarkdown(
      quoteMatch.group(1)!,
      const <InlineMark>[],
    );
    return QuoteBlock(
      id: block.id,
      text: parsed.text,
      author: '',
      source: '',
      marks: parsed.marks,
      createdAt: block.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
  final parsed = _parseInlineMarkdown(source, originalMarks);
  if (!parsed.changed) return block;
  return _withRichText(block, parsed.text, parsed.marks);
}

_InlineMarkdownResult _parseInlineMarkdown(
  String source,
  List<InlineMark> existingMarks,
) {
  final output = StringBuffer();
  final mapping = List<int>.filled(source.length + 1, 0);
  final generatedMarks = <InlineMark>[];
  var index = 0;
  var changed = false;
  while (index < source.length) {
    String? delimiter;
    var bold = false;
    var italic = false;
    var highlighted = false;
    if (source.startsWith('**', index)) {
      delimiter = '**';
      bold = true;
    } else if (source.startsWith('==', index)) {
      delimiter = '==';
      highlighted = true;
    } else if (source[index] == '*') {
      delimiter = '*';
      italic = true;
    } else if (source[index] == '_') {
      delimiter = '_';
      italic = true;
    }
    final closing = delimiter == null
        ? -1
        : source.indexOf(delimiter, index + delimiter.length);
    if (delimiter != null && closing > index + delimiter.length) {
      changed = true;
      final markStart = output.length;
      for (var cursor = index; cursor <= index + delimiter.length; cursor++) {
        mapping[cursor] = output.length;
      }
      for (var cursor = index + delimiter.length; cursor < closing; cursor++) {
        mapping[cursor] = output.length;
        output.write(source[cursor]);
        mapping[cursor + 1] = output.length;
      }
      final markEnd = output.length;
      for (
        var cursor = closing;
        cursor <= closing + delimiter.length;
        cursor++
      ) {
        mapping[cursor] = output.length;
      }
      generatedMarks.add(
        InlineMark(
          start: markStart,
          end: markEnd,
          bold: bold,
          italic: italic,
          highlighted: highlighted,
        ),
      );
      index = closing + delimiter.length;
      continue;
    }
    mapping[index] = output.length;
    output.write(source[index]);
    mapping[index + 1] = output.length;
    index++;
  }
  if (!changed) {
    return _InlineMarkdownResult(
      source,
      existingMarks,
      changed: false,
    );
  }
  final remapped = <InlineMark>[
    for (final mark in existingMarks)
      if (mapping[mark.start.clamp(0, source.length)] <
          mapping[mark.end.clamp(0, source.length)])
        InlineMark(
          start: mapping[mark.start.clamp(0, source.length)],
          end: mapping[mark.end.clamp(0, source.length)],
          bold: mark.bold,
          italic: mark.italic,
          highlighted: mark.highlighted,
        ),
    ...generatedMarks,
  ];
  return _InlineMarkdownResult(
    output.toString(),
    remapped,
    changed: true,
  );
}

List<InlineMark> _inlineMarksOf(DocumentBlock block) => switch (block) {
  ParagraphBlock(:final marks) => marks,
  QuoteBlock(:final marks) => marks,
  NoteBlock(:final marks) => marks,
  _ => const <InlineMark>[],
};

List<InlineMark> _marksWithin(
  List<InlineMark> marks, {
  required int sourceStart,
  required int sourceEnd,
  int targetOffset = 0,
}) {
  final result = <InlineMark>[];
  for (final mark in marks) {
    final clippedStart = mark.start > sourceStart ? mark.start : sourceStart;
    final clippedEnd = mark.end < sourceEnd ? mark.end : sourceEnd;
    if (clippedStart >= clippedEnd) continue;
    result.add(
      InlineMark(
        start: targetOffset + clippedStart - sourceStart,
        end: targetOffset + clippedEnd - sourceStart,
        bold: mark.bold,
        italic: mark.italic,
        highlighted: mark.highlighted,
      ),
    );
  }
  return result;
}

RichClipboardContent _clipboardContent(
  List<({DocumentBlock block, String text, List<InlineMark> marks})> blocks,
) {
  final html = StringBuffer('<div data-sermonary-clipboard="1">');
  for (final entry in blocks) {
    final block = entry.block;
    final inline = _inlineClipboardHtml(
      entry.text,
      entry.marks,
      bold: block is ParagraphBlock && block.isBold,
      italic: block is ParagraphBlock && block.isItalic,
    );
    switch (block) {
      case HeadingBlock():
        html.write('<h${block.level}>$inline</h${block.level}>');
      case QuoteBlock():
        html.write('<blockquote>$inline</blockquote>');
      case BibleQuoteBlock():
        html.write('<blockquote data-sermonary-bible="1">$inline</blockquote>');
      case NoteBlock():
        html.write(
          '<li data-sermonary-depth="${block.depth}">$inline</li>',
        );
      default:
        html.write('<p>$inline</p>');
    }
  }
  html.write('</div>');
  return RichClipboardContent(
    plainText: blocks.map((entry) => entry.text).join('\n'),
    html: html.toString(),
  );
}

String _inlineClipboardHtml(
  String text,
  List<InlineMark> marks, {
  required bool bold,
  required bool italic,
}) {
  if (text.isEmpty) return '';
  final boundaries = <int>{0, text.length};
  for (final mark in marks) {
    boundaries
      ..add(mark.start.clamp(0, text.length))
      ..add(mark.end.clamp(0, text.length));
  }
  final sorted = boundaries.toList()..sort();
  final result = StringBuffer();
  const escape = HtmlEscape();
  for (var index = 0; index < sorted.length - 1; index++) {
    final start = sorted[index];
    final end = sorted[index + 1];
    if (start == end) continue;
    final covering = marks.where(
      (mark) => mark.start <= start && mark.end >= end,
    );
    final isBold = bold || covering.any((mark) => mark.bold);
    final isItalic = italic || covering.any((mark) => mark.italic);
    final isHighlighted = covering.any((mark) => mark.highlighted);
    var fragment = escape.convert(text.substring(start, end));
    if (isBold) fragment = '<strong>$fragment</strong>';
    if (isItalic) fragment = '<em>$fragment</em>';
    if (isHighlighted) fragment = '<mark>$fragment</mark>';
    result.write(fragment);
  }
  return result.toString();
}

List<InlineMark> _adjustMarksForTextChange(
  List<InlineMark> marks, {
  required String oldText,
  required String newText,
}) {
  if (marks.isEmpty || oldText == newText) return marks;
  var changeStart = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (changeStart < sharedLength &&
      oldText.codeUnitAt(changeStart) == newText.codeUnitAt(changeStart)) {
    changeStart++;
  }
  var sharedSuffix = 0;
  while (sharedSuffix < oldText.length - changeStart &&
      sharedSuffix < newText.length - changeStart &&
      oldText.codeUnitAt(oldText.length - sharedSuffix - 1) ==
          newText.codeUnitAt(newText.length - sharedSuffix - 1)) {
    sharedSuffix++;
  }
  final oldChangeEnd = oldText.length - sharedSuffix;
  final newChangeEnd = newText.length - sharedSuffix;
  final delta = newChangeEnd - oldChangeEnd;
  final adjusted = <InlineMark>[];
  for (final mark in marks) {
    var start = mark.start.clamp(0, oldText.length);
    var end = mark.end.clamp(start, oldText.length);
    if (end <= changeStart) {
      // The edit happened after this formatting range.
    } else if (start >= oldChangeEnd) {
      start += delta;
      end += delta;
    } else {
      start = start < changeStart ? start : changeStart;
      end = end > oldChangeEnd ? end + delta : newChangeEnd;
    }
    start = start.clamp(0, newText.length);
    end = end.clamp(start, newText.length);
    if (start == end) continue;
    adjusted.add(
      InlineMark(
        start: start,
        end: end,
        bold: mark.bold,
        italic: mark.italic,
        highlighted: mark.highlighted,
      ),
    );
  }
  return adjusted;
}

({int start, int oldEnd, int newEnd}) _changedTextRange(
  String oldText,
  String newText,
) {
  var start = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (start < sharedLength &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var sharedSuffix = 0;
  while (sharedSuffix < oldText.length - start &&
      sharedSuffix < newText.length - start &&
      oldText.codeUnitAt(oldText.length - sharedSuffix - 1) ==
          newText.codeUnitAt(newText.length - sharedSuffix - 1)) {
    sharedSuffix++;
  }
  return (
    start: start,
    oldEnd: oldText.length - sharedSuffix,
    newEnd: newText.length - sharedSuffix,
  );
}

bool _inlineFormatAtCaret(
  List<InlineMark> marks,
  _InlineFormat format,
  int offset,
) => marks.any((mark) {
  final touchesCaret =
      (mark.start < offset && offset <= mark.end) ||
      (offset == 0 && mark.start == 0 && mark.end > 0);
  return touchesCaret && _inlineMarkHasFormat(mark, format);
});

bool _inlineFormatCoversRange(
  List<InlineMark> marks,
  _InlineFormat format,
  int start,
  int end,
) {
  if (start >= end) return false;
  final boundaries = <int>{start, end};
  for (final mark in marks) {
    if (!_inlineMarkHasFormat(mark, format) ||
        mark.end <= start ||
        mark.start >= end) {
      continue;
    }
    boundaries
      ..add(mark.start.clamp(start, end))
      ..add(mark.end.clamp(start, end));
  }
  final sorted = boundaries.toList()..sort();
  for (var index = 0; index < sorted.length - 1; index++) {
    final segmentStart = sorted[index];
    final segmentEnd = sorted[index + 1];
    if (segmentStart == segmentEnd) continue;
    if (!marks.any(
      (mark) =>
          _inlineMarkHasFormat(mark, format) &&
          mark.start <= segmentStart &&
          mark.end >= segmentEnd,
    )) {
      return false;
    }
  }
  return true;
}

bool _inlineMarkHasFormat(InlineMark mark, _InlineFormat format) =>
    switch (format) {
      _InlineFormat.bold => mark.bold,
      _InlineFormat.italic => mark.italic,
      _InlineFormat.highlight => mark.highlighted,
    };

InlineMark _inlineMarkSegment(
  InlineMark mark,
  int start,
  int end, {
  _InlineFormat? format,
  bool? enabled,
}) => InlineMark(
  start: start,
  end: end,
  bold: format == _InlineFormat.bold ? enabled! : mark.bold,
  italic: format == _InlineFormat.italic ? enabled! : mark.italic,
  highlighted: format == _InlineFormat.highlight ? enabled! : mark.highlighted,
);

bool _inlineMarkHasAnyFormat(InlineMark mark) =>
    mark.bold || mark.italic || mark.highlighted;

List<InlineMark> _setInlineFormatInRange(
  List<InlineMark> marks, {
  required _InlineFormat format,
  required int start,
  required int end,
  required bool enabled,
}) {
  if (start >= end) return marks;
  final next = <InlineMark>[];
  if (enabled) {
    next
      ..addAll(marks)
      ..add(
        InlineMark(
          start: start,
          end: end,
          bold: format == _InlineFormat.bold,
          italic: format == _InlineFormat.italic,
          highlighted: format == _InlineFormat.highlight,
        ),
      );
    return _coalesceInlineMarks(next);
  }
  for (final mark in marks) {
    if (!_inlineMarkHasFormat(mark, format) ||
        mark.end <= start ||
        mark.start >= end) {
      next.add(mark);
      continue;
    }
    if (mark.start < start) {
      next.add(_inlineMarkSegment(mark, mark.start, start));
    }
    final overlapStart = math.max(mark.start, start);
    final overlapEnd = math.min(mark.end, end);
    final overlap = _inlineMarkSegment(
      mark,
      overlapStart,
      overlapEnd,
      format: format,
      enabled: false,
    );
    if (_inlineMarkHasAnyFormat(overlap)) next.add(overlap);
    if (mark.end > end) {
      next.add(_inlineMarkSegment(mark, end, mark.end));
    }
  }
  return _coalesceInlineMarks(next);
}

List<InlineMark> _coalesceInlineMarks(List<InlineMark> marks) {
  final sorted = [...marks]
    ..sort((first, second) {
      final start = first.start.compareTo(second.start);
      return start != 0 ? start : first.end.compareTo(second.end);
    });
  final result = <InlineMark>[];
  for (final mark in sorted) {
    if (!_inlineMarkHasAnyFormat(mark) || mark.start >= mark.end) continue;
    final previous = result.lastOrNull;
    if (previous != null &&
        previous.bold == mark.bold &&
        previous.italic == mark.italic &&
        previous.highlighted == mark.highlighted &&
        mark.start <= previous.end) {
      result[result.length - 1] = InlineMark(
        start: previous.start,
        end: math.max(previous.end, mark.end),
        bold: previous.bold,
        italic: previous.italic,
        highlighted: previous.highlighted,
      );
    } else {
      result.add(mark);
    }
  }
  return result;
}

class _InlineMarkdownResult {
  const _InlineMarkdownResult(
    this.text,
    this.marks, {
    required this.changed,
  });

  final String text;
  final List<InlineMark> marks;
  final bool changed;
}

DocumentBlock _withRichText(
  DocumentBlock block,
  String text,
  List<InlineMark> marks,
) {
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
      isQuickNote: block.isQuickNote,
      marks: marks,
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
    _ => block,
  };
}

DocumentBlock _copyPastedBoundaryBlock(
  DocumentBlock block, {
  required String id,
  required String text,
  required List<InlineMark> marks,
  required DateTime now,
}) => switch (block) {
  HeadingBlock() => HeadingBlock(
    id: id,
    level: block.level,
    text: text,
    collapsed: block.collapsed,
    createdAt: now,
    updatedAt: now,
  ),
  QuoteBlock() => QuoteBlock(
    id: id,
    text: text,
    author: block.author,
    source: block.source,
    marks: marks,
    createdAt: now,
    updatedAt: now,
  ),
  NoteBlock() => NoteBlock(
    id: id,
    text: text,
    visibility: block.visibility,
    depth: block.depth,
    isQuickNote: block.isQuickNote,
    marks: marks,
    createdAt: now,
    updatedAt: now,
  ),
  _ => ParagraphBlock(
    id: id,
    text: text,
    semanticRole: block is ParagraphBlock
        ? block.semanticRole
        : ParagraphRole.normal,
    isBold: block is ParagraphBlock && block.isBold,
    isItalic: block is ParagraphBlock && block.isItalic,
    marks: marks,
    createdAt: now,
    updatedAt: now,
  ),
};

DocumentBlock _documentBlockFromPaste(
  PastedBlock item, {
  required bool noteMode,
  required bool quickNote,
  required DateTime now,
}) {
  final marks = [
    for (final mark in item.marks)
      InlineMark(
        start: mark.start,
        end: mark.end,
        bold: mark.bold,
        italic: mark.italic,
        highlighted: mark.highlighted,
      ),
  ];
  if (item.kind == PastedBlockKind.heading) {
    return HeadingBlock(
      id: const Uuid().v4(),
      level: item.headingLevel!.clamp(1, 3),
      text: item.text,
      collapsed: false,
      createdAt: now,
      updatedAt: now,
    );
  }
  if (item.kind == PastedBlockKind.quote && !noteMode) {
    return QuoteBlock(
      id: const Uuid().v4(),
      text: item.text,
      author: '',
      source: '',
      marks: marks,
      createdAt: now,
      updatedAt: now,
    );
  }
  if (noteMode) {
    return NoteBlock(
      id: const Uuid().v4(),
      text: item.text,
      visibility: NoteVisibility.editorOnly,
      depth: item.noteDepth?.clamp(0, 1) ?? 0,
      isQuickNote: quickNote,
      marks: marks,
      createdAt: now,
      updatedAt: now,
    );
  }
  return ParagraphBlock(
    id: const Uuid().v4(),
    text: item.text,
    semanticRole: ParagraphRole.normal,
    marks: marks,
    createdAt: now,
    updatedAt: now,
  );
}

bool _canMergeSelectedBoundaries(DocumentBlock first, DocumentBlock last) =>
    switch ((first, last)) {
      (ParagraphBlock(), ParagraphBlock()) => true,
      (QuoteBlock(), QuoteBlock()) => true,
      (
        NoteBlock(depth: final firstDepth, isQuickNote: final firstQuickNote),
        NoteBlock(depth: final lastDepth, isQuickNote: final lastQuickNote),
      ) =>
        firstDepth == lastDepth && firstQuickNote == lastQuickNote,
      _ => false,
    };

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            softWrap: true,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11.5,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
            ),
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
              softWrap: true,
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
  const _BibleReferenceRequest({required this.text});

  final String text;
}

class _BibleReferenceDialog extends StatefulWidget {
  const _BibleReferenceDialog({
    required this.provider,
    required this.initialBookId,
    required this.initialChapter,
    required this.asNote,
  });

  final BibleProvider provider;
  final String initialBookId;
  final int initialChapter;
  final bool asNote;

  @override
  State<_BibleReferenceDialog> createState() => _BibleReferenceDialogState();
}

class _BibleReferenceDialogState extends State<_BibleReferenceDialog> {
  late String _bookId = widget.initialBookId;
  late int _chapter = widget.initialChapter.clamp(1, 150);
  int _verseFrom = 1;
  int _verseTo = 1;
  List<int> _availableChapters = const [];
  List<int> _availableVerses = const [];
  bool _elb85 = false;
  bool _loading = false;
  bool _submitting = false;
  int _loadGeneration = 0;
  final TextEditingController _textController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleElb85() async {
    final enabled = !_elb85;
    setState(() {
      _elb85 = enabled;
      _errorText = null;
    });
    if (enabled) await _loadBook(_bookId);
  }

  Future<void> _loadBook(String bookId) async {
    final generation = ++_loadGeneration;
    setState(() {
      _bookId = bookId;
      _loading = true;
      _availableChapters = const [];
      _availableVerses = const [];
    });
    try {
      final chapters = await widget.provider.listChapters('elb85', bookId);
      if (!mounted || generation != _loadGeneration) return;
      if (chapters.isEmpty) {
        setState(() {
          _loading = false;
          _errorText = 'Für dieses Buch wurden keine Kapitel gefunden.';
        });
        return;
      }
      final chapter = chapters.contains(_chapter) ? _chapter : chapters.first;
      setState(() {
        _availableChapters = chapters;
        _chapter = chapter;
      });
      await _loadChapter(chapter, generation: generation);
    } on Object catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _errorText = 'Die lokale ELB85 konnte nicht geladen werden.';
      });
    }
  }

  Future<void> _loadChapter(int chapter, {int? generation}) async {
    final activeGeneration = generation ?? ++_loadGeneration;
    setState(() {
      _chapter = chapter;
      _loading = true;
      _availableVerses = const [];
    });
    try {
      final verses = await widget.provider.listVerses(
        'elb85',
        _bookId,
        chapter,
      );
      if (!mounted || activeGeneration != _loadGeneration) return;
      setState(() {
        _availableVerses = verses;
        _verseFrom = verses.isEmpty ? 1 : verses.first;
        _verseTo = verses.isEmpty ? 1 : verses.first;
        _loading = false;
        _errorText = verses.isEmpty
            ? 'Für dieses Kapitel wurden keine Verse gefunden.'
            : null;
      });
    } on Object catch (_) {
      if (!mounted || activeGeneration != _loadGeneration) return;
      setState(() {
        _loading = false;
        _errorText = 'Die Verse konnten nicht geladen werden.';
      });
    }
  }

  Future<void> _submit() async {
    if (_elb85) {
      if (_loading || _availableVerses.isEmpty) return;
      setState(() {
        _submitting = true;
        _errorText = null;
      });
      final reference = BibleReference(
        bookId: _bookId,
        startChapter: _chapter,
        startVerse: _verseFrom,
        endChapter: _chapter,
        endVerse: _verseTo,
        displayText: '',
      );
      final normalizedReference = BibleReference(
        bookId: reference.bookId,
        startChapter: reference.startChapter,
        startVerse: reference.startVerse,
        endChapter: reference.endChapter,
        endVerse: reference.endVerse,
        displayText: formatBibleReference(reference),
      );
      try {
        final passage = await widget.provider.getPassage(
          normalizedReference,
          'elb85',
        );
        if (!mounted) return;
        if (passage == null) {
          setState(() {
            _submitting = false;
            _errorText = 'Der ausgewählte Bibeltext wurde nicht gefunden.';
          });
          return;
        }
        final range = _verseFrom == _verseTo
            ? '$_verseFrom'
            : '$_verseFrom-$_verseTo';
        Navigator.of(context).pop(
          _BibleReferenceRequest(
            text:
                '${passage.text} '
                '${BibleBookCatalog.labelFor(_bookId)} $_chapter: $range',
          ),
        );
      } on Object catch (_) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _errorText = 'Der Bibeltext konnte nicht eingefügt werden.';
        });
      }
      return;
    }
    final imported = BibleTextImporter().import(_textController.text);
    if (imported == null) {
      setState(() {
        _errorText = _textController.text.trim().isEmpty
            ? 'Bitte zuerst den kopierten Bibeltext einfügen.'
            : 'Keine Versnummern erkannt. Bitte den Text einschließlich '
                  'Versnummern kopieren.';
      });
      return;
    }
    Navigator.of(context).pop(
      _BibleReferenceRequest(
        text: imported.withReference(
          book: BibleBookCatalog.labelFor(_bookId),
          chapter: _chapter,
        ),
      ),
    );
  }

  void _selectBook(String value) {
    if (_elb85) {
      unawaited(_loadBook(value));
    } else {
      setState(() => _bookId = value);
    }
  }

  void _selectChapter(int value) {
    if (_elb85) {
      unawaited(_loadChapter(value));
    } else {
      setState(() => _chapter = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dropdownStyle = TextStyle(
      fontFamily: AppTypography.ui,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: scheme.onSurface,
    );
    final chapterOptions = _elb85
        ? _availableChapters
        : List<int>.generate(150, (index) => index + 1);
    return Material(
      color: scheme.surfaceContainerLow,
      elevation: 5,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        key: const Key('bible-reference-dialog'),
        width: 430,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'BIBELTEXT EINFÜGEN',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.42),
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: TextButton(
                    key: const Key('elb85-mode'),
                    onPressed: _toggleElb85,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurface,
                      backgroundColor: _elb85
                          ? scheme.primaryContainer
                          : Colors.transparent,
                      side: BorderSide(color: scheme.outlineVariant),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(
                        fontFamily: AppTypography.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('ELB85'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!_elb85) ...[
              TextField(
                key: const Key('bible-text-field'),
                controller: _textController,
                autofocus: true,
                minLines: 5,
                maxLines: 8,
                style: dropdownStyle.copyWith(height: 1.45),
                decoration: const InputDecoration(
                  hintText:
                      'Bibeltext einschließlich Versnummern hier '
                      'einfügen …',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ).copyWith(errorText: _errorText),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Versnummern und Anmerkungen in [Klammern] werden automatisch '
                'entfernt.',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.48),
                ),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TypeaheadMenuRegion<String>(
                    options: BibleBookCatalog.all
                        .map((book) => book.id)
                        .toList(growable: false),
                    labelFor: BibleBookCatalog.labelFor,
                    onSelected: _selectBook,
                    builder: (context, typeahead) =>
                        DropdownButtonFormField<String>(
                          key: const Key('bible-book-field'),
                          initialValue: _bookId,
                          isExpanded: true,
                          dropdownColor: scheme.surfaceContainerLowest,
                          iconEnabledColor: scheme.onSurfaceVariant,
                          style: dropdownStyle,
                          decoration: const InputDecoration(
                            labelText: 'Buch',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                          ),
                          items: [
                            for (final book in BibleBookCatalog.all)
                              DropdownMenuItem(
                                value: book.id,
                                child: Text(
                                  book.label,
                                  style: dropdownStyle,
                                ),
                              ),
                          ],
                          onTap: typeahead.open,
                          onChanged: (value) {
                            typeahead.close();
                            if (value != null) _selectBook(value);
                          },
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TypeaheadMenuRegion<int>(
                    options: chapterOptions,
                    labelFor: (chapter) => '$chapter',
                    onSelected: _selectChapter,
                    builder: (context, typeahead) =>
                        DropdownButtonFormField<int>(
                          key: const Key('bible-chapter-field'),
                          initialValue: _chapter,
                          isExpanded: true,
                          menuMaxHeight: 320,
                          dropdownColor: scheme.surfaceContainerLowest,
                          iconEnabledColor: scheme.onSurfaceVariant,
                          style: dropdownStyle,
                          decoration: const InputDecoration(
                            labelText: 'Kapitel',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                          ),
                          items: [
                            for (final chapter in chapterOptions)
                              DropdownMenuItem(
                                value: chapter,
                                child: Text(
                                  '$chapter',
                                  style: dropdownStyle,
                                ),
                              ),
                          ],
                          onTap: typeahead.open,
                          onChanged: (value) {
                            typeahead.close();
                            if (value != null) _selectChapter(value);
                          },
                        ),
                  ),
                ),
              ],
            ),
            if (_elb85) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BibleNumberDropdown(
                      key: const Key('bible-verse-from-field'),
                      label: 'Vers von',
                      value: _availableVerses.contains(_verseFrom)
                          ? _verseFrom
                          : null,
                      values: _availableVerses,
                      style: dropdownStyle,
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _verseFrom = value;
                          if (_verseTo < value) _verseTo = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BibleNumberDropdown(
                      key: const Key('bible-verse-to-field'),
                      label: 'Vers bis',
                      value: _availableVerses.contains(_verseTo)
                          ? _verseTo
                          : null,
                      values: _availableVerses
                          .where((verse) => verse >= _verseFrom)
                          .toList(growable: false),
                      style: dropdownStyle,
                      onChanged: (value) {
                        if (value != null) setState(() => _verseTo = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (_elb85 && _errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: FilledButton(
                key: const Key('insert-bible-reference'),
                onPressed: _loading || _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.surfaceContainer,
                  foregroundColor: scheme.onSurface,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                    fontFamily: AppTypography.ui,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: _loading || _submitting
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : Text(
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
}

class _BibleNumberDropdown extends StatelessWidget {
  const _BibleNumberDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.style,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int? value;
  final List<int> values;
  final TextStyle style;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TypeaheadMenuRegion<int>(
      options: values,
      labelFor: (number) => '$number',
      onSelected: onChanged,
      builder: (context, typeahead) => DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        menuMaxHeight: 320,
        dropdownColor: scheme.surfaceContainerLowest,
        iconEnabledColor: scheme.onSurfaceVariant,
        style: style,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
        ),
        items: [
          for (final number in values)
            DropdownMenuItem(
              value: number,
              child: Text('$number', style: style),
            ),
        ],
        onTap: values.isEmpty ? null : typeahead.open,
        onChanged: values.isEmpty
            ? null
            : (value) {
                typeahead.close();
                onChanged(value);
              },
      ),
    );
  }
}

class _OutlineBibleReferenceFields extends StatelessWidget {
  const _OutlineBibleReferenceFields({
    required this.sermon,
    required this.allowMultiple,
    required this.onChanged,
    required this.onReferenceTextChanged,
  });

  final Sermon sermon;
  final bool allowMultiple;
  final ValueChanged<Sermon> onChanged;
  final ValueChanged<String> onReferenceTextChanged;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OutlineBookDropdown(
          reference: sermon.primaryBibleReference,
          allowMultiple: allowMultiple,
          onCleared: () => onChanged(
            sermon.copyWith(clearPrimaryBibleReference: true),
          ),
          onChanged: (reference) => onChanged(
            sermon.copyWith(primaryBibleReference: reference),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 96,
          child: _BareTextField(
            key: ValueKey('reference-${sermon.id}'),
            initialValue: sermon.primaryBibleReference == null
                ? ''
                : _referenceWithoutBook(sermon.primaryBibleReference!),
            hintText: '18:16–33',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(
                alpha: dark ? 0.72 : 0.62,
              ),
              fontFamily: AppTypography.editor,
              fontSize: 12.8,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            onChanged: (value) {
              onReferenceTextChanged(value);
              final book = sermon.primaryBibleReference?.bookId;
              if (book == null) return;
              final parsed = BibleReferenceParser().parsePassage(
                '${BibleBookCatalog.labelFor(book)} $value',
              );
              if (parsed != null) {
                onChanged(sermon.copyWith(primaryBibleReference: parsed));
              }
            },
          ),
        ),
      ],
    );
  }
}

class _OutlineBookDropdown extends StatelessWidget {
  const _OutlineBookDropdown({
    required this.reference,
    required this.allowMultiple,
    required this.onCleared,
    required this.onChanged,
  });

  final BibleReference? reference;
  final bool allowMultiple;
  final VoidCallback onCleared;
  final ValueChanged<BibleReference> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = [
      if (allowMultiple) _multipleBooksId,
      ...BibleBookCatalog.all.map((book) => book.id),
    ];
    String labelFor(String bookId) => bookId == _multipleBooksId
        ? 'Mehrere'
        : BibleBookCatalog.labelFor(bookId);
    void selectBook(String bookId) {
      if (bookId == _multipleBooksId) {
        onCleared();
        return;
      }
      final suffix = reference == null
          ? '1,1-1'
          : _referenceWithoutBook(reference!);
      final parsed = BibleReferenceParser().parsePassage(
        '${BibleBookCatalog.labelFor(bookId)} $suffix',
      );
      if (parsed != null) onChanged(parsed);
    }

    return TypeaheadMenuRegion<String>(
      options: values,
      labelFor: labelFor,
      onSelected: selectBook,
      builder: (context, typeahead) => PopupMenuButton<String>(
        tooltip: 'Buch auswählen',
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 8,
        offset: const Offset(0, 6),
        onOpened: typeahead.open,
        onCanceled: typeahead.close,
        onSelected: (value) {
          typeahead.close();
          selectBook(value);
        },
        itemBuilder: (context) => [
          if (allowMultiple)
            PopupMenuItem(
              value: _multipleBooksId,
              child: Text('Mehrere', style: _outlineMenuStyle(context)),
            ),
          for (final book in BibleBookCatalog.all)
            PopupMenuItem(
              value: book.id,
              child: Text(book.label, style: _outlineMenuStyle(context)),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (reference == null
                      ? allowMultiple
                            ? 'Mehrere'
                            : 'Buch'
                      : BibleBookCatalog.labelFor(reference!.bookId))
                  .toUpperCase(),
              style: _outlineContextStyle(context),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.46),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineSeriesDropdown extends StatelessWidget {
  const _OutlineSeriesDropdown({
    required this.current,
    required this.series,
    required this.onChanged,
  });

  final String? current;
  final List<SermonSeries> series;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        (current?.trim().isNotEmpty ?? false) &&
        current!.trim() != _unselectedSeriesId;
    final values = <String>{
      if (hasSelection) current!.trim(),
      ...series
          .map((item) => item.title.trim())
          .where((value) => value.isNotEmpty),
    }.toList(growable: false);
    return TypeaheadMenuRegion<String>(
      options: values,
      labelFor: (value) => value,
      onSelected: onChanged,
      builder: (context, typeahead) => PopupMenuButton<String>(
        tooltip: 'Vortragsreihe auswählen',
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 8,
        offset: const Offset(0, 6),
        onOpened: typeahead.open,
        onCanceled: typeahead.close,
        onSelected: (value) {
          typeahead.close();
          onChanged(value);
        },
        itemBuilder: (context) => [
          for (final value in values)
            PopupMenuItem(
              value: value,
              child: Text(value, style: _outlineMenuStyle(context)),
            ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hasSelection ? current!.trim().toUpperCase() : 'REIHE AUSWÄHLEN',
              style: _outlineContextStyle(context),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronDown,
              size: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.46),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutlineHairline extends StatelessWidget {
  const _OutlineHairline();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: SizedBox(
      width: double.infinity,
      height: 1,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
  );
}

class _BareTextField extends StatelessWidget {
  const _BareTextField({
    required this.initialValue,
    required this.hintText,
    required this.style,
    required this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.inputFormatters,
    super.key,
  });

  final String initialValue;
  final String hintText;
  final TextStyle style;
  final ValueChanged<String> onChanged;
  final int? minLines;
  final int? maxLines;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    final historyScope = _BlockSelectionScope.maybeOf(context);
    final field = TextFormField(
      initialValue: initialValue,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType:
          keyboardType ??
          (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      inputFormatters: inputFormatters,
      textAlign: textAlign,
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
      onChanged: onChanged,
    );
    if (historyScope == null) return field;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyZ &&
            isPrimaryShortcutPressed) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            historyScope.onRedo();
          } else {
            historyScope.onUndo();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: field,
    );
  }
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? scheme.surfaceContainer.withValues(alpha: 0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: AppTypography.ui,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1.5,
            letterSpacing: 0.6,
            color: scheme.onSurface.withValues(alpha: selected ? 0.78 : 0.26),
          ),
        ),
      ),
    );
  }
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
    this.onDoubleTap,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
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

class _SermonModuleTree extends StatelessWidget {
  const _SermonModuleTree({
    required this.modules,
    required this.activeModuleIds,
    required this.onSelect,
    required this.onAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRename,
    required this.onLink,
    required this.onMove,
    required this.onUnlink,
  });

  final List<SermonModule> modules;
  final Set<String> activeModuleIds;
  final ValueChanged<String> onSelect;
  final ValueChanged<SermonModuleKind> onAdd;
  final ValueChanged<String> onDuplicate;
  final ValueChanged<String> onDelete;
  final void Function(String moduleId, String title) onRename;
  final void Function(String sourceModuleId, String targetModuleId) onLink;
  final void Function(String moduleId, int targetIndex) onMove;
  final ValueChanged<String> onUnlink;

  @override
  Widget build(BuildContext context) {
    final ordered = _orderModulesForTree(modules);
    final linkedBefore = [
      for (var index = 0; index < ordered.length; index++)
        index > 0 &&
            ordered[index].linkGroupId != null &&
            ordered[index].linkGroupId == ordered[index - 1].linkGroupId &&
            _moduleVersionRoot(ordered[index]) !=
                _moduleVersionRoot(ordered[index - 1]),
    ];
    final olderVersionRows = [
      for (var index = 0; index < ordered.length; index++)
        index > 0 &&
            _moduleVersionRoot(ordered[index]) ==
                _moduleVersionRoot(ordered[index - 1]),
    ];
    final groupGapBefore = [
      for (var index = 0; index < ordered.length; index++)
        index > 0 &&
            !(ordered[index].linkGroupId != null &&
                ordered[index].linkGroupId == ordered[index - 1].linkGroupId) &&
            _moduleVersionRoot(ordered[index]) !=
                _moduleVersionRoot(ordered[index - 1]),
    ];
    final compactRows = [
      for (final module in ordered) module.linkGroupId != null,
      false,
    ];
    final lineColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2);
    return CustomPaint(
      key: const Key('sermon-module-tree'),
      painter: _SermonModuleTreePainter(
        itemCount: ordered.length + 1,
        linkedBefore: linkedBefore,
        groupGapBefore: [...groupGapBefore, true],
        compactRows: compactRows,
        branchRows: [...olderVersionRows.map((older) => !older), true],
        leadingGap: _moduleTreeLeadingDropHeight,
        color: lineColor,
      ),
      child: Column(
        children: [
          _SermonModulePositionDropZone(
            key: const Key('sermon-module-position-start'),
            height: _moduleTreeLeadingDropHeight,
            onAccept: (moduleId) => onMove(moduleId, 0),
          ),
          for (var index = 0; index < ordered.length; index++) ...[
            if (groupGapBefore[index])
              _SermonModulePositionDropZone(
                key: Key(
                  'sermon-module-position-before-${ordered[index].id}',
                ),
                height: _moduleTreeGroupGap,
                onAccept: (moduleId) => onMove(moduleId, index),
              ),
            if (linkedBefore[index])
              _SermonModuleLinkConnector(
                moduleId: ordered[index].id,
                onUnlink: () => onUnlink(ordered[index].id),
              ),
            _SermonModuleTreeItem(
              module: ordered[index],
              primaryOfKind: ordered
                  .take(index)
                  .every(
                    (module) => module.kind != ordered[index].kind,
                  ),
              active: activeModuleIds.contains(ordered[index].id),
              versioned:
                  modules
                      .where(
                        (module) =>
                            _moduleVersionRoot(module) ==
                            _moduleVersionRoot(ordered[index]),
                      )
                      .length >
                  1,
              hasNewerVersion: olderVersionRows[index],
              hasOlderVersion:
                  index + 1 < ordered.length &&
                  _moduleVersionRoot(ordered[index + 1]) ==
                      _moduleVersionRoot(ordered[index]),
              compact: compactRows[index],
              onTap: () => onSelect(ordered[index].id),
              onDuplicate: () => onDuplicate(ordered[index].id),
              onDelete: () => onDelete(ordered[index].id),
              onRename: (title) => onRename(ordered[index].id, title),
              onLink: (sourceId) => onLink(sourceId, ordered[index].id),
            ),
          ],
          _SermonModulePositionDropZone(
            key: const Key('sermon-module-position-end'),
            height: _moduleTreeGroupGap,
            onAccept: (moduleId) => onMove(moduleId, ordered.length),
          ),
          PopupMenuButton<SermonModuleKind>(
            key: const Key('sermon-module-add'),
            tooltip: 'Inhalt hinzufügen',
            padding: EdgeInsets.zero,
            onSelected: onAdd,
            itemBuilder: (context) => [
              for (final kind in SermonModuleKind.values)
                PopupMenuItem(
                  value: kind,
                  child: Text(
                    '${switch (kind) {
                      SermonModuleKind.notes => 'Notizen',
                      SermonModuleKind.script => 'Skript',
                      SermonModuleKind.presentation => 'Präsentation',
                    }} hinzufügen',
                  ),
                ),
            ],
            child: const _SermonModuleAddItem(),
          ),
        ],
      ),
    );
  }
}

List<SermonModule> _orderModulesForTree(List<SermonModule> modules) {
  final firstOrderByGroup = <String, int>{};
  final firstOrderByVersionRoot = <String, int>{};
  for (final module in modules) {
    final group = module.linkGroupId;
    if (group != null) {
      firstOrderByGroup.update(
        group,
        (value) => math.min(value, module.sortOrder),
        ifAbsent: () => module.sortOrder,
      );
    }
    final versionRoot = _moduleVersionRoot(module);
    firstOrderByVersionRoot.update(
      versionRoot,
      (value) => math.min(value, module.sortOrder),
      ifAbsent: () => module.sortOrder,
    );
  }
  int kindOrder(SermonModuleKind kind) => switch (kind) {
    SermonModuleKind.notes => 0,
    SermonModuleKind.script => 1,
    SermonModuleKind.presentation => 2,
  };

  return [...modules]..sort((left, right) {
    final leftOrder = left.linkGroupId == null
        ? left.sortOrder
        : firstOrderByGroup[left.linkGroupId]!;
    final rightOrder = right.linkGroupId == null
        ? right.sortOrder
        : firstOrderByGroup[right.linkGroupId]!;
    final blockOrder = leftOrder.compareTo(rightOrder);
    if (blockOrder != 0) return blockOrder;
    if (left.linkGroupId != null && left.linkGroupId == right.linkGroupId) {
      final byKind = kindOrder(left.kind).compareTo(kindOrder(right.kind));
      if (byKind != 0) return byKind;
    }
    final leftVersionRoot = _moduleVersionRoot(left);
    final rightVersionRoot = _moduleVersionRoot(right);
    final byVersionFamily = firstOrderByVersionRoot[leftVersionRoot]!.compareTo(
      firstOrderByVersionRoot[rightVersionRoot]!,
    );
    if (byVersionFamily != 0) return byVersionFamily;
    if (leftVersionRoot == rightVersionRoot) {
      final byRevision = right.revision.compareTo(left.revision);
      if (byRevision != 0) return byRevision;
    }
    final bySort = left.sortOrder.compareTo(right.sortOrder);
    return bySort != 0 ? bySort : left.id.compareTo(right.id);
  });
}

String _moduleVersionRoot(SermonModule module) =>
    module.versionRootId ?? module.id;

class _ModuleDragData {
  const _ModuleDragData(this.moduleId);

  final String moduleId;
}

class _SermonModuleTreeItem extends StatelessWidget {
  const _SermonModuleTreeItem({
    required this.module,
    required this.primaryOfKind,
    required this.active,
    required this.versioned,
    required this.hasNewerVersion,
    required this.hasOlderVersion,
    required this.compact,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRename,
    required this.onLink,
  });

  final SermonModule module;
  final bool primaryOfKind;
  final bool active;
  final bool versioned;
  final bool hasNewerVersion;
  final bool hasOlderVersion;
  final bool compact;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<String> onRename;
  final ValueChanged<String> onLink;

  @override
  Widget build(BuildContext context) => DragTarget<_ModuleDragData>(
    key: Key('sermon-module-drop-${module.id}'),
    onWillAcceptWithDetails: (details) => details.data.moduleId != module.id,
    onAcceptWithDetails: (details) => onLink(details.data.moduleId),
    builder: (context, candidates, rejected) {
      final item = _buildItem(
        context,
        dropHighlighted: candidates.isNotEmpty,
      );
      return Draggable<_ModuleDragData>(
        key: Key('sermon-module-drag-${module.id}'),
        data: _ModuleDragData(module.id),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 150,
            child: Opacity(opacity: 0.9, child: _buildItem(context)),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: item),
        child: item,
      );
    },
  );

  Widget _buildItem(
    BuildContext context, {
    bool dropHighlighted = false,
  }) {
    final color = Theme.of(context).colorScheme.onSurface;
    return Semantics(
      key: Key(
        primaryOfKind
            ? 'sermon-module-${module.kind.name}'
            : 'sermon-module-${module.id}',
      ),
      selected: active,
      child: SizedBox(
        height: compact ? _moduleTreeCompactRowHeight : _moduleTreeRowHeight,
        child: Row(
          children: [
            const SizedBox(width: 20),
            if (hasNewerVersion)
              _SermonModuleVersionBranch(
                hasNewer: hasNewerVersion,
                hasOlder: hasOlderVersion,
              ),
            Expanded(
              child: InkWell(
                onTap: onTap,
                onDoubleTap: () => _showRenameDialog(context),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  height: compact ? 21 : 25,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: dropHighlighted
                        ? Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: 0.45)
                        : active
                        ? color.withValues(alpha: 0.055)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        switch (module.kind) {
                          SermonModuleKind.notes => LucideIcons.notebookPen,
                          SermonModuleKind.script => LucideIcons.scrollText,
                          SermonModuleKind.presentation =>
                            LucideIcons.galleryHorizontal,
                        },
                        size: 11,
                        color: color.withValues(alpha: active ? 0.72 : 0.38),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _moduleDisplayTitle(module),
                            key: Key(
                              'sermon-module-title-${module.kind.name}',
                            ),
                            maxLines: 1,
                            softWrap: false,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  fontSize: 10.8,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: color.withValues(
                                    alpha: active ? 0.76 : 0.48,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      if (versioned) ...[
                        const SizedBox(width: 4),
                        Text(
                          'V${module.revision}',
                          key: Key('sermon-module-version-${module.id}'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.35,
                                color: color.withValues(
                                  alpha: active ? 0.5 : 0.3,
                                ),
                              ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key(
                primaryOfKind
                    ? 'duplicate-sermon-module-${module.kind.name}'
                    : 'duplicate-sermon-module-${module.id}',
              ),
              tooltip: '${_moduleDisplayTitle(module)} als Version duplizieren',
              onPressed: onDuplicate,
              icon: const Icon(LucideIcons.copyPlus, size: 10),
              style: IconButton.styleFrom(
                minimumSize: const Size(18, 23),
                maximumSize: const Size(18, 23),
                padding: EdgeInsets.zero,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            IconButton(
              key: Key(
                primaryOfKind
                    ? 'delete-sermon-module-${module.kind.name}'
                    : 'delete-sermon-module-${module.id}',
              ),
              tooltip: '${_moduleDisplayTitle(module)} löschen',
              onPressed: onDelete,
              icon: const Icon(LucideIcons.trash2, size: 10),
              style: IconButton.styleFrom(
                minimumSize: const Size(18, 23),
                maximumSize: const Size(18, 23),
                padding: EdgeInsets.zero,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final controller = TextEditingController(text: module.title);
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: Key('rename-sermon-module-${module.id}'),
        title: const Text('Inhalt umbenennen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ohne Namen wird das Datum angezeigt',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null) onRename(title.trim());
  }
}

class _SermonModuleVersionBranch extends StatelessWidget {
  const _SermonModuleVersionBranch({
    required this.hasNewer,
    required this.hasOlder,
  });

  final bool hasNewer;
  final bool hasOlder;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(11, 29),
    painter: _SermonModuleVersionBranchPainter(
      hasNewer: hasNewer,
      hasOlder: hasOlder,
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.22),
    ),
  );
}

class _SermonModuleVersionBranchPainter extends CustomPainter {
  const _SermonModuleVersionBranchPainter({
    required this.hasNewer,
    required this.hasOlder,
    required this.color,
  });

  final bool hasNewer;
  final bool hasOlder;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final center = size.height / 2;
    if (hasNewer) canvas.drawLine(const Offset(1, 0), Offset(1, center), paint);
    if (hasOlder) {
      canvas.drawLine(Offset(1, center), Offset(1, size.height), paint);
    }
    canvas.drawLine(Offset(1, center), Offset(size.width - 1, center), paint);
  }

  @override
  bool shouldRepaint(covariant _SermonModuleVersionBranchPainter oldDelegate) =>
      hasNewer != oldDelegate.hasNewer ||
      hasOlder != oldDelegate.hasOlder ||
      color != oldDelegate.color;
}

class _SermonModuleLinkConnector extends StatelessWidget {
  const _SermonModuleLinkConnector({
    required this.moduleId,
    required this.onUnlink,
  });

  final String moduleId;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _moduleTreeLinkHeight,
    child: Row(
      children: [
        const SizedBox(width: 20),
        IconButton(
          key: Key('unlink-sermon-module-$moduleId'),
          tooltip: 'Verknüpfung aufheben',
          onPressed: onUnlink,
          padding: EdgeInsets.zero,
          iconSize: 8,
          constraints: const BoxConstraints.tightFor(
            width: 18,
            height: _moduleTreeLinkHeight,
          ),
          icon: const Icon(LucideIcons.link2),
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.42),
        ),
      ],
    ),
  );
}

class _SermonModulePositionDropZone extends StatelessWidget {
  const _SermonModulePositionDropZone({
    required super.key,
    required this.height,
    required this.onAccept,
  });

  final double height;
  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) => DragTarget<_ModuleDragData>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) => onAccept(details.data.moduleId),
    builder: (context, candidates, rejected) => SizedBox(
      height: height,
      child: Center(
        child: AnimatedContainer(
          duration: AppMotion.quick,
          height: candidates.isEmpty ? 1 : 2,
          margin: const EdgeInsets.only(left: 20, right: 4),
          decoration: BoxDecoration(
            color: candidates.isEmpty
                ? Colors.transparent
                : Theme.of(context).colorScheme.primary.withValues(alpha: .62),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    ),
  );
}

class _SermonModuleAddItem extends StatelessWidget {
  const _SermonModuleAddItem();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      height: 29,
      child: Row(
        children: [
          const SizedBox(width: 20),
          Icon(LucideIcons.plus, size: 11, color: color.withValues(alpha: 0.4)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Hinzufügen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10.8,
                fontStyle: FontStyle.italic,
                color: color.withValues(alpha: 0.46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyWorkspacePane extends StatelessWidget {
  const _EmptyWorkspacePane({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Center(
    child: TextButton.icon(
      key: const Key('open-empty-workspace-pane'),
      onPressed: onOpen,
      icon: const Icon(LucideIcons.plus, size: 14),
      label: const Text('Inhalt öffnen'),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: .55),
        textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontFamily: AppTypography.editor,
          fontStyle: FontStyle.italic,
        ),
      ),
    ),
  );
}

class _SplitWorkspaceDropTarget extends StatefulWidget {
  const _SplitWorkspaceDropTarget({
    required this.child,
    required this.onActivatePane,
    required this.onDrop,
  });

  final Widget child;
  final ValueChanged<int> onActivatePane;
  final void Function(String moduleId, int paneIndex) onDrop;

  @override
  State<_SplitWorkspaceDropTarget> createState() =>
      _SplitWorkspaceDropTargetState();
}

class _SplitWorkspaceDropTargetState extends State<_SplitWorkspaceDropTarget> {
  final GlobalKey _boundsKey = GlobalKey();
  int? _hoveredPane;

  int _paneAt(Offset globalPosition) {
    final box = _boundsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0;
    return box.globalToLocal(globalPosition).dx < box.size.width / 2 ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) => DragTarget<_ModuleDragData>(
    onWillAcceptWithDetails: (_) => true,
    onMove: (details) {
      final pane = _paneAt(details.offset);
      if (_hoveredPane != pane) setState(() => _hoveredPane = pane);
    },
    onLeave: (_) => setState(() => _hoveredPane = null),
    onAcceptWithDetails: (details) {
      final pane = _paneAt(details.offset);
      setState(() => _hoveredPane = null);
      widget.onDrop(details.data.moduleId, pane);
    },
    builder: (context, candidates, rejected) => Listener(
      key: _boundsKey,
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => widget.onActivatePane(_paneAt(event.position)),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          const Positioned.fill(
            child: IgnorePointer(
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox.expand(
                      key: Key('workspace-pane-drop-0'),
                    ),
                  ),
                  Expanded(
                    child: SizedBox.expand(
                      key: Key('workspace-pane-drop-1'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_hoveredPane case final pane?)
            Positioned.fill(
              child: Align(
                alignment: pane == 0
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: .5,
                  heightFactor: 1,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: .045),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: .45),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _SermonModuleTreePainter extends CustomPainter {
  const _SermonModuleTreePainter({
    required this.itemCount,
    required this.linkedBefore,
    required this.groupGapBefore,
    required this.compactRows,
    required this.branchRows,
    required this.leadingGap,
    required this.color,
  });

  final int itemCount;
  final List<bool> linkedBefore;
  final List<bool> groupGapBefore;
  final List<bool> compactRows;
  final List<bool> branchRows;
  final double leadingGap;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount == 0) return;
    const railX = 7.0;
    const branchEndX = 18.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final rowCenters = <double>[];
    var top = leadingGap;
    for (var index = 0; index < itemCount; index++) {
      if (index < groupGapBefore.length && groupGapBefore[index]) {
        top += _moduleTreeGroupGap;
      }
      if (index < linkedBefore.length && linkedBefore[index]) {
        top += _moduleTreeLinkHeight;
      }
      final rowHeight = index < compactRows.length && compactRows[index]
          ? _moduleTreeCompactRowHeight
          : _moduleTreeRowHeight;
      rowCenters.add(top + rowHeight / 2);
      top += rowHeight;
    }
    canvas.drawLine(
      const Offset(railX, 0),
      Offset(railX, rowCenters.last),
      paint,
    );
    for (var index = 0; index < rowCenters.length; index++) {
      if (index < branchRows.length && branchRows[index]) {
        final y = rowCenters[index];
        canvas.drawLine(Offset(railX, y), Offset(branchEndX, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SermonModuleTreePainter oldDelegate) =>
      itemCount != oldDelegate.itemCount ||
      !_sameBools(linkedBefore, oldDelegate.linkedBefore) ||
      !_sameBools(groupGapBefore, oldDelegate.groupGapBefore) ||
      !_sameBools(compactRows, oldDelegate.compactRows) ||
      !_sameBools(branchRows, oldDelegate.branchRows) ||
      color != oldDelegate.color;
}

const _moduleTreeRowHeight = 29.0;
const _moduleTreeCompactRowHeight = 23.0;
const _moduleTreeLinkHeight = 4.0;
const _moduleTreeGroupGap = 10.0;
const _moduleTreeLeadingDropHeight = 7.0;

bool _sameBools(List<bool> left, List<bool> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

WorkspaceView _workspaceViewForModule(SermonModuleKind kind) => switch (kind) {
  SermonModuleKind.notes => WorkspaceView.notes,
  SermonModuleKind.script => WorkspaceView.script,
  SermonModuleKind.presentation => WorkspaceView.presentation,
};

class _ModuleSplitView extends StatefulWidget {
  const _ModuleSplitView({
    required this.leftModuleId,
    required this.rightModuleId,
    required this.linked,
    required this.sharedHeadingIds,
    required this.leftKeys,
    required this.rightKeys,
    required this.left,
    required this.right,
    super.key,
  });

  final String leftModuleId;
  final String rightModuleId;
  final bool linked;
  final List<String> sharedHeadingIds;
  final Map<String, GlobalKey<_RichBlockFieldState>> leftKeys;
  final Map<String, GlobalKey<_RichBlockFieldState>> rightKeys;
  final Widget left;
  final Widget right;

  @override
  State<_ModuleSplitView> createState() => _ModuleSplitViewState();
}

class _ModuleSplitViewState extends State<_ModuleSplitView> {
  final ScrollController _leftController = ScrollController();
  final ScrollController _rightController = ScrollController();
  bool _synchronizing = false;

  @override
  void initState() {
    super.initState();
    _leftController.addListener(_syncFromLeft);
    _rightController.addListener(_syncFromRight);
  }

  @override
  void dispose() {
    _leftController
      ..removeListener(_syncFromLeft)
      ..dispose();
    _rightController
      ..removeListener(_syncFromRight)
      ..dispose();
    super.dispose();
  }

  void _syncFromLeft() => _scheduleSync(
    source: _leftController,
    target: _rightController,
    sourceKeys: widget.leftKeys,
    targetKeys: widget.rightKeys,
  );

  void _syncFromRight() => _scheduleSync(
    source: _rightController,
    target: _leftController,
    sourceKeys: widget.rightKeys,
    targetKeys: widget.leftKeys,
  );

  void _scheduleSync({
    required ScrollController source,
    required ScrollController target,
    required Map<String, GlobalKey<_RichBlockFieldState>> sourceKeys,
    required Map<String, GlobalKey<_RichBlockFieldState>> targetKeys,
  }) {
    if (!widget.linked || _synchronizing) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _synchronizing) return;
      _syncScroll(
        source: source,
        target: target,
        sourceKeys: sourceKeys,
        targetKeys: targetKeys,
      );
    });
  }

  void _syncScroll({
    required ScrollController source,
    required ScrollController target,
    required Map<String, GlobalKey<_RichBlockFieldState>> sourceKeys,
    required Map<String, GlobalKey<_RichBlockFieldState>> targetKeys,
  }) {
    if (!source.hasClients || !target.hasClients) return;
    double? desiredOffset;
    final sourceViewport = source.position.context.storageContext
        .findRenderObject();
    final targetViewport = target.position.context.storageContext
        .findRenderObject();
    if (sourceViewport is RenderBox && targetViewport is RenderBox) {
      final sourceTop = sourceViewport.localToGlobal(Offset.zero).dy;
      final targetTop = targetViewport.localToGlobal(Offset.zero).dy;
      String? sectionId;
      double? sourceHeadingY;
      for (final id in widget.sharedHeadingIds) {
        final box = sourceKeys[id]?.currentContext?.findRenderObject();
        if (box is! RenderBox) continue;
        final y = box.localToGlobal(Offset.zero).dy;
        if (y <= sourceTop + 80) {
          sectionId = id;
          sourceHeadingY = y;
        } else {
          break;
        }
      }
      if (sectionId != null && sourceHeadingY != null) {
        final targetBox = targetKeys[sectionId]?.currentContext
            ?.findRenderObject();
        if (targetBox is RenderBox) {
          final targetHeadingY = targetBox.localToGlobal(Offset.zero).dy;
          desiredOffset =
              target.offset +
              (targetHeadingY - targetTop) -
              (sourceHeadingY - sourceTop);
        }
      }
    }
    desiredOffset ??= source.position.maxScrollExtent <= 0
        ? 0
        : source.offset /
              source.position.maxScrollExtent *
              target.position.maxScrollExtent;
    final clamped = desiredOffset.clamp(
      target.position.minScrollExtent,
      target.position.maxScrollExtent,
    );
    if ((target.offset - clamped).abs() < 0.5) return;
    _synchronizing = true;
    target.jumpTo(clamped);
    _synchronizing = false;
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: SingleChildScrollView(
          key: Key('module-scroll-${widget.leftModuleId}'),
          controller: _leftController,
          child: widget.left,
        ),
      ),
      VerticalDivider(
        width: 1,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      Expanded(
        child: SingleChildScrollView(
          key: Key('module-scroll-${widget.rightModuleId}'),
          controller: _rightController,
          child: widget.right,
        ),
      ),
    ],
  );
}

SermonModuleKind? _moduleKindForView(WorkspaceView view) => switch (view) {
  WorkspaceView.notes => SermonModuleKind.notes,
  WorkspaceView.script => SermonModuleKind.script,
  WorkspaceView.presentation => SermonModuleKind.presentation,
  WorkspaceView.outline => null,
};

String _moduleLabel(SermonModuleKind kind) => switch (kind) {
  SermonModuleKind.notes => 'Notizen',
  SermonModuleKind.script => 'Skript',
  SermonModuleKind.presentation => 'Präsentation',
};

String _moduleDisplayTitle(SermonModule module) {
  final custom = module.title.trim();
  if (custom.isNotEmpty) return custom;
  final date = (module.createdAt ?? DateTime.now()).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}.${two(date.month)}.${two(date.year % 100)}';
}

DocumentBlock _cloneDocumentBlock(
  DocumentBlock block, {
  required String id,
  required DateTime now,
  required String Function() createNestedId,
}) {
  final json = Map<String, Object?>.from(block.toJson())
    ..['id'] = id
    ..['createdAt'] = now.toIso8601String()
    ..['updatedAt'] = now.toIso8601String();
  if (json['items'] case final List<Object?> items) {
    json['items'] = [
      for (final item in items)
        if (item is Map<String, Object?>)
          _cloneBulletItemJson(item, createNestedId),
    ];
  }
  return DocumentBlock.fromJson(json);
}

Map<String, Object?> _cloneBulletItemJson(
  Map<String, Object?> item,
  String Function() createId,
) {
  final clone = Map<String, Object?>.from(item)..['id'] = createId();
  if (clone['children'] case final List<Object?> children) {
    clone['children'] = [
      for (final child in children)
        if (child is Map<String, Object?>)
          _cloneBulletItemJson(child, createId),
    ];
  }
  return clone;
}

PresentationSlide _clonePresentationSlide(
  PresentationSlide slide, {
  required String id,
  required String? continuationGroupId,
}) {
  final json = Map<String, Object?>.from(slide.toJson())
    ..['id'] = id
    ..['continuationGroupId'] = continuationGroupId;
  return PresentationSlide.fromJson(json);
}

IconData _moduleIcon(SermonModuleKind kind) => switch (kind) {
  SermonModuleKind.notes => LucideIcons.notebookPen,
  SermonModuleKind.script => LucideIcons.scrollText,
  SermonModuleKind.presentation => LucideIcons.galleryHorizontal,
};

class _DialogChoiceTile extends StatelessWidget {
  const _DialogChoiceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.68),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                LucideIcons.chevronRight,
                size: 13,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.34),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryPill extends StatefulWidget {
  const _EntryPill({
    required this.sermon,
    required this.selected,
    required this.showSeriesSubtitle,
    required this.versionCount,
    required this.versionIndex,
    required this.onTap,
    required this.activeModuleIds,
    required this.onSelectModule,
    required this.onAddModule,
    required this.onDuplicateModule,
    required this.onDeleteModule,
    required this.onRenameModule,
    required this.onLinkModules,
    required this.onMoveModule,
    required this.onUnlinkModule,
    required this.onDuplicate,
    required this.onDelete,
    required this.onAttachVersion,
  });

  final Sermon sermon;
  final bool selected;
  final bool showSeriesSubtitle;
  final int versionCount;
  final int? versionIndex;
  final VoidCallback onTap;
  final Set<String> activeModuleIds;
  final ValueChanged<String> onSelectModule;
  final ValueChanged<SermonModuleKind> onAddModule;
  final ValueChanged<String> onDuplicateModule;
  final ValueChanged<String> onDeleteModule;
  final void Function(String moduleId, String title) onRenameModule;
  final void Function(String sourceModuleId, String targetModuleId)
  onLinkModules;
  final void Function(String moduleId, int targetIndex) onMoveModule;
  final ValueChanged<String> onUnlinkModule;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<String> onAttachVersion;

  @override
  State<_EntryPill> createState() => _EntryPillState();
}

class _EntryPillState extends State<_EntryPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => DragTarget<String>(
    key: Key('sermon-drop-${widget.sermon.id}'),
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) {
      if (details.data != widget.sermon.id) {
        widget.onAttachVersion(details.data);
      }
    },
    builder: (context, candidateData, rejectedData) {
      final pill = _buildPill(
        context,
        dropHighlighted: candidateData.isNotEmpty,
      );
      return Draggable<String>(
        key: Key('sermon-drag-${widget.sermon.id}'),
        data: widget.sermon.id,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: AppSizes.entryListWidth - 20,
            child: Opacity(opacity: 0.92, child: _buildPill(context)),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.28,
          child: _buildPill(context),
        ),
        child: pill,
      );
    },
  );

  Widget _buildPill(
    BuildContext context, {
    bool dropHighlighted = false,
  }) {
    final sermon = widget.sermon;
    final selected = widget.selected;
    final isVersion = widget.versionIndex != null;
    final contextLabel = [
      if (sermon.seriesPosition != null) 'Einheit ${sermon.seriesPosition}',
      if (sermon.primaryBibleReference != null)
        sermon.primaryBibleReference!.displayText,
    ].join(' · ');
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: EdgeInsets.only(
          left: isVersion ? 10 : 0,
          bottom: 2,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: isVersion
                ? Border(
                    left: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                    ),
                  )
                : null,
          ),
          child: InkWell(
            key: Key('sermon-${sermon.id}'),
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: dropHighlighted
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : selected
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : isVersion
                    ? Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLow.withValues(alpha: 0.32)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 42),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isVersion)
                              Text(
                                'VERSION ${widget.versionIndex}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.28),
                                    ),
                              )
                            else if (contextLabel.isNotEmpty)
                              Text(
                                contextLabel,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 10.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(
                                            alpha: selected ? 0.62 : 0.4,
                                          ),
                                    ),
                              ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    sermon.title.isEmpty
                                        ? 'Ohne Titel'
                                        : sermon.title,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          fontSize: 12.5,
                                          height: 1.25,
                                          fontWeight: selected
                                              ? FontWeight.w500
                                              : FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(
                                                alpha: selected
                                                    ? 1
                                                    : isVersion
                                                    ? 0.55
                                                    : 0.64,
                                              ),
                                          fontStyle: sermon.title.isEmpty
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                  ),
                                ),
                                if (!isVersion && widget.versionCount > 1) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '×${widget.versionCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          fontSize: 9.5,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.34),
                                        ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.showSeriesSubtitle &&
                                (sermon.seriesId?.trim().isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 3),
                              Text(
                                sermon.seriesId!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      height: 1.25,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(
                                            alpha: selected ? 0.5 : 0.34,
                                          ),
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 9),
                        _SermonModuleTree(
                          modules: sermon.document.effectiveModules,
                          activeModuleIds: widget.activeModuleIds,
                          onSelect: widget.onSelectModule,
                          onAdd: widget.onAddModule,
                          onDuplicate: widget.onDuplicateModule,
                          onDelete: widget.onDeleteModule,
                          onRename: widget.onRenameModule,
                          onLink: widget.onLinkModules,
                          onMove: widget.onMoveModule,
                          onUnlink: widget.onUnlinkModule,
                        ),
                      ],
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
                  Positioned(
                    right: 0,
                    top: 0,
                    child: AnimatedOpacity(
                      opacity: _hovered ? 1 : 0,
                      duration: AppMotion.quick,
                      child: IgnorePointer(
                        ignoring: !_hovered,
                        child: Row(
                          children: [
                            _TinyIconButton(
                              icon: LucideIcons.copyPlus,
                              tooltip: 'Duplizieren',
                              onPressed: widget.onDuplicate,
                              size: 10,
                            ),
                            _TinyIconButton(
                              icon: LucideIcons.trash2,
                              tooltip: 'Löschen',
                              onPressed: widget.onDelete,
                              size: 10,
                              destructive: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.size = 13,
    this.destructive = false,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final double size;
  final bool destructive;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: size),
      style: IconButton.styleFrom(
        minimumSize: const Size(28, 28),
        maximumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        foregroundColor: destructive
            ? Theme.of(context).colorScheme.error.withValues(alpha: 0.55)
            : selected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    ),
  );
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _CornerActionButton(
    key: const Key('feedback-button'),
    tooltip: 'Feedback geben',
    icon: LucideIcons.messageSquareText,
    onPressed: onPressed,
  );
}

class _OnboardingHelpButton extends StatelessWidget {
  const _OnboardingHelpButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => _CornerActionButton(
    key: const Key('onboarding-help-button'),
    tooltip: 'Sermonary kennenlernen',
    icon: LucideIcons.circleHelp,
    onPressed: onPressed,
  );
}

class _CornerActionButton extends StatelessWidget {
  const _CornerActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(38),
        maximumSize: const Size.square(38),
        padding: EdgeInsets.zero,
        backgroundColor: const Color(0xFF171715),
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
        shadowColor: Colors.black.withValues(alpha: 0.18),
        elevation: 3,
      ),
    ),
  );
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.service,
    required this.screenshotPicker,
    this.sermonTitle,
  });

  final LocalFeedbackService service;
  final FeedbackScreenshotPicker screenshotPicker;
  final String? sermonTitle;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  FeedbackCategory _category = FeedbackCategory.bug;
  XFile? _screenshot;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectScreenshot() async {
    try {
      final screenshot = await widget.screenshotPicker();
      if (screenshot == null || !mounted) return;
      await widget.service.validateScreenshot(screenshot.path);
      if (!mounted) return;
      setState(() {
        _screenshot = screenshot;
        _error = null;
      });
    } on FeedbackAttachmentException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'Der Screenshot konnte nicht geöffnet werden.',
        );
      }
    }
  }

  Future<void> _submit() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Bitte eine kurze Beschreibung eingeben.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final receipt = await widget.service.save(
        category: _category,
        description: description,
        sermonTitle: widget.sermonTitle,
        screenshotPath: _screenshot?.path,
      );
      if (mounted) Navigator.pop(context, receipt);
    } on FeedbackAttachmentException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            'Das Feedback konnte nicht gespeichert werden. Bitte erneut versuchen.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.2,
      color: scheme.onSurfaceVariant.withValues(alpha: 0.52),
    );
    return AlertDialog(
      key: const Key('feedback-dialog'),
      title: const Text('Feedback geben'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Das Feedback bleibt auf diesem Mac und wird nicht automatisch versendet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Text('ART DES FEEDBACKS', style: labelStyle),
              const SizedBox(height: 7),
              TypeaheadMenuRegion<FeedbackCategory>(
                options: FeedbackCategory.values,
                labelFor: (category) => category.label,
                onSelected: (category) => setState(() => _category = category),
                builder: (context, typeahead) =>
                    DropdownButtonFormField<FeedbackCategory>(
                      key: const Key('feedback-category'),
                      initialValue: _category,
                      isExpanded: true,
                      items: [
                        for (final category in FeedbackCategory.values)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.label),
                          ),
                      ],
                      onTap: typeahead.open,
                      onChanged: (category) {
                        typeahead.close();
                        if (category != null) {
                          setState(() => _category = category);
                        }
                      },
                    ),
              ),
              const SizedBox(height: 18),
              Text('KURZE BESCHREIBUNG', style: labelStyle),
              const SizedBox(height: 7),
              TextField(
                key: const Key('feedback-description'),
                controller: _descriptionController,
                autofocus: true,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  hintText:
                      'Was ist passiert oder welche Funktion fehlt? Wenn möglich: Was hast du unmittelbar davor gemacht?',
                  alignLabelWithHint: true,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 8),
              Text('SCREENSHOT (OPTIONAL)', style: labelStyle),
              const SizedBox(height: 7),
              if (_screenshot == null)
                OutlinedButton.icon(
                  key: const Key('feedback-attach-screenshot'),
                  onPressed: _saving ? null : _selectScreenshot,
                  icon: const Icon(LucideIcons.paperclip, size: 14),
                  label: const Text('Screenshot auswählen'),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(11, 7, 5, 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.image, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _screenshot!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        key: const Key('feedback-remove-screenshot'),
                        tooltip: 'Screenshot entfernen',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _screenshot = null),
                        icon: const Icon(LucideIcons.x, size: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'PNG, JPG/JPEG oder WebP · maximal 10 MB',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.52),
                ),
              ),
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  key: const Key('feedback-error'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          key: const Key('feedback-submit'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 15,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              : const Text('Lokal speichern'),
        ),
      ],
    );
  }
}

class _OnboardingOverlay extends StatefulWidget {
  const _OnboardingOverlay({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.targetKey,
    required this.onClose,
    required this.onNext,
  });

  final _OnboardingStep step;
  final int stepIndex;
  final int stepCount;
  final GlobalKey targetKey;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  State<_OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<_OnboardingOverlay> {
  bool _layoutReady = false;
  bool _measurementScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleLayoutMeasurement();
  }

  @override
  void didUpdateWidget(covariant _OnboardingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stepIndex != widget.stepIndex ||
        oldWidget.targetKey != widget.targetKey) {
      _layoutReady = false;
      _scheduleLayoutMeasurement();
    }
  }

  void _scheduleLayoutMeasurement() {
    if (_measurementScheduled) return;
    _measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measurementScheduled = false;
      if (!mounted) return;
      setState(() => _layoutReady = true);
    });
  }

  Rect? _targetRect(BuildContext context) {
    if (!_layoutReady) return null;
    final renderObject = widget.targetKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final safePadding = MediaQuery.paddingOf(context);
    final offset = renderObject.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      offset.dx - safePadding.left,
      offset.dy - safePadding.top,
      renderObject.size.width,
      renderObject.size.height,
    ).inflate(5);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final target = _targetRect(context);
      const cardWidth = 316.0;
      // Reserve enough height for wrapped German help text so the action row
      // never slips below the window near bottom-aligned targets.
      const estimatedCardHeight = 330.0;
      const margin = 18.0;
      double left;
      double top;
      if (target == null) {
        left = (constraints.maxWidth - cardWidth) / 2;
        top = (constraints.maxHeight - estimatedCardHeight) / 2;
      } else if (target.right + margin + cardWidth <= constraints.maxWidth) {
        left = target.right + margin;
        top = target.center.dy - estimatedCardHeight / 2;
      } else if (target.bottom + margin + estimatedCardHeight <=
          constraints.maxHeight) {
        left = target.center.dx - cardWidth / 2;
        top = target.bottom + margin;
      } else {
        left = target.center.dx - cardWidth / 2;
        top = target.top - margin - estimatedCardHeight;
      }
      left = left.clamp(18.0, constraints.maxWidth - cardWidth - 18.0);
      top = top.clamp(18.0, constraints.maxHeight - estimatedCardHeight - 18.0);

      return Stack(
        children: [
          const Positioned.fill(
            child: ModalBarrier(dismissible: false, color: Colors.transparent),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OnboardingSpotlightPainter(
                  target: target,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: cardWidth,
            child: _OnboardingCard(
              step: widget.step,
              stepIndex: widget.stepIndex,
              stepCount: widget.stepCount,
              onClose: widget.onClose,
              onNext: widget.onNext,
            ),
          ),
          if (target != null)
            Positioned.fromRect(
              rect: target,
              child: const IgnorePointer(
                child: SizedBox(key: Key('onboarding-highlight')),
              ),
            ),
        ],
      );
    },
  );
}

class _OnboardingSpotlightPainter extends CustomPainter {
  const _OnboardingSpotlightPainter({required this.target, required this.dark});

  final Rect? target;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final spotlight = Path();
    if (target != null) {
      spotlight.addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(7)),
      );
    }
    final shade = target == null
        ? full
        : Path.combine(PathOperation.difference, full, spotlight);
    canvas.drawPath(
      shade,
      Paint()
        ..color = Colors.black.withValues(alpha: dark ? 0.62 : 0.48)
        ..style = PaintingStyle.fill,
    );
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(7)),
        Paint()
          ..color = const Color(0xFFC7AD91).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OnboardingSpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.dark != dark;
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.step,
    required this.stepIndex,
    required this.stepCount,
    required this.onClose,
    required this.onNext,
  });

  final _OnboardingStep step;
  final int stepIndex;
  final int stepCount;
  final VoidCallback onClose;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('onboarding-card'),
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${stepIndex + 1} / $stepCount',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  letterSpacing: 1.1,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.38),
                ),
              ),
              const Spacer(),
              IconButton(
                key: const Key('onboarding-close'),
                tooltip: 'Einführung schließen',
                onPressed: onClose,
                icon: const Icon(LucideIcons.x, size: 12),
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(24),
                  maximumSize: const Size.square(24),
                  padding: EdgeInsets.zero,
                  foregroundColor: scheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            step.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontFamily: AppTypography.editor,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              height: 1.48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var index = 0; index < stepCount; index++) ...[
                AnimatedContainer(
                  duration: AppMotion.quick,
                  width: index == stepIndex ? 15 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: index == stepIndex
                        ? scheme.onSurface.withValues(alpha: 0.55)
                        : scheme.onSurface.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (index < stepCount - 1) const SizedBox(width: 4),
              ],
              const Spacer(),
              TextButton(
                key: const Key('onboarding-next'),
                onPressed: onNext,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  foregroundColor: scheme.onSurface,
                  backgroundColor: scheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: Text(
                  stepIndex == stepCount - 1 ? 'Fertig' : 'Weiter',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewButton extends StatelessWidget {
  const _ViewButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    super.key,
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

class _ExportMenuItem extends StatelessWidget {
  const _ExportMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 14,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _ExportMenuSectionLabel extends StatelessWidget {
  const _ExportMenuSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.1,
      color: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.48),
    ),
  );
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.italic = false,
    this.selected = false,
    super.key,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool italic;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
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
                  color:
                      Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(
                        alpha: selected ? 1 : 0.55,
                      ),
                ),
              ),
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
  const _EmptyWorkspace({
    required this.onCreate,
    required this.label,
    required this.showBackground,
  });

  final VoidCallback onCreate;
  final String label;
  final bool showBackground;

  Widget _button(BuildContext context) => TextButton(
    onPressed: onCreate,
    child: Text(
      label,
      style: _prominentWorkspaceActionTextStyle(context),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!showBackground) return Center(child: _button(context));
    return DecoratedBox(
      key: const Key('start-screen-background'),
      decoration: _outlineBackgroundDecoration(
        'generic1',
        dark: Theme.of(context).brightness == Brightness.dark,
      ),
      child: Center(
        child: _ProminentWorkspaceActionSurface(
          decorationKey: const Key('start-screen-action-background'),
          child: _button(context),
        ),
      ),
    );
  }
}

TextStyle _prominentWorkspaceActionTextStyle(BuildContext context) => TextStyle(
  fontFamily: AppTypography.editor,
  fontStyle: FontStyle.italic,
  color: Theme.of(
    context,
  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
);

class _ProminentWorkspaceActionSurface extends StatelessWidget {
  const _ProminentWorkspaceActionSurface({
    required this.child,
    this.decorationKey,
  });

  final Widget child;
  final Key? decorationKey;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: decorationKey,
      decoration: BoxDecoration(
        color: dark
            ? const Color(0xFF11110F).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.92),
        border: Border.all(
          color: dark
              ? scheme.onSurface.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.7),
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            offset: Offset(0, 8),
            blurRadius: 28,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: child,
      ),
    );
  }
}

class _DocumentSegment {
  _DocumentSegment({
    List<HeadingBlock>? headings,
    List<DocumentBlock>? script,
    List<NoteBlock>? notes,
  }) : headings = headings ?? <HeadingBlock>[],
       script = script ?? <DocumentBlock>[],
       notes = notes ?? <NoteBlock>[];

  final List<HeadingBlock> headings;
  final List<DocumentBlock> script;
  final List<NoteBlock> notes;

  HeadingBlock? get heading => headings.lastOrNull;
  bool get hasContent => script.isNotEmpty || notes.isNotEmpty;
  bool get isEmpty => headings.isEmpty && !hasContent;
  bool contains(String? blockId) =>
      blockId != null &&
      (headings.any((block) => block.id == blockId) ||
          script.any((block) => block.id == blockId) ||
          notes.any((block) => block.id == blockId));
}

class _LinkedTextSegment {
  const _LinkedTextSegment({
    required this.headings,
    required this.left,
    required this.right,
  });

  final List<HeadingBlock> headings;
  final List<DocumentBlock> left;
  final List<DocumentBlock> right;

  HeadingBlock? get heading => headings.lastOrNull;
}

List<_LinkedTextSegment> _linkedTextSegments(
  SermonDocument document,
  SermonModule left,
  SermonModule right,
) {
  final byId = {for (final block in document.blocks) block.id: block};
  final sharedHeadingIds = left.blockIds
      .where(right.blockIds.contains)
      .where((id) => byId[id] is HeadingBlock)
      .toList(growable: false);

  List<DocumentBlock> between(
    SermonModule module,
    String? previousHeadingId,
    String? nextHeadingId,
  ) {
    final start = previousHeadingId == null
        ? 0
        : module.blockIds.indexOf(previousHeadingId) + 1;
    final foundEnd = nextHeadingId == null
        ? module.blockIds.length
        : module.blockIds.indexOf(nextHeadingId);
    final end = foundEnd < 0 ? module.blockIds.length : foundEnd;
    if (start < 0 || start > end) return const [];
    return module.blockIds
        .sublist(start, end)
        .map((id) => byId[id])
        .whereType<DocumentBlock>()
        .where((block) => block is! HeadingBlock)
        .toList(growable: false);
  }

  if (sharedHeadingIds.isEmpty) {
    return [
      _LinkedTextSegment(
        headings: const [],
        left: between(left, null, null),
        right: between(right, null, null),
      ),
    ];
  }

  final result = <_LinkedTextSegment>[];
  final leftPreamble = between(left, null, sharedHeadingIds.first);
  final rightPreamble = between(right, null, sharedHeadingIds.first);
  if (leftPreamble.isNotEmpty || rightPreamble.isNotEmpty) {
    result.add(
      _LinkedTextSegment(
        headings: const [],
        left: leftPreamble,
        right: rightPreamble,
      ),
    );
  }

  final pendingHeadings = <HeadingBlock>[];
  for (var index = 0; index < sharedHeadingIds.length; index++) {
    final headingId = sharedHeadingIds[index];
    final heading = byId[headingId];
    if (heading is HeadingBlock) pendingHeadings.add(heading);
    final nextHeadingId = index + 1 < sharedHeadingIds.length
        ? sharedHeadingIds[index + 1]
        : null;
    final leftBody = between(left, headingId, nextHeadingId);
    final rightBody = between(right, headingId, nextHeadingId);
    if (leftBody.isNotEmpty ||
        rightBody.isNotEmpty ||
        index == sharedHeadingIds.length - 1) {
      result.add(
        _LinkedTextSegment(
          headings: List.unmodifiable(pendingHeadings),
          left: leftBody,
          right: rightBody,
        ),
      );
      pendingHeadings.clear();
    }
  }
  return result;
}

class _SermonSearchResult {
  const _SermonSearchResult({
    required this.sermon,
    required this.score,
    required this.sourceLabel,
    required this.contextLabel,
    required this.snippet,
  });

  final Sermon sermon;
  final int score;
  final String sourceLabel;
  final String contextLabel;
  final String snippet;
}

List<_SermonSearchResult> _searchSermons(
  List<Sermon> sermons,
  String rawQuery,
) {
  final trimmedQuery = rawQuery.trim();
  final exactPhrase =
      trimmedQuery.length > 1 &&
      trimmedQuery.startsWith('"') &&
      trimmedQuery.endsWith('"');
  final query = _normalizeSearchText(trimmedQuery.replaceAll('"', ' '));
  if (query.isEmpty) return const <_SermonSearchResult>[];
  final tokens = query.split(' ').where((token) => token.isNotEmpty).toSet();
  final results = <_SermonSearchResult>[];

  for (final sermon in sermons) {
    final headings = sermon.document.blocks
        .whereType<HeadingBlock>()
        .map((block) => block.text)
        .join('\n');
    final notes = sermon.document.blocks
        .whereType<NoteBlock>()
        .map((block) => block.text)
        .join('\n');
    final script = sermon.document.blocks
        .where(
          (block) =>
              block is! HeadingBlock &&
              block is! NoteBlock &&
              block is! DividerBlock,
        )
        .map((block) => block.plainText)
        .where((text) => text.trim().isNotEmpty)
        .join('\n');
    final metadata = [
      sermon.primaryBibleReference?.displayText ?? '',
      sermon.seriesId ?? '',
      sermon.location ?? '',
      sermon.audience ?? '',
      ...sermon.topics,
      ...sermon.tags,
    ].join(' ');
    final title = _normalizeSearchText(sermon.title);
    final subtitle = _normalizeSearchText(sermon.subtitle);
    final normalizedHeadings = _normalizeSearchText(headings);
    final normalizedNotes = _normalizeSearchText(notes);
    final normalizedScript = _normalizeSearchText(script);
    final normalizedMetadata = _normalizeSearchText(metadata);
    final corpus = [
      title,
      subtitle,
      normalizedHeadings,
      normalizedNotes,
      normalizedScript,
      normalizedMetadata,
    ].join(' ');
    if (exactPhrase
        ? !corpus.contains(query)
        : !tokens.every(corpus.contains)) {
      continue;
    }

    var score = 0;
    if (title == query) {
      score += 1200;
    } else if (title.startsWith(query)) {
      score += 900;
    } else if (title.contains(query)) {
      score += 650;
    }
    final titleWords = title.split(' ');
    for (final token in tokens) {
      if (titleWords.contains(token)) {
        score += 180;
      } else if (titleWords.any((word) => word.startsWith(token))) {
        score += 125;
      } else if (title.contains(token)) {
        score += 80;
      }
    }
    score += _weightedSearchScore(subtitle, query, tokens, 90, 28);
    score += _weightedSearchScore(
      normalizedHeadings,
      query,
      tokens,
      80,
      24,
    );
    score += _weightedSearchScore(
      normalizedMetadata,
      query,
      tokens,
      60,
      18,
    );
    score += _weightedSearchScore(
      normalizedNotes,
      query,
      tokens,
      46,
      14,
    );
    score += _weightedSearchScore(
      normalizedScript,
      query,
      tokens,
      36,
      10,
    );

    final titleMatch = tokens.any(title.contains);
    final source = titleMatch
        ? ('TITEL', sermon.subtitle)
        : _firstSearchSource(
            query: query,
            tokens: tokens,
            sources: [
              ('ÜBERSCHRIFT', headings),
              ('ÜBERSICHT', sermon.subtitle),
              ('NOTES', notes),
              ('SCRIPT', script),
              ('METADATEN', metadata),
            ],
          );
    results.add(
      _SermonSearchResult(
        sermon: sermon,
        score: score,
        sourceLabel: source.$1,
        contextLabel: _searchContextLabel(sermon),
        snippet: _searchSnippet(source.$2, query, tokens),
      ),
    );
  }

  results.sort((left, right) {
    final relevance = right.score.compareTo(left.score);
    if (relevance != 0) return relevance;
    return right.sermon.updatedAt.compareTo(left.sermon.updatedAt);
  });
  return results;
}

int _weightedSearchScore(
  String text,
  String query,
  Set<String> tokens,
  int phraseWeight,
  int tokenWeight,
) {
  if (text.isEmpty) return 0;
  var score = text.contains(query) ? phraseWeight : 0;
  for (final token in tokens) {
    final occurrences = RegExp(RegExp.escape(token)).allMatches(text).length;
    score += math.min(occurrences, 5) * tokenWeight;
  }
  return score;
}

(String, String) _firstSearchSource({
  required String query,
  required Set<String> tokens,
  required List<(String, String)> sources,
}) {
  for (final source in sources) {
    final normalized = _normalizeSearchText(source.$2);
    if (normalized.contains(query) || tokens.any(normalized.contains)) {
      return source;
    }
  }
  return ('TREFFER', '');
}

String _searchContextLabel(Sermon sermon) {
  final reference = sermon.primaryBibleReference;
  if (reference != null) return reference.displayText;
  if (sermon.seriesId?.trim().isNotEmpty ?? false) return sermon.seriesId!;
  return switch (sermon.contentKind) {
    ContentKind.talk => 'Vortrag',
    ContentKind.introduction => 'Einleitung',
    ContentKind.shortTopic => 'Kurzthema',
    ContentKind.sermon => 'Predigt',
  };
}

String _searchSnippet(String source, String query, Set<String> tokens) {
  final compact = source.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.isEmpty) return '';
  final lower = compact.toLowerCase();
  var matchIndex = lower.indexOf(query);
  if (matchIndex < 0) {
    for (final token in tokens) {
      matchIndex = lower.indexOf(token);
      if (matchIndex >= 0) break;
    }
  }
  if (matchIndex < 0) matchIndex = 0;
  final start = math.max(0, matchIndex - 38);
  final end = math.min(compact.length, start + 145);
  return '${start > 0 ? '…' : ''}${compact.substring(start, end)}'
      '${end < compact.length ? '…' : ''}';
}

String _normalizeSearchText(String value) => value
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss')
    .replaceAll(RegExp('[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String _safeExportFileName(String title) {
  final safe = title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  return safe.isEmpty ? 'Predigt' : safe;
}

List<_DocumentSegment> _segments(List<DocumentBlock> blocks) {
  final result = <_DocumentSegment>[];
  var current = _DocumentSegment();
  for (final block in blocks) {
    if (block is HeadingBlock) {
      if (current.hasContent) {
        result.add(current);
        current = _DocumentSegment();
      }
      current.headings.add(block);
    } else if (block is NoteBlock) {
      current.notes.add(block);
    } else if (block is! BulletListBlock) {
      current.script.add(block);
    }
  }
  if (!current.isEmpty || result.isEmpty) result.add(current);
  return result;
}

bool _isScriptEditorBlock(DocumentBlock block) =>
    block is ParagraphBlock || block is QuoteBlock || block is BibleQuoteBlock;

double _blockTopMargin(DocumentBlock block, DocumentBlock? previous) {
  if (previous == null) return 0;
  if (block is HeadingBlock && block.level == 1) return 48;
  if (block is HeadingBlock && block.level == 3) {
    return previous is HeadingBlock && previous.level == 2 ? 16 : 24;
  }
  if (block is HeadingBlock) return 32;
  if (block is QuoteBlock) return previous is HeadingBlock ? 12 : 16;
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
      fontSize: 28.48,
      fontWeight: FontWeight.w500,
      height: 1.22,
      letterSpacing: -0.51,
    );

TextStyle _subheadingStyle(BuildContext context) =>
    Theme.of(context).textTheme.headlineSmall!.copyWith(
      fontFamily: AppTypography.ui,
      fontSize: 21.12,
      fontWeight: FontWeight.w500,
      height: 1.36,
      letterSpacing: -0.25,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.76),
    );

TextStyle _tertiaryHeadingStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium!.copyWith(
      fontFamily: AppTypography.editor,
      fontSize: 18.08,
      fontWeight: FontWeight.w500,
      height: 1.58,
      letterSpacing: -0.07,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
    );

TextStyle _outlineContextStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
  fontFamily: AppTypography.ui,
  fontSize: 12.8,
  fontWeight: FontWeight.w400,
  height: 1.5,
  letterSpacing: 1.024,
);

TextStyle _outlineMenuStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.76),
  fontFamily: AppTypography.ui,
  fontSize: 12.8,
  fontWeight: FontWeight.w400,
  height: 1.5,
);

TextStyle _outlineAnnotationStyle(BuildContext context) => TextStyle(
  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
  fontFamily: AppTypography.editor,
  fontSize: 14,
  fontWeight: FontWeight.w400,
  fontStyle: FontStyle.italic,
  height: 1.5,
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
  return formatBibleReference(reference, includeBook: false);
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
