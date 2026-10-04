import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_notice.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_actions.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_resources.dart';
import 'package:go_router/go_router.dart';

/// One action offered on a record's detail dialog.
typedef _RecordAction = ({String key, String label, bool destructive});

/// The list page for one kind of record, with its create / edit / delete
/// actions. Tapping a record opens its details and whatever can be done to it.
class AdminResourceScreen extends ConsumerWidget {
  const AdminResourceScreen({required this.resource, super.key});
  final String resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = adminResources[resource];
    if (definition == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Unknown section',
          message: 'Return to the dashboard and choose a section.',
        ),
      );
    }
    final value = ref.watch(adminCollectionProvider(resource));
    final busy = ref.watch(adminActionProvider).isLoading;
    final createLabel = definition.createLabel;
    final note = definition.note;

    return Scaffold(
      appBar: AppBar(
        title: Text(definition.label),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminCollectionProvider(resource)),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: createLabel == null
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : () => _create(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(createLabel),
            ),
      body: Column(
        children: [
          if (busy) const LinearProgressIndicator(),
          if (note != null) _Note(text: note),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(adminCollectionProvider(resource));
                await ref.read(adminCollectionProvider(resource).future);
              },
              child: value.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => ListView(
                  children: [
                    EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'Could not load ${definition.label.toLowerCase()}',
                      message: error.toString(),
                    ),
                  ],
                ),
                data: (items) => items.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyState(
                            icon: definition.icon,
                            title: 'Nothing here yet',
                            message: 'Records appear here as they are created.',
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          120,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _RecordCard(
                          resource: resource,
                          record: items[index],
                          onTap: () => _open(context, ref, items[index]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) {
    return switch (resource) {
      'users' => _createUser(context, ref),
      'wagers' => _createWager(context, ref),
      'settings' => _putSetting(context, ref),
      'notifications' => sendNotificationDialog(context, ref),
      _ => Future<void>.value(),
    };
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> record,
  ) async {
    if (resource == 'users') {
      final id = record['id'];
      if (id != null) await context.push('/users/$id');
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => _RecordDialog(
        title: _title(resource, record),
        record: record,
        actions: _actionsFor(resource, record),
      ),
    );
    if (action == null || !context.mounted) return;
    await _perform(context, ref, resource, record, action);
  }
}

// ───────────────────────────────────────────────────────────────────────────
// What each record looks like in the list
// ───────────────────────────────────────────────────────────────────────────

String _title(String resource, Map<String, Object?> record) {
  final text = switch (resource) {
    'users' || 'wallets' => firstValue(record, const ['full_name', 'email']),
    'wagers' => firstValue(record, const ['name']),
    'payments' => firstValue(record, const ['reference']),
    'transactions' => firstValue(record, const ['description', 'kind']),
    'challenges' =>
      '${firstValue(record, const ['challenger_name'])} vs ${firstValue(record, const ['opponent_name', 'opponent_team_id'])}',
    'teams' => firstValue(record, const ['team_name']),
    'notifications' => firstValue(record, const ['title']),
    'settings' => firstValue(record, const ['key']),
    'gameweeks' => firstValue(record, const ['name', 'number']),
    'fpl-logins' => firstValue(record, const ['full_name']),
    'audit-logs' => firstValue(record, const ['action']),
    _ => '',
  };
  return text.isEmpty ? 'Record' : text;
}

String _subtitle(String resource, Map<String, Object?> record) {
  final parts = switch (resource) {
    'users' => [
        firstValue(record, const ['email']),
        firstValue(record, const ['role']),
      ],
    'wagers' => [
        'GW${firstValue(record, const ['gameweek'])}',
        _moneyOf(record['stake_cents']),
        '${firstValue(record, const ['member_count'])} entries',
        firstValue(record, const ['pool_kind']),
      ],
    'wallets' => [
        firstValue(record, const ['email']),
        '${_moneyOf(record['available_cents'])} available',
        '${_moneyOf(record['locked_cents'])} locked',
      ],
    'payments' => [
        firstValue(record, const ['provider']),
        _moneyOf(record['amount_cents']),
        firstValue(record, const ['credential_mode']),
      ],
    'transactions' => [
        firstValue(record, const ['email']),
        firstValue(record, const ['kind']),
        _moneyOf(record['amount_cents']),
      ],
    'challenges' => [
        'GW${firstValue(record, const ['gameweek'])}',
        _moneyOf(record['stake_cents']),
      ],
    'teams' => [
        firstValue(record, const ['full_name']),
        'FPL ID ${firstValue(record, const ['entry_id'])}',
      ],
    'notifications' => [
        firstValue(record, const ['full_name']),
        firstValue(record, const ['body']),
      ],
    'settings' => [jsonEncode(record['value'])],
    'gameweeks' => [
        _dateOf(record['deadline']),
        '${firstValue(record, const ['pools'])} pools',
      ],
    'fpl-logins' => [
        'FPL ID ${firstValue(record, const ['entry_id'])}',
        _dateOf(record['created_at']),
      ],
    'audit-logs' => [
        firstValue(record, const ['admin_name']),
        '${firstValue(record, const ['resource_type'])} ${firstValue(record, const ['resource_id'])}',
        _dateOf(record['created_at']),
      ],
    _ => <String>[],
  };
  return parts.where((part) => part.trim().isNotEmpty).join(' · ');
}

String _moneyOf(Object? cents) => cents is num ? money(cents.toInt()) : '';

/// "2026-10-03 14:05" from an ISO timestamp, in the device's time zone.
String _dateOf(Object? value) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) return '';
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _pill(Map<String, Object?> record) =>
    firstValue(record, const ['status', 'outcome']);

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.resource,
    required this.record,
    required this.onTap,
  });

  final String resource;
  final Map<String, Object?> record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle(resource, record);
    final pill = _pill(record);
    final primary = Theme.of(context).colorScheme.primary;
    return GradientPanel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: primary.withValues(alpha: 0.13),
            child: Icon(adminResources[resource]!.icon, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(resource, record),
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (pill.isNotEmpty) ...[
            const SizedBox(width: 8),
            StatusPill(pill),
          ],
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 8, AppSpacing.md, 0),
        child: GradientPanel(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.emerald),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      );
}

