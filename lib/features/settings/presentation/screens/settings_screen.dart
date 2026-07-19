import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../company/data/company_repository.dart';
import '../../../company/domain/company_model.dart';
import '../../../company/domain/branch_model.dart';

// Settings Alarm State providers
final attendanceReminderTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 8, minute: 0));
final closingReminderTimeProvider = StateProvider<TimeOfDay>((ref) => const TimeOfDay(hour: 20, minute: 0));
final pushNotificationsEnabledProvider = StateProvider<bool>((ref) => true);

final settingsDetailsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  final user = authState.valueOrNull;
  if (user == null) return {};

  final compRepo = ref.read(companyRepositoryProvider);
  
  CompanyModel? company;
  BranchModel? branch;

  try {
    final comps = await compRepo.getCompanies();
    company = comps.firstWhere((c) => c.id == user.companyId);
    
    final branches = await compRepo.getBranches(user.companyId ?? 'co_test');
    branch = branches.firstWhere((b) => b.id == user.branchId);
  } catch (_) {}

  return {
    'company': company,
    'branch': branch,
  };
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _selectTime(BuildContext context, WidgetRef ref, bool isAttendance) async {
    final provider = isAttendance ? attendanceReminderTimeProvider : closingReminderTimeProvider;
    final currentTime = ref.read(provider);

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: currentTime,
    );

    if (picked != null && picked != currentTime) {
      ref.read(provider.notifier).state = picked;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder set for ${picked.format(context)}'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final authState = ref.watch(authControllerProvider);
    final user = authState.valueOrNull;

    final themeMode = ref.watch(themeModeProvider);
    final attendanceTime = ref.watch(attendanceReminderTimeProvider);
    final closingTime = ref.watch(closingReminderTimeProvider);
    final pushEnabled = ref.watch(pushNotificationsEnabledProvider);

    final detailsAsync = ref.watch(settingsDetailsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Franchise Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primaryGold.withOpacity(0.15),
                        child: const Icon(Icons.person_rounded, size: 36, color: AppTheme.primaryGold),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.name ?? 'User Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            Text(user?.role.name ?? 'Role', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            Text('+91 ${user?.mobileNumber}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Organization Info (Company & Branch)
              Text('Tenant Info', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              detailsAsync.when(
                data: (details) {
                  final CompanyModel? company = details['company'];
                  final BranchModel? branch = details['branch'];

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildSettingsRow(
                            Icons.business_rounded,
                            'Company Name',
                            company?.name ?? 'Courier Express Corp (Demo)',
                          ),
                          const Divider(height: 16),
                          _buildSettingsRow(
                            Icons.storefront_rounded,
                            'Active Branch',
                            branch != null ? '${branch.name} (${branch.city})' : 'Bangalore Central (Demo)',
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())),
                error: (err, _) => const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Failed to load company metadata'))),
              ),
              const SizedBox(height: 20),

              // 3. Application Preferences
              Text('App Preferences', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      // Dark Mode toggle
                      SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_outlined, color: AppTheme.primaryGold),
                        title: const Text('Dark Theme Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        value: themeMode == ThemeMode.dark,
                        activeColor: AppTheme.primaryGold,
                        onChanged: (val) {
                          ref.read(themeModeProvider.notifier).state = val ? ThemeMode.dark : ThemeMode.light;
                        },
                      ),
                      const Divider(height: 1),
                      // Push alerts toggle
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryGold),
                        title: const Text('Push Reminders', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        value: pushEnabled,
                        activeColor: AppTheme.primaryGold,
                        onChanged: (val) {
                          ref.read(pushNotificationsEnabledProvider.notifier).state = val;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 4. Time Reminders Module
              Text('Scheduler Settings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.alarm_rounded, color: AppTheme.primaryGold),
                        title: const Text('Morning Attendance Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        trailing: Text(
                          attendanceTime.format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                        ),
                        onTap: () => _selectTime(context, ref, true),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_clock_outlined, color: AppTheme.primaryGold),
                        title: const Text('Evening Closing Checklist Alert', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        trailing: Text(
                          closingTime.format(context),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                        ),
                        onTap: () => _selectTime(context, ref, false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Logout Button
              CustomButton(
                text: 'Log Out Account',
                type: ButtonType.danger,
                onPressed: () {
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryGold, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
