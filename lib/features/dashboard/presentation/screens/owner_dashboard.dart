import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/data/company_repository.dart';
import '../../../company/domain/branch_model.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../closing/data/closing_repository.dart';
import '../../../closing/domain/closing_model.dart';
import '../widgets/activity_timeline_widget.dart';
import '../widgets/stat_card.dart';

// Branch selection provider
final selectedBranchIdProvider = StateProvider<String?>((ref) => null);

// Owner Dashboard Stats provider
final ownerDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final compRepo = ref.read(companyRepositoryProvider);
  final riderRepo = ref.read(riderRepositoryProvider);
  final attRepo = ref.read(attendanceRepositoryProvider);
  final closingRepo = ref.read(closingRepositoryProvider);

  // Get branches
  final branches = await compRepo.getBranches(user.companyId ?? 'co_test');
  if (branches.isEmpty) return {'branches': <BranchModel>[]};

  final selectedBranchId = ref.watch(selectedBranchIdProvider) ?? branches.first.id;

  // Fetch metrics in parallel
  final riders = await riderRepo.getRiders(user.companyId ?? 'co_test', selectedBranchId);
  final today = DateTime.now();
  final attendance = await attRepo.getAttendanceForDate(user.companyId ?? 'co_test', selectedBranchId, today);
  final closings = await closingRepo.getClosings(user.companyId ?? 'co_test', selectedBranchId);

  // Calculations
  final totalRiders = riders.length;
  final ridersPresent = attendance.where((a) => a.status.name == 'Present' || a.status.name == 'Late').length;
  final ridersAbsent = totalRiders - ridersPresent;

  double todayCash = 0.0;
  double todayUpi = 0.0;
  double todayShortages = 0.0;
  double outstandingAmount = 0.0;
  int pendingClosings = 0;
  int completedClosings = 0;

  // Filter closings for today
  final todayClosings = closings.where((c) =>
      c.date.year == today.year &&
      c.date.month == today.month &&
      c.date.day == today.day);

  for (var c in todayClosings) {
    if (c.status == ClosingStatus.approved) {
      todayCash += c.cashCollected;
      todayUpi += c.upiCollected;
      if (c.difference > 0) {
        todayShortages += c.difference;
      }
      completedClosings++;
    } else if (c.status == ClosingStatus.submitted) {
      pendingClosings++;
    }
  }

  for (var r in riders) {
    outstandingAmount += r.outstandingBalance;
  }

  return {
    'branches': branches,
    'selectedBranchId': selectedBranchId,
    'totalRiders': totalRiders,
    'ridersPresent': ridersPresent,
    'ridersAbsent': ridersAbsent,
    'todayCash': todayCash,
    'todayUpi': todayUpi,
    'todayShortages': todayShortages,
    'outstandingAmount': outstandingAmount,
    'pendingClosings': pendingClosings,
    'completedClosings': completedClosings,
  };
});

class OwnerDashboard extends ConsumerWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final statsAsync = ref.watch(ownerDashboardStatsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Owner Console',
          style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(ownerDashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final branches = stats['branches'] as List<BranchModel>? ?? [];
          if (branches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 64, color: AppTheme.primaryGold),
                    const SizedBox(height: 16),
                    const Text('No Branches Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Create your first branch in settings to view metrics.', textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => ref.read(authControllerProvider.notifier).logout(),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            );
          }

          final selectedBranchId = stats['selectedBranchId'] as String;
          final currentBranch = branches.firstWhere((b) => b.id == selectedBranchId);

          final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ownerDashboardStatsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Welcome Card & Branch Switcher
                  Card(
                    color: isDark ? const Color(0xFF161924) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                                radius: 24,
                                child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryGold),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Welcome back,',
                                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                    ),
                                    Text(
                                      user?.name ?? 'Owner',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          const Text(
                            'Active Branch',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.primaryGold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F111A) : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<String>(
                              value: selectedBranchId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: isDark ? const Color(0xFF161924) : Colors.white,
                              items: branches.map((b) {
                                return DropdownMenuItem(
                                  value: b.id,
                                  child: Text('${b.name} (${b.city})'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  ref.read(selectedBranchIdProvider.notifier).state = val;
                                  ref.invalidate(activityLogsProvider);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Metrics Grid
                  Text(
                    'Operational Metrics',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.35,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: [
                      StatCard(
                        title: 'Total Riders',
                        value: '${stats['totalRiders']}',
                        icon: Icons.directions_bike_rounded,
                        iconColor: AppTheme.primaryGold,
                        trendText: '${stats['ridersPresent']} Present Today',
                        isPositiveTrend: true,
                      ),
                      StatCard(
                        title: 'Outstanding',
                        value: currencyFormat.format(stats['outstandingAmount']),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppTheme.errorRed,
                        trendText: 'Due from Riders',
                        isPositiveTrend: false,
                      ),
                      StatCard(
                        title: 'Cash Collected',
                        value: currencyFormat.format(stats['todayCash']),
                        icon: Icons.payments_rounded,
                        iconColor: AppTheme.successGreen,
                        trendText: 'Today\'s Cash Handover',
                        isPositiveTrend: true,
                      ),
                      StatCard(
                        title: 'UPI Collected',
                        value: currencyFormat.format(stats['todayUpi']),
                        icon: Icons.qr_code_2_rounded,
                        iconColor: AppTheme.infoBlue,
                        trendText: 'Today\'s UPI Payments',
                        isPositiveTrend: true,
                      ),
                      StatCard(
                        title: 'Cash Shortages',
                        value: currencyFormat.format(stats['todayShortages']),
                        icon: Icons.trending_down_rounded,
                        iconColor: AppTheme.errorRed,
                        trendText: 'Discrepancy Today',
                        isPositiveTrend: false,
                      ),
                      StatCard(
                        title: 'Closings Status',
                        value: '${stats['completedClosings']} Done',
                        icon: Icons.lock_clock_outlined,
                        iconColor: AppTheme.warningSaffron,
                        trendText: '${stats['pendingClosings']} Pending Review',
                        isPositiveTrend: stats['pendingClosings'] == 0 ? true : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Activity Timeline Widget
                  ActivityTimelineWidget(
                    companyId: user?.companyId ?? 'co_test',
                    branchId: selectedBranchId,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading dashboard statistics: $err')),
      ),
    );
  }
}
