import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/core/network/api_client.dart';
import 'package:fplboardman_admin/core/network/providers.dart';
import 'package:fplboardman_admin/features/admin/domain/admin_models.dart';
import 'package:fplboardman_admin/features/auth/domain/auth_models.dart';
import 'package:uuid/uuid.dart';

/// The rules for pools users create (see AdminRepository.poolRules).
typedef PoolRules = ({
  double deleteFeePercent,
  int winners,
  int entrants,
  int maxWinners,
});

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(apiClientProvider)),
);

/// Every call the admin app makes to the admin API.
///
/// Money is always sent in the smallest unit ("cents": 100 per naira). The
/// screens convert from the naira amounts an administrator types.
class AdminRepository {
  const AdminRepository(this._client);
  final ApiClient _client;
  static const _uuid = Uuid();

  /// Approving or checking a withdrawal and settling a pool make the server
  /// wait on Paystack, Korapay or FPL, which can take far longer than an
  /// ordinary request. The server allows these 110 seconds.
  static const _patient = Duration(seconds: 100);

  Future<AdminDashboardSummary> dashboard() async =>
      AdminDashboardSummary.fromJson(await _client.get('/admin/dashboard'));

  /// The most records a list page loads. Beyond this the newest are shown
  /// and the page says so.
  static const maxRows = 3000;
  static const _pageSize = 100;

  /// Lists one resource: users, wagers, payments, wallets, transactions,
  /// settings, teams, challenges, notifications, gameweeks, audit-logs,
  /// fpl-logins, withdrawals or notification-subscriptions.
  ///
  /// The server hands lists out a page at a time. This reads the pages one
  /// after another, newest first, so the list page can search, filter, sort
  /// and export everything rather than only the first screenful.
  Future<List<Map<String, Object?>>> collection(String resource) async {
    final all = <Map<String, Object?>>[];
    for (var page = 1; all.length < maxRows; page++) {
      final body = await _client.get(
        '/admin/$resource',
        query: {'page': page, 'per_page': _pageSize},
      );
      final items = _items(body);
      all.addAll(items);
      // A resource that is not paged reports no page size and has already
      // sent everything; a short page is the last one.
      final limit = body['limit'];
      if (limit is! num || limit <= 0 || items.length < limit) break;
    }
    return all.length > maxRows ? all.sublist(0, maxRows) : all;
  }

  /// The newest few records of a resource, for the dashboard.
  Future<List<Map<String, Object?>>> recent(
    String resource, {
    int count = 6,
  }) async =>
      _items(
        await _client.get(
          '/admin/$resource',
          query: {'page': 1, 'per_page': count},
        ),
      );

  /// Fourteen days of sign-ups and money movement, plus running totals, for
  /// the dashboard's charts.
  Future<Map<String, Object?>> stats() => _client.get('/admin/stats');

  // ── Auto pools ─────────────────────────────────────────────────────────

  /// Whether auto pools are running at all, and the stakes they are offered
  /// at.
  Future<({bool enabled, List<Map<String, Object?>> tiers})> autoPools() async {
    final body = await _client.get('/admin/auto-pools');
    return (enabled: body['enabled'] != false, tiers: _items(body));
  }

  /// Switches every auto pool on or off. Pools that are already open stay
  /// open; this only decides whether new ones are created.
  Future<void> setAutoPoolsEnabled(bool enabled) async {
    await _client.put('/admin/auto-pools/status', data: {'enabled': enabled});
  }

  /// Adds a stake at which an auto pool is offered every gameweek.
  Future<void> createAutoPoolTier(int stakeCents) async {
    await _client.post('/admin/auto-pools', data: {'stake_cents': stakeCents});
  }

  /// Pauses or resumes one stake. Paused, its open pool carries on but no
  /// new one is created after it.
  Future<void> setAutoPoolTierEnabled(String id, bool enabled) async {
    await _client.patch('/admin/auto-pools/$id', data: {'enabled': enabled});
  }

  /// Removes a stake for good. With [cancelOpen], its open pool is cancelled
  /// and everyone in it refunded; otherwise that pool plays out. Returns how
  /// many entries were refunded.
  Future<int> deleteAutoPoolTier(String id, {required bool cancelOpen}) async {
    final body = await _client.delete(
      '/admin/auto-pools/$id${cancelOpen ? '?cancel_open=true' : ''}',
    );
    return (body['refunded'] as num? ?? 0).toInt();
  }

  // ── Pool fees ──────────────────────────────────────────────────────────

