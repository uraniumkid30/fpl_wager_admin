import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/features/admin/domain/admin_models.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_resources.dart';
import 'package:fpl_wager_admin/features/auth/presentation/auth_controller.dart';
import 'package:go_router/go_router.dart';

/// The admin dashboard: platform totals, pools waiting for approval, and a
/// card for every section that can be managed.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminDashboardProvider);
    final admin = ref.watch(authControllerProvider).value?.user;
    // Draft custom pools are the ones waiting for an administrator.
    final pools = ref.watch(adminCollectionProvider('wagers')).value;
    final awaiting =
        pools?.where((pool) => '${pool['status']}' == 'draft').length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const BrandMark(compact: true),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(adminDashboardProvider);
              ref.invalidate(adminCollectionProvider('wagers'));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'My FPL team',
            onPressed: () => context.push('/team'),
            icon: const Icon(Icons.sports_soccer_rounded),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          ref.invalidate(adminCollectionProvider('wagers'));
          await ref.read(adminDashboardProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _Hero(
              name: admin?.fullName ?? 'Administrator',
              role: admin?.role ?? 'admin',
            ),
            if (awaiting > 0) ...[
              const SizedBox(height: AppSpacing.md),
              GradientPanel(
                onTap: () => context.push('/resources/wagers'),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      color: AppColors.purple,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        awaiting == 1
                            ? '1 pool is waiting for approval'
                            : '$awaiting pools are waiting for approval',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Platform overview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            summary.when(
              loading: () => const SizedBox(
                height: 150,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => GradientPanel(
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(error.toString())),
                    TextButton(
                      onPressed: () => ref.invalidate(adminDashboardProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (value) => _SummaryGrid(value: value),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text('Manage', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Every change made here is written to the audit trail.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: adminResources.entries
                      .map(
                        (entry) => SizedBox(
                          width: width,
                          child: _ResourceCard(
                            resource: entry.key,
                            definition: entry.value,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) => GradientPanel(
        colors: const [Color(0xFF082F27), Color(0xFF321551)],
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lime.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                size: 32,
                color: AppColors.lime,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FPLwager admin',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Signed in as $name · $role',
                    style: const TextStyle(color: Color(0xFFC8DDD5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.value});
  final AdminDashboardSummary value;

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Users', value: '${value.users}', icon: Icons.people_outline_rounded, color: AppColors.emerald),
      (label: 'Active pools', value: '${value.activeWagers}', icon: Icons.bolt_rounded, color: const Color(0xFF49D7F2)),
      (label: 'Pending payments', value: '${value.pendingPayments}', icon: Icons.pending_actions_rounded, color: AppColors.purple),
      (label: 'Ledger entries', value: '${value.transactions}', icon: Icons.receipt_long_outlined, color: const Color(0xFFFFB45A)),
      (label: 'In wallets', value: money(value.availableCents), icon: Icons.account_balance_wallet_outlined, color: AppColors.emerald),
      (label: 'Locked in games', value: money(value.lockedCents), icon: Icons.lock_clock_outlined, color: AppColors.danger),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: GradientPanel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.icon, color: item.color),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            item.value,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.definition});
  final String resource;
  final AdminResourceDefinition definition;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GradientPanel(
      onTap: () => context.push('/resources/$resource'),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.13),
            child: Icon(definition.icon, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  definition.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  definition.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
