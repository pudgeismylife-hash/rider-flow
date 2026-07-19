import 'package:flutter/foundation.dart';

enum AttendanceStatus {
  present,
  late,
  notWorking;

  String get name {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.notWorking:
        return 'Not Working';
    }
  }

  static AttendanceStatus fromString(String status) {
    return AttendanceStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == status.toLowerCase() || e.toString().split('.').last == status,
      orElse: () => AttendanceStatus.notWorking,
    );
  }
}

@immutable
class AttendanceModel {
  final String id;
  final String riderId;
  final String riderName;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? selfieUrl;

  const AttendanceModel({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.date,
    required this.status,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.selfieUrl,
  });

  AttendanceModel copyWith({
    String? id,
    String? riderId,
    String? riderName,
    DateTime? date,
    AttendanceStatus? status,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? selfieUrl,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      date: date ?? this.date,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      selfieUrl: selfieUrl ?? this.selfieUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'date': date.toIso8601String(),
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'selfieUrl': selfieUrl,
    };
  }

  factory AttendanceModel.fromMap(Map<String, dynamic> map) {
    return AttendanceModel(
      id: map['id'] ?? '',
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      status: AttendanceStatus.fromString(map['status'] ?? 'notWorking'),
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      selfieUrl: map['selfieUrl'],
    );
  }
}
