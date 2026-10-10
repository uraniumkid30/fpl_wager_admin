import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/data/admin_repository.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';

/// The rules for pools managers create themselves.
///
///   - The delete fee: managers can delete their own pool until the gameweek
///     deadline. Deleting refunds everyone; if somebody other than the
///     creator had joined, the creator also pays this fee, a percentage of
///     one entry fee. 5% unless changed here.
///   - The winners limit: a creator who splits the prize chooses how many
///     win, at most so many for every so many managers and never more than
///     a maximum. 3 for every 5, at most 50, unless changed here.
class PoolRulesScreen extends ConsumerWidget {
  const PoolRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminPoolRulesProvider);
    final busy = ref.watch(adminActionProvider).isLoading;
    final rules = value.orNull;
    final percent = rules?.deleteFeePercent;
    final palette = Palette.of(context);

    return PageBody(
      maxWidth: 900,
      onRefresh: () async {
        ref.invalidate(adminPoolRulesProvider);
        await ref.read(adminPoolRulesProvider.future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: 'Pool rules',
            subtitle: 'How pools that managers create may pay out, and what '
                'deleting one costs.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(adminPoolRulesProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: AppCard(
            padding: const EdgeInsets.all(22),
            child: percent == null
                ? SizedBox(
                    height: 140,
                    child: Center(
                      child: value.hasError
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${value.error}',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                FilledButton.tonal(
                                  onPressed: () =>
                                      ref.invalidate(adminPoolRulesProvider),
                                  child: const Text('Try again'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete fee',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_label(percent)}%',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'of one entry fee',
                              style: TextStyle(color: palette.muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        percent <= 0
                            ? 'Deleting a pool is free, whoever has joined.'
                            : 'On a ${money(200000)} pool that is '
                                '${money(_feeCents(200000, percent))}, '
                                'and on a ${money(500000)} pool '
                                '${money(_feeCents(500000, percent))}, '
                                'however many managers have joined.',
                        style: TextStyle(color: palette.muted),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed:
                            busy ? null : () => _change(context, ref, percent),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Change fee'),
                      ),
                    ],
                  ),
          ),
        ),
        if (rules != null) ...[
          const SizedBox(height: 18),
          FadeSlideIn(
            delay: const Duration(milliseconds: 90),
            child: _WinnersCard(
              rules: rules,
              busy: busy,
              onChange: () => _changeWinners(context, ref, rules),
            ),
          ),
        ],
        const SizedBox(height: 22),
        const FadeSlideIn(
          delay: Duration(milliseconds: 110),
          child: _HowItWorks(),
        ),
      ],
    );
  }

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    double current,
  ) async {
    final input = TextEditingController(text: _label(current));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change the delete fee'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The percentage of one entry fee a manager pays to delete '
                'their pool after someone else has joined. It applies to every '
                'pool from now on, including pools already open. 0 makes '
                'deleting free.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: input,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Fee (%)',
                  helperText: 'From 0 to 100, e.g. 5 or 2.5',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.percent_rounded),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final typed = input.text.trim();
    disposeAfterDialog([input]);
    if (accepted != true || !context.mounted) return;
    final percent = double.tryParse(typed);
    final twoDecimals = percent != null &&
        ((percent * 100) - (percent * 100).roundToDouble()).abs() < 1e-9;
    if (percent == null || percent < 0 || percent > 100 || !twoDecimals) {
      AppNotice.error(
        context,
        'Enter a percentage from 0 to 100, with at most two decimal places.',
      );
      return;
    }
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.setPoolDeleteFeePercent(percent),
      refresh: const ['settings', 'audit-logs'],
      success: percent == 0
          ? 'Deleting a pool is now free.'
          : 'The delete fee is now ${_label(percent)}% of one entry fee.',
    );
    // The page may have been left while the request was in flight.
    if (context.mounted) ref.invalidate(adminPoolRulesProvider);
  }

  Future<void> _changeWinners(
    BuildContext context,
    WidgetRef ref,
    PoolRules current,
  ) async {
    final winners = TextEditingController(text: '${current.winners}');
    final entrants = TextEditingController(text: '${current.entrants}');
    final maxWinners = TextEditingController(text: '${current.maxWinners}');
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change the winners limit'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A creator who splits the prize can pay at most this many '
                'winners for every so many managers, and never more than the '
                'maximum. It applies to pools created from now on; pools that '
                'already exist keep the limit they were created with.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _numberField(winners, 'Winners')),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('for every'),
                  ),
                  Expanded(child: _numberField(entrants, 'Managers')),
                ],
              ),
              const SizedBox(height: 12),
              _numberField(maxWinners, 'Most winners in any pool'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final w = int.tryParse(winners.text.trim());
    final e = int.tryParse(entrants.text.trim());
    final m = int.tryParse(maxWinners.text.trim());
    disposeAfterDialog([winners, entrants, maxWinners]);
    if (accepted != true || !context.mounted) return;
    if (w == null || e == null || m == null || e < 1 || e > 1000 || w < 1 || w > e || m < 1 || m > 1000) {
      AppNotice.error(
        context,
        'Use whole numbers: managers 1 to 1,000, winners from 1 up to the '
        'number of managers, and a maximum from 1 to 1,000.',
      );
      return;
    }
    await runAdminAction(
      context,
      ref,
      action: (repository) =>
          repository.setWinnerRule(winners: w, entrants: e, maxWinners: m),
      refresh: const ['settings', 'audit-logs'],
      success: 'New pools can pay $w ${w == 1 ? 'winner' : 'winners'} for '
          'every $e ${e == 1 ? 'manager' : 'managers'}, at most $m.',
    );
    if (context.mounted) ref.invalidate(adminPoolRulesProvider);
  }

  static Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      );
}

