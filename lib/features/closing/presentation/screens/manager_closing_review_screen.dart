import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/screens/manager_dashboard.dart';
import '../../../dashboard/presentation/screens/owner_dashboard.dart';
import '../../data/closing_repository.dart';
import '../../domain/closing_model.dart';

final reviewClosingsListProvider = FutureProvider.autoDispose<List<ClosingModel>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  final repo = ref.read(closingRepositoryProvider);
  return repo.getClosings(companyId, branchId);
});

class ManagerClosingReviewScreen extends ConsumerStatefulWidget {
  const ManagerClosingReviewScreen({super.key});

  @override
  ConsumerState<ManagerClosingReviewScreen> createState() => _ManagerClosingReviewScreenState();
}

class _ManagerClosingReviewScreenState extends ConsumerState<ManagerClosingReviewScreen> {
  String _statusFilter = 'submitted'; // 'submitted' (Pending Review), 'approved', 'rejected'

  // Text Controllers for Edit Dialog
  final _cashCollEditController = TextEditingController();
  final _upiCollEditController = TextEditingController();
  final _cashHandEditController = TextEditingController();
  final _rejectRemarksController = TextEditingController();

  @override
  void dispose() {
    _cashCollEditController.dispose();
    _upiCollEditController.dispose();
    _cashHandEditController.dispose();
    _rejectRemarksController.dispose();
    super.dispose();
  }

