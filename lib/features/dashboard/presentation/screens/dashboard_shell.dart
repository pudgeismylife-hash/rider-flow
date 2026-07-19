import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import 'owner_dashboard.dart';
import 'manager_dashboard.dart';
import 'rider_dashboard.dart';

// Dynamically chooses the dashboard child page based on the current user's role
class DashboardShellChildRouter extends ConsumerWidget {
  const DashboardShellChildRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (user.role) {
      case UserRole.owner:
        return const OwnerDashboard();
      case UserRole.manager:
        return const ManagerDashboard();
      case UserRole.rider:
        return const RiderDashboard();
    }
  }
}

// Shell Container containing App Layout and Navigation
class DashboardShell extends ConsumerWidget {
  final Widget child;

  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    final location = GoRouterState.of(context).matchedLocation;

    if (user == null) {
      return Scaffold(body: child);
    }

    // Determine bottom nav indices based on role
    final index = _getSelectedIndex(location, user.role);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => _onItemTapped(context, value, user.role),
        destinations: _getNavDestinations(user.role),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.cardDark 
            : Colors.white,
        indicatorColor: AppTheme.primaryGold.withOpacity(0.2),
      ),
      floatingActionButton: _buildFloatingActionButton(context, user),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  int _getSelectedIndex(String location, UserRole role) {
    if (location == '/') return 0;
    
    if (role == UserRole.owner || role == UserRole.manager) {
      if (location.startsWith('/riders')) return 1;
      if (location.startsWith('/reports')) return 2;
      if (location.startsWith('/notifications')) return 3;
      if (location.startsWith('/settings')) return 4;
    } else {
      // Rider navigation items
      if (location.startsWith('/ledger')) return 1;
      if (location.startsWith('/closing')) return 2;
      if (location.startsWith('/notifications')) return 3;
      if (location.startsWith('/settings')) return 4;
    }
    return 0;
  }

  void _onItemTapped(BuildContext context, int index, UserRole role) {
    if (role == UserRole.owner || role == UserRole.manager) {
      switch (index) {
        case 0: context.go('/'); break;
        case 1: context.go('/riders'); break;
        case 2: context.go('/reports'); break;
        case 3: context.go('/notifications'); break;
        case 4: context.go('/settings'); break;
      }
    } else {
      switch (index) {
        case 0: context.go('/'); break;
        case 1: context.go('/ledger'); break;
        case 2: context.go('/closing'); break;
        case 3: context.go('/notifications'); break;
        case 4: context.go('/settings'); break;
      }
    }
  }

  List<NavigationDestination> _getNavDestinations(UserRole role) {
    if (role == UserRole.owner || role == UserRole.manager) {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryGold),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_bike_outlined),
          selectedIcon: Icon(Icons.directions_bike, color: AppTheme.primaryGold),
          label: 'Riders',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart, color: AppTheme.primaryGold),
          label: 'Reports',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications, color: AppTheme.primaryGold),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: AppTheme.primaryGold),
          label: 'Settings',
        ),
      ];
    } else {
      return const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryGold),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primaryGold),
          label: 'Ledger',
        ),
        NavigationDestination(
          icon: Icon(Icons.lock_clock_outlined),
          selectedIcon: Icon(Icons.lock_clock, color: AppTheme.primaryGold),
          label: 'Closing',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications, color: AppTheme.primaryGold),
          label: 'Alerts',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings, color: AppTheme.primaryGold),
          label: 'Settings',
        ),
      ];
    }
  }

  Widget? _buildFloatingActionButton(BuildContext context, UserModel user) {
    // Return floating action buttons contextually based on user permissions
    switch (user.role) {
      case UserRole.owner:
        return FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.add_alert_rounded),
          label: const Text('New Alert'),
          onPressed: () => context.push('/notifications'),
        );
      case UserRole.manager:
        return FloatingActionButton.extended(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.black,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Rider'),
          onPressed: () => context.push('/riders/add'),
        );
      case UserRole.rider:
        return FloatingActionButton(
          backgroundColor: AppTheme.primaryGold,
          foregroundColor: Colors.black,
          child: const Icon(Icons.how_to_reg_rounded),
          onPressed: () => context.push('/attendance'),
        );
    }
  }
}
