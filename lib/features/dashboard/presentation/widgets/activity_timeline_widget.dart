import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/domain/activity_log.dart';

class ActivityTimelineWidget extends ConsumerWidget {
  final String companyId;
  final String branchId;
  final int maxItems;

  const ActivityTimelineWidget({
    super.key,
    required this.companyId,
    required this.branchId,
    this.maxItems = 5,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsFuture = ref.watch(activityLogsProvider(ActivityLogParams(companyId, branchId)));

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Activity Timeline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    // Force refresh logs
                    ref.invalidate(activityLogsProvider);
                  },
                  child: const Text('Refresh', style: TextStyle(color: AppTheme.primaryGold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            logsFuture.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(child: Text('No actions recorded today.')),
                  );
                }
                final displayLogs = logs.take(maxItems).toList();
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayLogs.length,
                  itemBuilder: (context, index) {
                    final log = displayLogs[index];
                    final isLast = index == displayLogs.length - 1;
                    return _buildTimelineItem(context, log, isLast);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error loading activity feed: $err'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, ActivityLog log, bool isLast) {
    final timeStr = DateFormat('hh:mm a').format(log.timestamp);
    final dateStr = DateFormat('dd MMM').format(log.timestamp);
    final theme = Theme.of(context);

    Color nodeColor = AppTheme.primaryGold;
    IconData icon = Icons.info_outline_rounded;

    if (log.action.toLowerCase().contains('attendance')) {
      nodeColor = AppTheme.successGreen;
      icon = Icons.how_to_reg_rounded;
    } else if (log.action.toLowerCase().contains('advance')) {
      nodeColor = AppTheme.infoBlue;
      icon = Icons.monetization_on_outlined;
    } else if (log.action.toLowerCase().contains('shortage')) {
      nodeColor = AppTheme.errorRed;
      icon = Icons.trending_down_rounded;
    } else if (log.action.toLowerCase().contains('closing')) {
      nodeColor = AppTheme.warningSaffron;
      icon = Icons.lock_clock_outlined;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Timestamps
          Column(
            children: [
              Text(
                timeStr,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                dateStr,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Center: Line and Node
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: nodeColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: nodeColor, width: 1.5),
                ),
                child: Icon(icon, size: 14, color: nodeColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: nodeColor.withOpacity(0.3),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
          const SizedBox(width: 16),
          // Right side: Log Content text
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.action,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By ${log.actorName} (${log.actorRole})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Params definition for Riverpod Family provider
class ActivityLogParams {
  final String companyId;
  final String branchId;
  ActivityLogParams(this.companyId, this.branchId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActivityLogParams &&
          other.runtimeType == other.runtimeType &&
          other.companyId == companyId &&
          other.branchId == branchId;

  @override
  int get hashCode => companyId.hashCode ^ branchId.hashCode;
}

final activityLogsProvider = FutureProvider.family<List<ActivityLog>, ActivityLogParams>((ref, params) async {
  final repo = ref.watch(activityLogRepositoryProvider);
  return repo.getLogs(params.companyId, params.branchId);
});
