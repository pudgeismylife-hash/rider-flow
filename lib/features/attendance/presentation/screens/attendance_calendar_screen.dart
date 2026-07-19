import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../rider/domain/rider_model.dart';
import '../../data/attendance_repository.dart';
import '../../domain/attendance_model.dart';

final riderAttendanceHistoryProvider = FutureProvider.family.autoDispose<List<AttendanceModel>, String>((ref, riderId) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  final repo = ref.read(attendanceRepositoryProvider);
  return repo.getAttendanceForRider(companyId, branchId, riderId);
});

final calendarTargetRiderIdProvider = StateProvider<String?>((ref) => null);

class AttendanceCalendarScreen extends ConsumerStatefulWidget {
  const AttendanceCalendarScreen({super.key});

  @override
  ConsumerState<AttendanceCalendarScreen> createState() => _AttendanceCalendarScreenState();
}

class _AttendanceCalendarScreenState extends ConsumerState<AttendanceCalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  List<RiderModel> _riders = [];
  bool _isLoadingRiders = false;

  @override
  void initState() {
    super.initState();
    _loadRidersDropdown();
  }

  Future<void> _loadRidersDropdown() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null || user.role == UserRole.rider) return;

    setState(() => _isLoadingRiders = true);
    try {
      final riderRepo = ref.read(riderRepositoryProvider);
      final list = await riderRepo.getRiders(user.companyId ?? 'co_test', user.branchId ?? 'br_test');
      setState(() {
        _riders = list;
      });
      if (list.isNotEmpty) {
        ref.read(calendarTargetRiderIdProvider.notifier).state = list.first.id;
      }
    } catch (_) {}
    setState(() => _isLoadingRiders = false);
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Determine target rider ID
    String targetRiderId;
    if (user.role == UserRole.rider) {
      targetRiderId = user.uid;
    } else {
      targetRiderId = ref.watch(calendarTargetRiderIdProvider) ?? '';
    }

    final attendanceAsync = ref.watch(riderAttendanceHistoryProvider(targetRiderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Calendar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Selector Dropdown (Managers/Owners only)
            if (user.role != UserRole.rider) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Rider',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGold),
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingRiders)
                      const LinearProgressIndicator()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161924) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: targetRiderId.isEmpty ? null : targetRiderId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF161924) : Colors.white,
                          items: _riders.map((r) {
                            return DropdownMenuItem(
                              value: r.id,
                              child: Text('${r.name} (${r.employeeId})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(calendarTargetRiderIdProvider.notifier).state = val;
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // 2. Calendar Month Navigator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppTheme.primaryGold),
                    onPressed: _previousMonth,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryGold),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),

            // 3. Days of the Week Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                    .map((d) => SizedBox(
                          width: 40,
                          child: Text(
                            d,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),

            // 4. Calendar Grid
            Expanded(
              child: attendanceAsync.when(
                data: (history) {
                  return _buildCalendarGrid(context, history);
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error loading calendar: $err')),
              ),
            ),
            
            // 5. Color Legend
            _buildColorLegend(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, List<AttendanceModel> history) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstDayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7; // Sunday = 0

    final cells = <Widget>[];

    // Blank cells for offset days
    for (int i = 0; i < firstDayOffset; i++) {
      cells.add(const SizedBox(width: 40, height: 40));
    }

    // Days cells
    for (int day = 1; day <= daysInMonth; day++) {
      final cellDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      
      // Look up attendance for this day
      AttendanceModel? attRecord;
      try {
        attRecord = history.firstWhere((a) =>
            a.date.year == cellDate.year &&
            a.date.month == cellDate.month &&
            a.date.day == cellDate.day);
      } catch (_) {}

      cells.add(_buildDayCell(context, day, attRecord));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.custom(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        childrenDelegate: SliverChildListDelegate(cells),
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, int day, AttendanceModel? attendance) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    Color boxColor = isDark ? const Color(0xFF161924) : Colors.grey.shade100;
    Color border = Colors.transparent;
    Color text = isDark ? Colors.white70 : Colors.black87;

    if (attendance != null) {
      switch (attendance.status) {
        case AttendanceStatus.present:
          boxColor = AppTheme.successGreen.withOpacity(0.15);
          border = AppTheme.successGreen;
          text = AppTheme.successGreen;
          break;
        case AttendanceStatus.late:
          boxColor = AppTheme.warningSaffron.withOpacity(0.15);
          border = AppTheme.warningSaffron;
          text = AppTheme.warningSaffron;
          break;
        case AttendanceStatus.notWorking:
          boxColor = AppTheme.errorRed.withOpacity(0.15);
          border = AppTheme.errorRed;
          text = AppTheme.errorRed;
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(10),
        border: border != Colors.transparent ? Border.all(color: border, width: 1.5) : null,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: text,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildColorLegend(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Present', AppTheme.successGreen),
          _buildLegendItem('Late', AppTheme.warningSaffron),
          _buildLegendItem('Not Working', AppTheme.errorRed),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
