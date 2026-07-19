import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  static const String _userKey = 'cached_user';
  static const String _companiesKey = 'local_companies';
  static const String _branchesKey = 'local_branches';

  final _userController = StreamController<UserModel?>.broadcast();
  UserModel? _cachedUser;
  SharedPreferences? _prefs;

  AuthRepository() {
    _init();
  }

  Stream<UserModel?> get authStateChanges => _userController.stream;
  UserModel? get currentUser => _cachedUser;

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final userJson = _prefs?.getString(_userKey);
    if (userJson != null) {
      try {
        _cachedUser = UserModel.fromMap(json.decode(userJson));
        _userController.add(_cachedUser);
      } catch (e) {
        _cachedUser = null;
        _userController.add(null);
      }
    } else {
      _userController.add(null);
    }
  }

  // Simulated Phone OTP requests
  Future<void> requestOTP(String mobileNumber) async {
    // In production, this would call: FirebaseAuth.instance.verifyPhoneNumber(...)
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate API delay
  }

  // Verify OTP and look up or create a mock user
  Future<UserModel> verifyOTP(String mobileNumber, String otpCode) async {
    await Future.delayed(const Duration(milliseconds: 1000)); // Simulate API delay
    
    _prefs ??= await SharedPreferences.getInstance();
    
    // In production, check Firebase Auth credentials.
    // Here we check if the user is registered in our mock DB (stored in SharedPrefs/cached).
    final allUsersJson = _prefs?.getString('registered_users') ?? '[]';
    final List<dynamic> usersList = json.decode(allUsersJson);
    
    Map<String, dynamic>? existingUserMap;
    for (var u in usersList) {
      if (u['mobileNumber'] == mobileNumber) {
        existingUserMap = u;
        break;
      }
    }
    
    UserModel user;
    if (existingUserMap != null) {
      user = UserModel.fromMap(existingUserMap);
    } else {
      // New registration - defaults to rider role, pending setup
      String generatedUid = 'usr_${DateTime.now().millisecondsSinceEpoch}';
      user = UserModel(
        uid: generatedUid,
        name: '',
        mobileNumber: mobileNumber,
        role: UserRole.rider, // Initial default
        status: 'pending',    // Needs onboarding setup
        createdAt: DateTime.now(),
      );
    }

    _cachedUser = user;
    await _prefs?.setString(_userKey, json.encode(user.toMap()));
    _userController.add(_cachedUser);
    return user;
  }

  // Complete Onboarding: Register Name, Role, Company, and Branch details
  Future<UserModel> completeOnboarding({
    required String name,
    required UserRole role,
    String? companyId,
    String? branchId,
    String? newCompanyName,
    String? newBranchName,
    String? newBranchCity,
  }) async {
    if (_cachedUser == null) throw Exception('No authenticated user found');
    await Future.delayed(const Duration(milliseconds: 1200));

    _prefs ??= await SharedPreferences.getInstance();
    
    String? finalCompanyId = companyId;
    String? finalBranchId = branchId;

    // Handle Owner creating a new Company and Branch
    if (role == UserRole.owner && newCompanyName != null && newBranchName != null) {
      finalCompanyId = 'co_${DateTime.now().millisecondsSinceEpoch}';
      finalBranchId = 'br_${DateTime.now().millisecondsSinceEpoch}';

      // Save company locally
      final companiesJson = _prefs?.getString(_companiesKey) ?? '[]';
      final List<dynamic> companies = json.decode(companiesJson);
      companies.add({
        'id': finalCompanyId,
        'name': newCompanyName,
        'ownerUid': _cachedUser!.uid,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _prefs?.setString(_companiesKey, json.encode(companies));

      // Save branch locally
      final branchesJson = _prefs?.getString(_branchesKey) ?? '[]';
      final List<dynamic> branches = json.decode(branchesJson);
      branches.add({
        'id': finalBranchId,
        'companyId': finalCompanyId,
        'name': newBranchName,
        'city': newBranchCity ?? 'Default City',
        'managerUid': _cachedUser!.uid, // Owner serves as initial manager
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _prefs?.setString(_branchesKey, json.encode(branches));
    }

    final updatedUser = _cachedUser!.copyWith(
      name: name,
      role: role,
      companyId: finalCompanyId,
      branchId: finalBranchId,
      status: 'active',
    );

    // Save updated user in cache
    _cachedUser = updatedUser;
    await _prefs?.setString(_userKey, json.encode(updatedUser.toMap()));
    
    // Save to registered users database
    final allUsersJson = _prefs?.getString('registered_users') ?? '[]';
    final List<dynamic> usersList = json.decode(allUsersJson);
    
    // Remove if duplicates exist
    usersList.removeWhere((element) => element['uid'] == updatedUser.uid);
    usersList.add(updatedUser.toMap());
    
    await _prefs?.setString('registered_users', json.encode(usersList));
    _userController.add(_cachedUser);
    
    return updatedUser;
  }

  // Set active user (useful for role-swapping during presentation/testing)
  Future<void> testSwitchUser(UserModel user) async {
    _cachedUser = user;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_userKey, json.encode(user.toMap()));
    
    final allUsersJson = _prefs?.getString('registered_users') ?? '[]';
    final List<dynamic> usersList = json.decode(allUsersJson);
    usersList.removeWhere((element) => element['uid'] == user.uid);
    usersList.add(user.toMap());
    await _prefs?.setString('registered_users', json.encode(usersList));
    
    _userController.add(_cachedUser);
  }

  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _cachedUser = null;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.remove(_userKey);
    _userController.add(null);
  }
}
