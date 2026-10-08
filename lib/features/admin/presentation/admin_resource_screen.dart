import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/export/save_file.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/core/ui/ui_prefs.dart';
import 'package:fplboardman_admin/features/admin/data/admin_repository.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_resources.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/record_panel.dart';
import 'package:fplboardman_admin/features/admin/presentation/resource_cells.dart';
import 'package:fplboardman_admin/features/admin/presentation/resource_views.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The list page for one kind of record.
///
/// A table that can be searched, filtered, grouped, sorted and exported.
/// Clicking a row slides its details in from the right, with a button for
/// everything that can be done to it.
class AdminResourceScreen extends ConsumerStatefulWidget {
  const AdminResourceScreen({required this.resource, super.key});
  final String resource;

  @override
  ConsumerState<AdminResourceScreen> createState() =>
      _AdminResourceScreenState();
}

/// How many rows of a group are shown before "Show more".
const _groupChunk = 25;

/// Groups beyond this many are not listed; the page says to narrow down.
const _maxGroups = 200;

class _AdminResourceScreenState extends ConsumerState<AdminResourceScreen> {
  final _search = TextEditingController();
  final _horizontal = ScrollController();

  String _query = '';

  /// Chosen values per filter field. A record must match one value of every
  /// field that has any chosen.
  final Map<String, Set<String>> _filters = {};
  String? _groupKey;

  /// How many rows of each group are showing. Zero is collapsed; a group
  /// not in the map follows the default (open when there are few groups).
  final Map<String, int> _groupRows = {};
  String? _sortKey;
  bool _ascending = true;
  int _page = 0;
  int _pageSize = 25;
  late final Set<String> _hidden;

  /// The searchable text of each record, worked out once per record.
  final _haystacks = Expando<String>();

  ResourceView get _view =>
      resourceViews[widget.resource] ?? const ResourceView(columns: []);

  @override
  void initState() {
    super.initState();
    _hidden = {
      for (final column in _view.columns)
        if (column.hidden) column.key,
    };
  }

