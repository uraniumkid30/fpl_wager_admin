import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/router.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/ui_prefs.dart';

class FplWagerAdminApp extends ConsumerWidget {
  const FplWagerAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(uiPrefsProvider.select((prefs) => prefs.themeMode));
    return MaterialApp.router(
      title: 'FPLboardman admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      themeAnimationDuration: AppMotion.standard,
      themeAnimationCurve: AppMotion.curve,
      routerConfig: router,
    );
  }
}
