import 'dart:convert';
import 'dart:io';

const _sourcePath =
    'imports/BIBLE/'
    '_german_Bible_Die_Bibel_Elberfelder_Uebersetzung_Revidiert_1985.txt';
const _targetPath = 'assets/bible/elb85.jsonl.gz';

const _bookIds = <String, String>{
  '1 mose': 'gen',
  '2 mose': 'exod',
  '3 mose': 'lev',
  '4 mose': 'num',
  '5 mose': 'deut',
  'josua': 'josh',
  'richter': 'judg',
  'ruth': 'ruth',
  '1 samuel': '1sam',
  '2 samuel': '2sam',
  '1 könige': '1kgs',
  '2 könige': '2kgs',
  '1 chronik': '1chr',
  '2 chronik': '2chr',
  'esra': 'ezra',
  'nehemia': 'neh',
  'esther': 'esth',
  'hiob': 'job',
  'psalmen': 'ps',
  'sprüche': 'prov',
  'prediger': 'eccl',
  'hohelied': 'song',
  'jesaja': 'isa',
  'jeremia': 'jer',
  'klagelieder': 'lam',
  'hesekiel': 'ezek',
  'daniel': 'dan',
  'hosea': 'hos',
  'joel': 'joel',
  'amos': 'amos',
  'obadja': 'obad',
  'jona': 'jonah',
  'micha': 'mic',
  'nahum': 'nah',
  'habakuk': 'hab',
  'zephania': 'zeph',
  'haggai': 'hag',
  'sacharja': 'zech',
  'maleachi': 'mal',
  'matthäus': 'matt',
  'markus': 'mark',
  'lukas': 'luke',
  'johannes': 'john',
  'apostelgeschichte': 'acts',
  'römer': 'rom',
  '1 korinther': '1cor',
  '2 korinther': '2cor',
  'galater': 'gal',
  'epheser': 'eph',
  'philipper': 'phil',
  'kolosser': 'col',
  '1 thessalonicher': '1thess',
  '2 thessalonicher': '2thess',
  '1 timotheus': '1tim',
  '2 timotheus': '2tim',
  'titus': 'titus',
  'philemon': 'phlm',
  'hebräer': 'heb',
  'jakobus': 'james',
  '1 petrus': '1pet',
  '2 petrus': '2pet',
  '1 johannes': '1john',
  '2 johannes': '2john',
  '3 johannes': '3john',
  'judas': 'jude',
  'offenbarung': 'rev',
};

void main() {
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Quelldatei fehlt: $_sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = latin1.decode(source.readAsBytesSync());
  final records = <_VerseRecord>[];
  final recordIndexes = <String, int>{};
  var count = 0;

  for (final rawLine in const LineSplitter().convert(decoded)) {
    final firstSeparator = rawLine.indexOf('#');
    final secondSeparator = rawLine.indexOf('#', firstSeparator + 1);
    if (firstSeparator < 0 || secondSeparator < 0) {
      throw FormatException('Ungültige Zeile ${count + 1}');
    }
    final reference = rawLine.substring(firstSeparator + 1, secondSeparator);
    final referenceParts = reference.split(',');
    if (referenceParts.length != 3) {
      throw FormatException('Ungültige Referenz: $reference');
    }
    final sourceBook = _normalizeBook(referenceParts[0]);
    final bookId = _bookIds[sourceBook];
    if (bookId == null) throw FormatException('Unbekanntes Buch: $sourceBook');
    final chapter = int.parse(referenceParts[1]);
    final verse = int.parse(referenceParts[2]);
    final key = '$bookId:$chapter:$verse';
    final sourceText = rawLine.substring(secondSeparator + 1).trim();
    final cleanText = _cleanVerse(sourceText);
    final existingIndex = recordIndexes[key];
    if (existingIndex != null) {
      final existing = records[existingIndex];
      records[existingIndex] = _VerseRecord(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        cleanText: cleanText.length > existing.cleanText.length
            ? cleanText
            : existing.cleanText,
        sourceText: '${existing.sourceText}\n$sourceText',
      );
      continue;
    }
    recordIndexes[key] = records.length;
    records.add(
      _VerseRecord(
        bookId: bookId,
        chapter: chapter,
        verse: verse,
        cleanText: cleanText,
        sourceText: sourceText,
      ),
    );
    count++;
  }

  final output = StringBuffer()
    ..writeln(
      jsonEncode({
        'id': 'elb85',
        'abbreviation': 'ELB85',
        'name': 'Elberfelder Bibel, revidierte Fassung 1985',
        'language': 'de',
        'source': source.uri.pathSegments.last,
        'copyright':
            'Elberfelder Bibel, revidierte Fassung 1985. '
            'Lokaler Benutzerimport.',
        'dataVersion': 1,
      }),
    );
  for (final record in records) {
    if (record.cleanText.isEmpty) {
      throw FormatException(
        'Leerer Vers: ${record.bookId}:${record.chapter}:${record.verse}',
      );
    }
    output.writeln(
      jsonEncode([
        record.bookId,
        record.chapter,
        record.verse,
        record.cleanText,
        record.sourceText,
      ]),
    );
  }

  File(_targetPath)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(gzip.encode(utf8.encode(output.toString())));
  stdout.writeln('$count eindeutige Verse nach $_targetPath geschrieben.');
}

class _VerseRecord {
  const _VerseRecord({
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.cleanText,
    required this.sourceText,
  });

  final String bookId;
  final int chapter;
  final int verse;
  final String cleanText;
  final String sourceText;
}

String _normalizeBook(String value) => value
    .replaceAll('\u00a0', ' ')
    .replaceAll('.', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();

String _cleanVerse(String value) {
  var text = value
      .replaceFirst(RegExp(r'^\d+\.\s*'), '')
      .replaceFirst(RegExp(r'\s+-(?:\d+|[a-z]+)\).*$'), '')
      .replaceAll(RegExp(r'-(?:\d+[a-z]?|[a-z])+-'), '')
      .replaceAllMapped(RegExp('--([^-]+)-'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'-\+([^-]+)-'), (match) => match.group(1)!)
      .replaceAll(RegExp(r'\s+\d+\.\s+'), ' ')
      .replaceAll('#', '-')
      .replaceAll(RegExp('[*+]'), '')
      .replaceAll('\u00a0', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (match) => match.group(1)!)
      .trim();
  if (text.startsWith('- ')) text = text.substring(2);
  return text;
}
