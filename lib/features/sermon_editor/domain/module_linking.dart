import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class ModuleLinkConflict implements Exception {
  const ModuleLinkConflict(this.message, {this.headings = const []});

  final String message;
  final List<String> headings;

  @override
  String toString() => message;
}

class ModuleLinkingService {
  const ModuleLinkingService();

  SermonDocument link({
    required SermonDocument document,
    required String sourceModuleId,
    required String targetModuleId,
    required String Function() createGroupId,
    required DateTime now,
  }) {
    final source = document.moduleById(sourceModuleId);
    final target = document.moduleById(targetModuleId);
    if (source == null || target == null) {
      throw const ModuleLinkConflict('Der Inhalt wurde nicht gefunden.');
    }
    if (source.id == target.id ||
        document.modulesAreLinked(source.id, target.id)) {
      return document;
    }
    final sourceMembers = _members(document, source);
    final targetMembers = _members(document, target);
    final joiningIds = {
      ...sourceMembers.map((module) => module.id),
      ...targetMembers.map((module) => module.id),
    };
    final textModules = document.effectiveModules
        .where(
          (module) =>
              joiningIds.contains(module.id) &&
              module.kind != SermonModuleKind.presentation,
        )
        .toList(growable: false);
    final merge = _mergeHeadings(document, textModules);
    final groupId = target.linkGroupId ?? source.linkGroupId ?? createGroupId();
    final modules = [
      for (final module in document.effectiveModules)
        if (joiningIds.contains(module.id))
          module.copyWith(
            linkGroupId: groupId,
            blockIds: module.kind == SermonModuleKind.presentation
                ? module.blockIds
                : _applyHeadingOrder(
                    document,
                    module,
                    merge.canonicalIds,
                    merge.replacements,
                  ),
            updatedAt: now,
          )
        else
          module,
    ];
    final replacedHeadingIds = merge.replacements.keys.toSet();
    final stillReferencedIds = modules
        .expand((module) => module.blockIds)
        .toSet();
    final blocks = [
      for (final block in document.blocks)
        if (!replacedHeadingIds.contains(block.id) ||
            stillReferencedIds.contains(block.id))
          block,
    ];
    return SermonDocument(
      schemaVersion: SermonDocument.currentSchemaVersion,
      blocks: blocks,
      presentation: document.presentation,
      modules: modules,
    );
  }

  SermonDocument unlink({
    required SermonDocument document,
    required String moduleId,
    required String Function() createBlockId,
    required DateTime now,
  }) {
    final module = document.moduleById(moduleId);
    final groupId = module?.linkGroupId;
    if (module == null || groupId == null) return document;
    final byId = {for (final block in document.blocks) block.id: block};
    final clonedBlocks = <DocumentBlock>[];
    final replacements = <String, String>{};
    for (final id in module.blockIds) {
      final block = byId[id];
      if (block is! HeadingBlock) continue;
      final nextId = createBlockId();
      replacements[id] = nextId;
      clonedBlocks.add(
        HeadingBlock(
          id: nextId,
          level: block.level,
          text: block.text,
          collapsed: block.collapsed,
          createdAt: block.createdAt,
          updatedAt: now,
        ),
      );
    }
    var modules = [
      for (final candidate in document.effectiveModules)
        if (candidate.id == module.id)
          candidate.copyWith(
            clearLinkGroupId: true,
            blockIds: [
              for (final id in candidate.blockIds) replacements[id] ?? id,
            ],
            updatedAt: now,
          )
        else
          candidate,
    ];
    final remaining = modules
        .where((candidate) => candidate.linkGroupId == groupId)
        .toList(growable: false);
    if (remaining.length == 1) {
      modules = [
        for (final candidate in modules)
          if (candidate.id == remaining.single.id)
            candidate.copyWith(clearLinkGroupId: true, updatedAt: now)
          else
            candidate,
      ];
    }
    final detachedSlideIds = module.slideIds.toSet();
    final presentation = PresentationDeck(
      slides: [
        for (final slide in document.presentation.slides)
          if (detachedSlideIds.contains(slide.id) ||
              slide.anchor?.moduleId == module.id)
            slide.copyWith(clearAnchor: true)
          else
            slide,
      ],
    );
    return SermonDocument(
      schemaVersion: SermonDocument.currentSchemaVersion,
      blocks: [...document.blocks, ...clonedBlocks],
      presentation: presentation,
      modules: modules,
    );
  }

