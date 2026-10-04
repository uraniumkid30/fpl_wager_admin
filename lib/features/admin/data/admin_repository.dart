import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/core/network/api_client.dart';
import 'package:fpl_wager_admin/core/network/providers.dart';
import 'package:fpl_wager_admin/features/admin/domain/admin_models.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';
import 'package:uuid/uuid.dart';

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

  /// Lists one resource: users, wagers, payments, wallets, transactions,
  /// settings, teams, challenges, notifications, gameweeks, audit-logs,
  /// fpl-logins, withdrawals or notification-subscriptions.
  Future<List<Map<String, Object?>>> collection(String resource) async =>
      _items(await _client.get('/admin/$resource'));

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
