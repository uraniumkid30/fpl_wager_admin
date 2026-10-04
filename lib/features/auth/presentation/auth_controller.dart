import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/features/auth/data/auth_repository.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

/// Holds the signed-in administrator, or null when nobody is signed in.
class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() =>
      ref.read(authRepositoryProvider).restoreSession();

  /// Signs in. Throws the server's error (wrong password, not an admin,
  /// account blocked) for the login screen to show.
  Future<void> login(String email, String password) async {
    final session = await ref.read(authRepositoryProvider).login(email, password);
    state = AsyncData(session);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}
