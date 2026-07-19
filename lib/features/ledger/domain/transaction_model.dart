import 'package:flutter/foundation.dart';

enum TransactionType {
  advance,
  cashShortage,
  paymentReceived;

  String get name {
    switch (this) {
      case TransactionType.advance:
        return 'Advance';
      case TransactionType.cashShortage:
        return 'Cash Shortage';
      case TransactionType.paymentReceived:
        return 'Payment Received';
    }
  }

  static TransactionType fromString(String type) {
    return TransactionType.values.firstWhere(
      (e) => e.name.toLowerCase() == type.toLowerCase() || e.toString().split('.').last == type,
      orElse: () => TransactionType.advance,
    );
  }
}

@immutable
class TransactionModel {
  final String id;
  final String riderId;
  final String riderName;
  final TransactionType type;
  final double amount;
  final String remarks;
  final String addedBy; // Name of Owner/Manager
  final DateTime timestamp;

  const TransactionModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.type,
    required this.amount,
    required this.remarks,
    required this.addedBy,
    required this.timestamp,
  });

  TransactionModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    TransactionType? type,
    double? amount,
    String? remarks,
    String? addedBy,
    DateTime? timestamp,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      remarks: remarks ?? this.remarks,
      addedBy: addedBy ?? this.addedBy,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'type': type.toString().split('.').last,
      'amount': amount,
      'remarks': remarks,
      'addedBy': addedBy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      type: TransactionType.fromString(map['type'] ?? 'advance'),
      amount: (map['amount'] ?? 0.0).toDouble(),
      remarks: map['remarks'] ?? '',
      addedBy: map['addedBy'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
    );
  }
}
