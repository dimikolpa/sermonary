import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

class LocalBibleProvider implements BibleProvider {
  LocalBibleProvider(this.database, {AssetBundle? assetBundle})
    : _assetBundle = assetBundle ?? rootBundle;

  static const translationId = 'elb85';
  static const _assetPath = 'assets/bible/elb85.jsonl.gz';
  static const _dataVersion = 1;

  final AppDatabase database;
  final AssetBundle _assetBundle;
  Future<void>? _preparing;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    final existing = await (database.select(
      database.bibleTranslations,
    )..where((row) => row.id.equals(translationId))).getSingleOrNull();
    if (existing?.dataVersion == _dataVersion) return;

    final asset = await _assetBundle.load(_assetPath);
    final compressed = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    final lines = const LineSplitter().convert(
      utf8.decode(const GZipDecoder().decodeBytes(compressed)),
    );
    if (lines.isEmpty) throw const FormatException('Leeres Bibel-Asset');
    final metadata = jsonDecode(lines.first) as Map<String, Object?>;
    final importedAt = DateTime.now().toUtc();

    await database.transaction(() async {
      await (database.delete(
        database.bibleVerses,
      )..where((row) => row.translationId.equals(translationId))).go();
      await (database.delete(
        database.bibleTranslations,
      )..where((row) => row.id.equals(translationId))).go();
      await database
          .into(database.bibleTranslations)
          .insert(
            BibleTranslationsCompanion.insert(
              id: metadata['id']! as String,
              abbreviation: metadata['abbreviation']! as String,
              name: metadata['name']! as String,
              language: metadata['language']! as String,
              source: metadata['source']! as String,
              copyrightNotice: metadata['copyright']! as String,
              dataVersion: metadata['dataVersion']! as int,
              importedAt: importedAt,
            ),
          );

      const chunkSize = 500;
      for (var offset = 1; offset < lines.length; offset += chunkSize) {
        final end = (offset + chunkSize).clamp(0, lines.length);
        final companions = <BibleVersesCompanion>[];
        for (var index = offset; index < end; index++) {
          final values = jsonDecode(lines[index]) as List<Object?>;
          companions.add(
            BibleVersesCompanion.insert(
              translationId: translationId,
              bookId: values[0]! as String,
              chapter: values[1]! as int,
              verse: values[2]! as int,
              content: values[3]! as String,
              sourceText: values[4]! as String,
            ),
          );
        }
        await database.batch((batch) {
          batch.insertAll(database.bibleVerses, companions);
        });
      }
    });
  }

  @override
  Future<List<BibleTranslationInfo>> listTranslations() async {
    await prepare();
    final rows = await database.select(database.bibleTranslations).get();
    return [
      for (final row in rows)
        BibleTranslationInfo(
          id: row.id,
          label: '${row.abbreviation} · ${row.name}',
          isOffline: true,
        ),
    ];
  }

  @override
  Future<List<int>> listChapters(
    String requestedTranslationId,
    String bookId,
  ) async {
    await prepare();
    final query =
        database.selectOnly(
            database.bibleVerses,
            distinct: true,
          )
          ..addColumns([database.bibleVerses.chapter])
          ..where(
            database.bibleVerses.translationId.equals(requestedTranslationId) &
                database.bibleVerses.bookId.equals(bookId),
          )
          ..orderBy([
            OrderingTerm.asc(database.bibleVerses.chapter),
          ]);
    return [
      for (final row in await query.get())
        row.read(database.bibleVerses.chapter)!,
    ];
  }

  @override
  Future<List<int>> listVerses(
    String requestedTranslationId,
    String bookId,
    int chapter,
  ) async {
    await prepare();
    final query = database.selectOnly(database.bibleVerses)
      ..addColumns([database.bibleVerses.verse])
      ..where(
        database.bibleVerses.translationId.equals(requestedTranslationId) &
            database.bibleVerses.bookId.equals(bookId) &
            database.bibleVerses.chapter.equals(chapter),
      )
      ..orderBy([
        OrderingTerm.asc(database.bibleVerses.verse),
      ]);
    return [
      for (final row in await query.get())
        row.read(database.bibleVerses.verse)!,
    ];
  }

  @override
  Future<BiblePassage?> getPassage(
    BibleReference reference,
    String requestedTranslationId,
  ) async {
    await prepare();
    final startVerse = reference.startVerse ?? 1;
    final endVerse = reference.endVerse ?? startVerse;
    final endChapter = reference.endChapter ?? reference.startChapter;
    final query = database.select(database.bibleVerses)
      ..where(
        (row) =>
            row.translationId.equals(requestedTranslationId) &
            row.bookId.equals(reference.bookId) &
            ((row.chapter.equals(reference.startChapter) &
                    row.verse.isBiggerOrEqualValue(startVerse)) |
                row.chapter.isBiggerThanValue(reference.startChapter)) &
            ((row.chapter.equals(endChapter) &
                    row.verse.isSmallerOrEqualValue(endVerse)) |
                row.chapter.isSmallerThanValue(endChapter)),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.chapter),
        (row) => OrderingTerm.asc(row.verse),
      ]);
    final verses = await query.get();
    if (verses.isEmpty) return null;
    final translation = await (database.select(
      database.bibleTranslations,
    )..where((row) => row.id.equals(requestedTranslationId))).getSingleOrNull();
    return BiblePassage(
      reference: reference,
      translationId: requestedTranslationId,
      text: verses.map((verse) => verse.content).join(' '),
      copyrightNotice: translation?.copyrightNotice ?? '',
    );
  }

  @override
  Future<List<BibleSearchResult>> search(String query) async {
    await prepare();
    final parsed = BibleReferenceParser().parse(query);
    if (parsed != null) {
      final passage = await getPassage(parsed, translationId);
      return passage == null
          ? const []
          : [
              BibleSearchResult(
                reference: parsed,
                preview: passage.text,
              ),
            ];
    }
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];
    final matches =
        await (database.select(database.bibleVerses)
              ..where(
                (row) =>
                    row.translationId.equals(translationId) &
                    row.content.like('%$normalized%'),
              )
              ..limit(50))
            .get();
    return [
      for (final match in matches)
        BibleSearchResult(
          reference: BibleReference(
            bookId: match.bookId,
            startChapter: match.chapter,
            startVerse: match.verse,
            displayText:
                '${BibleBookCatalog.labelFor(match.bookId)} '
                '${match.chapter},${match.verse}',
          ),
          preview: match.content,
        ),
    ];
  }
}