// ───────────────────────────────────────────────────────────────────────────
// A record's details and what can be done to it
// ───────────────────────────────────────────────────────────────────────────

_RecordAction _action(String key, String label, {bool destructive = false}) =>
    (key: key, label: label, destructive: destructive);

List<_RecordAction> _actionsFor(String resource, Map<String, Object?> record) {
  final status = '${record['status'] ?? ''}';
  switch (resource) {
    case 'wagers':
      return [
        if (status == 'draft') _action('approve', 'Approve'),
        _action('members', 'Entries'),
        _action('edit', 'Edit'),
        _action('status', 'Change status'),
        _action('delete', 'Delete', destructive: true),
      ];
    case 'wallets':
      return [
        _action('add', 'Add money'),
        _action('deduct', 'Deduct money'),
      ];
    case 'payments':
      return [
        _action('verify', 'Verify with provider'),
        _action('delete', 'Delete', destructive: true),
      ];
    case 'settings':
      return [
        _action('edit', 'Edit'),
        _action('delete', 'Delete', destructive: true),
      ];
    case 'teams':
      return [_action('delete', 'Unlink team', destructive: true)];
    case 'challenges':
    case 'notifications':
    case 'fpl-logins':
      return [_action('delete', 'Delete', destructive: true)];
    default:
      // Transactions, gameweeks and the audit trail are read-only.
      return const [];
  }
}

class _RecordDialog extends StatelessWidget {
  const _RecordDialog({
    required this.title,
    required this.record,
    required this.actions,
  });

  final String title;
  final Map<String, Object?> record;
  final List<_RecordAction> actions;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              prettyJson(record),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
        ),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          for (final action in actions)
            action.destructive
                ? TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(context, action.key),
                    child: Text(action.label),
                  )
                : FilledButton.tonal(
                    onPressed: () => Navigator.pop(context, action.key),
                    child: Text(action.label),
                  ),
        ],
      );
}

