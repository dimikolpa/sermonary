import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:sermonary/app/theme/app_theme.dart';

enum SermonWorkflowStage { outline, notes, script, presentation, live }

class SermonWorkflowContentItem {
  const SermonWorkflowContentItem({
    required this.id,
    required this.label,
    this.linked = false,
    this.stage,
    this.onboardingKey,
  });

  final String id;
  final String label;
  final bool linked;
  final SermonWorkflowStage? stage;
  final Key? onboardingKey;
}

class SermonWorkflowNavigation extends StatelessWidget {
  const SermonWorkflowNavigation({
    required this.sermonTitle,
    required this.activeStages,
    required this.onSelected,
    super.key,
    this.availableStages = const {
      SermonWorkflowStage.outline,
      SermonWorkflowStage.notes,
      SermonWorkflowStage.script,
      SermonWorkflowStage.presentation,
      SermonWorkflowStage.live,
    },
    this.backgroundColor,
    this.foregroundColor,
    this.contentItems = const [],
    this.activeContentIds = const {},
    this.onContentSelected,
  });

  final String sermonTitle;
  final Set<SermonWorkflowStage> activeStages;
  final Set<SermonWorkflowStage> availableStages;
  final ValueChanged<SermonWorkflowStage> onSelected;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final List<SermonWorkflowContentItem> contentItems;
  final Set<String> activeContentIds;
  final ValueChanged<String>? onContentSelected;

