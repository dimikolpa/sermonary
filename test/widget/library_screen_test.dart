import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/core/database/app_database.dart';
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
}
