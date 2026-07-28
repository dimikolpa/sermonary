import 'package:sermonary/features/bible/domain/bible_reference.dart';

class BibleTranslationInfo {
  const BibleTranslationInfo({
    required this.id,
    required this.label,
    required this.isOffline,
  });
  final String id;
  final String label;
  final bool isOffline;
}

class BiblePassage {
  const BiblePassage({
    required this.reference,
    required this.translationId,
    required this.text,
    required this.copyrightNotice,
  });
  final BibleReference reference;
  final String translationId;
  final String text;
  final String copyrightNotice;
}

class BibleSearchResult {
  const BibleSearchResult({required this.reference, required this.preview});
  final BibleReference reference;
  final String preview;
}

abstract interface class BibleProvider {
  Future<List<BibleTranslationInfo>> listTranslations();
  Future<List<BibleSearchResult>> search(String query);
  Future<BiblePassage?> getPassage(
    BibleReference reference,
    String translationId,
  );
}

class MockBibleProvider implements BibleProvider {
  const MockBibleProvider();

  static const _translation = BibleTranslationInfo(
    id: 'sermonary-demo',
    label: 'Sermonary Demo (Platzhalter)',
    isOffline: true,
  );

  @override
  Future<List<BibleTranslationInfo>> listTranslations() async => [
    _translation,
  ];

  @override
  Future<BiblePassage?> getPassage(
    BibleReference reference,
    String translationId,
  ) async {
    if (translationId != _translation.id) return null;
    final text = switch (reference.bookId) {
      'john' =>
        'Selbst formulierter Platzhalter: Gottes Liebe lädt zu Vertrauen ein.',
      'matt' =>
        'Selbst formulierter Platzhalter: Müde Menschen finden Ruhe und Nähe.',
      _ => null,
    };
    if (text == null) return null;
    return BiblePassage(
      reference: reference,
      translationId: translationId,
      text: text,
      copyrightNotice: 'Frei formulierter Sermonary-Demotext, kein Bibelzitat.',
    );
  }

  @override
  Future<List<BibleSearchResult>> search(String query) async {
    final reference = BibleReferenceParser().parse(query);
    if (reference == null) return const [];
    final passage = await getPassage(reference, _translation.id);
    return passage == null
        ? const []
        : [
            BibleSearchResult(
              reference: reference,
              preview: passage.text,
            ),
          ];
  }
}
