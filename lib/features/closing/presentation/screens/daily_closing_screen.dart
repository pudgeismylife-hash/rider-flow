import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../dashboard/presentation/screens/rider_dashboard.dart';
import '../../data/closing_repository.dart';
import '../../domain/closing_model.dart';

class DailyClosingScreen extends ConsumerStatefulWidget {
  const DailyClosingScreen({super.key});

  @override
  ConsumerState<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends ConsumerState<DailyClosingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _cashCollectedController = TextEditingController();
  final _upiCollectedController = TextEditingController();
  final _cashHandedOverController = TextEditingController();
  final _remarksController = TextEditingController();

  double _difference = 0.0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cashCollectedController.addListener(_calculateDifference);
    _cashHandedOverController.addListener(_calculateDifference);
  }

  @override
  void dispose() {
    _cashCollectedController.dispose();
    _upiCollectedController.dispose();
    _cashHandedOverController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _calculateDifference() {
    final cashColl = double.tryParse(_cashCollectedController.text.trim()) ?? 0.0;
    final cashHand = double.tryParse(_cashHandedOverController.text.trim()) ?? 0.0;
    setState(() {
      _difference = cashColl - cashHand;
    });
  }

  Future<void> _submitClosing() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    final closing = ClosingModel(
      id: '',
      riderId: user.uid,
      riderName: user.name,
      date: DateTime.now(),
      cashCollected: double.parse(_cashCollectedController.text.trim()),
      upiCollected: double.parse(_upiCollectedController.text.trim()),
      cashHandedOver: double.parse(_cashHandedOverController.text.trim()),
      remarks: _remarksController.text.trim(),
      difference: _difference,
      status: ClosingStatus.submitted,
      timestamp: DateTime.now(),
    );

    try {
      final closingRepo = ref.read(closingRepositoryProvider);
      final submitted = await closingRepo.submitClosing(companyId, branchId, closing);

      // Log action to timeline
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logAction(
        companyId: companyId,
        branchId: branchId,
        action: 'Daily Closing Submitted (Cash Difference: ₹${submitted.difference})',
        actorName: user.name,
        actorRole: user.role.name,
        referenceId: submitted.id,
      );

      ref.invalidate(riderDashboardStatsProvider);
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily closing submitted successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit closing: $e'),
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
    
    // Check if closing already submitted today
    final dashboardStats = ref.watch(riderDashboardStatsProvider);
    ClosingModel? todayClosing;
    if (dashboardStats.hasValue) {
      todayClosing = dashboardStats.value!['todayClosing'];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Closing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.primaryGold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              if (todayClosing != null && todayClosing.status != ClosingStatus.rejected) ...[
                // Already submitted card
                _buildAlreadySubmittedCard(context, todayClosing),
              ] else ...[
                Text(
                  'Record Collection Totals',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (todayClosing?.status == ClosingStatus.rejected) ...[
                  // Rejection warning alert
                  _buildRejectionWarning(todayClosing!.remarks),
                  const SizedBox(height: 16),
                ],

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Cash Collected
                      CustomTextField(
                        controller: _cashCollectedController,
                        labelText: 'Cash Collected (₹)',
                        prefixIcon: Icons.payments_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val == null || val.isEmpty ? 'Cash collected is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // UPI Collected
                      CustomTextField(
                        controller: _upiCollectedController,
                        labelText: 'UPI Collected (₹)',
                        prefixIcon: Icons.qr_code_2_rounded,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val == null || val.isEmpty ? 'UPI collected is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Cash Handed Over
                      CustomTextField(
                        controller: _cashHandedOverController,
                        labelText: 'Cash Handed Over at Counter (₹)',
                        prefixIcon: Icons.handshake_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (val) => val == null || val.isEmpty ? 'Handover cash is required' : null,
                      ),
                      const SizedBox(height: 20),

                      // Difference Calculation Box
                      _buildDifferenceCard(context),
                      const SizedBox(height: 20),

                      // Remarks
                      CustomTextField(
                        controller: _remarksController,
                        labelText: 'Remarks / Exceptions',
                        prefixIcon: Icons.comment_bank_outlined,
                        validator: (val) => val == null || val.isEmpty ? 'Remarks are required for verification' : null,
                      ),

                      const SizedBox(height: 48),
                      CustomButton(
                        text: todayClosing?.status == ClosingStatus.rejected ? 'Resubmit Closing' : 'Submit Today\'s Closing',
                        isLoading: _isSaving,
                        onPressed: _submitClosing,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifferenceCard(BuildContext context) {
    final theme = Theme.of(context);
    final owesMoney = _difference > 0;
    
    Color color = Colors.grey;
    if (_difference > 0) color = AppTheme.errorRed;
    if (_difference == 0.0) color = AppTheme.successGreen;

    return Card(
      color: color.withOpacity(0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cash Difference', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '₹${_difference.toStringAsFixed(0)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color),
                ),
              ],
            ),
            if (owesMoney) ...[
              const Divider(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A cash shortage of ₹${_difference.toStringAsFixed(0)} will be added to your outstanding ledger account upon manager approval.',
                      style: const TextStyle(fontSize: 11, color: AppTheme.errorRed, height: 1.3),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionWarning(String remarks) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Closing Rejected By Manager', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.errorRed)),
                const SizedBox(height: 4),
                Text(
                  'Reason: "$remarks"',
                  style: const TextStyle(fontSize: 11, color: AppTheme.errorRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadySubmittedCard(BuildContext context, ClosingModel closing) {
    final theme = Theme.of(context);
    final timeStr = DateFormat('hh:mm a').format(closing.timestamp);
    
    Color statusColor = AppTheme.infoBlue;
    IconData icon = Icons.pending_actions_rounded;
    String statusDesc = 'Your submission has been received and is in the queue for manager approval.';

    if (closing.status == ClosingStatus.approved) {
      statusColor = AppTheme.successGreen;
      icon = Icons.check_circle_outline_rounded;
      statusDesc = 'Approved! Your collections have been tallied and accepted by ${closing.reviewedBy}.';
    }

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor.withOpacity(0.2), width: 2),
            ),
            child: Icon(
              icon,
              size: 72,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Closing ${closing.status.name}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            statusDesc,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  _buildSummaryItem('Cash Collected', '₹${closing.cashCollected.toStringAsFixed(0)}'),
                  const Divider(height: 16),
                  _buildSummaryItem('UPI Collected', '₹${closing.upiCollected.toStringAsFixed(0)}'),
                  const Divider(height: 16),
                  _buildSummaryItem('Cash Handed Over', '₹${closing.cashHandedOver.toStringAsFixed(0)}'),
                  const Divider(height: 16),
                  _buildSummaryItem('Difference Ledger', '₹${closing.difference.toStringAsFixed(0)}', color: closing.difference > 0 ? AppTheme.errorRed : AppTheme.successGreen),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          CustomButton(
            text: 'Return to Dashboard',
            type: ButtonType.outline,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }
}
