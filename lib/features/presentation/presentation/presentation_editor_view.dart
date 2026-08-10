import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/platform/keyboard_shortcuts.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/presentation/domain/presentation_bible_pagination.dart';
import 'package:sermonary/features/presentation/domain/presentation_text_formatting.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

class PresentationEditorView extends StatelessWidget {
  const PresentationEditorView({
    required this.sermon,
    required this.selectedSlideId,
    required this.onSelectSlide,
    required this.onDeckChanged,
    required this.onPickImage,
    required this.onExportPdf,
    required this.onExportPowerPoint,
    required this.onExportImagePowerPoint,
    required this.smartAddAvailable,
    required this.onSmartAdd,
    super.key,
    this.compact = false,
  });

  final Sermon sermon;
  final String? selectedSlideId;
  final ValueChanged<String?> onSelectSlide;
  final ValueChanged<PresentationDeck> onDeckChanged;
  final Future<String?> Function() onPickImage;
  final VoidCallback onExportPdf;
  final VoidCallback onExportPowerPoint;
  final VoidCallback onExportImagePowerPoint;
  final bool smartAddAvailable;
  final ValueChanged<PresentationSlideTemplate> onSmartAdd;
  final bool compact;

  List<PresentationSlide> get _slides => sermon.document.presentation.slides;

