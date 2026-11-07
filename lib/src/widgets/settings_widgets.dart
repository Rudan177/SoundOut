import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.footnote,
  });

  final String title;
  final List<Widget> children;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Material(
            color: scheme.brightness == Brightness.dark
                ? scheme.surfaceContainerLow
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                children: [
                  for (var index = 0; index < children.length; index++) ...[
                    if (index > 0)
                      Divider(
                        height: 0.5,
                        thickness: 0.5,
                        indent: 16,
                        endIndent: 16,
                        color: scheme.onSurface.withValues(alpha: 0.08),
                      ),
                    children[index],
                  ],
                ],
              ),
            ),
          ),
          if (footnote != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Text(
                footnote!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.onSurfaceVariant),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: scheme.onSurfaceVariant),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
