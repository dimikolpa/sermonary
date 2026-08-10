import 'dart:math' as math;

import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class PresentationBibleTextPart {
  const PresentationBibleTextPart({required this.text, required this.marks});

  final String text;
  final List<InlineMark> marks;
}

List<PresentationBibleTextPart> splitPresentationBibleText(
  String text,
  List<InlineMark> marks, {
  int maxCharacters = 520,
}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const [PresentationBibleTextPart(text: '', marks: [])];
  }
  if (trimmed.length <= maxCharacters) {
    final leading = text.indexOf(trimmed);
    return [
      PresentationBibleTextPart(
        text: trimmed,
        marks: _marksForRange(marks, leading, leading + trimmed.length),
      ),
    ];
  }

  final parts = <PresentationBibleTextPart>[];
  var start = text.indexOf(RegExp(r'\S'));
  while (start >= 0 && start < text.length) {
    var end = math.min(start + maxCharacters, text.length);
    if (end < text.length) {
      final preferredStart = start + (maxCharacters * .58).round();
      var sentenceBoundary = -1;
      for (var index = end - 1; index >= preferredStart; index--) {
        if ('.!?;'.contains(text[index]) &&
            index + 1 < text.length &&
            RegExp(r'\s').hasMatch(text[index + 1])) {
          sentenceBoundary = index + 1;
          break;
        }
      }
      if (sentenceBoundary > start) {
        end = sentenceBoundary;
      } else {
        while (end > start && !RegExp(r'\s').hasMatch(text[end - 1])) {
          end--;
        }
        if (end == start) end = math.min(start + maxCharacters, text.length);
      }
    }
    while (end > start && RegExp(r'\s').hasMatch(text[end - 1])) {
      end--;
    }
    var visibleStart = start;
    while (visibleStart < end && RegExp(r'\s').hasMatch(text[visibleStart])) {
      visibleStart++;
    }
    parts.add(
      PresentationBibleTextPart(
        text: text.substring(visibleStart, end),
        marks: _marksForRange(marks, visibleStart, end),
      ),
    );
    start = end;
    while (start < text.length && RegExp(r'\s').hasMatch(text[start])) {
      start++;
    }
  }
  return parts;
}

List<PresentationSlide> paginatePresentationBibleSlide(
  PresentationSlide slide, {
  required String Function() createId,
  List<PresentationSlide> existingParts = const [],
}) {
  if (slide.template != PresentationSlideTemplate.headingBible) {
    return [
      slide.copyWith(
        clearContinuationGroupId: true,
        continuationIndex: 1,
        continuationCount: 1,
      ),
    ];
  }
  final parts = splitPresentationBibleText(
    slide.body,
    slide.bodyMarks,
    maxCharacters: slide.title.trim().isEmpty ? 640 : 520,
  );
  if (parts.length == 1) {
    return [
      slide.copyWith(
        body: parts.single.text,
        bodyMarks: parts.single.marks,
        clearContinuationGroupId: true,
        continuationIndex: 1,
        continuationCount: 1,
      ),
    ];
  }
  final groupId = slide.continuationGroupId ?? slide.id;
  return [
    for (var index = 0; index < parts.length; index++)
      slide
          .copyWith(
            body: parts[index].text,
            bodyMarks: parts[index].marks,
            continuationGroupId: groupId,
            continuationIndex: index + 1,
            continuationCount: parts.length,
          )
          .withId(
            index < existingParts.length
                ? existingParts[index].id
                : index == 0
                ? slide.id
                : createId(),
          ),
  ];
}

List<PresentationSlide> replaceAndPaginatePresentationBibleSlide(
  List<PresentationSlide> slides,
  PresentationSlide changed, {
  required String Function() createId,
}) {
  final groupId = changed.continuationGroupId;
  final existingParts =
      groupId == null
            ? slides.where((slide) => slide.id == changed.id).toList()
            : slides
                  .where((slide) => slide.continuationGroupId == groupId)
                  .toList()
        ..sort(
          (left, right) =>
              left.continuationIndex.compareTo(right.continuationIndex),
        );
  final groupIds = existingParts.map((slide) => slide.id).toSet();
  final insertionIndex = slides.indexWhere(
    (slide) => groupIds.contains(slide.id),
  );
  if (insertionIndex < 0) return slides;

  final updatedParts = [
    for (final part in existingParts)
      if (part.id == changed.id) changed else part,
  ];
  final combined = _combineParts(updatedParts);
  final source = changed.copyWith(
    body: combined.text,
    bodyMarks: combined.marks,
  );
  final replacements = paginatePresentationBibleSlide(
    source,
    createId: createId,
    existingParts: existingParts,
  );
  final result = [...slides]
    ..removeWhere((slide) => groupIds.contains(slide.id))
    ..insertAll(insertionIndex, replacements);
  return result;
}

PresentationBibleTextPart _combineParts(List<PresentationSlide> parts) {
  final text = StringBuffer();
  final marks = <InlineMark>[];
  for (final part in parts) {
    if (text.isNotEmpty) text.write(' ');
    final offset = text.length;
    text.write(part.body.trim());
    marks.addAll([
      for (final mark in part.bodyMarks)
        InlineMark(
          start: offset + mark.start,
          end: offset + mark.end,
          bold: mark.bold,
          italic: mark.italic,
          highlighted: mark.highlighted,
        ),
    ]);
  }
  return PresentationBibleTextPart(text: text.toString(), marks: marks);
}

List<InlineMark> _marksForRange(
  List<InlineMark> marks,
  int start,
  int end,
) => [
  for (final mark in marks)
    if (mark.end > start && mark.start < end)
      InlineMark(
        start: math.max(mark.start, start) - start,
        end: math.min(mark.end, end) - start,
        bold: mark.bold,
        italic: mark.italic,
        highlighted: mark.highlighted,
      ),
];

extension on PresentationSlide {
  PresentationSlide withId(String nextId) => PresentationSlide(
    id: nextId,
    template: template,
    title: title,
    subtitle: subtitle,
    body: body,
    reference: reference,
    items: items,
    imagePath: imagePath,
    caption: caption,
    anchor: anchor,
    titleMarks: titleMarks,
    subtitleMarks: subtitleMarks,
    bodyMarks: bodyMarks,
    referenceMarks: referenceMarks,
    itemMarks: itemMarks,
    captionMarks: captionMarks,
    continuationGroupId: continuationGroupId,
    continuationIndex: continuationIndex,
    continuationCount: continuationCount,
  );
}
