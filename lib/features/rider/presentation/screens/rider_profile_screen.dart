import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/rider_repository.dart';
import '../../domain/rider_model.dart';

// Family provider to load details for a single rider
final riderProfileDetailsProvider = FutureProvider.family.autoDispose<RiderModel?, String>((ref, id) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;

  final companyId = user.companyId ?? 'co_test';
  final branchId = user.branchId ?? 'br_test';

  final repo = ref.read(riderRepositoryProvider);
  return repo.getRider(companyId, branchId, id);
});

class RiderProfileScreen extends ConsumerWidget {
  final String riderId;

  const RiderProfileScreen({super.key, required this.riderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riderAsync = ref.watch(riderProfileDetailsProvider(riderId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: riderAsync.when(
          data: (rider) {
            if (rider == null) {
              return const Center(child: Text('Rider profile not found.'));
            }

            final isOwed = rider.outstandingBalance >= 0;
            final absBalance = rider.outstandingBalance.abs();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header Profile Box
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                            child: const Icon(Icons.person_rounded, size: 48, color: AppTheme.primaryGold),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            rider.name,
                            style: theme.textTheme.displayMedium?.copyWith(fontSize: 22),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${rider.employeeId} • Joined ${DateFormat('dd MMM yyyy').format(rider.joiningDate)}',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const Divider(height: 32),
                          
                          // Ledger balance highlight
                          Text(
                            isOwed ? 'OUTSTANDING BALANCE' : 'CREDIT BALANCE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOwed ? AppTheme.primaryGold : AppTheme.successGreen,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(absBalance),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isOwed ? AppTheme.errorRed : AppTheme.successGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Quick Actions (for Owners/Managers only)
                  if (user != null && user.role != UserRole.rider) ...[
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Add Transaction',
                            icon: Icons.add_circle_outline_rounded,
                            type: ButtonType.primary,
                            height: 48,
                            onPressed: () {
                              context.push('/ledger/add', extra: rider.id);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomButton(
                            text: 'View Ledger',
                            icon: Icons.receipt_long_rounded,
                            type: ButtonType.outline,
                            height: 48,
                            onPressed: () {
                              // Direct navigation to filter ledger for this rider
                              // For simplicity, we can pass extra parameters
                              context.go('/ledger', extra: rider.id);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 3. Information Accordion
                  Text('Rider Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        children: [
                          _buildDetailRow(Icons.phone_rounded, 'Mobile Number', '+91 ${rider.mobileNumber}'),
                          const Divider(height: 12),
                          _buildDetailRow(Icons.motorcycle_rounded, 'Vehicle Number', rider.vehicleNumber),
                          const Divider(height: 12),
                          _buildDetailRow(Icons.badge_outlined, 'DL Number', rider.drivingLicence),
                          const Divider(height: 12),
                          _buildDetailRow(Icons.fingerprint_rounded, 'Aadhaar Number', rider.aadhaar),
                          const Divider(height: 12),
                          _buildDetailRow(Icons.credit_card_rounded, 'PAN Card', rider.pan),
                          const Divider(height: 12),
                          _buildDetailRow(Icons.contact_emergency_rounded, 'Emergency Contact', '${rider.emergencyContactName} (+91 ${rider.emergencyContactPhone})'),
                          if (rider.notes != null) ...[
                            const Divider(height: 12),
                            _buildDetailRow(Icons.notes_rounded, 'Notes', rider.notes!),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Documents Section
                  Text('Verification Documents', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildDocTile(context, 'Aadhaar Card', rider.aadhaarDocUrl),
                          _buildDocTile(context, 'PAN Card', rider.panDocUrl),
                          _buildDocTile(context, 'Driving Licence', rider.dlDocUrl),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Center(child: Text('Error loading profile: $err')),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocTile(BuildContext context, String title, String? docUrl) {
    final hasDoc = docUrl != null && docUrl.isNotEmpty;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasDoc ? AppTheme.successGreen.withOpacity(0.1) : Colors.grey.shade200.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          hasDoc ? Icons.article_rounded : Icons.article_outlined,
          color: hasDoc ? AppTheme.successGreen : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: hasDoc ? null : Colors.grey)),
      subtitle: Text(
        hasDoc ? docUrl.split('/').last : 'No file uploaded',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: hasDoc
          ? IconButton(
              icon: const Icon(Icons.visibility_outlined, color: AppTheme.primaryGold),
              onPressed: () {
                // Show a dialog/snackbar simulating viewing document
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening document: ${docUrl.split('/').last}'),
                    backgroundColor: AppTheme.infoBlue,
                  ),
                );
              },
            )
          : null,
    );
  }
}
