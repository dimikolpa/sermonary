import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/bible/domain/bible_book_background_catalog.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';

void main() {
  test('every Bible book has an optimized JPG background', () {
    final bookIds = BibleBookCatalog.all.map((book) => book.id).toSet();

    expect(BibleBookBackgroundCatalog.lightAssets.keys.toSet(), bookIds);
    expect(
      BibleBookBackgroundCatalog.lightAssets.values.toSet(),
      hasLength(66),
    );
    for (final asset in BibleBookBackgroundCatalog.lightAssets.values) {
      expect(asset, endsWith('.jpg'));
      expect(asset, isNot(endsWith('.png')));
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('every Bible book has an optimized dark-mode JPG background', () {
    final bookIds = BibleBookCatalog.all.map((book) => book.id).toSet();

    expect(BibleBookBackgroundCatalog.darkAssets.keys.toSet(), bookIds);
    expect(
      BibleBookBackgroundCatalog.darkAssets.values.toSet(),
      hasLength(66),
    );
    for (final asset in BibleBookBackgroundCatalog.darkAssets.values) {
      expect(asset, endsWith('-dark.jpg'));
      expect(asset, isNot(endsWith('.png')));
      expect(File(asset).existsSync(), isTrue, reason: asset);
    }
  });

  test('every nested dark-mode background is declared as a Flutter asset', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final asset in BibleBookBackgroundCatalog.darkAssets.values) {
      expect(
        pubspec,
        contains('- $asset'),
        reason: '$asset muss einzeln im App-Bundle deklariert sein.',
      );
    }
  });
}
