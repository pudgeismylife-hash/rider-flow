import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../closing/data/closing_repository.dart';
import '../../../closing/domain/closing_model.dart';
import '../widgets/activity_timeline_widget.dart';
import '../widgets/stat_card.dart';

// Manager Dashboard stats provider
final managerDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final riderRepo = ref.read(riderRepositoryProvider);
  final attRepo = ref.read(attendanceRepositoryProvider);
  final closingRepo = ref.read(closingRepositoryProvider);

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  // Parallel fetching
  final riders = await riderRepo.getRiders(companyId, branchId);
  final today = DateTime.now();
  final attendance = await attRepo.getAttendanceForDate(companyId, branchId, today);
  final closings = await closingRepo.getClosings(companyId, branchId);

  // Calculations
  final totalRiders = riders.length;
  final ridersPresent = attendance.where((a) => a.status.name == 'Present' || a.status.name == 'Late').length;
  final ridersAbsent = totalRiders - ridersPresent;

  double todayCash = 0.0;
  double todayUpi = 0.0;
  double todayShortages = 0.0;
  double outstandingAmount = 0.0;
  
  final List<ClosingModel> pendingApprovals = [];
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
      pendingApprovals.add(c);
    }
  }

  // Double check all submitted closings (even older ones) that are pending review
  final allPending = closings.where((c) => c.status == ClosingStatus.submitted).toList();

  for (var r in riders) {
    outstandingAmount += r.outstandingBalance;
  }

  return {
    'totalRiders': totalRiders,
    'ridersPresent': ridersPresent,
    'ridersAbsent': ridersAbsent,
    'todayCash': todayCash,
    'todayUpi': todayUpi,
    'todayShortages': todayShortages,
    'outstandingAmount': outstandingAmount,
    'pendingApprovalsList': allPending,
    'completedClosings': completedClosings,
  };
});

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final statsAsync = ref.watch(managerDashboardStatsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manager Console',
          style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(managerDashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final pendingApprovals = stats['pendingApprovalsList'] as List<ClosingModel>? ?? [];

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(managerDashboardStatsProvider),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Welcome Card
                  Card(
                    color: isDark ? const Color(0xFF161924) : Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                            radius: 24,
                            child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryGold),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Active Session',
                                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                ),
                                Text(
                                  user?.name ?? 'Branch Manager',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick Action Grid Shortcuts
                  Text(
                    'Quick Actions',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildShortcutButton(
                          context,
                          label: 'Attendance',
                          icon: Icons.how_to_reg_rounded,
                          color: AppTheme.successGreen,
                          onTap: () => context.push('/attendance'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildShortcutButton(
                          context,
                          label: 'Add Advance',
                          icon: Icons.add_card_rounded,
                          color: AppTheme.infoBlue,
                          onTap: () => context.push('/ledger/add'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildShortcutButton(
                          context,
                          label: 'Closing Queue',
                          icon: Icons.checklist_rtl_rounded,
                          color: AppTheme.warningSaffron,
                          onTap: () => context.push('/closing/review'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 2. Metrics Grid
                  Text(
                    'Today\'s Stats',
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
                        title: 'Present Today',
                        value: '${stats['ridersPresent']} / ${stats['totalRiders']}',
                        icon: Icons.directions_bike_rounded,
                        iconColor: AppTheme.primaryGold,
                        trendText: '${stats['ridersAbsent']} Not Working',
                        isPositiveTrend: stats['ridersAbsent'] == 0 ? true : null,
                      ),
                      StatCard(
                        title: 'Outstanding Due',
                        value: currencyFormat.format(stats['outstandingAmount']),
                        icon: Icons.account_balance_wallet_outlined,
                        iconColor: AppTheme.errorRed,
                        trendText: 'Branch Outstanding',
                        isPositiveTrend: false,
                      ),
                      StatCard(
                        title: 'Today Collection',
                        value: currencyFormat.format(stats['todayCash']),
                        icon: Icons.payments_rounded,
                        iconColor: AppTheme.successGreen,
                        trendText: 'Handover Completed',
                        isPositiveTrend: true,
                      ),
                      StatCard(
                        title: 'Today UPI',
                        value: currencyFormat.format(stats['todayUpi']),
                        icon: Icons.qr_code_2_rounded,
                        iconColor: AppTheme.infoBlue,
                        trendText: 'Today\'s UPI Payments',
                        isPositiveTrend: true,
                      ),
                      StatCard(
                        title: 'Today Shortage',
                        value: currencyFormat.format(stats['todayShortages']),
                        icon: Icons.trending_down_rounded,
                        iconColor: AppTheme.errorRed,
                        trendText: 'Closing Shortages',
                        isPositiveTrend: false,
                      ),
                      StatCard(
                        title: 'Pending Closing',
                        value: '${pendingApprovals.length}',
                        icon: Icons.lock_clock_outlined,
                        iconColor: AppTheme.warningSaffron,
                        trendText: 'Requires Approval',
                        isPositiveTrend: pendingApprovals.isEmpty ? true : false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 3. Pending Closings Section (If any exist)
                  if (pendingApprovals.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pending Closings Review',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningSaffron,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push('/closing/review'),
                          child: const Text('Review All', style: TextStyle(color: AppTheme.primaryGold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingApprovals.length,
                      itemBuilder: (context, index) {
                        final closing = pendingApprovals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.warningSaffron.withOpacity(0.15),
                              child: const Icon(Icons.history_toggle_off_rounded, color: AppTheme.warningSaffron),
                            ),
                            title: Text(closing.riderName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Cash Coll: ₹${closing.cashCollected} | UPI: ₹${closing.upiCollected}'),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => context.push('/closing/review'),
                              child: const Text('Review', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 4. Activity Timeline
                  ActivityTimelineWidget(
                    companyId: user?.companyId ?? 'co_test',
                    branchId: user?.branchId ?? 'br_test',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading dashboard: $err')),
      ),
    );
  }

  Widget _buildShortcutButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF161924) : Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
