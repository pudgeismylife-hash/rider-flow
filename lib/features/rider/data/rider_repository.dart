import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/domain/user_model.dart';
import '../domain/rider_model.dart';

final riderRepositoryProvider = Provider<RiderRepository>((ref) {
  return RiderRepository();
});

class RiderRepository {
  static const String _ridersKey = 'local_riders';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get riders scoped by branch
  Future<List<RiderModel>> getRiders(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_ridersKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      // Return default mock riders if none exist for presentation
      return _getMockRiders(companyId, branchId);
    }
    
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => RiderModel.fromMap(e)).toList();
  }

  // Get a single rider
  Future<RiderModel?> getRider(String companyId, String branchId, String riderId) async {
    final riders = await getRiders(companyId, branchId);
    try {
      return riders.firstWhere((r) => r.id == riderId);
    } catch (_) {
      return null;
    }
  }

  // Add a new rider
  Future<RiderModel> addRider(String companyId, String branchId, RiderModel rider) async {
    await _init();
    final riders = await getRiders(companyId, branchId);
    
    // Add to list
    final newRider = rider.copyWith(
      id: rider.id.isEmpty ? 'rdr_${DateTime.now().millisecondsSinceEpoch}' : rider.id,
    );
    
    riders.add(newRider);
    await _saveRiders(companyId, branchId, riders);
    
    // Also save user credentials for the rider so they can log in
    await _registerRiderAsUser(newRider, companyId, branchId);
    
    return newRider;
  }

  // Update rider details
  Future<RiderModel> updateRider(String companyId, String branchId, RiderModel rider) async {
    await _init();
    final riders = await getRiders(companyId, branchId);
    
    final index = riders.indexWhere((r) => r.id == rider.id);
    if (index != -isNegative) {
      riders[index] = rider;
      await _saveRiders(companyId, branchId, riders);
      
      // Update registered users cache too
      await _registerRiderAsUser(rider, companyId, branchId);
    }
    return rider;
  }

  // Helper to save riders list
  Future<void> _saveRiders(String companyId, String branchId, List<RiderModel> riders) async {
    await _init();
    final list = riders.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_ridersKey}_${companyId}_$branchId', json.encode(list));
  }

  // When a rider is added/updated, they should also be able to sign in with their phone number
  Future<void> _registerRiderAsUser(RiderModel rider, String companyId, String branchId) async {
    await _init();
    final allUsersJson = _prefs?.getString('registered_users') ?? '[]';
    final List<dynamic> usersList = json.decode(allUsersJson);
    
    final riderUser = UserModel(
      uid: rider.id,
      name: rider.name,
      mobileNumber: rider.mobileNumber,
      role: UserRole.rider,
      companyId: companyId,
      branchId: branchId,
      status: 'active',
      createdAt: rider.joiningDate,
    );
    
    usersList.removeWhere((element) => element['uid'] == rider.id);
    usersList.add(riderUser.toMap());
    await _prefs?.setString('registered_users', json.encode(usersList));
  }

  // Mock list for beautiful preview
  List<RiderModel> _getMockRiders(String companyId, String branchId) {
    final now = DateTime.now();
    final list = [
      RiderModel(
        id: 'rdr_1',
        name: 'Arjun Kumar',
        mobileNumber: '9876543210',
        employeeId: 'RF-2026-001',
        aadhaar: '1234 5678 9012',
        pan: 'ABCDE1234F',
        drivingLicence: 'DL-1234567890123',
        vehicleNumber: 'KA-01-EF-5678',
        joiningDate: now.subtract(const Duration(days: 90)),
        status: 'active',
        emergencyContactName: 'Ramesh Kumar (Father)',
        emergencyContactPhone: '9876543211',
        notes: 'Experienced rider, knows central routes well.',
        outstandingBalance: 1200.0,
      ),
      RiderModel(
        id: 'rdr_2',
        name: 'Siddharth Nair',
        mobileNumber: '8765432109',
        employeeId: 'RF-2026-002',
        aadhaar: '9876 5432 1098',
        pan: 'FGHIJ5678K',
        drivingLicence: 'DL-9876543210987',
        vehicleNumber: 'KA-03-GH-9012',
        joiningDate: now.subtract(const Duration(days: 45)),
        status: 'active',
        emergencyContactName: 'Meera Nair (Wife)',
        emergencyContactPhone: '8765432100',
        notes: 'Punctual and consistent performer.',
        outstandingBalance: 0.0,
      ),
      RiderModel(
        id: 'rdr_3',
        name: 'Rahul Sharma',
        mobileNumber: '7654321098',
        employeeId: 'RF-2026-003',
        aadhaar: '4567 8901 2345',
        pan: 'KLMNO9012P',
        drivingLicence: 'DL-4567890123456',
        vehicleNumber: 'KA-05-IJ-3456',
        joiningDate: now.subtract(const Duration(days: 15)),
        status: 'active',
        emergencyContactName: 'Sunita Sharma (Mother)',
        emergencyContactPhone: '7654321090',
        notes: 'Needs guidance on closing submissions.',
        outstandingBalance: -500.0, // Credit balance
      ),
    ];
    
    // Save these mocks to cache
    _saveRiders(companyId, branchId, list);
    for (var r in list) {
      _registerRiderAsUser(r, companyId, branchId);
    }
    return list;
  }
}
