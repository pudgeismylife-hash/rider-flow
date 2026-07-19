import 'package:flutter/foundation.dart';

enum ClosingStatus {
  pending,
  submitted,
  approved,
  rejected;

  String get name {
    switch (this) {
      case ClosingStatus.pending:
        return 'Pending';
      case ClosingStatus.submitted:
        return 'Submitted';
      case ClosingStatus.approved:
        return 'Approved';
      case ClosingStatus.rejected:
        return 'Rejected';
    }
  }

  static ClosingStatus fromString(String status) {
    return ClosingStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == status.toLowerCase() || e.toString().split('.').last == status,
      orElse: () => ClosingStatus.pending,
    );
  }
}

@immutable
class ClosingModel {
  final String id;
  final String riderId;
  final String riderName;
  final DateTime date;
  final double cashCollected;
  final double upiCollected;
  final double cashHandedOver;
  final String remarks;
  final double difference; // Automatically calculated: Cash Collected - Cash Handed Over
  final ClosingStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime timestamp;

  const ClosingModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.date,
    required this.cashCollected,
    required this.upiCollected,
    required this.cashHandedOver,
    required this.remarks,
    required this.difference,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.timestamp,
  });

  ClosingModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    DateTime? date,
    double? cashCollected,
    double? upiCollected,
    double? cashHandedOver,
    String? remarks,
    double? difference,
    ClosingStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? timestamp,
  }) {
    return ClosingModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      date: date ?? this.date,
      cashCollected: cashCollected ?? this.cashCollected,
      upiCollected: upiCollected ?? this.upiCollected,
      cashHandedOver: cashHandedOver ?? this.cashHandedOver,
      remarks: remarks ?? this.remarks,
      difference: difference ?? this.difference,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'date': date.toIso8601String(),
      'cashCollected': cashCollected,
      'upiCollected': upiCollected,
      'cashHandedOver': cashHandedOver,
      'remarks': remarks,
      'difference': difference,
      'status': status.toString().split('.').last,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ClosingModel.fromMap(Map<String, dynamic> map) {
    double cashColl = (map['cashCollected'] ?? 0.0).toDouble();
    double cashHand = (map['cashHandedOver'] ?? 0.0).toDouble();
    double diff = cashColl - cashHand; // Ensure correct diff calculation
    return ClosingModel(
      id: map['id'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      cashCollected: cashColl,
      upiCollected: (map['upiCollected'] ?? 0.0).toDouble(),
      cashHandedOver: cashHand,
      remarks: map['remarks'] ?? '',
      difference: (map['difference'] ?? diff).toDouble(),
      status: ClosingStatus.fromString(map['status'] ?? 'pending'),
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null ? DateTime.parse(map['reviewedAt']) : null,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }
}
