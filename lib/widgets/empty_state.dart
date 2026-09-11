import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.actionKey,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: AppTheme.glassPanel(highlighted: true, radius: 26),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.activePrimary.withValues(alpha: 0.24),
                        AppTheme.activeSecondary.withValues(alpha: 0.18),
                        AppTheme.activeAccent.withValues(alpha: 0.14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.activeLine),
                    boxShadow: AppTheme.neonGlow(alpha: 0.08),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 40,
                    color: AppTheme.activeSoft,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  AppTheme.glitchText(title),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppTheme.glitchText(description),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: actionKey,
                    onPressed: onAction,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(AppTheme.glitchText(actionLabel!)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
