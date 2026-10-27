import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The story tools inherit the active palette, silhouette and button artwork.
class StorySurfaceTheme extends StatelessWidget {
  const StorySurfaceTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ButtonStyle? roomySkinButton(ButtonStyle? style) =>
        !AppTheme.usesRasterWideButtonArtwork
            ? style
            : style?.copyWith(
                minimumSize: WidgetStateProperty.resolveWith((states) {
                final previous =
                    style.minimumSize?.resolve(states) ?? const Size(64, 40);
                return Size(math.max(96, previous.width), previous.height);
              }));

    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
            style: roomySkinButton(theme.filledButtonTheme.style)),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: roomySkinButton(theme.outlinedButtonTheme.style)),
        chipTheme: theme.chipTheme.copyWith(
          backgroundColor: AppTheme.panel.withValues(alpha: 0.35),
          selectedColor: AppTheme.activePrimary.withValues(alpha: 0.18),
          side: BorderSide(color: AppTheme.activeLine),
          labelStyle: theme.textTheme.labelLarge,
          checkmarkColor: AppTheme.activeSoft,
          shape: RoundedRectangleBorder(
              borderRadius: AppTheme.storySurface().borderRadius!),
        ),
        expansionTileTheme: theme.expansionTileTheme.copyWith(
          iconColor: AppTheme.activeSoft,
          collapsedIconColor: AppTheme.textMuted,
          textColor: AppTheme.textMain,
          collapsedTextColor: AppTheme.textMain,
          shape: const Border(),
          collapsedShape: const Border(),
        ),
      ),
      child: child,
    );
  }
}

class StoryDialog extends StatelessWidget {
  const StoryDialog(
      {super.key,
      required this.child,
      this.maxWidth = 520,
      this.maxHeight = 680,
      this.heightFraction = .82,
      this.insetPadding =
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24)});
  final Widget child;
  final double maxWidth, maxHeight, heightFraction;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = math.max(0.0,
        media.size.height - media.viewInsets.vertical - media.padding.vertical);
    final decoration = AppTheme.storySurface(opaque: true, highlighted: true);
    return Dialog(
      alignment: Alignment.center,
      insetPadding: insetPadding,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: math.min(
                maxHeight,
                math.min(available * heightFraction,
                    math.max(0, available - insetPadding.vertical)))),
        child: DecoratedBox(
          key: const ValueKey('story-dialog-surface'),
          decoration: decoration,
          child: ClipRRect(
            borderRadius:
                decoration.borderRadius!.resolve(Directionality.of(context)),
            child: StorySurfaceTheme(child: child),
          ),
        ),
      ),
    );
  }
}

/// Alert-style layout without a second Material dialog hiding the skin surface.
class StoryAlertDialog extends StatelessWidget {
  const StoryAlertDialog(
      {super.key,
      required this.title,
      required this.content,
      this.actions = const [],
      this.maxWidth = 620,
      this.insetPadding =
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      this.titlePadding = const EdgeInsets.fromLTRB(20, 20, 20, 12),
      this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 12),
      this.actionsPadding = const EdgeInsets.fromLTRB(16, 0, 16, 16)});
  final Widget title, content;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsets insetPadding, titlePadding, contentPadding, actionsPadding;

  @override
  Widget build(BuildContext context) => StoryDialog(
        maxWidth: maxWidth,
        insetPadding: insetPadding,
        child: Semantics(
            namesRoute: true,
            explicitChildNodes: true,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                      padding: titlePadding,
                      child: DefaultTextStyle(
                          style: Theme.of(context).textTheme.titleLarge!,
                          child: title)),
                  Flexible(
                      child: Padding(padding: contentPadding, child: content)),
                  if (actions.isNotEmpty)
                    Padding(
                        padding: actionsPadding,
                        child: OverflowBar(
                            alignment: MainAxisAlignment.end,
                            spacing: 8,
                            overflowSpacing: 8,
                            children: actions)),
                ])),
      );
}

class StorySection extends StatelessWidget {
  const StorySection(
      {super.key,
      required this.child,
      this.highlighted = false,
      this.padding = EdgeInsets.zero});
  final Widget child;
  final bool highlighted;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DecoratedBox(
          decoration: AppTheme.storySurface(highlighted: highlighted),
          child:
              StorySurfaceTheme(child: Padding(padding: padding, child: child)),
        ),
      );
}

class StoryExpansionSection extends StatelessWidget {
  const StoryExpansionSection(
      {super.key,
      required this.title,
      required this.children,
      this.subtitle,
      this.highlighted = false,
      this.childrenPadding = const EdgeInsets.all(12)});
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final bool highlighted;
  final EdgeInsets childrenPadding;
  @override
  Widget build(BuildContext context) => StorySection(
      highlighted: highlighted,
      child: ExpansionTile(
          title: title,
          subtitle: subtitle,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          childrenPadding: childrenPadding,
          children: children));
}
