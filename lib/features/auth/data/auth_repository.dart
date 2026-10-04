import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/core/errors/app_exception.dart';
import 'package:fpl_wager_admin/core/network/api_client.dart';
import 'package:fpl_wager_admin/core/network/providers.dart';
import 'package:fpl_wager_admin/core/storage/session_store.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Signs an administrator in and keeps the session alive.
///
/// Administrators sign in with an email and password — there is no FPL step.
/// The server only accepts admin and superadmin accounts on this endpoint,
/// and this class double-checks the role before treating anyone as signed in.
class AuthRepository {
  AuthRepository(this._client, this._sessions) {
    _client.setRefreshHandler(_refreshAccessToken);
  }

  final ApiClient _client;
  final SessionStore _sessions;
  StoredTokens? _tokens;
  Future<String?>? _refreshing;

  /// Picks up a previous session from secure storage, if it is still valid
  /// and still belongs to an administrator.
  Future<AuthSession?> restoreSession() async {
    final stored = await _sessions.read();
    if (stored == null) return null;
    _tokens = stored;
    _client.authorize(stored.accessToken);
    try {
      final body = await _client.get('/me');
      final user = UserProfile.fromJson(_json(body, 'user'));
      if (!user.isAdmin) {
        await _forget();
        return null;
      }
      // A refresh during the request may have replaced the tokens.
      final current = _tokens ?? stored;
      return AuthSession(
        user: user,
        accessToken: current.accessToken,
        refreshToken: current.refreshToken,
      );
    } on AuthenticationException {
      await _forget();
      return null;
    }
  }

  Future<AuthSession> login(String email, String password) async {
    final body = await _client.post(
      '/auth/admin/login',
      allowRefresh: false,
      data: {'email': email, 'password': password},
    );
    final session = await _saveTokenResponse(body);
    if (!session.user.isAdmin) {
      await _forget();
      throw const AuthenticationException(
        'This account is not an administrator.',
      );
    }
    return session;
  }

  Future<void> logout() async {
    final refresh = _tokens?.refreshToken;
    if (refresh != null) {
      try {
        await _client.post(
          '/auth/logout',
          allowRefresh: false,
          data: {'refresh_token': refresh},
        );
      } on AppException {
        // Signing out locally must still work when the network is down.
      }
    }
    await _forget();
  }

  Future<void> _forget() async {
    _tokens = null;
    _client.authorize(null);
    await _sessions.clear();
  }

  Future<AuthSession> _saveTokenResponse(Map<String, Object?> body) async {
    final stored = StoredTokens(
      accessToken: body['access_token']! as String,
      refreshToken: body['refresh_token']! as String,
    );
    _tokens = stored;
    _client.authorize(stored.accessToken);
    await _sessions.write(stored);
    return AuthSession(
      user: UserProfile.fromJson(_json(body, 'user')),
      accessToken: stored.accessToken,
      refreshToken: stored.refreshToken,
    );
  }

  Future<String?> _refreshAccessToken() {
    final active = _refreshing;
    if (active != null) return active;
    final future = _performRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<String?> _performRefresh() async {
    final refresh = _tokens?.refreshToken;
    if (refresh == null) return null;
    try {
      final body = await _client.post(
        '/auth/refresh',
        allowRefresh: false,
        data: {'refresh_token': refresh},
      );
      return (await _saveTokenResponse(body)).accessToken;
    } on AppException {
      _tokens = null;
      await _sessions.clear();
      return null;
    }
  }
}

Map<String, Object?> _json(Map<String, Object?> source, String key) =>
    Map<String, Object?>.from(source[key]! as Map<Object?, Object?>);
