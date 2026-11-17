import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_actions.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';
import 'package:intl/intl.dart';

/// Marketing campaigns: banners at the top of Home and Pools in the app,
/// each with its own page (the Royal Rumble first). Live campaigns show at
/// once on every open app; drafts only here.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(adminCampaignsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;
    final items = value.value;

    return PageBody(
      maxWidth: 1100,
      onRefresh: () async {
        ref.invalidate(adminCampaignsProvider);
        await ref.read(adminCampaignsProvider.future);
      },
      children: [
        FadeSlideIn(
          child: PageHeader(
            title: 'Campaigns',
            subtitle: 'Banners at the top of Home and Pools in the app, each '
                'with its own page. Use them for the Royal Rumble and every '
                'marketing drive after it.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(adminCampaignsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => _edit(context, ref, null),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New campaign'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (items == null)
          AppCard(
            padding: const EdgeInsets.all(22),
            child: SizedBox(
              height: 140,
              child: Center(
                child: value.hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${value.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          FilledButton.tonal(
                            onPressed: () =>
                                ref.invalidate(adminCampaignsProvider),
                            child: const Text('Try again'),
                          ),
                        ],
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
          )
        else if (items.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Icon(Icons.campaign_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  'No campaigns yet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                const Text('Create one and set it live when it is ready.'),
              ],
            ),
          )
        else
          for (final (index, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeSlideIn(
                delay: Duration(milliseconds: 40 + index * 30),
                child: _CampaignRow(
                  campaign: item,
                  busy: busy,
                  onEdit: () => _edit(context, ref, item),
                  onStatus: (status) => _setStatus(context, ref, item, status),
                  onDelete: () => _delete(context, ref, item),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?>? campaign,
  ) async {
    final values = await showDialog<Map<String, Object?>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CampaignEditor(campaign: campaign),
    );
    if (values == null || !context.mounted) return;
    final id = campaign?['id'] as String?;
    await runAdminAction(
      context,
      ref,
      action: (repository) => id == null
          ? repository.createCampaign(values)
          : repository.updateCampaign(id, values),
      refresh: const ['audit-logs'],
      success: id == null
          ? '${values['title']} was created.'
          : '${values['title']} was saved.',
    );
    if (context.mounted) ref.invalidate(adminCampaignsProvider);
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> campaign,
    String status,
  ) async {
    final title = campaign['title'] as String? ?? 'The campaign';
    await runAdminAction(
      context,
      ref,
      action: (repository) =>
          repository.updateCampaign(campaign['id']! as String, {'status': status}),
      refresh: const ['audit-logs'],
      success: switch (status) {
        'live' => '$title is live in the app.',
        'draft' => '$title is back to draft and no longer shows in the app.',
        _ => '$title was archived.',
      },
    );
    if (context.mounted) ref.invalidate(adminCampaignsProvider);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Map<String, Object?> campaign,
  ) async {
    final title = campaign['title'] as String? ?? 'this campaign';
    final confirmed = await confirmAdminAction(
      context,
      title: 'Delete $title?',
      message: 'It disappears from the app at once. This cannot be undone; '
          'archive it instead to keep it.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      action: (repository) =>
          repository.deleteCampaign(campaign['id']! as String),
      refresh: const ['audit-logs'],
      success: '$title was deleted.',
    );
    if (context.mounted) ref.invalidate(adminCampaignsProvider);
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({
    required this.campaign,
    required this.busy,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Map<String, Object?> campaign;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final status = campaign['status'] as String? ?? 'draft';
    final placements = [
      for (final item in (campaign['placements'] as List? ?? const [])) '$item',
    ];
    final window = _windowText(campaign);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final preview = SizedBox(
      width: wide ? 380 : double.infinity,
      child: CampaignPreview(values: campaign),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              campaign['title'] as String? ?? '',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            StatusPill(
              status,
              tone: switch (status) {
                'live' => Tone.success,
                'draft' => Tone.warning,
                _ => Tone.neutral,
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '/campaigns/${campaign['slug']} · shows on '
          '${placements.map((p) => p == 'home' ? 'Home' : 'Pools').join(' and ')}'
          ' · priority ${campaign['priority'] ?? 0}',
          style: TextStyle(color: palette.muted),
        ),
        if (window.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(window, style: TextStyle(color: palette.muted)),
        ],
        const SizedBox(height: 4),
        Text(
          _ctaText(campaign),
          style: TextStyle(color: palette.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            if (status != 'live')
              FilledButton.icon(
                onPressed: busy ? null : () => onStatus('live'),
                icon: const Icon(Icons.campaign_rounded, size: 18),
                label: const Text('Set live'),
              )
            else
              OutlinedButton.icon(
                onPressed: busy ? null : () => onStatus('draft'),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Take down'),
              ),
            if (status != 'archived')
              OutlinedButton.icon(
                onPressed: busy ? null : () => onStatus('archived'),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Archive'),
              ),
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ],
    );
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                preview,
                const SizedBox(width: 20),
                Expanded(child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [preview, const SizedBox(height: 16), details],
            ),
    );
  }
}

String _windowText(Map<String, Object?> campaign) {
  final starts = formatDateTime(campaign['starts_at']);
  final ends = formatDateTime(campaign['ends_at']);
  if (starts.isEmpty && ends.isEmpty) return '';
  if (starts.isEmpty) return 'Shows until $ends';
  if (ends.isEmpty) return 'Shows from $starts';
  return 'Shows from $starts to $ends';
}

String _ctaText(Map<String, Object?> campaign) {
  final label = campaign['cta_label'] as String? ?? '';
  final target = campaign['cta_target'] as String? ?? '';
  return switch (campaign['cta_kind']) {
    'pool' => 'Button "$label" opens pool $target',
    'route' => 'Button "$label" opens $target in the app',
    'url' => 'Button "$label" opens $target',
    _ => 'Button "$label" opens the campaign page',
  };
}

// ─────────────────────────────────────────────────────────────────────────
// The banner, as the app draws it
// ─────────────────────────────────────────────────────────────────────────

/// The colours of each banner theme. The app uses the same values
/// (src/features/campaigns/themes.ts); all are built from the brand palette.
const campaignThemes = <String, ({List<Color> colors, Color accent, String label})>{
  'rumble': (
    colors: [Color(0xFFE90052), Color(0xFF3D195B), Color(0xFF1A0B28)],
    accent: Color(0xFF00FF85),
    label: 'Rumble (pink and purple)',
  ),
  'pitch': (
    colors: [Color(0xFF00B862), Color(0xFF0F4B45), Color(0xFF1A0B28)],
    accent: Color(0xFF00FF85),
    label: 'Pitch (green)',
  ),
  'cyan': (
    colors: [Color(0xFF04C8D9), Color(0xFF2A3E8C), Color(0xFF1A0B28)],
    accent: Color(0xFF04F5FF),
    label: 'Captain (cyan)',
  ),
  'gold': (
    colors: [Color(0xFFF5A524), Color(0xFF8A2E3B), Color(0xFF1A0B28)],
    accent: Color(0xFFFFD36B),
    label: 'Trophy (gold)',
  ),
  'midnight': (
    colors: [Color(0xFF3D195B), Color(0xFF26123A), Color(0xFF1A0B28)],
    accent: Color(0xFF00FF85),
    label: 'Midnight (purple)',
  ),
};

class CampaignPreview extends StatelessWidget {
  const CampaignPreview({required this.values, super.key});

  final Map<String, Object?> values;

  @override
  Widget build(BuildContext context) {
    final theme = campaignThemes[values['theme']] ?? campaignThemes['rumble']!;
    final badge = (values['badge'] as String? ?? '').trim();
    final title = (values['title'] as String? ?? '').trim();
    final tagline = (values['tagline'] as String? ?? '').trim();
    final cta = (values['cta_label'] as String? ?? '').trim();
    final facts = [
      for (final item in (values['highlights'] as List? ?? const []))
        if (item is Map) item,
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.colors,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            title.isEmpty ? 'Campaign title' : title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          if (tagline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tagline,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82)),
            ),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final fact in facts)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${fact['label']}  ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                          TextSpan(
                            text: '${fact['value']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              cta.isEmpty ? 'See how it works' : cta,
              style: const TextStyle(
                color: Color(0xFF3D195B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Editor
// ─────────────────────────────────────────────────────────────────────────

class _CampaignEditor extends StatefulWidget {
  const _CampaignEditor({required this.campaign});

  /// The campaign to change, or null for a new one.
  final Map<String, Object?>? campaign;

  @override
  State<_CampaignEditor> createState() => _CampaignEditorState();
}

class _CampaignEditorState extends State<_CampaignEditor> {
  late final Map<String, Object?> _initial = widget.campaign ?? const {};
  late final _title = TextEditingController(text: _text('title'));
  late final _slug = TextEditingController(text: _text('slug'));
  late final _badge = TextEditingController(text: _text('badge'));
  late final _tagline = TextEditingController(text: _text('tagline'));
  late final _body = TextEditingController(text: _text('body'));
  late final _rules = TextEditingController(
    text: [for (final rule in (_initial['rules'] as List? ?? const [])) '$rule']
        .join('\n'),
  );
  late final _highlights = TextEditingController(
    text: [
      for (final fact in (_initial['highlights'] as List? ?? const []))
        if (fact is Map) '${fact['label']}: ${fact['value']}',
    ].join('\n'),
  );
  late final _ctaLabel =
      TextEditingController(text: _text('cta_label', 'See how it works'));
  late final _ctaTarget = TextEditingController(text: _text('cta_target'));
  late final _countdownLabel =
      TextEditingController(text: _text('countdown_label'));
  late final _priority =
      TextEditingController(text: '${_initial['priority'] ?? 0}');
  late String _theme = _text('theme', 'rumble');
  late String _ctaKind = _text('cta_kind', 'none');
  late String _status = _text('status', 'draft');
  late final Set<String> _placements = {
    for (final item in (_initial['placements'] as List? ?? const ['home', 'pools']))
      '$item',
  };
  late DateTime? _startsAt = parseDate(_initial['starts_at']);
  late DateTime? _endsAt = parseDate(_initial['ends_at']);
  late DateTime? _countdownTo = parseDate(_initial['countdown_to']);
  bool _slugTouched = false;
  String? _error;

  String _text(String key, [String fallback = '']) {
    final value = _initial[key];
    return value is String && value.isNotEmpty ? value : fallback;
  }

  @override
  void initState() {
    super.initState();
    _slugTouched = widget.campaign != null;
    _title.addListener(() {
      if (!_slugTouched) _slug.text = _slugify(_title.text);
      setState(() {});
    });
    for (final controller in [_badge, _tagline, _ctaLabel, _highlights]) {
      controller.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title, _slug, _badge, _tagline, _body, _rules, _highlights,
      _ctaLabel, _ctaTarget, _countdownLabel, _priority,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String _slugify(String text) => text
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');

  List<Map<String, String>> get _facts => [
        for (final line in _highlights.text.split('\n'))
          if (line.trim().isNotEmpty)
            {
              'label': line.split(':').first.trim(),
              'value': line.contains(':')
                  ? line.substring(line.indexOf(':') + 1).trim()
                  : '',
            },
      ];

  Map<String, Object?> get _values => {
        'title': _title.text.trim(),
        'slug': _slug.text.trim(),
        'badge': _badge.text.trim(),
        'tagline': _tagline.text.trim(),
        'body': _body.text.trim(),
        'rules': [
          for (final line in _rules.text.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ],
        'highlights': _facts,
        'theme': _theme,
        'cta_label': _ctaLabel.text.trim(),
        'cta_kind': _ctaKind,
        'cta_target': _ctaKind == 'none' ? '' : _ctaTarget.text.trim(),
        'placements': [
          for (final place in const ['home', 'pools'])
            if (_placements.contains(place)) place,
        ],
        'priority': int.tryParse(_priority.text.trim()) ?? 0,
        'status': _status,
        'starts_at': _startsAt?.toUtc().toIso8601String(),
        'ends_at': _endsAt?.toUtc().toIso8601String(),
        'countdown_to': _countdownTo?.toUtc().toIso8601String(),
        'countdown_label': _countdownLabel.text.trim(),
      };

  String? _problem(Map<String, Object?> values) {
    if ((values['title'] as String).isEmpty) return 'Give the campaign a title.';
    if (!RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(values['slug'] as String) ||
        (values['slug'] as String).length < 3) {
      return 'The address must be lowercase letters, numbers and dashes, like royal-rumble.';
    }
    if ((values['cta_label'] as String).isEmpty) return 'The button needs a label.';
    if (_placements.isEmpty) return 'Show it on Home, Pools or both.';
    final target = values['cta_target'] as String;
    if (_ctaKind == 'pool' &&
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(target)) {
      return "Paste the pool's id (from its page in this admin app).";
    }
    if (_ctaKind == 'route' && !target.startsWith('/')) {
      return 'A page of the app starts with /, like /pools.';
    }
    if (_ctaKind == 'url' && !target.startsWith('https://')) {
      return 'A web address must start with https://.';
    }
    if (_facts.length > 4) return 'Use at most 4 highlights.';
    if (_facts.any((fact) => fact['label']!.isEmpty || fact['value']!.isEmpty)) {
      return 'Write each highlight as "Label: value".';
    }
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      return 'The end must be after the start.';
    }
    return null;
  }

  Future<void> _pick(DateTime? current, ValueChanged<DateTime?> done) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current ?? now),
    );
    if (!mounted) return;
    final picked = time ?? const TimeOfDay(hour: 0, minute: 0);
    setState(() => done(
          DateTime(date.year, date.month, date.day, picked.hour, picked.minute),
        ));
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime?> set) {
    final palette = Palette.of(context);
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          Expanded(
            child: Text(
              value == null ? 'Not set' : DateFormat('d MMM y, HH:mm').format(value),
              style: TextStyle(color: value == null ? palette.muted : null),
            ),
          ),
          IconButton(
            tooltip: 'Choose',
            icon: const Icon(Icons.event_rounded, size: 20),
            onPressed: () => _pick(value, set),
          ),
          if (value != null)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => setState(() => set(null)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 1000;
    const gap = SizedBox(height: 14);
    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Title', hintText: 'Royal Rumble'),
        ),
        TextField(
          controller: _slug,
          maxLength: 60,
          onChanged: (_) => _slugTouched = true,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-z0-9-]'))],
          decoration: const InputDecoration(
            labelText: 'Address',
            prefixText: '/campaigns/',
            helperText: 'Lowercase letters, numbers and dashes',
          ),
        ),
        gap,
        TextField(
          controller: _badge,
          maxLength: 30,
          decoration: const InputDecoration(
            labelText: 'Badge (optional)',
            hintText: 'Season challenge',
          ),
        ),
        TextField(
          controller: _tagline,
          maxLength: 160,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Tagline'),
        ),
        TextField(
          controller: _body,
          maxLength: 4000,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(
            labelText: 'Description (on the campaign page)',
            helperText: 'A blank line starts a new paragraph',
          ),
        ),
        gap,
        TextField(
          controller: _rules,
          minLines: 3,
          maxLines: 10,
          decoration: const InputDecoration(
            labelText: 'Rules',
            helperText: 'One rule per line',
          ),
        ),
        gap,
        TextField(
          controller: _highlights,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Highlights (up to 4)',
            helperText: 'One per line, as "Label: value", e.g. Entry: ₦2,000',
          ),
        ),
        gap,
        DropdownButtonFormField<String>(
          initialValue: _theme,
          decoration: const InputDecoration(labelText: 'Look'),
          items: [
            for (final entry in campaignThemes.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value.label)),
          ],
          onChanged: (value) => setState(() => _theme = value ?? 'rumble'),
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _ctaKind,
                decoration: const InputDecoration(labelText: 'Button opens'),
                items: const [
                  DropdownMenuItem(value: 'none', child: Text('The campaign page')),
                  DropdownMenuItem(value: 'pool', child: Text('A pool')),
                  DropdownMenuItem(value: 'route', child: Text('A page of the app')),
                  DropdownMenuItem(value: 'url', child: Text('A web address')),
                ],
                onChanged: (value) => setState(() => _ctaKind = value ?? 'none'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _ctaLabel,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Button label'),
              ),
            ),
          ],
        ),
        if (_ctaKind != 'none') ...[
          TextField(
            controller: _ctaTarget,
            decoration: InputDecoration(
              labelText: switch (_ctaKind) {
                'pool' => 'Pool id',
                'route' => 'Page path',
                _ => 'Web address',
              },
              hintText: switch (_ctaKind) {
                'pool' => '9b1e…-…',
                'route' => '/pools',
                _ => 'https://',
              },
              helperText: _ctaKind == 'pool'
                  ? 'The banner still opens the campaign page; its button opens the pool.'
                  : null,
            ),
          ),
          gap,
        ],
        Text('Show on', style: Theme.of(context).textTheme.labelLarge),
        Row(
          children: [
            for (final place in const ['home', 'pools'])
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: FilterChip(
                  label: Text(place == 'home' ? 'Home' : 'Pools (top)'),
                  selected: _placements.contains(place),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _placements.add(place);
                    } else {
                      _placements.remove(place);
                    }
                  }),
                ),
              ),
          ],
        ),
        gap,
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Draft (hidden)')),
                  DropdownMenuItem(value: 'live', child: Text('Live')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (value) => setState(() => _status = value ?? 'draft'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _priority,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[-0-9]'))],
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  helperText: 'Higher shows first',
                ),
              ),
            ),
          ],
        ),
        gap,
        _dateField('Show from (optional)', _startsAt, (v) => _startsAt = v),
        gap,
        _dateField('Show until (optional)', _endsAt, (v) => _endsAt = v),
        gap,
        Row(
          children: [
            Expanded(
              child: _dateField('Countdown to (optional)', _countdownTo,
                  (v) => _countdownTo = v),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _countdownLabel,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Countdown label',
                  hintText: 'Entries close in',
                ),
              ),
            ),
          ],
        ),
      ],
    );
    final preview = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preview', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        CampaignPreview(values: _values),
        const SizedBox(height: 8),
        Text(
          'How the banner looks in the app (dark theme).',
          style: TextStyle(color: palette.muted, fontSize: 12),
        ),
      ],
    );
    return AlertDialog(
      title: Text(widget.campaign == null ? 'New campaign' : 'Edit campaign'),
      content: SizedBox(
        width: wide ? 960 : 560,
        height: size.height * 0.72,
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: form)),
                  const SizedBox(width: 24),
                  SizedBox(width: 360, child: preview),
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [preview, const SizedBox(height: 18), form],
                ),
              ),
      ),
      actions: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final values = _values;
            final problem = _problem(values);
            if (problem != null) {
              setState(() => _error = problem);
              AppNotice.error(context, problem);
              return;
            }
            Navigator.pop(context, values);
          },
          child: Text(widget.campaign == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
