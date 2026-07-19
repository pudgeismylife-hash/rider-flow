import 'package:flutter/foundation.dart';

@immutable
class CompanyModel {
  final String id;
  final String name;
  final String ownerUid;
  final DateTime createdAt;
  final String? address;
  final String? gstin;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.createdAt,
    this.address,
    this.gstin,
  });

  CompanyModel copyWith({
    String? id,
    String? name,
    String? ownerUid,
    DateTime? createdAt,
    String? address,
    String? gstin,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'ownerUid': ownerUid,
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'gstin': gstin,
    };
  }

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      ownerUid: map['ownerUid'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      address: map['address'],
      gstin: map['gstin'],
    );
  }
}
