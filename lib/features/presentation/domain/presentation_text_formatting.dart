import 'dart:math' as math;

import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

enum PresentationTextFormat { bold, italic, highlight }

class PresentationTextSegment {
  const PresentationTextSegment({
    required this.text,
    required this.bold,
    required this.italic,
    required this.highlighted,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool highlighted;
}

class PresentationTextItem {
  const PresentationTextItem({required this.text, required this.marks});

  final String text;
  final List<InlineMark> marks;
}

List<PresentationTextItem> presentationVisibleItems(
  List<String> items,
  List<List<InlineMark>> itemMarks,
) => [
  for (var index = 0; index < items.length; index++)
    if (items[index].trim().isNotEmpty)
      PresentationTextItem(
        text: items[index],
        marks: index < itemMarks.length ? itemMarks[index] : const [],
      ),
];

List<PresentationTextSegment> presentationTextSegments(
  String text,
  List<InlineMark> marks,
) {
  if (text.isEmpty) return const [];
  final boundaries = <int>{0, text.length};
  for (final mark in marks) {
    boundaries
      ..add(mark.start.clamp(0, text.length))
      ..add(mark.end.clamp(0, text.length));
  }
  final sorted = boundaries.toList()..sort();
  return [
    for (var index = 0; index < sorted.length - 1; index++)
      if (sorted[index] < sorted[index + 1])
        PresentationTextSegment(
          text: text.substring(sorted[index], sorted[index + 1]),
          bold: marks.any(
            (mark) =>
                mark.bold &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
          italic: marks.any(
            (mark) =>
                mark.italic &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
          highlighted: marks.any(
            (mark) =>
                mark.highlighted &&
                mark.start <= sorted[index] &&
                mark.end >= sorted[index + 1],
          ),
        ),
  ];
}

bool presentationFormatAtCaret(
  List<InlineMark> marks,
  PresentationTextFormat format,
  int offset,
) => marks.any((mark) {
  final touches =
      (mark.start < offset && offset <= mark.end) ||
      (offset == 0 && mark.start == 0 && mark.end > 0);
  return touches && _hasFormat(mark, format);
});

bool presentationFormatCoversRange(
  List<InlineMark> marks,
  PresentationTextFormat format,
  int start,
  int end,
) {
  if (start >= end) return false;
  for (var offset = start; offset < end; offset++) {
    if (!marks.any(
      (mark) =>
          _hasFormat(mark, format) && mark.start <= offset && mark.end > offset,
    )) {
      return false;
    }
  }
  return true;
}

List<InlineMark> setPresentationFormat(
  List<InlineMark> marks, {
  required PresentationTextFormat format,
  required int start,
  required int end,
  required bool enabled,
}) {
  if (start >= end) return marks;
  final boundaries = <int>{start, end};
  for (final mark in marks) {
    boundaries
      ..add(mark.start)
      ..add(mark.end);
  }
  final sorted = boundaries.where((value) => value >= 0).toList()..sort();
  final result = <InlineMark>[];
  for (var index = 0; index < sorted.length - 1; index++) {
    final segmentStart = sorted[index];
    final segmentEnd = sorted[index + 1];
    if (segmentStart == segmentEnd) continue;
    final covering = marks.where(
      (mark) => mark.start <= segmentStart && mark.end >= segmentEnd,
    );
    var bold = covering.any((mark) => mark.bold);
    var italic = covering.any((mark) => mark.italic);
    var highlighted = covering.any((mark) => mark.highlighted);
    if (segmentStart < end && segmentEnd > start) {
      switch (format) {
        case PresentationTextFormat.bold:
          bold = enabled;
        case PresentationTextFormat.italic:
          italic = enabled;
        case PresentationTextFormat.highlight:
          highlighted = enabled;
      }
    }
    if (bold || italic || highlighted) {
      result.add(
        InlineMark(
          start: segmentStart,
          end: segmentEnd,
          bold: bold,
          italic: italic,
          highlighted: highlighted,
        ),
      );
    }
  }
  return _coalesce(result);
}

List<InlineMark> adjustPresentationMarks(
  List<InlineMark> marks, {
  required String oldText,
  required String newText,
}) {
  if (marks.isEmpty || oldText == newText) return marks;
  var start = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (start < sharedLength &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var suffix = 0;
  while (suffix < oldText.length - start &&
      suffix < newText.length - start &&
      oldText.codeUnitAt(oldText.length - suffix - 1) ==
          newText.codeUnitAt(newText.length - suffix - 1)) {
    suffix++;
  }
  final oldEnd = oldText.length - suffix;
  final newEnd = newText.length - suffix;
  final delta = newEnd - oldEnd;
  final adjusted = <InlineMark>[];
  for (final mark in marks) {
    final next = _adjustMark(
      mark,
      start,
      oldEnd,
      newEnd,
      delta,
      newText.length,
    );
    if (next != null) adjusted.add(next);
  }
  return _coalesce(adjusted);
}

({int start, int oldEnd, int newEnd}) presentationChangedTextRange(
  String oldText,
  String newText,
) {
  var start = 0;
  final sharedLength = math.min(oldText.length, newText.length);
  while (start < sharedLength &&
      oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
    start++;
  }
  var suffix = 0;
  while (suffix < oldText.length - start &&
      suffix < newText.length - start &&
      oldText.codeUnitAt(oldText.length - suffix - 1) ==
          newText.codeUnitAt(newText.length - suffix - 1)) {
    suffix++;
  }
  return (
    start: start,
    oldEnd: oldText.length - suffix,
    newEnd: newText.length - suffix,
  );
}

InlineMark? _adjustMark(
  InlineMark mark,
  int changeStart,
  int oldEnd,
  int newEnd,
  int delta,
  int newLength,
) {
  var start = mark.start;
  var end = mark.end;
  if (end <= changeStart) {
    // The change is after this mark.
  } else if (start >= oldEnd) {
    start += delta;
    end += delta;
  } else {
    start = math.min(start, changeStart);
    end = end > oldEnd ? end + delta : newEnd;
  }
  start = start.clamp(0, newLength);
  end = end.clamp(start, newLength);
  if (start == end) return null;
  return InlineMark(
    start: start,
    end: end,
    bold: mark.bold,
    italic: mark.italic,
    highlighted: mark.highlighted,
  );
}

bool _hasFormat(InlineMark mark, PresentationTextFormat format) =>
    switch (format) {
      PresentationTextFormat.bold => mark.bold,
      PresentationTextFormat.italic => mark.italic,
      PresentationTextFormat.highlight => mark.highlighted,
    };

List<InlineMark> _coalesce(List<InlineMark> marks) {
  final sorted = [...marks]
    ..sort((left, right) {
      final start = left.start.compareTo(right.start);
      return start != 0 ? start : left.end.compareTo(right.end);
    });
  final result = <InlineMark>[];
  for (final mark in sorted) {
    if (result.isNotEmpty) {
      final previous = result.last;
      if (previous.end == mark.start &&
          previous.bold == mark.bold &&
          previous.italic == mark.italic &&
          previous.highlighted == mark.highlighted) {
        result[result.length - 1] = InlineMark(
          start: previous.start,
          end: mark.end,
          bold: mark.bold,
          italic: mark.italic,
          highlighted: mark.highlighted,
        );
        continue;
      }
    }
    result.add(mark);
  }
  return result;
}
