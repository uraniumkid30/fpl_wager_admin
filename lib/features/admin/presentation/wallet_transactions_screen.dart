import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:go_router/go_router.dart';

/// One account's money: balances, totals in and out, and every ledger
/// entry, newest first.
class WalletTransactionsScreen extends ConsumerStatefulWidget {
  const WalletTransactionsScreen({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState
    extends ConsumerState<WalletTransactionsScreen> {
  /// The kind shown, or null for every kind.
  String? _kind;

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(adminWalletProvider(widget.userId));
    final ledger = ref.watch(adminWalletTransactionsProvider(widget.userId));
    final busy = ref.watch(adminActionProvider).isLoading;
    final palette = Palette.of(context);
    final w = wallet.orNull ?? const <String, Object?>{};
    final name = firstValue(w, const ['full_name', 'email']);
    return PageBody(
      maxWidth: 1280,
      onRefresh: () async {
        ref.invalidate(adminWalletProvider(widget.userId));
        ref.invalidate(adminWalletTransactionsProvider(widget.userId));
        await ref.read(adminWalletTransactionsProvider(widget.userId).future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: name.isEmpty ? 'Transactions' : 'Transactions · $name',
            subtitle: '${w['email'] ?? ''}',
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/resources/wallets'),
            actions: [
              OutlinedButton.icon(
                onPressed: () => context.push('/users/${widget.userId}'),
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Open account'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => adjustWalletDialog(
                          context,
                          ref,
                          userId: widget.userId,
                          userLabel: name,
                          credit: true,
                        ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add money'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => adjustWalletDialog(
                          context,
                          ref,
                          userId: widget.userId,
                          userLabel: name,
                          credit: false,
                        ),
                icon: const Icon(Icons.remove_rounded, size: 18),
                label: const Text('Deduct'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (wallet.hasError)
          NoticeBar(text: wallet.error.toString(), tone: Tone.danger)
        else
          WalletTotals(wallet: w),
        const SizedBox(height: 14),
        SectionCard(
          title: 'Ledger',
          subtitle: 'Every movement of this account\'s money, newest first.',
          trailing: ledger.hasValue
              ? DropdownButton<String?>(
                  value: _kind,
                  hint: const Text('All kinds'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All kinds')),
                    for (final kind in {
                      for (final entry in ledger.requireValue) '${entry['kind']}',
                    })
                      DropdownMenuItem<String?>(
                        value: kind,
                        child: Text(readableStatus(kind)),
                      ),
                  ],
                  onChanged: (kind) => setState(() => _kind = kind),
                )
              : null,
          child: AsyncContent(
            value: ledger,
            onRetry: () => ref.invalidate(adminWalletTransactionsProvider(widget.userId)),
            data: (items) {
              final rows = _kind == null
                  ? items
                  : items.where((entry) => '${entry['kind']}' == _kind).toList();
              if (rows.isEmpty) {
                return Text('No transactions.', style: TextStyle(color: palette.muted));
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingTextStyle: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                  columns: const [
                    DataColumn(label: Text('When')),
                    DataColumn(label: Text('Entry')),
                    DataColumn(label: Text('Kind')),
                    DataColumn(label: Text('Amount'), numeric: true),
                    DataColumn(label: Text('Balance after'), numeric: true),
                  ],
                  rows: [
                    for (final entry in rows)
                      DataRow(
                        cells: [
                          DataCell(Text(formatDateTime(entry['created_at']))),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: Text(
                                '${entry['description'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(StatusPill(
                            readableStatus('${entry['kind'] ?? ''}'),
                            tone: Tone.neutral,
                            dot: false,
                          )),
                          DataCell(Builder(
                            builder: (context) {
                              final amount = entry['amount_cents'];
                              final positive = amount is num && amount > 0;
                              return Text(
                                amount is num ? signedMoney(amount.toInt()) : '',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: positive
                                      ? toneColor(context, Tone.success)
                                      : toneColor(context, Tone.danger),
                                ),
                              );
                            },
                          )),
                          DataCell(Text(moneyOf(entry['balance_after_cents']))),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A wallet's balances and its totals in and out, as stat cards.
class WalletTotals extends StatelessWidget {
  const WalletTotals({required this.wallet, super.key, this.maxColumns = 6});
  final Map<String, Object?> wallet;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => ResponsiveGrid(
        minWidth: 180,
        maxColumns: maxColumns,
        children: [
          StatCard(
            label: 'Available',
            value: moneyOf(wallet['available_cents']),
            icon: Icons.account_balance_wallet_outlined,
            caption: '${moneyOf(wallet['locked_cents'])} locked in games',
          ),
          StatCard(
            label: 'Total deposit',
            value: moneyOf(wallet['total_deposit_cents']),
            icon: Icons.south_west_rounded,
            tone: Tone.success,
            valueColor: _flowColor(context, wallet['total_deposit_cents'], incoming: true),
          ),
          StatCard(
            label: 'Total withdrawal',
            value: moneyOf(wallet['total_withdrawal_cents']),
            icon: Icons.north_east_rounded,
            tone: Tone.danger,
            valueColor: _flowColor(context, wallet['total_withdrawal_cents'], incoming: false),
          ),
          StatCard(
            label: 'Total spent',
            value: moneyOf(wallet['total_spent_cents']),
            icon: Icons.sports_soccer_rounded,
            tone: Tone.danger,
            valueColor: _flowColor(context, wallet['total_spent_cents'], incoming: false),
            caption: 'stakes, less refunds',
          ),
          StatCard(
            label: 'Total won',
            value: moneyOf(wallet['total_won_cents']),
            icon: Icons.emoji_events_outlined,
            tone: Tone.success,
            valueColor: _flowColor(context, wallet['total_won_cents'], incoming: true),
          ),
          StatCard(
            label: 'Transactions',
            value: '${wallet['transactions'] ?? 0}',
            icon: Icons.receipt_long_outlined,
            tone: Tone.neutral,
            caption: _joinOrNull([
              if (wallet['total_fees_cents'] is num &&
                  (wallet['total_fees_cents']! as num) > 0)
                'fees ${moneyOf(wallet['total_fees_cents'])}',
              if (wallet['total_adjustments_cents'] is num &&
                  (wallet['total_adjustments_cents']! as num) != 0)
                'adjusted ${moneyOf(wallet['total_adjustments_cents'])}',
            ]),
          ),
        ],
      );
}

String? _joinOrNull(List<String> parts) =>
    parts.isEmpty ? null : parts.join(' · ');

/// Green for money coming in, red for money going out; nothing for zero.
Color? _flowColor(BuildContext context, Object? cents, {required bool incoming}) {
  if (cents is! num || cents == 0) return null;
  return toneColor(context, incoming ? Tone.success : Tone.danger);
}
