import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../company/data/company_repository.dart';
import '../../../company/domain/company_model.dart';
import '../../../company/domain/branch_model.dart';
import '../../domain/user_model.dart';
import '../controllers/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  // Owner Fields
  final _companyNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  final _cityController = TextEditingController();

  UserRole _selectedRole = UserRole.rider;

  // Manager/Rider Selection Fields
  List<CompanyModel> _companies = [];
  List<BranchModel> _branches = [];
  
  String? _selectedCompanyId;
  String? _selectedBranchId;
  bool _isLoadingDropdowns = false;

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _branchNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    setState(() => _isLoadingDropdowns = true);
    try {
      final compRepo = ref.read(companyRepositoryProvider);
      
      // Let's ensure there is at least one company in the system for testing
      var comps = await compRepo.getCompanies();
      if (comps.isEmpty) {
        // Seed a demo company & branch so managers/riders have something to select
        final demoComp = await compRepo.createCompany('Courier Express Corp', 'own_demo');
        await compRepo.createBranch(demoComp.id, 'Bangalore Central', 'Bangalore', 'own_demo');
        comps = await compRepo.getCompanies();
      }

      setState(() {
        _companies = comps;
        _selectedCompanyId = comps.first.id;
      });
      
      await _loadBranchesForCompany(_selectedCompanyId!);
    } catch (_) {}
    setState(() => _isLoadingDropdowns = false);
  }

  Future<void> _loadBranchesForCompany(String companyId) async {
    final compRepo = ref.read(companyRepositoryProvider);
    final branches = await compRepo.getBranches(companyId);
    setState(() {
      _branches = branches;
      _selectedBranchId = branches.isNotEmpty ? branches.first.id : null;
    });
  }

  void _submitOnboarding() {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authControllerProvider.notifier).completeOnboarding(
          name: _nameController.text.trim(),
          role: _selectedRole,
          companyId: _selectedRole == UserRole.owner ? null : _selectedCompanyId,
          branchId: _selectedRole == UserRole.owner ? null : _selectedBranchId,
          newCompanyName: _selectedRole == UserRole.owner ? _companyNameController.text.trim() : null,
          newBranchName: _selectedRole == UserRole.owner ? _branchNameController.text.trim() : null,
          newBranchCity: _selectedRole == UserRole.owner ? _cityController.text.trim() : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Onboarding Setup',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Set up your organization credentials to get started',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Name Field
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Your Full Name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 28),
                
                // Role Picker Selection
                Text(
                  'Select Your Role',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildRoleCard(UserRole.rider, Icons.directions_bike_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRoleCard(UserRole.manager, Icons.storefront_rounded)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildRoleCard(UserRole.owner, Icons.domain_rounded)),
                  ],
                ),
                const SizedBox(height: 32),

                // Conditional Form Inputs based on role
                if (_selectedRole == UserRole.owner) ...[
                  Text('Register New Company', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _companyNameController,
                    labelText: 'Company Name',
                    prefixIcon: Icons.business_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'Company Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _branchNameController,
                    labelText: 'First Branch Name',
                    prefixIcon: Icons.store_rounded,
                    validator: (val) => val == null || val.isEmpty ? 'Branch Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _cityController,
                    labelText: 'City Location',
                    prefixIcon: Icons.location_on_outlined,
                    validator: (val) => val == null || val.isEmpty ? 'City location is required' : null,
                  ),
                ] else ...[
                  Text('Assign Company & Branch', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (_isLoadingDropdowns)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Company Dropdown
                    _buildDropdownLabel('Select Company'),
                    _buildDropdownContainer(
                      DropdownButton<String>(
                        value: _selectedCompanyId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: theme.textTheme.bodyLarge,
                        dropdownColor: isDark ? const Color(0xFF1B1D2A) : Colors.white,
                        items: _companies.map((e) {
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCompanyId = val);
                            _loadBranchesForCompany(val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Branch Dropdown
                    _buildDropdownLabel('Select Branch'),
                    _buildDropdownContainer(
                      DropdownButton<String>(
                        value: _selectedBranchId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        style: theme.textTheme.bodyLarge,
                        dropdownColor: isDark ? const Color(0xFF1B1D2A) : Colors.white,
                        hint: const Text('No branches available'),
                        items: _branches.map((e) {
                          return DropdownMenuItem(
                            value: e.id,
                            child: Text('${e.name} (${e.city})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedBranchId = val);
                          }
                        },
                      ),
                    ),
                  ],
                ],
                
                const SizedBox(height: 40),
                CustomButton(
                  text: 'Complete Settings',
                  isLoading: authState.isLoading,
                  onPressed: _submitOnboarding,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(UserRole role, IconData icon) {
    final isSelected = _selectedRole == role;
    final theme = Theme.of(context);
    
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.primaryGold.withOpacity(0.1) 
              : (theme.brightness == Brightness.dark ? const Color(0xFF161924) : Colors.white),
          border: Border.all(
            color: isSelected ? AppTheme.primaryGold : (theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppTheme.primaryGold : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              role.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primaryGold : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDropdownContainer(Widget child) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B1D2A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade300,
        ),
      ),
      child: child,
    );
  }
}
