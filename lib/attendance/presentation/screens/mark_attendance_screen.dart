import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/screens/rider_dashboard.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_model.dart';
import 'attendance_calendar_screen.dart';

class MarkAttendanceScreen extends ConsumerStatefulWidget {
  const MarkAttendanceScreen({super.key});

  @override
  ConsumerState<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends ConsumerState<MarkAttendanceScreen> {
  AttendanceStatus _selectedStatus = AttendanceStatus.present;
  
  // Location & Selfie verification states
  double? _latitude;
  double? _longitude;
  bool _isFetchingLocation = false;
  String? _locationStatus;

  String? _selfiePath;
  bool _isTakingSelfie = false;

  bool _isSubmitting = false;

  // Simulate fetching GPS coordinates
  Future<void> _fetchGPSCoordinates() async {
    setState(() {
      _isFetchingLocation = true;
      _locationStatus = 'Locating GPS satellites...';
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _latitude = 12.9715987 + (math.Random().nextDouble() - 0.5) * 0.01;
      _longitude = 77.5945627 + (math.Random().nextDouble() - 0.5) * 0.01;
      _locationStatus = 'Coordinates retrieved successfully ✔';
      _isFetchingLocation = false;
    });
  }

  // Simulate capturing selfie picture
  Future<void> _captureSelfie() async {
    setState(() {
      _isTakingSelfie = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    setState(() {
      final stamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      _selfiePath = 'storage://selfie/selfie_$stamp.jpg';
      _isTakingSelfie = false;
    });
  }

  Future<void> _submitAttendance() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your GPS Location before marking attendance.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (_selfiePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selfie verification is mandatory. Please snap a selfie.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    final attendance = AttendanceModel(
      id: 'att_${user.uid}_${DateTime.now().millisecondsSinceEpoch}',
      riderId: user.uid,
      riderName: user.name,
      date: DateTime.now(),
      status: _selectedStatus,
      timestamp: DateTime.now(),
      latitude: _latitude,
      longitude: _longitude,
      selfieUrl: _selfiePath,
    );

    try {
      final attRepo = ref.read(attendanceRepositoryProvider);
      await attRepo.markAttendance(companyId, branchId, attendance);

      // Log action to activity timeline
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logAction(
        companyId: companyId,
        branchId: branchId,
        action: 'Attendance Marked: ${_selectedStatus.name}',
        actorName: user.name,
        actorRole: user.role.name,
        referenceId: attendance.id,
      );

      ref.invalidate(riderDashboardStatsProvider);
      ref.invalidate(riderAttendanceHistoryProvider);
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance recorded as ${_selectedStatus.name}'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark attendance: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    // Check if rider already checked in today (optional validation display)
    // To keep simple, we read rider dashboard stats
    final dashboardStats = ref.watch(riderDashboardStatsProvider);
    AttendanceModel? todayAttendance;
    if (dashboardStats.hasValue) {
      todayAttendance = dashboardStats.value!['todayAttendance'];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryGold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              if (todayAttendance != null) ...[
                // Already marked card
                _buildAlreadyMarkedCard(context, todayAttendance),
              ] else ...[
                Text(
                  'Record Today\'s Attendance',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Status Choices Row
                Row(
                  children: [
                    Expanded(child: _buildStatusRadio(AttendanceStatus.present, Icons.check_circle_outline_rounded, AppTheme.successGreen)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusRadio(AttendanceStatus.late, Icons.alarm_rounded, AppTheme.warningSaffron)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatusRadio(AttendanceStatus.notWorking, Icons.cancel_outlined, AppTheme.errorRed)),
                  ],
                ),
                const SizedBox(height: 28),

                // GPS Location Module
                _buildVerificationHeader('1. GPS Location Check-in'),
                const SizedBox(height: 12),
                _buildLocationCard(isDark),
                const SizedBox(height: 24),

                // Selfie Capture Module
                _buildVerificationHeader('2. Biometric Selfie Capture'),
                const SizedBox(height: 12),
                _buildSelfieCard(isDark),

                const SizedBox(height: 48),
                CustomButton(
                  text: 'Submit Attendance Check-In',
                  isLoading: _isSubmitting,
                  onPressed: _submitAttendance,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGold, letterSpacing: 0.5),
    );
  }

  Widget _buildStatusRadio(AttendanceStatus status, IconData icon, Color color) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 28),
            const SizedBox(height: 8),
            Text(
              status.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(bool isDark) {
    final hasGPS = _latitude != null && _longitude != null;
    return Card(
      color: isDark ? const Color(0xFF161924) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              hasGPS ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
              color: hasGPS ? AppTheme.successGreen : AppTheme.errorRed,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GPS Verification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    hasGPS 
                        ? 'Lat: ${_latitude!.toStringAsFixed(5)}, Lon: ${_longitude!.toStringAsFixed(5)}' 
                        : (_locationStatus ?? 'GPS location required.'),
                    style: TextStyle(fontSize: 11, color: hasGPS ? AppTheme.successGreen : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasGPS ? AppTheme.successGreen.withOpacity(0.15) : AppTheme.primaryGold.withOpacity(0.15),
                foregroundColor: hasGPS ? AppTheme.successGreen : AppTheme.primaryGold,
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isFetchingLocation ? null : _fetchGPSCoordinates,
              child: _isFetchingLocation 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)) 
                  : Text(hasGPS ? 'Refresh' : 'Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfieCard(bool isDark) {
    final hasSelfie = _selfiePath != null;
    return Card(
      color: isDark ? const Color(0xFF161924) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: hasSelfie ? AppTheme.successGreen : Colors.grey.shade600),
              ),
              child: hasSelfie
                  ? const Icon(Icons.face_retouching_natural_rounded, color: AppTheme.successGreen)
                  : const Icon(Icons.photo_camera_back_outlined, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selfie Check-in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    hasSelfie ? 'Selfie capture complete ✔' : 'Take a selfie verification photo.',
                    style: TextStyle(fontSize: 11, color: hasSelfie ? AppTheme.successGreen : Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelfie ? AppTheme.successGreen.withOpacity(0.15) : AppTheme.primaryGold.withOpacity(0.15),
                foregroundColor: hasSelfie ? AppTheme.successGreen : AppTheme.primaryGold,
                minimumSize: const Size(80, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isTakingSelfie ? null : _captureSelfie,
              child: _isTakingSelfie 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)) 
                  : Text(hasSelfie ? 'Retake' : 'Snap'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyMarkedCard(BuildContext context, AttendanceModel attendance) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(attendance.timestamp);
    
    Color statusColor = AppTheme.successGreen;
    if (attendance.status == AttendanceStatus.late) statusColor = AppTheme.warningSaffron;
    if (attendance.status == AttendanceStatus.notWorking) statusColor = AppTheme.errorRed;

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.successGreen.withOpacity(0.2), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 72,
              color: AppTheme.successGreen,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Attendance Completed',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your attendance for today has already been recorded.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        attendance.status.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('MARKED AT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          CustomButton(
            text: 'View Attendance Calendar',
            type: ButtonType.outline,
            onPressed: () => context.push('/attendance/calendar'),
          ),
        ],
      ),
    );
  }
}
// Add Math import helper for random calculations
class math {
  static double get pi => 3.1415926535897932;
  static math.Random Random() => math.Random();
}
