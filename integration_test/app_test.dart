import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sermonary/app/app.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('happy path through modular writing, split and live mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    Future<void> settle() => tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    Future<void> advance([
      Duration duration = const Duration(milliseconds: 500),
    ]) => tester.pump(duration);

    Future<SermonDocument> storedDocument() async => sermonFromRow(
      (await database.select(database.sermonRows).get()).single,
    ).document;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const SermonaryApp(),
      ),
    );
    await settle();
    await tester.pump(const Duration(milliseconds: 100));
    await settle();

    expect(find.byKey(const Key('quick-new-sermon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-new-sermon')));
    await settle();

    final sermonId =
        (await database.select(database.sermonRows).get()).single.id;
    expect(find.byKey(ValueKey('title-$sermonId')), findsOneWidget);
    await tester.enterText(
      find.byKey(ValueKey('title-$sermonId')),
      'Happy-Path-Predigt',
    );
    await advance();
    await tester.tap(find.text('KURZTHEMA'));
    await advance();
    await tester.tap(find.text('SPEICHERN'));
    await advance(const Duration(milliseconds: 900));

    await tester.tap(find.byKey(const Key('outline-add-content')));
    await advance();
    await tester.tap(find.byKey(const Key('add-content-notes')));
    await advance();
    await tester.tap(find.text('—  Stichpunkt'));
    await advance();
    await tester.pump(const Duration(milliseconds: 800));
    var document = await storedDocument();
    final notes = document.modulesOfKind(SermonModuleKind.notes).single;
    final noteBlock = document.blocksForModule(notes.id).single;
    await tester.enterText(
      find.descendant(
        of: find.byKey(ValueKey('focus-fade-${noteBlock.id}')),
        matching: find.byType(TextField),
      ),
      'Ein klarer Hauptpunkt',
    );

    await tester.tap(find.byKey(const Key('workflow-stage-outline')));
    await advance();
    await tester.tap(find.byKey(const Key('outline-add-linked-content')));
    await advance();
    await tester.tap(find.byKey(const Key('add-linked-content-script')));
    await advance();
    await tester.tap(find.text('Absatz hinzufügen'));
    await advance();
    await tester.pump(const Duration(milliseconds: 800));
    document = await storedDocument();
    final script = document.modulesOfKind(SermonModuleKind.script).single;
    final scriptBlock = document.blocksForModule(script.id).single;
    await tester.enterText(
      find.descendant(
        of: find.byKey(
          ValueKey('focus-fade-${scriptBlock.id}'),
        ),
        matching: find.byType(TextField),
      ),
      'Ausformulierter Text.',
    );

    await tester.tap(find.byKey(const Key('toggle-workspace-split')));
    await advance();
    await tester.tap(find.byKey(const Key('open-empty-workspace-pane')));
    await advance();
    await tester.tap(find.byKey(Key('pane-picker-module-${notes.id}')));
    await advance();
    expect(
      find.byKey(ValueKey('focus-fade-${notes.id}-${noteBlock.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('focus-fade-${script.id}-${scriptBlock.id}')),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 1));
    document = await storedDocument();
    expect(document.modulesAreLinked(notes.id, script.id), isTrue);
    expect(
      document.blocksForModule(notes.id).single.plainText,
      'Ein klarer Hauptpunkt',
    );
    expect(
      document.blocksForModule(script.id).single.plainText,
      'Ausformulierter Text.',
    );
    expect(
      sermonFromRow(
        (await database.select(database.sermonRows).get()).single,
      ).title,
      'Happy-Path-Predigt',
    );

    await tester.tap(find.byTooltip('Live-Ansicht'));
    await advance();
    expect(find.byKey(const Key('live-content-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('live-content-script')));
    await advance(const Duration(seconds: 2));
    expect(find.byKey(const Key('live-content-dialog')), findsNothing);
    expect(find.byTooltip('Livemode verlassen'), findsOneWidget);
    expect(find.text('Happy-Path-Predigt'), findsWidgets);
    expect(find.text('Ausformulierter Text.'), findsOneWidget);
  });
}
