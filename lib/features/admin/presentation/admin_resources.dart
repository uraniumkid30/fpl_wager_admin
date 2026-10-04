import 'package:flutter/material.dart';

typedef AdminResourceDefinition = ({
  String label,
  String description,
  IconData icon,

  /// The label of the "+" button, or null when records of this kind cannot
  /// be created from the admin app.
  String? createLabel,

  /// A one-line note shown above the list, or null.
  String? note,
});

/// Everything the admin app manages, in the order it appears on the dashboard.
/// The key is the path under `/v1/admin/`.
const adminResources = <String, AdminResourceDefinition>{
  'users': (
    label: 'Users',
    description: 'Create, edit, block and delete accounts',
    icon: Icons.people_outline_rounded,
    createLabel: 'Add user',
    note: null,
  ),
  'wagers': (
    label: 'Pools',
    description: 'Approve, create, edit, settle, cancel and delete pools',
    icon: Icons.emoji_events_outlined,
    createLabel: 'Create pool',
    note: 'Locked pools are settled and paid automatically once FPL '
        'finalises the gameweek. Cancelling or deleting an unsettled pool '
        'refunds every entry.',
  ),
  'wallets': (
    label: 'Wallets',
    description: 'Balances; add or deduct money',
    icon: Icons.account_balance_wallet_outlined,
    createLabel: null,
    note: 'Every change is written to the ledger and the audit trail.',
  ),
  'withdrawals': (
    label: 'Withdrawals',
    description: 'Approve or reject withdrawal requests',
    icon: Icons.north_east_rounded,
    createLabel: null,
    note: 'Approving sends the money to the user\'s bank through the payment '
        'provider. Rejecting returns it to their wallet.',
  ),
  'payments': (
    label: 'Payments',
    description: 'Re-verify with the provider, or delete a record',
    icon: Icons.payments_outlined,
    createLabel: null,
    note: 'Deleting a payment record does not take back money it credited.',
  ),
  'transactions': (
    label: 'Transactions',
    description: 'The platform-wide ledger (read-only)',
    icon: Icons.receipt_long_outlined,
    createLabel: null,
    note: 'Ledger entries cannot be edited or deleted on their own.',
  ),
  'challenges': (
    label: 'Head to head',
    description: 'View and delete challenges',
    icon: Icons.compare_arrows_rounded,
    createLabel: null,
    note: 'Deleting an open challenge refunds the challenger.',
  ),
  'teams': (
    label: 'FPL teams',
    description: 'Linked FPL entries; unlink one',
    icon: Icons.sports_soccer_rounded,
    createLabel: null,
    note: null,
  ),
  'notifications': (
    label: 'Notifications',
    description: 'Send a message to a user; delete one',
    icon: Icons.notifications_outlined,
    createLabel: 'Send notification',
    note: null,
  ),
  'notification-subscriptions': (
    label: 'Notification emails',
    description: 'Who is emailed about withdrawal requests and finished pools',
    icon: Icons.mark_email_unread_outlined,
    createLabel: 'Add email',
    note: 'Each address is emailed only about the events switched on for it.',
  ),
  'settings': (
    label: 'System settings',
    description: 'Create, update and delete configuration values',
    icon: Icons.tune_rounded,
    createLabel: 'Add setting',
    note: null,
  ),
  'gameweeks': (
    label: 'Gameweeks',
    description: 'The FPL calendar, synced from FPL (read-only)',
    icon: Icons.calendar_month_outlined,
    createLabel: null,
    note: 'Gameweeks are kept in step with FPL by the scheduler.',
  ),
  'fpl-logins': (
    label: 'FPL sign-ins',
    description: 'What FPL returned at each sign-in',
    icon: Icons.manage_search_rounded,
    createLabel: null,
    note: 'Everything FPL sent back when a manager signed in, tokens removed.',
  ),
  'audit-logs': (
    label: 'Audit trail',
    description: 'Every administrator action (read-only)',
    icon: Icons.verified_user_outlined,
    createLabel: null,
    note: null,
  ),
};
