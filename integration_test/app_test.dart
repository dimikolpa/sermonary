import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sermonary/app/app.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/core/database/app_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('happy path from library through writing to live mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const SermonaryApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('new-sermon')));
    await tester.pumpAndSettle();
    expect(find.text('Gliederung'), findsOneWidget);

    await tester.enterText(
      find.byKey(
        ValueKey(
          'title-${(await database.select(database.sermonRows).get()).single.id}',
        ),
      ),
      'Happy-Path-Predigt',
    );
    await tester.tap(find.byKey(const Key('add-first-raw-point')));
    await tester.pump();
    final rawField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.key.toString().contains('raw-line'),
    );
    await tester.enterText(rawField.first, 'Ein klarer Hauptpunkt');

    await tester.tap(find.text('Script'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Absatz').last);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, 'Schreiben …'),
      'Ausformulierter Text.',
    );

    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Livemode (⌘3)'));
    await tester.pumpAndSettle();
    expect(find.text('Happy-Path-Predigt'), findsWidgets);
    expect(find.text('Ausformulierter Text.'), findsOneWidget);
  });
}
