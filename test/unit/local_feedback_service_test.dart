import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/features/feedback/application/local_feedback_service.dart';

void main() {
  late Directory temporaryDirectory;
  late Directory feedbackDirectory;
  late LocalFeedbackService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sermonary-feedback-test-',
    );
    feedbackDirectory = Directory(
      '${temporaryDirectory.path}/Sermonary Feedback',
    );
    service = LocalFeedbackService(
      directoryResolver: () async => feedbackDirectory,
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'stores each feedback as text and optional image in a unique folder',
    () async {
      final screenshot = File('${temporaryDirectory.path}/screen.png');
      await screenshot.writeAsBytes(const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
        0,
      ]);

      final receipt = await service.save(
        category: FeedbackCategory.bug,
        description: 'Beim Speichern verschwindet die Bibelstelle.',
        sermonTitle: 'Testpredigt',
        screenshotPath: screenshot.path,
        createdAt: DateTime(2026, 8, 8, 10, 15, 30),
      );

      expect(receipt.directory.path, contains('feedback-20260808-101530-'));
      expect(receipt.textFile.existsSync(), isTrue);
      expect(receipt.screenshotFile!.existsSync(), isTrue);
      final text = await receipt.textFile.readAsString();
      expect(text, contains('Kategorie: Bug / Fehler'));
      expect(text, contains('Betroffene Predigt: Testpredigt'));
      expect(text, contains('Beim Speichern verschwindet die Bibelstelle.'));
      expect(text, contains('Screenshot: screenshot.png'));
    },
  );

  test('rejects files that are not supported screenshots', () async {
    final attachment = File('${temporaryDirectory.path}/screen.txt');
    await attachment.writeAsString('kein Bild');

    await expectLater(
      service.validateScreenshot(attachment.path),
      throwsA(isA<FeedbackAttachmentException>()),
    );
  });
}