  @override
  Widget build(BuildContext context) {
    final selected = _slides
        .where((slide) => slide.id == selectedSlideId)
        .firstOrNull;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height - 49,
      child: Row(
        children: [
          SizedBox(
            width: compact ? 150 : 210,
            child: _SlideRail(
              slides: _slides,
              selectedSlideId: selectedSlideId,
              onSelect: onSelectSlide,
              onAdd: () => _showTemplatePicker(context),
              onSmartAdd: smartAddAvailable
                  ? () => _showTemplatePicker(context, smart: true)
                  : null,
              onDuplicate: _duplicate,
              onDelete: _delete,
              onMove: _move,
            ),
          ),
          VerticalDivider(
            width: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: selected == null
                ? _PresentationEmpty(onAdd: () => _showTemplatePicker(context))
                : _SlideEditor(
                    slide: selected,
                    compact: compact,
                    onChanged: _replace,
                    onPickImage: onPickImage,
                    onExportPdf: onExportPdf,
                    onExportPowerPoint: onExportPowerPoint,
                    onExportImagePowerPoint: onExportImagePowerPoint,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTemplatePicker(
    BuildContext context, {
    bool smart = false,
  }) async {
    final template = await showDialog<PresentationSlideTemplate>(
      context: context,
      builder: (context) => _TemplatePickerDialog(smart: smart),
    );
    if (template == null) return;
    if (smart) {
      onSmartAdd(template);
      return;
    }
    final slide = PresentationSlide(
      id: const Uuid().v4(),
      template: template,
      title: template == PresentationSlideTemplate.title ? sermon.title : '',
      subtitle: template == PresentationSlideTemplate.title
          ? sermon.primaryBibleReference?.displayText ?? sermon.subtitle
          : '',
    );
    onDeckChanged(PresentationDeck(slides: [..._slides, slide]));
    onSelectSlide(slide.id);
  }

  void _replace(PresentationSlide slide) => onDeckChanged(
    PresentationDeck(
      slides: replaceAndPaginatePresentationBibleSlide(
        _slides,
        slide,
        createId: () => const Uuid().v4(),
      ),
    ),
  );

  void _duplicate(PresentationSlide slide) {
    final copy = PresentationSlide(
      id: const Uuid().v4(),
      template: slide.template,
      title: slide.title,
      subtitle: slide.subtitle,
      body: slide.body,
      reference: slide.reference,
      items: slide.items,
      imagePath: slide.imagePath,
      caption: slide.caption,
      titleMarks: slide.titleMarks,
      subtitleMarks: slide.subtitleMarks,
      bodyMarks: slide.bodyMarks,
      referenceMarks: slide.referenceMarks,
      itemMarks: slide.itemMarks,
      captionMarks: slide.captionMarks,
    );
    final slides = [..._slides, copy];
    onDeckChanged(PresentationDeck(slides: slides));
    onSelectSlide(copy.id);
  }

  void _delete(PresentationSlide slide) {
    final index = _slides.indexWhere((item) => item.id == slide.id);
    var slides = _slides.where((item) => item.id != slide.id).toList();
    final groupId = slide.continuationGroupId;
    if (groupId != null) {
      final remaining =
          slides.where((item) => item.continuationGroupId == groupId).toList()
            ..sort(
              (left, right) =>
                  left.continuationIndex.compareTo(right.continuationIndex),
            );
      slides = [
        for (final item in slides)
          if (item.continuationGroupId != groupId)
            item
          else
            item.copyWith(
              clearContinuationGroupId: remaining.length == 1,
              continuationIndex: remaining.indexOf(item) + 1,
              continuationCount: remaining.length,
            ),
      ];
    }
    onDeckChanged(PresentationDeck(slides: slides));
    if (slide.id == selectedSlideId) {
      onSelectSlide(
        slides.isEmpty ? null : slides[index.clamp(0, slides.length - 1)].id,
      );
    }
  }

  void _move(PresentationSlide slide, int delta) {
    if (slide.anchor != null) return;
    final index = _slides.indexWhere((item) => item.id == slide.id);
    final groupId = slide.continuationGroupId;
    if (groupId != null) {
      final group = _slides
          .where((item) => item.continuationGroupId == groupId)
          .toList();
      final first = _slides.indexWhere(
        (item) => item.continuationGroupId == groupId,
      );
      final last = _slides.lastIndexWhere(
        (item) => item.continuationGroupId == groupId,
      );
      final target = delta < 0 ? first - 1 : last + 1;
      if (target < 0 || target >= _slides.length) return;
      final neighbor = _slides[target];
      final slides = [..._slides]
        ..removeWhere(
          (item) => item.continuationGroupId == groupId,
        );
      final neighborIndex = slides.indexOf(neighbor);
      slides.insertAll(
        delta < 0 ? neighborIndex : neighborIndex + 1,
        group,
      );
      onDeckChanged(PresentationDeck(slides: slides));
      return;
    }
    final target = (index + delta).clamp(0, _slides.length - 1);
    if (target == index) return;
    final slides = [..._slides]
      ..removeAt(index)
      ..insert(target, slide);
    onDeckChanged(PresentationDeck(slides: slides));
  }
}

class _SlideRail extends StatelessWidget {
  const _SlideRail({
    required this.slides,
    required this.selectedSlideId,
    required this.onSelect,
    required this.onAdd,
    required this.onSmartAdd,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMove,
  });

  final List<PresentationSlide> slides;
  final String? selectedSlideId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAdd;
  final VoidCallback? onSmartAdd;
  final ValueChanged<PresentationSlide> onDuplicate;
  final ValueChanged<PresentationSlide> onDelete;
  final void Function(PresentationSlide, int) onMove;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: Column(
      children: [
        if (onSmartAdd != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                key: const Key('presentation-smart-add-slide'),
                onPressed: onSmartAdd,
                icon: const Icon(LucideIcons.sparkles, size: 13),
                label: const Text(
                  'Intelligente Folie hinzufügen',
                  textAlign: TextAlign.left,
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 9,
                  ),
                  textStyle: const TextStyle(fontSize: 10.5),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(18, onSmartAdd == null ? 18 : 9, 10, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'FOLIEN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .45),
                  ),
                ),
              ),
              IconButton(
                key: const Key('presentation-add-slide'),
                tooltip: 'Neue Folie',
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 15),
              ),
            ],
          ),
        ),
        Expanded(
          child: slides.isEmpty
              ? Center(
                  child: Text(
                    'Noch keine Folien',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 24),
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    final selected = slide.id == selectedSlideId;
                    return Draggable<PresentationSlide>(
                      data: slide,
                      feedback: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 190,
                          child: SlideCanvas(slide: slide),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: .35,
                        child: _SlideCard(
                          slide: slide,
                          index: index,
                          selected: selected,
                          onTap: () => onSelect(slide.id),
                          onDuplicate: () => onDuplicate(slide),
                          onDelete: () => onDelete(slide),
                          onMoveUp: () => onMove(slide, -1),
                          onMoveDown: () => onMove(slide, 1),
                        ),
                      ),
                      child: _SlideCard(
                        slide: slide,
                        index: index,
                        selected: selected,
                        onTap: () => onSelect(slide.id),
                        onDuplicate: () => onDuplicate(slide),
                        onDelete: () => onDelete(slide),
                        onMoveUp: () => onMove(slide, -1),
                        onMoveDown: () => onMove(slide, 1),
                      ),
                    );
                  },
                ),
        ),
      ],
    ),
  );
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({
    required this.slide,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });
  final PresentationSlide slide;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surfaceContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .22)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SlideCanvas(slide: slide),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  '${index + 1}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 9),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _templateLabel(slide.template),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
                    ),
                  ),
                ),
                if (slide.anchor == null) ...[
                  _MiniAction(
                    icon: LucideIcons.chevronUp,
                    tooltip: 'Nach oben',
                    onTap: onMoveUp,
                  ),
                  _MiniAction(
                    icon: LucideIcons.chevronDown,
                    tooltip: 'Nach unten',
                    onTap: onMoveDown,
                  ),
                ],
                _MiniAction(
                  icon: LucideIcons.copy,
                  tooltip: 'Duplizieren',
                  onTap: onDuplicate,
                ),
                _MiniAction(
                  icon: LucideIcons.trash2,
                  tooltip: 'Löschen',
                  onTap: onDelete,
                ),
              ],
            ),
            if (slide.anchor != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    const Icon(LucideIcons.link2, size: 9),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Im ${slide.anchor!.view == PresentationAnchorView.notes ? 'Notes' : 'Script'} verknüpft',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(fontSize: 8.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          icon,
          size: 10,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
        ),
      ),
    ),
  );
}