  @override
  void dispose() {
    _search.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  // ── Working the rows out ────────────────────────────────────────────────

  String _haystack(Map<String, Object?> record) =>
      _haystacks[record] ??= [
        for (final column in _view.columns) ...[
          cellText(column, record),
          column.secondary?.call(record) ?? '',
        ],
        recordId(record),
        '${record['email'] ?? ''}',
        '${record['reference'] ?? ''}',
      ].join(' ').toLowerCase();

  List<Map<String, Object?>> _apply(List<Map<String, Object?>> items) {
    final view = _view;
    final words = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final active = [
      for (final field in view.filters)
        if (_filters[field.key]?.isNotEmpty ?? false) field,
    ];

    var rows = items.where((record) {
      for (final field in active) {
        if (!_filters[field.key]!.contains(field.text(record))) return false;
      }
      if (words.isEmpty) return true;
      final haystack = _haystack(record);
      return words.every(haystack.contains);
    }).toList();

    final sortKey = _sortKey;
    if (sortKey != null) {
      final column = view.columns.where((c) => c.key == sortKey).firstOrNull;
      if (column != null) {
        final keyed = [
          for (final record in rows)
            (key: cellSortKey(column, record), record: record),
        ];
        keyed.sort(
          (a, b) => _ascending
              ? compareSortKeys(a.key, b.key)
              : compareSortKeys(b.key, a.key),
        );
        rows = [for (final item in keyed) item.record];
      }
    }
    return rows;
  }

  /// The values a filter offers, with how many records have each.
  List<MapEntry<String, int>> _options(
    FieldSpec field,
    List<Map<String, Object?>> items,
  ) {
    final counts = <String, int>{};
    for (final record in items) {
      final text = field.text(record);
      counts[text] = (counts[text] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(60).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return top;
  }

  // ── Changing the view ───────────────────────────────────────────────────

  void _toggleFilter(String field, String value) => setState(() {
        final chosen = _filters.putIfAbsent(field, () => <String>{});
        if (!chosen.remove(value)) chosen.add(value);
        _page = 0;
      });

  void _clearFilters() => setState(() {
        _filters.clear();
        _search.clear();
        _query = '';
        _page = 0;
      });

  void _sortBy(ColumnSpec column) => setState(() {
        if (_sortKey != column.key) {
          _sortKey = column.key;
          // Numbers and dates are usually wanted biggest or newest first.
          _ascending = !(column.numeric || column.kind == CellKind.date);
        } else if (_ascending == !(column.numeric || column.kind == CellKind.date)) {
          _ascending = !_ascending;
        } else {
          // Third click: back to the order the server sent.
          _sortKey = null;
        }
        _page = 0;
      });

  void _toggleColumn(String key, int visibleCount) {
    if (!_hidden.contains(key) && visibleCount <= 1) {
      AppNotice.info(context, 'At least one column has to stay.');
      return;
    }
    setState(() {
      if (!_hidden.remove(key)) _hidden.add(key);
    });
  }

  void _refresh() => ref.invalidate(adminCollectionProvider(widget.resource));

  // ── Export ──────────────────────────────────────────────────────────────

  Future<void> _export(
    List<Map<String, Object?>> rows,
    List<ColumnSpec> columns, {
    required bool download,
  }) async {
    if (rows.isEmpty) {
      AppNotice.info(context, 'There is nothing to export.');
      return;
    }
    final header = <String>[
      for (final column in columns) ...[
        column.label,
        if (column.secondary != null) '${column.label} (detail)',
      ],
      'ID',
    ];
    final csv = toCsv(
      header,
      rows.map(
        (record) => [
          for (final column in columns) ...[
            cellExport(column, record),
            if (column.secondary != null) column.secondary!(record),
          ],
          recordId(record),
        ],
      ),
    );
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final filename = 'fplboardman-${widget.resource}-$stamp.csv';
    final count = '${rows.length} ${rows.length == 1 ? 'row' : 'rows'}';

    // The leading mark tells Excel the file is UTF-8, so "₦" and accented
    // names survive.
    if (download && saveTextFile(filename: filename, content: '\uFEFF$csv')) {
      AppNotice.success(context, '$count saved as $filename.');
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    AppNotice.info(
      context,
      download
          ? 'Files can only be saved from the web version. $count copied '
              'as CSV instead: paste them into a spreadsheet.'
          : '$count copied as CSV. Paste them into a spreadsheet.',
    );
  }

  // ── Opening a record ────────────────────────────────────────────────────

  Future<void> _open(Map<String, Object?> record) async {
    final resource = widget.resource;
    if (resource == 'users') {
      final id = record['id'];
      if (id != null) await context.push('/users/$id');
      return;
    }
    final action = await showRecordPanel(
      context,
      resource: resource,
      record: record,
    );
    if (action == null || !mounted) return;
    if (action == openUserAction) {
      await context.push('/users/${record['user_id']}');
      return;
    }
    await performRecordAction(context, ref, resource, record, action);
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resource = widget.resource;
    final definition = adminResources[resource];
    if (definition == null) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'Unknown section',
        message: 'Choose a section from the menu.',
        action: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Go to the dashboard'),
        ),
      );
    }
    final value = ref.watch(adminCollectionProvider(resource));
    final busy = ref.watch(adminActionProvider).isLoading;
    final compact = ref.watch(uiPrefsProvider).compact;
    final view = _view;
    final items = value.orNull;
    final rows = items == null ? null : _apply(items);
    final visible = [
      for (final column in view.columns)
        if (!_hidden.contains(column.key)) column,
    ];
    final createLabel = definition.createLabel;
    final note = definition.note;

    return PageBody(
      onRefresh: () async {
        _refresh();
        await ref.read(adminCollectionProvider(resource).future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: definition.label,
            subtitle: definition.description,
            actions: [
              Tooltip(
                message: 'Reload from the server',
                child: OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Export what is listed',
                position: PopupMenuPosition.under,
                enabled: rows != null,
                onSelected: (choice) => _export(
                  rows ?? const [],
                  visible,
                  download: choice == 'download',
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'download',
                    child: _MenuRow(
                      icon: Icons.download_rounded,
                      text: 'Download CSV',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'copy',
                    child: _MenuRow(
                      icon: Icons.copy_rounded,
                      text: 'Copy as CSV',
                    ),
                  ),
                ],
                child: const _ButtonFace(
                  icon: Icons.ios_share_rounded,
                  label: 'Export',
                ),
              ),
              if (createLabel != null)
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => createRecord(context, ref, resource),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(createLabel),
                ),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 14),
          NoticeBar(text: note, tone: Tone.neutral),
        ],
        if (items != null && items.length >= AdminRepository.maxRows) ...[
          const SizedBox(height: 10),
          NoticeBar(
            text: 'Showing the newest ${AdminRepository.maxRows} records. '
                'Older ones are not loaded here.',
            tone: Tone.warning,
          ),
        ],
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _toolbar(context, view, items ?? const [], rows, visible),
                  if (value.isLoading && items != null)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    Divider(color: Palette.of(context).border, height: 1),
                  AnimatedSize(
                    duration: AppMotion.standard,
                    curve: AppMotion.curve,
                    alignment: Alignment.topCenter,
                    child: _content(
                      context,
                      value,
                      definition,
                      items,
                      rows,
                      visible,
                      compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    AsyncValue<List<Map<String, Object?>>> value,
    AdminResourceDefinition definition,
    List<Map<String, Object?>>? items,
    List<Map<String, Object?>>? rows,
    List<ColumnSpec> visible,
    bool compact,
  ) {
    if (items == null || rows == null) {
      if (value.hasError) {
        return EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load ${definition.label.toLowerCase()}',
          message: '${value.error}',
          action: FilledButton.tonal(
            onPressed: _refresh,
            child: const Text('Try again'),
          ),
        );
      }
      return const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: definition.icon,
        title: 'Nothing here yet',
        message: 'Records appear here as they are created.',
      );
    }
    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing matches',
        message: 'No record fits the search and filters you have set.',
        action: OutlinedButton(
          onPressed: _clearFilters,
          child: const Text('Clear search and filters'),
        ),
      );
    }

    final groupKey = _groupKey;
    final field = groupKey == null
        ? null
        : _view.groups.where((g) => g.key == groupKey).firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        const chevron = 40.0;
        final widths = _widths(visible, constraints.maxWidth - chevron);
        final total = widths.fold<double>(chevron, (sum, w) => sum + w);
        final body = field == null
            ? _plainRows(context, rows, visible, widths, compact)
            : _groupedRows(context, rows, field, visible, widths, compact);
        final table = SizedBox(
          width: total,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderRow(
                columns: visible,
                widths: widths,
                sortKey: _sortKey,
                ascending: _ascending,
                onSort: _sortBy,
              ),
              ...body,
            ],
          ),
        );
        final scrolls = total > constraints.maxWidth + 0.01;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scrolls)
              Scrollbar(
                controller: _horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: table,
                ),
              )
            else
              table,
            if (field == null) _pager(context, rows.length),
          ],
        );
      },
    );
  }

  /// Every column gets its minimum; what is left over is shared out by flex.
  List<double> _widths(List<ColumnSpec> columns, double available) {
    final minimum = columns.fold<double>(0, (sum, c) => sum + c.width);
    final extra = math.max(0.0, available - minimum);
    final flex = columns.fold<int>(0, (sum, c) => sum + c.flex);
    return [
      for (final column in columns)
        column.width +
            (flex == 0
                ? extra / math.max(1, columns.length)
                : extra * column.flex / flex),
    ];
  }

  List<Widget> _plainRows(
    BuildContext context,
    List<Map<String, Object?>> rows,
    List<ColumnSpec> visible,
    List<double> widths,
    bool compact,
  ) {
    final pages = math.max(1, (rows.length / _pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final start = page * _pageSize;
    final end = math.min(rows.length, start + _pageSize);
    return [
      for (var i = start; i < end; i++)
        _DataRow(
          key: ObjectKey(rows[i]),
          record: rows[i],
          columns: visible,
          widths: widths,
          compact: compact,
          last: i == end - 1,
          onTap: () => _open(rows[i]),
        ),
    ];
  }

  List<Widget> _groupedRows(
    BuildContext context,
    List<Map<String, Object?>> rows,
    FieldSpec field,
    List<ColumnSpec> visible,
    List<double> widths,
    bool compact,
  ) {
    final groups = <String, List<Map<String, Object?>>>{};
    for (final record in rows) {
      (groups[field.text(record)] ??= []).add(record);
    }
    final names = groups.keys.toList()..sort();
    final openByDefault = names.length <= 8;
    // A money column to total up in each group's heading, if there is one.
    final sumColumn = visible
        .where((c) => c.kind == CellKind.money || c.kind == CellKind.signedMoney)
        .firstOrNull;
    final palette = Palette.of(context);

    final widgets = <Widget>[];
    for (final name in names.take(_maxGroups)) {
      final members = groups[name]!;
      final showing = math.min(
        members.length,
        _groupRows[name] ?? (openByDefault ? _groupChunk : 0),
      );
      var sum = 0.0;
      if (sumColumn != null) {
        for (final record in members) {
          final value = sumColumn.value(record);
          if (value is num) sum += value;
        }
      }
      widgets.add(
        _GroupHeader(
          label: '${field.label}: $name',
          count: members.length,
          total: sumColumn == null
              ? null
              : '${sumColumn.label} ${money(sum.round())}',
          open: showing > 0,
          onTap: () => setState(
            () => _groupRows[name] = showing > 0 ? 0 : _groupChunk,
          ),
        ),
      );
      for (var i = 0; i < showing; i++) {
        widgets.add(
          _DataRow(
            key: ObjectKey(members[i]),
            record: members[i],
            columns: visible,
            widths: widths,
            compact: compact,
            last: false,
            onTap: () => _open(members[i]),
          ),
        );
      }
      if (showing > 0 && showing < members.length) {
        final remaining = members.length - showing;
        widgets.add(
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: TextButton(
              onPressed: () => setState(
                () => _groupRows[name] = showing + _groupChunk,
              ),
              child: Text(
                'Show ${math.min(remaining, _groupChunk)} more of $remaining',
              ),
            ),
          ),
        );
      }
    }
    if (names.length > _maxGroups) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Showing the first $_maxGroups of ${names.length} groups. '
            'Search or filter to narrow the list down.',
            style: TextStyle(color: palette.muted),
          ),
        ),
      );
    }
    return widgets;
  }

  // ── Toolbar ─────────────────────────────────────────────────────────────

  Widget _toolbar(
    BuildContext context,
    ResourceView view,
    List<Map<String, Object?>> items,
    List<Map<String, Object?>>? rows,
    List<ColumnSpec> visible,
  ) {
    final palette = Palette.of(context);
    final groupKey = _groupKey;
    final grouped =
        view.groups.where((g) => g.key == groupKey).firstOrNull;
    final chosen = [
      for (final field in view.filters)
        for (final value in _filters[field.key] ?? const <String>{})
          (field: field, value: value),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ${adminResources[widget.resource]?.label.toLowerCase() ?? ''}',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19),
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    fillColor: palette.subtle,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close_rounded, size: 17),
                            onPressed: () => setState(() {
                              _search.clear();
                              _query = '';
                              _page = 0;
                            }),
                          ),
                  ),
                  onChanged: (text) => setState(() {
                    _query = text.trim();
                    _page = 0;
                  }),
                ),
              ),
              for (final field in view.filters)
                PopupMenuButton<String>(
                  tooltip: 'Filter by ${field.label.toLowerCase()}',
                  position: PopupMenuPosition.under,
                  onSelected: (value) => _toggleFilter(field.key, value),
                  itemBuilder: (context) => [
                    for (final option in _options(field, items))
                      CheckedPopupMenuItem<String>(
                        value: option.key,
                        checked:
                            _filters[field.key]?.contains(option.key) ?? false,
                        child: Text('${option.key}  ·  ${option.value}'),
                      ),
                  ],
                  child: _ButtonFace(
                    icon: Icons.filter_list_rounded,
                    label: field.label,
                    count: _filters[field.key]?.length ?? 0,
                  ),
                ),
              if (view.groups.isNotEmpty)
                PopupMenuButton<String>(
                  tooltip: 'Group the list',
                  position: PopupMenuPosition.under,
                  onSelected: (key) => setState(() {
                    _groupKey = key.isEmpty ? null : key;
                    _groupRows.clear();
                    _page = 0;
                  }),
                  itemBuilder: (context) => [
                    CheckedPopupMenuItem<String>(
                      value: '',
                      checked: groupKey == null,
                      child: const Text('No grouping'),
                    ),
                    for (final field in view.groups)
                      CheckedPopupMenuItem<String>(
                        value: field.key,
                        checked: groupKey == field.key,
                        child: Text(field.label),
                      ),
                  ],
                  child: _ButtonFace(
                    icon: Icons.account_tree_outlined,
                    label: grouped == null
                        ? 'Group by'
                        : 'Grouped by ${grouped.label.toLowerCase()}',
                    active: grouped != null,
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Choose columns',
                position: PopupMenuPosition.under,
                onSelected: (key) => _toggleColumn(key, visible.length),
                itemBuilder: (context) => [
                  for (final column in view.columns)
                    CheckedPopupMenuItem<String>(
                      value: column.key,
                      checked: !_hidden.contains(column.key),
                      child: Text(column.label),
                    ),
                ],
                child: const _ButtonFace(
                  icon: Icons.view_column_outlined,
                  label: 'Columns',
                ),
              ),
              if (rows != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    rows.length == items.length
                        ? '${items.length} ${items.length == 1 ? 'record' : 'records'}'
                        : '${rows.length} of ${items.length}',
                    style: TextStyle(color: palette.muted, fontSize: 13),
                  ),
                ),
            ],
          ),
          AnimatedSize(
            duration: AppMotion.quick,
            curve: AppMotion.curve,
            alignment: Alignment.topLeft,
            child: chosen.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final item in chosen)
                          _FilterChip(
                            label: '${item.field.label}: ${item.value}',
                            onRemove: () =>
                                _toggleFilter(item.field.key, item.value),
                          ),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Pager ───────────────────────────────────────────────────────────────

  Widget _pager(BuildContext context, int count) {
    final palette = Palette.of(context);
    final pages = math.max(1, (count / _pageSize).ceil());
    final page = math.min(_page, pages - 1);
    final first = count == 0 ? 0 : page * _pageSize + 1;
    final last = math.min(count, (page + 1) * _pageSize);
    void go(int to) => setState(() => _page = to);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rows per page',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<int>(
                tooltip: 'Rows per page',
                onSelected: (size) => setState(() {
                  _pageSize = size;
                  _page = 0;
                }),
                itemBuilder: (context) => [
                  for (final size in const [10, 25, 50, 100])
                    CheckedPopupMenuItem<int>(
                      value: size,
                      checked: size == _pageSize,
                      child: Text('$size'),
                    ),
                ],
                child: _ButtonFace(label: '$_pageSize', dense: true),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$first–$last of $count',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'First page',
                onPressed: page > 0 ? () => go(0) : null,
                icon: const Icon(Icons.first_page_rounded),
              ),
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0 ? () => go(page - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${page + 1} / $pages',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: page < pages - 1 ? () => go(page + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              IconButton(
                tooltip: 'Last page',
                onPressed: page < pages - 1 ? () => go(pages - 1) : null,
                icon: const Icon(Icons.last_page_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Pieces of the table
// ───────────────────────────────────────────────────────────────────────────

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.columns,
    required this.widths,
    required this.sortKey,
    required this.ascending,
    required this.onSort,
  });

  final List<ColumnSpec> columns;
  final List<double> widths;
  final String? sortKey;
  final bool ascending;
  final void Function(ColumnSpec column) onSort;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: palette.subtle,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++)
            SizedBox(
              width: widths[i],
              child: _HeaderCell(
                column: columns[i],
                sorted: sortKey == columns[i].key,
                ascending: ascending,
                first: i == 0,
                onTap: () => onSort(columns[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.sorted,
    required this.ascending,
    required this.first,
    required this.onTap,
  });

  final ColumnSpec column;
  final bool sorted;
  final bool ascending;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final color = sorted ? palette.text : palette.muted;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: 'Sort by ${column.label.toLowerCase()}',
          waitDuration: const Duration(milliseconds: 800),
          child: Padding(
            padding: EdgeInsets.only(left: first ? 18 : 10, right: 10),
            child: Row(
              mainAxisAlignment: column.numeric
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    column.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                AnimatedOpacity(
                  duration: AppMotion.quick,
                  opacity: sorted ? 1 : 0,
                  child: AnimatedRotation(
                    duration: AppMotion.quick,
                    turns: ascending ? 0 : 0.5,
                    child: Icon(Icons.arrow_upward_rounded, size: 14, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.record,
    required this.columns,
    required this.widths,
    required this.compact,
    required this.last,
    required this.onTap,
    super.key,
  });

  final Map<String, Object?> record;
  final List<ColumnSpec> columns;
  final List<double> widths;
  final bool compact;

  /// The last row of a page has no line under it.
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.hover,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 40 : 56),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: [
              for (var i = 0; i < columns.length; i++)
                SizedBox(
                  width: widths[i],
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      i == 0 ? 18 : 10,
                      compact ? 6 : 9,
                      10,
                      compact ? 6 : 9,
                    ),
                    child: Align(
                      alignment: columns[i].numeric
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: CellView(
                        column: columns[i],
                        record: record,
                        showSecondary: !compact,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 40,
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: palette.muted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.label,
    required this.count,
    required this.total,
    required this.open,
    required this.onTap,
  });

  final String label;
  final int count;

  /// A sum to show at the right, e.g. "Amount ₦120,000.00"; null for none.
  final String? total;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final total = this.total;
    return Material(
      color: palette.subtle.withValues(alpha: 0.6),
      child: InkWell(
        onTap: onTap,
        hoverColor: palette.hover,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: palette.border)),
          ),
          child: Row(
            children: [
              AnimatedRotation(
                duration: AppMotion.quick,
                turns: open ? 0.25 : 0,
                child: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (total != null) ...[
                const SizedBox(width: 14),
                Text(
                  total,
                  style: TextStyle(color: palette.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Pieces of the toolbar
// ───────────────────────────────────────────────────────────────────────────

/// The look of a toolbar button that opens a menu. (The menu button itself
/// supplies the click.)
class _ButtonFace extends StatelessWidget {
  const _ButtonFace({
    required this.label,
    this.icon,
    this.count = 0,
    this.active = false,
    this.dense = false,
  });

  final String label;
  final IconData? icon;

  /// How many values are chosen, shown in a small badge.
  final int count;
  final bool active;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final on = active || count > 0;
    final color = on ? palette.accent : palette.text;
    final icon = this.icon;
    return Container(
      height: dense ? 32 : 42,
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
      decoration: BoxDecoration(
        color: on ? palette.accent.withValues(alpha: 0.08) : palette.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: on ? palette.accent.withValues(alpha: 0.5) : palette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: on ? palette.accent : palette.muted),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(width: 4),
          Icon(Icons.expand_more_rounded, size: 17, color: palette.muted),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Text(text),
        ],
      );
}

/// One chosen filter value, with a cross to drop it.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 14, color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
