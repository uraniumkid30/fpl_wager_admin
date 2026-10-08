import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/core/ui/app_notice.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/core/ui/ui_kit.dart';
import 'package:fplboardman_admin/features/admin/data/admin_repository.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_providers.dart';

/// Lets the signed-in administrator link their own FPL team by its ID.
///
/// Managers who sign in with FPL get their team automatically. An
/// administrator signs in with a password instead, so they add theirs here:
/// type the FPL ID, check it is the right team, then link it.
class MyTeamScreen extends ConsumerStatefulWidget {
  const MyTeamScreen({super.key});

  @override
  ConsumerState<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends ConsumerState<MyTeamScreen> {
  final _form = GlobalKey<FormState>();
  final _entryId = TextEditingController();

  /// The team FPL returned for the ID that was last checked.
  Map<String, Object?>? _found;
  int? _foundId;
  bool _busy = false;

  @override
  void dispose() {
    _entryId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(adminMyTeamProvider);
    final found = _found;
    return PageBody(
      maxWidth: 620,
      children: [
        const FadeSlideIn(
          child: PageHeader(
            title: 'My FPL team',
            subtitle: 'Link your own FPL team to this administrator account.',
          ),
        ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Linked team',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    GradientPanel(
                      child: current.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => Text(error.toString()),
                        data: (team) => team == null
                            ? const Text('You have not linked an FPL team yet.')
                            : _TeamSummary(
                                teamName: '${team['team_name'] ?? ''}',
                                managerName: '${team['manager_name'] ?? ''}',
                                entryId: '${team['entry_id'] ?? ''}',
                              ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text(
                      'Link a team',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your FPL ID is the number in the address of your team\'s '
                      'Points page on the FPL website: /entry/1234567/event/1.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Form(
                      key: _form,
                      child: TextFormField(
                        controller: _entryId,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'FPL ID',
                          prefixIcon: Icon(Icons.sports_soccer_rounded),
                        ),
                        validator: (value) =>
                            (int.tryParse((value ?? '').trim()) ?? 0) > 0
                                ? null
                                : 'Enter your FPL ID',
                        onChanged: (_) {
                          // A different number needs checking again.
                          if (_found != null) {
                            setState(() {
                              _found = null;
                              _foundId = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (found == null)
                      FilledButton.icon(
                        onPressed: _busy ? null : _check,
                        icon: const Icon(Icons.search_rounded),
                        label: const Text('Check team'),
                      )
                    else ...[
                      GradientPanel(
                        child: _TeamSummary(
                          teamName: '${found['name'] ?? ''}',
                          managerName:
                              '${found['player_first_name'] ?? ''} ${found['player_last_name'] ?? ''}'
                                  .trim(),
                          entryId: '$_foundId',
                        ),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _busy ? null : _link,
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Link this team'),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _check() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final id = int.parse(_entryId.text.trim());
    setState(() => _busy = true);
    try {
      final team = await ref.read(adminRepositoryProvider).validateTeam(id);
      if (!mounted) return;
      setState(() {
        _found = team;
        _foundId = id;
      });
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link() async {
    final id = _foundId;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminRepositoryProvider).linkTeam(id);
      ref.invalidate(adminMyTeamProvider);
      ref.invalidate(adminCollectionProvider('teams'));
      if (!mounted) return;
      setState(() {
        _found = null;
        _foundId = null;
        _entryId.clear();
      });
      AppNotice.success(context, 'Your FPL team is linked.');
    } on Object catch (error) {
      if (mounted) AppNotice.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({
    required this.teamName,
    required this.managerName,
    required this.entryId,
  });

  final String teamName;
  final String managerName;
  final String entryId;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.13),
            child: Icon(
              Icons.shield_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teamName, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$managerName · FPL ID $entryId',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      );
}
