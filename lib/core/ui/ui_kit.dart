import 'package:flutter/material.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/core/ui/charts.dart';
import 'package:intl/intl.dart';

/// The standard bordered card.
typedef AppCard = GradientPanel;

// ───────────────────────────────────────────────────────────────────────────
// Dates
// ───────────────────────────────────────────────────────────────────────────

DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

/// "6 Oct 2026, 14:05" in the device's time zone, or '' when there is no date.
String formatDateTime(Object? value) {
  final date = parseDate(value);
  return date == null ? '' : DateFormat('d MMM y, HH:mm').format(date);
}

/// "6 Oct 2026".
String formatDate(Object? value) {
  final date = parseDate(value);
  return date == null ? '' : DateFormat('d MMM y').format(date);
}

/// "just now", "5 min ago", "3 h ago", "2 d ago", then the date.
String timeAgo(Object? value) {
  final date = parseDate(value);
  if (date == null) return '';
  final gap = DateTime.now().difference(date);
  if (gap.isNegative) return formatDateTime(value);
  if (gap.inMinutes < 1) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
  if (gap.inHours < 24) return '${gap.inHours} h ago';
  if (gap.inDays < 7) return '${gap.inDays} d ago';
  return formatDate(value);
}

// ───────────────────────────────────────────────────────────────────────────
// Page furniture
// ───────────────────────────────────────────────────────────────────────────

/// The title block at the top of every page: title, a line of explanation,
/// and the page's buttons on the right (below, on a narrow screen).
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.actions = const [],
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Shows a back arrow before the title when set.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final subtitle = this.subtitle;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: palette.muted)),
              ],
            ],
          ),
        ),
      ],
    );
    if (actions.isEmpty) return heading;
    final buttons = Wrap(spacing: 10, runSpacing: 10, children: actions);
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 720
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 14), buttons],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                buttons,
              ],
            ),
    );
  }
}

/// A card with a title row (and an optional link on the right) above its
/// content.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 20),
    this.fill = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  /// Gives [child] all the height the card has left. Only for a card whose
  /// own height is fixed by its parent.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final subtitle = this.subtitle;
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: palette.muted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// A headline number: what it is, its value, a line of context, and
/// optionally the recent trend.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    required this.icon,
    super.key,
    this.caption,
    this.tone = Tone.accent,
    this.trend,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;

  /// A short line under the value, e.g. "+4 this week".
  final String? caption;
  final Tone tone;

  /// Recent values, drawn as a small line.
  final List<double>? trend;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = toneColor(context, tone);
    final caption = this.caption;
    final trend = this.trend;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: palette.muted, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (trend != null && trend.length > 1) ...[
                const SizedBox(width: 10),
                Sparkline(values: trend, color: color),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays children out in equal columns that wrap: as many as fit at
/// [minWidth], up to [maxColumns].
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.children,
    super.key,
    this.minWidth = 230,
    this.maxColumns = 4,
    this.gap = 14,
  });

  final List<Widget> children;
  final double minWidth;
  final int maxColumns;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final fit = ((constraints.maxWidth + gap) / (minWidth + gap)).floor();
          final columns = fit < 1
              ? 1
              : fit > maxColumns
                  ? maxColumns
                  : fit;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final child in children)
                SizedBox(width: width.floorToDouble(), child: child),
            ],
          );
        },
      );
}

/// A thin inline banner: an icon, a sentence, and somewhere to go.
class NoticeBar extends StatelessWidget {
  const NoticeBar({
    required this.text,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.tone = Tone.info,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData icon;
  final Tone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    final actionLabel = this.actionLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}

/// The scrolling body every page sits in: centred, with the same margins,
/// and a gentle entrance.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.children,
    super.key,
    this.maxWidth = 1440,
    this.onRefresh,
  });

  final List<Widget> children;
  final double maxWidth;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        narrow ? 16 : 28,
        narrow ? 16 : 24,
        narrow ? 16 : 28,
        48,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    final onRefresh = this.onRefresh;
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh, child: list);
  }
}