/// "5" or "2.5".
String _label(double percent) => percent == percent.roundToDouble()
    ? percent.toStringAsFixed(0)
    : percent.toString();

/// The fee on an entry of [stakeCents], worked out as the server does.
int _feeCents(int stakeCents, double percent) =>
    stakeCents * (percent * 100).round() ~/ 10000;

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    const points = [
      'Managers can delete their own pool until the gameweek deadline. '
          'Everyone who joined gets their entry back in full.',
      'The fee is only charged when somebody other than the creator has '
          'joined. Deleting an empty pool, or one only the creator is in, is '
          'free.',
      'It is a percentage of one entry fee, not of the whole pot, so it is '
          'the same however many have joined. It is taken from the creator\'s '
          'wallet.',
      'The winners limit applies to pools created after it changes. If fewer '
          'managers join a pool than its winners need, fewer places are paid '
          'and their shares grow to cover the whole prize.',
      'The app shows the fee on the "Create a pool" page and again, with the '
          'exact amount, before the creator confirms a delete. If the fee '
          'changes while they are deciding, they are asked again.',
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

/// The winners limit, with what it means for a few pool sizes.
class _WinnersCard extends StatelessWidget {
  const _WinnersCard({
    required this.rules,
    required this.busy,
    required this.onChange,
  });

  final PoolRules rules;
  final bool busy;
  final VoidCallback onChange;

  int _cap(int managers) {
    var places = managers * rules.winners ~/ rules.entrants;
    if (places > rules.maxWinners) places = rules.maxWinners;
    if (places > managers) places = managers;
    return places < 1 ? 1 : places;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Winners limit', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                '${rules.winners} per ${rules.entrants}',
                style: theme.textTheme.displaySmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'managers, at most ${rules.maxWinners} winners',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A pool that splits its prize can pay up to '
            '${[5, 10, 20, 50].map((n) => '${_cap(n)} with $n managers').join(', ')}. '
            'Winner-takes-all pools always pay one. Auto pools are not affected.',
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: busy ? null : onChange,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Change limit'),
          ),
        ],
      ),
    );
  }
}
