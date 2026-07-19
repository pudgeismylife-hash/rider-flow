import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../attendance/domain/attendance_model.dart';
import '../../../ledger/data/ledger_repository.dart';
import '../../../ledger/domain/transaction_model.dart';
import '../../../closing/data/closing_repository.dart';
import '../../../closing/domain/closing_model.dart';
import '../widgets/activity_timeline_widget.dart';
import '../widgets/stat_card.dart';

// Rider Dashboard Stats Provider
final riderDashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final riderRepo = ref.read(riderRepositoryProvider);
  final attRepo = ref.read(attendanceRepositoryProvider);
  final ledgerRepo = ref.read(ledgerRepositoryProvider);
  final closingRepo = ref.read(closingRepositoryProvider);

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';
  final riderId = user.uid;

  // Parallel fetches
  final rider = await riderRepo.getRider(companyId, branchId, riderId);
  final today = DateTime.now();
  final attendance = await attRepo.getAttendanceForRider(companyId, branchId, riderId);
  final closings = await closingRepo.getRiderClosings(companyId, branchId, riderId);
  final txs = await ledgerRepo.getRiderTransactions(companyId, branchId, riderId);

  // Check today's status
  AttendanceModel? todayAttendance;
  try {
    todayAttendance = attendance.firstWhere((a) =>
        a.date.year == today.year &&
        a.date.month == today.month &&
        a.date.day == today.day);
  } catch (_) {}

  ClosingModel? todayClosing;
  try {
    todayClosing = closings.firstWhere((c) =>
        c.date.year == today.year &&
        c.date.month == today.month &&
        c.date.day == today.day);
  } catch (_) {}

  return {
    'rider': rider,
    'todayAttendance': todayAttendance,
    'todayClosing': todayClosing,
    'transactions': txs.take(3).toList(),
  };
});

class RiderDashboard extends ConsumerWidget {
  const RiderDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final statsAsync = ref.watch(riderDashboardStatsProvider);
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Rider Console',
          style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(riderDashboardStatsProvider),
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final rider = stats['rider'];
          final AttendanceModel? todayAttendance = stats['todayAttendance'];
          final ClosingModel? todayClosing = stats['todayClosing'];
          final txs = stats['transactions'] as List<TransactionModel>? ?? [];

          final outstandingBalance = rider?.outstandingBalance ?? 0.0;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(riderDashboardStatsProvider),
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
                            child: const Icon(Icons.directions_bike_rounded, color: AppTheme.primaryGold),
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
                                  user?.name ?? 'Rider',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Outstanding Balance Card (Highlight)
                  _buildBalanceHighlightCard(context, outstandingBalance, currencyFormat),
                  const SizedBox(height: 20),

                  // 3. Action Cards (Attendance and Closing status)
                  Text(
                    'Daily Checklist',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Attendance Card Action
                      Expanded(
                        child: _buildChecklistCard(
                          context,
                          title: 'Morning Attendance',
                          subtitle: todayAttendance != null 
                              ? 'Marked: ${todayAttendance.status.name}' 
                              : 'Please check-in',
                          icon: Icons.how_to_reg_rounded,
                          color: todayAttendance != null ? AppTheme.successGreen : AppTheme.warningSaffron,
                          onTap: () => context.push('/attendance'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Closing Card Action
                      Expanded(
                        child: _buildChecklistCard(
                          context,
                          title: 'Evening Closing',
                          subtitle: todayClosing != null 
                              ? 'Status: ${todayClosing.status.name}' 
                              : 'Pending submission',
                          icon: Icons.lock_clock_outlined,
                          color: todayClosing != null 
                              ? (todayClosing.status == ClosingStatus.approved ? AppTheme.successGreen : AppTheme.infoBlue) 
                              : AppTheme.errorRed,
                          onTap: () => context.push('/closing'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. Quick Mini-Ledger Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Transactions',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => context.go('/ledger'),
                        child: const Text('View All', style: TextStyle(color: AppTheme.primaryGold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (txs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: Text('No transaction history found.')),
                      ),
                    )
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txs.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          final isCredit = tx.type == TransactionType.paymentReceived;
                          return ListTile(
                            leading: Icon(
                              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                              color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                            ),
                            title: Text(tx.type.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(DateFormat('dd MMM hh:mm a').format(tx.timestamp)),
                            trailing: Text(
                              '${isCredit ? "-" : "+"}${currencyFormat.format(tx.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // 5. Activity Timeline
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

  Widget _buildBalanceHighlightCard(
      BuildContext context, double balance, NumberFormat currencyFormat) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Check if rider owes money or is in credit
    final owesMoney = balance >= 0;
    final absBalance = balance.abs();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: owesMoney
              ? [const Color(0xFF1B1D2A), const Color(0xFF161924)]
              : [AppTheme.successGreen.withOpacity(0.15), AppTheme.successGreen.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: owesMoney ? AppTheme.primaryGold.withOpacity(0.3) : AppTheme.successGreen.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: owesMoney ? AppTheme.primaryGold.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            owesMoney ? 'OUTSTANDING BALANCE' : 'CREDIT BALANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: owesMoney ? AppTheme.primaryGold : AppTheme.successGreen,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(absBalance),
            style: theme.textTheme.displayMedium?.copyWith(
              fontSize: 36,
              color: owesMoney ? Colors.white : AppTheme.successGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            owesMoney
                ? 'This balance must be settled during daily handovers.'
                : 'Excellent! You have deposited extra collection cash.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistCard(
    BuildContext context, {
    required String title,
    required String subtitle,
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
