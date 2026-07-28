import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class OutlineEntry {
  const OutlineEntry({
    required this.blockId,
    required this.title,
    required this.level,
    required this.wordCount,
    required this.estimatedMinutes,
  });
  final String blockId;
  final String title;
  final int level;
  final int wordCount;
  final double estimatedMinutes;
}

List<OutlineEntry> buildOutline(
  SermonDocument document, {
  int wordsPerMinute = 120,
}) {
  final entries = <OutlineEntry>[];
  for (var index = 0; index < document.blocks.length; index++) {
    final block = document.blocks[index];
    final level = switch (block) {
      TitleBlock() => 0,
      HeadingBlock(:final level) => level,
      BulletListBlock() => 1,
      _ => null,
    };
    if (level == null || block.plainText.trim().isEmpty) continue;
    final nextHeading = document.blocks
        .skip(index + 1)
        .toList()
        .indexWhere(
          (candidate) => candidate is HeadingBlock || candidate is TitleBlock,
        );
    final end = nextHeading < 0
        ? document.blocks.length
        : index + 1 + nextHeading;
    final words = document.blocks
        .sublist(index, end)
        .fold(0, (sum, item) => sum + countWords(item.plainText));
    entries.add(
      OutlineEntry(
        blockId: block.id,
        title: block is BulletListBlock
            ? block.plainText.split('\n').first
            : block.plainText,
        level: level,
        wordCount: words,
        estimatedMinutes: words / wordsPerMinute,
      ),
    );
  }
  return entries;
}
