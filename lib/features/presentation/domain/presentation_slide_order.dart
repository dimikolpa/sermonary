import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

/// Keeps anchored slides in text order while preserving every unanchored
/// slide at the position chosen by the user.
List<PresentationSlide> orderPresentationSlidesByText({
  required SermonDocument document,
  required List<PresentationSlide> slides,
}) {
  if (slides.length < 2) return List.unmodifiable(slides);
  final originalIndex = <String, int>{
    for (var index = 0; index < slides.length; index++) slides[index].id: index,
  };
  final moduleOrder = <String, int>{
    for (var index = 0; index < document.effectiveModules.length; index++)
      document.effectiveModules[index].id: index,
  };

  ({int module, int block, int offset}) position(PresentationSlide slide) {
    final anchor = slide.anchor;
    final source = anchor == null
        ? null
        : anchor.moduleId == null
        ? document.effectiveModules
              .where((module) => module.blockIds.contains(anchor.blockId))
              .firstOrNull
        : document.moduleById(anchor.moduleId!);
    final blockIndex = source?.blockIds.indexOf(anchor!.blockId) ?? -1;
    return (
      module: source == null ? 1 << 30 : moduleOrder[source.id] ?? 1 << 29,
      block: blockIndex < 0 ? 1 << 30 : blockIndex,
      offset: anchor?.offset ?? 0,
    );
  }

  final anchored = slides.where((slide) => slide.anchor != null).toList()
    ..sort((left, right) {
      final leftPosition = position(left);
      final rightPosition = position(right);
      var comparison = leftPosition.module.compareTo(rightPosition.module);
      if (comparison != 0) return comparison;
      comparison = leftPosition.block.compareTo(rightPosition.block);
      if (comparison != 0) return comparison;
      comparison = leftPosition.offset.compareTo(rightPosition.offset);
      if (comparison != 0) return comparison;
      comparison = left.continuationIndex.compareTo(right.continuationIndex);
      if (comparison != 0) return comparison;
      return originalIndex[left.id]!.compareTo(originalIndex[right.id]!);
    });

  var anchoredIndex = 0;
  return List.unmodifiable([
    for (final slide in slides)
      if (slide.anchor == null) slide else anchored[anchoredIndex++],
  ]);
}
