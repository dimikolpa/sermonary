import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/sermon_editor/domain/raw_outline_logic.dart';

void main() {
  const lines = [
    RawLine(id: 'a', text: 'A', depth: 0, collapsed: false),
    RawLine(id: 'b', text: 'B', depth: 0, collapsed: false),
    RawLine(id: 'c', text: 'C', depth: 0, collapsed: false),
  ];

  test('indent and outdent preserve stable IDs', () {
    final indented = indentRawLine(lines, 1);
    expect(indented[1].id, 'b');
    expect(indented[1].depth, 1);
    final tree = buildBulletTree(indented);
    expect(tree.first.children.single.id, 'b');
    expect(flattenBulletItems(tree).map((line) => line.id), ['a', 'b', 'c']);
    expect(outdentRawLine(indented, 1)[1].depth, 0);
  });

  test('move changes order without changing content', () {
    final moved = moveRawLine(lines, 1, -1);
    expect(moved.map((line) => line.id), ['b', 'a', 'c']);
  });
}
