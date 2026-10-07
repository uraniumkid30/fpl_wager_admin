import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_notice.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/core/ui/ui_kit.dart';
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

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/resources/users');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(adminUserProvider(widget.userId));
    final busy = ref.watch(adminActionProvider).isLoading;
    return AsyncContent(
      value: value,
      onRetry: () => ref.invalidate(adminUserProvider(widget.userId)),
      data: (user) {
        if (_loadedId != user.id) {
          _loadedId = user.id;
          _name.text = user.fullName;
          _phone.text = user.phone;
        }
        final palette = Palette.of(context);
        final wide = MediaQuery.sizeOf(context).width >= 1100;

        final account = SectionCard(
          title: 'Account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(user.role, tone: Tone.info),
                  StatusPill(user.status),
                  StatusPill(
                    user.emailVerified ? 'Email verified' : 'Email not verified',
                    tone: user.emailVerified ? Tone.success : Tone.warning,
                  ),
                  if (user.fplEntryId != null)
                    StatusPill(
                      'FPL ID ${user.fplEntryId}',
                      tone: Tone.neutral,
                      dot: false,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      user.id,
                      style: TextStyle(
                        color: palette.muted,
                        fontFamily: 'monospace',
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy user ID',
                    icon: const Icon(Icons.copy_rounded, size: 17),
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
        );

        final wallet = SectionCard(
          title: 'Wallet',
          child: _WalletPanel(user: user, busy: busy),
        );

        final details = SectionCard(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 14),
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
            ],
          ),
        );

        final access = SectionCard(
          title: 'Access',
          subtitle: 'Changes here are saved as soon as you choose them.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 14),
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
            ],
          ),
        );

        const gap = SizedBox(height: 14);
        return PageBody(
          maxWidth: 1180,
          children: [
            FadeSlideIn(
              child: PageHeader(
                title: user.fullName,
                subtitle: user.email,
                onBack: _back,
                actions: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => sendNotificationDialog(
                              context,
                              ref,
                              userId: user.id,
                              userLabel: 'To ${user.fullName}',
                            ),
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: const Text('Send notification'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: busy ? null : () => _delete(user),
                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                    label: const Text('Delete user'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [account, gap, wallet],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [details, gap, access],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [account, gap, wallet, gap, details, gap, access],
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              'To block someone without losing their records, set their '
              'status to deactivated or banned instead of deleting them.',
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        );
      },
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
    if (done && mounted) _back();
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
    final balances = wallet.orNull;
    final available = balances?['available_cents'];
    final locked = balances?['locked_cents'];
    return Column(
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
                    fontWeight: FontWeight.w700,
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
    );
  }
}
