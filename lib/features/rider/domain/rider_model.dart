import 'package:flutter/foundation.dart';

@immutable
class RiderModel {
  final String id;
  final String name;
  final String mobileNumber;
  final String employeeId;
  final String aadhaar;
  final String pan;
  final String drivingLicence;
  final String vehicleNumber;
  final DateTime joiningDate;
  final String status; // 'active', 'inactive'
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String? notes;
  final String? profilePicUrl;
  final String? aadhaarDocUrl;
  final String? panDocUrl;
  final String? dlDocUrl;
  final double outstandingBalance;

  const RiderModel({
    required this.id,
    required this.name,
    required this.mobileNumber,
    required this.employeeId,
    required this.aadhaar,
    required this.pan,
    required this.drivingLicence,
    required this.vehicleNumber,
    required this.joiningDate,
    required this.status,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.notes,
    this.profilePicUrl,
    this.aadhaarDocUrl,
    this.panDocUrl,
    this.dlDocUrl,
    this.outstandingBalance = 0.0,
  });

  RiderModel copyWith({
    String? id,
    String? name,
    String? mobileNumber,
    String? employeeId,
    String? aadhaar,
    String? pan,
    String? drivingLicence,
    String? vehicleNumber,
    DateTime? joiningDate,
    String? status,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? notes,
    String? profilePicUrl,
    String? aadhaarDocUrl,
    String? panDocUrl,
    String? dlDocUrl,
    double? outstandingBalance,
  }) {
    return RiderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      employeeId: employeeId ?? this.employeeId,
      aadhaar: aadhaar ?? this.aadhaar,
      pan: pan ?? this.pan,
      drivingLicence: drivingLicence ?? this.drivingLicence,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      joiningDate: joiningDate ?? this.joiningDate,
      status: status ?? this.status,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      notes: notes ?? this.notes,
      profilePicUrl: profilePicUrl ?? this.profilePicUrl,
      aadhaarDocUrl: aadhaarDocUrl ?? this.aadhaarDocUrl,
      panDocUrl: panDocUrl ?? this.panDocUrl,
      dlDocUrl: dlDocUrl ?? this.dlDocUrl,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mobileNumber': mobileNumber,
      'employeeId': employeeId,
      'aadhaar': aadhaar,
      'pan': pan,
      'drivingLicence': drivingLicence,
      'vehicleNumber': vehicleNumber,
      'joiningDate': joiningDate.toIso8601String(),
      'status': status,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'notes': notes,
      'profilePicUrl': profilePicUrl,
      'aadhaarDocUrl': aadhaarDocUrl,
      'panDocUrl': panDocUrl,
      'dlDocUrl': dlDocUrl,
      'outstandingBalance': outstandingBalance,
    };
  }

  factory RiderModel.fromMap(Map<String, dynamic> map) {
    return RiderModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      mobileNumber: map['mobileNumber'] ?? '',
      employeeId: map['employeeId'] ?? '',
      aadhaar: map['aadhaar'] ?? '',
      pan: map['pan'] ?? '',
      drivingLicence: map['drivingLicence'] ?? '',
      vehicleNumber: map['vehicleNumber'] ?? '',
      joiningDate: map['joiningDate'] != null
          ? DateTime.parse(map['joiningDate'])
          : DateTime.now(),
      status: map['status'] ?? 'active',
      emergencyContactName: map['emergencyContactName'] ?? '',
      emergencyContactPhone: map['emergencyContactPhone'] ?? '',
      notes: map['notes'],
      profilePicUrl: map['profilePicUrl'],
      aadhaarDocUrl: map['aadhaarDocUrl'],
      panDocUrl: map['panDocUrl'],
      dlDocUrl: map['dlDocUrl'],
      outstandingBalance: (map['outstandingBalance'] ?? 0.0).toDouble(),
    );
  }
}
