import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  static const String _notificationsKey = 'local_notifications';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get notifications
  Future<List<NotificationModel>> getNotifications(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_notificationsKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      return _getMockNotifications();
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    final list = decoded.map((e) => NotificationModel.fromMap(e)).toList();
    // Sort latest first
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // Add/Send notification
  Future<NotificationModel> sendNotification(
      String companyId, String branchId, NotificationModel notification) async {
    await _init();
    final list = await getNotifications(companyId, branchId);
    
    final newNotification = notification.copyWith(
      id: notification.id.isEmpty ? 'nt_${DateTime.now().millisecondsSinceEpoch}' : notification.id,
      timestamp: DateTime.now(),
    );
    
    list.add(newNotification);
    await _saveNotifications(companyId, branchId, list);
    return newNotification;
  }

  // Mark all as read
  Future<void> markAllAsRead(String companyId, String branchId) async {
    await _init();
    final list = await getNotifications(companyId, branchId);
    final updatedList = list.map((n) => n.copyWith(isRead: true)).toList();
    await _saveNotifications(companyId, branchId, updatedList);
  }

  Future<void> _saveNotifications(
      String companyId, String branchId, List<NotificationModel> list) async {
    await _init();
    final encoded = list.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_notificationsKey}_${companyId}_$branchId', json.encode(encoded));
  }

  // Seed mock notifications
  List<NotificationModel> _getMockNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: 'nt_1',
        title: 'Daily Closing Reminder',
        body: 'Please complete today\'s closing. Enter cash collected and UPI details before 9:00 PM.',
        type: 'closingReminder',
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: 'nt_2',
        title: 'Advance Recorded',
        body: 'An advance transaction of ₹500 has been recorded in your ledger by Manager Raj.',
        type: 'advanceAdded',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationModel(
        id: 'nt_3',
        title: 'General Announcement',
        body: 'Franchise working hours for the upcoming national holiday will be 8:00 AM - 2:00 PM.',
        type: 'general',
        timestamp: now.subtract(const Duration(days: 2)),
        isRead: true,
      ),
    ];
  }
}
