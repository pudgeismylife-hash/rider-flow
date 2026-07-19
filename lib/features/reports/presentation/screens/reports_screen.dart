import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../ledger/data/ledger_repository.dart';
import '../../../ledger/domain/transaction_model.dart';
import '../../../closing/data/closing_repository.dart';
import '../../../closing/domain/closing_model.dart';

final reportsDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  final closingRepo = ref.read(closingRepositoryProvider);
  final ledgerRepo = ref.read(ledgerRepositoryProvider);
  final riderRepo = ref.read(riderRepositoryProvider);

  final closings = await closingRepo.getClosings(companyId, branchId);
  final transactions = await ledgerRepo.getTransactions(companyId, branchId);
  final riders = await riderRepo.getRiders(companyId, branchId);

  return {
    'closings': closings,
    'transactions': transactions,
    'riders': riders,
  };
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsDataProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: dataAsync.when(
          data: (data) {
            final List<ClosingModel> closings = data['closings'] as List<ClosingModel>? ?? [];
            final List<TransactionModel> transactions = data['transactions'] as List<TransactionModel>? ?? [];
            final riders = data['riders'] as List<dynamic>? ?? [];

            if (closings.isEmpty && transactions.isEmpty) {
              return const Center(child: Text('Add transaction records to compile reports.'));
            }

            // Tally reports statistics
            double totalOutstanding = riders.fold(0.0, (sum, r) => sum + r.outstandingBalance);
            double totalCash = closings.where((c) => c.status == ClosingStatus.approved).fold(0.0, (sum, c) => sum + c.cashCollected);
            double totalUpi = closings.where((c) => c.status == ClosingStatus.approved).fold(0.0, (sum, c) => sum + c.upiCollected);
            double totalShortages = closings.where((c) => c.status == ClosingStatus.approved && c.difference > 0).fold(0.0, (sum, c) => sum + c.difference);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // KPI Grid
                  _buildKpiCard(context, 'Outstanding Balances', currencyFormat.format(totalOutstanding), AppTheme.errorRed),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildKpiCard(context, 'Total Cash', currencyFormat.format(totalCash), AppTheme.successGreen)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildKpiCard(context, 'Total UPI', currencyFormat.format(totalUpi), AppTheme.infoBlue)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Collections Trend line Chart
                  Text('Weekly Collections Trend', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildLineChartCard(isDark, closings),
                  const SizedBox(height: 24),

                  // Shortages bar chart
                  Text('Cash Shortages Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildBarChartCard(isDark, closings),
                  const SizedBox(height: 24),

                  // Outstanding balances summary
                  Text('Riders Outstanding Tally', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: riders.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rider = riders[index];
                        final balance = rider.outstandingBalance;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGold.withOpacity(0.12),
                            child: Text(rider.name.substring(0, 1)),
                          ),
                          title: Text(rider.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('ID: ${rider.employeeId}'),
                          trailing: Text(
                            currencyFormat.format(balance),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: balance > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error loading charts: $err')),
        ),
      ),
    );
  }

  Widget _buildKpiCard(BuildContext context, String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      color: isDark ? const Color(0xFF161924) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChartCard(bool isDark, List<ClosingModel> closings) {
    // Collect last 5 closings data points
    final sorted = closings.where((c) => c.status == ClosingStatus.approved).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final displayPoints = sorted.take(5).toList();

    List<FlSpot> cashSpots = [];
    List<FlSpot> upiSpots = [];

    for (int i = 0; i < displayPoints.length; i++) {
      cashSpots.add(FlSpot(i.toDouble(), displayPoints[i].cashCollected / 1000));
      upiSpots.add(FlSpot(i.toDouble(), displayPoints[i].upiCollected / 1000));
    }

    if (cashSpots.isEmpty) {
      cashSpots = [const FlSpot(0, 0), const FlSpot(1, 2), const FlSpot(2, 1.5)];
      upiSpots = [const FlSpot(0, 0), const FlSpot(1, 1), const FlSpot(2, 2.5)];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChartLegendItem('Cash (x1000)', AppTheme.successGreen),
                SizedBox(width: 16),
                _ChartLegendItem('UPI (x1000)', AppTheme.infoBlue),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: cashSpots,
                      isCurved: true,
                      color: AppTheme.successGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                    LineChartBarData(
                      spots: upiSpots,
                      isCurved: true,
                      color: AppTheme.infoBlue,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChartCard(bool isDark, List<ClosingModel> closings) {
    final approvedClosings = closings.where((c) => c.status == ClosingStatus.approved).toList();
    
    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < approvedClosings.length; i++) {
      final c = approvedClosings[i];
      if (c.difference > 0) {
        barGroups.add(
          BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: c.difference,
                color: AppTheme.errorRed,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      }
    }

    if (barGroups.isEmpty) {
      // Mock shortage rods
      barGroups = [
        BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 200, color: AppTheme.errorRed, width: 14)]),
        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 0, color: AppTheme.errorRed, width: 14)]),
        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 500, color: AppTheme.errorRed, width: 14)]),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ChartLegendItem('Shortages (₹)', AppTheme.errorRed),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _ChartLegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
