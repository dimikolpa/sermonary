import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum WorkspaceSessionPaneKind { empty, outline, module }

class WorkspaceSessionPane {
  const WorkspaceSessionPane({required this.kind, this.moduleId});

  final WorkspaceSessionPaneKind kind;
  final String? moduleId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'moduleId': moduleId,
  };

  factory WorkspaceSessionPane.fromJson(Map<String, Object?> json) =>
      WorkspaceSessionPane(
        kind: WorkspaceSessionPaneKind.values.firstWhere(
          (value) => value.name == json['kind'],
          orElse: () => WorkspaceSessionPaneKind.empty,
        ),
        moduleId: json['moduleId'] as String?,
      );
}

class WorkspaceSession {
  const WorkspaceSession({
    required this.sermonId,
    required this.splitActive,
    required this.activePaneIndex,
    required this.panes,
    this.focusMode = false,
  });

  final String? sermonId;
  final bool splitActive;
  final int activePaneIndex;
  final List<WorkspaceSessionPane> panes;
  final bool focusMode;

  Map<String, Object?> toJson() => {
    'version': 1,
    'sermonId': sermonId,
    'splitActive': splitActive,
    'activePaneIndex': activePaneIndex,
    'panes': panes.map((pane) => pane.toJson()).toList(growable: false),
    'focusMode': focusMode,
  };

  factory WorkspaceSession.fromJson(Map<String, Object?> json) =>
      WorkspaceSession(
        sermonId: json['sermonId'] as String?,
        splitActive: json['splitActive'] as bool? ?? false,
        activePaneIndex: json['activePaneIndex'] as int? ?? 0,
        panes: (json['panes'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(WorkspaceSessionPane.fromJson)
            .toList(growable: false),
        focusMode: json['focusMode'] as bool? ?? false,
      );
}

abstract interface class WorkspaceSessionStore {
  Future<WorkspaceSession?> load();

  Future<void> save(WorkspaceSession session);
}

class LocalWorkspaceSessionStore implements WorkspaceSessionStore {
  const LocalWorkspaceSessionStore();

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return File('${directory.path}/workspace_session.json');
  }

  @override
  Future<WorkspaceSession?> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, Object?>
          ? WorkspaceSession.fromJson(decoded)
          : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(WorkspaceSession session) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(session.toJson()), flush: true);
    if (file.existsSync()) file.deleteSync();
    await temporary.rename(file.path);
  }
}
