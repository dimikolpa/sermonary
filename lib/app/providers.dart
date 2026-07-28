import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/export/application/export_service.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';
import 'package:sermonary/features/sermon_editor/domain/sermon_document.dart';
import 'package:uuid/uuid.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final sermonRepositoryProvider = Provider<SermonRepository>(
  (ref) => DriftSermonRepository(ref.watch(databaseProvider)),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => const LocalExportService(),
);

final bibleProviderProvider = Provider<BibleProvider>(
  (ref) => const MockBibleProvider(),
);

final sermonsProvider = StreamProvider<List<Sermon>>(
  (ref) => ref.watch(sermonRepositoryProvider).watchAll(),
);

final StreamProviderFamily<Sermon?, String> sermonProvider =
    StreamProvider.family<Sermon?, String>(
      (ref, id) => ref.watch(sermonRepositoryProvider).watchById(id),
    );

final bootstrapProvider = FutureProvider<void>((ref) async {
  if (const bool.fromEnvironment('dart.vm.product')) return;
  final database = ref.watch(databaseProvider);
  final existing = await database.select(database.sermonRows).get();
  if (existing.isNotEmpty) return;
  final repository = ref.watch(sermonRepositoryProvider);
  const uuid = Uuid();
  final examples = [
    (
      'Zu wem sollen wir gehen?',
      SermonStatus.preached,
      'Johannes 6,60–71',
      'Vertrauen wächst nicht aus vollständiger Gewissheit, sondern im Bleiben.',
    ),
    (
      'Kommt her zu mir',
      SermonStatus.inProgress,
      'Matthäus 11,28–30',
      'Eine Einladung für Müde: Lasten benennen, Nähe suchen, Ruhe empfangen.',
    ),
    (
      'Die erste Liebe',
      SermonStatus.draft,
      'Offenbarung 2,1–7',
      'Treue Tätigkeit ersetzt nicht die lebendige Beziehung.',
    ),
  ];
  for (final example in examples) {
    final sermon = await repository.create();
    final now = DateTime.now().toUtc();
    await repository.update(
      sermon.copyWith(
        title: example.$1,
        status: example.$2,
        subtitle: example.$3,
        document: SermonDocument(
          schemaVersion: 1,
          blocks: [
            HeadingBlock(
              id: uuid.v4(),
              level: 1,
              text: 'Leitgedanke',
              collapsed: false,
              createdAt: now,
              updatedAt: now,
            ),
            ParagraphBlock(
              id: uuid.v4(),
              text: example.$4,
              semanticRole: ParagraphRole.introduction,
              createdAt: now,
              updatedAt: now,
            ),
            BulletListBlock(
              id: uuid.v4(),
              ordered: false,
              items: [
                BulletItem(
                  id: uuid.v4(),
                  text: 'Text beobachten',
                  semanticRole: ParagraphRole.explanation,
                  collapsed: false,
                  children: const [],
                ),
                BulletItem(
                  id: uuid.v4(),
                  text: 'Evangelium entfalten',
                  semanticRole: ParagraphRole.application,
                  collapsed: false,
                  children: const [],
                ),
              ],
              createdAt: now,
              updatedAt: now,
            ),
          ],
        ),
      ),
    );
  }
});
