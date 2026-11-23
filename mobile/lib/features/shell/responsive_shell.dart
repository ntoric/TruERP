import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/session_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _dests = [
  _Dest('Home', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Dest('Sales', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  _Dest('Purchases', Icons.shopping_bag_outlined, Icons.shopping_bag_rounded),
  _Dest('Parties', Icons.groups_outlined, Icons.groups_rounded),
  _Dest('More', Icons.apps_outlined, Icons.apps_rounded),
];

/// Bottom navigation on phones, a navigation rail on tablets
/// (labels shown on wide screens).
class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  void _go(int i) =>
      shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    // Keying on the store makes every tab rebuild (and refetch) after a switch.
    final storeId = ref.watch(activeStoreIdProvider);
    final body = KeyedSubtree(key: ValueKey(storeId), child: shell);

    if (width < Breakpoints.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in _dests)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= Breakpoints.expanded;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              extended: extended,
              minExtendedWidth: 200,
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                child: extended
                    ? Row(
                        children: [
                          Image.asset('assets/logo.png', height: 32),
                          const SizedBox(width: Spacing.sm),
                          Text('TruERP', style: context.text.titleMedium),
                        ],
                      )
                    : Image.asset('assets/logo.png', height: 32),
              ),
              destinations: [
                for (final d in _dests)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: context.colors.outlineVariant),
          Expanded(child: body),
        ],
      ),
    );
  }
}