Future<void> _perform(
  BuildContext context,
  WidgetRef ref,
  String resource,
  Map<String, Object?> record,
  String action,
) async {
  final name = _title(resource, record);
  // Which button was pressed on which kind of record, e.g. "wagers/approve".
  final pressed = '$resource/$action';

  // ── Pools ────────────────────────────────────────────────────────────
  if (pressed == 'wagers/approve') {
    final id = '${record['id']}';
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.approveWager(id),
      refresh: const ['wagers', 'notifications'],
      success: '$name is approved and open. Its creator has been notified.',
    );
    return;
  }
  if (pressed == 'wagers/members') {
    await showDialog<void>(
      context: context,
      builder: (context) => _PoolEntriesDialog(
        poolId: '${record['id']}',
        poolName: name,
      ),
    );
    return;
  }
  if (pressed == 'wagers/edit') {
    await _editWager(context, ref, record);
    return;
  }
  if (pressed == 'wagers/status') {
    await _changeWagerStatus(context, ref, record);
    return;
  }
  if (pressed == 'wagers/delete') {
    final id = '${record['id']}';
    final settled = '${record['status']}' == 'settled';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete $name?',
      message: settled
          ? 'The pool and its entries will be removed. It is already '
              'settled, so no money moves. This cannot be undone.'
          : 'Every paid entry will be refunded, then the pool and its '
              'entries will be removed. This cannot be undone.',
      confirmLabel: 'Delete pool',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteWager(id),
      refresh: const ['wagers', 'wallets', 'transactions'],
      success: '$name was deleted.',
    );
    return;
  }

  // ── Wallets ──────────────────────────────────────────────────────────
  if (pressed == 'wallets/add' || pressed == 'wallets/deduct') {
    await adjustWalletDialog(
      context,
      ref,
      userId: '${record['user_id']}',
      userLabel: firstValue(record, const ['full_name', 'email']),
      credit: action == 'add',
    );
    return;
  }

  // ── Payments ─────────────────────────────────────────────────────────
  if (pressed == 'payments/verify') {
    final reference = '${record['reference']}';
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.verifyPayment(reference),
      refresh: const ['payments', 'wallets', 'transactions'],
      success: 'Payment checked with the provider.',
    );
    return;
  }
  if (pressed == 'payments/delete') {
    final reference = '${record['reference']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete this payment record?',
      message: 'Only the record is removed. Money it already added to the '
          'wallet stays there. This cannot be undone.',
      confirmLabel: 'Delete record',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deletePayment(reference),
      refresh: const ['payments'],
      success: 'Payment record deleted.',
    );
    return;
  }

  // ── Settings ─────────────────────────────────────────────────────────
  if (pressed == 'settings/edit') {
    await _putSetting(context, ref, record: record);
    return;
  }
  if (pressed == 'settings/delete') {
    final key = '${record['key']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete setting "$key"?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete setting',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteSetting(key),
      refresh: const ['settings'],
      success: 'Setting deleted.',
    );
    return;
  }

  // ── Teams, challenges, notifications, FPL sign-ins ───────────────────
  if (pressed == 'teams/delete') {
    final userId = '${record['user_id']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Unlink $name?',
      message: 'The user will have no FPL team until they link one again. '
          'An account that signs in with FPL gets it back at its next '
          'sign-in.',
      confirmLabel: 'Unlink team',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteTeam(userId),
      refresh: const ['teams'],
      success: 'Team unlinked.',
    );
    return;
  }
  if (pressed == 'challenges/delete') {
    final id = '${record['id']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete this challenge?',
      message: 'If it is still open the challenger is refunded first. '
          'This cannot be undone.',
      confirmLabel: 'Delete challenge',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteChallenge(id),
      refresh: const ['challenges', 'wallets', 'transactions'],
      success: 'Challenge deleted.',
    );
    return;
  }
  if (pressed == 'notifications/delete') {
    final id = '${record['id']}';
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteNotification(id),
      refresh: const ['notifications'],
      success: 'Notification deleted.',
    );
    return;
  }
  if (pressed == 'fpl-logins/delete') {
    final id = '${record['id']}';
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteFplLogin(id),
      refresh: const ['fpl-logins'],
      success: 'Sign-in record deleted.',
    );
    return;
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Dialogs
// ───────────────────────────────────────────────────────────────────────────