class _SlideEditor extends StatelessWidget {
  const _SlideEditor({
    required this.slide,
    required this.compact,
    required this.onChanged,
    required this.onPickImage,
    required this.onExportPdf,
    required this.onExportPowerPoint,
    required this.onExportImagePowerPoint,
  });
  final PresentationSlide slide;
  final bool compact;
  final ValueChanged<PresentationSlide> onChanged;
  final Future<String?> Function() onPickImage;
  final VoidCallback onExportPdf;
  final VoidCallback onExportPowerPoint;
  final VoidCallback onExportImagePowerPoint;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(compact ? 20 : 54, 34, compact ? 20 : 54, 100),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  _templateLabel(slide.template).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: .45),
                  ),
                ),
                const SizedBox(width: 12),
                if (compact)
                  Tooltip(
                    message: 'Wird automatisch gespeichert',
                    child: Icon(
                      LucideIcons.cloudCheck,
                      size: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                    ),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        LucideIcons.cloudCheck,
                        size: 11,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Wird automatisch gespeichert',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withValues(alpha: .38),
                        ),
                      ),
                    ],
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'PDF exportieren',
                  onPressed: onExportPdf,
                  icon: const Icon(LucideIcons.fileText, size: 13),
                ),
                IconButton(
                  tooltip: 'PowerPoint bearbeitbar exportieren',
                  onPressed: onExportPowerPoint,
                  icon: const Icon(LucideIcons.presentation, size: 13),
                ),
                IconButton(
                  tooltip: 'PowerPoint pixelgetreu exportieren',
                  onPressed: onExportImagePowerPoint,
                  icon: const Icon(LucideIcons.images, size: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SlideCanvas(slide: slide, large: true),
            const SizedBox(height: 32),
            _SlideFields(
              key: ValueKey('slide-fields-${slide.id}'),
              slide: slide,
              onChanged: onChanged,
              onPickImage: onPickImage,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SlideFields extends StatelessWidget {
  const _SlideFields({
    required this.slide,
    required this.onChanged,
    required this.onPickImage,
    super.key,
  });
  final PresentationSlide slide;
  final ValueChanged<PresentationSlide> onChanged;
  final Future<String?> Function() onPickImage;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (slide.template != PresentationSlideTemplate.image &&
          slide.template != PresentationSlideTemplate.largeContents)
        _LineField(
          label: 'ÜBERSCHRIFT',
          value: slide.title,
          marks: slide.titleMarks,
          onChanged: (value, marks) => onChanged(
            slide.copyWith(title: value, titleMarks: marks),
          ),
        ),
      if (slide.template == PresentationSlideTemplate.title)
        _LineField(
          label: 'UNTERTITEL',
          value: slide.subtitle,
          marks: slide.subtitleMarks,
          onChanged: (value, marks) => onChanged(
            slide.copyWith(subtitle: value, subtitleMarks: marks),
          ),
        ),
      if (slide.template == PresentationSlideTemplate.headingText ||
          slide.template == PresentationSlideTemplate.headingBible ||
          slide.template == PresentationSlideTemplate.headingImageBible)
        _LineField(
          label:
              slide.template == PresentationSlideTemplate.headingBible ||
                  slide.template == PresentationSlideTemplate.headingImageBible
              ? 'BIBELTEXT'
              : 'TEXT',
          value: slide.body,
          marks: slide.bodyMarks,
          maxLines: 6,
          onChanged: (value, marks) =>
              onChanged(slide.copyWith(body: value, bodyMarks: marks)),
        ),
      if (slide.template == PresentationSlideTemplate.headingBible ||
          slide.template == PresentationSlideTemplate.headingImageBible)
        _LineField(
          label: 'BIBELSTELLE',
          value: slide.reference,
          marks: slide.referenceMarks,
          onChanged: (value, marks) => onChanged(
            slide.copyWith(reference: value, referenceMarks: marks),
          ),
        ),
      if (slide.template == PresentationSlideTemplate.contents ||
          slide.template == PresentationSlideTemplate.largeContents)
        _LineField(
          label: 'PUNKTE · JE ZEILE EIN PUNKT',
          value: slide.items.join('\n'),
          marks: _joinedItemMarks(slide.items, slide.itemMarks),
          maxLines: 7,
          onChanged: (value, marks) => onChanged(
            slide.copyWith(
              items: value.split('\n'),
              itemMarks: _splitItemMarks(value, marks),
            ),
          ),
        ),
      if (_templateUsesImage(slide.template)) ...[
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final path = await onPickImage();
              if (path != null) onChanged(slide.copyWith(imagePath: path));
            },
            icon: const Icon(LucideIcons.imagePlus, size: 15),
            label: Text(
              slide.imagePath == null ? 'Bild auswählen' : 'Bild ersetzen',
            ),
          ),
        ),
        if (slide.template == PresentationSlideTemplate.image) ...[
          const SizedBox(height: 18),
          _LineField(
            label: 'BILDUNTERSCHRIFT',
            value: slide.caption,
            marks: slide.captionMarks,
            onChanged: (value, marks) => onChanged(
              slide.copyWith(caption: value, captionMarks: marks),
            ),
          ),
        ],
      ],
    ];
    return Column(
      children: fields
          .expand((field) => [field, const SizedBox(height: 22)])
          .toList(),
    );
  }
}

