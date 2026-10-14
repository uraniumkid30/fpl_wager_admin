import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One pool: its money, every entry with its live or final position, the
/// winners once it is settled, its prize plan and settings, and everything
/// that can be done to it.
class AdminPoolScreen extends ConsumerWidget {
  const AdminPoolScreen({required this.poolId, super.key});
  final String poolId;

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/resources/wagers');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminPoolProvider(poolId));
    final busy = ref.watch(adminActionProvider).isLoading;
    return AsyncContent(
      value: value,
      onRetry: () => ref.invalidate(adminPoolProvider(poolId)),
      data: (pool) {
        final palette = Palette.of(context);
        final status = '${pool['status'] ?? ''}';
        final live = status == 'locked' || status == 'scoring';
        final settled = status == 'settled';
        final ranked = pool['ranked'] == true;
        final finances = _map(pool['finances']);
        final members = _list(pool['members']);
        final payout = _map(pool['payout']);
        final actions = actionsFor('wagers', pool)
            .where((action) => action.key != 'members')
            .toList();
        final creator = '${pool['creator_name'] ?? ''}';
        final kind = '${pool['pool_kind']}' == 'auto' ? 'Auto pool' : 'Custom pool';

        Future<void> run(String action) async {
          await performRecordAction(context, ref, 'wagers', pool, action);
          if (!context.mounted) return;
          ref.invalidate(adminPoolProvider(poolId));
          if (action == 'delete') {
            // Gone if the delete went through.
            try {
              await ref.read(adminPoolProvider(poolId).future);
            } catch (_) {
              if (context.mounted) context.go('/resources/wagers');
            }
          }
        }

        final winners = members
            .where((m) => m['status'] == 'active' && _int(m['payout_cents']) > 0)
            .toList();

        return PageBody(
          maxWidth: 1280,
          onRefresh: () async {
            ref.invalidate(adminPoolProvider(poolId));
            await ref.read(adminPoolProvider(poolId).future);
          },
          children: [
            FadeSlideIn(
              child: PageHeader(
                title: '${pool['name'] ?? 'Pool'}',
                subtitle: [
                  'Gameweek ${pool['gameweek']}',
                  kind,
                  if ('${pool['visibility']}' == 'private') 'private',
                  if (creator.isNotEmpty) 'created by $creator',
                ].join(' · '),
                onBack: () => _back(context),
                actions: [
                  for (final action in actions)
                    _ActionButton(
                      label: action.label,
                      icon: action.icon,
                      primary: action.primary,
                      destructive: action.destructive,
                      onPressed: busy ? null : () => run(action.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(readableStatus(status)),
                StatusPill(
                  'Deadline ${formatDateTime(pool['deadline'])}',
                  tone: Tone.neutral,
                  dot: false,
                ),
                if (live)
                  StatusPill(
                    ranked
                        ? 'Live positions · updated ${timeAgo(pool['scored_at'])}'
                        : 'In play · no points scored yet',
                    tone: Tone.info,
                  ),
                InkWell(
                  onTap: () => context.push('/gameweeks/${pool['gameweek']}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      'Open gameweek ${pool['gameweek']}',
                      style: TextStyle(
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (status == 'cancelled') ...[
              const SizedBox(height: 14),
              const NoticeBar(
                text: 'This pool was cancelled and every entry was refunded. '
                    'It can no longer be edited or reopened.',
                tone: Tone.warning,
              ),
            ],
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: ResponsiveGrid(
                minWidth: 190,
                maxColumns: 6,
                children: [
                  StatCard(
                    label: 'Entries',
                    value: _count(finances['entries']),
                    icon: Icons.groups_2_outlined,
                    caption: _joinOrNull([
                      if (_int(finances['pending']) > 0)
                        '${finances['pending']} pending',
                      if (_int(finances['refunded']) > 0)
                        '${finances['refunded']} refunded',
                      if (pool['max_members'] is num) 'limit ${pool['max_members']}',
                    ]),
                  ),
                  StatCard(
                    label: 'Total staked',
                    value: moneyOf(finances['total_staked_cents']),
                    icon: Icons.payments_outlined,
                    caption: 'stake ${moneyOf(pool['stake_cents'])}',
                  ),
                  StatCard(
                    label: 'House cut',
                    value: moneyOf(finances['house_cut_cents']),
                    icon: Icons.account_balance_outlined,
                    tone: Tone.info,
                    caption: payout['house_cut_percent'] is num
                        ? '${_percent(payout['house_cut_percent'])}% of the pot'
                        : null,
                  ),
                  StatCard(
                    label: 'Prize pool',
                    value: moneyOf(finances['prize_pool_cents']),
                    icon: Icons.emoji_events_outlined,
                    tone: Tone.success,
                    caption: _int(payout['winners']) > 0
                        ? '${payout['winners']} paid place${_int(payout['winners']) == 1 ? '' : 's'}'
                        : null,
                  ),
                  StatCard(
                    label: 'Paid out',
                    value: settled ? moneyOf(finances['paid_out_cents']) : '—',
                    icon: Icons.north_east_rounded,
                    tone: Tone.success,
                    caption: settled ? 'to the winners\' wallets' : 'paid when settled',
                  ),
                  StatCard(
                    label: 'Winners',
                    value: settled ? _count(finances['winners']) : '—',
                    icon: Icons.military_tech_outlined,
                    tone: Tone.warning,
                    caption: settled ? null : 'known when settled',
                  ),
                ],
              ),
            ),
            if (settled) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'Winners',
                subtitle: winners.isEmpty
                    ? 'Nobody was paid in this pool.'
                    : 'Paid into their wallets when the pool was settled.',
                child: Column(
                  children: [
                    for (final winner in winners)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              toneColor(context, Tone.success).withValues(alpha: 0.14),
                          child: Text(
                            ordinalOf(winner['rank']),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: toneColor(context, Tone.success),
                            ),
                          ),
                        ),
                        title: Text('${winner['full_name'] ?? ''}'),
                        subtitle: Text(
                          [
                            '${winner['points'] ?? 0} pts',
                            if (winner['team_name'] != null) '${winner['team_name']}',
                            '${winner['email'] ?? ''}',
                          ].where((part) => part.isNotEmpty).join(' · '),
                        ),
                        trailing: Text(
                          moneyOf(winner['payout_cents']),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: toneColor(context, Tone.success),
                          ),
                        ),
                        onTap: () => context.push('/users/${winner['user_id']}'),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            SectionCard(
              title: 'Entries',
              subtitle: settled
                  ? 'Final positions.'
                  : live
                      ? ranked
                          ? 'Live positions, and what each would win if the gameweek ended now.'
                          : 'Positions show once FPL has scored the gameweek\'s first matches.'
                      : 'Positions show once the gameweek is being played.',
              child: members.isEmpty
                  ? Text(
                      'Nobody has entered this pool yet.',
                      style: TextStyle(color: palette.muted),
                    )
                  : _EntriesTable(
                      members: members,
                      settled: settled,
                      live: live && ranked,
                    ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final prizes = _PrizePlan(payout: payout, settled: settled);
                final settings = _Settings(pool: pool);
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [prizes, const SizedBox(height: 14), settings],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: prizes),
                    const SizedBox(width: 14),
                    Expanded(child: settings),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final child = Text(label);
    final leading = Icon(icon, size: 18);
    if (primary) {
      return FilledButton.icon(onPressed: onPressed, icon: leading, label: child);
    }
    final error = Theme.of(context).colorScheme.error;
    return OutlinedButton.icon(
      style: destructive
          ? OutlinedButton.styleFrom(
              foregroundColor: error,
              side: BorderSide(color: error.withValues(alpha: 0.45)),
            )
          : null,
      onPressed: onPressed,
      icon: leading,
      label: child,
    );
  }
}

/// Every entry: position, manager, FPL team, points, status, and what they
/// won (or would win now, while the gameweek is played). A row opens the
/// manager's account.
class _EntriesTable extends StatelessWidget {
  const _EntriesTable({
    required this.members,
    required this.settled,
    required this.live,
  });

  final List<Map<String, Object?>> members;
  final bool settled;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final success = toneColor(context, Tone.success);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingTextStyle: TextStyle(
          color: palette.muted,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
        columns: [
          const DataColumn(label: Text('Pos')),
          const DataColumn(label: Text('Manager')),
          const DataColumn(label: Text('FPL team')),
          const DataColumn(label: Text('Points'), numeric: true),
          const DataColumn(label: Text('Entry')),
          DataColumn(
            label: Text(settled ? 'Won' : live ? 'Would win now' : 'Prize'),
            numeric: true,
          ),
          const DataColumn(label: Text('Joined')),
        ],
        rows: [
          for (final member in members)
            DataRow(
              onSelectChanged: (_) => context.push('/users/${member['user_id']}'),
              cells: [
                DataCell(
                  Text(
                    member['rank'] is num && _int(member['rank']) > 0
                        ? ordinalOf(member['rank'])
                        : '—',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${member['full_name'] ?? ''}'),
                      Text(
                        '${member['email'] ?? ''}',
                        style: TextStyle(color: palette.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    [
                      if (member['team_name'] != null) '${member['team_name']}',
                      if (member['entry_id'] != null) '#${member['entry_id']}',
                    ].join(' '),
                  ),
                ),
                DataCell(Text(member['points'] is num ? '${member['points']}' : '—')),
                DataCell(StatusPill(readableStatus('${member['status'] ?? ''}'))),
                DataCell(
                  Builder(
                    builder: (context) {
                      final cents = settled
                          ? _int(member['payout_cents'])
                          : live
                              ? _int(member['projected_cents'])
                              : 0;
                      return Text(
                        cents > 0 ? moneyOf(cents) : '—',
                        style: TextStyle(
                          fontWeight: cents > 0 ? FontWeight.w700 : null,
                          color: cents > 0 ? success : palette.muted,
                        ),
                      );
                    },
                  ),
                ),
                DataCell(Text(formatDateTime(member['joined_at']))),
              ],
            ),
        ],
      ),
    );
  }
}

/// The prizes by place at the pool's current size.
class _PrizePlan extends StatelessWidget {
  const _PrizePlan({required this.payout, required this.settled});
  final Map<String, Object?> payout;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final prizes = _list(payout['prizes']);
    final mode = '${payout['mode'] ?? 'standard'}';
    final how = switch (mode) {
      'winner_takes_all' => 'Winner takes all',
      'split' => 'Split between the top ${payout['chosen_winners'] ?? payout['winners']}',
      _ => 'Standard curve: one winner in ten',
    };
    return SectionCard(
      title: 'Prize plan',
      subtitle: settled
          ? '$how. What each place was worth at settlement.'
          : '$how. At the pool\'s current size; it grows as managers join.',
      child: prizes.isEmpty
          ? Text(
              'No prizes until someone enters.',
              style: TextStyle(color: palette.muted),
            )
          : Column(
              children: [
                for (final prize in prizes.take(20))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            ordinalOf(prize['place']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            prize['percent'] is num
                                ? '${_percent(prize['percent'])}%'
                                : '',
                            style: TextStyle(color: palette.muted),
                          ),
                        ),
                        Text(
                          moneyOf(prize['amount_cents']),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                if (prizes.length > 20)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'and ${prizes.length - 20} more places',
                      style: TextStyle(color: palette.muted),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Settings extends StatelessWidget {
  const _Settings({required this.pool});
  final Map<String, Object?> pool;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final rows = <(String, String)>[
      ('Ties', switch ('${pool['draw_method']}') {
        'captains' => 'Captains\' points decide',
        'number' => 'Goals scored decide',
        _ => 'Split equally',
      }),
      ('Visibility', '${pool['visibility'] ?? ''}'),
      ('Entry limit', pool['max_members'] is num ? '${pool['max_members']}' : 'None'),
      if ('${pool['invite_code'] ?? ''}'.isNotEmpty)
        ('Invite code', '${pool['invite_code']}'),
      if ('${pool['creator_email'] ?? ''}'.isNotEmpty)
        ('Creator', '${pool['creator_name']} · ${pool['creator_email']}'),
      ('Created', formatDateTime(pool['created_at'])),
      ('Last change', formatDateTime(pool['updated_at'])),
      ('Pool ID', '${pool['id']}'),
    ];
    final rules = '${pool['rules'] ?? ''}';
    return SectionCard(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(label, style: TextStyle(color: palette.muted)),
                  ),
                  Expanded(child: SelectableText(value)),
                ],
              ),
            ),
          if (rules.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Rules', style: TextStyle(color: palette.muted)),
            const SizedBox(height: 4),
            Text(rules),
          ],
        ],
      ),
    );
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : const {};

List<Map<String, Object?>> _list(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, Object?>.from(item),
      ]
    : const [];

int _int(Object? value) => value is num ? value.toInt() : 0;

String _count(Object? value) =>
    NumberFormat.decimalPattern().format(_int(value));

String _percent(Object? value) {
  if (value is! num) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String? _joinOrNull(List<String> parts) =>
    parts.isEmpty ? null : parts.join(' · ');
