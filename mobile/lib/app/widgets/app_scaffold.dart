import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/l10n/app_localizations.dart';
import '../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onTap,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.dashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(Icons.people_rounded),
              label: l10n.customers,
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long_rounded),
              label: l10n.ledger,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_rounded),
              selectedIcon: const Icon(Icons.menu_open_rounded),
              label: l10n.more,
            ),
          ],
        ),
      ),
    );
  }
}
