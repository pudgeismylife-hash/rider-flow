import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/activity_log.dart';

final activityLogRepositoryProvider = Provider<ActivityLogRepository>((ref) {
  return ActivityLogRepository();
});

class ActivityLogRepository {
  static const String _logsKey = 'local_activity_logs';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get chronological activity logs
  Future<List<ActivityLog>> getLogs(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_logsKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      return _getMockLogs(companyId, branchId);
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    final list = decoded.map((e) => ActivityLog.fromMap(e)).toList();
    // Sort latest logs first
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // Log a new activity action
  Future<ActivityLog> logAction({
    required String companyId,
    required String branchId,
    required String action,
    required String actorName,
    required String actorRole,
    String? referenceId,
  }) async {
    await _init();
    final list = await getLogs(companyId, branchId);
    
    final newLog = ActivityLog(
      id: 'log_${DateTime.now().millisecondsSinceEpoch}',
      action: action,
      timestamp: DateTime.now(),
      actorName: actorName,
      actorRole: actorRole,
      referenceId: referenceId,
      branchId: branchId,
      companyId: companyId,
    );
    
    list.add(newLog);
    await _saveLogs(companyId, branchId, list);
    return newLog;
  }

  Future<void> _saveLogs(
      String companyId, String branchId, List<ActivityLog> list) async {
    await _init();
    final encoded = list.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_logsKey}_${companyId}_$branchId', json.encode(encoded));
  }

  // Seed mock activity logs
  List<ActivityLog> _getMockLogs(String companyId, String branchId) {
    final now = DateTime.now();
    final list = [
      ActivityLog(
        id: 'log_1',
        action: 'Attendance Marked: Present',
        timestamp: now.subtract(const Duration(hours: 4)),
        actorName: 'Arjun Kumar',
        actorRole: 'Rider',
        branchId: branchId,
        companyId: companyId,
      ),
      ActivityLog(
        id: 'log_2',
        action: 'Advance of ₹500.0 Added',
        timestamp: now.subtract(const Duration(hours: 3)),
        actorName: 'Manager Raj',
        actorRole: 'Branch Manager',
        branchId: branchId,
        companyId: companyId,
      ),
      ActivityLog(
        id: 'log_3',
        action: 'Daily Closing Submitted (Cash: ₹1800, UPI: ₹800)',
        timestamp: now.subtract(const Duration(hours: 2)),
        actorName: 'Rahul Sharma',
        actorRole: 'Rider',
        branchId: branchId,
        companyId: companyId,
      ),
      ActivityLog(
        id: 'log_4',
        action: 'Manager Approved Daily Closing',
        timestamp: now.subtract(const Duration(hours: 1)),
        actorName: 'Manager Raj',
        actorRole: 'Branch Manager',
        branchId: branchId,
        companyId: companyId,
      ),
    ];
    
    _saveLogs(companyId, branchId, list);
    return list;
  }
}