  static const Map<SermonWorkflowStage, String> _labels = {
    SermonWorkflowStage.outline: 'Outline',
    SermonWorkflowStage.notes: 'Notizen',
    SermonWorkflowStage.script: 'Script',
    SermonWorkflowStage.presentation: 'Präsentation',
    SermonWorkflowStage.live: 'Live',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = backgroundColor ?? scheme.surface;
    final foreground = foregroundColor ?? scheme.onSurface;
    return SizedBox(
      key: const Key('sermon-workflow-navigation'),
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      background,
                      background.withValues(alpha: .94),
                      background.withValues(alpha: 0),
                    ],
                    stops: const [0, .58, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 32,
            right: 32,
            bottom: 9,
            child: SizedBox(
              height: 30,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      sermonTitle.trim().isEmpty
                          ? 'Unbenannte Predigt'
                          : sermonTitle,
                      key: const Key('workflow-sermon-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontFamily: AppTypography.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: foreground.withValues(alpha: .48),
                      ),
                    ),
                  ),
                  _WorkflowSeparator(color: foreground),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: contentItems.isEmpty
                            ? [
                                for (final stage
                                    in SermonWorkflowStage.values.where(
                                      availableStages.contains,
                                    )) ...[
                                  _WorkflowStageButton(
                                    stage: stage,
                                    label: _labels[stage]!,
                                    active: activeStages.contains(stage),
                                    foreground: foreground,
                                    onPressed: () => onSelected(stage),
                                  ),
                                  if (stage !=
                                      SermonWorkflowStage.values
                                          .where(availableStages.contains)
                                          .last)
                                    _WorkflowSeparator(color: foreground),
                                ],
                              ]
                            : [
                                _WorkflowStageButton(
                                  stage: SermonWorkflowStage.outline,
                                  label: _labels[SermonWorkflowStage.outline]!,
                                  active: activeStages.contains(
                                    SermonWorkflowStage.outline,
                                  ),
                                  foreground: foreground,
                                  onPressed: () => onSelected(
                                    SermonWorkflowStage.outline,
                                  ),
                                ),
                                for (
                                  var index = 0;
                                  index < contentItems.length;
                                  index++
                                ) ...[
                                  _WorkflowSeparator(color: foreground),
                                  KeyedSubtree(
                                    key: contentItems[index].onboardingKey,
                                    child: _WorkflowContentButton(
                                      item: contentItems[index],
                                      legacyStageKey:
                                          contentItems[index].stage != null &&
                                          contentItems
                                              .take(index)
                                              .every(
                                                (item) =>
                                                    item.stage !=
                                                    contentItems[index].stage,
                                              ),
                                      active: activeContentIds.contains(
                                        contentItems[index].id,
                                      ),
                                      foreground: foreground,
                                      onPressed: onContentSelected == null
                                          ? null
                                          : () => onContentSelected!(
                                              contentItems[index].id,
                                            ),
                                    ),
                                  ),
                                ],
                                _WorkflowSeparator(color: foreground),
                                _WorkflowStageButton(
                                  stage: SermonWorkflowStage.live,
                                  label: _labels[SermonWorkflowStage.live]!,
                                  active: activeStages.contains(
                                    SermonWorkflowStage.live,
                                  ),
                                  foreground: foreground,
                                  onPressed: () =>
                                      onSelected(SermonWorkflowStage.live),
                                ),
                              ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowContentButton extends StatelessWidget {
  const _WorkflowContentButton({
    required this.item,
    required this.legacyStageKey,
    required this.active,
    required this.foreground,
    required this.onPressed,
  });

  final SermonWorkflowContentItem item;
  final bool legacyStageKey;
  final bool active;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    key: legacyStageKey ? Key('${item.stage!.name}-view-button') : null,
    message: switch (item.stage) {
      SermonWorkflowStage.notes => 'Notizen',
      SermonWorkflowStage.script => 'Skript',
      SermonWorkflowStage.presentation => 'Präsentation',
      SermonWorkflowStage.outline => 'Outline',
      SermonWorkflowStage.live => 'Live',
      null => item.label,
    },
    child: Semantics(
      key: Key(
        legacyStageKey
            ? 'workflow-stage-${item.stage!.name}'
            : 'workflow-content-${item.id}',
      ),
      selected: active,
      button: true,
      child: TextButton(
        key: Key('workflow-content-${item.id}'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 26),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          foregroundColor: active
              ? foreground.withValues(alpha: .92)
              : foreground.withValues(alpha: .27),
          backgroundColor: active
              ? foreground.withValues(alpha: .07)
              : Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: TextStyle(
            fontFamily: AppTypography.ui,
            fontSize: 10.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              switch (item.stage) {
                SermonWorkflowStage.notes => LucideIcons.notebookPen,
                SermonWorkflowStage.script => LucideIcons.scrollText,
                SermonWorkflowStage.presentation =>
                  LucideIcons.galleryHorizontal,
                SermonWorkflowStage.outline => LucideIcons.layoutTemplate,
                SermonWorkflowStage.live => LucideIcons.monitorPlay,
                null => LucideIcons.fileText,
              },
              key: Key('workflow-content-icon-${item.id}'),
              size: 11,
            ),
            const SizedBox(width: 4),
            Text(item.label),
          ],
        ),
      ),
    ),
  );
}

class _WorkflowStageButton extends StatelessWidget {
  const _WorkflowStageButton({
    required this.stage,
    required this.label,
    required this.active,
    required this.foreground,
    required this.onPressed,
  });

  final SermonWorkflowStage stage;
  final String label;
  final bool active;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    key: Key('workflow-stage-${stage.name}'),
    selected: active,
    button: true,
    label: '$label, ${active ? 'aktiv' : 'inaktiv'}',
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 26),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        foregroundColor: active
            ? foreground.withValues(alpha: .92)
            : foreground.withValues(alpha: .27),
        backgroundColor: active
            ? foreground.withValues(alpha: .07)
            : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: TextStyle(
          fontFamily: AppTypography.ui,
          fontSize: 10.5,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      child: Text(label),
    ),
  );
}

class _WorkflowSeparator extends StatelessWidget {
  const _WorkflowSeparator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 1),
    child: Text(
      '›',
      style: TextStyle(
        fontFamily: AppTypography.ui,
        fontSize: 11,
        color: color.withValues(alpha: .17),
      ),
    ),
  );
}
