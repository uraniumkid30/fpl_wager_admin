import 'dart:convert';

import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:intl/intl.dart';

/// How a column's values are shown, sorted and exported.
enum CellKind {
  text,

  /// An amount in cents, shown as naira.
  money,

  /// An amount that may be negative: green with a plus, red with a minus.
  signedMoney,
  number,
  date,

  /// A status word, shown as a coloured pill.
  status,

  /// A category word, shown as a plain pill.
  tag,

  /// True or false, shown as a tick or a dash.
  flag,

  /// A reference or key, shown in a fixed-width font.
  code,
}

/// One column of a list page.
class ColumnSpec {
  const ColumnSpec(
    this.key,
    this.label, {
    this.kind = CellKind.text,
    this.width = 140,
    this.flex = 0,
    this.primary = false,
    this.hidden = false,
    this.read,
    this.secondary,
  });

  /// The field in the record, and the column's identity for sorting and
  /// hiding.
  final String key;
  final String label;
  final CellKind kind;

  /// The narrowest the column may be.
  final double width;

  /// Its share of any width left over once every column has its minimum.
  final int flex;

  /// The column that names the record; shown stronger than the rest.
  final bool primary;

  /// Left out until the administrator switches it on under Columns.
  final bool hidden;

  /// Works the value out when it is not simply `record[key]`.
  final Object? Function(Map<String, Object?> record)? read;

  /// A second, quieter line under the value (an email under a name).
  final String Function(Map<String, Object?> record)? secondary;

  Object? value(Map<String, Object?> record) {
    final read = this.read;
    return read == null ? record[key] : read(record);
  }

  bool get numeric =>
      kind == CellKind.money ||
      kind == CellKind.signedMoney ||
      kind == CellKind.number;
}

/// A field a list can be filtered or grouped by.
class FieldSpec {
  const FieldSpec(this.key, this.label, {this.read});

  final String key;
  final String label;
  final Object? Function(Map<String, Object?> record)? read;

