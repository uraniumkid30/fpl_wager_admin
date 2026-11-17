import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';

/// Which provider takes top-ups: Zenith GlobalPay (the main one) or Paystack.
///
/// Only administrators choose; the app no longer offers a choice. Payments
/// already started finish with the provider they started with, and
/// withdrawals are not affected (they use the server's PAYMENT_SERVICE).
class PaymentSettingsScreen extends ConsumerWidget {
  const PaymentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminPaymentSettingsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;
    final settings = value.value;
    final palette = Palette.of(context);

    final providers = <Map<String, Object?>>[
      for (final item in (settings?['providers'] as List? ?? const []))
        if (item is Map) Map<String, Object?>.from(item),
    ];
    final selected = settings?['deposit_provider'] as String? ?? '';
    final inUse = settings?['in_use'] as String? ?? selected;
    final environment = settings?['environment'] as String? ?? '';
    final withdrawals = settings?['withdrawal_provider'] as String? ?? '';
    String labelOf(String name) =>
        providers.firstWhere(
          (item) => item['name'] == name,
          orElse: () => {'label': name},
        )['label'] as String? ??
        name;

    return PageBody(
      maxWidth: 900,
      onRefresh: () async {
        ref.invalidate(adminPaymentSettingsProvider);
        await ref.read(adminPaymentSettingsProvider.future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: 'Payment provider',
            subtitle: 'Where managers\' wallet top-ups are paid. Zenith '
                'GlobalPay is the main provider; Paystack is the other option.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(adminPaymentSettingsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (settings == null)
          AppCard(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              height: 140,
              child: Center(
                child: value.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${value.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(adminPaymentSettingsProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          )
        else ...[
          if (inUse != selected)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NoticeBar(
                tone: Tone.warning,
                icon: Icons.warning_amber_rounded,
                text: '${labelOf(selected)} has no key on this server for '
                    '${environment == 'production' ? 'live' : 'test'} payments, '
                    'so top-ups are going through ${labelOf(inUse)} until one '
                    'is added.',
              ),
            ),
          for (final (index, provider) in providers.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 60 + index * 40),
                child: _ProviderCard(
                  provider: provider,
                  busy: busy,
                  production: environment == 'production',
                  onChoose: () => _choose(context, ref, provider),
                ),
              ),
            ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How switching works',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                for (final line in [
                  'Every top-up started after the switch goes through the '
                      'provider you choose. Managers do not choose any more.',
                  'A top-up already started finishes with its own provider, '
                      'so switching never loses a payment.',
                  'Withdrawals are not affected: they are paid through '
                      '${withdrawals == 'korapay' ? 'Korapay' : labelOf(withdrawals)}, '
                      'set on the server with PAYMENT_SERVICE.',
                  'GlobalPay must be told where to send its payment '
                      'notifications: https://<your API>/v1/payments/webhooks/globalpay.',
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 7, right: 10),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: palette.muted,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(line, style: TextStyle(color: palette.muted)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> provider,
  ) async {
    final name = provider['name'] as String? ?? '';
    final label = provider['label'] as String? ?? name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use $label for top-ups?'),
        content: SizedBox(
          width: 420,
          child: Text(
            'Every wallet top-up from now on goes through $label. Top-ups '
            'already started finish with their own provider.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Use $label'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.setDepositProvider(name),
      refresh: const ['settings', 'audit-logs'],
      success: 'Top-ups now go through $label.',
    );
    if (context.mounted) ref.invalidate(adminPaymentSettingsProvider);
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.busy,
    required this.production,
    required this.onChoose,
  });

  final Map<String, Object?> provider;
  final bool busy;
  final bool production;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final name = provider['name'] as String? ?? '';
    final label = provider['label'] as String? ?? name;
    final selected = provider['selected'] == true;
    final live = provider['live_configured'] == true;
    final test = provider['test_configured'] == true;
    final main = name == 'globalpay';
    final usable = production ? live : (live || test);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: selected ? 0.16 : 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              main ? Icons.account_balance_rounded : Icons.credit_card_rounded,
              color: selected ? palette.accent : palette.muted,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (selected) const StatusPill('In use', tone: Tone.success),
                    if (main) const StatusPill('Main', tone: Tone.accent, dot: false),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    StatusPill(
                      live ? 'Live key set' : 'No live key',
                      tone: live ? Tone.success : Tone.danger,
                    ),
                    StatusPill(
                      test ? 'Test key set' : 'No test key',
                      tone: test ? Tone.neutral : Tone.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (selected)
            Icon(Icons.check_circle_rounded, color: palette.accent, size: 28)
          else
            FilledButton(
              onPressed: busy || !usable ? null : onChoose,
              child: const Text('Use this'),
            ),
        ],
      ),
    );
  }
}
