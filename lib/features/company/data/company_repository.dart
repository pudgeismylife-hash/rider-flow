import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/company_model.dart';
import '../domain/branch_model.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository();
});

class CompanyRepository {
  static const String _companiesKey = 'local_companies';
  static const String _branchesKey = 'local_branches';
  SharedPreferences? _prefs;

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Fetch all companies (for selection / Owner list)
  Future<List<CompanyModel>> getCompanies() async {
    await _init();
    final jsonStr = _prefs?.getString(_companiesKey);
    if (jsonStr == null) return [];
    
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => CompanyModel.fromMap(e)).toList();
  }

  // Fetch branches of a specific company
  Future<List<BranchModel>> getBranches(String companyId) async {
    await _init();
    final jsonStr = _prefs?.getString(_branchesKey);
    if (jsonStr == null) return [];
    
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded
        .map((e) => BranchModel.fromMap(e))
        .where((e) => e.companyId == companyId)
        .toList();
  }

  // Create a new Company
  Future<CompanyModel> createCompany(String name, String ownerUid) async {
    await _init();
    final companies = await getCompanies();
    
    final newCompany = CompanyModel(
      id: 'co_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      ownerUid: ownerUid,
      createdAt: DateTime.now(),
    );
    
    companies.add(newCompany);
    await _prefs?.setString(_companiesKey, json.encode(companies.map((e) => e.toMap()).toList()));
    return newCompany;
  }

  // Create a new Branch
  Future<BranchModel> createBranch(String companyId, String name, String city, String? managerUid) async {
    await _init();
    final jsonStr = _prefs?.getString(_branchesKey) ?? '[]';
    final List<dynamic> decoded = json.decode(jsonStr);
    final branches = decoded.map((e) => BranchModel.fromMap(e)).toList();
    
    final newBranch = BranchModel(
      id: 'br_${DateTime.now().millisecondsSinceEpoch}',
      companyId: companyId,
      name: name,
      city: city,
      managerUid: managerUid,
      createdAt: DateTime.now(),
    );
    
    branches.add(newBranch);
    await _prefs?.setString(_branchesKey, json.encode(branches.map((e) => e.toMap()).toList()));
    return newBranch;
  }
}
