import 'package:flutter/material.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/features/admin/presentation/resource_views.dart';

/// One value of a record, drawn the way its column asks: a pill for a
/// status, a tick for a flag, coloured money, and so on. Used by both the
/// table and the detail panel.
class CellView extends StatelessWidget {
  const CellView({
    required this.column,
    required this.record,
    super.key,
    this.showSecondary = true,
    this.wrap = false,
  });

  final ColumnSpec column;
  final Map<String, Object?> record;

  /// Whether to show the quieter second line (left out in compact tables).
  final bool showSecondary;

  /// Lets long text run onto more lines (the detail panel) instead of being
  /// cut short with an ellipsis (the table).
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final value = column.value(record);
    final text = cellText(column, record);
    const empty = '—';

    Widget plain(String content, {TextStyle? style}) => Text(
          content.isEmpty ? empty : content,
          maxLines: wrap ? null : 1,
          overflow: wrap ? null : TextOverflow.ellipsis,
          softWrap: wrap,
          style: content.isEmpty
              ? TextStyle(color: palette.muted)
              : style,
        );

    switch (column.kind) {
      case CellKind.status:
        if (text.isEmpty) return plain('');
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusPill('$value'),
        );
      case CellKind.tag:
        if (text.isEmpty) return plain('');
        return Align(
          alignment: Alignment.centerLeft,
          child: StatusPill('$value', tone: Tone.neutral, dot: false),
        );
      case CellKind.flag:
        final on = value == true;
        return Align(
          alignment: Alignment.centerLeft,
          child: Icon(
            on ? Icons.check_circle_rounded : Icons.remove_rounded,
            size: 18,
            color: on ? toneColor(context, Tone.success) : palette.muted,
          ),
        );
      case CellKind.money:
        return plain(
          text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );
      case CellKind.signedMoney:
        final negative = value is num && value < 0;
        return plain(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: toneColor(context, negative ? Tone.danger : Tone.success),
          ),
        );
      case CellKind.number:
        return plain(text);
      case CellKind.date:
        return plain(text, style: TextStyle(color: palette.muted));
      case CellKind.code:
        return plain(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            fontWeight: column.primary ? FontWeight.w600 : FontWeight.w400,
          ),
        );
      case CellKind.text:
        final secondary = showSecondary ? column.secondary?.call(record) : null;
        final main = plain(
          text,
          style: column.primary
              ? const TextStyle(fontWeight: FontWeight.w600)
              : null,
        );
        if (secondary == null || secondary.isEmpty) return main;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            main,
            const SizedBox(height: 1),
            Text(
              secondary,
              maxLines: wrap ? null : 1,
              overflow: wrap ? null : TextOverflow.ellipsis,
              softWrap: wrap,
              style: TextStyle(color: palette.muted, fontSize: 12.5),
            ),
          ],
        );
    }
  }
}
