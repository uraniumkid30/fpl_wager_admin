import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_resources.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/resource_cells.dart';
import 'package:fplboardman_admin/features/admin/presentation/resource_views.dart';

/// What [showRecordPanel] returns when the administrator asks to open the
/// account of the user a record belongs to.
const openUserAction = '__open_user';

/// Slides a record's details in from the right: its fields laid out to be
/// read, the raw data for when that is needed, and a button for everything
/// that can be done to it.
///
/// Returns the key of the action that was pressed (see [actionsFor]),
/// [openUserAction], or null if the panel was simply closed.
Future<String?> showRecordPanel(
  BuildContext context, {
  required String resource,
  required Map<String, Object?> record,
}) =>
    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: AppMotion.standard,
      pageBuilder: (context, _, _) =>
          _RecordPanel(resource: resource, record: record),
      transitionBuilder: (context, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppMotion.curve)),
        child: child,
      ),
    );

/// The identifier worth copying for a record: its id, or what stands in for
/// one.
String recordId(Map<String, Object?> record) =>
    firstValue(record, const ['id', 'user_id', 'key', 'number']);

class _RecordPanel extends StatelessWidget {
  const _RecordPanel({required this.resource, required this.record});

  final String resource;
  final Map<String, Object?> record;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final definition = adminResources[resource];
    final view = resourceViews[resource];
    final columns = view?.columns ?? const <ColumnSpec>[];
    final actions = actionsFor(resource, record);
    final status = firstValue(record, const ['status', 'outcome']);
    final id = recordId(record);
    final userId = record['user_id'];
    final screen = MediaQuery.sizeOf(context);
    final width = math.min(520.0, screen.width);

    // Everything the columns do not already show.
    final shown = {for (final column in columns) column.key};
    final others = record.entries
        .where((entry) => !shown.contains(entry.key) && _worthShowing(entry.value))
        .toList();

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: palette.card,
        elevation: 18,
        shadowColor: Colors.black54,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 10, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(
                          definition?.icon ?? Icons.description_outlined,
                          color: palette.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              definition?.label ?? 'Record',
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              recordTitle(resource, record),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (status.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              StatusPill(status),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(color: palette.border, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (id.isNotEmpty)
                        _CopyRow(label: 'ID', value: id),
                      for (final column in columns)
                        _FieldRow(
                          label: column.label,
                          child: CellView(
                            column: column,
                            record: record,
                            wrap: true,
                          ),
                        ),
                      if (others.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          'More',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        for (final entry in others)
                          _AnyField(name: entry.key, value: entry.value),
                      ],
                      const SizedBox(height: 18),
                      _RawData(record: record),
                    ],
                  ),
                ),
                if (actions.isNotEmpty ||
                    (userId is String && resource != 'users')) ...[
                  Divider(color: palette.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final action in actions)
                          _ActionButton(action: action),
                        if (userId is String && resource != 'users')
                          TextButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(openUserAction),
                            icon: const Icon(Icons.person_outline_rounded, size: 18),
                            label: const Text('Open user account'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty values and bulky nested data are left to the raw view.
bool _worthShowing(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Map) return value.isNotEmpty && _isFlat(value);
  if (value is List) return false;
  return true;
}

/// A small map of plain values, such as a bank account.
bool _isFlat(Map<Object?, Object?> map) =>
    map.length <= 10 &&
    map.values.every((value) => value is! Map && value is! List);

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});
  final RecordAction action;

  @override
  Widget build(BuildContext context) {
    void press() => Navigator.of(context).pop(action.key);
    final icon = Icon(action.icon, size: 18);
    final label = Text(action.label);
    if (action.primary) {
      return FilledButton.icon(onPressed: press, icon: icon, label: label);
    }
    if (action.destructive) {
      final error = Theme.of(context).colorScheme.error;
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: error,
          side: BorderSide(color: error.withValues(alpha: 0.45)),
        ),
        onPressed: press,
        icon: icon,
        label: label,
      );
    }
    return OutlinedButton.icon(onPressed: press, icon: icon, label: label);
  }
}

/// A label on the left and its value on the right, with a hairline under.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 12),
              child: Text(
                label,
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A value that can be copied with one click.
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => _FieldRow(
        label: label,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (context.mounted) AppNotice.info(context, '$label copied.');
              },
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Tooltip(
                  message: 'Copy',
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: Palette.of(context).muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

/// A field with no column of its own, shown by what its name and value
/// suggest: money for "..._cents", a date for "..._at", and so on.
class _AnyField extends StatelessWidget {
  const _AnyField({required this.name, required this.value});
  final String name;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final value = this.value;
    if (value is Map) {
      return _FieldRow(
        label: labelForKey(name),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in value.entries)
              if (entry.value != null && '${entry.value}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${labelForKey('${entry.key}')}: ',
                          style: TextStyle(color: palette.muted),
                        ),
                        TextSpan(text: _plain('${entry.key}', entry.value)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );
    }
    return _FieldRow(
      label: labelForKey(name),
      child: SelectableText(_plain(name, value)),
    );
  }

  static String _plain(String key, Object? value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num && key.endsWith('_cents')) return moneyOf(value);
    if (value is String && (key.endsWith('_at') || key == 'deadline')) {
      final formatted = formatDateTime(value);
      if (formatted.isNotEmpty) return formatted;
    }
    return '$value';
  }
}

/// The record exactly as the server sent it, folded away until asked for.
class _RawData extends StatefulWidget {
  const _RawData({required this.record});
  final Map<String, Object?> record;

  @override
  State<_RawData> createState() => _RawDataState();
}

class _RawDataState extends State<_RawData> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final json = prettyJson(widget.record);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _open = !_open),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _open ? 0.25 : 0,
                        duration: AppMotion.quick,
                        child: const Icon(Icons.chevron_right_rounded, size: 20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Raw data',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: json));
                if (context.mounted) AppNotice.info(context, 'Copied as JSON.');
              },
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copy'),
            ),
          ],
        ),
        AnimatedSize(
          duration: AppMotion.standard,
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.subtle,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.border),
                  ),
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
