import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

/// Rounded tinted square holding an icon — used for module tiles and list leading.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, required this.color, this.size = 40});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

/// Initials avatar for parties/staff.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.color, this.size = 40});
  final String name;
  final Color? color;
  final double size;

  static const _palette = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF0891B2), Color(0xFF16A34A),
    Color(0xFFEA580C), Color(0xFFDB2777), Color(0xFFCA8A04), Color(0xFF0F766E),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
            ? parts.first[0].toUpperCase()
            : (parts.first[0] + parts.last[0]).toUpperCase();
    final c = color ?? _palette[name.hashCode.abs() % _palette.length];
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: c.withValues(alpha: dark ? 0.25 : 0.14),
      child: Text(initials,
          style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: size * 0.36)),
    );
  }
}

/// Card with an optional header row.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
  });

  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.sm, 0),
              child: Row(
                children: [
                  Expanded(child: Text(title!, style: context.text.titleSmall)),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// KPI tile: label, big value, optional caption, accent icon.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.caption,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconBadge(icon, color: accent, size: 32),
                  const Spacer(),
                  if (onTap != null) Icon(Icons.chevron_right_rounded, size: 18, color: context.colors.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: Spacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value,
                    style: context.text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
              const SizedBox(height: 2),
              Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (caption != null)
                Text(caption!,
                    style: context.text.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Status pill with consistent colours across modules.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});
  final String status;
  final String? label;

  static Color colorFor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'active':
      case 'approved':
      case 'completed':
      case 'issued':
      case 'processed':
      case 'received':
      case 'accepted':
      case 'present':
      case 'sent':
      case 'open':
        return StatusColors.success;
      case 'partial':
      case 'partially_paid':
      case 'pending':
      case 'scheduled':
      case 'half_day':
      case 'submitted':
        return StatusColors.warning;
      case 'unpaid':
      case 'overdue':
      case 'rejected':
      case 'failed':
      case 'absent':
        return StatusColors.danger;
      case 'draft':
      case 'cancelled':
      case 'closed':
      case 'inactive':
      default:
        return StatusColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colorFor(status);
    final text = label ?? status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.isEmpty ? '—' : text[0].toUpperCase() + text.substring(1),
        style: TextStyle(
          color: c,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          decoration: status == 'cancelled' ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Label/value row for detail screens.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = bold ? context.text.titleSmall : context.text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: bold ? style : context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant))),
          const SizedBox(width: Spacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: style?.copyWith(color: valueColor, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: context.colors.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: context.colors.onPrimaryContainer),
            ),
            const SizedBox(height: Spacing.lg),
            Text(title, style: context.text.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(message!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: Spacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final network = error is ApiException && (error as ApiException).isNetwork;
    return EmptyState(
      icon: network ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: network ? 'You\'re offline' : 'Couldn\'t load this',
      message: errorMessage(error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
    );
  }
}

/// Grey placeholder rows shown while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 8});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors.surfaceContainerHigh;
    Widget bar(double w, double h) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(Spacing.lg),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: Spacing.lg),
      itemBuilder: (_, __) => Row(
        children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12))),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [bar(160, 12), const SizedBox(height: 8), bar(100, 10)],
            ),
          ),
          bar(64, 12),
        ],
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? StatusColors.danger : null,
  ));
}

/// Bottom-sheet confirmation; returns true when confirmed.
Future<bool> confirmSheet(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.xl, 0, Spacing.xl, Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: ctx.text.titleMedium),
            if (message != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(message, style: ctx.text.bodyMedium?.copyWith(color: ctx.colors.onSurfaceVariant)),
            ],
            const SizedBox(height: Spacing.xl),
            FilledButton(
              style: destructive ? FilledButton.styleFrom(backgroundColor: StatusColors.danger) : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: Spacing.sm),
            OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}

/// Constrains content to a readable width on tablets and centres it.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 720});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// Inline red banner for form-level errors.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: StatusColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Radii.control),
        border: Border.all(color: StatusColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: StatusColors.danger, size: 20),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(message, style: const TextStyle(color: StatusColors.danger))),
        ],
      ),
    );
  }
}