class _LineField extends StatefulWidget {
  const _LineField({
    required this.label,
    required this.value,
    required this.marks,
    required this.onChanged,
    this.maxLines = 1,
  });
  final String label;
  final String value;
  final List<InlineMark> marks;
  final void Function(String value, List<InlineMark> marks) onChanged;
  final int maxLines;

  @override
  State<_LineField> createState() => _LineFieldState();
}

class _LineFieldState extends State<_LineField> {
  late final _PresentationTextController _controller =
      _PresentationTextController(widget.value, widget.marks)
        ..addListener(_selectionChanged);
  late final FocusNode _focusNode = FocusNode(
    onKeyEvent: _handleKeyEvent,
  )..addListener(_focusChanged);
  final Map<PresentationTextFormat, bool> _typingFormats = {};
  late String _lastText = widget.value;
  bool _syncingExternal = false;

  @override
  void didUpdateWidget(_LineField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      final offset = _controller.selection.extentOffset.clamp(
        0,
        widget.value.length,
      );
      _syncingExternal = true;
      _controller
        ..value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: offset),
        )
        ..marks = widget.marks;
      _syncingExternal = false;
      _lastText = widget.value;
    } else if (oldWidget.marks != widget.marks) {
      _controller.marks = widget.marks;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_selectionChanged)
      ..dispose();
    _focusNode
      ..removeListener(_focusChanged)
      ..dispose();
    super.dispose();
  }

  void _selectionChanged() {
    if (!_syncingExternal && mounted && _focusNode.hasFocus) setState(() {});
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  bool _active(PresentationTextFormat format) {
    final selection = _controller.selection;
    if (!selection.isValid) return false;
    final inherited = selection.isCollapsed
        ? presentationFormatAtCaret(
            _controller.marks,
            format,
            selection.extentOffset,
          )
        : presentationFormatCoversRange(
            _controller.marks,
            format,
            selection.start,
            selection.end,
          );
    return selection.isCollapsed
        ? _typingFormats[format] ?? inherited
        : inherited;
  }

  void _toggle(PresentationTextFormat format) {
    final selection = _controller.selection;
    if (!selection.isValid) return;
    if (selection.isCollapsed) {
      setState(() {
        _typingFormats[format] = !_active(format);
      });
      _focusNode.requestFocus();
      return;
    }
    final next = setPresentationFormat(
      _controller.marks,
      format: format,
      start: selection.start,
      end: selection.end,
      enabled: !_active(format),
    );
    setState(() => _controller.marks = next);
    widget.onChanged(_controller.text, next);
    _focusNode.requestFocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !isPrimaryShortcutPressed) {
      return KeyEventResult.ignored;
    }
    final format = switch (event.logicalKey) {
      LogicalKeyboardKey.keyB => PresentationTextFormat.bold,
      LogicalKeyboardKey.keyI => PresentationTextFormat.italic,
      LogicalKeyboardKey.keyM => PresentationTextFormat.highlight,
      _ => null,
    };
    if (format == null) return KeyEventResult.ignored;
    _toggle(format);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: 1.1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: .42),
              ),
            ),
          ),
          _PresentationFormatButton(
            key: Key('presentation-format-$_fieldSlug-bold'),
            label: 'B',
            tooltip: 'Fett · ${primaryShortcutModifier}B',
            selected: _active(PresentationTextFormat.bold),
            onPressed: () => _toggle(PresentationTextFormat.bold),
          ),
          _PresentationFormatButton(
            key: Key('presentation-format-$_fieldSlug-italic'),
            label: 'I',
            italic: true,
            tooltip: 'Kursiv · ${primaryShortcutModifier}I',
            selected: _active(PresentationTextFormat.italic),
            onPressed: () => _toggle(PresentationTextFormat.italic),
          ),
          IconButton(
            key: Key('presentation-format-$_fieldSlug-highlight'),
            tooltip: 'Markieren · ${primaryShortcutModifier}M',
            onPressed: () => _toggle(PresentationTextFormat.highlight),
            icon: const Icon(LucideIcons.highlighter, size: 12),
            isSelected: _active(PresentationTextFormat.highlight),
            style: IconButton.styleFrom(
              minimumSize: const Size.square(24),
              maximumSize: const Size.square(24),
              padding: EdgeInsets.zero,
              backgroundColor: _active(PresentationTextFormat.highlight)
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                  : Colors.transparent,
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      TextField(
        key: Key(
          'presentation-field-$_fieldSlug',
        ),
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _textChanged,
        maxLines: widget.maxLines,
        minLines: widget.maxLines == 1 ? 1 : 3,
        decoration: const InputDecoration(
          isDense: true,
          border: UnderlineInputBorder(),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0x1F77736B)),
          ),
        ),
      ),
    ],
  );

  void _textChanged(String value) {
    final change = presentationChangedTextRange(_lastText, value);
    var marks = adjustPresentationMarks(
      _controller.marks,
      oldText: _lastText,
      newText: value,
    );
    if (change.start < change.newEnd) {
      for (final entry in _typingFormats.entries) {
        marks = setPresentationFormat(
          marks,
          format: entry.key,
          start: change.start,
          end: change.newEnd,
          enabled: entry.value,
        );
      }
    }
    _lastText = value;
    _controller.marks = marks;
    widget.onChanged(value, marks);
  }

  String get _fieldSlug =>
      widget.label.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
}

