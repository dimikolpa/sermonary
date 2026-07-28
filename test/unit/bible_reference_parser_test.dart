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
}
