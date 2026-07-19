import 'package:flutter/foundation.dart';

enum UserRole {
  owner,
  manager,
  rider;

  String get name {
    switch (this) {
      case UserRole.owner:
        return 'Owner';
      case UserRole.manager:
        return 'Branch Manager';
      case UserRole.rider:
        return 'Rider';
    }
  }

  static UserRole fromString(String role) {
    return UserRole.values.firstWhere(
      (e) => e.name.toLowerCase() == role.toLowerCase() || e.toString().split('.').last == role,
      orElse: () => UserRole.rider,
    );
  }
}

@immutable
class UserModel {
  final String uid;
  final String name;
  final String mobileNumber;
  final UserRole role;
  final String? companyId;
  final String? branchId;
  final String status; // 'active', 'inactive', 'pending'
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.mobileNumber,
    required this.role,
    this.companyId,
    this.branchId,
    required this.status,
    required this.createdAt,
  });

  UserModel copyWith({
    String? uid,
    String? name,
    String? mobileNumber,
    UserRole? role,
    String? companyId,
    String? branchId,
    String? status,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      branchId: branchId ?? this.branchId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'mobileNumber': mobileNumber,
      'role': role.toString().split('.').last,
      'companyId': companyId,
      'branchId': branchId,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      role: UserRole.fromString(map['role'] ?? 'rider'),
      companyId: map['companyId'],
      branchId: map['branchId'],
      status: map['status'] ?? 'active',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
