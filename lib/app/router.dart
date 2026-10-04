import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_home_screen.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_resource_screen.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_user_screen.dart';
import 'package:fpl_wager_admin/features/admin/presentation/my_team_screen.dart';
import 'package:fpl_wager_admin/features/auth/presentation/auth_controller.dart';
import 'package:fpl_wager_admin/features/auth/presentation/login_screen.dart';
import 'package:go_router/go_router.dart';

/// Routes for the admin app. Nothing but the sign-in page is reachable
/// without an administrator session.
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
      GoRoute(
        path: '/',
        builder: (_, _) => const AdminHomeScreen(),
        routes: [
          GoRoute(
            path: 'resources/:resource',
            builder: (_, state) => AdminResourceScreen(
              resource: state.pathParameters['resource']!,
            ),
          ),
          GoRoute(
            path: 'users/:userId',
            builder: (_, state) => AdminUserScreen(
              userId: state.pathParameters['userId']!,
            ),
          ),
          GoRoute(
            path: 'team',
            builder: (_, _) => const MyTeamScreen(),
          ),
        ],
      ),
    ],
  );
});

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
