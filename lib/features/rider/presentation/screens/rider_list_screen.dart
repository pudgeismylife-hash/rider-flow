import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/rider_repository.dart';
import '../../domain/rider_model.dart';

final ridersListProvider = FutureProvider.autoDispose<List<RiderModel>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return [];
  
  final companyId = user.companyId ?? 'co_test';
  
  // For owners who can switch branch views, read the selected branch provider.
  // For managers, use their pre-assigned branchId.
  String branchId;
  if (user.role == UserRole.owner) {
    // We import from owner_dashboard.dart
    final selectedBranchId = ref.watch(selectedBranchIdProviderOwner);
    branchId = selectedBranchId ?? user.branchId ?? 'br_test';
  } else {
    branchId = user.branchId ?? 'br_test';
  }

  final repo = ref.read(riderRepositoryProvider);
  return repo.getRiders(companyId, branchId);
});

// Setup a simple selected branch provider copy for scope references
final selectedBranchIdProviderOwner = StateProvider<String?>((ref) => null);

class RiderListScreen extends ConsumerStatefulWidget {
  const RiderListScreen({super.key});

  @override
  ConsumerState<RiderListScreen> createState() => _RiderListScreenState();
}

class _RiderListScreenState extends ConsumerState<RiderListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'active', 'inactive'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ridersAsync = ref.watch(ridersListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riders Directory'),
        actions: [
          if (user != null && user.role != UserRole.rider)
            IconButton(
              icon: const Icon(Icons.person_add_alt_rounded),
              onPressed: () => context.push('/riders/add'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Filters Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search by name or ID...',
                        prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryGold),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter Chip trigger
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.filter_list_rounded, color: AppTheme.primaryGold),
                    onSelected: (val) {
                      setState(() {
                        _statusFilter = val;
                      });
                    },
                    dropdownColor: isDark ? const Color(0xFF1B1D2A) : Colors.white,
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'all', child: Text('All Status')),
                      const PopupMenuItem(value: 'active', child: Text('Active Only')),
                      const PopupMenuItem(value: 'inactive', child: Text('Inactive Only')),
                    ],
                  ),
                ],
              ),
            ),

            // Riders List Content
            Expanded(
              child: ridersAsync.when(
                data: (riders) {
                  // Filter list
                  final filteredRiders = riders.where((r) {
                    final matchesSearch = r.name.toLowerCase().contains(_searchQuery) ||
                        r.employeeId.toLowerCase().contains(_searchQuery);
                    final matchesStatus = _statusFilter == 'all' ||
                        (_statusFilter == 'active' && r.status == 'active') ||
                        (_statusFilter == 'inactive' && r.status == 'inactive');
                    return matchesSearch && matchesStatus;
                  }).toList();

                  if (filteredRiders.isEmpty) {
                    return EmptyState(
                      title: 'No Riders Found',
                      message: _searchQuery.isNotEmpty 
                          ? 'Try modifying your search text' 
                          : 'Click the "+" button at the top to add riders to this branch.',
                      icon: Icons.directions_bike_rounded,
                      action: user != null && user.role != UserRole.rider
                          ? CustomButton(
                              text: 'Register Rider',
                              onPressed: () => context.push('/riders/add'),
                              width: 180,
                            )
                          : null,
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => ref.refresh(ridersListProvider),
                    child: ListView.builder(
                      itemCount: filteredRiders.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemBuilder: (context, index) {
                        final rider = filteredRiders[index];
                        return _buildRiderItem(context, rider);
                      },
                    ),
                  );
                },
                loading: () => ListView.builder(
                  itemCount: 5,
                  itemBuilder: (context, index) => const SkeletonListTile(),
                ),
                error: (err, _) => Center(child: Text('Error loading riders list: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiderItem(BuildContext context, RiderModel rider) {
    final theme = Theme.of(context);
    final isOwed = rider.outstandingBalance > 0;
    final balanceText = rider.outstandingBalance == 0.0
        ? 'Settled'
        : (isOwed 
            ? 'Owes: ₹${rider.outstandingBalance.abs().toStringAsFixed(0)}' 
            : 'Credit: ₹${rider.outstandingBalance.abs().toStringAsFixed(0)}');
            
    final balanceColor = rider.outstandingBalance == 0.0
        ? Colors.grey
        : (isOwed ? AppTheme.errorRed : AppTheme.successGreen);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => context.push('/riders/${rider.id}'),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
          child: const Icon(Icons.person_rounded, color: AppTheme.primaryGold),
        ),
        title: Text(
          rider.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${rider.employeeId} | Mob: ${rider.mobileNumber}'),
            const SizedBox(height: 2),
            Text('Vehicle: ${rider.vehicleNumber}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: balanceColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                balanceText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: balanceColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 4,
                  backgroundColor: rider.status == 'active' ? AppTheme.successGreen : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  rider.status == 'active' ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
