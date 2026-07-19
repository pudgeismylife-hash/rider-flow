import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../rider/domain/rider_model.dart';
import '../../data/ledger_repository.dart';
import '../../domain/transaction_model.dart';
import 'ledger_screen.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String? riderId;

  const AddTransactionScreen({super.key, this.riderId});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _remarksController = TextEditingController();

  String? _selectedRiderId;
  TransactionType _selectedType = TransactionType.advance;
  
  List<RiderModel> _riders = [];
  bool _isLoadingRiders = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedRiderId = widget.riderId;
    _loadRiders();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadRiders() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    setState(() => _isLoadingRiders = true);
    try {
      final riderRepo = ref.read(riderRepositoryProvider);
      final list = await riderRepo.getRiders(user.companyId ?? 'co_test', user.branchId ?? 'br_test');
      setState(() {
        _riders = list;
        // If riderId was not pre-selected and list has items, default to the first
        if (_selectedRiderId == null && list.isNotEmpty) {
          _selectedRiderId = list.first.id;
        }
      });
    } catch (_) {}
    setState(() => _isLoadingRiders = false);
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRiderId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rider account.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    final targetRider = _riders.firstWhere((r) => r.id == _selectedRiderId);

    final transaction = TransactionModel(
      id: '',
      riderId: _selectedRiderId!,
      riderName: targetRider.name,
      type: _selectedType,
      amount: double.parse(_amountController.text.trim()),
      remarks: _remarksController.text.trim(),
      addedBy: user.name,
      timestamp: DateTime.now(),
    );

    try {
      final ledgerRepo = ref.read(ledgerRepositoryProvider);
      final addedTx = await ledgerRepo.addTransaction(companyId, branchId, transaction);

      // Log action to activity timeline
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logAction(
        companyId: companyId,
        branchId: branchId,
        action: '${_selectedType.name} of ₹${addedTx.amount} added to ${targetRider.name}\'s ledger.',
        actorName: user.name,
        actorRole: user.role.name,
        referenceId: addedTx.id,
      );

      // Invalidate relevant providers
      ref.invalidate(ledgerTransactionsProvider);
      ref.invalidate(riderRepositoryProvider); // refresh rider outstanding balance
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_selectedType.name} transaction recorded successfully.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save transaction: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _isLoadingRiders
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Record Ledger Entry',
                        style: theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Rider Account Selector
                      _buildFieldLabel('Rider Account'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161924) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedRiderId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF161924) : Colors.white,
                          items: _riders.map((r) {
                            return DropdownMenuItem(
                              value: r.id,
                              child: Text('${r.name} (${r.employeeId}) - Bal: ₹${r.outstandingBalance.toStringAsFixed(0)}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedRiderId = val;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Transaction Type Selector
                      _buildFieldLabel('Transaction Type'),
                      Row(
                        children: [
                          Expanded(child: _buildTypeRadio(TransactionType.advance, 'Advance', AppTheme.infoBlue)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTypeRadio(TransactionType.cashShortage, 'Shortage', AppTheme.errorRed)),
                          const SizedBox(width: 6),
                          Expanded(child: _buildTypeRadio(TransactionType.paymentReceived, 'Deposit', AppTheme.successGreen)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Amount Input
                      CustomTextField(
                        controller: _amountController,
                        labelText: 'Transaction Amount (₹)',
                        prefixIcon: Icons.currency_rupee_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Amount is required';
                          }
                          final numVal = double.tryParse(val);
                          if (numVal == null || numVal <= 0) {
                            return 'Enter a valid positive number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Remarks Input
                      CustomTextField(
                        controller: _remarksController,
                        labelText: 'Remarks / Explanation',
                        prefixIcon: Icons.comment_bank_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Remarks are required for audits' : null,
                      ),

                      const SizedBox(height: 48),
                      CustomButton(
                        text: 'Execute Entry',
                        isLoading: _isSaving,
                        onPressed: _saveTransaction,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTypeRadio(TransactionType type, String label, Color color) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade400,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : null,
            ),
          ),
        ),
      ),
    );
  }
}