  List<SermonModule> _members(SermonDocument document, SermonModule module) {
    final groupId = module.linkGroupId;
    if (groupId == null) return [module];
    return document.effectiveModules
        .where((candidate) => candidate.linkGroupId == groupId)
        .toList(growable: false);
  }

  _HeadingMerge _mergeHeadings(
    SermonDocument document,
    List<SermonModule> modules,
  ) {
    final blocksById = {for (final block in document.blocks) block.id: block};
    final canonicalByKey = <String, HeadingBlock>{};
    final levelByText = <String, int>{};
    final replacements = <String, String>{};
    final sequences = <List<String>>[];
    for (final module in modules) {
      final seen = <String>{};
      final sequence = <String>[];
      for (final id in module.blockIds) {
        final block = blocksById[id];
        if (block is! HeadingBlock) continue;
        final textKey = _normalize(block.text);
        final existingLevel = levelByText[textKey];
        if (existingLevel != null && existingLevel != block.level) {
          throw ModuleLinkConflict(
            'Die Überschrift „${block.text}“ besitzt unterschiedliche Ebenen.',
            headings: [block.text],
          );
        }
        levelByText[textKey] = block.level;
        final key = '${block.level}|$textKey';
        if (!seen.add(key)) {
          throw ModuleLinkConflict(
            'Die Überschrift „${block.text}“ kommt mehrfach vor und kann nicht eindeutig zugeordnet werden.',
            headings: [block.text],
          );
        }
        final canonical = canonicalByKey[key];
        if (canonical == null) {
          canonicalByKey[key] = block;
        } else if (canonical.text.trim() != block.text.trim()) {
          throw ModuleLinkConflict(
            'Die Überschriften „${canonical.text}“ und „${block.text}“ sind nicht eindeutig identisch.',
            headings: [canonical.text, block.text],
          );
        } else if (canonical.id != block.id) {
          replacements[block.id] = canonical.id;
        }
        sequence.add(key);
      }
      sequences.add(sequence);
    }
    final edges = <String, Set<String>>{};
    final indegree = <String, int>{
      for (final key in canonicalByKey.keys) key: 0,
    };
    for (final sequence in sequences) {
      for (var index = 0; index + 1 < sequence.length; index++) {
        final before = sequence[index];
        final after = sequence[index + 1];
        final targets = edges.putIfAbsent(before, () => <String>{});
        if (targets.add(after)) indegree[after] = (indegree[after] ?? 0) + 1;
      }
    }
    final preferred = canonicalByKey.keys.toList(growable: false);
    final available = preferred
        .where((key) => indegree[key] == 0)
        .toList(growable: true);
    final mergedKeys = <String>[];
    while (available.isNotEmpty) {
      available.sort(
        (a, b) => preferred.indexOf(a).compareTo(preferred.indexOf(b)),
      );
      final key = available.removeAt(0);
      mergedKeys.add(key);
      for (final next in edges[key] ?? const <String>{}) {
        indegree[next] = indegree[next]! - 1;
        if (indegree[next] == 0) available.add(next);
      }
    }
    if (mergedKeys.length != canonicalByKey.length) {
      throw const ModuleLinkConflict(
        'Die Reihenfolge der Überschriften widerspricht sich.',
      );
    }
    return _HeadingMerge(
      canonicalIds: [for (final key in mergedKeys) canonicalByKey[key]!.id],
      replacements: replacements,
    );
  }

  List<String> _applyHeadingOrder(
    SermonDocument document,
    SermonModule module,
    List<String> canonicalHeadingIds,
    Map<String, String> replacements,
  ) {
    final blocksById = {for (final block in document.blocks) block.id: block};
    final ids = [for (final id in module.blockIds) replacements[id] ?? id];
    final existingHeadings = ids
        .where((id) => blocksById[id] is HeadingBlock)
        .toSet();
    for (var index = 0; index < canonicalHeadingIds.length; index++) {
      final headingId = canonicalHeadingIds[index];
      if (existingHeadings.contains(headingId)) continue;
      var insertionIndex = ids.length;
      for (final later in canonicalHeadingIds.skip(index + 1)) {
        final found = ids.indexOf(later);
        if (found >= 0) {
          insertionIndex = found;
          break;
        }
      }
      ids.insert(insertionIndex, headingId);
      existingHeadings.add(headingId);
    }
    return ids;
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

class _HeadingMerge {
  const _HeadingMerge({
    required this.canonicalIds,
    required this.replacements,
  });

  final List<String> canonicalIds;
  final Map<String, String> replacements;
}