class _PresentationFormatButton extends StatelessWidget {
  const _PresentationFormatButton({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
    super.key,
    this.italic = false,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;
  final bool italic;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.ui,
            fontSize: 11,
            fontWeight: label == 'B' ? FontWeight.w700 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    ),
  );
}

class _PresentationTextController extends TextEditingController {
  _PresentationTextController(String text, this._marks) : super(text: text);

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
  }) => TextSpan(
    style: style,
    children: [
      for (final segment in presentationTextSegments(text, marks))
        TextSpan(
          text: segment.text,
          style: style?.copyWith(
            fontWeight: segment.bold ? FontWeight.w700 : style.fontWeight,
            fontStyle: segment.italic ? FontStyle.italic : style.fontStyle,
            backgroundColor: segment.highlighted
                ? AppColors.highlight.withValues(alpha: .64)
                : null,
          ),
        ),
    ],
  );
}

List<InlineMark> _joinedItemMarks(
  List<String> items,
  List<List<InlineMark>> itemMarks,
) {
  final result = <InlineMark>[];
  var offset = 0;
  for (var index = 0; index < items.length; index++) {
    final marks = index < itemMarks.length
        ? itemMarks[index]
        : const <InlineMark>[];
    for (final mark in marks) {
      result.add(
        InlineMark(
          start: mark.start + offset,
          end: mark.end + offset,
          bold: mark.bold,
          italic: mark.italic,
          highlighted: mark.highlighted,
        ),
      );
    }
    offset += items[index].length + 1;
  }
  return result;
}

List<List<InlineMark>> _splitItemMarks(
  String text,
  List<InlineMark> marks,
) {
  final lines = text.split('\n');
  final result = <List<InlineMark>>[];
  var offset = 0;
  for (final line in lines) {
    final end = offset + line.length;
    result.add([
      for (final mark in marks)
        if (mark.end > offset && mark.start < end)
          InlineMark(
            start: (mark.start - offset).clamp(0, line.length),
            end: (mark.end - offset).clamp(0, line.length),
            bold: mark.bold,
            italic: mark.italic,
            highlighted: mark.highlighted,
          ),
    ]);
    offset = end + 1;
  }
  return result;
}

class SlideCanvas extends StatelessWidget {
  const SlideCanvas({required this.slide, super.key, this.large = false});
  final PresentationSlide slide;
  final bool large;

