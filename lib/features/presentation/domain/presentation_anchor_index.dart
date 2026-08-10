import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class PresentationAnchorReference {
  const PresentationAnchorReference({
    required this.slide,
    required this.number,
    required this.blockId,
    required this.offset,
  });

  final PresentationSlide slide;
  final int number;
  final String blockId;
  final int offset;
}

/// Resolves presentation anchors into the coordinate system of one Notes or
/// Script module. This keeps editor, Live mode and exports consistent when a
/// slide was originally anchored in another linked module.
List<PresentationAnchorReference> presentationAnchorsForModule(
  SermonDocument document,
  String moduleId,
) {
  final target = document.moduleById(moduleId);
  if (target == null || target.kind == SermonModuleKind.presentation) {
    return const [];
  }
  final linkedSlideIds = document.effectiveModules
      .where(
        (module) =>
            module.kind == SermonModuleKind.presentation &&
            document.modulesAreLinked(module.id, target.id),
      )
      .expand((module) => module.slideIds)
      .toSet();
  final hasPresentationModules = document.effectiveModules.any(
    (module) => module.kind == SermonModuleKind.presentation,
  );
  // Scoped export documents intentionally contain only the selected text
  // module while retaining its linked slides. In that case all deck slides
  // belong to the selected content.
  final slides =
      !hasPresentationModules ||
          document.schemaVersion < SermonDocument.currentSchemaVersion
      ? document.presentation.slides
      : document.presentation.slides
            .where((slide) => linkedSlideIds.contains(slide.id))
            .toList(growable: false);
  final targetBlocks = document.blocksForModule(target.id);
  final result = <PresentationAnchorReference>[];
  for (var index = 0; index < slides.length; index++) {
    final slide = slides[index];
    final anchor = slide.anchor;
    if (anchor == null) continue;
    final resolved = _anchorForTarget(document, anchor, target, targetBlocks);
    if (resolved == null) continue;
    result.add(
      PresentationAnchorReference(
        slide: slide,
        number: index + 1,
        blockId: resolved.$1,
        offset: resolved.$2,
      ),
    );
  }
  return List.unmodifiable(result);
}

(String, int)? _anchorForTarget(
  SermonDocument document,
  PresentationAnchor anchor,
  SermonModule target,
  List<DocumentBlock> targetBlocks,
) {
  if (target.blockIds.contains(anchor.blockId)) {
    return (anchor.blockId, anchor.offset);
  }
  final source = anchor.moduleId == null
      ? null
      : document.moduleById(anchor.moduleId!);
  if (source == null || !document.modulesAreLinked(source.id, target.id)) {
    return null;
  }
  final anchorIndex = source.blockIds.indexOf(anchor.blockId);
  if (anchorIndex < 0) return null;
  for (var index = anchorIndex; index >= 0; index--) {
    final sourceBlockId = source.blockIds[index];
    final sourceBlock = document.blocks
        .where((block) => block.id == sourceBlockId)
        .firstOrNull;
    if (sourceBlock is! HeadingBlock) continue;
    if (targetBlocks.any((block) => block.id == sourceBlock.id)) {
      return (sourceBlock.id, sourceBlock.text.length);
    }
  }
  if (targetBlocks.isEmpty) return null;
  return (targetBlocks.first.id, 0);
}

Map<String, List<PresentationAnchorReference>>
presentationAnchorsByBlockForModule(
  SermonDocument document,
  String moduleId,
) {
  final result = <String, List<PresentationAnchorReference>>{};
  for (final reference in presentationAnchorsForModule(document, moduleId)) {
    result.putIfAbsent(reference.blockId, () => []).add(reference);
  }
  return Map.unmodifiable({
    for (final entry in result.entries)
      entry.key: List<PresentationAnchorReference>.unmodifiable(entry.value),
  });
}
