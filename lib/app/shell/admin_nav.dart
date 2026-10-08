import 'package:flutter/material.dart';
import 'package:fplboardman_admin/features/admin/presentation/admin_resources.dart';

/// One destination in the sidebar.
class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.badge,
    this.keywords = '',
  });

  final String label;
  final IconData icon;

  /// Where it goes, e.g. "/resources/users".
  final String route;

  /// Which count to show beside it: "pools" (awaiting approval) or
  /// "withdrawals" (awaiting approval). Null for none.
  final String? badge;

  /// Extra words the quick search matches, besides the label.
  final String keywords;
}

class NavGroup {
  const NavGroup({required this.title, required this.items});
  final String title;
  final List<NavItem> items;
}

NavItem _resource(String key, {String? badge, String keywords = ''}) {
  final definition = adminResources[key]!;
  return NavItem(
    label: definition.label,
    icon: definition.icon,
    route: '/resources/$key',
    badge: badge,
    keywords: '${definition.description} $keywords',
  );
}

/// The sidebar, top to bottom.
final List<NavGroup> adminNavigation = [
  const NavGroup(
    title: 'Overview',
    items: [
      NavItem(
        label: 'Dashboard',
        icon: Icons.space_dashboard_outlined,
        route: '/',
        keywords: 'home overview stats',
      ),
    ],
  ),
  NavGroup(
    title: 'Game',
    items: [
      _resource('wagers', badge: 'pools', keywords: 'custom private approve'),
      const NavItem(
        label: 'Auto pools',
        icon: Icons.autorenew_rounded,
        route: '/auto-pools',
        keywords: 'automatic standard stakes tiers stop pause',
      ),
      const NavItem(
        label: 'Pool fees',
        icon: Icons.percent_rounded,
        route: '/pool-fees',
        keywords: 'delete fee fine cancel custom private percentage',
      ),
      _resource('challenges'),
      _resource('gameweeks'),
      _resource('teams'),
    ],
  ),
  NavGroup(
    title: 'Money',
    items: [
      _resource('withdrawals', badge: 'withdrawals', keywords: 'payout bank'),
      _resource('payments', keywords: 'top up deposit paystack korapay'),
      _resource('wallets', keywords: 'balance'),
      _resource('transactions', keywords: 'ledger history'),
    ],
  ),
  NavGroup(
    title: 'People',
    items: [
      _resource('users', keywords: 'accounts managers admins'),
      _resource('notifications'),
      _resource('notification-subscriptions', keywords: 'alerts email'),
    ],
  ),
  NavGroup(
    title: 'System',
    items: [
      _resource('settings'),
      _resource('fpl-logins'),
      _resource('audit-logs', keywords: 'history log'),
    ],
  ),
];

/// Every destination, in sidebar order.
List<NavItem> get allNavItems =>
    [for (final group in adminNavigation) ...group.items];

/// The sidebar entry a location belongs to: "/users/123" lights up Users.
NavItem? navItemFor(String location) {
  if (location.startsWith('/users/')) {
    return allNavItems.firstWhere((item) => item.route == '/resources/users');
  }
  for (final item in allNavItems) {
    if (item.route == location) return item;
  }
  return null;
}

/// The group a destination sits in, for the breadcrumb.
String? navGroupFor(NavItem item) {
  for (final group in adminNavigation) {
    if (group.items.contains(item)) return group.title;
  }
  return null;
}