  /// The rules for pools users create: the delete fee (a percentage of one
  /// entry fee) and the winners limit (at most `winners` paid places for
  /// every `entrants` managers, never more than `maxWinners`).
  Future<PoolRules> poolRules() async {
    final body = await _client.get('/admin/pool-settings');
    final rule = body['winner_rule'];
    final map = rule is Map ? rule : const {};
    return (
      deleteFeePercent: (body['delete_fee_percent'] as num? ?? 5).toDouble(),
      winners: (map['winners'] as num? ?? 3).toInt(),
      entrants: (map['entrants'] as num? ?? 5).toInt(),
      maxWinners: (map['max_winners'] as num? ?? 50).toInt(),
    );
  }

  /// Changes the winners limit for pools created from now on.
  Future<void> setWinnerRule({
    required int winners,
    required int entrants,
    required int maxWinners,
  }) async {
    await _client.put(
      '/admin/pool-settings',
      data: {
        'winner_rule': {
          'winners': winners,
          'entrants': entrants,
          'max_winners': maxWinners,
        },
      },
    );
  }

  /// Changes that fee. [percent] is 0 to 100 with up to two decimals.
  Future<void> setPoolDeleteFeePercent(double percent) async {
    await _client.put(
      '/admin/pool-settings',
      data: {'delete_fee_percent': percent},
    );
  }

  // ── Users ──────────────────────────────────────────────────────────────

  Future<UserProfile> user(String id) async =>
      UserProfile.fromJson(await _client.get('/admin/users/$id'));

  Future<void> createUser(Map<String, Object?> values) async {
    await _client.post('/admin/users', data: values);
  }

  Future<UserProfile> updateUser(String id, Map<String, Object?> changes) async =>
      UserProfile.fromJson(await _client.patch('/admin/users/$id', data: changes));

  /// Permanently deletes the account and everything that belongs to it.
  Future<void> deleteUser(String id) async {
    await _client.delete('/admin/users/$id');
  }

  // ── Pools ("wagers") ───────────────────────────────────────────────────

  Future<void> createWager(Map<String, Object?> values) async {
    await _client.post(
      '/admin/wagers',
      data: values,
      idempotencyKey: _uuid.v4(),
    );
  }

  Future<void> updateWager(String id, Map<String, Object?> changes) async {
    await _client.patch('/admin/wagers/$id', data: changes);
  }

  Future<void> updateWagerStatus(String id, String status) async {
    await _client.patch('/admin/wagers/$id', data: {'status': status});
  }

  /// Opens a custom pool that is waiting for review.
  Future<void> approveWager(String id) async {
    await _client.post('/admin/wagers/$id/approve');
  }

  /// Deletes a pool. Unsettled pools refund every paid entry first.
  Future<void> deleteWager(String id) async {
    await _client.delete('/admin/wagers/$id');
  }

  /// Finishes a locked pool now: scores it from FPL, pays the winners and
  /// emails them. Returns a sentence describing what happened. The server
  /// refuses until FPL has finalised the pool's gameweek.
  Future<String> settleWager(String id) async {
    final body = await _client.post(
      '/admin/wagers/$id/settle',
      receiveTimeout: _patient,
    );
    if ('${body['status']}' == 'cancelled') {
      return 'The pool had fewer than two entries, so it was cancelled and '
          'refunded.';
    }
    final winners = (body['winners'] as num? ?? 0).toInt();
    final entrants = (body['entrants'] as num? ?? 0).toInt();
    return 'Pool settled: $entrants entries, $winners paid '
        '${winners == 1 ? 'place' : 'places'}. Winners have been paid and '
        'emailed.';
  }

  Future<List<Map<String, Object?>>> wagerMembers(String id) async =>
      _items(await _client.get('/admin/wagers/$id/members'));

  Future<void> removeWagerMember(String poolId, String userId) async {
    await _client.delete('/admin/wagers/$poolId/members/$userId');
  }

  // ── Money ──────────────────────────────────────────────────────────────

  /// Adds (positive) or deducts (negative) money on a user's wallet. Every
  /// adjustment is written to the ledger and the audit trail with [reason].
  Future<void> adjustWallet({
    required String userId,
    required int amountCents,
    required String reason,
  }) async {
    await _client.post(
      '/admin/wallets/$userId/adjustments',
      data: {'amount_cents': amountCents, 'reason': reason},
      idempotencyKey: _uuid.v4(),
    );
  }

