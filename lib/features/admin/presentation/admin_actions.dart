import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/core/ui/app_notice.dart';
import 'package:fpl_wager_admin/features/admin/data/admin_repository.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';

/// Runs one admin change, refreshes the lists it affects and tells the
/// administrator how it went. Returns true on success.
Future<bool> runAdminAction(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function(AdminRepository repository) action,
  required String success,
  List<String> refresh = const [],
}) async {
  final error = await ref
      .read(adminActionProvider.notifier)
      .run(action, refresh: refresh);
  if (!context.mounted) return error == null;
  if (error == null) {
    AppNotice.success(context, success);
  } else {
    AppNotice.error(context, error);
  }
  return error == null;
}

/// Like [runAdminAction], for changes where the server explains the outcome
/// itself: approving a withdrawal can end as "processing", "successful",
/// "failed and refunded" or "waiting for a one-time code". The server's
/// sentence is shown as a neutral notice, because a request that was handled
/// correctly is not always good news.
///
/// The lists in [refresh] are reloaded even when the action fails, because a
/// refused bank transfer still changes what the record shows.
Future<bool> runAdminActionForMessage(
  BuildContext context,
  WidgetRef ref, {
  required Future<String> Function(AdminRepository repository) action,
  List<String> refresh = const [],
}) async {
  var message = '';
  final error = await ref.read(adminActionProvider.notifier).run(
    (repository) async => message = await action(repository),
    refresh: refresh,
    refreshOnError: true,
  );
  if (!context.mounted) return error == null;
  if (error == null) {
    AppNotice.info(context, message);
  } else {
    AppNotice.error(context, error);
  }
  return error == null;
}

/// Asks before doing something that cannot be undone. Returns true only if
/// the administrator pressed the confirm button.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
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
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Disposes a dialog's text controllers once the dialog has finished closing.
///
/// `showDialog` returns while the dialog is still on screen, fading out, and
/// its text fields are still attached to their controllers. Disposing a
/// controller at that moment makes the field complain if it rebuilds, so
/// this waits until the closing animation is over.
void disposeAfterDialog(List<ChangeNotifier> controllers) {
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}

/// Turns a typed naira amount ("5,000" or "5000.50") into cents, or null if
/// it is not a positive amount.
int? nairaToCents(String text) {
  final value = double.tryParse(text.replaceAll(',', '').trim());
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

/// Pretty-prints a record for the detail dialog.
String prettyJson(Object? value) =>
    const JsonEncoder.withIndent('  ').convert(value);

/// The first non-empty value among [keys], as text.
String firstValue(Map<String, Object?> record, List<String> keys) {
  for (final key in keys) {
    final value = record[key];
    if (value != null && '$value'.isNotEmpty) return '$value';
  }
  return '';
}

/// Asks for a naira amount and a reason, then adds it to or deducts it from a
/// user's wallet.
Future<void> adjustWalletDialog(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String userLabel,
  required bool credit,
}) async {
  final amount = TextEditingController();
  final reason = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(credit ? 'Add money' : 'Deduct money'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(userLabel),
            const SizedBox(height: 14),
            TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₦)',
                helperText: 'In naira, for example 5000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                helperText: 'Shown in the user\'s history and the audit trail',
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
          child: Text(credit ? 'Add money' : 'Deduct money'),
        ),
      ],
    ),
  );
  final cents = nairaToCents(amount.text);
  final why = reason.text.trim();
  disposeAfterDialog([amount, reason]);
  if (accepted != true || !context.mounted) return;
  if (cents == null) {
    AppNotice.error(context, 'Enter an amount greater than zero.');
    return;
  }
  if (why.length < 5) {
    AppNotice.error(context, 'Give a short reason (at least 5 characters).');
    return;
  }
  final done = await runAdminAction(
    context,
    ref,
    action: (repository) => repository.adjustWallet(
      userId: userId,
      amountCents: credit ? cents : -cents,
      reason: why,
    ),
    refresh: const ['wallets', 'transactions'],
    success: credit ? 'Money added to the wallet.' : 'Money deducted from the wallet.',
  );
  if (done) ref.invalidate(adminWalletProvider(userId));
}

/// Asks for a title and message and sends them to one user as an in-app
/// notification. [userId] may be left empty to let the administrator paste
/// one in.
Future<void> sendNotificationDialog(
  BuildContext context,
  WidgetRef ref, {
  String userId = '',
  String userLabel = '',
}) async {
  final target = TextEditingController(text: userId);
  final title = TextEditingController();
  final body = TextEditingController();
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Send notification'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userLabel.isNotEmpty) ...[
              Text(userLabel),
              const SizedBox(height: 14),
            ] else ...[
              TextField(
                controller: target,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  helperText: 'Copy it from the user\'s page under Users',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: body,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Message'),
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
          child: const Text('Send'),
        ),
      ],
    ),
  );
  final to = target.text.trim();
  final heading = title.text.trim();
  final message = body.text.trim();
  disposeAfterDialog([target, title, body]);
  if (accepted != true || !context.mounted) return;
  if (to.isEmpty || heading.length < 2 || message.isEmpty) {
    AppNotice.error(context, 'A user, a title and a message are all required.');
    return;
  }
  await runAdminAction(
    context,
    ref,
    action: (repository) => repository.createNotification(
      userId: to,
      title: heading,
      body: message,
    ),
    refresh: const ['notifications'],
    success: 'Notification sent.',
  );
}
