import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/widgets/sermon_workflow_navigation.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/domain/presentation_anchor_index.dart';
import 'package:sermonary/features/presentation/presentation/presentation_editor_view.dart';
import 'package:sermonary/features/sermon_editor/domain/outline.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

enum LiveContentSource { notes, script }

class LiveModeScreen extends ConsumerStatefulWidget {
  const LiveModeScreen({
    required this.sermonId,
    this.moduleId,
    this.contentSource = LiveContentSource.script,
    super.key,
  });
  final String sermonId;
  final String? moduleId;
  final LiveContentSource contentSource;

  @override
  ConsumerState<LiveModeScreen> createState() => _LiveModeScreenState();
}

class _LiveModeScreenState extends ConsumerState<LiveModeScreen> {
  final ScrollController _scrollController = ScrollController();
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _running = false;
  bool _dark = false;
  bool _showOutline = true;
  double _fontSize = 24;
  double _maxWidth = 760;
  double _progress = 0;
  String? _activeBlockId;
  double _activeBlockFraction = 0;
  final Map<String, GlobalKey> _blockKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateProgress);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _scrollController
      ..removeListener(_updateProgress)
      ..dispose();
    super.dispose();
  }

  void _updateProgress() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    String? closestId;
    var closestDistance = double.infinity;
    var closestFraction = 0.0;
    for (final entry in _blockKeys.entries) {
      final render = entry.value.currentContext?.findRenderObject();
      if (render is! RenderBox || !render.attached) continue;
      final top = render.localToGlobal(Offset.zero).dy;
      final bottom = top + render.size.height;
      final distance = 150 < top
          ? top - 150
          : 150 > bottom
          ? 150 - bottom
          : 0.0;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestId = entry.key;
        closestFraction = render.size.height <= 0
            ? 0
            : ((150 - top) / render.size.height).clamp(0, 1);
      }
    }
    setState(() {
      _progress = max <= 0 ? 1 : _scrollController.offset / max;
      _activeBlockId = closestId ?? _activeBlockId;
      _activeBlockFraction = closestFraction;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sermonAsync = ref.watch(sermonProvider(widget.sermonId));
    return sermonAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
      data: (sermon) => sermon == null
          ? const Scaffold(body: Center(child: Text('Predigt nicht gefunden.')))
          : _buildLive(context, sermon),
    );
  }

  Widget _buildLive(BuildContext context, Sermon sermon) {
    final background = _dark ? AppColors.darkPaper : AppColors.paper;
    final foreground = _dark ? AppColors.darkInk : AppColors.ink;
    final module = _effectiveModule(sermon);
    final source = module?.kind == SermonModuleKind.notes
        ? LiveContentSource.notes
        : LiveContentSource.script;
    final blocks = _liveBlocks(sermon, module);
    final slideAnchors = module == null
        ? const <String, List<PresentationAnchorReference>>{}
        : presentationAnchorsByBlockForModule(
            sermon.document,
            module.id,
          );
    final liveDocument = sermon.document.copyWith(blocks: blocks);
    final wordCount = blocks.fold<int>(0, (count, block) {
      return count +
          block.plainText
              .trim()
              .split(RegExp(r'\s+'))
              .where((word) => word.isNotEmpty)
              .length;
    });
    final remainingWords = (wordCount * (1 - _progress)).round();
    final remaining = Duration(
      seconds: (remainingWords * 60 / AppConfig.defaultWordsPerMinute).round(),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): () => _scrollBy(420),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _scrollBy(130),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _scrollBy(-130),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            context.go('/sermons/${sermon.id}/${source.name}'),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: background,
          appBar: AppBar(
            backgroundColor: background,
            foregroundColor: foreground,
            leading: IconButton(
              tooltip: 'Livemode verlassen',
              onPressed: () =>
                  context.go('/sermons/${sermon.id}/${source.name}'),
              icon: const Icon(Icons.close),
            ),
            title: Text(
              sermon.title,
              style: TextStyle(
                color: foreground.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            actions: [
              _TimerLabel(
                elapsed: _elapsed,
                plannedMinutes: sermon.plannedDurationMinutes,
                remaining: remaining,
                foreground: foreground,
              ),
              IconButton(
                tooltip: _running ? 'Timer pausieren' : 'Timer starten',
                onPressed: _toggleTimer,
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              ),
              IconButton(
                tooltip: _dark ? 'Helle Ansicht' : 'Dunkle Ansicht',
                onPressed: () => setState(() => _dark = !_dark),
                icon: Icon(_dark ? Icons.light_mode : Icons.dark_mode),
              ),
              IconButton(
                tooltip: 'Outline ein-/ausblenden',
                onPressed: () => setState(() => _showOutline = !_showOutline),
                icon: const Icon(Icons.toc),
              ),
              PopupMenuButton<void>(
                tooltip: 'Darstellung',
                icon: const Icon(Icons.text_fields),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: StatefulBuilder(
                      builder: (context, setMenuState) => SizedBox(
                        width: 260,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Schriftgröße ${_fontSize.round()}'),
                            Slider(
                              value: _fontSize,
                              min: 20,
                              max: 44,
                              onChanged: (value) {
                                setState(() => _fontSize = value);
                                setMenuState(() {});
                              },
                            ),
                            Text('Textbreite ${_maxWidth.round()}'),
                            Slider(
                              value: _maxWidth,
                              min: 620,
                              max: 1200,
                              onChanged: (value) {
                                setState(() => _maxWidth = value);
                                setMenuState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    if (_showOutline)
                      SizedBox(
                        width: 260,
                        child: ColoredBox(
                          color: _dark
                              ? const Color(0xFF1E1D1A)
                              : AppColors.sidebar,
                          child: _LiveOutline(
                            document: liveDocument,
                            foreground: foreground,
                            onTap: _jumpToFraction,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 60,
                                vertical: 96,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: _maxWidth,
                                  ),
                                  child: SelectionArea(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sermon.title,
                                          style: TextStyle(
                                            fontFamily: AppTypography.editor,
                                            color: foreground,
                                            fontSize: _fontSize * 1.65,
                                            height: 1.2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (sermon.subtitle.isNotEmpty) ...[
                                          const SizedBox(height: 14),
                                          Text(
                                            sermon.subtitle,
                                            style: TextStyle(
                                              fontFamily: AppTypography.editor,
                                              color: foreground.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: _fontSize,
                                            ),
                                          ),
                                        ],
                                        SizedBox(height: _fontSize * 2),
                                        for (final block in blocks)
                                          KeyedSubtree(
                                            key: _blockKeys.putIfAbsent(
                                              block.id,
                                              GlobalKey.new,
                                            ),
                                            child: _LiveBlock(
                                              block: block,
                                              fontSize: _fontSize,
                                              foreground: foreground,
                                              background: background,
                                              slideAnchors:
                                                  slideAnchors[block.id] ??
                                                  const [],
                                            ),
                                          ),
                                        const SizedBox(height: 400),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (sermon.document.presentation.slides.isNotEmpty)
                            SizedBox(
                              width: 440,
                              child: _LivePresentationPane(
                                slide: _activeSlide(sermon),
                                foreground: foreground,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SermonWorkflowNavigation(
                  sermonTitle: sermon.title,
                  activeStages: const {SermonWorkflowStage.live},
                  availableStages: {
                    SermonWorkflowStage.outline,
                    if (sermon.document.hasModule(SermonModuleKind.notes))
                      SermonWorkflowStage.notes,
                    if (sermon.document.hasModule(SermonModuleKind.script))
                      SermonWorkflowStage.script,
                    if (sermon.document.hasModule(
                      SermonModuleKind.presentation,
                    ))
                      SermonWorkflowStage.presentation,
                    SermonWorkflowStage.live,
                  },
                  backgroundColor: background,
                  foregroundColor: foreground,
                  onSelected: (stage) {
                    if (stage == SermonWorkflowStage.live) return;
                    final path = switch (stage) {
                      SermonWorkflowStage.outline => 'outline',
                      SermonWorkflowStage.notes => 'notes',
                      SermonWorkflowStage.script => 'script',
                      SermonWorkflowStage.presentation => 'presentation',
                      SermonWorkflowStage.live => 'live',
                    };
                    context.go('/sermons/${sermon.id}/$path');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LiveContentSource _effectiveSource(Sermon sermon) {
    if (widget.contentSource == LiveContentSource.notes &&
        sermon.document.hasModule(SermonModuleKind.notes)) {
      return LiveContentSource.notes;
    }
    if (widget.contentSource == LiveContentSource.script &&
        sermon.document.hasModule(SermonModuleKind.script)) {
      return LiveContentSource.script;
    }
    return sermon.document.hasModule(SermonModuleKind.notes)
        ? LiveContentSource.notes
        : LiveContentSource.script;
  }

  SermonModule? _effectiveModule(Sermon sermon) {
    final requested = widget.moduleId == null
        ? null
        : sermon.document.moduleById(widget.moduleId!);
    if (requested != null &&
        (requested.kind == SermonModuleKind.notes ||
            requested.kind == SermonModuleKind.script)) {
      return requested;
    }
    final source = _effectiveSource(sermon);
    return sermon.document
        .modulesOfKind(
          source == LiveContentSource.notes
              ? SermonModuleKind.notes
              : SermonModuleKind.script,
        )
        .firstOrNull;
  }

  List<DocumentBlock> _liveBlocks(
    Sermon sermon,
    SermonModule? module,
  ) => module == null
      ? const <DocumentBlock>[]
      : sermon.document.blocksForModule(module.id);

  PresentationSlide? _activeSlide(Sermon sermon) {
    final liveModule = _effectiveModule(sermon);
    if (liveModule == null) return null;
    final presentationIds = sermon.document.effectiveModules
        .where(
          (module) =>
              module.kind == SermonModuleKind.presentation &&
              sermon.document.modulesAreLinked(module.id, liveModule.id),
        )
        .expand((module) => module.slideIds)
        .toSet();
    final slides = sermon.document.presentation.slides
        .where((slide) => presentationIds.contains(slide.id))
        .toList(growable: false);
    if (slides.isEmpty) return null;
    final liveBlocks = sermon.document.blocksForModule(liveModule.id);
    final activeIndex = liveBlocks.indexWhere(
      (block) => block.id == _activeBlockId,
    );
    final activeBlock = activeIndex < 0 ? null : liveBlocks[activeIndex];
    final activeOffset =
        ((activeBlock?.plainText.length ?? 0) * _activeBlockFraction).round();
    PresentationSlide? current;
    var currentIndex = -1;
    for (final slide in slides) {
      final anchor = slide.anchor;
      if (anchor == null) continue;
      final position = _anchorPositionForModule(
        sermon.document,
        anchor,
        liveModule,
      );
      final index = position.$1;
      final offset = position.$2;
      final reached =
          index < activeIndex ||
          (index == activeIndex && offset <= activeOffset);
      if (reached &&
          (index > currentIndex ||
              (index == currentIndex &&
                  (current?.anchor?.offset ?? -1) <= offset))) {
        current = slide;
        currentIndex = index;
      }
    }
    return current ?? slides.first;
  }

  (int, int) _anchorPositionForModule(
    SermonDocument document,
    PresentationAnchor anchor,
    SermonModule target,
  ) {
    final targetBlocks = document.blocksForModule(target.id);
    if (anchor.moduleId == target.id) {
      return (
        targetBlocks.indexWhere((block) => block.id == anchor.blockId),
        anchor.offset,
      );
    }
    final source = anchor.moduleId == null
        ? null
        : document.moduleById(anchor.moduleId!);
    if (source == null || !document.modulesAreLinked(source.id, target.id)) {
      return (-1, 0);
    }
    final sourceIds = source.blockIds;
    final anchorIndex = sourceIds.indexOf(anchor.blockId);
    if (anchorIndex < 0) return (-1, 0);
    for (var index = anchorIndex; index >= 0; index--) {
      final headingId = sourceIds[index];
      final heading = document.blocks
          .where((block) => block.id == headingId)
          .firstOrNull;
      if (heading is! HeadingBlock) continue;
      final targetIndex = targetBlocks.indexWhere(
        (block) => block.id == heading.id,
      );
      return (targetIndex, heading.text.length);
    }
    return (0, 0);
  }

  void _toggleTimer() {
    setState(() => _running = !_running);
    _ticker?.cancel();
    if (_running) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
    }
  }

  void _scrollBy(double amount) {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        (_scrollController.offset + amount).clamp(
          0,
          _scrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      ),
    );
  }

  void _jumpToFraction(double fraction) {
    if (!_scrollController.hasClients) return;
    unawaited(
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent * fraction,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      ),
    );
  }
}

class _LivePresentationPane extends StatelessWidget {
  const _LivePresentationPane({
    required this.slide,
    required this.foreground,
  });

  final PresentationSlide? slide;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(26, 48, 34, 48),
    decoration: BoxDecoration(
      border: Border(
        left: BorderSide(color: foreground.withValues(alpha: .1)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AKTIVE FOLIE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            letterSpacing: 1.2,
            color: foreground.withValues(alpha: .38),
          ),
        ),
        const SizedBox(height: 18),
        if (slide == null)
          Text(
            'Keine Folie zugeordnet',
            style: TextStyle(color: foreground.withValues(alpha: .45)),
          )
        else
          SlideCanvas(slide: slide!, large: true),
      ],
    ),
  );
}

class _LiveBlock extends StatelessWidget {
  const _LiveBlock({
    required this.block,
    required this.fontSize,
    required this.foreground,
    required this.background,
    required this.slideAnchors,
  });
  final DocumentBlock block;
  final double fontSize;
  final Color foreground;
  final Color background;
  final List<PresentationAnchorReference> slideAnchors;
  @override
  Widget build(BuildContext context) {
    final child = switch (block) {
      TitleBlock(:final text) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontSize: fontSize * 1.7,
          height: 1.2,
          color: foreground,
          fontWeight: FontWeight.bold,
        ),
      ),
      HeadingBlock(:final text, :final level) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontSize:
              fontSize *
              (level == 1
                  ? 1.5
                  : level == 2
                  ? 1.3
                  : 1.15),
          height: 1.25,
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
      ParagraphBlock(:final text, :final isBold, :final isItalic) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontSize: fontSize,
          height: 1.82,
          color: foreground,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        ),
      ),
      BulletListBlock(:final items) => _LiveBullets(
        items: items,
        fontSize: fontSize,
        foreground: foreground,
      ),
      BibleQuoteBlock(:final text, :final reference) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontFamily: AppTypography.editor,
                  fontSize: fontSize * 1.05,
                  height: 1.82,
                  color: foreground,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reference.displayText,
                style: TextStyle(
                  fontSize: fontSize * 0.65,
                  color: foreground.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
      QuoteBlock(:final text, :final author) => Text(
        '„$text“${author.isEmpty ? '' : '\n— $author'}',
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontSize: fontSize,
          height: 1.82,
          color: foreground.withValues(alpha: 0.85),
          fontStyle: FontStyle.italic,
        ),
      ),
      NoteBlock(:final text) => Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.editor,
          fontSize: fontSize * 0.82,
          color: foreground.withValues(alpha: 0.65),
        ),
      ),
      DividerBlock() => Divider(color: foreground.withValues(alpha: 0.25)),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: fontSize * 1.25),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (slideAnchors.isNotEmpty)
            Positioned(
              right: -46,
              top: 5,
              child: _LiveSlideMarker(
                references: slideAnchors,
                foreground: foreground,
                background: background,
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveSlideMarker extends StatefulWidget {
  const _LiveSlideMarker({
    required this.references,
    required this.foreground,
    required this.background,
  });

  final List<PresentationAnchorReference> references;
  final Color foreground;
  final Color background;

  @override
  State<_LiveSlideMarker> createState() => _LiveSlideMarkerState();
}

class _LiveSlideMarkerState extends State<_LiveSlideMarker> {
  final OverlayPortalController _controller = OverlayPortalController();
  final LayerLink _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    final numbers = widget.references
        .map((reference) => reference.number)
        .toList(growable: false);
    return CompositedTransformTarget(
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
                width: 280,
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
                    for (final reference in widget.references.take(3)) ...[
                      Row(
                        children: [
                          Text(
                            'Folie ${reference.number}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      SlideCanvas(slide: reference.slide),
                      if (reference != widget.references.take(3).last)
                        const SizedBox(height: 8),
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
            key: Key('live-slide-marker-${numbers.join('-')}'),
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: widget.foreground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.galleryHorizontal,
                  size: 10,
                  color: widget.background,
                ),
                const SizedBox(width: 4),
                Text(
                  numbers.length <= 3
                      ? numbers.join('·')
                      : '${numbers.take(2).join('·')}…',
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: widget.background,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveBullets extends StatelessWidget {
  const _LiveBullets({
    required this.items,
    required this.fontSize,
    required this.foreground,
    this.depth = 0,
  });
  final List<BulletItem> items;
  final double fontSize;
  final Color foreground;
  final int depth;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final item in items)
        Padding(
          padding: EdgeInsets.only(left: depth * 28, bottom: 12),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: fontSize * 0.52),
                    child: Icon(
                      depth == 0 ? Icons.circle : Icons.circle_outlined,
                      size: depth == 0 ? 9 : 8,
                      color: foreground,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.text,
                      style: TextStyle(
                        fontFamily: AppTypography.editor,
                        fontSize: fontSize,
                        height: 1.72,
                        color: foreground,
                        fontWeight: depth == 0
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
              if (!item.collapsed)
                _LiveBullets(
                  items: item.children,
                  fontSize: fontSize,
                  foreground: foreground,
                  depth: depth + 1,
                ),
            ],
          ),
        ),
    ],
  );
}

class _LiveOutline extends StatelessWidget {
  const _LiveOutline({
    required this.document,
    required this.foreground,
    required this.onTap,
  });
  final SermonDocument document;
  final Color foreground;
  final ValueChanged<double> onTap;
  @override
  Widget build(BuildContext context) {
    final entries = buildOutline(document);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Outline',
          style: TextStyle(color: foreground, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < entries.length; index++)
          Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.only(left: entries[index].level * 10),
              title: Text(
                entries[index].title,
                softWrap: true,
                style: TextStyle(color: foreground),
              ),
              subtitle: Text(
                '${entries[index].wordCount} Wörter',
                style: TextStyle(color: foreground.withValues(alpha: 0.6)),
              ),
              onTap: () => onTap(
                entries.length <= 1 ? 0 : index / (entries.length - 1),
              ),
            ),
          ),
      ],
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({
    required this.elapsed,
    required this.plannedMinutes,
    required this.remaining,
    required this.foreground,
  });
  final Duration elapsed;
  final int? plannedMinutes;
  final Duration remaining;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${_two(elapsed.inMinutes)}:${_two(elapsed.inSeconds % 60)}'
          '${plannedMinutes == null ? '' : ' / $plannedMinutes Min.'}',
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            height: 1.1,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'Rest ca. ${remaining.inMinutes + 1} Min.',
          style: TextStyle(
            color: foreground.withValues(alpha: 0.6),
            fontSize: 10,
            height: 1.1,
          ),
        ),
      ],
    ),
  );

  String _two(int value) => value.toString().padLeft(2, '0');
}