  /// One user's wallet: balances and their recent ledger.
  Future<Map<String, Object?>> wallet(String userId) =>
      _client.get('/admin/wallets/$userId');

  // ── Withdrawals ────────────────────────────────────────────────────────

  /// Approves a withdrawal request and starts the bank transfer through the
  /// payment provider. Returns the server's description of what happened.
  Future<String> approveWithdrawal(String id) async => _message(
        await _client.post(
          '/admin/withdrawals/$id/approve',
          receiveTimeout: _patient,
        ),
        'Withdrawal approved.',
      );

  /// Rejects a request that is waiting for approval and returns the money to
  /// the user's wallet. [reason] is optional and is shown to the user.
  Future<String> rejectWithdrawal(String id, String reason) async => _message(
        await _client.post(
          '/admin/withdrawals/$id/reject',
          data: {'reason': reason},
        ),
        'Withdrawal rejected.',
      );

  /// Asks the provider for the current state of an approved withdrawal's
  /// transfer and updates the withdrawal if it changed.
  Future<String> verifyWithdrawal(String id) async => _message(
        await _client.post(
          '/admin/withdrawals/$id/verify',
          receiveTimeout: _patient,
        ),
        'Status checked.',
      );

  Future<void> verifyPayment(String reference) async {
    await _client.post('/admin/payments/$reference/verify');
  }

  Future<void> deletePayment(String reference) async {
    await _client.delete('/admin/payments/$reference');
  }

  // ── Everything else ────────────────────────────────────────────────────

  Future<void> putSetting(String key, Object? value) async {
    await _client.put('/admin/settings/$key', data: {'value': value});
  }

  Future<void> deleteSetting(String key) async {
    await _client.delete('/admin/settings/$key');
  }

  Future<void> deleteTeam(String userId) async {
    await _client.delete('/admin/teams/$userId');
  }

  Future<void> deleteChallenge(String id) async {
    await _client.delete('/admin/challenges/$id');
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    await _client.post(
      '/admin/notifications',
      data: {'user_id': userId, 'title': title, 'body': body},
    );
  }

  Future<void> deleteNotification(String id) async {
    await _client.delete('/admin/notifications/$id');
  }

  // ── Notification emails ────────────────────────────────────────────────

  /// Adds an address to the list of people emailed about platform events.
  Future<void> createNotificationEmail({
    required String email,
    required bool onWithdrawRequest,
    required bool onPoolEnded,
  }) async {
    await _client.post(
      '/admin/notification-subscriptions',
      data: {
        'email': email,
        'on_withdraw_request': onWithdrawRequest,
        'on_pool_ended': onPoolEnded,
      },
    );
  }

  Future<void> updateNotificationEmail(
    String id, {
    required String email,
    required bool onWithdrawRequest,
    required bool onPoolEnded,
  }) async {
    await _client.patch(
      '/admin/notification-subscriptions/$id',
      data: {
        'email': email,
        'on_withdraw_request': onWithdrawRequest,
        'on_pool_ended': onPoolEnded,
      },
    );
  }

  Future<void> deleteNotificationEmail(String id) async {
    await _client.delete('/admin/notification-subscriptions/$id');
  }

  Future<void> deleteFplLogin(String id) async {
    await _client.delete('/admin/fpl-logins/$id');
  }

  // ── The administrator's own FPL team ───────────────────────────────────

  /// The signed-in administrator's linked FPL team, or null if none.
  Future<Map<String, Object?>?> myTeam() async {
    final body = await _client.get('/dashboard');
    final team = body['team'];
    return team is Map<Object?, Object?>
        ? Map<String, Object?>.from(team)
        : null;
  }

  /// Looks an FPL entry up without linking it, to confirm it is the right one.
  Future<Map<String, Object?>> validateTeam(int entryId) =>
      _client.post('/fpl-team/validate', data: {'entry_id': entryId});

  /// Links an FPL entry to the signed-in administrator's account.
  Future<Map<String, Object?>> linkTeam(int entryId) =>
      _client.post('/fpl-team/link', data: {'entry_id': entryId});
}

/// The server's own sentence about what an action did, or [fallback].
String _message(Map<String, Object?> body, String fallback) {
  final message = body['message'];
  return message is String && message.trim().isNotEmpty ? message : fallback;
}

List<Map<String, Object?>> _items(Map<String, Object?> body) =>
    (body['items'] as List<Object?>? ?? const [])
        .map((item) => Map<String, Object?>.from(item! as Map<Object?, Object?>))
        .toList();
