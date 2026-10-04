import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/features/admin/data/admin_repository.dart';
import 'package:fpl_wager_admin/features/admin/domain/admin_models.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';

final adminDashboardProvider = FutureProvider.autoDispose<AdminDashboardSummary>(
  (ref) => ref.watch(adminRepositoryProvider).dashboard(),
);

final adminCollectionProvider = FutureProvider.autoDispose
    .family<List<Map<String, Object?>>, String>(
  (ref, resource) => ref.watch(adminRepositoryProvider).collection(resource),
);

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
      if (refreshOnError) {
        for (final resource in refresh) {
          ref.invalidate(adminCollectionProvider(resource));
        }
        ref.invalidate(adminDashboardProvider);
      }
      return result.error;
    }

    for (final resource in refresh) {
      ref.invalidate(adminCollectionProvider(resource));
    }
    ref.invalidate(adminDashboardProvider);
    return null;
  }
}
