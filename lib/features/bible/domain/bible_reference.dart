import 'package:collection/collection.dart';

class BibleReference {
  const BibleReference({
    required this.bookId,
    required this.startChapter,
    required this.displayText,
    this.startVerse,
    this.endChapter,
    this.endVerse,
  });

  final String bookId;
  final int startChapter;
  final int? startVerse;
  final int? endChapter;
  final int? endVerse;
  final String displayText;

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'startChapter': startChapter,
    'startVerse': startVerse,
    'endChapter': endChapter,
    'endVerse': endVerse,
    'displayText': displayText,
  };

  factory BibleReference.fromJson(Map<String, Object?> json) => BibleReference(
    bookId: json['bookId']! as String,
    startChapter: json['startChapter']! as int,
    startVerse: json['startVerse'] as int?,
    endChapter: json['endChapter'] as int?,
    endVerse: json['endVerse'] as int?,
    displayText: json['displayText']! as String,
  );
}

class BibleBookInfo {
  const BibleBookInfo({
    required this.id,
    required this.label,
    required this.aliases,
  });

  final String id;
  final String label;
  final List<String> aliases;
}

abstract final class BibleBookCatalog {
  static const all = <BibleBookInfo>[
    BibleBookInfo(
      id: 'gen',
      label: '1. Mose',
      aliases: ['1mose', 'genesis', 'gen'],
    ),
    BibleBookInfo(
      id: 'exod',
      label: '2. Mose',
      aliases: ['2mose', 'exodus', 'ex'],
    ),
    BibleBookInfo(
      id: 'lev',
      label: '3. Mose',
      aliases: ['3mose', 'levitikus', 'lev'],
    ),
    BibleBookInfo(
      id: 'num',
      label: '4. Mose',
      aliases: ['4mose', 'numeri', 'num'],
    ),
    BibleBookInfo(
      id: 'deut',
      label: '5. Mose',
      aliases: ['5mose', 'deuteronomium', 'dtn'],
    ),
    BibleBookInfo(id: 'josh', label: 'Josua', aliases: ['josua', 'jos']),
    BibleBookInfo(id: 'judg', label: 'Richter', aliases: ['richter', 'ri']),
    BibleBookInfo(id: 'ruth', label: 'Rut', aliases: ['rut', 'ruth']),
    BibleBookInfo(id: '1sam', label: '1. Samuel', aliases: ['1samuel', '1sam']),
    BibleBookInfo(id: '2sam', label: '2. Samuel', aliases: ['2samuel', '2sam']),
    BibleBookInfo(
      id: '1kgs',
      label: '1. Könige',
      aliases: ['1könige', '1koenige', '1kön'],
    ),
    BibleBookInfo(
      id: '2kgs',
      label: '2. Könige',
      aliases: ['2könige', '2koenige', '2kön'],
    ),
    BibleBookInfo(
      id: '1chr',
      label: '1. Chronik',
      aliases: ['1chronik', '1chr'],
    ),
    BibleBookInfo(
      id: '2chr',
      label: '2. Chronik',
      aliases: ['2chronik', '2chr'],
    ),
    BibleBookInfo(id: 'ezra', label: 'Esra', aliases: ['esra', 'ezra']),
    BibleBookInfo(id: 'neh', label: 'Nehemia', aliases: ['nehemia', 'neh']),
    BibleBookInfo(id: 'esth', label: 'Ester', aliases: ['ester', 'est']),
    BibleBookInfo(id: 'job', label: 'Hiob', aliases: ['hiob', 'job']),
    BibleBookInfo(
      id: 'ps',
      label: 'Psalmen',
      aliases: ['psalm', 'psalmen', 'ps'],
    ),
    BibleBookInfo(
      id: 'prov',
      label: 'Sprüche',
      aliases: ['sprüche', 'sprueche', 'spr'],
    ),
    BibleBookInfo(id: 'eccl', label: 'Prediger', aliases: ['prediger', 'koh']),
    BibleBookInfo(id: 'song', label: 'Hohelied', aliases: ['hohelied', 'hld']),
    BibleBookInfo(id: 'isa', label: 'Jesaja', aliases: ['jesaja', 'jes']),
    BibleBookInfo(id: 'jer', label: 'Jeremia', aliases: ['jeremia', 'jer']),
    BibleBookInfo(
      id: 'lam',
      label: 'Klagelieder',
      aliases: ['klagelieder', 'kla'],
    ),
    BibleBookInfo(id: 'ezek', label: 'Hesekiel', aliases: ['hesekiel', 'hes']),
    BibleBookInfo(id: 'dan', label: 'Daniel', aliases: ['daniel', 'dan']),
    BibleBookInfo(id: 'hos', label: 'Hosea', aliases: ['hosea', 'hos']),
    BibleBookInfo(id: 'joel', label: 'Joel', aliases: ['joel']),
    BibleBookInfo(id: 'amos', label: 'Amos', aliases: ['amos', 'am']),
    BibleBookInfo(id: 'obad', label: 'Obadja', aliases: ['obadja', 'obd']),
    BibleBookInfo(id: 'jonah', label: 'Jona', aliases: ['jona']),
    BibleBookInfo(id: 'mic', label: 'Micha', aliases: ['micha', 'mi']),
    BibleBookInfo(id: 'nah', label: 'Nahum', aliases: ['nahum', 'nah']),
    BibleBookInfo(id: 'hab', label: 'Habakuk', aliases: ['habakuk', 'hab']),
    BibleBookInfo(id: 'zeph', label: 'Zefanja', aliases: ['zefanja', 'zeph']),
    BibleBookInfo(id: 'hag', label: 'Haggai', aliases: ['haggai', 'hag']),
    BibleBookInfo(id: 'zech', label: 'Sacharja', aliases: ['sacharja', 'sach']),
    BibleBookInfo(id: 'mal', label: 'Maleachi', aliases: ['maleachi', 'mal']),
    BibleBookInfo(
      id: 'matt',
      label: 'Matthäus',
      aliases: ['matthäus', 'matthaeus', 'mt'],
    ),
    BibleBookInfo(id: 'mark', label: 'Markus', aliases: ['markus', 'mk']),
    BibleBookInfo(id: 'luke', label: 'Lukas', aliases: ['lukas', 'lk']),
    BibleBookInfo(id: 'john', label: 'Johannes', aliases: ['johannes', 'joh']),
    BibleBookInfo(
      id: 'acts',
      label: 'Apostelgeschichte',
      aliases: ['apostelgeschichte', 'apg'],
    ),
    BibleBookInfo(
      id: 'rom',
      label: 'Römer',
      aliases: ['römer', 'roemer', 'röm', 'roem'],
    ),
    BibleBookInfo(
      id: '1cor',
      label: '1. Korinther',
      aliases: ['1korinther', '1kor'],
    ),
    BibleBookInfo(
      id: '2cor',
      label: '2. Korinther',
      aliases: ['2korinther', '2kor'],
    ),
    BibleBookInfo(id: 'gal', label: 'Galater', aliases: ['galater', 'gal']),
    BibleBookInfo(id: 'eph', label: 'Epheser', aliases: ['epheser', 'eph']),
    BibleBookInfo(
      id: 'phil',
      label: 'Philipper',
      aliases: ['philipper', 'phil'],
    ),
    BibleBookInfo(
      id: 'col',
      label: 'Kolosser',
      aliases: ['kolosser', 'kollosser', 'kol'],
    ),
    BibleBookInfo(
      id: '1thess',
      label: '1. Thessalonicher',
      aliases: ['1thessalonicher', '1thess'],
    ),
    BibleBookInfo(
      id: '2thess',
      label: '2. Thessalonicher',
      aliases: ['2thessalonicher', '2thess'],
    ),
    BibleBookInfo(
      id: '1tim',
      label: '1. Timotheus',
      aliases: ['1timotheus', '1tim'],
    ),
    BibleBookInfo(
      id: '2tim',
      label: '2. Timotheus',
      aliases: ['2timotheus', '2tim'],
    ),
    BibleBookInfo(id: 'titus', label: 'Titus', aliases: ['titus', 'tit']),
    BibleBookInfo(id: 'phlm', label: 'Philemon', aliases: ['philemon', 'phlm']),
    BibleBookInfo(
      id: 'heb',
      label: 'Hebräer',
      aliases: ['hebräer', 'hebraeer', 'heb'],
    ),
    BibleBookInfo(id: 'james', label: 'Jakobus', aliases: ['jakobus', 'jak']),
    BibleBookInfo(id: '1pet', label: '1. Petrus', aliases: ['1petrus', '1pet']),
    BibleBookInfo(id: '2pet', label: '2. Petrus', aliases: ['2petrus', '2pet']),
    BibleBookInfo(
      id: '1john',
      label: '1. Johannes',
      aliases: ['1johannes', '1joh'],
    ),
    BibleBookInfo(
      id: '2john',
      label: '2. Johannes',
      aliases: ['2johannes', '2joh'],
    ),
    BibleBookInfo(
      id: '3john',
      label: '3. Johannes',
      aliases: ['3johannes', '3joh'],
    ),
    BibleBookInfo(id: 'jude', label: 'Judas', aliases: ['judas', 'jud']),
    BibleBookInfo(
      id: 'rev',
      label: 'Offenbarung',
      aliases: ['offenbarung', 'offb'],
    ),
  ];

