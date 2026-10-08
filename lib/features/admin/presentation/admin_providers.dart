import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/features/admin/data/admin_repository.dart';
import 'package:fplboardman_admin/features/admin/domain/admin_models.dart';
import 'package:fplboardman_admin/features/auth/domain/auth_models.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardSummary>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

final adminCollectionProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, resource) => ref.watch(adminRepositoryProvider).collection(resource),
);

/// The newest few records of a resource, for the dashboard's short lists.
final adminRecentProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, resource) => ref.watch(adminRepositoryProvider).recent(resource),
);

/// Sign-ups and money movement by day, with totals, for the dashboard.
final adminStatsProvider = FutureProvider.autoDispose<Map<String, Object?>>(
  (ref) => ref.watch(adminRepositoryProvider).stats(),
);

/// The auto pool switch and the stakes auto pools are offered at.
final adminAutoPoolsProvider = FutureProvider.autoDispose<
    ({bool enabled, List<Map<String, Object?>> tiers})>(
  (ref) => ref.watch(adminRepositoryProvider).autoPools(),
);

/// The fee for deleting a user's pool after others have joined, in percent.
final adminPoolFeeProvider = FutureProvider.autoDispose<double>(
  (ref) => ref.watch(adminRepositoryProvider).poolDeleteFeePercent(),
);

/// What is waiting for an administrator: custom pools to approve and
/// withdrawal requests to approve or reject.
final attentionProvider =
    Provider.autoDispose<({int pools, int withdrawals})>((ref) {
  // Draft pools are the ones waiting for approval.
  final byStatus = ref.watch(adminStatsProvider).orNull?['pools_by_status'];
  final summary = ref.watch(adminDashboardProvider).orNull;
  return (
    pools: byStatus is Map ? (byStatus['draft'] as num? ?? 0).toInt() : 0,
    withdrawals: summary?.pendingWithdrawals ?? 0,
  );
});

extension AsyncValueOrNull<T> on AsyncValue<T> {
  /// The latest value, or null while there is none (still loading the first
  /// time, or failed before anything loaded).
  T? get orNull => hasValue ? requireValue : null;
}

final adminUserProvider = FutureProvider.autoDispose.family<UserProfile, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).user(userId),
);

final adminWagerMembersProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, poolId) => ref.watch(adminRepositoryProvider).wagerMembers(poolId),
);

final adminWalletProvider = FutureProvider.autoDispose
    .family<Map<String, Object?>, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).wallet(userId),
);

/// The signed-in administrator's own linked FPL team, or null.
final adminMyTeamProvider = FutureProvider.autoDispose<Map<String, Object?>?>(
  (ref) => ref.watch(adminRepositoryProvider).myTeam(),
);

final adminActionProvider =
    AsyncNotifierProvider<AdminActionController, void>(
  AdminActionController.new,
);

/// Runs one admin change at a time and refreshes whatever it affects.
///
/// [run] returns null on success, or the error to show. While it is running,
/// `ref.watch(adminActionProvider).isLoading` is true so screens can disable
/// their buttons.
class AdminActionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ///
  /// [refreshOnError] reloads the lists in [refresh] even when the action
  /// fails. A bank transfer the provider refused still changes what the
  /// withdrawal shows, so those lists must not be left stale.
  Future<Object?> run(
    Future<void> Function(AdminRepository repository) action, {
    List<String> refresh = const [],
    bool refreshOnError = false,
  }) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard<void>(
      () => action(ref.read(adminRepositoryProvider)),
    );
    // The outcome is returned to the caller to show; this provider only
    // tracks whether something is in flight.
    state = const AsyncData(null);
    if (result.hasError) {
      if (refreshOnError) _reload(refresh);
      return result.error;
    }
    _reload(refresh);
    return null;
  }

  /// Reloads the lists an action touched, and the figures that depend on
  /// them.
  void _reload(List<String> resources) {
    for (final resource in resources) {
      ref.invalidate(adminCollectionProvider(resource));
      ref.invalidate(adminRecentProvider(resource));
    }
    // Every action is written to the audit trail.
    ref.invalidate(adminRecentProvider('audit-logs'));
    ref.invalidate(adminCollectionProvider('audit-logs'));
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminStatsProvider);
  }
}
