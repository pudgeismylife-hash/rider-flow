import 'package:flutter/foundation.dart';

@immutable
class BranchModel {
  final String id;
  final String companyId;
  final String name;
  final String? managerUid; // Manager assigned to this branch
  final String city;
  final DateTime createdAt;

  const BranchModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.managerUid,
    required this.city,
    required this.createdAt,
  });

  BranchModel copyWith({
    String? id,
    String? companyId,
    String? name,
    String? managerUid,
    String? city,
    DateTime? createdAt,
  }) {
    return BranchModel(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      managerUid: managerUid ?? this.managerUid,
      city: city ?? this.city,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'companyId': companyId,
      'name': name,
      'managerUid': managerUid,
      'city': city,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'] ?? '',
      companyId: map['companyId'] ?? '',
      name: map['name'] ?? '',
      managerUid: map['managerUid'],
      city: map['city'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
    );
  }
}
