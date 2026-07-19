import 'package:flutter/foundation.dart';

@immutable
class ActivityLog {
  final String id;
  final String action;
  final DateTime timestamp;
  final String actorName;
  final String actorRole;
  final String? referenceId; // Associated transaction, closing, or attendance ID
  final String branchId;
  final String companyId;

  const ActivityLog({
    required this.id,
    required this.action,
    required this.timestamp,
    required this.actorName,
    required this.actorRole,
    this.referenceId,
    required this.branchId,
    required this.companyId,
  });

  ActivityLog copyWith({
    String? id,
    String? action,
    DateTime? timestamp,
    String? actorName,
    String? actorRole,
    String? referenceId,
    String? branchId,
    String? companyId,
  }) {
    return ActivityLog(
      id: id ?? this.id,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      actorName: actorName ?? this.actorName,
      actorRole: actorRole ?? this.actorRole,
      referenceId: referenceId ?? this.referenceId,
      branchId: branchId ?? this.branchId,
      companyId: companyId ?? this.companyId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'actorName': actorName,
      'actorRole': actorRole,
      'referenceId': referenceId,
      'branchId': branchId,
      'companyId': companyId,
    };
  }

  factory ActivityLog.fromMap(Map<String, dynamic> map) {
    return ActivityLog(
      id: map['id'] ?? '',
      action: map['action'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      actorName: map['actorName'] ?? '',
      actorRole: map['actorRole'] ?? '',
      referenceId: map['referenceId'],
      branchId: map['branchId'] ?? '',
      companyId: map['companyId'] ?? '',
    );
  }
}
