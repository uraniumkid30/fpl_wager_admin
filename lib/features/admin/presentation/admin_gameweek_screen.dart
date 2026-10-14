import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// One gameweek: how much was played and won, every pool played in it (each
/// opens its own page) and where every manager finished.
class AdminGameweekScreen extends ConsumerWidget {
  const AdminGameweekScreen({required this.number, super.key});
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminGameweekProvider(number));
    return AsyncContent(
      value: value,
      onRetry: () => ref.invalidate(adminGameweekProvider(number)),
      data: (gameweek) {
        final palette = Palette.of(context);
        final summary = _map(gameweek['summary']);
        final pools = _list(gameweek['pools']);
        final standings = _list(gameweek['standings']);
        final staked = _int(summary['staked_cents']);
        final paid = _int(summary['paid_out_cents']);
        return PageBody(
          maxWidth: 1280,
          onRefresh: () async {
            ref.invalidate(adminGameweekProvider(number));
            await ref.read(adminGameweekProvider(number).future);
          },
          children: [
            FadeSlideIn(
              child: PageHeader(
                title: 'Gameweek $number',
                subtitle: [
                  'Deadline ${formatDateTime(gameweek['deadline'])}',
                  if (gameweek['average_points'] is num)
                    'FPL average ${gameweek['average_points']} pts',
                  if (gameweek['highest_points'] is num)
                    'highest ${gameweek['highest_points']} pts',
                ].join(' · '),
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/resources/gameweeks'),
                actions: [
                  if (number > 1)
                    OutlinedButton.icon(
                      onPressed: () => context.go('/gameweeks/${number - 1}'),
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      label: Text('GW${number - 1}'),
                    ),
                  if (number < 38)
                    OutlinedButton.icon(
                      onPressed: () => context.go('/gameweeks/${number + 1}'),
                      icon: const Icon(Icons.chevron_right_rounded, size: 18),
                      label: Text('GW${number + 1}'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [StatusPill(readableStatus('${gameweek['status'] ?? ''}'))],
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: ResponsiveGrid(
                minWidth: 190,
                maxColumns: 6,
                children: [
                  StatCard(
                    label: 'Pools',
                    value: _count(summary['pools']),
                    icon: Icons.emoji_events_outlined,
                    caption: _joinOrNull([
                      if (_int(summary['pools_settled']) > 0) '${summary['pools_settled']} settled',
                      if (_int(summary['pools_in_play']) > 0) '${summary['pools_in_play']} in play',
                      if (_int(summary['pools_open']) > 0) '${summary['pools_open']} open',
                      if (_int(summary['pools_cancelled']) > 0) '${summary['pools_cancelled']} cancelled',
                    ]),
                  ),
                  StatCard(
                    label: 'Managers',
                    value: _count(summary['managers']),
                    icon: Icons.people_outline_rounded,
                    caption: '${_count(summary['entries'])} entries',
                  ),
                  StatCard(
                    label: 'Total played',
                    value: moneyOf(staked),
                    icon: Icons.payments_outlined,
                    caption: 'staked in pools',
                  ),
                  StatCard(
                    label: 'Paid to winners',
                    value: moneyOf(paid),
                    icon: Icons.north_east_rounded,
                    tone: Tone.success,
                    caption: '${_count(summary['winners'])} winning entries',
                  ),
                  StatCard(
                    label: 'House cut',
                    value: moneyOf(summary['house_cut_cents']),
                    icon: Icons.account_balance_outlined,
                    tone: Tone.info,
                    caption: 'from settled pools',
                  ),
                  StatCard(
                    label: 'Refunded entries',
                    value: _count(summary['refunded_entries']),
                    icon: Icons.undo_rounded,
                    tone: Tone.warning,
                    caption: 'left or cancelled',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Pools played',
              subtitle: 'Open a pool for its entries, positions and winners.',
              child: pools.isEmpty
                  ? Text('No pools in this gameweek.', style: TextStyle(color: palette.muted))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingTextStyle: TextStyle(
                          color: palette.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        columns: const [
                          DataColumn(label: Text('Pool')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Stake'), numeric: true),
                          DataColumn(label: Text('Entries'), numeric: true),
                          DataColumn(label: Text('Played'), numeric: true),
                          DataColumn(label: Text('Paid out'), numeric: true),
                          DataColumn(label: Text('Winners'), numeric: true),
                        ],
                        rows: [
                          for (final pool in pools)
                            DataRow(
                              onSelectChanged: (_) => context.push('/pools/${pool['id']}'),
                              cells: [
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${pool['name'] ?? ''}',
                                        style: TextStyle(
                                          color: palette.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        [
                                          '${pool['pool_kind']}' == 'auto' ? 'Auto' : 'Custom',
                                          if ('${pool['visibility']}' == 'private') 'private',
                                        ].join(' · '),
                                        style: TextStyle(color: palette.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(StatusPill(readableStatus('${pool['status'] ?? ''}'))),
                                DataCell(Text(moneyOf(pool['stake_cents']))),
                                DataCell(Text(_count(pool['entrants']))),
                                DataCell(Text(moneyOf(pool['staked_cents']))),
                                DataCell(Text(
                                  '${pool['status']}' == 'settled' ? moneyOf(pool['paid_out_cents']) : '—',
                                )),
                                DataCell(Text(
                                  '${pool['status']}' == 'settled' ? _count(pool['winners']) : '—',
                                )),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Manager positions',
              subtitle: 'Everyone who played, placed by their best score '
                  'across the pools they entered. Level scores share a position.',
              child: standings.isEmpty
                  ? Text('Nobody played this gameweek.', style: TextStyle(color: palette.muted))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingTextStyle: TextStyle(
                          color: palette.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        columns: const [
                          DataColumn(label: Text('Pos')),
                          DataColumn(label: Text('Manager')),
                          DataColumn(label: Text('Points'), numeric: true),
                          DataColumn(label: Text('Pools'), numeric: true),
                          DataColumn(label: Text('Staked'), numeric: true),
                          DataColumn(label: Text('Won'), numeric: true),
                          DataColumn(label: Text('Net'), numeric: true),
                        ],
                        rows: [
                          for (final row in standings)
                            DataRow(
                              onSelectChanged: (_) => context.push('/users/${row['user_id']}'),
                              cells: [
                                DataCell(Text(
                                  row['position'] is num ? ordinalOf(row['position']) : '—',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                )),
                                DataCell(
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${row['full_name'] ?? ''}'),
                                      Text(
                                        '${row['email'] ?? ''}',
                                        style: TextStyle(color: palette.muted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(row['points'] is num ? '${row['points']}' : '—')),
                                DataCell(Text(_count(row['pools_entered']))),
                                DataCell(Text(moneyOf(row['staked_cents']))),
                                DataCell(Text(
                                  moneyOf(row['won_cents']),
                                  style: TextStyle(
                                    color: _int(row['won_cents']) > 0
                                        ? toneColor(context, Tone.success)
                                        : null,
                                  ),
                                )),
                                DataCell(Text(_signed(row['net_cents']))),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
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

String _signed(Object? cents) {
  final value = _int(cents);
  return '${value < 0 ? '−' : '+'}${moneyOf(value.abs())}';
}

String? _joinOrNull(List<String> parts) =>
    parts.isEmpty ? null : parts.join(' · ');
