import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:go_router/go_router.dart';

/// Controls the pools the platform opens by itself.
///
/// There is one auto pool per stake, opened for every gameweek and again
/// whenever one fills up. From here an administrator can stop all of that,
/// pause or remove a single stake, or add a new one.
class AutoPoolsScreen extends ConsumerWidget {
  const AutoPoolsScreen({super.key});

  static const _affected = ['wagers', 'wallets', 'transactions', 'notifications'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminAutoPoolsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;
    final data = value.orNull;
    final palette = Palette.of(context);

    return PageBody(
      maxWidth: 1180,
      onRefresh: () async {
        ref.invalidate(adminAutoPoolsProvider);
        await ref.read(adminAutoPoolsProvider.future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: 'Auto pools',
            subtitle: 'The standard pools FPLboardman opens by itself, one '
                'for each stake.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(adminAutoPoolsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: busy || data == null ? null : () => _add(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add auto pool'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (data == null)
          AppCard(
            child: SizedBox(
              height: 200,
              child: Center(
                child: value.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${value.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(adminAutoPoolsProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          )
        else ...[
          FadeSlideIn(
            delay: const Duration(milliseconds: 60),
            child: _MasterSwitch(
              enabled: data.enabled,
              busy: busy,
              onChanged: (next) => _setAll(context, ref, next),
            ),
          ),
          const SizedBox(height: 22),
          Text('Stakes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Each stake has its own pool. Pause one to stop it coming back; '
            'delete it to remove it for good.',
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 12),
          if (data.tiers.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.autorenew_rounded,
                title: 'No auto pools',
                message: 'Add a stake and a pool for it opens for the next '
                    'gameweek.',
                action: FilledButton.icon(
                  onPressed: busy ? null : () => _add(context, ref),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add auto pool'),
                ),
              ),
            )
          else
            ResponsiveGrid(
              minWidth: 300,
              maxColumns: 3,
              children: [
                for (final (index, tier) in data.tiers.indexed)
                  FadeSlideIn(
                    delay: Duration(milliseconds: 90 + index * 50),
                    child: _TierCard(
                      tier: tier,
                      allEnabled: data.enabled,
                      busy: busy,
                      onToggle: (next) => _setTier(context, ref, tier, next),
                      onDelete: () => _delete(context, ref, tier),
                      onViewPools: () => context.go('/resources/wagers'),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 22),
          const _HowItWorks(),
        ],
      ],
    );
  }

  Future<void> _setAll(BuildContext context, WidgetRef ref, bool enabled) async {
    if (!enabled) {
      final confirmed = await confirmAdminAction(
        context,
        title: 'Stop all auto pools?',
        message: 'No new auto pool will be created for any stake, including '
            'when one fills up or a new gameweek comes round.\n\n'
            'Pools that are already open stay open and are settled as usual. '
            'To remove one of those, delete it from the Pools page.',
        confirmLabel: 'Stop auto pools',
      );
      if (!confirmed || !context.mounted) return;
    }
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.setAutoPoolsEnabled(enabled),
      refresh: _affected,
      success: enabled
          ? 'Auto pools are running again. Any stake without an open pool '
              'has been given one.'
          : 'Auto pools are stopped. No new ones will be created.',
    );
    // The page may have been left while the request was in flight.
    if (context.mounted) ref.invalidate(adminAutoPoolsProvider);
  }

  Future<void> _setTier(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> tier,
    bool enabled,
  ) async {
    final stake = _stake(tier);
    await runAdminAction(
      context,
      ref,
      action: (repository) =>
          repository.setAutoPoolTierEnabled('${tier['id']}', enabled),
      refresh: _affected,
      success: enabled
          ? 'The $stake auto pool is back on.'
          : 'The $stake auto pool is paused. Its open pool carries on, but '
              'no new one will follow it.',
    );
    // The page may have been left while the request was in flight.
    if (context.mounted) ref.invalidate(adminAutoPoolsProvider);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final amount = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add auto pool'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose what each manager pays to enter. A pool at this stake '
                'opens for the next gameweek straight away, and a new one '
                'follows it every gameweek.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Stake (₦)',
                  helperText: 'Whole naira, from ₦100 to ₦1,000,000',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                onSubmitted: (_) => Navigator.pop(context, true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    final typed = amount.text.replaceAll(',', '').trim();
    disposeAfterDialog([amount]);
    if (accepted != true || !context.mounted) return;
    final naira = int.tryParse(typed);
    if (naira == null || naira < 100 || naira > 1000000) {
      AppNotice.error(
        context,
        'Enter a whole amount in naira between 100 and 1,000,000.',
      );
      return;
    }
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.createAutoPoolTier(naira * 100),
      refresh: _affected,
      success: 'The ${money(naira * 100)} auto pool was added.',
    );
    // The page may have been left while the request was in flight.
    if (context.mounted) ref.invalidate(adminAutoPoolsProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> tier,
  ) async {
    final stake = _stake(tier);
    final hasOpen = tier['open_pool_id'] != null;
    final entries = (tier['open_pool_entries'] as num? ?? 0).toInt();
    final choice = await showDialog<({bool cancelOpen})>(
      context: context,
      builder: (_) => _DeleteTierDialog(
        stake: stake,
        openPoolName: hasOpen ? '${tier['open_pool_name'] ?? 'its open pool'}' : null,
        entries: entries,
      ),
    );
    if (choice == null || !context.mounted) return;
    await runAdminActionForMessage(
      context,
      ref,
      action: (repository) async {
        final refunded = await repository.deleteAutoPoolTier(
          '${tier['id']}',
          cancelOpen: choice.cancelOpen,
        );
        if (!hasOpen) return 'The $stake auto pool was removed.';
        if (!choice.cancelOpen) {
          return 'The $stake auto pool was removed. The pool that is open '
              'now plays out, and none will follow it.';
        }
        return 'The $stake auto pool was removed and its open pool '
            'cancelled. $refunded ${refunded == 1 ? 'entry was' : 'entries were'} '
            'refunded.';
      },
      refresh: _affected,
    );
    // The page may have been left while the request was in flight.
    if (context.mounted) ref.invalidate(adminAutoPoolsProvider);
  }
}

String _stake(Map<String, Object?> tier) =>
    money((tier['stake_cents'] as num? ?? 0).toInt());

class _MasterSwitch extends StatelessWidget {
  const _MasterSwitch({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = toneColor(context, enabled ? Tone.success : Tone.danger);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppMotion.standard,
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              enabled ? Icons.autorenew_rounded : Icons.pause_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Auto pools are running' : 'Auto pools are stopped',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  enabled
                      ? 'A pool opens for every stake that is switched on, '
                          'each gameweek and whenever one fills up.'
                      : 'No new auto pools are being created. Pools that '
                          'were already open carry on to their deadline.',
                  style: TextStyle(color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: enabled ? 'Stop all auto pools' : 'Start auto pools',
            child: Switch(
              value: enabled,
              onChanged: busy ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.allEnabled,
    required this.busy,
    required this.onToggle,
    required this.onDelete,
    required this.onViewPools,
  });

  final Map<String, Object?> tier;

  /// The master switch. When it is off, a stake that is "on" still creates
  /// nothing.
  final bool allEnabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewPools;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final on = tier['enabled'] == true;
    final openName = tier['open_pool_name'];
    final entries = (tier['open_pool_entries'] as num? ?? 0).toInt();
    final gameweek = tier['open_pool_gameweek'];
    final created = (tier['pools_created'] as num? ?? 0).toInt();
    final (label, tone) = !on
        ? ('Paused', Tone.warning)
        : allEnabled
            ? ('Running', Tone.success)
            : ('On, but all stopped', Tone.danger);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stake(tier),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              StatusPill(label, tone: tone),
            ],
          ),
          const SizedBox(height: 2),
          Text('to enter', style: TextStyle(color: palette.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          _Fact(
            icon: Icons.emoji_events_outlined,
            text: openName == null
                ? 'No pool open right now'
                : 'Open now: Gameweek $gameweek · $entries '
                    '${entries == 1 ? 'entry' : 'entries'}',
          ),
          const SizedBox(height: 6),
          _Fact(
            icon: Icons.history_rounded,
            text: '$created ${created == 1 ? 'pool' : 'pools'} created so far',
          ),
          const SizedBox(height: 12),
          Divider(color: palette.border, height: 1),
          const SizedBox(height: 6),
          Row(
            children: [
              Switch(value: on, onChanged: busy ? null : onToggle),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  on ? 'Opens a new pool each time' : 'Will not open new pools',
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'See its pools',
                onPressed: onViewPools,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Delete this auto pool',
                onPressed: busy ? null : onDelete,
                color: Theme.of(context).colorScheme.error,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

/// Asks whether to remove a stake, and what to do with its open pool.
class _DeleteTierDialog extends StatefulWidget {
  const _DeleteTierDialog({
    required this.stake,
    required this.openPoolName,
    required this.entries,
  });

  final String stake;

  /// The pool that is open for this stake now, or null if there is none.
  final String? openPoolName;
  final int entries;

  @override
  State<_DeleteTierDialog> createState() => _DeleteTierDialogState();
}

class _DeleteTierDialogState extends State<_DeleteTierDialog> {
  bool _cancelOpen = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final openPoolName = widget.openPoolName;
    final entries = widget.entries;
    return AlertDialog(
      title: Text('Delete the ${widget.stake} auto pool?'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No pool will be opened at this stake again. You can add it '
              'back later. To stop it only for a while, pause it instead.',
            ),
            if (openPoolName != null) ...[
              const SizedBox(height: 14),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _cancelOpen,
                onChanged: (next) => setState(() => _cancelOpen = next ?? false),
                title: const Text('Also cancel the pool that is open now'),
                subtitle: Text(
                  entries == 0
                      ? '$openPoolName has no entries yet.'
                      : '$openPoolName has $entries '
                          '${entries == 1 ? 'entry, which is' : 'entries, which are'} '
                          'refunded in full. Left unticked, the pool plays out.',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, (cancelOpen: _cancelOpen)),
          child: Text(
            _cancelOpen && entries > 0 ? 'Delete and refund' : 'Delete',
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    const points = [
      'Stopping or pausing never touches a pool that is already open: '
          'managers who have entered still play, and it is settled as usual.',
      'To remove an open pool, delete it from the Pools page (everyone is '
          'refunded), or delete its stake here and tick "cancel the pool that '
          'is open now".',
      'If you delete an open auto pool while its stake is still running, a '
          'fresh one opens in its place. Pause the stake first to prevent '
          'that.',
    ];
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good to know', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle, size: 6, color: palette.muted),
                  ),
                  Expanded(
                    child: Text(point, style: TextStyle(color: palette.muted)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
