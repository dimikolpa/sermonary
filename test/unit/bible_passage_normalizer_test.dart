import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/bible/application/bible_passage_normalizer.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

void main() {
  const provider = _ChapterProvider({
    'gen': {16: 16, 17: 27},
    'zech': {3: 10, 4: 14, 5: 11},
    'rev': {6: 17, 7: 17, 8: 13},
  });
  const normalizer = BiblePassageNormalizer(provider);

  test('expands a chapter range to the final verse', () async {
    final reference = await normalizer.normalize(
      bookId: 'gen',
      passage: '16–17',
    );

    expect(formatBibleReference(reference!, includeBook: false), '16,1-17,27');
  });

  test('expands a single chapter to its complete range', () async {
    final reference = await normalizer.normalize(
      bookId: 'zech',
      passage: '3',
    );

    expect(formatBibleReference(reference!, includeBook: false), '3,1-10');
  });

  test('keeps an explicit end verse after an implicit chapter start', () async {
    final reference = await normalizer.normalize(
      bookId: 'rev',
      passage: '6–8,2',
    );

    expect(formatBibleReference(reference!, includeBook: false), '6,1-8,2');
  });

  test('expands an arbitrary chapter range with Bible data', () async {
    final reference = await normalizer.normalize(
      bookId: 'zech',
      passage: '3-5',
    );

    expect(formatBibleReference(reference!, includeBook: false), '3,1-5,11');
  });

  test('normalizes and validates an explicit passage', () async {
    final reference = await normalizer.normalize(
      bookId: 'rev',
      passage: '6:3-8:2',
    );

    expect(formatBibleReference(reference!, includeBook: false), '6,3-8,2');
  });

  test('rejects chapters and verses absent from the Bible', () async {
    expect(
      await normalizer.normalize(bookId: 'zech', passage: '3,99'),
      isNull,
    );
    expect(
      await normalizer.normalize(bookId: 'zech', passage: '3-6'),
      isNull,
    );
  });
}

class _ChapterProvider implements BibleProvider {
  const _ChapterProvider(this.books);

  final Map<String, Map<int, int>> books;

  @override
  Future<void> prepare() async {}

  @override
  Future<List<int>> listChapters(String translationId, String bookId) async =>
      books[bookId]?.keys.toList() ?? const [];

  @override
  Future<List<int>> listVerses(
    String translationId,
    String bookId,
    int chapter,
  ) async {
    final lastVerse = books[bookId]?[chapter];
    if (lastVerse == null) return const [];
    return [for (var verse = 1; verse <= lastVerse; verse++) verse];
  }

  @override
  Future<List<BibleTranslationInfo>> listTranslations() async => const [];

  @override
  Future<List<BibleSearchResult>> search(String query) async => const [];

  @override
  Future<BiblePassage?> getPassage(
    BibleReference reference,
    String translationId,
  ) async => null;
}
