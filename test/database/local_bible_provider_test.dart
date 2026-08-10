import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/application/bible_passage_normalizer.dart';
import 'package:sermonary/features/bible/data/local_bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('imports and retrieves the structured ELB85 asset', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final provider = LocalBibleProvider(database);

    await provider.prepare();

    expect(
      await database.select(database.bibleVerses).get(),
      hasLength(31167),
    );
    expect(await provider.listChapters('elb85', 'gen'), hasLength(50));
    expect(await provider.listVerses('elb85', 'gen', 1), hasLength(31));

    final normalizer = BiblePassageNormalizer(provider);
    final genesisRange = await normalizer.normalize(
      bookId: 'gen',
      passage: '16–17',
    );
    final zechariahChapter = await normalizer.normalize(
      bookId: 'zech',
      passage: '3',
    );
    final revelationRange = await normalizer.normalize(
      bookId: 'rev',
      passage: '6–8,2',
    );
    expect(
      formatBibleReference(genesisRange!, includeBook: false),
      '16,1-17,27',
    );
    expect(
      formatBibleReference(zechariahChapter!, includeBook: false),
      '3,1-10',
    );
    expect(
      formatBibleReference(revelationRange!, includeBook: false),
      '6,1-8,2',
    );

    final passage = await provider.getPassage(
      const BibleReference(
        bookId: 'gen',
        startChapter: 1,
        startVerse: 1,
        endVerse: 3,
        displayText: '1. Mose 1,1–3',
      ),
      'elb85',
    );
    expect(passage, isNotNull);
    expect(
      passage!.text,
      startsWith('IM Anfang schuf Gott die Himmel und die Erde.'),
    );
    expect(passage.text, contains('Und Gott sprach: Es werde Licht!'));
    expect(passage.text, isNot(contains('-1-')));

    final crossChapter = await provider.getPassage(
      const BibleReference(
        bookId: 'gen',
        startChapter: 1,
        startVerse: 31,
        endChapter: 2,
        endVerse: 1,
        displayText: '1. Mose 1,31-2,1',
      ),
      'elb85',
    );
    expect(crossChapter?.text, contains('Und Gott sah alles, was er gemacht'));
    expect(crossChapter?.text, contains('wurden die Himmel und die Erde'));

    final firstVerse =
        await (database.select(database.bibleVerses)..where(
              (row) =>
                  row.translationId.equals('elb85') &
                  row.bookId.equals('gen') &
                  row.chapter.equals(1) &
                  row.verse.equals(1),
            ))
            .getSingle();
    expect(firstVerse.sourceText, contains('Himmel-1-'));

    final example = await provider.getPassage(
      const BibleReference(
        bookId: 'exod',
        startChapter: 3,
        startVerse: 16,
        endVerse: 17,
        displayText: '2. Mose 3,16–17',
      ),
      'elb85',
    );
    expect(
      example?.text,
      'Geh hin, versammle die Ältesten Israels und sprich zu ihnen: Jahwe, '
      'der Gott eurer Väter, ist mir erschienen, der Gott Abrahams, Isaaks '
      'und Jakobs, und hat gesagt: Ich habe genau achtgehabt auf euch und auf '
      'das, was euch in Ägypten angetan worden ist, und habe gesagt: Ich will '
      'euch aus dem Elend Ägyptens hinaufführen in das Land der Kanaaniter, '
      'Hetiter, Amoriter, Perisiter, Hewiter und Jebusiter, in ein Land, das '
      'von Milch und Honig überfließt.',
    );
  });
}
