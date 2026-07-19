import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../rider/data/rider_repository.dart';
import '../../../rider/domain/rider_model.dart';
import '../../data/ledger_repository.dart';
import '../../domain/transaction_model.dart';

final ledgerSelectedRiderIdProvider = StateProvider<String?>((ref) => null);
final ledgerTypeFilterProvider = StateProvider<String>((ref) => 'all'); // 'all', 'advance', 'cashShortage', 'paymentReceived'

final ledgerTransactionsProvider = FutureProvider.autoDispose<List<TransactionModel>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';
  
  final ledgerRepo = ref.read(ledgerRepositoryProvider);
  
  // Decide target rider: lock to rider if user role is rider.
  // Otherwise, get from selection dropdown.
  String targetRiderId;
  if (user.role == UserRole.rider) {
    targetRiderId = user.uid;
  } else {
    targetRiderId = ref.watch(ledgerSelectedRiderIdProvider) ?? '';
  }

  if (targetRiderId.isEmpty) {
    // If no rider is selected yet by manager/owner, return all branch transactions
    return ledgerRepo.getTransactions(companyId, branchId);
  }

  return ledgerRepo.getRiderTransactions(companyId, branchId, targetRiderId);
});

class LedgerScreen extends ConsumerStatefulWidget {
  const LedgerScreen({super.key});

  @override
  ConsumerState<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends ConsumerState<LedgerScreen> {
  List<RiderModel> _riders = [];
  bool _isLoadingRiders = false;

  @override
  void initState() {
    super.initState();
    _loadRidersDropdown();
  }

  Future<void> _loadRidersDropdown() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null || user.role == UserRole.rider) return;

    setState(() => _isLoadingRiders = true);
    try {
      final riderRepo = ref.read(riderRepositoryProvider);
      final list = await riderRepo.getRiders(user.companyId ?? 'co_test', user.branchId ?? 'br_test');
      setState(() {
        _riders = list;
      });
      // Optionally pre-select the first rider from arguments
      final extraRiderId = GoRouterState.of(context).extra as String?;
      if (extraRiderId != null) {
        ref.read(ledgerSelectedRiderIdProvider.notifier).state = extraRiderId;
      } else if (list.isNotEmpty && ref.read(ledgerSelectedRiderIdProvider) == null) {
        ref.read(ledgerSelectedRiderIdProvider.notifier).state = list.first.id;
      }
    } catch (_) {}
    setState(() => _isLoadingRiders = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final selectedRiderId = ref.watch(ledgerSelectedRiderIdProvider);
    final typeFilter = ref.watch(ledgerTypeFilterProvider);
    final txsAsync = ref.watch(ledgerTransactionsProvider);

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger Statements'),
        actions: [
          if (user.role != UserRole.rider)
            IconButton(
              icon: const Icon(Icons.add_card_rounded),
              onPressed: () {
                context.push('/ledger/add', extra: selectedRiderId);
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Rider Selector (Managers/Owners only)
            if (user.role != UserRole.rider) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rider Account Filter',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGold),
                    ),
                    const SizedBox(height: 6),
                    if (_isLoadingRiders)
                      const LinearProgressIndicator()
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161924) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: selectedRiderId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: isDark ? const Color(0xFF161924) : Colors.white,
                          hint: const Text('All Branch Accounts'),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('All Branch Accounts'),
                            ),
                            ..._riders.map((r) {
                              return DropdownMenuItem(
                                value: r.id,
                                child: Text('${r.name} (${r.employeeId})'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            ref.read(ledgerSelectedRiderIdProvider.notifier).state = val;
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // 2. Transaction Type Filters Horizontal Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('All Ledger', 'all', typeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('Advances', 'advance', typeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('Shortages', 'cashShortage', typeFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip('Deposits', 'paymentReceived', typeFilter),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),

            // 3. Transactions List
            Expanded(
              child: txsAsync.when(
                data: (txs) {
                  // Apply filter logic
                  final filteredTxs = txs.where((t) {
                    if (typeFilter == 'all') return true;
                    return t.type.name.toLowerCase() == typeFilter.toLowerCase() ||
                        t.type.toString().split('.').last.toLowerCase() == typeFilter.toLowerCase();
                  }).toList();

                  if (filteredTxs.isEmpty) {
                    return const EmptyState(
                      title: 'No Statement Logs',
                      message: 'No ledger transactions exist matching this criteria.',
                      icon: Icons.account_balance_wallet_outlined,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(ledgerTransactionsProvider),
                    child: ListView.separated(
                      itemCount: filteredTxs.length,
                      padding: const EdgeInsets.all(16),
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = filteredTxs[index];
                        return _buildBankStatementRow(context, tx, currencyFormat);
                      },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) => const SkeletonListTile(),
                ),
                error: (err, _) => Center(child: Text('Error compiling statements: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(ledgerTypeFilterProvider.notifier).state = value;
        }
      },
      selectedColor: AppTheme.primaryGold.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryGold,
    );
  }

  Widget _buildBankStatementRow(BuildContext context, TransactionModel tx, NumberFormat currencyFormat) {
    final theme = Theme.of(context);
    final isCredit = tx.type == TransactionType.paymentReceived;
    
    final flowColor = isCredit ? AppTheme.successGreen : AppTheme.errorRed;
    final flowSymbol = isCredit ? '-' : '+'; // payments reduce dues (-), advances add dues (+)

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon visualizer
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: flowColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: flowColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),

          // Ledger contents
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.type.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  tx.remarks,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  'Account: ${tx.riderName} | By ${tx.addedBy}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(tx.timestamp),
                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),

          // Amount
          Text(
            '$flowSymbol${currencyFormat.format(tx.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: flowColor,
            ),
          ),
        ],
      ),
    );
  }
}
