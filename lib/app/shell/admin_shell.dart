import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpl_wager_admin/app/shell/admin_nav.dart';
import 'package:fpl_wager_admin/app/theme/app_theme.dart';
import 'package:fpl_wager_admin/core/ui/app_widgets.dart';
import 'package:fpl_wager_admin/core/ui/ui_prefs.dart';
import 'package:fpl_wager_admin/features/admin/presentation/admin_providers.dart';
import 'package:fpl_wager_admin/features/auth/domain/auth_models.dart';
import 'package:fpl_wager_admin/features/auth/presentation/auth_controller.dart';
import 'package:go_router/go_router.dart';

/// The frame around every signed-in page: the sidebar on the left, the bar
/// across the top, and the page itself in the space that is left.
///
/// On a wide screen the sidebar is always there and can be shrunk to icons.
/// On a medium screen it is icons only. On a phone it becomes a drawer.
class AdminShell extends ConsumerWidget {
  const AdminShell({required this.location, required this.child, super.key});

  /// The current path, e.g. "/resources/users".
  final String location;
  final Widget child;

  static const _expandedWidth = 256.0;
  static const _railWidth = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final prefs = ref.watch(uiPrefsProvider);
    final phone = width < 860;
    final roomy = width >= 1180;
    final collapsed = !roomy || prefs.sidebarCollapsed;
    final sidebarWidth = collapsed ? _railWidth : _expandedWidth;
    final palette = Palette.of(context);

    return Scaffold(
      drawer: phone
          ? Drawer(
              width: _expandedWidth,
              backgroundColor: palette.sidebar,
              shape: const RoundedRectangleBorder(),
              child: SafeArea(
                child: _Sidebar(
                  location: location,
                  collapsed: false,
                  closeOnNavigate: true,
                ),
              ),
            )
          : null,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              showQuickSearch(context),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              showQuickSearch(context),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!phone)
                AnimatedContainer(
                  duration: AppMotion.standard,
                  curve: AppMotion.curve,
                  width: sidebarWidth,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(color: palette.sidebar),
                  // The sidebar is always laid out at the width it is heading
                  // for, and clipped while the container catches up, so
                  // nothing squashes during the animation.
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: sidebarWidth,
                    maxWidth: sidebarWidth,
                    child: SafeArea(
                      right: false,
                      child: _Sidebar(
                        location: location,
                        collapsed: collapsed,
                        closeOnNavigate: false,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      location: location,
                      phone: phone,
                      canCollapse: roomy,
                      collapsed: collapsed,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Sidebar
// ───────────────────────────────────────────────────────────────────────────

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.location,
    required this.collapsed,
    required this.closeOnNavigate,
  });

  final String location;
  final bool collapsed;

  /// True inside the phone drawer, which shuts once a page is chosen.
  final bool closeOnNavigate;

  void _go(BuildContext context, String route) {
    if (closeOnNavigate) Navigator.of(context).pop();
    context.go(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final attention = ref.watch(attentionProvider);
    final admin = ref.watch(authControllerProvider).orNull?.user;
    final active = navItemFor(location);

    int badgeFor(NavItem item) => switch (item.badge) {
          'pools' => attention.pools,
          'withdrawals' => attention.withdrawals,
          _ => 0,
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 60,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: collapsed ? 0 : 18),
            child: Align(
              alignment: collapsed ? Alignment.center : Alignment.centerLeft,
              child: BrandMark(
                compact: true,
                onDark: true,
                showName: !collapsed,
              ),
            ),
          ),
        ),
        Divider(color: palette.sidebarBorder, height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            children: [
              for (final group in adminNavigation) ...[
                if (collapsed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: palette.sidebarBorder, height: 1),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
                    child: Text(
                      group.title.toUpperCase(),
                      style: TextStyle(
                        color: palette.sidebarMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                for (final item in group.items)
                  _NavTile(
                    item: item,
                    active: identical(item, active) || item.route == active?.route,
                    collapsed: collapsed,
                    badge: badgeFor(item),
                    onTap: () => _go(context, item.route),
                  ),
              ],
            ],
          ),
        ),
        Divider(color: palette.sidebarBorder, height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavTile(
                item: const NavItem(
                  label: 'My FPL team',
                  icon: Icons.sports_soccer_rounded,
                  route: '/team',
                ),
                active: location == '/team',
                collapsed: collapsed,
                badge: 0,
                onTap: () => _go(context, '/team'),
              ),
              const SizedBox(height: 8),
              _SidebarUser(admin: admin, collapsed: collapsed),
            ],
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.item,
    required this.active,
    required this.collapsed,
    required this.badge,
    required this.onTap,
  });

