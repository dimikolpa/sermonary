import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

class RawLine {
  const RawLine({
    required this.id,
    required this.text,
    required this.depth,
    required this.collapsed,
    this.semanticRole,
  });
  final String id;
  final String text;
  final int depth;
  final bool collapsed;
  final ParagraphRole? semanticRole;

  RawLine copyWith({String? text, int? depth, bool? collapsed}) => RawLine(
    id: id,
    text: text ?? this.text,
    depth: depth ?? this.depth,
    collapsed: collapsed ?? this.collapsed,
    semanticRole: semanticRole,
  );
}

List<RawLine> flattenBulletItems(
  List<BulletItem> items, [
  int depth = 0,
]) => [
  for (final item in items) ...[
    RawLine(
      id: item.id,
      text: item.text,
      depth: depth,
      collapsed: item.collapsed,
      semanticRole: item.semanticRole,
    ),
    ...flattenBulletItems(item.children, depth + 1),
  ],
];

List<BulletItem> buildBulletTree(List<RawLine> lines) {
  final roots = <_MutableBullet>[];
  final stack = <_MutableBullet>[];
  for (final line in lines) {
    final node = _MutableBullet(line);
    final depth = line.depth.clamp(0, stack.length);
    if (depth == 0) {
      roots.add(node);
    } else {
      stack[depth - 1].children.add(node);
    }
    if (stack.length > depth) stack.removeRange(depth, stack.length);
    stack.add(node);
  }
  return roots.map((node) => node.freeze()).toList(growable: false);
}

List<RawLine> indentRawLine(List<RawLine> lines, int index) {
  if (index <= 0 || index >= lines.length) return lines;
  final maxDepth = lines[index - 1].depth + 1;
  final current = lines[index];
  if (current.depth >= maxDepth) return lines;
  return [
    ...lines.take(index),
    current.copyWith(depth: current.depth + 1),
    ...lines.skip(index + 1),
  ];
}

List<RawLine> outdentRawLine(List<RawLine> lines, int index) {
  if (index < 0 || index >= lines.length || lines[index].depth == 0) {
    return lines;
  }
  final currentDepth = lines[index].depth;
  final result = [...lines];
  result[index] = result[index].copyWith(depth: currentDepth - 1);
  var cursor = index + 1;
  while (cursor < result.length && result[cursor].depth > currentDepth) {
    result[cursor] = result[cursor].copyWith(depth: result[cursor].depth - 1);
    cursor++;
  }
  return result;
}

List<RawLine> moveRawLine(List<RawLine> lines, int index, int offset) {
  final target = index + offset;
  if (index < 0 ||
      index >= lines.length ||
      target < 0 ||
      target >= lines.length) {
    return lines;
  }
  final result = [...lines];
  final item = result.removeAt(index);
  result.insert(target, item);
  return result;
}

class _MutableBullet {
  _MutableBullet(this.line);
  final RawLine line;
  final children = <_MutableBullet>[];
  BulletItem freeze() => BulletItem(
    id: line.id,
    text: line.text,
    semanticRole: line.semanticRole,
    collapsed: line.collapsed,
    children: children.map((node) => node.freeze()).toList(growable: false),
  );
}
