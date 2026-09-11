import 'package:flutter/material.dart';

import '../data/release_notes.dart';
import '../theme/app_theme.dart';

class ReleaseNotesDialog extends StatelessWidget {
  const ReleaseNotesDialog({
    super.key,
    required this.release,
  });

  final ReleaseNotes release;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    final maxWidth = MediaQuery.sizeOf(context).width < 560 ? 420.0 : 560.0;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: 18 * uiScale,
          vertical: 24 * uiScale,
        ),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: AppTheme.glassPanel(highlighted: true, radius: 30),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20 * uiScale,
                20 * uiScale,
                20 * uiScale,
                18 * uiScale,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 54 * uiScale,
                        height: 54 * uiScale,
                        decoration: BoxDecoration(
                          gradient: AppTheme.actionGradient,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: AppTheme.neonGlow(alpha: 0.24),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.selectedTintText,
                          size: 26 * uiScale,
                        ),
                      ),
                      SizedBox(width: 12 * uiScale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              release.version,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppTheme.activeSoft,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            SizedBox(height: 4 * uiScale),
                            Text(
                              AppTheme.glitchText(release.title),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12 * uiScale),
                  Text(
                    AppTheme.glitchText(release.subtitle),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                          height: 1.55,
                        ),
                  ),
                  SizedBox(height: 16 * uiScale),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: release.items
                            .map(
                              (item) => Padding(
                                padding: EdgeInsets.only(bottom: 10 * uiScale),
                                child: _ReleaseNoteTile(item: item),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  SizedBox(height: 8 * uiScale),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppTheme.glitchText('知道了')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseNoteTile extends StatelessWidget {
  const _ReleaseNoteTile({required this.item});

  final ReleaseNoteItem item;

  @override
  Widget build(BuildContext context) {
    final uiScale = AppTheme.uiScaleOf(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * uiScale),
      decoration: BoxDecoration(
        color: AppTheme.translucentPanelFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.activeLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(item.icon, color: AppTheme.activeSoft, size: 22 * uiScale),
          SizedBox(width: 10 * uiScale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppTheme.glitchText(item.title),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.contrastText,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                SizedBox(height: 4 * uiScale),
                Text(
                  AppTheme.glitchText(item.description),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMuted,
                        height: 1.5,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
