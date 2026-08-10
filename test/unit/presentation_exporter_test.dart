import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/presentation/application/presentation_exporter.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates a widescreen PDF and editable PowerPoint slides', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final created = await DriftSermonRepository(database).create();
    final sermon = created.copyWith(
      title: 'Bleibt in mir',
      document: const SermonDocument(
        schemaVersion: 1,
        blocks: [],
        presentation: PresentationDeck(
          slides: [
            PresentationSlide(
              id: 'title',
              template: PresentationSlideTemplate.title,
              title: 'Bleibt in mir',
              subtitle: 'Johannes 15,4–11',
            ),
            PresentationSlide(
              id: 'bible',
              template: PresentationSlideTemplate.headingBible,
              title: 'Der Weinstock',
              body: 'Bleibt in mir und ich in euch.',
              bodyMarks: [
                InlineMark(
                  start: 0,
                  end: 6,
                  bold: true,
                  italic: true,
                  highlighted: true,
                ),
              ],
              reference: 'Johannes 15,4',
              continuationGroupId: 'bible-group',
              continuationCount: 2,
            ),
            PresentationSlide(
              id: 'large-contents',
              template: PresentationSlideTemplate.largeContents,
              title: 'Nicht exportierte Überschrift',
              items: ['Gnade verstehen', 'Gnade weitergeben'],
            ),
            PresentationSlide(
              id: 'heading-image',
              template: PresentationSlideTemplate.headingImage,
              title: 'Gottes Schöpfung',
            ),
            PresentationSlide(
              id: 'heading-image-bible',
              template: PresentationSlideTemplate.headingImageBible,
              title: 'Der Weinstock',
              body: 'Bleibt in mir und ich in euch.',
              reference: 'Johannes 15,4',
            ),
          ],
        ),
      ),
    );

    const exporter = PresentationExporter();
    final pdf = await exporter.buildPdf(sermon);
    expect(ascii.decode(pdf.take(5).toList()), '%PDF-');

    final powerpoint = await exporter.buildPowerPoint(sermon);
    final archive = ZipDecoder().decodeBytes(powerpoint);
    expect(archive.findFile('ppt/presentation.xml'), isNotNull);
    expect(archive.findFile('ppt/slides/slide1.xml'), isNotNull);
    expect(archive.findFile('ppt/slides/slide2.xml'), isNotNull);
    expect(archive.findFile('ppt/slides/slide3.xml'), isNotNull);
    expect(archive.findFile('ppt/slides/slide4.xml'), isNotNull);
    expect(archive.findFile('ppt/slides/slide5.xml'), isNotNull);
    final secondSlide = utf8.decode(
      archive.findFile('ppt/slides/slide2.xml')!.readBytes()!,
    );
    expect(secondSlide, contains('Der Weinstock'));
    expect(secondSlide, contains('Johannes 15,4'));
    expect(secondSlide, contains('b="1"'));
    expect(secondSlide, contains('i="1"'));
    expect(secondSlide, contains('<a:highlight>'));
    expect(secondSlide, contains('1&#47;2'));
    expect(secondSlide, contains('<a:srgbClr val="FDFCF9"/>'));
    final thirdSlide = utf8.decode(
      archive.findFile('ppt/slides/slide3.xml')!.readBytes()!,
    );
    expect(thirdSlide, contains('Gnade verstehen'));
    expect(thirdSlide, contains('Gnade weitergeben'));
    expect(thirdSlide, contains('01'));
    expect(thirdSlide, isNot(contains('Nicht exportierte Überschrift')));
    final fourthSlide = utf8.decode(
      archive.findFile('ppt/slides/slide4.xml')!.readBytes()!,
    );
    expect(fourthSlide, contains('Gottes Schöpfung'));
    final fifthSlide = utf8.decode(
      archive.findFile('ppt/slides/slide5.xml')!.readBytes()!,
    );
    expect(fifthSlide, contains('Der Weinstock'));
    expect(fifthSlide, contains('Bleibt in mir und ich in euch.'));
    expect(fifthSlide, contains('Johannes 15,4'));

    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL9WQAAAABJRU5ErkJggg==',
    );
    final imagePowerPoint = await exporter.buildImagePowerPoint(
      sermon,
      [pixel, pixel, pixel, pixel, pixel],
    );
    final imageArchive = ZipDecoder().decodeBytes(imagePowerPoint);
    expect(imageArchive.findFile('ppt/media/image1.png'), isNotNull);
    expect(imageArchive.findFile('ppt/media/image2.png'), isNotNull);
    expect(imageArchive.findFile('ppt/media/image3.png'), isNotNull);
    expect(imageArchive.findFile('ppt/media/image4.png'), isNotNull);
    expect(imageArchive.findFile('ppt/media/image5.png'), isNotNull);
    final rasterSlide = utf8.decode(
      imageArchive.findFile('ppt/slides/slide1.xml')!.readBytes()!,
    );
    expect(rasterSlide, contains('<p:pic>'));
    expect(rasterSlide, isNot(contains('Bleibt in mir')));
    final contentTypes = utf8.decode(
      imageArchive.findFile('[Content_Types].xml')!.readBytes()!,
    );
    expect(contentTypes, contains('ContentType="image/png"'));
  });
}
