import 'package:collection/collection.dart';

class BibleReference {
  const BibleReference({
    required this.bookId,
    required this.startChapter,
    required this.displayText,
    this.startVerse,
    this.endChapter,
    this.endVerse,
  });

  final String bookId;
  final int startChapter;
  final int? startVerse;
  final int? endChapter;
  final int? endVerse;
  final String displayText;

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'startChapter': startChapter,
    'startVerse': startVerse,
    'endChapter': endChapter,
    'endVerse': endVerse,
    'displayText': displayText,
  };

  factory BibleReference.fromJson(Map<String, Object?> json) => BibleReference(
    bookId: json['bookId']! as String,
    startChapter: json['startChapter']! as int,
    startVerse: json['startVerse'] as int?,
    endChapter: json['endChapter'] as int?,
    endVerse: json['endVerse'] as int?,
    displayText: json['displayText']! as String,
  );
}

class BibleReferenceParser {
  static const _books = <String, List<String>>{
    'john': ['joh', 'johannes'],
    'rom': ['röm', 'roem', 'römer', 'roemer'],
    '1cor': ['1kor', '1 kor', '1. kor', '1. korinther', '1 korinther'],
    'matt': ['mt', 'matthäus', 'matthaeus'],
    'rev': ['offb', 'offenbarung'],
  };

  BibleReference? parse(String input) {
    final normalized = input
        .trim()
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'^(.+?)\s*(\d+)(?:\s*,\s*(\d+))?(?:\s*-\s*(?:(\d+)\s*,\s*)?(\d+))?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final rawBook = match.group(1)!.trim().toLowerCase();
    final entry = _books.entries.firstWhereOrNull(
      (candidate) => candidate.value.contains(rawBook),
    );
    if (entry == null) return null;
    final startChapter = int.parse(match.group(2)!);
    final startVerse = int.tryParse(match.group(3) ?? '');
    final explicitEndChapter = int.tryParse(match.group(4) ?? '');
    final endValue = int.tryParse(match.group(5) ?? '');
    return BibleReference(
      bookId: entry.key,
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: explicitEndChapter,
      endVerse: endValue,
      displayText: input.trim().replaceAll('-', '–'),
    );
  }
}