/// The managers in a pool, each with a button to remove (and refund) them.
class _PoolEntriesDialog extends ConsumerWidget {
  const _PoolEntriesDialog({required this.poolId, required this.poolName});
  final String poolId;
  final String poolName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(adminWagerMembersProvider(poolId));
    return AlertDialog(
      title: Text('Entries · $poolName', maxLines: 2, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 520,
        child: members.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text(error.toString()),
          data: (items) => items.isEmpty
              ? const Text('Nobody has entered this pool yet.')
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final member in items)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(firstValue(member, const ['full_name', 'email'])),
                          subtitle: Text(
                            [
                              firstValue(member, const ['status']),
                              if (member['entry_id'] != null)
                                'FPL ID ${member['entry_id']}',
                              if (member['team_name'] != null)
                                '${member['team_name']}',
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            tooltip: 'Remove from pool',
                            color: Theme.of(context).colorScheme.error,
                            icon: const Icon(Icons.person_remove_outlined),
                            onPressed: () => _remove(context, ref, member),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> member,
  ) async {
    final who = firstValue(member, const ['full_name', 'email']);
    final confirmed = await confirmAdminAction(
      context,
      title: 'Remove $who?',
      message: 'They leave $poolName and get their stake back, unless the '
          'pool is already settled.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    final userId = '${member['user_id']}';
    final done = await runAdminAction(
      context,
      ref,
      action: (repository) => repository.removeWagerMember(poolId, userId),
      refresh: const ['wagers', 'wallets', 'transactions'],
      success: '$who was removed from the pool.',
    );
    if (done) ref.invalidate(adminWagerMembersProvider(poolId));
  }
}

Future<void> _createUser(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final role = ValueNotifier<String>('admin');
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add user'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This creates an account that signs in with an email and '
              'password. Managers who play sign up themselves with FPL.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 10 characters',
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: role,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                initialValue: value,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  helperText: 'Only a superadmin can create an admin',
                ),
                items: const ['user', 'admin', 'superadmin']
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (next) {
                  if (next != null) role.value = next;
                },
              ),
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
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final values = <String, Object?>{
    'full_name': name.text.trim(),
    'email': email.text.trim(),
    'phone': phone.text.trim(),
    'password': password.text,
    'role': role.value,
  };
  name.dispose();
  email.dispose();
  phone.dispose();
  password.dispose();
  role.dispose();
  if (accepted != true || !context.mounted) return;
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.createUser(values),
    refresh: const ['users', 'wallets'],
    success: '${values['full_name']} was created.',
  );
}

Future<void> _createWager(BuildContext context, WidgetRef ref) async {
  final name = TextEditingController();
  final gameweek = TextEditingController();
  final stake = TextEditingController(text: '1000');
  final rules = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create pool'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The pool is created as a draft. Approve it to open it for '
              'entries.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gameweek,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gameweek'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stake,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Stake (₦)',
                helperText: 'At least ₦1,000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rules,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Rules'),
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
          child: const Text('Create'),
        ),
      ],
    ),
  );
  final poolName = name.text.trim();
  final week = int.tryParse(gameweek.text.trim());
  final stakeCents = nairaToCents(stake.text);
  final poolRules = rules.text.trim();
  name.dispose();
  gameweek.dispose();
  stake.dispose();
  rules.dispose();
  if (accepted != true || !context.mounted) return;
  if (poolName.length < 3 || week == null || stakeCents == null) {
    AppNotice.error(context, 'A name, a gameweek and a stake are required.');
    return;
  }
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.createWager({
      'name': poolName,
      'gameweek': week,
      'stake_cents': stakeCents,
      'visibility': 'public',
      'approval_required': false,
      'rules': poolRules,
      'draw_method': 'split',
    }),
    refresh: const ['wagers'],
    success: '$poolName was created as a draft. Approve it to open it.',
  );
}