  /// The value as the word shown in the filter menu and group heading.
  String text(Map<String, Object?> record) {
    final read = this.read;
    final value = read == null ? record[key] : read(record);
    if (value == null || '$value'.trim().isEmpty) return 'None';
    if (value is bool) return value ? 'Yes' : 'No';
    if (key == 'gameweek') return 'Gameweek $value';
    final text = '$value'.replaceAll('_', ' ');
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// The columns, filters and groupings of one section's list page.
class ResourceView {
  const ResourceView({
    required this.columns,
    this.filters = const [],
    this.groups = const [],
  });

  final List<ColumnSpec> columns;
  final List<FieldSpec> filters;
  final List<FieldSpec> groups;
}

String _text(Object? value) => value == null ? '' : '$value';

String _email(Map<String, Object?> record) => _text(record['email']);

const _status = FieldSpec('status', 'Status');
const _gameweek = FieldSpec('gameweek', 'Gameweek');
const _provider = FieldSpec('provider', 'Provider');
const _mode = FieldSpec('credential_mode', 'Mode');

/// The list page of every section, keyed like [adminResources].
final Map<String, ResourceView> resourceViews = {
  'users': ResourceView(
    columns: [
      ColumnSpec('full_name', 'User', primary: true, width: 220, flex: 3, secondary: _email),
      const ColumnSpec('role', 'Role', kind: CellKind.tag, width: 120),
      const ColumnSpec('status', 'Status', kind: CellKind.status, width: 130),
      const ColumnSpec('email_verified', 'Email verified', kind: CellKind.flag, width: 130),
      const ColumnSpec('fpl_entry_id', 'FPL ID', kind: CellKind.number, width: 110),
      const ColumnSpec('created_at', 'Joined', kind: CellKind.date, width: 160),
      const ColumnSpec('updated_at', 'Updated', kind: CellKind.date, width: 160, hidden: true),
    ],
    filters: const [
      _status,
      FieldSpec('role', 'Role'),
      FieldSpec('email_verified', 'Email verified'),
    ],
    groups: const [FieldSpec('role', 'Role'), _status],
  ),
  'wagers': ResourceView(
    columns: [
      ColumnSpec(
        'name',
        'Pool',
        primary: true,
        width: 250,
        flex: 3,
        secondary: (record) => [
          _text(record['pool_kind']) == 'auto' ? 'Auto pool' : 'Custom pool',
          if (_text(record['visibility']) == 'private') 'private',
        ].join(' · '),
      ),
      const ColumnSpec('gameweek', 'GW', kind: CellKind.number, width: 76),
      const ColumnSpec('stake_cents', 'Stake', kind: CellKind.money, width: 110),
      const ColumnSpec('member_count', 'Entries', kind: CellKind.number, width: 96),
      const ColumnSpec('prize_pool_cents', 'Prize pool', kind: CellKind.money, width: 130),
      const ColumnSpec('status', 'Status', kind: CellKind.status, width: 130),
      const ColumnSpec('deadline', 'Deadline', kind: CellKind.date, width: 160),
      const ColumnSpec('max_members', 'Entry limit', kind: CellKind.number, width: 110, hidden: true),
      const ColumnSpec('draw_method', 'Ties', kind: CellKind.tag, width: 110, hidden: true),
      const ColumnSpec('created_at', 'Created', kind: CellKind.date, width: 160, hidden: true),
    ],
    filters: const [
      _status,
      FieldSpec('pool_kind', 'Kind'),
      _gameweek,
      FieldSpec('visibility', 'Visibility'),
    ],
    groups: const [_status, _gameweek, FieldSpec('pool_kind', 'Kind')],
  ),
  'wallets': ResourceView(
    columns: [
      ColumnSpec('full_name', 'User', primary: true, width: 240, flex: 3, secondary: _email),
      const ColumnSpec('available_cents', 'Available', kind: CellKind.money, width: 150),
      const ColumnSpec('locked_cents', 'Locked in games', kind: CellKind.money, width: 150),
      const ColumnSpec('updated_at', 'Last change', kind: CellKind.date, width: 170),
    ],
  ),
  'withdrawals': ResourceView(
    columns: [
      ColumnSpec('full_name', 'User', primary: true, width: 210, flex: 2, secondary: _email),
      const ColumnSpec('amount_cents', 'Amount', kind: CellKind.money, width: 120),
      ColumnSpec(
        'bank_details',
        'Paid to',
        width: 250,
        flex: 3,
        read: (record) => bankOf(record['bank_details']),
      ),
      const ColumnSpec('status', 'Status', kind: CellKind.status, width: 150),
      const ColumnSpec('provider', 'Provider', kind: CellKind.tag, width: 110),
      const ColumnSpec('created_at', 'Requested', kind: CellKind.date, width: 160),
      const ColumnSpec('reviewed_by_name', 'Reviewed by', width: 150, hidden: true),
      const ColumnSpec('reason', 'Reason', width: 200, hidden: true),
      const ColumnSpec('last_error', 'Provider said', width: 220, hidden: true),
      const ColumnSpec('reference', 'Reference', kind: CellKind.code, width: 260, hidden: true),
    ],
    filters: const [_status, _provider, _mode],
    groups: const [_status, _provider],
  ),
  'payments': const ResourceView(
    columns: [
      ColumnSpec('reference', 'Reference', kind: CellKind.code, primary: true, width: 240, flex: 3),
      ColumnSpec('amount_cents', 'Amount', kind: CellKind.money, width: 120),
      ColumnSpec('provider', 'Provider', kind: CellKind.tag, width: 110),
      ColumnSpec('credential_mode', 'Mode', kind: CellKind.tag, width: 90),
      ColumnSpec('status', 'Status', kind: CellKind.status, width: 130),
      ColumnSpec('created_at', 'Started', kind: CellKind.date, width: 160),
      ColumnSpec('paid_at', 'Paid', kind: CellKind.date, width: 160),
      ColumnSpec('user_id', 'User ID', kind: CellKind.code, width: 280, hidden: true),
    ],
    filters: [_status, _provider, _mode],
    groups: [_status, _provider],
  ),
  'transactions': ResourceView(
    columns: [
      ColumnSpec('description', 'Entry', primary: true, width: 260, flex: 3, secondary: _email),
      const ColumnSpec('kind', 'Kind', kind: CellKind.tag, width: 170),
      const ColumnSpec('amount_cents', 'Amount', kind: CellKind.signedMoney, width: 130),
      const ColumnSpec('balance_after_cents', 'Balance after', kind: CellKind.money, width: 140),
      const ColumnSpec('created_at', 'When', kind: CellKind.date, width: 160),
    ],
    filters: const [FieldSpec('kind', 'Kind')],
    groups: const [FieldSpec('kind', 'Kind'), FieldSpec('email', 'User')],
  ),
  'challenges': ResourceView(
    columns: [
      ColumnSpec(
        'challenger_name',
        'Challenger',
        primary: true,
        width: 210,
        flex: 2,
        secondary: (record) => _text(record['challenger_email']),
      ),
      ColumnSpec(
        'opponent_name',
        'Opponent',
        width: 190,
        flex: 2,
        read: (record) {
          final name = _text(record['opponent_name']);
          return name.isNotEmpty
              ? name
              : 'FPL ID ${_text(record['opponent_team_id'])}';
        },
      ),
      const ColumnSpec('gameweek', 'GW', kind: CellKind.number, width: 76),
      const ColumnSpec('stake_cents', 'Stake', kind: CellKind.money, width: 110),
      const ColumnSpec('status', 'Status', kind: CellKind.status, width: 130),
      const ColumnSpec('created_at', 'Created', kind: CellKind.date, width: 160),
    ],
    filters: const [_status, _gameweek],
    groups: const [_status, _gameweek],
  ),
  'teams': ResourceView(
    columns: [
      ColumnSpec(
        'team_name',
        'Team',
        primary: true,
        width: 220,
        flex: 2,
        secondary: (record) => _text(record['manager_name']),
      ),
      ColumnSpec('full_name', 'Account', width: 200, flex: 2, secondary: _email),
      const ColumnSpec('entry_id', 'FPL ID', kind: CellKind.number, width: 110),
      const ColumnSpec('overall_points', 'Points', kind: CellKind.number, width: 96),
      const ColumnSpec('overall_rank', 'Rank', kind: CellKind.number, width: 110),
      const ColumnSpec('gameweek_points', 'GW points', kind: CellKind.number, width: 110),
      const ColumnSpec('synced_at', 'Synced', kind: CellKind.date, width: 160),
    ],
  ),
  'notifications': ResourceView(
    columns: [
      ColumnSpec(
        'title',
        'Notification',
        primary: true,
        width: 280,
        flex: 3,
        secondary: (record) => _text(record['body']),
      ),
      ColumnSpec('full_name', 'To', width: 190, flex: 1, secondary: _email),
      const ColumnSpec('kind', 'Kind', kind: CellKind.tag, width: 170),
      ColumnSpec(
        'read_at',
        'Read',
        kind: CellKind.flag,
        width: 86,
        read: (record) => record['read_at'] != null,
      ),
      const ColumnSpec('created_at', 'Sent', kind: CellKind.date, width: 160),
    ],
    filters: [
      const FieldSpec('kind', 'Kind'),
      FieldSpec('read_at', 'Read', read: (record) => record['read_at'] != null),
    ],
    groups: const [FieldSpec('kind', 'Kind')],
  ),
  'notification-subscriptions': const ResourceView(
    columns: [
      ColumnSpec('email', 'Email address', primary: true, width: 260, flex: 3),
      ColumnSpec('on_withdraw_request', 'Withdrawal requests', kind: CellKind.flag, width: 170),
      ColumnSpec('on_pool_ended', 'Pool ended', kind: CellKind.flag, width: 130),
      ColumnSpec('created_at', 'Added', kind: CellKind.date, width: 160),
    ],
  ),
  'settings': ResourceView(
    columns: [
      const ColumnSpec('key', 'Key', kind: CellKind.code, primary: true, width: 240, flex: 2),
      ColumnSpec(
        'value',
        'Value',
        kind: CellKind.code,
        width: 280,
        flex: 3,
        read: (record) => jsonEncode(record['value']),
      ),
      const ColumnSpec('updated_at', 'Updated', kind: CellKind.date, width: 160),
    ],
  ),
  'gameweeks': const ResourceView(
    columns: [
      ColumnSpec('name', 'Gameweek', primary: true, width: 180, flex: 2),
      ColumnSpec('deadline', 'Deadline', kind: CellKind.date, width: 170),
      ColumnSpec('status', 'Status', kind: CellKind.status, width: 130),
      ColumnSpec('pools', 'Pools', kind: CellKind.number, width: 90),
      ColumnSpec('average_points', 'Average', kind: CellKind.number, width: 100),
      ColumnSpec('highest_points', 'Highest', kind: CellKind.number, width: 100),
      ColumnSpec('updated_at', 'Synced', kind: CellKind.date, width: 160, hidden: true),
    ],
    filters: [_status],
  ),
  'fpl-logins': ResourceView(
    columns: [
      ColumnSpec('full_name', 'Manager', primary: true, width: 230, flex: 3, secondary: _email),
      const ColumnSpec('entry_id', 'FPL ID', kind: CellKind.number, width: 110),
      const ColumnSpec('outcome', 'Outcome', kind: CellKind.status, width: 150),
      const ColumnSpec('created_at', 'When', kind: CellKind.date, width: 170),
    ],
    filters: const [FieldSpec('outcome', 'Outcome')],
    groups: const [FieldSpec('outcome', 'Outcome')],
  ),
  'audit-logs': ResourceView(
    columns: [
      const ColumnSpec('action', 'Action', kind: CellKind.code, primary: true, width: 230, flex: 2),
      const ColumnSpec('admin_name', 'Administrator', width: 180, flex: 1),
      ColumnSpec(
        'resource_id',
        'Record',
        width: 260,
        flex: 2,
        read: (record) =>
            '${_text(record['resource_type'])} ${_text(record['resource_id'])}'
                .trim(),
      ),
      const ColumnSpec('created_at', 'When', kind: CellKind.date, width: 170),
    ],
    filters: const [
      FieldSpec('action', 'Action'),
      FieldSpec('admin_name', 'Administrator'),
      FieldSpec('resource_type', 'Record type'),
    ],
    groups: const [
      FieldSpec('action', 'Action'),
      FieldSpec('admin_name', 'Administrator'),
      FieldSpec('resource_type', 'Record type'),
    ],
  ),
};

// ───────────────────────────────────────────────────────────────────────────
// Turning values into text
// ───────────────────────────────────────────────────────────────────────────

/// A cell's value as the text shown in the table (and matched by search).
String cellText(ColumnSpec column, Map<String, Object?> record) {
  final value = column.value(record);
  if (value == null) return '';
  return switch (column.kind) {
    CellKind.money => moneyOf(value),
    CellKind.signedMoney => value is num
        ? '${value < 0 ? '−' : '+'}${moneyOf(value.abs())}'
        : '',
    CellKind.date => formatDateTime(value),
    CellKind.flag => value == true ? 'Yes' : 'No',
    CellKind.status || CellKind.tag => readableStatus('$value'),
    CellKind.number => value is num ? NumberFormat.decimalPattern().format(value) : '$value',
    CellKind.text || CellKind.code => '$value',
  };
}

/// A cell's value for a spreadsheet: plain numbers for money, sortable
/// dates, no symbols.
String cellExport(ColumnSpec column, Map<String, Object?> record) {
  final value = column.value(record);
  if (value == null) return '';
  switch (column.kind) {
    case CellKind.money:
    case CellKind.signedMoney:
      return value is num ? (value / 100).toStringAsFixed(2) : '';
    case CellKind.date:
      final date = parseDate(value);
      return date == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(date);
    case CellKind.flag:
      return value == true ? 'Yes' : 'No';
    case CellKind.number:
    case CellKind.status:
    case CellKind.tag:
    case CellKind.text:
    case CellKind.code:
      return '$value';
  }
}

/// What a column sorts by: numbers as numbers, dates as moments, everything
/// else as lower-case text. Null sorts first.
Comparable<Object>? cellSortKey(ColumnSpec column, Map<String, Object?> record) {
  final value = column.value(record);
  if (value == null) return null;
  switch (column.kind) {
    case CellKind.money:
    case CellKind.signedMoney:
    case CellKind.number:
      return value is num ? value : num.tryParse('$value');
    case CellKind.date:
      return parseDate(value)?.millisecondsSinceEpoch;
    case CellKind.flag:
      return value == true ? 1 : 0;
    case CellKind.status:
    case CellKind.tag:
    case CellKind.text:
    case CellKind.code:
      return '$value'.toLowerCase();
  }
}

/// Orders two sort keys of the same column. A missing value comes before
/// any present one.
int compareSortKeys(Comparable<Object>? a, Comparable<Object>? b) {
  if (a == null && b == null) return 0;
  if (a == null) return -1;
  if (b == null) return 1;
  if (a is num && b is num) return a.compareTo(b);
  return '$a'.compareTo('$b');
}

/// Writes rows as CSV. Values containing a comma, a quote or a line break
/// are quoted, and a value a spreadsheet could mistake for a formula is
/// made plain text.
String toCsv(List<String> header, Iterable<List<String>> rows) {
  String cell(String value) {
    var text = value;
    if (text.isNotEmpty && '=+-@\t\r'.contains(text[0]) && num.tryParse(text) == null) {
      text = "'$text";
    }
    return RegExp('[",\n\r]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  final buffer = StringBuffer()..writeln(header.map(cell).join(','));
  for (final row in rows) {
    buffer.writeln(row.map(cell).join(','));
  }
  return buffer.toString();
}

/// A field name as a label: "provider_status" → "Provider status".
String labelForKey(String key) {
  var text = key.replaceAll('_', ' ').trim();
  if (text.endsWith(' cents')) text = text.substring(0, text.length - 6);
  if (text.endsWith(' at')) text = text.substring(0, text.length - 3);
  if (text.isEmpty) return key;
  return text[0].toUpperCase() + text.substring(1);
}
