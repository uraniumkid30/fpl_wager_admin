import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/core/network/providers.dart';

/// How the administrator likes the app to look. Remembered on this device.
class UiPrefs {
  const UiPrefs({
    this.themeMode = ThemeMode.system,
    this.compact = false,
    this.sidebarCollapsed = false,
  });

  final ThemeMode themeMode;

  /// Tighter table rows, to fit more on screen.
  final bool compact;

  /// The sidebar shrunk to icons only.
  final bool sidebarCollapsed;

  UiPrefs copyWith({
    ThemeMode? themeMode,
    bool? compact,
    bool? sidebarCollapsed,
  }) =>
      UiPrefs(
        themeMode: themeMode ?? this.themeMode,
        compact: compact ?? this.compact,
        sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      );
}

final uiPrefsProvider =
    NotifierProvider<UiPrefsController, UiPrefs>(UiPrefsController.new);

class UiPrefsController extends Notifier<UiPrefs> {
  static const _themeKey = 'ui_theme';
  static const _compactKey = 'ui_compact';
  static const _sidebarKey = 'ui_sidebar_collapsed';

  @override
  UiPrefs build() {
    _restore();
    return const UiPrefs();
  }

  /// Reads what was saved last time. Preferences are a nicety: if storage is
  /// unavailable the defaults simply stay.
  Future<void> _restore() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final theme = await storage.read(key: _themeKey);
      final compact = await storage.read(key: _compactKey);
      final sidebar = await storage.read(key: _sidebarKey);
      state = UiPrefs(
        themeMode: switch (theme) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        compact: compact == 'true',
        sidebarCollapsed: sidebar == 'true',
      );
    } on Object {
      // Keep the defaults.
    }
  }

  Future<void> _save(String key, String value) async {
    try {
      await ref.read(secureStorageProvider).write(key: key, value: value);
    } on Object {
      // Not being able to remember a preference is not worth an error.
    }
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _save(_themeKey, mode.name);
  }

  /// Switches between light and dark, starting from whatever is showing.
  void toggleTheme(Brightness showing) => setThemeMode(
        showing == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
      );

  void toggleCompact() {
    state = state.copyWith(compact: !state.compact);
    _save(_compactKey, '${state.compact}');
  }

  void toggleSidebar() {
    state = state.copyWith(sidebarCollapsed: !state.sidebarCollapsed);
    _save(_sidebarKey, '${state.sidebarCollapsed}');
  }
}
