import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/attendance_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

class AttendanceRepository {
  static const String _attendanceKey = 'local_attendance';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get attendance list for a specific branch & company
  Future<List<AttendanceModel>> getAttendance(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_attendanceKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      return _getMockAttendance(companyId, branchId);
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => AttendanceModel.fromMap(e)).toList();
  }

  // Get attendance on a specific day
  Future<List<AttendanceModel>> getAttendanceForDate(
      String companyId, String branchId, DateTime date) async {
    final list = await getAttendance(companyId, branchId);
    return list.where((a) =>
        a.date.year == date.year &&
        a.date.month == date.month &&
        a.date.day == date.day).toList();
  }

  // Get monthly attendance for calendar grid
  Future<List<AttendanceModel>> getAttendanceForRider(
      String companyId, String branchId, String riderId) async {
    final list = await getAttendance(companyId, branchId);
    return list.where((a) => a.riderId == riderId).toList();
  }

  // Mark/save attendance
  Future<AttendanceModel> markAttendance(
      String companyId, String branchId, AttendanceModel attendance) async {
    await _init();
    final list = await getAttendance(companyId, branchId);
    
    // Remove duplicate for same rider on same day if exists
    list.removeWhere((a) =>
        a.riderId == attendance.riderId &&
        a.date.year == attendance.date.year &&
        a.date.month == attendance.date.month &&
        a.date.day == attendance.date.day);
        
    list.add(attendance);
    await _saveAttendance(companyId, branchId, list);
    return attendance;
  }

  Future<void> _saveAttendance(
      String companyId, String branchId, List<AttendanceModel> list) async {
    await _init();
    final encoded = list.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_attendanceKey}_${companyId}_$branchId', json.encode(encoded));
  }

  // Seed mock historical attendance for the dashboard & calendar reviews
  List<AttendanceModel> _getMockAttendance(String companyId, String branchId) {
    final now = DateTime.now();
    final list = <AttendanceModel>[];
    
    // Pre-populate some records for riders: rdr_1, rdr_2, rdr_3 for past 5 days
    for (int i = 1; i <= 5; i++) {
      final date = now.subtract(Duration(days: i));
      
      list.add(AttendanceModel(
        id: 'att_r1_${date.millisecondsSinceEpoch}',
        riderId: 'rdr_1',
        riderName: 'Arjun Kumar',
        date: date,
        status: i % 4 == 0 ? AttendanceStatus.late : AttendanceStatus.present,
        timestamp: date.copyWith(hour: i % 4 == 0 ? 9 : 8, minute: 30),
      ));

      list.add(AttendanceModel(
        id: 'att_r2_${date.millisecondsSinceEpoch}',
        riderId: 'rdr_2',
        riderName: 'Siddharth Nair',
        date: date,
        status: AttendanceStatus.present,
        timestamp: date.copyWith(hour: 8, minute: 15),
      ));

      list.add(AttendanceModel(
        id: 'att_r3_${date.millisecondsSinceEpoch}',
        riderId: 'rdr_3',
        riderName: 'Rahul Sharma',
        date: date,
        status: i == 3 ? AttendanceStatus.notWorking : AttendanceStatus.present,
        timestamp: date.copyWith(hour: 8, minute: 45),
      ));
    }
    
    _saveAttendance(companyId, branchId, list);
    return list;
  }
}
