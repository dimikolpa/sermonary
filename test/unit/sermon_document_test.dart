import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/sermon_editor/domain/outline.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  final now = DateTime.utc(2026, 7, 28);

  test('SermonDocument JSON roundtrip preserves typed blocks', () {
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'heading',
          level: 1,
          text: 'Gnade',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'paragraph',
          text: 'Gnade trägt durch jeden neuen Tag.',
          semanticRole: ParagraphRole.application,
          isBold: true,
          marks: const [
            InlineMark(start: 0, end: 5, bold: true),
            InlineMark(start: 6, end: 11, highlighted: true),
          ],
          createdAt: now,
          updatedAt: now,
        ),
        NoteBlock(
          id: 'note',
          text: 'Pause',
          visibility: NoteVisibility.editorOnly,
          depth: 1,
          marks: const [InlineMark(start: 0, end: 5, italic: true)],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );

    final encoded = jsonEncode(document.toJson());
    final decoded = SermonDocument.fromJson(
      jsonDecode(encoded) as Map<String, Object?>,
    );

    expect(decoded.schemaVersion, 1);
    expect(decoded.blocks, hasLength(3));
    expect(decoded.blocks[1], isA<ParagraphBlock>());
    expect((decoded.blocks[1] as ParagraphBlock).isBold, isTrue);
    expect((decoded.blocks[1] as ParagraphBlock).marks, hasLength(2));
    expect((decoded.blocks[2] as NoteBlock).depth, 1);
    expect((decoded.blocks[2] as NoteBlock).marks.single.italic, isTrue);
    expect(jsonEncode(decoded.toJson()), encoded);
  });

  test('version 1 migration is a no-op', () {
    const document = SermonDocument(schemaVersion: 1, blocks: []);
    final migrated = const V1DocumentMigrator().migrate(
      document,
      fromVersion: 1,
      toVersion: 1,
    );
    expect(identical(document, migrated), isTrue);
  });

  test('word count, duration and outline use structured content', () {
    final document = SermonDocument(
      schemaVersion: 1,
      blocks: [
        HeadingBlock(
          id: 'h',
          level: 1,
          text: 'Erster Punkt',
          collapsed: false,
          createdAt: now,
          updatedAt: now,
        ),
        ParagraphBlock(
          id: 'p',
          text: 'Eins zwei drei vier fünf sechs',
          semanticRole: ParagraphRole.normal,
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    expect(document.wordCount, 8);
    expect(document.estimatedDuration().inSeconds, 4);
    final outline = buildOutline(document);
    expect(outline.single.title, 'Erster Punkt');
    expect(outline.single.wordCount, 8);
  });
}
