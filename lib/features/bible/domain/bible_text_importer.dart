class ImportedBibleText {
  const ImportedBibleText({
    required this.text,
    required this.firstVerse,
    required this.lastVerse,
  });

  final String text;
  final int firstVerse;
  final int lastVerse;

  String get verseRange =>
      firstVerse == lastVerse ? '$firstVerse' : '$firstVerse-$lastVerse';

  String withReference({
    required String book,
    required int chapter,
  }) => '$text $book $chapter: $verseRange';
}

class BibleTextImporter {
  ImportedBibleText? import(String source) {
    if (source.trim().isEmpty) return null;

    final verses = <int>[];
    // BibleServer footnotes such as "[10]" are removed. Textual additions in
    // square brackets are part of the Bible text and must be preserved.
    var text = source.replaceAll(RegExp(r'\[\s*\d+\s*\]'), '');
    text = text.replaceAllMapped(
      RegExp(
        r'(^|[\r\n\u2000-\u200B\u2028\u2029]|[.!?;:][ \t]+)(\d{1,3}):?[\u00A0\u202F \t]+',
        multiLine: true,
      ),
      (match) {
        verses.add(int.parse(match.group(2)!));
        final prefix = match.group(1) ?? '';
        if (prefix.isEmpty) return '';
        if (RegExp('[.!?;:]').hasMatch(prefix)) return prefix;
        return ' ';
      },
    );
    text = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (match) => match.group(1)!)
        .trim();

    if (text.isEmpty || verses.isEmpty) return null;
    return ImportedBibleText(
      text: text,
      firstVerse: verses.first,
      lastVerse: verses.last,
    );
  }
}
