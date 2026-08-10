import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sermonary/core/database/app_database.dart';
import 'package:sermonary/core/database/database_backup_service.dart';
import 'package:sermonary/features/bible/data/local_bible_provider.dart';
import 'package:sermonary/features/bible/domain/bible_provider.dart';
import 'package:sermonary/features/export/application/export_service.dart';
import 'package:sermonary/features/library/application/welcome_sermon_seeder.dart';
import 'package:sermonary/features/library/data/sermon_repository.dart';
import 'package:sermonary/features/library/domain/sermon.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final databaseBackupServiceProvider = FutureProvider<DatabaseBackupService>((
  ref,
) async {
  final directory = await getApplicationDocumentsDirectory();
  return DatabaseBackupService(
    dataDirectory: directory,
    targetSchemaVersion: AppDatabase.currentSchemaVersion,
  );
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

final sermonRepositoryProvider = Provider<SermonRepository>(
  (ref) => DriftSermonRepository(ref.watch(databaseProvider)),
);

final exportServiceProvider = Provider<ExportService>(
  (ref) => const LocalExportService(),
);

final bibleProviderProvider = Provider<BibleProvider>(
  (ref) => LocalBibleProvider(ref.watch(databaseProvider)),
);

final sermonsProvider = StreamProvider<List<Sermon>>(
  (ref) => ref.watch(sermonRepositoryProvider).watchAll(),
);

final sermonSeriesProvider = StreamProvider<List<SermonSeries>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.select(database.sermonSeriesRows).watch().map((rows) {
    final series =
        rows
            .where((row) => !row.isArchived)
            .map(
              (row) => SermonSeries(
                id: row.id,
                title: row.title,
                description: row.description,
                primaryBibleBook: row.primaryBibleBook,
                colorToken: row.colorToken,
                backgroundImageId: row.backgroundImageId,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
                isArchived: row.isArchived,
              ),
            )
            .toList(growable: false)
          ..sort((left, right) => left.title.compareTo(right.title));
    return series;
  });
});

final StreamProviderFamily<Sermon?, String> sermonProvider =
    StreamProvider.family<Sermon?, String>(
      (ref, id) => ref.watch(sermonRepositoryProvider).watchById(id),
    );

final bootstrapProvider = FutureProvider<void>((ref) async {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(sermonRepositoryProvider);
  await WelcomeSermonSeeder.ensureSeeded(database, repository);
  await ref.watch(bibleProviderProvider).prepare();
});
