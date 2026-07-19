import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_shell.dart';
import '../../features/rider/presentation/screens/add_rider_screen.dart';
import '../../features/rider/presentation/screens/rider_list_screen.dart';
import '../../features/rider/presentation/screens/rider_profile_screen.dart';
import '../../features/attendance/presentation/screens/attendance_calendar_screen.dart';
import '../../features/attendance/presentation/screens/attendance_report_screen.dart';
import '../../features/attendance/presentation/screens/mark_attendance_screen.dart';
import '../../features/ledger/presentation/screens/add_transaction_screen.dart';
import '../../features/ledger/presentation/screens/ledger_screen.dart';
import '../../features/closing/presentation/screens/daily_closing_screen.dart';
import '../../features/closing/presentation/screens/manager_closing_review_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

// Create a helper class to listen to Riverpod state changes inside GoRouter
class RouterTransitionNotifier extends ChangeNotifier {
  final Ref _ref;
  VoidCallback? _subscription;

  RouterTransitionNotifier(this._ref) {
    _ref.listen<AsyncValue<UserModel?>>(
      authControllerProvider,
      (previous, next) {
        notifyListeners();
      },
    );
  }
}

final routerNotifierProvider = Provider<RouterTransitionNotifier>((ref) {
  return RouterTransitionNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) {
      final user = authState.valueOrNull;
      final isLoggingIn = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/otp';
      final isOnboarding = state.matchedLocation == '/onboarding';

      // 1. Not Authenticated: Redirect to Login
      if (user == null) {
        if (!isLoggingIn) return '/login';
        return null;
      }

      // 2. Authenticated but Pending Onboarding: Redirect to Onboarding
      if (user.status == 'pending') {
        if (!isOnboarding) return '/onboarding';
        return null;
      }

      // 3. Authenticated & Onboarded, but trying to access auth screens: redirect to dashboard
      if (isLoggingIn || isOnboarding) {
        return '/';
      }

      // No redirect needed
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      // Dashboard Shell that embeds the different screens using sub-routes
      ShellRoute(
        builder: (context, state, child) {
          return DashboardShell(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardShellChildRouter(),
          ),
          GoRoute(
            path: '/riders',
            builder: (context, state) => const RiderListScreen(),
          ),
          GoRoute(
            path: '/riders/add',
            builder: (context, state) => const AddRiderScreen(),
          ),
          GoRoute(
            path: '/riders/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return RiderProfileScreen(riderId: id);
            },
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const MarkAttendanceScreen(),
          ),
          GoRoute(
            path: '/attendance/calendar',
            builder: (context, state) => const AttendanceCalendarScreen(),
          ),
          GoRoute(
            path: '/attendance/report',
            builder: (context, state) => const AttendanceReportScreen(),
          ),
          GoRoute(
            path: '/ledger',
            builder: (context, state) => const LedgerScreen(),
          ),
          GoRoute(
            path: '/ledger/add',
            builder: (context, state) {
              final riderId = state.extra as String? ?? '';
              return AddTransactionScreen(riderId: riderId);
            },
          ),
          GoRoute(
            path: '/closing',
            builder: (context, state) => const DailyClosingScreen(),
          ),
          GoRoute(
            path: '/closing/review',
            builder: (context, state) => const ManagerClosingReviewScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
