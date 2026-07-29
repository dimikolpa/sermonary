import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/outline.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class LiveModeScreen extends ConsumerStatefulWidget {
  const LiveModeScreen({required this.sermonId, super.key});
  final String sermonId;

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
    setState(() => _progress = max <= 0 ? 1 : _scrollController.offset / max);
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
    final remainingWords = (sermon.document.wordCount * (1 - _progress))
        .round();
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
            context.go('/sermons/${sermon.id}/script'),
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
              onPressed: () => context.go('/sermons/${sermon.id}/script'),
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
          body: Row(
            children: [
              if (_showOutline)
                SizedBox(
                  width: 260,
                  child: ColoredBox(
                    color: _dark ? const Color(0xFF1E1D1A) : AppColors.sidebar,
                    child: _LiveOutline(
                      document: sermon.document,
                      foreground: foreground,
                      onTap: _jumpToFraction,
                    ),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 60,
                    vertical: 96,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _maxWidth),
                      child: SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                  color: foreground.withValues(alpha: 0.7),
                                  fontSize: _fontSize,
                                ),
                              ),
                            ],
                            SizedBox(height: _fontSize * 2),
                            for (final block in sermon.document.blocks)
                              if (block case NoteBlock(
                                visibility: NoteVisibility.editorOnly,
                              ))
                                const SizedBox.shrink()
                              else
                                _LiveBlock(
                                  block: block,
                                  fontSize: _fontSize,
                                  foreground: foreground,
                                ),
                            const SizedBox(height: 400),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _LiveBlock extends StatelessWidget {
  const _LiveBlock({
    required this.block,
    required this.fontSize,
    required this.foreground,
  });
  final DocumentBlock block;
  final double fontSize;
  final Color foreground;
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
      child: child,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
