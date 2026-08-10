import 'package:drift/drift.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

abstract final class WelcomeSermonSeeder {
  static const markerKey = 'welcome_sermon_seed_v1';

  static Future<void> ensureSeeded(
    AppDatabase database,
    SermonRepository repository, {
    Uuid uuid = const Uuid(),
  }) async {
    final marker = await (database.select(
      database.appSettings,
    )..where((row) => row.key.equals(markerKey))).getSingleOrNull();
    if (marker != null) return;

    final existing = await database.select(database.sermonRows).get();
    if (existing.isEmpty) {
      await _createExample(repository, uuid);
    }

    final now = DateTime.now().toUtc();
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: markerKey,
            valueJson: '{"completed":true}',
            updatedAt: now,
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  static Future<void> _createExample(
    SermonRepository repository,
    Uuid uuid,
  ) async {
    final now = DateTime.now().toUtc();
    final sermon = await repository.create();
    String id() => uuid.v4();

    final quickIdeaId = id();
    final quickGoalId = id();
    final firstHeadingId = id();
    final secondHeadingId = id();
    final thirdHeadingId = id();
    final firstNoteId = id();
    final secondNoteId = id();
    final thirdNoteId = id();
    final fourthNoteId = id();
    final introductionId = id();
    final explanationId = id();
    final bibleQuoteId = id();
    final applicationId = id();
    final freeNotesHeadingId = id();
    final freeNoteId = id();
    final freeScriptHeadingId = id();
    final freeScriptParagraphId = id();
    final linkedNotesId = id();
    final linkedScriptId = id();
    final linkedPresentationId = id();
    final freeNotesId = id();
    final freeScriptId = id();
    final linkGroupId = id();
    final titleSlideId = id();
    final thoughtSlideId = id();
    final bibleSlideId = id();

    final blocks = <DocumentBlock>[
      NoteBlock(
        id: quickIdeaId,
        text: 'Leitgedanke: Frucht wächst aus der Nähe zu Jesus.',
        visibility: NoteVisibility.editorOnly,
        isQuickNote: true,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: quickGoalId,
        text:
            'Ziel: Die Gemeinde zum täglichen Bleiben bei Christus ermutigen.',
        visibility: NoteVisibility.editorOnly,
        isQuickNote: true,
        createdAt: now,
        updatedAt: now,
      ),
      HeadingBlock(
        id: firstHeadingId,
        level: 1,
        text: '1. Verbunden mit dem Weinstock',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: firstNoteId,
        text:
            'Einstieg: Wo versuche ich, geistliches Wachstum selbst herzustellen?',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: secondNoteId,
        text: 'Bild erklären: Eine Rebe lebt nicht aus eigener Kraft.',
        visibility: NoteVisibility.editorOnly,
        depth: 1,
        createdAt: now,
        updatedAt: now,
      ),
      ParagraphBlock(
        id: introductionId,
        text:
            'Manchmal behandeln wir den Glauben wie ein Projekt. Jesus wählt ein anderes Bild: Eine Rebe trägt Frucht, weil sie mit dem Weinstock verbunden bleibt. Dieser Beispielabsatz zeigt, wie ein verknüpftes Skript unter derselben Überschrift ausführlicher werden kann.',
        semanticRole: ParagraphRole.introduction,
        createdAt: now,
        updatedAt: now,
      ),
      HeadingBlock(
        id: secondHeadingId,
        level: 2,
        text: '2. Bleiben geschieht im Alltag',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: thirdNoteId,
        text:
            'Gottes Wort hören, ehrlich beten und nach einem Scheitern zurückkehren.',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
      ParagraphBlock(
        id: explanationId,
        text:
            'Bleiben ist keine besondere Stimmung. Es zeigt sich in kleinen, wiederkehrenden Bewegungen: Wir hören auf Gottes Wort, bringen Christus ehrlich unser Leben und vertrauen seiner Gnade.',
        semanticRole: ParagraphRole.explanation,
        createdAt: now,
        updatedAt: now,
      ),
      BibleQuoteBlock(
        id: bibleQuoteId,
        reference: BibleReferenceParser().parsePassage('Johannes 15,5')!,
        translationId: 'ELB85',
        translationLabel: 'ELB85',
        text: 'Ich bin der Weinstock, ihr seid die Reben.',
        showVerseNumbers: false,
        copyrightNotice: '',
        createdAt: now,
        updatedAt: now,
      ),
      HeadingBlock(
        id: thirdHeadingId,
        level: 3,
        text: 'Ein konkreter nächster Schritt',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: fourthNoteId,
        text: 'Eine Gewohnheit auswählen, die Nähe zu Jesus schafft.',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
      ParagraphBlock(
        id: applicationId,
        text:
            'Wähle für diese Woche einen einfachen nächsten Schritt: einen Psalm am Morgen, ein ehrliches Gebet oder einen festen Moment der Stille. Dieser Text ist ein Platzhalter und darf vollständig ersetzt werden.',
        semanticRole: ParagraphRole.application,
        createdAt: now,
        updatedAt: now,
      ),
      HeadingBlock(
        id: freeNotesHeadingId,
        level: 1,
        text: 'Unabhängige Ideensammlung',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      NoteBlock(
        id: freeNoteId,
        text:
            'Diese Notiz ist nicht verknüpft. Ihre Überschriften und Änderungen bleiben unabhängig vom Predigtskript.',
        visibility: NoteVisibility.editorOnly,
        createdAt: now,
        updatedAt: now,
      ),
      HeadingBlock(
        id: freeScriptHeadingId,
        level: 1,
        text: 'Alternativer Einstieg',
        collapsed: false,
        createdAt: now,
        updatedAt: now,
      ),
      ParagraphBlock(
        id: freeScriptParagraphId,
        text:
            'Dieses eigenständige Skript ist nicht mit den Predigtnotizen verbunden. Es eignet sich zum Ausprobieren einer Alternative, ohne den Hauptentwurf zu verändern.',
        semanticRole: ParagraphRole.illustration,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final slides = <PresentationSlide>[
      PresentationSlide(
        id: titleSlideId,
        template: PresentationSlideTemplate.title,
        title: 'Bleibt in mir',
        subtitle: 'Johannes 15,1–11',
        anchor: PresentationAnchor(
          view: PresentationAnchorView.script,
          blockId: firstHeadingId,
          moduleId: linkedScriptId,
        ),
      ),
      PresentationSlide(
        id: thoughtSlideId,
        template: PresentationSlideTemplate.headingText,
        title: 'Verbunden mit dem Weinstock',
        body: 'Frucht ist das Ergebnis der Verbindung – nicht der Anstrengung.',
        anchor: PresentationAnchor(
          view: PresentationAnchorView.script,
          blockId: introductionId,
          moduleId: linkedScriptId,
        ),
      ),
      PresentationSlide(
        id: bibleSlideId,
        template: PresentationSlideTemplate.headingBible,
        title: 'Jesu Bild',
        body: 'Ich bin der Weinstock, ihr seid die Reben.',
        reference: 'Johannes 15,5',
        anchor: PresentationAnchor(
          view: PresentationAnchorView.script,
          blockId: bibleQuoteId,
          moduleId: linkedScriptId,
        ),
      ),
    ];

    await repository.update(
      sermon.copyWith(
        title: 'Bleibt in mir',
        subtitle:
            'Jesus lädt seine Jünger ein, aus der Verbindung mit ihm zu leben. Frucht entsteht nicht aus angestrengter Selbstoptimierung, sondern aus dem Bleiben bei Christus.',
        status: SermonStatus.draft,
        primaryBibleReference: BibleReferenceParser().parsePassage(
          'Johannes 15,1–11',
        ),
        topics: const ['Nachfolge', 'Glaube', 'Frucht'],
        tags: const ['Beispielpredigt', 'Johannes 15'],
        plannedDurationMinutes: 18,
        document: SermonDocument(
          schemaVersion: SermonDocument.currentSchemaVersion,
          blocks: blocks,
          presentation: PresentationDeck(slides: slides),
          modules: [
            SermonModule(
              id: linkedNotesId,
              kind: SermonModuleKind.notes,
              title: 'Predigtnotizen',
              sortOrder: 0,
              blockIds: [
                firstHeadingId,
                firstNoteId,
                secondNoteId,
                secondHeadingId,
                thirdNoteId,
                thirdHeadingId,
                fourthNoteId,
              ],
              linkGroupId: linkGroupId,
              createdAt: now,
              updatedAt: now,
            ),
            SermonModule(
              id: linkedScriptId,
              kind: SermonModuleKind.script,
              title: 'Predigtskript',
              sortOrder: 1,
              blockIds: [
                firstHeadingId,
                introductionId,
                secondHeadingId,
                explanationId,
                bibleQuoteId,
                thirdHeadingId,
                applicationId,
              ],
              linkGroupId: linkGroupId,
              createdAt: now,
              updatedAt: now,
            ),
            SermonModule(
              id: linkedPresentationId,
              kind: SermonModuleKind.presentation,
              title: 'Predigtfolien',
              sortOrder: 2,
              slideIds: [titleSlideId, thoughtSlideId, bibleSlideId],
              linkGroupId: linkGroupId,
              createdAt: now,
              updatedAt: now,
            ),
            SermonModule(
              id: freeNotesId,
              kind: SermonModuleKind.notes,
              title: 'Ideensammlung · frei',
              sortOrder: 3,
              blockIds: [freeNotesHeadingId, freeNoteId],
              createdAt: now,
              updatedAt: now,
            ),
            SermonModule(
              id: freeScriptId,
              kind: SermonModuleKind.script,
              title: 'Alternativer Einstieg · frei',
              sortOrder: 4,
              blockIds: [freeScriptHeadingId, freeScriptParagraphId],
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
    );
  }
}
