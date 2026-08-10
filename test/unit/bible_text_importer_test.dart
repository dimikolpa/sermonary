import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/bible/domain/bible_text_importer.dart';

void main() {
  final importer = BibleTextImporter();

  test('cleans a multi-verse BibleServer copy', () {
    const source =
        '16\u00a0Geh hin, versammle die Ältesten Israels und sprich zu ihnen: '
        'Jahwe[10], der Gott eurer Väter, ist mir erschienen, der Gott '
        'Abrahams, Isaaks und Jakobs, und hat gesagt: Ich habe genau '
        'achtgehabt auf euch und auf das, was euch in Ägypten angetan worden '
        'ist,\u200217\u00a0und habe gesagt: Ich will euch aus dem Elend '
        'Ägyptens hinaufführen in das Land der Kanaaniter, Hetiter, Amoriter, '
        'Perisiter, Hewiter und Jebusiter, in ein Land, das von Milch und '
        'Honig[11] überfließt.';

    final result = importer.import(source);

    expect(result, isNotNull);
    expect(
      result!.text,
      'Geh hin, versammle die Ältesten Israels und sprich zu ihnen: '
      'Jahwe, der Gott eurer Väter, ist mir erschienen, der Gott Abrahams, '
      'Isaaks und Jakobs, und hat gesagt: Ich habe genau achtgehabt auf euch '
      'und auf das, was euch in Ägypten angetan worden ist, und habe gesagt: '
      'Ich will euch aus dem Elend Ägyptens hinaufführen in das Land der '
      'Kanaaniter, Hetiter, Amoriter, Perisiter, Hewiter und Jebusiter, in '
      'ein Land, das von Milch und Honig überfließt.',
    );
    expect(result.verseRange, '16-17');
    expect(
      result.withReference(book: '2. Mose', chapter: 3),
      endsWith('2. Mose 3: 16-17'),
    );
  });

  test('supports a single verse and ordinary whitespace after punctuation', () {
    final result = importer.import('16 Text des Verses. 17 Nächster Vers.');

    expect(result?.text, 'Text des Verses. Nächster Vers.');
    expect(result?.verseRange, '16-17');
  });

  test('recognizes verse numbers followed by a colon', () {
    final result = importer.import(
      '20: Er aber sprach zu ihnen. 21: Und sie gingen weiter.',
    );

    expect(result?.text, 'Er aber sprach zu ihnen. Und sie gingen weiter.');
    expect(result?.verseRange, '20-21');
  });

  test('removes numeric footnotes but preserves textual square brackets', () {
    final result = importer.import(
      '20: Jesus[12] sprach [oder: antwortete] zu ihnen.',
    );

    expect(result?.text, 'Jesus sprach [oder: antwortete] zu ihnen.');
    expect(result?.verseRange, '20');
  });

  test('requires detectable verse numbers', () {
    expect(importer.import('Text ohne Versnummer'), isNull);
    expect(importer.import(''), isNull);
  });
}