  @override
  Widget build(BuildContext context) {
    const foreground = Color(0xFF23221F);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRect(
        child: FittedBox(
          child: SizedBox(
            width: 1280,
            height: 720,
            child: Container(
              key: const Key('presentation-slide-background'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                // PNG/WebP transparency deliberately reveals the same warm
                // paper tone used by every other presentation template.
                color: const Color(0xFFFDFCF9),
                border: Border.all(color: const Color(0x1977736B)),
                boxShadow: large
                    ? const [
                        BoxShadow(
                          color: Color(0x18000000),
                          blurRadius: 22,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (slide.template == PresentationSlideTemplate.image)
                    if (slide.imagePath case final String path)
                      Image.file(
                        File(path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const _PresentationImageFrame(path: null),
                      )
                    else
                      const _PresentationImageFrame(path: null),
                  Padding(
                    padding: const EdgeInsets.all(72),
                    child: _SlideContent(
                      slide: slide,
                      foreground: foreground,
                      headingSize: 40,
                      large: true,
                    ),
                  ),
                  if (slide.continuationCount > 1)
                    Positioned(
                      right: 46,
                      bottom: 34,
                      child: Text(
                        '${slide.continuationIndex}/${slide.continuationCount}',
                        key: const Key('presentation-continuation-label'),
                        style: TextStyle(
                          fontFamily: AppTypography.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: foreground.withValues(alpha: .42),
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

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.slide,
    required this.foreground,
    required this.headingSize,
    required this.large,
  });
  final PresentationSlide slide;
  final Color foreground;
  final double headingSize;
  final bool large;
  @override
  Widget build(BuildContext context) => switch (slide.template) {
    PresentationSlideTemplate.title => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slide.title.trim().isNotEmpty)
            _MarkedSlideText(
              text: slide.title,
              marks: slide.titleMarks,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppTypography.ui,
                fontSize: headingSize * 1.25,
                height: 1.16,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          if (slide.title.trim().isNotEmpty && slide.subtitle.trim().isNotEmpty)
            SizedBox(height: large ? 22 : 5),
          if (slide.subtitle.trim().isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Divider(color: foreground.withValues(alpha: .2)),
                ),
                SizedBox(width: large ? 18 : 4),
                Expanded(
                  key: const Key('presentation-title-subtitle'),
                  flex: 3,
                  child: _MarkedSlideText(
                    text: slide.subtitle,
                    marks: slide.subtitleMarks,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.editor,
                      fontStyle: FontStyle.italic,
                      fontSize: headingSize * .55,
                      height: 1.3,
                      color: foreground.withValues(alpha: .62),
                    ),
                  ),
                ),
                SizedBox(width: large ? 18 : 4),
                Expanded(
                  child: Divider(color: foreground.withValues(alpha: .2)),
                ),
              ],
            ),
        ],
      ),
    ),
    PresentationSlideTemplate.headingText => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _CanvasHeading(
            slide.title,
            slide.titleMarks,
            headingSize,
            foreground,
          ),
          SizedBox(height: large ? 18 : 4),
          Divider(color: foreground.withValues(alpha: .22)),
          SizedBox(height: large ? 22 : 5),
        ],
        Expanded(
          child: slide.body.trim().isEmpty
              ? const SizedBox.shrink()
              : _MarkedSlideText(
                  text: slide.body,
                  marks: slide.bodyMarks,
                  maxLines: large ? 9 : 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppTypography.editor,
                    fontSize: headingSize * .54,
                    height: 1.52,
                    color: foreground.withValues(alpha: .78),
                  ),
                ),
        ),
      ],
    ),
    PresentationSlideTemplate.headingBible => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _CanvasHeading(
            slide.title,
            slide.titleMarks,
            headingSize,
            foreground,
          ),
          SizedBox(height: large ? 28 : 6),
        ],
        Expanded(
          child: Container(
            padding: EdgeInsets.only(left: large ? 24 : 6),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: foreground.withValues(alpha: .32),
                  width: large ? 2 : 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: slide.body.trim().isEmpty
                      ? const SizedBox.shrink()
                      : _MarkedSlideText(
                          text: slide.body,
                          marks: slide.bodyMarks,
                          maxLines: large ? 10 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.editor,
                            fontStyle: FontStyle.italic,
                            fontSize: headingSize * .55,
                            height: 1.5,
                            color: foreground.withValues(alpha: .78),
                          ),
                        ),
                ),
                if (slide.reference.trim().isNotEmpty)
                  _MarkedSlideText(
                    text: slide.reference,
                    marks: slide.referenceMarks,
                    style: TextStyle(
                      fontFamily: AppTypography.ui,
                      fontSize: headingSize * .36,
                      height: 1.3,
                      color: foreground.withValues(alpha: .5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
    PresentationSlideTemplate.contents => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _CanvasHeading(
            slide.title,
            slide.titleMarks,
            headingSize,
            foreground,
          ),
          SizedBox(height: large ? 28 : 6),
        ],
        for (
          var index = 0;
          index <
                  presentationVisibleItems(
                    slide.items,
                    slide.itemMarks,
                  ).length &&
              index < 5;
          index++
        )
          Padding(
            padding: EdgeInsets.only(bottom: large ? 14 : 3),
            child: Row(
              children: [
                SizedBox(
                  width: large ? 42 : 10,
                  child: Text(
                    '${index + 1}'.padLeft(2, '0'),
                    style: TextStyle(
                      fontFamily: AppTypography.ui,
                      fontSize: headingSize * .35,
                      color: foreground.withValues(alpha: .38),
                    ),
                  ),
                ),
                Expanded(
                  child: _MarkedSlideText(
                    text: presentationVisibleItems(
                      slide.items,
                      slide.itemMarks,
                    )[index].text,
                    marks: presentationVisibleItems(
                      slide.items,
                      slide.itemMarks,
                    )[index].marks,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.editor,
                      fontSize: headingSize * .55,
                      height: 1.3,
                      color: foreground.withValues(alpha: .8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    PresentationSlideTemplate.largeContents => _LargeContentsSlide(
      slide: slide,
      foreground: foreground,
      headingSize: headingSize,
      large: large,
    ),
    PresentationSlideTemplate.headingImage => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _CanvasHeading(
            slide.title,
            slide.titleMarks,
            headingSize,
            foreground,
          ),
          SizedBox(height: large ? 24 : 5),
        ],
        Expanded(child: _PresentationImageFrame(path: slide.imagePath)),
      ],
    ),
    PresentationSlideTemplate.headingImageBible => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slide.title.trim().isNotEmpty) ...[
          _CanvasHeading(
            slide.title,
            slide.titleMarks,
            headingSize,
            foreground,
          ),
          SizedBox(height: large ? 28 : 6),
        ],
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PresentationImageFrame(path: slide.imagePath),
              ),
              SizedBox(width: large ? 34 : 8),
              Expanded(
                flex: 2,
                child: Container(
                  padding: EdgeInsets.only(left: large ? 24 : 6),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: foreground.withValues(alpha: .32),
                        width: large ? 2 : 1,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: slide.body.trim().isEmpty
                            ? const SizedBox.shrink()
                            : _MarkedSlideText(
                                text: slide.body,
                                marks: slide.bodyMarks,
                                maxLines: large ? 9 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: AppTypography.editor,
                                  fontStyle: FontStyle.italic,
                                  fontSize: headingSize * .49,
                                  height: 1.55,
                                  color: foreground.withValues(alpha: .78),
                                ),
                              ),
                      ),
                      if (slide.reference.trim().isNotEmpty)
                        _MarkedSlideText(
                          text: slide.reference,
                          marks: slide.referenceMarks,
                          style: TextStyle(
                            fontFamily: AppTypography.ui,
                            fontSize: headingSize * .34,
                            height: 1.3,
                            color: foreground.withValues(alpha: .5),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    PresentationSlideTemplate.image => Align(
      alignment: Alignment.bottomLeft,
      child: slide.caption.trim().isEmpty
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              padding: EdgeInsets.all(large ? 16 : 4),
              color: Colors.black.withValues(alpha: .45),
              child: _MarkedSlideText(
                text: slide.caption,
                marks: slide.captionMarks,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppTypography.ui,
                  fontSize: headingSize * .46,
                  color: Colors.white,
                ),
              ),
            ),
    ),
  };
}

class _PresentationImageFrame extends StatelessWidget {
  const _PresentationImageFrame({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      key: const Key('presentation-image-placeholder'),
      color: const Color(0xFFF4F2EC),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.image,
        size: 58,
        color: Color(0x5577736B),
      ),
    );
    final imagePath = path;
    if (imagePath == null || imagePath.trim().isEmpty) return placeholder;
    return ClipRect(
      child: Image.file(
        File(imagePath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _LargeContentsSlide extends StatelessWidget {
  const _LargeContentsSlide({
    required this.slide,
    required this.foreground,
    required this.headingSize,
    required this.large,
  });

  final PresentationSlide slide;
  final Color foreground;
  final double headingSize;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final items = presentationVisibleItems(
      slide.items,
      slide.itemMarks,
    ).take(5).toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: EdgeInsets.only(bottom: large ? 24 : 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: large ? 68 : 16,
                    child: Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: TextStyle(
                        fontFamily: AppTypography.ui,
                        fontSize: headingSize * .42,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                        color: foreground.withValues(alpha: .38),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _MarkedSlideText(
                      text: items[index].text,
                      marks: items[index].marks,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTypography.ui,
                        fontSize: headingSize * .82,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                        color: foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CanvasHeading extends StatelessWidget {
  const _CanvasHeading(this.text, this.marks, this.size, this.color);
  final String text;
  final List<InlineMark> marks;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => text.trim().isEmpty
      ? const SizedBox.shrink()
      : _MarkedSlideText(
          text: text,
          marks: marks,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: AppTypography.ui,
            fontSize: size,
            height: 1.18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        );
}

class _MarkedSlideText extends StatelessWidget {
  const _MarkedSlideText({
    required this.text,
    required this.marks,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final List<InlineMark> marks;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => RichText(
    textAlign: textAlign ?? TextAlign.start,
    maxLines: maxLines,
    overflow: overflow ?? TextOverflow.clip,
    text: TextSpan(
      style: style,
      children: [
        for (final segment in presentationTextSegments(text, marks))
          TextSpan(
            text: segment.text,
            style: style.copyWith(
              fontWeight: segment.bold ? FontWeight.w700 : style.fontWeight,
              fontStyle: segment.italic ? FontStyle.italic : style.fontStyle,
              backgroundColor: segment.highlighted
                  ? AppColors.highlight.withValues(alpha: .68)
                  : null,
            ),
          ),
      ],
    ),
  );
}

class _PresentationEmpty extends StatelessWidget {
  const _PresentationEmpty({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          LucideIcons.galleryHorizontal,
          size: 24,
          color: Color(0x5577736B),
        ),
        const SizedBox(height: 14),
        Text(
          'Folie auswählen oder neue anlegen',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: .48),
          ),
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(LucideIcons.plus, size: 14),
          label: const Text('Neue Folie'),
        ),
      ],
    ),
  );
}

class _TemplatePickerDialog extends StatelessWidget {
  const _TemplatePickerDialog({this.smart = false});

  final bool smart;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 760,
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              smart ? 'Intelligente Folie hinzufügen' : 'Neue Folie',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              smart
                  ? 'Die markierten Inhalte werden passend zur Vorlage übernommen.'
                  : 'Vorlage auswählen',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: .5),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 16,
              runSpacing: 18,
              children: [
                for (final template in PresentationSlideTemplate.values)
                  SizedBox(
                    width: 210,
                    child: InkWell(
                      key: Key('presentation-template-${template.name}'),
                      onTap: () => Navigator.pop(context, template),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SlideCanvas(slide: _templatePreviewSlide(template)),
                          const SizedBox(height: 8),
                          Text(
                            _templateLabel(template),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

String _templateLabel(PresentationSlideTemplate template) => switch (template) {
  PresentationSlideTemplate.title => 'Titel',
  PresentationSlideTemplate.headingText => 'Überschrift & Text',
  PresentationSlideTemplate.headingBible => 'Überschrift & Bibeltext',
  PresentationSlideTemplate.contents => 'Inhaltsangabe',
  PresentationSlideTemplate.largeContents => 'Große Inhaltsangabe',
  PresentationSlideTemplate.headingImage => 'Überschrift & Bild',
  PresentationSlideTemplate.headingImageBible =>
    'Überschrift, Bild & Bibeltext',
  PresentationSlideTemplate.image => 'Bild',
};

bool _templateUsesImage(PresentationSlideTemplate template) =>
    template == PresentationSlideTemplate.image ||
    template == PresentationSlideTemplate.headingImage ||
    template == PresentationSlideTemplate.headingImageBible;

PresentationSlide _templatePreviewSlide(
  PresentationSlideTemplate template,
) => PresentationSlide(
  id: 'preview-${template.name}',
  template: template,
  title: switch (template) {
    PresentationSlideTemplate.title => 'Predigttitel',
    PresentationSlideTemplate.largeContents ||
    PresentationSlideTemplate.image => '',
    _ => 'Überschrift',
  },
  subtitle: template == PresentationSlideTemplate.title ? 'Johannes 15,4' : '',
  body: switch (template) {
    PresentationSlideTemplate.headingText => 'Ein kurzer Gedanke zur Predigt.',
    PresentationSlideTemplate.headingBible ||
    PresentationSlideTemplate.headingImageBible =>
      'Bleibt in mir und ich in euch.',
    _ => '',
  },
  reference:
      template == PresentationSlideTemplate.headingBible ||
          template == PresentationSlideTemplate.headingImageBible
      ? 'Johannes 15,4'
      : '',
  items:
      template == PresentationSlideTemplate.contents ||
          template == PresentationSlideTemplate.largeContents
      ? const ['Erster Punkt', 'Zweiter Punkt', 'Dritter Punkt']
      : const [],
  caption: template == PresentationSlideTemplate.image ? 'Bild' : '',
);
