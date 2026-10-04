import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_notice.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_actions.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';
import 'package:go_router/go_router.dart';

/// One user's account: edit their details, status and role, add or deduct
/// money, send them a message, or delete the account.
class AdminUserScreen extends ConsumerStatefulWidget {
  const AdminUserScreen({required this.userId, super.key});
  final String userId;

  @override
  ConsumerState<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends ConsumerState<AdminUserScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _loadedId;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminUserProvider(widget.userId));
    final busy = ref.watch(adminActionProvider).isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('User account')),
      body: AsyncContent(
        value: value,
        onRetry: () => ref.invalidate(adminUserProvider(widget.userId)),
        data: (user) {
          if (_loadedId != user.id) {
            _loadedId = user.id;
            _name.text = user.fullName;
            _phone.text = user.phone;
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              GradientPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusPill(user.role),
                        StatusPill(user.status),
                        StatusPill(
                          user.emailVerified
                              ? 'Email verified'
                              : 'Email not verified',
                        ),
                        if (user.fplEntryId != null)
                          StatusPill('FPL ID ${user.fplEntryId}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            'User ID: ${user.id}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy user ID',
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: user.id));
                            if (context.mounted) {
                              AppNotice.info(context, 'User ID copied.');
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Wallet ───────────────────────────────────────────────
              const SizedBox(height: 22),
              Text('Wallet', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              _WalletPanel(user: user, busy: busy),

              // ── Details ──────────────────────────────────────────────
              const SizedBox(height: 22),
              Text('Details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => _update(
                          {
                            'full_name': _name.text.trim(),
                            'phone': _phone.text.trim(),
                          },
                          'Details saved.',
                        ),
                child: const Text('Save details'),
              ),
              const SizedBox(height: 22),
              DropdownButtonFormField<String>(
                key: ValueKey('status-${user.status}'),
                initialValue: user.status,
                decoration: const InputDecoration(
                  labelText: 'Account status',
                  helperText: 'Anything other than active blocks sign-in',
                ),
                items: const ['active', 'inactive', 'deactivated', 'banned']
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (next) {
                        if (next != null && next != user.status) {
                          _update({'status': next}, 'Status is now $next.');
                        }
                      },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('role-${user.role}'),
                initialValue: user.role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  helperText: 'Only a superadmin can change roles',
                ),
                items: const ['user', 'admin', 'superadmin']
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: busy
                    ? null
                    : (next) {
                        if (next != null && next != user.role) {
                          _update({'role': next}, 'Role is now $next.');
                        }
                      },
              ),

              // ── Other actions ────────────────────────────────────────
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => sendNotificationDialog(
                          context,
                          ref,
                          userId: user.id,
                          userLabel: 'To ${user.fullName}',
                        ),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Send notification'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: busy ? null : () => _delete(user),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Delete user permanently'),
              ),
              const SizedBox(height: 8),
              Text(
                'To block someone without losing their records, set their '
                'status to deactivated or banned instead of deleting them.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _update(Map<String, Object?> changes, String success) async {
    final done = await runAdminAction(
      context,
      ref,
      action: (repository) => repository.updateUser(widget.userId, changes),
      refresh: const ['users'],
      success: success,
    );
    if (done) ref.invalidate(adminUserProvider(widget.userId));
  }

  Future<void> _delete(UserProfile user) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete ${user.fullName}?',
      message: 'This removes the account and everything that belongs to it: '
          'wallet and balance, ledger, payments, FPL team, pool entries, '
          'challenges and notifications. Pools they created are kept. '
          'This cannot be undone.',
      confirmLabel: 'Delete permanently',
    );
    if (!confirmed || !mounted) return;
    final done = await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteUser(widget.userId),
      refresh: const [
        'users',
        'wallets',
        'transactions',
        'payments',
        'teams',
        'wagers',
        'challenges',
        'notifications',
      ],
      success: '${user.fullName} was deleted.',
    );
    if (done && mounted) context.pop();
  }
}

/// The user's balances with the add / deduct money buttons.
class _WalletPanel extends ConsumerWidget {
  const _WalletPanel({required this.user, required this.busy});
  final UserProfile user;
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(adminWalletProvider(user.id));
    final available = wallet.value?['available_cents'];
    final locked = wallet.value?['locked_cents'];
    return GradientPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (wallet.isLoading && !wallet.hasValue)
            const LinearProgressIndicator()
          else if (wallet.hasError)
            Text(wallet.error.toString())
          else ...[
            Text(
              available is num ? money(available.toInt()) : '—',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.purple,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'available · ${locked is num ? money(locked.toInt()) : '—'} locked in games',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => adjustWalletDialog(
                            context,
                            ref,
                            userId: user.id,
                            userLabel: user.fullName,
                            credit: true,
                          ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add money'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => adjustWalletDialog(
                            context,
                            ref,
                            userId: user.id,
                            userLabel: user.fullName,
                            credit: false,
                          ),
                  icon: const Icon(Icons.remove_rounded),
                  label: const Text('Deduct'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
