import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sermonary/app/app_config.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/library/presentation/library_screen.dart';
import 'package:sermonary/features/live_mode/presentation/live_mode_screen.dart';
import 'package:sermonary/features/sermon_editor/presentation/editor_screen.dart';

final _router = GoRouter(
  initialLocation: '/library',
  routes: [
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/trash',
      builder: (context, state) =>
          const LibraryScreen(initialView: LibraryView.trash),
    ),
    GoRoute(
      path: '/sermons/:id/raw',
      builder: (context, state) => EditorScreen(
        sermonId: state.pathParameters['id']!,
        mode: EditorMode.raw,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/script',
      builder: (context, state) => EditorScreen(
        sermonId: state.pathParameters['id']!,
        mode: EditorMode.script,
      ),
    ),
    GoRoute(
      path: '/sermons/:id/live',
      builder: (context, state) =>
          LiveModeScreen(sermonId: state.pathParameters['id']!),
    ),
  ],
);

class SermonaryApp extends StatelessWidget {
  const SermonaryApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: AppConfig.name,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    routerConfig: _router,
  );
}
