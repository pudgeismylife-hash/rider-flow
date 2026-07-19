import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../rider/data/rider_repository.dart';
import '../domain/transaction_model.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  final riderRepository = ref.watch(riderRepositoryProvider);
  return LedgerRepository(riderRepository);
});

class LedgerRepository {
  static const String _ledgerKey = 'local_ledger';
  final RiderRepository _riderRepository;
  SharedPreferences? _prefs;

  LedgerRepository(this._riderRepository);

  Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // Get all ledger transactions for a branch
  Future<List<TransactionModel>> getTransactions(String companyId, String branchId) async {
    await _init();
    final jsonStr = _prefs?.getString('${_ledgerKey}_${companyId}_$branchId');
    if (jsonStr == null) {
      return _getMockTransactions(companyId, branchId);
    }
    final List<dynamic> decoded = json.decode(jsonStr);
    return decoded.map((e) => TransactionModel.fromMap(e)).toList();
  }

  // Get transactions for a specific rider
  Future<List<TransactionModel>> getRiderTransactions(
      String companyId, String branchId, String riderId) async {
    final list = await getTransactions(companyId, branchId);
    final riderList = list.where((t) => t.riderId == riderId).toList();
    // Sort chronological: latest first
    riderList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return riderList;
  }

  // Add transaction and automatically re-calculate outstanding balance
  Future<TransactionModel> addTransaction(
      String companyId, String branchId, TransactionModel transaction) async {
    await _init();
    final list = await getTransactions(companyId, branchId);
    
    final newTransaction = transaction.copyWith(
      id: transaction.id.isEmpty ? 'tx_${DateTime.now().millisecondsSinceEpoch}' : transaction.id,
    );
    
    list.add(newTransaction);
    await _saveTransactions(companyId, branchId, list);
    
    // Recalculate rider balance
    await _recalculateRiderBalance(companyId, branchId, transaction.riderId);
    
    return newTransaction;
  }

  Future<void> _saveTransactions(
      String companyId, String branchId, List<TransactionModel> list) async {
    await _init();
    final encoded = list.map((e) => e.toMap()).toList();
    await _prefs?.setString('${_ledgerKey}_${companyId}_$branchId', json.encode(encoded));
  }

  // Automatically calculate outstanding balance
  Future<void> _recalculateRiderBalance(
      String companyId, String branchId, String riderId) async {
    final transactions = await getRiderTransactions(companyId, branchId, riderId);
    final rider = await _riderRepository.getRider(companyId, branchId, riderId);
    
    if (rider != null) {
      double balance = 0.0;
      // Note: Advance and Cash Shortages increase the amount the rider owes.
      // Payments received decrease what the rider owes.
      for (var tx in transactions) {
        if (tx.type == TransactionType.advance || tx.type == TransactionType.cashShortage) {
          balance += tx.amount;
        } else if (tx.type == TransactionType.paymentReceived) {
          balance -= tx.amount;
        }
      }
      
      final updatedRider = rider.copyWith(outstandingBalance: balance);
      await _riderRepository.updateRider(companyId, branchId, updatedRider);
    }
  }

  // Seed mock transactions for a realistic presentation view
  List<TransactionModel> _getMockTransactions(String companyId, String branchId) {
    final now = DateTime.now();
    final list = [
      TransactionModel(
        id: 'tx_1',
        riderId: 'rdr_1',
        riderName: 'Arjun Kumar',
        type: TransactionType.advance,
        amount: 1000.0,
        remarks: 'Advance for fuel charges',
        addedBy: 'Manager Raj',
        timestamp: now.subtract(const Duration(days: 4)),
      ),
      TransactionModel(
        id: 'tx_2',
        riderId: 'rdr_1',
        riderName: 'Arjun Kumar',
        type: TransactionType.cashShortage,
        amount: 200.0,
        remarks: 'Discrepancy in closing of 15th July',
        addedBy: 'Manager Raj',
        timestamp: now.subtract(const Duration(days: 3)),
      ),
      TransactionModel(
        id: 'tx_3',
        riderId: 'rdr_3',
        riderName: 'Rahul Sharma',
        type: TransactionType.advance,
        amount: 500.0,
        remarks: 'Emergency vehicle repair advance',
        addedBy: 'Manager Raj',
        timestamp: now.subtract(const Duration(days: 2)),
      ),
      TransactionModel(
        id: 'tx_4',
        riderId: 'rdr_3',
        riderName: 'Rahul Sharma',
        type: TransactionType.paymentReceived,
        amount: 1000.0,
        remarks: 'Cash handed over at counter',
        addedBy: 'Manager Raj',
        timestamp: now.subtract(const Duration(days: 1)),
      ),
    ];
    
    _saveTransactions(companyId, branchId, list);
    return list;
  }
}
