import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

/// Resolves user-entered Bible passages to a complete, canonical verse range.
///
/// Besides explicit passages such as `2,3-5`, this accepts chapter shorthand:
/// `3`, `3-5`, and `6-8,2`. Missing verse boundaries are resolved against the
/// installed Bible translation rather than a hard-coded chapter-length table.
class BiblePassageNormalizer {
  const BiblePassageNormalizer(this._provider);

  static const defaultTranslationId = 'elb85';

  final BibleProvider _provider;

  Future<BibleReference?> normalize({
    required String bookId,
    required String passage,
    String translationId = defaultTranslationId,
  }) async {
    final book = BibleBookCatalog.byId(bookId);
    if (book == null) return null;

    final normalized = _normalizeInput(passage);
    if (normalized.isEmpty) return null;

    final explicit = BibleReferenceParser().parsePassage(
      '${book.label} $normalized',
    );
    if (explicit != null) {
      return await _isValid(explicit, translationId) ? explicit : null;
    }

    final shorthand = RegExp(
      r'^(\d+)(?:\s*-\s*(\d+)(?:\s*[:,]\s*(\d+))?)?$',
    ).firstMatch(normalized);
    if (shorthand == null) return null;

    final startChapter = int.parse(shorthand.group(1)!);
    final endChapter = int.tryParse(shorthand.group(2) ?? '') ?? startChapter;
    final explicitEndVerse = int.tryParse(shorthand.group(3) ?? '');
    if (startChapter < 1 || endChapter < startChapter) return null;

    final chapters = await _provider.listChapters(translationId, bookId);
    if (!chapters.contains(startChapter) || !chapters.contains(endChapter)) {
      return null;
    }

    final endVerses = await _provider.listVerses(
      translationId,
      bookId,
      endChapter,
    );
    if (endVerses.isEmpty) return null;
    final endVerse = explicitEndVerse ?? endVerses.last;
    if (!endVerses.contains(endVerse)) return null;

    return _completeReference(
      bookId: bookId,
      startChapter: startChapter,
      startVerse: 1,
      endChapter: endChapter,
      endVerse: endVerse,
    );
  }

  Future<bool> _isValid(
    BibleReference reference,
    String translationId,
  ) async {
    final endChapter = reference.endChapter ?? reference.startChapter;
    final startVerse = reference.startVerse;
    final endVerse = reference.endVerse;
    if (startVerse == null || endVerse == null) return false;

    final chapters = await _provider.listChapters(
      translationId,
      reference.bookId,
    );
    if (!chapters.contains(reference.startChapter) ||
        !chapters.contains(endChapter)) {
      return false;
    }
    final startVerses = await _provider.listVerses(
      translationId,
      reference.bookId,
      reference.startChapter,
    );
    if (!startVerses.contains(startVerse)) return false;
    final endVerses = endChapter == reference.startChapter
        ? startVerses
        : await _provider.listVerses(
            translationId,
            reference.bookId,
            endChapter,
          );
    return endVerses.contains(endVerse);
  }

  BibleReference _completeReference({
    required String bookId,
    required int startChapter,
    required int startVerse,
    required int endChapter,
    required int endVerse,
  }) {
    final reference = BibleReference(
      bookId: bookId,
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: endChapter,
      endVerse: endVerse,
      displayText: '',
    );
    return BibleReference(
      bookId: reference.bookId,
      startChapter: reference.startChapter,
      startVerse: reference.startVerse,
      endChapter: reference.endChapter,
      endVerse: reference.endVerse,
      displayText: formatBibleReference(reference),
    );
  }

  String _normalizeInput(String input) => input
      .trim()
      .replaceAll('â', '-')
      .replaceAll('â', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(RegExp(r'\s+'), ' ');
}