  final NavItem item;
  final bool active;
  final bool collapsed;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final active = widget.active;
    final foreground = active || _hovered
        ? Colors.white
        : palette.sidebarText.withValues(alpha: 0.72);
    final badge = widget.badge;

    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          widget.item.icon,
          size: 19,
          color: active ? AppColors.lime : foreground,
        ),
        if (widget.collapsed && badge > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          curve: AppMotion.curve,
          height: 38,
          margin: const EdgeInsets.symmetric(vertical: 1.5),
          padding: EdgeInsets.symmetric(horizontal: widget.collapsed ? 0 : 10),
          decoration: BoxDecoration(
            color: active
                ? palette.sidebarActive
                : _hovered
                    ? palette.sidebarActive.withValues(alpha: 0.55)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: widget.collapsed
              ? Center(child: icon)
              : Row(
                  children: [
                    icon,
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13.5,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Color(0xFF1C1B18),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );

    if (!widget.collapsed) return tile;
    return Tooltip(
      message: badge > 0
          ? '${widget.item.label} · $badge waiting'
          : widget.item.label,
      preferBelow: false,
      child: tile,
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  if (parts.isEmpty) return 'A';
  final letters = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return letters;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.size = 32});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.lime, AppColors.emerald],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
        ),
        child: Text(
          _initials(name),
          style: TextStyle(
            color: const Color(0xFF06231A),
            fontSize: size * 0.38,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}

class _SidebarUser extends ConsumerWidget {
  const _SidebarUser({required this.admin, required this.collapsed});
  final UserProfile? admin;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final name = admin?.fullName ?? 'Administrator';
    if (collapsed) {
      return Tooltip(
        message: '$name · ${admin?.role ?? 'admin'}',
        preferBelow: false,
        child: Center(child: _Avatar(name: name)),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: palette.sidebarActive.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          _Avatar(name: name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  admin?.role ?? 'admin',
                  maxLines: 1,
                  style: TextStyle(color: palette.sidebarMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            visualDensity: VisualDensity.compact,
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: Icon(
              Icons.logout_rounded,
              size: 18,
              color: palette.sidebarMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Top bar
// ───────────────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.location,
    required this.phone,
    required this.canCollapse,
    required this.collapsed,
  });

  final String location;
  final bool phone;

  /// Whether the screen is wide enough for the full sidebar, so the button
  /// that shrinks it is worth showing.
  final bool canCollapse;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Palette.of(context);
    final prefs = ref.watch(uiPrefsProvider);
    final brightness = Theme.of(context).brightness;
    final attention = ref.watch(attentionProvider);
    final waiting = attention.pools + attention.withdrawals;
    final admin = ref.watch(authControllerProvider).orNull?.user;
    final busy = ref.watch(adminActionProvider).isLoading;

    final item = navItemFor(location);
    final group = item == null ? null : navGroupFor(item);
    final page = item?.label ??
        switch (location) {
          '/team' => 'My FPL team',
          _ => 'Admin',
        };
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: palette.card,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: phone ? 8 : 16),
            child: Row(
              children: [
                if (phone)
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                    icon: const Icon(Icons.menu_rounded),
                  )
                else if (canCollapse)
                  IconButton(
                    tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: () =>
                        ref.read(uiPrefsProvider.notifier).toggleSidebar(),
                    icon: Icon(
                      collapsed
                          ? Icons.menu_rounded
                          : Icons.menu_open_rounded,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      if (group != null && !phone) ...[
                        Text(group, style: TextStyle(color: palette.muted)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: palette.muted,
                          ),
                        ),
                      ],
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: AppMotion.quick,
                          child: Text(
                            page,
                            key: ValueKey(page),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (wide)
                  _SearchButton(onTap: () => showQuickSearch(context))
                else
                  IconButton(
                    tooltip: 'Search',
                    onPressed: () => showQuickSearch(context),
                    icon: const Icon(Icons.search_rounded),
                  ),
                const SizedBox(width: 6),
                if (!phone)
                  IconButton(
                    tooltip: prefs.compact
                        ? 'Comfortable rows'
                        : 'Compact rows',
                    onPressed: () =>
                        ref.read(uiPrefsProvider.notifier).toggleCompact(),
                    icon: Icon(
                      prefs.compact
                          ? Icons.density_medium_rounded
                          : Icons.density_small_rounded,
                    ),
                  ),
                IconButton(
                  tooltip: brightness == Brightness.dark
                      ? 'Light theme'
                      : 'Dark theme',
                  onPressed: () => ref
                      .read(uiPrefsProvider.notifier)
                      .toggleTheme(brightness),
                  icon: AnimatedSwitcher(
                    duration: AppMotion.standard,
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      key: ValueKey(brightness),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: waiting == 0
                      ? 'Nothing is waiting for you'
                      : '$waiting waiting for you',
                  position: PopupMenuPosition.under,
                  onSelected: (route) => context.go(route),
                  itemBuilder: (context) => [
                    if (waiting == 0)
                      const PopupMenuItem<String>(
                        enabled: false,
                        child: Text('Nothing is waiting for you.'),
                      ),
                    if (attention.pools > 0)
                      PopupMenuItem<String>(
                        value: '/resources/wagers',
                        child: _AttentionRow(
                          icon: Icons.emoji_events_outlined,
                          text: attention.pools == 1
                              ? '1 pool is waiting for approval'
                              : '${attention.pools} pools are waiting for approval',
                        ),
                      ),
                    if (attention.withdrawals > 0)
                      PopupMenuItem<String>(
                        value: '/resources/withdrawals',
                        child: _AttentionRow(
                          icon: Icons.north_east_rounded,
                          text: attention.withdrawals == 1
                              ? '1 withdrawal is waiting for approval'
                              : '${attention.withdrawals} withdrawals are waiting for approval',
                        ),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: palette.muted,
                          size: 21,
                        ),
                        if (waiting > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              constraints: const BoxConstraints(minWidth: 15),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                waiting > 9 ? '9+' : '$waiting',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: 'Account',
                  position: PopupMenuPosition.under,
                  onSelected: (choice) {
                    switch (choice) {
                      case 'team':
                        context.go('/team');
                      case 'theme-system':
                        ref
                            .read(uiPrefsProvider.notifier)
                            .setThemeMode(ThemeMode.system);
                      case 'logout':
                        ref.read(authControllerProvider.notifier).logout();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            admin?.fullName ?? 'Administrator',
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${admin?.email ?? ''} · ${admin?.role ?? 'admin'}',
                            style: TextStyle(color: palette.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'team',
                      child: _AttentionRow(
                        icon: Icons.sports_soccer_rounded,
                        text: 'My FPL team',
                      ),
                    ),
                    if (prefs.themeMode != ThemeMode.system)
                      const PopupMenuItem<String>(
                        value: 'theme-system',
                        child: _AttentionRow(
                          icon: Icons.brightness_auto_outlined,
                          text: 'Match the device theme',
                        ),
                      ),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: _AttentionRow(
                        icon: Icons.logout_rounded,
                        text: 'Sign out',
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _Avatar(name: admin?.fullName ?? 'Administrator'),
                  ),
                ),
              ],
            ),
          ),
          // A hairline of progress along the bottom while a change is
          // being saved.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedOpacity(
              duration: AppMotion.quick,
              opacity: busy ? 1 : 0,
              child: const LinearProgressIndicator(minHeight: 2),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Flexible(child: Text(text)),
        ],
      );
}

class _SearchButton extends StatefulWidget {
  const _SearchButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.quick,
          width: 240,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _hovered ? palette.hover : palette.subtle,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 17, color: palette.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Go to…',
                  style: TextStyle(color: palette.muted, fontSize: 13.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'Ctrl K',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// Quick search (Ctrl/⌘ K)
// ───────────────────────────────────────────────────────────────────────────

/// Opens the "go to" box: type a few letters of a section's name and press
/// Enter to jump there.
Future<void> showQuickSearch(BuildContext context) async {
  final route = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close search',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: AppMotion.quick,
    pageBuilder: (context, _, _) => const _QuickSearch(),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.97, end: 1).animate(
          CurvedAnimation(parent: animation, curve: AppMotion.curve),
        ),
        child: child,
      ),
    ),
  );
  if (route != null && context.mounted) context.go(route);
}

class _QuickSearch extends StatefulWidget {
  const _QuickSearch();

  @override
  State<_QuickSearch> createState() => _QuickSearchState();
}

class _QuickSearchState extends State<_QuickSearch> {
  final _query = TextEditingController();
  int _selected = 0;

  static const _extra = [
    NavItem(
      label: 'My FPL team',
      icon: Icons.sports_soccer_rounded,
      route: '/team',
      keywords: 'link entry',
    ),
  ];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<NavItem> get _matches {
    final words = _query.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    final all = [...allNavItems, ..._extra];
    if (words.isEmpty) return all;
    return all.where((item) {
      final haystack = '${item.label} ${item.keywords}'.toLowerCase();
      return words.every(haystack.contains);
    }).toList();
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _selected = (_selected + by) % count);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette.of(context);
    final matches = _matches;
    final selected = matches.isEmpty
        ? 0
        : _selected < matches.length
            ? _selected
            : matches.length - 1;
    return SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Material(
            color: palette.card,
            elevation: 16,
            shadowColor: Colors.black54,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560, maxHeight: 460),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                      _move(1, matches.length),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                      _move(matches.length - 1, matches.length),
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: palette.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _query,
                              autofocus: true,
                              textInputAction: TextInputAction.go,
                              decoration: const InputDecoration(
                                hintText: 'Go to a section…',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              onChanged: (_) => setState(() => _selected = 0),
                              onSubmitted: (_) {
                                if (matches.isNotEmpty) {
                                  Navigator.of(context)
                                      .pop(matches[selected].route);
                                }
                              },
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    Divider(color: palette.border, height: 1),
                    Flexible(
                      child: matches.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Text(
                                'No section matches "${_query.text.trim()}".',
                                style: TextStyle(color: palette.muted),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: matches.length,
                              itemBuilder: (context, index) {
                                final item = matches[index];
                                final active = index == selected;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () =>
                                      Navigator.of(context).pop(item.route),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active ? palette.hover : null,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 18,
                                          color: active
                                              ? palette.accent
                                              : palette.muted,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text(item.label)),
                                        if (active)
                                          Icon(
                                            Icons.keyboard_return_rounded,
                                            size: 16,
                                            color: palette.muted,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
