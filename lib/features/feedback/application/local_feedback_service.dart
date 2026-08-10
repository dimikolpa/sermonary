import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum FeedbackCategory {
  bug,
  missingFeature,
  usability,
  design,
  performance,
  other;

  String get label => switch (this) {
    FeedbackCategory.bug => 'Bug / Fehler',
    FeedbackCategory.missingFeature => 'Fehlende Funktion',
    FeedbackCategory.usability => 'Bedienung / Verständlichkeit',
    FeedbackCategory.design => 'Darstellung / Design',
    FeedbackCategory.performance => 'Leistung / Stabilität',
    FeedbackCategory.other => 'Sonstiges',
  };
}

class LocalFeedbackReceipt {
  const LocalFeedbackReceipt({
    required this.id,
    required this.directory,
    required this.textFile,
    this.screenshotFile,
  });

  final String id;
  final Directory directory;
  final File textFile;
  final File? screenshotFile;
}

class FeedbackAttachmentException implements Exception {
  const FeedbackAttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef FeedbackDirectoryResolver = Future<Directory> Function();

class LocalFeedbackService {
  LocalFeedbackService({FeedbackDirectoryResolver? directoryResolver})
    : _directoryResolver = directoryResolver ?? _defaultDirectory;

  static const int maxScreenshotBytes = 10 * 1024 * 1024;
  static const supportedScreenshotExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  final FeedbackDirectoryResolver _directoryResolver;

  Future<void> validateScreenshot(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const FeedbackAttachmentException(
        'Der ausgewählte Screenshot wurde nicht gefunden.',
      );
    }
    final extension = path
        .extension(filePath)
        .replaceFirst('.', '')
        .toLowerCase();
    if (!supportedScreenshotExtensions.contains(extension)) {
      throw const FeedbackAttachmentException(
        'Bitte einen Screenshot als PNG, JPG oder WebP auswählen.',
      );
    }
    final length = await file.length();
    if (length > maxScreenshotBytes) {
      throw const FeedbackAttachmentException(
        'Der Screenshot darf höchstens 10 MB groß sein.',
      );
    }
    final header = await file
        .openRead(0, mathMin(length, 12))
        .fold<List<int>>(
          <int>[],
          (bytes, chunk) => bytes..addAll(chunk),
        );
    if (!_matchesImageSignature(extension, header)) {
      throw const FeedbackAttachmentException(
        'Die Bilddatei ist beschädigt oder hat ein unpassendes Dateiformat.',
      );
    }
  }

  Future<LocalFeedbackReceipt> save({
    required FeedbackCategory category,
    required String description,
    String? sermonTitle,
    String? screenshotPath,
    DateTime? createdAt,
  }) async {
    final normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      throw const FormatException('Bitte eine kurze Beschreibung eingeben.');
    }
    if (screenshotPath != null) await validateScreenshot(screenshotPath);

    final timestamp = (createdAt ?? DateTime.now()).toLocal();
    final id =
        '${_fileTimestamp(timestamp)}-${const Uuid().v4().substring(0, 8)}';
    final root = await _directoryResolver();
    await root.create(recursive: true);
    final temporary = Directory(path.join(root.path, '.$id.tmp'));
    final destination = Directory(path.join(root.path, 'feedback-$id'));
    await temporary.create(recursive: true);

    try {
      File? screenshotFile;
      if (screenshotPath != null) {
        final extension = path.extension(screenshotPath).toLowerCase();
        screenshotFile = await File(
          screenshotPath,
        ).copy(path.join(temporary.path, 'screenshot$extension'));
      }
      final textFile = File(path.join(temporary.path, 'feedback.txt'));
      await textFile.writeAsString(
        _feedbackText(
          id: id,
          createdAt: timestamp,
          category: category,
          description: normalizedDescription,
          sermonTitle: sermonTitle,
          screenshotName: screenshotFile == null
              ? null
              : path.basename(screenshotFile.path),
        ),
        flush: true,
      );
      final completed = await temporary.rename(destination.path);
      return LocalFeedbackReceipt(
        id: id,
        directory: completed,
        textFile: File(path.join(completed.path, 'feedback.txt')),
        screenshotFile: screenshotFile == null
            ? null
            : File(
                path.join(completed.path, path.basename(screenshotFile.path)),
              ),
      );
    } on Object {
      if (temporary.existsSync()) await temporary.delete(recursive: true);
      rethrow;
    }
  }

  static Future<Directory> _defaultDirectory() async {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return Directory(path.join(downloads.path, 'Sermonary Feedback'));
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory(path.join(documents.path, 'Sermonary Feedback'));
  }
}

int mathMin(int first, int second) => first < second ? first : second;

bool _matchesImageSignature(String extension, List<int> bytes) {
  bool startsWith(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  return switch (extension) {
    'png' => startsWith(const [137, 80, 78, 71, 13, 10, 26, 10]),
    'jpg' || 'jpeg' => startsWith(const [255, 216, 255]),
    'webp' =>
      bytes.length >= 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP',
    _ => false,
  };
}

String _fileTimestamp(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}-'
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';

String _feedbackText({
  required String id,
  required DateTime createdAt,
  required FeedbackCategory category,
  required String description,
  required String? sermonTitle,
  required String? screenshotName,
}) => [
  'SERMONARY BETA-FEEDBACK',
  '',
  'Feedback-ID: $id',
  'Erstellt: ${createdAt.toIso8601String()}',
  'Kategorie: ${category.label}',
  'Betroffene Predigt: ${sermonTitle?.trim().isNotEmpty == true ? sermonTitle!.trim() : 'Nicht angegeben'}',
  'Screenshot: ${screenshotName ?? 'Keiner'}',
  '',
  'KURZE BESCHREIBUNG',
  description,
  '',
].join('\n');
