import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';

/// One thing that can be done to a record: a button on its detail panel.
///
/// [primary] marks the action an administrator most likely opened the
/// record for (approve, settle), which gets the filled button.
typedef RecordAction = ({
  String key,
  String label,
  IconData icon,
  bool destructive,
  bool primary,
});

/// Starts the "create" flow for a section that has one (users, pools,
/// settings, notifications, notification emails).
Future<void> createRecord(BuildContext context, WidgetRef ref, String resource) {
  return switch (resource) {
    'users' => _createUser(context, ref),
    'wagers' => _createWager(context, ref),
    'settings' => _putSetting(context, ref),
    'notifications' => sendNotificationDialog(context, ref),
    'notification-subscriptions' => _notificationEmailDialog(context, ref),
    _ => Future<void>.value(),
  };
}

// ───────────────────────────────────────────────────────────────────────────
// How a record is named and its values are shown
// ───────────────────────────────────────────────────────────────────────────

String recordTitle(String resource, Map<String, Object?> record) {
  final text = switch (resource) {
    'users' || 'wallets' => firstValue(record, const ['full_name', 'email']),
    'wagers' => firstValue(record, const ['name']),
    'payments' => firstValue(record, const ['reference']),
    'withdrawals' =>
      '${moneyOf(record['amount_cents'])} · ${firstValue(record, const ['full_name', 'email'])}',
    'notification-subscriptions' => firstValue(record, const ['email']),
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


String moneyOf(Object? cents) => cents is num ? money(cents.toInt()) : '';

/// "Access Bank 0123456789 (CHRIS OKORO)" from a withdrawal's bank details,
/// or '' when there are none.
String bankOf(Object? details) {
  if (details is! Map) return '';
  final bank = '${details['bank_name'] ?? ''}'.trim();
  final number = '${details['account_number'] ?? ''}'.trim();
  final name = '${details['account_name'] ?? ''}'.trim();
  if (number.isEmpty) return '';
  final account = bank.isEmpty ? number : '$bank $number';
  return name.isEmpty ? account : '$account ($name)';
}

/// How a status reads to a person: "pending_approval" → "pending approval".
String readableStatus(String status) => status.replaceAll('_', ' ');

// ───────────────────────────────────────────────────────────────────────────
// What can be done to a record
// ───────────────────────────────────────────────────────────────────────────

RecordAction _action(
  String key,
  String label, {
  bool destructive = false,
  bool primary = false,
}) =>
    (
      key: key,
      label: label,
      icon: switch (key) {
        'approve' => Icons.check_circle_outline_rounded,
        'reject' => Icons.block_rounded,
        'settle' => Icons.flag_outlined,
        'members' => Icons.groups_2_outlined,
        'edit' => Icons.edit_outlined,
        'status' => Icons.swap_horiz_rounded,
        'verify' => Icons.sync_rounded,
        'add' => Icons.add_rounded,
        'deduct' => Icons.remove_rounded,
        'delete' => Icons.delete_outline_rounded,
        _ => Icons.chevron_right_rounded,
      },
      destructive: destructive,
      primary: primary,
    );

List<RecordAction> actionsFor(String resource, Map<String, Object?> record) {
  final status = '${record['status'] ?? ''}';
  switch (resource) {
    case 'wagers':
      return [
        if (status == 'draft') _action('approve', 'Approve', primary: true),
        // A locked pool can be finished by hand once FPL has finalised its
        // gameweek; the worker does the same on its own every few minutes.
        if (status == 'locked' || status == 'scoring')
          _action('settle', 'Settle now', primary: true),
        _action('members', 'Entries'),
        _action('edit', 'Edit'),
        // A settled pool has paid out; its status is final.
        if (status != 'settled') _action('status', 'Change status'),
        _action('delete', 'Delete', destructive: true),
      ];
    case 'withdrawals':
      // The provider has acknowledged the transfer once it has reported a
      // status for it. Until then an approved request can be sent again.
      final acknowledged = '${record['provider_status'] ?? ''}'.isNotEmpty;
      return [
        if (status == 'pending_approval') ...[
          _action('approve', 'Approve and pay', primary: true),
          _action('reject', 'Reject', destructive: true),
        ],
        if (status == 'approved' && !acknowledged)
          _action('approve', 'Retry transfer', primary: true),
        if (status == 'approved' || status == 'successful' || status == 'failed')
          _action('verify', 'Check status'),
      ];
    case 'notification-subscriptions':
      return [
        _action('edit', 'Edit'),
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

Future<void> performRecordAction(
  BuildContext context,
  WidgetRef ref,
  String resource,
  Map<String, Object?> record,
  String action,
) async {
  final name = recordTitle(resource, record);
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
  if (pressed == 'wagers/settle') {
    final id = '${record['id']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Settle $name now?',
      message: 'Every entry is scored from FPL, the winners are paid into '
          'their wallets and emailed, and the pool is closed for good. It '
          'only works once FPL has finalised the gameweek.',
      confirmLabel: 'Settle pool',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminActionForMessage(
      context,
      ref,
      action: (repository) => repository.settleWager(id),
      refresh: const ['wagers', 'wallets', 'transactions', 'notifications'],
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
    // An open auto pool that is deleted is replaced straight away, unless
    // its stake (or auto pools as a whole) has been stopped.
    final replaced = '${record['pool_kind']}' == 'auto' &&
        '${record['status']}' == 'open';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete $name?',
      message: settled
          ? 'The pool and its entries will be removed. It is already '
              'settled, so no money moves. This cannot be undone.'
          : 'Every paid entry will be refunded, then the pool and its '
              'entries will be removed. This cannot be undone.'
              '${replaced ? '\n\nThis is an auto pool: a fresh one opens in its place. To stop that, pause its stake on the Auto pools page first.' : ''}',
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

  // ── Withdrawals ──────────────────────────────────────────────────────
  if (pressed == 'withdrawals/approve') {
    final id = '${record['id']}';
    final provider = '${record['provider'] ?? 'the payment provider'}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Pay ${moneyOf(record['amount_cents'])}?',
      message: 'To ${bankOf(record['bank_details'])}.\n\n'
          'The money is sent from your $provider balance to this bank '
          'account. A transfer that has gone through cannot be taken back '
          'from here.',
      confirmLabel: 'Approve and pay',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminActionForMessage(
      context,
      ref,
      action: (repository) => repository.approveWithdrawal(id),
      refresh: const ['withdrawals', 'wallets', 'transactions'],
    );
    return;
  }
  if (pressed == 'withdrawals/reject') {
    await _rejectWithdrawal(context, ref, record);
    return;
  }
  if (pressed == 'withdrawals/verify') {
    final id = '${record['id']}';
    await runAdminActionForMessage(
      context,
      ref,
      action: (repository) => repository.verifyWithdrawal(id),
      refresh: const ['withdrawals', 'wallets', 'transactions'],
    );
    return;
  }

  // ── Notification emails ──────────────────────────────────────────────
  if (pressed == 'notification-subscriptions/edit') {
    await _notificationEmailDialog(context, ref, record: record);
    return;
  }
  if (pressed == 'notification-subscriptions/delete') {
    final id = '${record['id']}';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Remove $name?',
      message: 'This address will no longer be emailed about anything.',
      confirmLabel: 'Remove',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) => repository.deleteNotificationEmail(id),
      refresh: const ['notification-subscriptions'],
      success: '$name was removed.',
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
                              // Filled in when the pool is settled.
                              if (member['rank'] != null)
                                '${_ordinal(member['rank'])} · ${member['points']} pts',
                              if (member['payout_cents'] is num &&
                                  (member['payout_cents']! as num) > 0)
                                'won ${moneyOf(member['payout_cents'])}',
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

/// "1st", "2nd", "11th" from a rank.
String _ordinal(Object? rank) {
  if (rank is! num) return '';
  final n = rank.toInt();
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) { 1 => 'st', 2 => 'nd', 3 => 'rd', _ => 'th' };
  return '$n$suffix';
}

/// Rejects a withdrawal request. The reason is optional; when given, the
/// user sees it in the app and in their email.
Future<void> _rejectWithdrawal(
  BuildContext context,
  WidgetRef ref,
  Map<String, Object?> record,
) async {
  final id = '${record['id']}';
  final reason = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Reject ${moneyOf(record['amount_cents'])}?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${firstValue(record, const ['full_name', 'email'])} gets the '
              'money back in their wallet and is told by email.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reason,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                helperText: 'Shown to the user',
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
  final why = reason.text.trim();
  disposeAfterDialog([reason]);
  if (accepted != true || !context.mounted) return;
  await runAdminActionForMessage(
    context,
    ref,
    action: (repository) => repository.rejectWithdrawal(id, why),
    refresh: const ['withdrawals', 'wallets', 'transactions'],
  );
}

/// Adds a notification email, or edits one when [record] is given: the
/// address and which events it is emailed about.
Future<void> _notificationEmailDialog(
  BuildContext context,
  WidgetRef ref, {
  Map<String, Object?>? record,
}) async {
  final id = record == null ? null : '${record['id']}';
  final email = TextEditingController(text: '${record?['email'] ?? ''}');
  // A new address starts with both alerts on; one that hears about nothing
  // would be pointless. An existing one keeps what it has.
  var onWithdrawRequest = record == null || record['on_withdraw_request'] == true;
  var onPoolEnded = record == null || record['on_pool_ended'] == true;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(id == null ? 'Add notification email' : 'Edit notification email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: email,
                autofocus: id == null,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email address'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Withdrawal requests'),
                subtitle: const Text('When a user asks to withdraw money'),
                value: onWithdrawRequest,
                onChanged: (value) => setState(() => onWithdrawRequest = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pool ended'),
                subtitle: const Text('When a pool is settled or cancelled'),
                value: onPoolEnded,
                onChanged: (value) => setState(() => onPoolEnded = value),
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
            child: Text(id == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    ),
  );
  final address = email.text.trim().toLowerCase();
  disposeAfterDialog([email]);
  if (accepted != true || !context.mounted) return;
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(address)) {
    AppNotice.error(context, 'Enter a valid email address.');
    return;
  }
  await runAdminAction(
    context,
    ref,
    action: (repository) => id == null
        ? repository.createNotificationEmail(
            email: address,
            onWithdrawRequest: onWithdrawRequest,
            onPoolEnded: onPoolEnded,
          )
        : repository.updateNotificationEmail(
            id,
            email: address,
            onWithdrawRequest: onWithdrawRequest,
            onPoolEnded: onPoolEnded,
          ),
    refresh: const ['notification-subscriptions'],
    success: id == null ? '$address was added.' : '$address was updated.',
  );
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
  disposeAfterDialog([name, email, phone, password, role]);
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
  disposeAfterDialog([name, gameweek, stake, rules]);
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
  disposeAfterDialog([name, rules, maxMembers]);
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
                // "settled" is not offered: a pool is settled by scoring
                // and paying it (Settle now, or the worker), not by a label.
                items: const [
                  'draft',
                  'open',
                  'locked',
                  'scoring',
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
              'entry. A locked pool is settled and paid automatically once '
              'FPL finalises its gameweek, or with Settle now.',
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
  disposeAfterDialog([status]);
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
  disposeAfterDialog([key, value]);
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