  void _openReviewDialog(BuildContext context, ClosingModel closing) {
    _cashCollEditController.text = closing.cashCollected.toStringAsFixed(0);
    _upiCollEditController.text = closing.upiCollected.toStringAsFixed(0);
    _cashHandEditController.text = closing.cashHandedOver.toStringAsFixed(0);
    
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double cashColl = double.tryParse(_cashCollEditController.text.trim()) ?? 0.0;
            double cashHand = double.tryParse(_cashHandEditController.text.trim()) ?? 0.0;
            double diff = cashColl - cashHand;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF161924) : Colors.white,
              title: Text('Review Closing: ${closing.riderName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _cashCollEditController,
                      labelText: 'Cash Collected (₹)',
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _upiCollEditController,
                      labelText: 'UPI Collected (₹)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _cashHandEditController,
                      labelText: 'Cash Handed Over (₹)',
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        setStateDialog(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Difference Card display inside dialog
                    Card(
                      color: diff > 0 ? AppTheme.errorRed.withOpacity(0.06) : AppTheme.successGreen.withOpacity(0.06),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Discrepancy (Shortage):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(
                              '₹${diff.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: diff > 0 ? AppTheme.errorRed : AppTheme.successGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Reject',
                        type: ButtonType.danger,
                        height: 40,
                        onPressed: () {
                          Navigator.pop(context);
                          _openRejectReasonDialog(closing);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'Approve',
                        type: ButtonType.primary,
                        height: 40,
                        onPressed: () {
                          Navigator.pop(context);
                          _processReview(
                            closing: closing,
                            status: ClosingStatus.approved,
                            cashColl: cashColl,
                            cashHand: cashHand,
                            upiColl: double.tryParse(_upiCollEditController.text.trim()) ?? 0.0,
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CustomButton(
                  text: 'Cancel',
                  type: ButtonType.outline,
                  height: 40,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openRejectReasonDialog(ClosingModel closing) {
    _rejectRemarksController.clear();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161924) : Colors.white,
          title: const Text('Rejection Reason', style: TextStyle(fontWeight: FontWeight.bold)),
          content: CustomTextField(
            controller: _rejectRemarksController,
            labelText: 'Reason for rejection',
            prefixIcon: Icons.edit_note_rounded,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final reason = _rejectRemarksController.text.trim();
                if (reason.isEmpty) return;
                
                Navigator.pop(context);
                _processReview(
                  closing: closing,
                  status: ClosingStatus.rejected,
                  remarks: reason,
                );
              },
              child: const Text('Confirm Reject', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processReview({
    required ClosingModel closing,
    required ClosingStatus status,
    double? cashColl,
    double? cashHand,
    double? upiColl,
    String? remarks,
  }) async {
    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    try {
      final closingRepo = ref.read(closingRepositoryProvider);
      final reviewed = await closingRepo.reviewClosing(
        companyId: companyId,
        branchId: branchId,
        closingId: closing.id,
        status: status,
        reviewerName: user.name,
        editedCashCollected: cashColl,
        editedCashHandedOver: cashHand,
        editedUpiCollected: upiColl,
        remarks: remarks,
      );

      // Log action to timeline
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logAction(
        companyId: companyId,
        branchId: branchId,
        action: 'Daily Closing reviewed: ${status.name} for ${closing.riderName}',
        actorName: user.name,
        actorRole: user.role.name,
        referenceId: reviewed.id,
      );

      // Invalidate views
      ref.invalidate(reviewClosingsListProvider);
      ref.invalidate(managerDashboardStatsProvider);
      ref.invalidate(ownerDashboardStatsProvider);
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Closing status updated to: ${status.name}'),
            backgroundColor: status == ClosingStatus.approved ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to review closing: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final closingsAsync = ref.watch(reviewClosingsListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Closings Review'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Bar Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  _buildFilterChip('Submitted', 'submitted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Approved', 'approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected', 'rejected'),
                ],
              ),
            ),
            const Divider(height: 1),

            // Closings review list
            Expanded(
              child: closingsAsync.when(
                data: (closings) {
                  // Filter list
                  final filteredClosings = closings.where((c) {
                    return c.status.name.toLowerCase() == _statusFilter.toLowerCase();
                  }).toList();

                  if (filteredClosings.isEmpty) {
                    return EmptyState(
                      title: 'Queue Empty',
                      message: 'No daily closings currently match this status filter.',
                      icon: Icons.checklist_rtl_rounded,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(reviewClosingsListProvider),
                    child: ListView.builder(
                      itemCount: filteredClosings.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final closing = filteredClosings[index];
                        return _buildReviewCard(context, closing);
                      },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) => const SkeletonListTile(),
                ),
                error: (err, _) => Center(child: Text('Error loading closings: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
          });
        }
      },
      selectedColor: AppTheme.primaryGold.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryGold,
    );
  }

  Widget _buildReviewCard(BuildContext context, ClosingModel closing) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('dd MMMM yyyy').format(closing.date);

    Color statusColor = AppTheme.infoBlue;
    if (closing.status == ClosingStatus.approved) statusColor = AppTheme.successGreen;
    if (closing.status == ClosingStatus.rejected) statusColor = AppTheme.errorRed;

    final owesMoney = closing.difference > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(closing.riderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    closing.status.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: statusColor),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            
            // Numbers Tally
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNumberTallyItem('Cash Coll.', '₹${closing.cashCollected.toStringAsFixed(0)}'),
                _buildNumberTallyItem('UPI Coll.', '₹${closing.upiCollected.toStringAsFixed(0)}'),
                _buildNumberTallyItem('Handed Over', '₹${closing.cashHandedOver.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Discrepancy Difference display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: owesMoney ? AppTheme.errorRed.withOpacity(0.08) : AppTheme.successGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Discrepancy Amount:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '₹${closing.difference.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: owesMoney ? AppTheme.errorRed : AppTheme.successGreen,
                    ),
                  ),
                ],
              ),
            ),

            if (closing.remarks.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Note: "${closing.remarks}"',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade500),
              ),
            ],

            // Action Button for pending entries
            if (closing.status == ClosingStatus.submitted) ...[
              const SizedBox(height: 16),
              CustomButton(
                text: 'Review & Verify Totals',
                onPressed: () => _openReviewDialog(context, closing),
                height: 42,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberTallyItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
