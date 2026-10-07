import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/core/ui/charts.dart';
import 'package:fpl_wager_admin/core/ui/ui_kit.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_actions.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager_admin/features/admin/presentation/record_actions.dart';
import 'package:fpl_wager_admin/features/auth/presentation/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The first page after signing in: what needs attention, the headline
/// numbers, two weeks of money movement, and the latest goings-on.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminStatsProvider);
    ref.invalidate(adminRecentProvider('withdrawals'));
    ref.invalidate(adminRecentProvider('audit-logs'));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(authControllerProvider).orNull?.user;
    final summary = ref.watch(adminDashboardProvider);
    final stats = ref.watch(adminStatsProvider);
    final attention = ref.watch(attentionProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final statsData = stats.orNull;
    final days = _maps(statsData?['days']);
    final totals = _map(statsData?['totals']);
    final wide = MediaQuery.sizeOf(context).width >= 1180;

    final moneyChart = SectionCard(
      title: 'Money in and out',
      subtitle: 'The last 14 days',
      fill: wide,
      child: statsData == null
          ? _Pending(
              value: stats,
              height: 280,
              onRetry: () => ref.invalidate(adminStatsProvider),
            )
          : SeriesChart(
              // Beside the pools card the chart takes the card's height.
              height: wide ? null : 240,
              labels: [for (final day in days) _dayLabel(day['day'])],
              formatValue: (value) => compactMoney(value.round()),
              series: [
                ChartSeries(
                  name: 'Top-ups',
                  color: toneColor(context, Tone.success),
                  values: _series(days, 'deposits_cents'),
                ),
                ChartSeries(
                  name: 'Stakes',
                  color: AppColors.purple,
                  values: _series(days, 'stakes_cents'),
                ),
                ChartSeries(
                  name: 'Withdrawals',
                  color: toneColor(context, Tone.warning),
                  values: _series(days, 'withdrawals_cents'),
                ),
              ],
            ),
    );

    final poolsChart = SectionCard(
      title: 'Pools by status',
      subtitle: 'Every pool on the platform',
      trailing: TextButton(
        onPressed: () => context.go('/resources/wagers'),
        child: const Text('View all'),
      ),
      fill: wide,
      child: statsData == null
          ? _Pending(
              value: stats,
              height: 190,
              onRetry: () => ref.invalidate(adminStatsProvider),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                // Shrinks the ring and its legend together if the card is
                // too small for them at full size.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: DonutChart(
                    centerLabel: 'pools',
                    segments: _poolSegments(
                      context,
                      _map(statsData['pools_by_status']),
                    ),
                  ),
                ),
              ),
            ),
    );

    final withdrawals = SectionCard(
      title: 'Latest withdrawals',
      subtitle: attention.withdrawals > 0
          ? '${attention.withdrawals} waiting for approval'
          : 'Nothing is waiting for approval',
      trailing: TextButton(
        onPressed: () => context.go('/resources/withdrawals'),
        child: const Text('View all'),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: _RecentList(
        provider: adminRecentProvider('withdrawals'),
        emptyText: 'No withdrawal has been requested yet.',
        builder: (record) => _RecentRow(
          title: firstValue(record, const ['full_name', 'email']),
          subtitle: bankOf(record['bank_details']),
          trailing: moneyOf(record['amount_cents']),
          status: '${record['status'] ?? ''}',
          when: timeAgo(record['created_at']),
        ),
      ),
    );

    final activity = SectionCard(
      title: 'Recent activity',
      subtitle: 'What administrators have done',
      trailing: TextButton(
        onPressed: () => context.go('/resources/audit-logs'),
        child: const Text('Audit trail'),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: _RecentList(
        provider: adminRecentProvider('audit-logs'),
        emptyText: 'Nothing has been changed yet.',
        builder: (record) => _ActivityRow(
          action: '${record['action'] ?? ''}',
          who: firstValue(record, const ['admin_name', 'email']),
          when: timeAgo(record['created_at']),
        ),
      ),
    );

    return PageBody(
      onRefresh: () async {
        _refresh(ref);
        await ref.read(adminDashboardProvider.future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: 'Dashboard',
            subtitle:
                '$greeting, ${admin?.firstName ?? 'there'}. '
                '${DateFormat('EEEE, d MMMM').format(DateTime.now())}.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _refresh(ref),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/resources/wagers'),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Manage pools'),
              ),
            ],
          ),
        ),
        if (attention.pools > 0) ...[
          const SizedBox(height: 16),
          NoticeBar(
            icon: Icons.pending_actions_rounded,
            tone: Tone.warning,
            text: attention.pools == 1
                ? '1 pool is waiting for your approval.'
                : '${attention.pools} pools are waiting for your approval.',
            actionLabel: 'Review',
            onAction: () => context.go('/resources/wagers'),
          ),
        ],
        if (attention.withdrawals > 0) ...[
          const SizedBox(height: 10),
          NoticeBar(
            icon: Icons.north_east_rounded,
            tone: Tone.warning,
            text: attention.withdrawals == 1
                ? '1 withdrawal is waiting for your approval.'
                : '${attention.withdrawals} withdrawals are waiting for your approval.',
            actionLabel: 'Review',
            onAction: () => context.go('/resources/withdrawals'),
          ),
        ],
        const SizedBox(height: 20),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: summary.orNull == null
              ? _Pending(
                  value: summary,
                  height: 130,
                  onRetry: () => ref.invalidate(adminDashboardProvider),
                )
              : ResponsiveGrid(
                  children: [
                    StatCard(
                      label: 'Users',
                      value: _count(summary.requireValue.users),
                      icon: Icons.people_outline_rounded,
                      caption: statsData == null
                          ? null
                          : '+${_lastDays(days, 'new_users', 7)} in the last 7 days',
                      trend: statsData == null
                          ? null
                          : _series(days, 'new_users'),
                      onTap: () => context.go('/resources/users'),
                    ),
                    StatCard(
                      label: 'Active pools',
                      value: _count(summary.requireValue.activeWagers),
                      icon: Icons.emoji_events_outlined,
                      tone: Tone.info,
                      caption: attention.pools > 0
                          ? '${attention.pools} awaiting approval'
                          : 'Open or in play',
                      trend: statsData == null
                          ? null
                          : _series(days, 'stakes_cents'),
                      onTap: () => context.go('/resources/wagers'),
                    ),
                    StatCard(
                      label: 'In wallets',
                      value: money(summary.requireValue.availableCents),
                      icon: Icons.account_balance_wallet_outlined,
                      tone: Tone.success,
                      caption:
                          '${money(summary.requireValue.lockedCents)} locked in games',
                      onTap: () => context.go('/resources/wallets'),
                    ),
                    StatCard(
                      label: 'Platform fees earned',
                      value: money(_cents(totals, 'platform_fees_cents')),
                      icon: Icons.savings_outlined,
                      tone: Tone.warning,
                      caption: 'From settled pools',
                      onTap: () => context.go('/resources/transactions'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: wide
              // A fixed height keeps the two cards level; the chart inside
              // is a fixed height too.
              ? SizedBox(
                  height: 430,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 5, child: moneyChart),
                      const SizedBox(width: 14),
                      Expanded(flex: 3, child: poolsChart),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    moneyChart,
                    const SizedBox(height: 14),
                    poolsChart,
                  ],
                ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: withdrawals),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: activity),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [withdrawals, const SizedBox(height: 14), activity],
                ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 240),
          child: ResponsiveGrid(
            maxColumns: 3,
            minWidth: 260,
            children: [
              _FinanceCard(
                label: 'Topped up, all time',
                value: money(_cents(totals, 'deposits_cents')),
                caption: summary.orNull == null
                    ? ''
                    : '${summary.requireValue.pendingPayments} '
                          '${summary.requireValue.pendingPayments == 1 ? 'payment' : 'payments'} still pending',
                icon: Icons.south_west_rounded,
                tone: Tone.success,
              ),
              _FinanceCard(
                label: 'Winnings paid out',
                value: money(_cents(totals, 'winnings_paid_cents')),
                caption:
                    '${money(_cents(totals, 'stakes_cents'))} staked in total',
                icon: Icons.military_tech_outlined,
                tone: Tone.info,
              ),
              _FinanceCard(
                label: 'Withdrawn to banks',
                value: money(_cents(totals, 'withdrawals_paid_cents')),
                caption:
                    '${money(_cents(totals, 'withdrawals_pending_cents'))} requested and not yet paid',
                icon: Icons.north_east_rounded,
                tone: Tone.warning,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Reading the stats
// ───────────────────────────────────────────────────────────────────────────

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const <String, Object?>{};

List<Map<String, Object?>> _maps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, Object?>.from(item),
      ]
    : const [];

int _cents(Map<String, Object?> map, String key) =>
    (map[key] as num? ?? 0).toInt();

List<double> _series(List<Map<String, Object?>> days, String key) => [
  for (final day in days) (day[key] as num? ?? 0).toDouble(),
];

/// The sum of a daily figure over the most recent [count] days.
int _lastDays(List<Map<String, Object?>> days, String key, int count) {
  final recent = days.length > count ? days.sublist(days.length - count) : days;
  return recent.fold<int>(
    0,
    (sum, day) => sum + (day[key] as num? ?? 0).toInt(),
  );
}

String _count(int value) => NumberFormat.decimalPattern().format(value);

/// "6 Oct" from "2026-10-06".
String _dayLabel(Object? day) {
  final date = day is String ? DateTime.tryParse(day) : null;
  return date == null ? '$day' : DateFormat('d MMM').format(date);
}

List<DonutSegment> _poolSegments(
  BuildContext context,
  Map<String, Object?> byStatus,
) {
  // A fixed order, so each status keeps its place and colour.
  const order = ['open', 'locked', 'scoring', 'settled', 'draft', 'cancelled'];
  Color colorFor(String status) => switch (status) {
    'open' => toneColor(context, Tone.success),
    'locked' => toneColor(context, Tone.warning),
    'scoring' => AppColors.purple,
    'settled' => toneColor(context, Tone.info),
    'draft' => AppColors.amber,
    'cancelled' => toneColor(context, Tone.danger),
    _ => Palette.of(context).muted,
  };
  final names = [
    ...order.where(byStatus.containsKey),
    ...byStatus.keys.where((name) => !order.contains(name)),
  ];
  return [
    for (final name in names)
      DonutSegment(
        label: name == 'draft'
            ? 'Awaiting approval'
            : name[0].toUpperCase() + name.substring(1),
        value: (byStatus[name] as num? ?? 0).toDouble(),
        color: colorFor(name),
      ),
  ];
}

// ───────────────────────────────────────────────────────────────────────────
// Pieces
// ───────────────────────────────────────────────────────────────────────────

/// What a card shows while its figures are loading, or if they failed.
class _Pending extends StatelessWidget {
  const _Pending({
    required this.value,
    required this.height,
    required this.onRetry,
  });

  final AsyncValue<Object?> value;
  final double height;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: value.hasError
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${value.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Palette.of(context).muted),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: onRetry, child: const Text('Try again')),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}

/// A short list fed by one of the "recent" providers.
class _RecentList extends ConsumerWidget {
  const _RecentList({
    required this.provider,
    required this.emptyText,
    required this.builder,
  });

  final ProviderListenable<AsyncValue<List<Map<String, Object?>>>> provider;
  final String emptyText;
  final Widget Function(Map<String, Object?> record) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    final items = value.orNull;
    final palette = Palette.of(context);
    if (items == null) {
      return SizedBox(
        height: 140,
        child: Center(
          child: value.hasError
              ? Text('${value.error}', style: TextStyle(color: palette.muted))
              : const CircularProgressIndicator(),
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(emptyText, style: TextStyle(color: palette.muted)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Container(
            decoration: BoxDecoration(
              border: i == items.length - 1
                  ? null
                  : Border(bottom: BorderSide(color: palette.border)),
            ),
            child: builder(items[i]),
          ),
      ],
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.status,
    required this.when,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final String status;
  final String when;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [subtitle, when].where((part) => part.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailing,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              if (status.isNotEmpty) StatusPill(status),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.action,
    required this.who,
    required this.when,
  });

  final String action;
  final String who;
  final String when;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sentence(action),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  [who, when].where((part) => part.isNotEmpty).join(' · '),
                  style: TextStyle(color: palette.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "wager.status.update" → "Wager status update".
  static String _sentence(String action) {
    final text = action.replaceAll(RegExp(r'[._]'), ' ').trim();
    return text.isEmpty ? 'Change' : text[0].toUpperCase() + text.substring(1);
  }
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = toneColor(context, tone);
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(fontSize: 21),
                  ),
                ),
                if (caption.isNotEmpty)
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontSize: 12.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
