import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ledger/data/ledger_repository.dart';
import '../../ledger/domain/transaction_model.dart';
import '../domain/closing_model.dart';

final closingRepositoryProvider = Provider<ClosingRepository>((ref) {
  final ledgerRepo = ref.watch(ledgerRepositoryProvider);
  return ClosingRepository(ledgerRepo);
});

class ClosingRepository {
  static const String _closingsKey = 'local_closings';
  final LedgerRepository _ledgerRepository;
  SharedPreferences? _prefs;

  ClosingRepository(this._ledgerRepository);

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get all closing records for a branch
  Future<List<ClosingModel>> getClosings(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_closingsKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      return _getMockClosings(companyId, branchId);
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => ClosingModel.fromMap(e)).toList();
  }

  // Get closings for a specific rider
  Future<List<ClosingModel>> getRiderClosings(
      String companyId, String branchId, String riderId) async {
    final list = await getClosings(companyId, branchId);
    return list.where((c) => c.riderId == riderId).toList();
  }

  // Submit daily closing (Rider action)
  Future<ClosingModel> submitClosing(
      String companyId, String branchId, ClosingModel closing) async {
    await _init();
    final list = await getClosings(companyId, branchId);
    
    // Auto calculate differences
    double diff = closing.cashCollected - closing.cashHandedOver;
    final newClosing = closing.copyWith(
      id: closing.id.isEmpty ? 'cls_${DateTime.now().millisecondsSinceEpoch}' : closing.id,
      difference: diff,
      status: ClosingStatus.submitted,
      timestamp: DateTime.now(),
    );
    
    // Remove if there's an existing pending/submitted one for same day & rider
    list.removeWhere((c) =>
        c.riderId == closing.riderId &&
        c.date.year == closing.date.year &&
        c.date.month == closing.date.month &&
        c.date.day == closing.date.day);

    list.add(newClosing);
    await _saveClosings(companyId, branchId, list);
    return newClosing;
  }

  // Review closing (Manager action: Approve, Edit, Reject)
  Future<ClosingModel> reviewClosing({
    required String companyId,
    required String branchId,
    required String closingId,
    required ClosingStatus status,
    required String reviewerName,
    double? editedCashCollected,
    double? editedCashHandedOver,
    double? editedUpiCollected,
  }) async {
    await _init();
    final list = await getClosings(companyId, branchId);
    final index = list.indexWhere((c) => c.id == closingId);
    
    if (index == -isNegative) {
      var closing = list[index];
      
      // Update values if manager edited them during review
      double cashCollected = editedCashCollected ?? closing.cashCollected;
      double cashHandedOver = editedCashHandedOver ?? closing.cashHandedOver;
      double upiCollected = editedUpiCollected ?? closing.upiCollected;
      double difference = cashCollected - cashHandedOver;
      
      closing = closing.copyWith(
        status: status,
        cashCollected: cashCollected,
        cashHandedOver: cashHandedOver,
        upiCollected: upiCollected,
        difference: difference,
        reviewedBy: reviewerName,
        reviewedAt: DateTime.now(),
      );
      
      list[index] = closing;
      await _saveClosings(companyId, branchId, list);
      
      // Critical check: If status is APPROVED and difference > 0, generate an automated Cash Shortage ledger transaction
      if (status == ClosingStatus.approved && difference > 0) {
        final shortageTx = TransactionModel(
          id: 'tx_auto_${closing.id}',
          riderId: closing.riderId,
          riderName: closing.riderName,
          type: TransactionType.cashShortage,
          amount: difference,
          remarks: 'Automated shortage from Closing on ${closing.date.day}/${closing.date.month}/${closing.date.year}',
          addedBy: reviewerName,
          timestamp: DateTime.now(),
        );
        await _ledgerRepository.addTransaction(companyId, branchId, shortageTx);
      }
      
      return closing;
    } else {
      throw Exception('Closing record not found');
    }
  }

  Future<void> _saveClosings(
      String companyId, String branchId, List<ClosingModel> list) async {
    await _init();
    final encoded = list.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_closingsKey}_${companyId}_$branchId', json.encode(encoded));
  }

  // Seed mock daily closings history
  List<ClosingModel> _getMockClosings(String companyId, String branchId) {
    final now = DateTime.now();
    final list = [
      ClosingModel(
        id: 'cls_1',
        riderId: 'rdr_1',
        riderName: 'Arjun Kumar',
        date: now.subtract(const Duration(days: 1)),
        cashCollected: 3500.0,
        upiCollected: 1200.0,
        cashHandedOver: 3300.0, // Difference: 200.0 (Shortage)
        remarks: 'Collected fuel charge deduction from cash',
        difference: 200.0,
        status: ClosingStatus.approved,
        reviewedBy: 'Manager Raj',
        reviewedAt: now.subtract(const Duration(hours: 12)),
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      ClosingModel(
        id: 'cls_2',
        riderId: 'rdr_2',
        riderName: 'Siddharth Nair',
        date: now.subtract(const Duration(days: 1)),
        cashCollected: 4200.0,
        upiCollected: 2500.0,
        cashHandedOver: 4200.0, // Difference: 0
        remarks: 'Smooth collection day',
        difference: 0.0,
        status: ClosingStatus.approved,
        reviewedBy: 'Manager Raj',
        reviewedAt: now.subtract(const Duration(hours: 12)),
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
      ),
      ClosingModel(
        id: 'cls_3',
        riderId: 'rdr_3',
        riderName: 'Rahul Sharma',
        date: now.subtract(const Duration(days: 1)),
        cashCollected: 1800.0,
        upiCollected: 800.0,
        cashHandedOver: 1800.0,
        remarks: 'Closing completed',
        difference: 0.0,
        status: ClosingStatus.submitted, // Pending Manager Review
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
    ];
    
    _saveClosings(companyId, branchId, list);
    return list;
  }
}
