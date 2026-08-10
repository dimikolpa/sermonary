abstract final class BibleBookBackgroundCatalog {
  static const darkFallbackAsset =
      'assets/images/background_dark/generic1-dark.jpg';

  static const lightAssets = <String, String>{
    'gen': 'assets/images/background/1_1Mose/1mose.jpg',
    'exod': 'assets/images/background/2_2Mose/2mose.jpg',
    'lev': 'assets/images/background/3_3Mose/3mose.jpg',
    'num': 'assets/images/background/4_4Mose/4mose.jpg',
    'deut': 'assets/images/background/5_5Mose/5mose.jpg',
    'josh': 'assets/images/background/6_Josua/josua.jpg',
    'judg': 'assets/images/background/7_Richter/richter.jpg',
    'ruth': 'assets/images/background/8_Rut/rut.jpg',
    '1sam': 'assets/images/background/9_1Samuel/1samuel.jpg',
    '2sam': 'assets/images/background/10_2Samuel/2samuel.jpg',
    '1kgs': 'assets/images/background/11_1Koenige/1koenige.jpg',
    '2kgs': 'assets/images/background/12_2Koenige/2koenige.jpg',
    '1chr': 'assets/images/background/13_1Chronik/1chronik.jpg',
    '2chr': 'assets/images/background/14_2Chronik/2chronik.jpg',
    'ezra': 'assets/images/background/15_Esra/esra.jpg',
    'neh': 'assets/images/background/16_Nehemia/nehemia.jpg',
    'esth': 'assets/images/background/17_Ester/ester.jpg',
    'job': 'assets/images/background/18_Hiob/hiob.jpg',
    'ps': 'assets/images/background/19_Psalmen/psalmen.jpg',
    'prov': 'assets/images/background/20_Sprueche/sprueche.jpg',
    'eccl': 'assets/images/background/21_Prediger/prediger.jpg',
    'song': 'assets/images/background/22_Hohelied/hohelied.jpg',
    'isa': 'assets/images/background/23_Jesaja/jesaja.jpg',
    'jer': 'assets/images/background/24_Jeremia/jeremia.jpg',
    'lam': 'assets/images/background/25_Klagelieder/klagelieder.jpg',
    'ezek': 'assets/images/background/26_Hesekiel/hesekiel.jpg',
    'dan': 'assets/images/background/27_Daniel/daniel.jpg',
    'hos': 'assets/images/background/28_Hosea/hosea.jpg',
    'joel': 'assets/images/background/29_Joel/joel.jpg',
    'amos': 'assets/images/background/30_Amos/amos.jpg',
    'obad': 'assets/images/background/31_Obadja/obadja.jpg',
    'jonah': 'assets/images/background/32_Jona/jona.jpg',
    'mic': 'assets/images/background/33_Micha/micha.jpg',
    'nah': 'assets/images/background/34_Nahum/nahum.jpg',
    'hab': 'assets/images/background/35_Habakuk/habakuk.jpg',
    'zeph': 'assets/images/background/36_Zefanja/zefanja.jpg',
    'hag': 'assets/images/background/37_Haggai/haggai.jpg',
    'zech': 'assets/images/background/38_Sacharja/sacharja.jpg',
    'mal': 'assets/images/background/39_Maleachi/maleachi.jpg',
    'matt': 'assets/images/background/40_Matthaeus/matthaeus.jpg',
    'mark': 'assets/images/background/41_Markus/markus.jpg',
    'luke': 'assets/images/background/42_Lukas/lukas.jpg',
    'john': 'assets/images/background/43_Johannes/johannes.jpg',
    'acts':
        'assets/images/background/44_Apostelgeschichte/apostelgeschichte.jpg',
    'rom': 'assets/images/background/45_Roemer/roemer.jpg',
    '1cor': 'assets/images/background/46_1Korinther/1korinther.jpg',
    '2cor': 'assets/images/background/47_2Korinther/2korinther.jpg',
    'gal': 'assets/images/background/48_Galater/galater.jpg',
    'eph': 'assets/images/background/49_Epheser/epheser.jpg',
    'phil': 'assets/images/background/50_Philipper/philipper.jpg',
    'col': 'assets/images/background/51_Kolosser/kolosser.jpg',
    '1thess': 'assets/images/background/52_1Thessalonicher/1thessalonicher.jpg',
    '2thess': 'assets/images/background/53_2Thessalonicher/2thessalonicher.jpg',
    '1tim': 'assets/images/background/54_1Timotheus/1timotheus.jpg',
    '2tim': 'assets/images/background/55_2Timotheus/2timotheus.jpg',
    'titus': 'assets/images/background/56_Titus/titus.jpg',
    'phlm': 'assets/images/background/57_Philemon/philemon.jpg',
    'heb': 'assets/images/background/58_Hebraeer/hebraeer.jpg',
    'james': 'assets/images/background/59_Jakobus/jakobus.jpg',
    '1pet': 'assets/images/background/60_1Petrus/1petrus.jpg',
    '2pet': 'assets/images/background/61_2Petrus/2petrus.jpg',
    '1john': 'assets/images/background/62_1Johannes/1johannes.jpg',
    '2john': 'assets/images/background/63_2Johannes/2johannes.jpg',
    '3john': 'assets/images/background/64_3Johannes/3johannes.jpg',
    'jude': 'assets/images/background/65_Judas/judas.jpg',
    'rev': 'assets/images/background/66_Offenbarung/offenbarung.jpg',
  };

  static final darkAssets = <String, String>{
    for (final entry in lightAssets.entries)
      entry.key: entry.value
          .replaceFirst(
            'assets/images/background/',
            'assets/images/background_dark/',
          )
          .replaceFirst(RegExp(r'\.jpg$'), '-dark.jpg'),
  };

  static String? lightAssetFor(String bookId) => lightAssets[bookId];

  static String darkAssetFor(String bookId) =>
      darkAssets[bookId] ?? darkFallbackAsset;
}
