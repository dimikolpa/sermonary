import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/live_mode/presentation/live_mode_screen.dart';
import 'package:sermonary/features/print_mode/presentation/print_mode_screen.dart';
import 'package:sermonary/features/workspace/presentation/workspace_screen.dart';

final _router = GoRouter(
  initialLocation: '/library',
  routes: [
    GoRoute(
      path: '/library',
      builder: (context, state) => const SermonWorkspaceScreen(
        restoreLastSession: true,
        persistSession: true,
      ),
    ),
    GoRoute(path: '/trash', redirect: (context, state) => '/library'),
    GoRoute(
      path: '/sermons/:id/outline',
      builder: (context, state) => SermonWorkspaceScreen(
        sermonId: state.pathParameters['id'],
        persistSession: true,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/raw',
      builder: (context, state) => SermonWorkspaceScreen(
        sermonId: state.pathParameters['id'],
        initialView: WorkspaceView.notes,
        persistSession: true,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/notes',
      builder: (context, state) => SermonWorkspaceScreen(
        sermonId: state.pathParameters['id'],
        initialView: WorkspaceView.notes,
        persistSession: true,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/script',
      builder: (context, state) => SermonWorkspaceScreen(
        sermonId: state.pathParameters['id'],
        initialView: WorkspaceView.script,
        persistSession: true,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/presentation',
      builder: (context, state) => SermonWorkspaceScreen(
        sermonId: state.pathParameters['id'],
        initialView: WorkspaceView.presentation,
        persistSession: true,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/live',
      builder: (context, state) => LiveModeScreen(
        sermonId: state.pathParameters['id']!,
        moduleId: state.uri.queryParameters['module'],
        contentSource: state.uri.queryParameters['source'] == 'notes'
            ? LiveContentSource.notes
            : LiveContentSource.script,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/print',
      builder: (context, state) =>
          PrintModeScreen(sermonId: state.pathParameters['id']!),
    ),
  ],
);

class SermonaryApp extends ConsumerWidget {
  const SermonaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: AppConfig.name,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ref.watch(themeModeProvider),
    routerConfig: _router,
  );
}
