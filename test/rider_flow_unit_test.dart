import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rider_flow/features/auth/domain/user_model.dart';
import 'package:rider_flow/features/rider/domain/rider_model.dart';
import 'package:rider_flow/features/rider/data/rider_repository.dart';
import 'package:rider_flow/features/ledger/domain/transaction_model.dart';
import 'package:rider_flow/features/ledger/data/ledger_repository.dart';
import 'package:rider_flow/features/closing/domain/closing_model.dart';
import 'package:rider_flow/features/closing/data/closing_repository.dart';

void main() {
  // Setup Mock SharedPreferences before tests
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('RiderFlow Balance Computations Unit Tests', () {
    late RiderRepository riderRepository;
    late LedgerRepository ledgerRepository;
    late ClosingRepository closingRepository;

    const companyId = 'co_unit_test';
    const branchId = 'br_unit_test';

    setUp(() {
      riderRepository = RiderRepository();
      ledgerRepository = LedgerRepository(riderRepository);
      closingRepository = ClosingRepository(ledgerRepository);
    });

    test('Ledger balance recalculation correctly tallies advances and payments', () async {
      // 1. Register a test rider
      final testRider = RiderModel(
        id: 'rdr_test_1',
        name: 'Unit Test Rider',
        mobileNumber: '9999999999',
        employeeId: 'RF-TEST-01',
        aadhaar: '1111 2222 3333',
        pan: 'PAN12345',
        drivingLicence: 'DL12345',
        vehicleNumber: 'MH-12-XX-1234',
        joiningDate: DateTime.now(),
        status: 'active',
        emergencyContactName: 'Contact Name',
        emergencyContactPhone: '8888888888',
        outstandingBalance: 0.0,
      );
      await riderRepository.addRider(companyId, branchId, testRider);

      // 2. Add an Advance transaction (+1500)
      final txAdvance = TransactionModel(
        id: 'tx_unit_1',
        riderId: 'rdr_test_1',
        riderName: 'Unit Test Rider',
        type: TransactionType.advance,
        amount: 1500.0,
        remarks: 'Test Advance',
        addedBy: 'Test Manager',
        timestamp: DateTime.now(),
      );
      await ledgerRepository.addTransaction(companyId, branchId, txAdvance);

      // Verify balance increased to 1500
      var rider = await riderRepository.getRider(companyId, branchId, 'rdr_test_1');
      expect(rider!.outstandingBalance, 1500.0);

      // 3. Add a Payment Received transaction (-1000)
      final txPayment = TransactionModel(
        id: 'tx_unit_2',
        riderId: 'rdr_test_1',
        riderName: 'Unit Test Rider',
        type: TransactionType.paymentReceived,
        amount: 1000.0,
        remarks: 'Test Payment Received',
        addedBy: 'Test Manager',
        timestamp: DateTime.now(),
      );
      await ledgerRepository.addTransaction(companyId, branchId, txPayment);

      // Verify balance decreased to 500 (1500 - 1000)
      rider = await riderRepository.getRider(companyId, branchId, 'rdr_test_1');
      expect(rider!.outstandingBalance, 500.0);
    });

    test('Daily Closing discrepancy automatically generates Cash Shortage on approval', () async {
      // 1. Register a test rider
      final testRider = RiderModel(
        id: 'rdr_test_2',
        name: 'Unit Test Rider 2',
        mobileNumber: '9999999998',
        employeeId: 'RF-TEST-02',
        aadhaar: '1111 2222 3334',
        pan: 'PAN12346',
        drivingLicence: 'DL12346',
        vehicleNumber: 'MH-12-XX-1235',
        joiningDate: DateTime.now(),
        status: 'active',
        emergencyContactName: 'Contact Name',
        emergencyContactPhone: '8888888888',
        outstandingBalance: 0.0,
      );
      await riderRepository.addRider(companyId, branchId, testRider);

      // 2. Submit Daily Closing with Cash discrepancy (Difference: 300)
      final closing = ClosingModel(
        id: 'cls_unit_1',
        riderId: 'rdr_test_2',
        riderName: 'Unit Test Rider 2',
        date: DateTime.now(),
        cashCollected: 2300.0,
        upiCollected: 500.0,
        cashHandedOver: 2000.0, // Shortage difference is 300 (2300 - 2000)
        remarks: 'Test Closing discrepancy',
        difference: 300.0,
        status: ClosingStatus.submitted,
        timestamp: DateTime.now(),
      );
      await closingRepository.submitClosing(companyId, branchId, closing);

      // Verify ledger has no shortage transaction yet (status is still submitted, not approved)
      var transactions = await ledgerRepository.getRiderTransactions(companyId, branchId, 'rdr_test_2');
      expect(transactions.length, 0);

      // 3. Approve Daily Closing as Manager
      await closingRepository.reviewClosing(
        companyId: companyId,
        branchId: branchId,
        closingId: 'cls_unit_1',
        status: ClosingStatus.approved,
        reviewerName: 'Unit Reviewer',
      );

      // Verify an automated Cash Shortage transaction was created in the ledger
      transactions = await ledgerRepository.getRiderTransactions(companyId, branchId, 'rdr_test_2');
      expect(transactions.length, 1);
      expect(transactions.first.type, TransactionType.cashShortage);
      expect(transactions.first.amount, 300.0);

      // Verify rider outstanding balance is now 300
      final rider = await riderRepository.getRider(companyId, branchId, 'rdr_test_2');
      expect(rider!.outstandingBalance, 300.0);
    });
  });
}
