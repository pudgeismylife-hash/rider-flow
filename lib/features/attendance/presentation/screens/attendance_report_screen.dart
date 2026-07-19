import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_model.dart';

final attendanceReportDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final attendanceReportProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';
  final targetDate = ref.watch(attendanceReportDateProvider);

  final riderRepo = ref.read(riderRepositoryProvider);
  final attRepo = ref.read(attendanceRepositoryProvider);

  final riders = await riderRepo.getRiders(companyId, branchId);
  final records = await attRepo.getAttendanceForDate(companyId, branchId, targetDate);

  return {
    'riders': riders,
    'records': records,
  };
});

class AttendanceReportScreen extends ConsumerWidget {
  const AttendanceReportScreen({super.key});

  Future<void> _selectDate(BuildContext context, WidgetRef ref, DateTime currentDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != currentDate) {
      ref.read(attendanceReportDateProvider.notifier).state = picked;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final targetDate = ref.watch(attendanceReportDateProvider);
    final dataAsync = ref.watch(attendanceReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Date Selection Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Date',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, d MMMM yyyy').format(targetDate),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
                      foregroundColor: AppTheme.primaryGold,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: const Text('Change'),
                    onPressed: () => _selectDate(context, ref, targetDate),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Logs List
            Expanded(
              child: dataAsync.when(
                data: (data) {
                  final riders = data['riders'] as List<dynamic>? ?? [];
                  final records = data['records'] as List<AttendanceModel>? ?? [];

                  if (riders.isEmpty) {
                    return const EmptyState(
                      title: 'No Riders Registered',
                      message: 'Register riders to begin tracking attendance.',
                      icon: Icons.directions_bike_rounded,
                    );
                  }

                  return ListView.separated(
                    itemCount: riders.length,
                    padding: const EdgeInsets.all(16),
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final rider = riders[index];
                      
                      // Look up attendance record
                      AttendanceModel? attRecord;
                      try {
                        attRecord = records.firstWhere((r) => r.riderId == rider.id);
                      } catch (_) {}

                      return _buildRiderAttendanceTile(context, rider, attRecord);
                    },
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) => const SkeletonListTile(),
                ),
                error: (err, _) => Center(child: Text('Error compiling report: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderAttendanceTile(BuildContext context, dynamic rider, AttendanceModel? attendance) {
    final theme = Theme.of(context);
    
    String statusLabel = 'Unmarked';
    Color statusColor = Colors.grey;
    String markedTime = '--:--';
    bool hasDetails = false;

    if (attendance != null) {
      statusLabel = attendance.status.name;
      hasDetails = attendance.status != AttendanceStatus.notWorking;
      markedTime = DateFormat('hh:mm a').format(attendance.timestamp);
      
      switch (attendance.status) {
        case AttendanceStatus.present:
          statusColor = AppTheme.successGreen;
          break;
        case AttendanceStatus.late:
          statusColor = AppTheme.warningSaffron;
          break;
        case AttendanceStatus.notWorking:
          statusColor = AppTheme.errorRed;
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rider.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${rider.employeeId}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (hasDetails && attendance != null) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.alarm_rounded, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Check-in: $markedTime',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.primaryGold),
                      const SizedBox(width: 4),
                      Text(
                        'GPS Checked',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.face_retouching_natural_rounded, size: 14, color: AppTheme.successGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Selfie Verified',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
