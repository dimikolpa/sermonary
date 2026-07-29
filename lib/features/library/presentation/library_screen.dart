import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sermonary/app/providers.dart';
import 'package:sermonary/app/theme/app_theme.dart';
import 'package:sermonary/features/bible/domain/bible_reference.dart';
import 'package:sermonary/features/library/domain/sermon.dart';

enum LibraryView {
  all,
  bibleBook,
  series,
  talks,
  shortTopics,
  trash,
}

enum SermonSort { updated, title, scheduled, biblePassage }

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
  String? _selectedBookId;
  String? _selectedSeriesId;

  @override
  Widget build(BuildContext context) {
    ref.watch(bootstrapProvider);
    final sermonsAsync = ref.watch(sermonsProvider);
    return Scaffold(
      body: SafeArea(
        child: sermonsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _ErrorState(
            message: 'Bibliothek konnte nicht geladen werden.',
            onRetry: () => ref.invalidate(sermonsProvider),
          ),
          data: (items) => Row(
            children: [
              _Sidebar(
                sermons: items,
                selected: _view,
                selectedBookId: _selectedBookId,
                selectedSeriesId: _selectedSeriesId,
                onSelected: _selectView,
                onBookSelected: _selectBook,
                onSeriesSelected: _selectSeries,
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildLibraryContent(items)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLibraryContent(List<Sermon> items) {
    final filtered = _filterAndSort(items);
    final selected = filtered
        .where((sermon) => sermon.id == _selectedId)
        .firstOrNull;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showDetails = constraints.maxWidth >= AppSizes.expandedBreakpoint;
        return Row(
          children: [
            Expanded(
              flex: 5,
              child: _SermonList(
                sermons: filtered,
                title: _viewTitle,
                view: _view,
                sort: _sort,
                query: _query,
                selectedId: _selectedId,
                onQueryChanged: (value) => setState(() => _query = value),
                onSortChanged: (value) => setState(() => _sort = value),
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
                      : () => context.go('/sermons/${selected.id}/raw'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String get _viewTitle => switch (_view) {
    LibraryView.all => 'Bibliothek',
    LibraryView.bibleBook =>
      _selectedBookId == null
          ? 'Bibelbuch'
          : BibleBookCatalog.labelFor(_selectedBookId!),
    LibraryView.series => _selectedSeriesId ?? 'Vortragsreihen',
    LibraryView.talks => 'Vorträge',
    LibraryView.shortTopics => 'Kurzthemen',
    LibraryView.trash => 'Papierkorb',
  };

  void _selectView(LibraryView view) => setState(() {
    _view = view;
    _selectedBookId = null;
    _selectedSeriesId = null;
    _selectedId = null;
    _sort = view == LibraryView.all ? SermonSort.updated : SermonSort.title;
  });

  void _selectBook(String bookId) => setState(() {
    _view = LibraryView.bibleBook;
    _selectedBookId = bookId;
    _selectedSeriesId = null;
    _selectedId = null;
    _sort = SermonSort.biblePassage;
  });

  void _selectSeries(String seriesId) => setState(() {
    _view = LibraryView.series;
    _selectedSeriesId = seriesId;
    _selectedBookId = null;
    _selectedId = null;
    _sort = SermonSort.title;
  });

  List<Sermon> _filterAndSort(List<Sermon> sermons) {
    final query = _query.trim().toLowerCase();
    final filtered = sermons.where((sermon) {
      final matchesView = switch (_view) {
        LibraryView.all =>
          !sermon.isDeleted && sermon.contentKind == ContentKind.sermon,
        LibraryView.bibleBook =>
          !sermon.isDeleted &&
              sermon.contentKind == ContentKind.sermon &&
              sermon.primaryBibleReference?.bookId == _selectedBookId,
        LibraryView.series =>
          !sermon.isDeleted &&
              sermon.seriesId != null &&
              (_selectedSeriesId == null ||
                  sermon.seriesId == _selectedSeriesId),
        LibraryView.talks =>
          !sermon.isDeleted && sermon.contentKind == ContentKind.talk,
        LibraryView.shortTopics =>
          !sermon.isDeleted && sermon.contentKind == ContentKind.shortTopic,
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
        SermonSort.scheduled => (a, b) => _compareNullableDates(
          a.scheduledAt,
          b.scheduledAt,
        ),
        SermonSort.biblePassage => _compareBiblePassages,
      },
    );
  }

  int _compareBiblePassages(Sermon a, Sermon b) {
    final left = a.primaryBibleReference;
    final right = b.primaryBibleReference;
    if (left == null && right == null) return a.title.compareTo(b.title);
    if (left == null) return 1;
    if (right == null) return -1;
    final bookComparison = BibleBookCatalog.orderOf(
      left.bookId,
    ).compareTo(BibleBookCatalog.orderOf(right.bookId));
    if (bookComparison != 0) return bookComparison;
    final chapterComparison = left.startChapter.compareTo(right.startChapter);
    if (chapterComparison != 0) return chapterComparison;
    final verseComparison = (left.startVerse ?? 0).compareTo(
      right.startVerse ?? 0,
    );
    return verseComparison != 0 ? verseComparison : a.title.compareTo(b.title);
  }

  int _compareNullableDates(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> _createSermon() async {
    final repository = ref.read(sermonRepositoryProvider);
    var sermon = await repository.create();
    final contentKind = switch (_view) {
      LibraryView.talks => ContentKind.talk,
      LibraryView.shortTopics => ContentKind.shortTopic,
      _ => ContentKind.sermon,
    };
    if (contentKind != sermon.contentKind) {
      sermon = sermon.copyWith(contentKind: contentKind);
      await repository.update(sermon);
    }
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
  const _Sidebar({
    required this.sermons,
    required this.selected,
    required this.selectedBookId,
    required this.selectedSeriesId,
    required this.onSelected,
    required this.onBookSelected,
    required this.onSeriesSelected,
  });

  final List<Sermon> sermons;
  final LibraryView selected;
  final String? selectedBookId;
  final String? selectedSeriesId;
  final ValueChanged<LibraryView> onSelected;
  final ValueChanged<String> onBookSelected;
  final ValueChanged<String> onSeriesSelected;

  @override
  Widget build(BuildContext context) {
    final visibleSermons = sermons
        .where(
          (sermon) =>
              !sermon.isDeleted &&
              sermon.contentKind == ContentKind.sermon &&
              sermon.primaryBibleReference != null,
        )
        .toList(growable: false);
    final bookIds =
        visibleSermons
            .map((sermon) => sermon.primaryBibleReference!.bookId)
            .toSet()
            .toList()
          ..sort(
            (a, b) => BibleBookCatalog.orderOf(
              a,
            ).compareTo(BibleBookCatalog.orderOf(b)),
          );
    final seriesIds =
        sermons
            .where(
              (sermon) =>
                  !sermon.isDeleted &&
                  sermon.seriesId != null &&
                  sermon.seriesId!.trim().isNotEmpty,
            )
            .map((sermon) => sermon.seriesId!)
            .toSet()
            .toList()
          ..sort();
    return Container(
      width: 230,
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
          const SizedBox(height: AppSpacing.md),
          const _SectionLabel(label: 'BIBLIOTHEK'),
          _NavItem(
            icon: Icons.library_books_outlined,
            label: 'Alle Predigten',
            selected: selected == LibraryView.all,
            onTap: () => onSelected(LibraryView.all),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final bookId in bookIds)
                  _NavItem(
                    icon: Icons.menu_book_outlined,
                    label: BibleBookCatalog.labelFor(bookId),
                    count: visibleSermons
                        .where(
                          (sermon) =>
                              sermon.primaryBibleReference!.bookId == bookId,
                        )
                        .length,
                    selected:
                        selected == LibraryView.bibleBook &&
                        selectedBookId == bookId,
                    onTap: () => onBookSelected(bookId),
                  ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(),
                ),
                const _SectionLabel(label: 'VORTRAGSREIHEN'),
                _NavItem(
                  icon: Icons.collections_bookmark_outlined,
                  label: 'Alle Reihen',
                  selected:
                      selected == LibraryView.series &&
                      selectedSeriesId == null,
                  onTap: () => onSelected(LibraryView.series),
                ),
                for (final seriesId in seriesIds)
                  _NavItem(
                    icon: Icons.subdirectory_arrow_right,
                    label: seriesId,
                    count: sermons
                        .where((sermon) => sermon.seriesId == seriesId)
                        .length,
                    selected:
                        selected == LibraryView.series &&
                        selectedSeriesId == seriesId,
                    onTap: () => onSeriesSelected(seriesId),
                  ),
                const SizedBox(height: AppSpacing.sm),
                _NavItem(
                  icon: Icons.co_present_outlined,
                  label: 'Vorträge',
                  selected: selected == LibraryView.talks,
                  onTap: () => onSelected(LibraryView.talks),
                ),
                _NavItem(
                  icon: Icons.lightbulb_outline,
                  label: 'Kurzthemen',
                  selected: selected == LibraryView.shortTopics,
                  onTap: () => onSelected(LibraryView.shortTopics),
                ),
              ],
            ),
          ),
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
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

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
        leading: Icon(icon, size: 19),
        title: Text(label),
        trailing: count == null
            ? null
            : Text('$count', style: Theme.of(context).textTheme.labelSmall),
        onTap: onTap,
      ),
    ),
  );
}

class _SermonList extends StatelessWidget {
  const _SermonList({
    required this.sermons,
    required this.title,
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
  final String title;
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
                title,
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
                label: Text(
                  switch (view) {
                    LibraryView.talks => 'Neuer Vortrag',
                    LibraryView.shortTopics => 'Neues Kurzthema',
                    _ => 'Neue Predigt',
                  },
                ),
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
                  hintText: 'Archiv durchsuchen',
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
                  value: SermonSort.biblePassage,
                  child: Text('Bibelabschnitt'),
                ),
                PopupMenuItem(
                  value: SermonSort.updated,
                  child: Text('Zuletzt bearbeitet'),
                ),
                PopupMenuItem(value: SermonSort.title, child: Text('Titel')),
                PopupMenuItem(
                  value: SermonSort.scheduled,
                  child: Text('Predigtdatum'),
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
                      ? 'Hier sind noch keine Einträge.'
                      : 'Keine Treffer für „$query“.',
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: sermons.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final sermon = sermons[index];
                  final reference = sermon.primaryBibleReference?.displayText;
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
                      leading: reference == null
                          ? null
                          : _ReferenceBadge(reference: reference),
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
}

class _ReferenceBadge extends StatelessWidget {
  const _ReferenceBadge({required this.reference});
  final String reference;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 72, maxWidth: 112),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Text(
      reference,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({required this.sermon, required this.onOpen});
  final Sermon? sermon;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final sermon = this.sermon;
    if (sermon == null) {
      return const Center(child: Text('Eintrag auswählen'));
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sermon.primaryBibleReference case final reference?) ...[
            Text(
              reference.displayText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
          ],
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
              child: const Text('Öffnen'),
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