Future<void> _editWager(
  BuildContext context,
  WidgetRef ref,
  Map<String, Object?> record,
) async {
  final id = '${record['id']}';
  final isAuto = '${record['pool_kind']}' == 'auto';
  final originalName = '${record['name'] ?? ''}';
  final originalRules = '${record['rules'] ?? ''}';
  final originalMax = record['max_members'] is num
      ? '${(record['max_members']! as num).toInt()}'
      : '';
  final name = TextEditingController(text: originalName);
  final rules = TextEditingController(text: originalRules);
  final maxMembers = TextEditingController(text: originalMax);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit pool'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rules,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Rules'),
            ),
            if (!isAuto) ...[
              const SizedBox(height: 12),
              TextField(
                controller: maxMembers,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum managers',
                  helperText: 'Between 2 and 100,000',
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Auto pools keep their standard stake and size; only the '
                'name and rules can be edited.',
              ),
            ],
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
  final newName = name.text.trim();
  final newRules = rules.text.trim();
  final newMax = maxMembers.text.trim();
  name.dispose();
  rules.dispose();
  maxMembers.dispose();
  if (accepted != true || !context.mounted) return;

  // Send only what actually changed.
  final changes = <String, Object?>{
    if (newName != originalName) 'name': newName,
    if (newRules != originalRules) 'rules': newRules,
    if (!isAuto && newMax != originalMax && int.tryParse(newMax) != null)
      'max_members': int.parse(newMax),
  };
  if (changes.isEmpty) {
    AppNotice.info(context, 'Nothing was changed.');
    return;
  }
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.updateWager(id, changes),
    refresh: const ['wagers'],
    success: 'Pool updated.',
  );
}

Future<void> _changeWagerStatus(
  BuildContext context,
  WidgetRef ref,
  Map<String, Object?> record,
) async {
  final id = '${record['id']}';
  final current = '${record['status'] ?? 'draft'}';
  final status = ValueNotifier<String>(current);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Change status'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: status,
              builder: (context, value, _) => DropdownButtonFormField<String>(
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Pool status'),
                items: const [
                  'draft',
                  'open',
                  'locked',
                  'scoring',
                  'settled',
                  'cancelled',
                ]
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (next) {
                  if (next != null) status.value = next;
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Open approves a draft pool. Cancelled refunds every paid '
              'entry.',
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
          child: const Text('Update'),
        ),
      ],
    ),
  );
  final next = status.value;
  status.dispose();
  if (accepted != true || next == current || !context.mounted) return;
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.updateWagerStatus(id, next),
    refresh: const ['wagers', 'wallets', 'transactions', 'notifications'],
    success: 'Pool status is now $next.',
  );
}

Future<void> _putSetting(
  BuildContext context,
  WidgetRef ref, {
  Map<String, Object?>? record,
}) async {
  final key = TextEditingController(text: record?['key']?.toString() ?? '');
  final value = TextEditingController(
    text: record == null ? 'true' : prettyJson(record['value']),
  );
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(record == null ? 'Add setting' : 'Edit setting'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: key,
              enabled: record == null,
              decoration: const InputDecoration(labelText: 'Key'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: value,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Value (JSON)',
                helperText: 'For example true, 5, "text" or {"a": 1}',
              ),
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
  final settingKey = key.text.trim();
  final raw = value.text;
  key.dispose();
  value.dispose();
  if (accepted != true || !context.mounted) return;
  if (settingKey.isEmpty) {
    AppNotice.error(context, 'A key is required.');
    return;
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    AppNotice.error(context, 'The value must be valid JSON.');
    return;
  }
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.putSetting(settingKey, decoded),
    refresh: const ['settings'],
    success: 'Setting saved.',
  );
}