  static BibleBookInfo? byId(String id) =>
      all.where((book) => book.id == id).firstOrNull;

  static int orderOf(String id) {
    final index = all.indexWhere((book) => book.id == id);
    return index < 0 ? all.length : index;
  }

  static String labelFor(String id) => byId(id)?.label ?? id;
}

class BibleReferenceParser {
  BibleReference? parse(String input) {
    final normalized = input
        .trim()
        .replaceAll('–', '-')
        .replaceAll(RegExp(r'\s+'), ' ');
    final match = RegExp(
      r'^(.+?)\s*(\d+)(?:\s*[:,]\s*(\d+))?(?:\s*-\s*(?:(\d+)\s*[:,]\s*)?(\d+))?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;
    final rawBook = _normalizeBookName(match.group(1)!);
    final book = BibleBookCatalog.all.firstWhereOrNull(
      (candidate) => candidate.aliases.any(
        (alias) => _normalizeBookName(alias) == rawBook,
      ),
    );
    if (book == null) return null;
    final startChapter = int.parse(match.group(2)!);
    final startVerse = int.tryParse(match.group(3) ?? '');
    final explicitEndChapter = int.tryParse(match.group(4) ?? '');
    final endValue = int.tryParse(match.group(5) ?? '');
    return BibleReference(
      bookId: book.id,
      startChapter: startChapter,
      startVerse: startVerse,
      endChapter: explicitEndChapter,
      endVerse: endValue,
      displayText: input.trim().replaceAll('-', '–'),
    );
  }

  String _normalizeBookName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
}
