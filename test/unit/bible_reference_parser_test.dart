import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

void main() {
  final parser = BibleReferenceParser();

  for (final input in [
    'Joh 3,16',
    'Johannes 3,16–18',
    'Röm 8',
    'Röm 8,28–30',
    '1. Kor 15,1–4',
    '1Kor 15,1-4',
    '1. Mose 18,16–33',
    '1. Mose 18:16–33',
    'Johannes 3:16-4:2',
    '2. Könige 5,1–14',
    '1. Thessalonicher 4,13–18',
  ]) {
    test('parses $input', () {
      final reference = parser.parse(input);
      expect(reference, isNotNull);
      expect(reference!.startChapter, greaterThan(0));
    });
  }

  test('rejects unknown books and malformed ranges', () {
    expect(parser.parse('Unbekannt 3,4'), isNull);
    expect(parser.parse('Johannes'), isNull);
  });

  test('normalizes complete sermon passages with comma or colon', () {
    final sameChapter = parser.parsePassage('Johannes 2:3-5');
    expect(sameChapter, isNotNull);
    expect(sameChapter!.startChapter, 2);
    expect(sameChapter.startVerse, 3);
    expect(sameChapter.endChapter, 2);
    expect(sameChapter.endVerse, 5);
    expect(sameChapter.displayText, 'Johannes 2,3-5');

    final crossChapter = parser.parsePassage('Johannes 2,4-4,1');
    expect(crossChapter, isNotNull);
    expect(crossChapter!.startChapter, 2);
    expect(crossChapter.startVerse, 4);
    expect(crossChapter.endChapter, 4);
    expect(crossChapter.endVerse, 1);
    expect(crossChapter.displayText, 'Johannes 2,4-4,1');
  });

  test('complete sermon passages reject chapters without verses', () {
    expect(parser.parsePassage('Johannes 2'), isNull);
    expect(parser.parsePassage('Johannes 2-4'), isNull);
    expect(parser.parsePassage('Johannes 2,5-2,4'), isNull);
  });

  test('catalog preserves canonical Bible order', () {
    expect(
      BibleBookCatalog.orderOf('gen'),
      lessThan(BibleBookCatalog.orderOf('ps')),
    );
    expect(
      BibleBookCatalog.orderOf('ps'),
      lessThan(BibleBookCatalog.orderOf('matt')),
    );
    expect(BibleBookCatalog.labelFor('1cor'), '1. Korinther');
  });
}
