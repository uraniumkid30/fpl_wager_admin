import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fplboardman_admin/app/shell/admin_shell.dart';
import 'package:fplboardman_admin/app/theme/app_theme.dart';
import 'package:fplboardman_admin/core/ui/app_widgets.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_resource_screen.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_user_screen.dart';
import 'package:fplboardman_admin/features/admin/presentation/auto_pools_screen.dart';
import 'package:fplboardman_admin/features/admin/presentation/dashboard_screen.dart';
import 'package:fplboardman_admin/features/admin/presentation/my_team_screen.dart';
import 'package:fplboardman_admin/features/admin/presentation/pool_fees_screen.dart';
import 'package:fplboardman_admin/features/auth/presentation/auth_controller.dart';
import 'package:fplboardman_admin/features/auth/presentation/login_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the admin app. Nothing but the sign-in page is reachable
/// without an administrator session.
///
/// Every signed-in page sits inside [AdminShell], which keeps the sidebar
/// and top bar in place while the page in the middle changes.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final signedIn = auth.value != null;
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;
      if (auth.isLoading) return location == '/splash' ? null : '/splash';
      if (!signedIn) return location == '/login' ? null : '/login';
      if (location == '/login' || location == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) =>
            AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _page(state, const DashboardScreen()),
          ),
          GoRoute(
            path: '/resources/:resource',
            pageBuilder: (_, state) {
              final resource = state.pathParameters['resource']!;
              return _page(
                state,
                // Keyed by section, so each one starts with its own search,
                // filters and sorting.
                AdminResourceScreen(
                  key: ValueKey('resource-$resource'),
                  resource: resource,
                ),
              );
            },
          ),
          GoRoute(
            path: '/auto-pools',
            pageBuilder: (_, state) => _page(state, const AutoPoolsScreen()),
          ),
          GoRoute(
            path: '/pool-fees',
            pageBuilder: (_, state) => _page(state, const PoolFeesScreen()),
          ),
          GoRoute(
            path: '/users/:userId',
            pageBuilder: (_, state) => _page(
              state,
              AdminUserScreen(userId: state.pathParameters['userId']!),
            ),
          ),
          GoRoute(
            path: '/team',
            pageBuilder: (_, state) => _page(state, const MyTeamScreen()),
          ),
        ],
      ),
    ],
  );
});

/// A page that fades in and rises a little as it arrives.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: AppMotion.standard,
      reverseTransitionDuration: AppMotion.quick,
      child: child,
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.012),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(),
              SizedBox(height: 28),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}
