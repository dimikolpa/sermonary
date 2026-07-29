import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/presentation/library_screen.dart';

void main() {
  testWidgets('library shows sermons and creates a new sermon', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const LibraryScreen(),
        ),
        GoRoute(
          path: '/sermons/:id/raw',
          builder: (context, state) =>
              const Scaffold(body: Text('Editor geöffnet')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bibliothek'), findsOneWidget);
    expect(find.byKey(const Key('new-sermon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('new-sermon')));
    await tester.pumpAndSettle();
    expect(await database.select(database.sermonRows).get(), hasLength(1));
    expect(find.text('Editor geöffnet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('Bible books are dynamic and passages use canonical order', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final parser = BibleReferenceParser();

    for (final entry in const [
      ('Später Abschnitt', 'Johannes 10,1'),
      ('Früher Abschnitt', 'Johannes 2,1'),
      ('Bergpredigt', 'Matthäus 5,1'),
    ]) {
      final sermon = await repository.create();
      await repository.update(
        sermon.copyWith(
          title: entry.$1,
          primaryBibleReference: parser.parse(entry.$2),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Matthäus'), findsOneWidget);
    expect(find.text('Johannes'), findsOneWidget);
    await tester.tap(find.text('Johannes'));
    await tester.pumpAndSettle();

    expect(find.text('Früher Abschnitt'), findsOneWidget);
    expect(find.text('Später Abschnitt'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Früher Abschnitt')).dy,
      lessThan(tester.getTopLeft(find.text('Später Abschnitt')).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
