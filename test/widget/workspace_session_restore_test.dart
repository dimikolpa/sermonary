import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:sermonary/features/workspace/application/workspace_session_store.dart';
import 'package:sermonary/features/workspace/presentation/workspace_screen.dart';

void main() {
  testWidgets('restores the last sermon and both split content panes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftSermonRepository(database);
    final created = await repository.create();
    final now = DateTime.now().toUtc();
    await repository.update(
      created.copyWith(
        title: 'Letzte Arbeitssitzung',
        document: SermonDocument(
          schemaVersion: SermonDocument.currentSchemaVersion,
          blocks: [
            NoteBlock(
              id: 'remembered-note',
              text: 'Gemerkte Notiz',
              visibility: NoteVisibility.editorOnly,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: 'remembered-script',
              text: 'Gemerkter Skriptabsatz',
              semanticRole: ParagraphRole.normal,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          modules: [
            SermonModule(
              id: 'remembered-notes',
              kind: SermonModuleKind.notes,
              title: 'Notizen',
              sortOrder: 0,
              blockIds: const ['remembered-note'],
              linkGroupId: 'remembered-group',
              createdAt: now,
              updatedAt: now,
            ),
            SermonModule(
              id: 'remembered-script-module',
              kind: SermonModuleKind.script,
              title: 'Skript',
              sortOrder: 1,
              blockIds: const ['remembered-script'],
              linkGroupId: 'remembered-group',
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
    );
    final store = _MemoryWorkspaceSessionStore(
      WorkspaceSession(
        sermonId: created.id,
        splitActive: true,
        activePaneIndex: 1,
        panes: const [
          WorkspaceSessionPane(
            kind: WorkspaceSessionPaneKind.module,
            moduleId: 'remembered-notes',
          ),
          WorkspaceSessionPane(
            kind: WorkspaceSessionPaneKind.module,
            moduleId: 'remembered-script-module',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          bootstrapProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: SermonWorkspaceScreen(
            restoreLastSession: true,
            persistSession: true,
            sessionStore: store,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Letzte Arbeitssitzung'), findsWidgets);
    expect(
      find.byKey(ValueKey('split-title-${created.id}')),
      findsOneWidget,
    );
    expect(find.text('Gemerkte Notiz'), findsOneWidget);
    expect(find.text('Gemerkter Skriptabsatz'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(store.saved?.sermonId, created.id);
    expect(store.saved?.splitActive, isTrue);
    expect(store.saved?.activePaneIndex, 1);
    expect(store.saved?.panes[0].moduleId, 'remembered-notes');
    expect(store.saved?.panes[1].moduleId, 'remembered-script-module');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

class _MemoryWorkspaceSessionStore implements WorkspaceSessionStore {
  _MemoryWorkspaceSessionStore(this.saved);

  WorkspaceSession? saved;

  @override
  Future<WorkspaceSession?> load() async => saved;

  @override
  Future<void> save(WorkspaceSession session) async => saved = session;
}
