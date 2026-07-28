import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/library/domain/sermon.dart';

enum LibraryView { all, drafts, ready, preached, series, trash }

enum SermonSort { updated, title, scheduled, bibleBook }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.initialView = LibraryView.all});
  final LibraryView initialView;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  late LibraryView _view = widget.initialView;
  SermonSort _sort = SermonSort.updated;
  String _query = '';
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapProvider);
    final sermons = ref.watch(sermonsProvider);
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _Sidebar(
              selected: _view,
              onSelected: (view) => setState(() => _view = view),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: sermons.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _ErrorState(
                  message: 'Bibliothek konnte nicht geladen werden.',
                  onRetry: () => ref.invalidate(sermonsProvider),
                ),
                data: (items) {
                  final filtered = _filterAndSort(items);
                  final selected = filtered
                      .where((sermon) => sermon.id == _selectedId)
                      .firstOrNull;
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final showDetails =
                          constraints.maxWidth >= AppSizes.expandedBreakpoint;
                      return Row(
                        children: [
                          Expanded(
                            flex: 5,
                            child: _SermonList(
                              sermons: filtered,
                              view: _view,
                              sort: _sort,
                              query: _query,
                              selectedId: _selectedId,
                              onQueryChanged: (value) =>
                                  setState(() => _query = value),
                              onSortChanged: (value) =>
                                  setState(() => _sort = value),
                              onSelected: (sermon) {
                                if (showDetails) {
                                  setState(() => _selectedId = sermon.id);
                                } else {
                                  context.go('/sermons/${sermon.id}/raw');
                                }
                              },
                              onCreate: _createSermon,
                              onAction: _handleAction,
                            ),
                          ),
                          if (showDetails) ...[
                            const VerticalDivider(width: 1),
                            Expanded(
                              flex: 4,
                              child: _DetailsPane(
                                sermon: selected,
                                onOpen: selected == null
                                    ? null
                                    : () => context.go(
                                        '/sermons/${selected.id}/raw',
                                      ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Sermon> _filterAndSort(List<Sermon> sermons) {
    final query = _query.trim().toLowerCase();
    final filtered = sermons.where((sermon) {
      final matchesView = switch (_view) {
        LibraryView.all => !sermon.isDeleted,
        LibraryView.drafts =>
          !sermon.isDeleted &&
              {SermonStatus.draft, SermonStatus.inProgress}.contains(
                sermon.status,
              ),
        LibraryView.ready =>
          !sermon.isDeleted && sermon.status == SermonStatus.ready,
        LibraryView.preached =>
          !sermon.isDeleted && sermon.status == SermonStatus.preached,
        LibraryView.series => !sermon.isDeleted && sermon.seriesId != null,
        LibraryView.trash => sermon.isDeleted,
      };
      if (!matchesView) return false;
      if (query.isEmpty) return true;
      return [
        sermon.title,
        sermon.subtitle,
        sermon.primaryBibleReference?.displayText ?? '',
        sermon.document.plainText,
        ...sermon.topics,
        ...sermon.tags,
      ].join(' ').toLowerCase().contains(query);
    }).toList();
    return filtered..sort(
      switch (_sort) {
        SermonSort.updated => (a, b) => b.updatedAt.compareTo(a.updatedAt),
        SermonSort.title => (a, b) => a.title.compareTo(b.title),
        SermonSort.scheduled => (a, b) => _nullableDate(
          a.scheduledAt,
          b.scheduledAt,
        ),
        SermonSort.bibleBook =>
          (a, b) => (a.primaryBibleReference?.bookId ?? 'zzz').compareTo(
            b.primaryBibleReference?.bookId ?? 'zzz',
          ),
      },
    );
  }

  int _nullableDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> _createSermon() async {
    final sermon = await ref.read(sermonRepositoryProvider).create();
    if (mounted) context.go('/sermons/${sermon.id}/raw');
  }

  Future<void> _handleAction(Sermon sermon, String action) async {
    final repository = ref.read(sermonRepositoryProvider);
    switch (action) {
      case 'duplicate':
        await repository.duplicate(sermon.id);
      case 'trash':
        await repository.moveToTrash(sermon.id);
      case 'restore':
        await repository.restore(sermon.id);
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Endgültig löschen?'),
            content: Text(
              '„${sermon.title}“ und gespeicherte Versionen werden entfernt.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Löschen'),
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          await repository.deletePermanently(sermon.id);
        }
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.selected, required this.onSelected});
  final LibraryView selected;
  final ValueChanged<LibraryView> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            'Sermonary',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final item in const [
          (LibraryView.all, Icons.library_books_outlined, 'Alle Predigten'),
          (LibraryView.drafts, Icons.edit_note_outlined, 'Entwürfe'),
          (LibraryView.ready, Icons.task_alt_outlined, 'Bereit'),
          (LibraryView.preached, Icons.record_voice_over_outlined, 'Gehalten'),
          (LibraryView.series, Icons.collections_bookmark_outlined, 'Reihen'),
        ])
          _NavItem(
            icon: item.$2,
            label: item.$3,
            selected: selected == item.$1,
            onTap: () => onSelected(item.$1),
          ),
        const Spacer(),
        _NavItem(
          icon: Icons.delete_outline,
          label: 'Papierkorb',
          selected: selected == LibraryView.trash,
          onTap: () => onSelected(LibraryView.trash),
        ),
      ],
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        leading: Icon(icon, size: 20),
        title: Text(label),
        onTap: onTap,
      ),
    ),
  );
}

class _SermonList extends StatelessWidget {
  const _SermonList({
    required this.sermons,
    required this.view,
    required this.sort,
    required this.query,
    required this.selectedId,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onSelected,
    required this.onCreate,
    required this.onAction,
  });
  final List<Sermon> sermons;
  final LibraryView view;
  final SermonSort sort;
  final String query;
  final String? selectedId;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<SermonSort> onSortChanged;
  final ValueChanged<Sermon> onSelected;
  final VoidCallback onCreate;
  final void Function(Sermon sermon, String action) onAction;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _viewTitle(view),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (view != LibraryView.trash)
              FilledButton.icon(
                key: const Key('new-sermon'),
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Neue Predigt'),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('library-search'),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Predigten durchsuchen',
                ),
                onChanged: onQueryChanged,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<SermonSort>(
              tooltip: 'Sortierung',
              initialValue: sort,
              onSelected: onSortChanged,
              icon: const Icon(Icons.sort),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: SermonSort.updated,
                  child: Text('Zuletzt bearbeitet'),
                ),
                PopupMenuItem(
                  value: SermonSort.title,
                  child: Text('Titel'),
                ),
                PopupMenuItem(
                  value: SermonSort.scheduled,
                  child: Text('Predigtdatum'),
                ),
                PopupMenuItem(
                  value: SermonSort.bibleBook,
                  child: Text('Bibelbuch'),
                ),
              ],
            ),
          ],
        ),
      ),
      Expanded(
        child: sermons.isEmpty
            ? Center(
                child: Text(
                  query.isEmpty
                      ? 'Hier sind noch keine Predigten.'
                      : 'Keine Treffer für „$query“.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: sermons.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sermon = sermons[index];
                  return Card(
                    color: selectedId == sermon.id
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : null,
                    child: ListTile(
                      key: Key('sermon-${sermon.id}'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      title: Text(
                        sermon.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (sermon.subtitle.isNotEmpty)
                              Text(sermon.subtitle),
                            _StatusLabel(status: sermon.status),
                            Text(
                              DateFormat(
                                'dd.MM.yyyy',
                              ).format(sermon.updatedAt.toLocal()),
                            ),
                          ],
                        ),
                      ),
                      onTap: () => onSelected(sermon),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Aktionen',
                        onSelected: (action) => onAction(sermon, action),
                        itemBuilder: (context) => sermon.isDeleted
                            ? const [
                                PopupMenuItem(
                                  value: 'restore',
                                  child: Text('Wiederherstellen'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Endgültig löschen'),
                                ),
                              ]
                            : const [
                                PopupMenuItem(
                                  value: 'duplicate',
                                  child: Text('Duplizieren'),
                                ),
                                PopupMenuItem(
                                  value: 'trash',
                                  child: Text('In Papierkorb'),
                                ),
                              ],
                      ),
                    ),
                  );
                },
              ),
      ),
    ],
  );

  String _viewTitle(LibraryView view) => switch (view) {
    LibraryView.all => 'Bibliothek',
    LibraryView.drafts => 'Entwürfe',
    LibraryView.ready => 'Bereit',
    LibraryView.preached => 'Gehalten',
    LibraryView.series => 'Predigtreihen',
    LibraryView.trash => 'Papierkorb',
  };
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.sermon, required this.onOpen});
  final Sermon? sermon;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) {
    final sermon = this.sermon;
    if (sermon == null) {
      return const Center(child: Text('Predigt auswählen'));
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sermon.title, style: Theme.of(context).textTheme.headlineMedium),
          if (sermon.subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sermon.subtitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 24),
          _MetadataRow(label: 'Status', value: _statusName(sermon.status)),
          _MetadataRow(
            label: 'Wörter',
            value: '${sermon.document.wordCount}',
          ),
          _MetadataRow(
            label: 'Geschätzt',
            value: '${sermon.document.estimatedDuration().inMinutes + 1} Min.',
          ),
          const SizedBox(height: 24),
          Text(
            sermon.document.plainText,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpen,
              child: const Text('Predigt öffnen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(value),
      ],
    ),
  );
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.status});
  final SermonStatus status;
  @override
  Widget build(BuildContext context) => Text(
    _statusName(status),
    style: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _statusName(SermonStatus status) => switch (status) {
  SermonStatus.draft => 'Entwurf',
  SermonStatus.inProgress => 'In Bearbeitung',
  SermonStatus.ready => 'Bereit',
  SermonStatus.preached => 'Gehalten',
  SermonStatus.archived => 'Archiviert',
};

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Erneut versuchen'),
        ),
      ],
    ),
  );
}
