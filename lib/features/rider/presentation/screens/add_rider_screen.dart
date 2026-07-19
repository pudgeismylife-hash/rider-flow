import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/data/activity_log_repository.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/rider_repository.dart';
import '../../domain/rider_model.dart';
import 'rider_list_screen.dart';

class AddRiderScreen extends ConsumerStatefulWidget {
  const AddRiderScreen({super.key});

  @override
  ConsumerState<AddRiderScreen> createState() => _AddRiderScreenState();
}

class _AddRiderScreenState extends ConsumerState<AddRiderScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _dlController = TextEditingController();
  final _vehicleController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _joiningDate = DateTime.now();
  bool _isSaving = false;

  // Mock Upload Documents State
  String? _aadhaarFileName;
  String? _panFileName;
  String? _dlFileName;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _dlController.dispose();
    _vehicleController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectJoiningDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _joiningDate) {
      setState(() {
        _joiningDate = picked;
      });
    }
  }

  // Simulate file uploading delay
  Future<void> _mockUploadDocument(String docType) async {
    setState(() {
      if (docType == 'aadhaar') _aadhaarFileName = 'Uploading...';
      if (docType == 'pan') _panFileName = 'Uploading...';
      if (docType == 'dl') _dlFileName = 'Uploading...';
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      final rand = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      if (docType == 'aadhaar') _aadhaarFileName = 'aadhaar_doc_$rand.pdf';
      if (docType == 'pan') _panFileName = 'pan_card_$rand.jpg';
      if (docType == 'dl') _dlFileName = 'dl_license_$rand.pdf';
    });
  }

  Future<void> _saveRider() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final authState = ref.read(authControllerProvider);
    final user = authState.valueOrNull;
    if (user == null) return;

    final companyId = user.companyId ?? 'co_test';
    final branchId = user.branchId ?? 'br_test';

    final rider = RiderModel(
      id: '',
      name: _nameController.text.trim(),
      mobileNumber: _phoneController.text.trim(),
      employeeId: _employeeIdController.text.trim(),
      aadhaar: _aadhaarController.text.trim(),
      pan: _panController.text.trim(),
      drivingLicence: _dlController.text.trim(),
      vehicleNumber: _vehicleController.text.trim().toUpperCase(),
      joiningDate: _joiningDate,
      status: 'active',
      emergencyContactName: _emergencyNameController.text.trim(),
      emergencyContactPhone: _emergencyPhoneController.text.trim(),
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      aadhaarDocUrl: _aadhaarFileName != null ? 'storage://docs/$_aadhaarFileName' : null,
      panDocUrl: _panFileName != null ? 'storage://docs/$_panFileName' : null,
      dlDocUrl: _dlFileName != null ? 'storage://docs/$_dlFileName' : null,
      outstandingBalance: 0.0,
    );

    try {
      final riderRepo = ref.read(riderRepositoryProvider);
      final addedRider = await riderRepo.addRider(companyId, branchId, rider);

      // Log action to activity timeline
      final logRepo = ref.read(activityLogRepositoryProvider);
      await logRepo.logAction(
        companyId: companyId,
        branchId: branchId,
        action: 'Rider Added: ${addedRider.name} (${addedRider.employeeId})',
        actorName: user.name,
        actorRole: user.role.name,
        referenceId: addedRider.id,
      );

      ref.invalidate(ridersListProvider);
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${addedRider.name} has been successfully registered.'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save rider: $e'),
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
        title: const Text('Add New Rider'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Rider Registry Form',
                  style: theme.textTheme.displayMedium?.copyWith(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Section 1: Personal Details
                _buildSectionHeader(context, 'Personal Specifications'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _nameController,
                  labelText: 'Rider Full Name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Mobile Number',
                  prefixIcon: Icons.phone_iphone_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.isEmpty ? 'Mobile number is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _employeeIdController,
                  labelText: 'Employee / Rider ID',
                  prefixIcon: Icons.badge_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Rider ID is required' : null,
                ),
                const SizedBox(height: 24),

                // Section 2: Identification & Vehicle
                _buildSectionHeader(context, 'Identification & Credentials'),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _aadhaarController,
                  labelText: 'Aadhaar Number',
                  prefixIcon: Icons.fingerprint_rounded,
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || val.isEmpty ? 'Aadhaar number is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _panController,
                  labelText: 'PAN Number',
                  prefixIcon: Icons.credit_card_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'PAN is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _dlController,
                  labelText: 'Driving Licence Number',
                  prefixIcon: Icons.badge_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'DL number is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _vehicleController,
                  labelText: 'Vehicle Plate Number',
                  prefixIcon: Icons.motorcycle_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Vehicle Plate is required' : null,
                ),
                const SizedBox(height: 24),

                // Section 3: Professional Info
                _buildSectionHeader(context, 'Franchise Onboarding Info'),
                const SizedBox(height: 12),
                // Date picker for onboarding
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Joining Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${_joiningDate.day}/${_joiningDate.month}/${_joiningDate.year}'),
                  trailing: TextButton(
                    onPressed: () => _selectJoiningDate(context),
                    child: const Text('Select Date', style: TextStyle(color: AppTheme.primaryGold)),
                  ),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: _emergencyNameController,
                  labelText: 'Emergency Contact Person',
                  prefixIcon: Icons.contact_emergency_outlined,
                  validator: (val) => val == null || val.isEmpty ? 'Emergency Contact Name is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _emergencyPhoneController,
                  labelText: 'Emergency Contact Phone',
                  prefixIcon: Icons.phone_callback_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.isEmpty ? 'Emergency Phone is required' : null,
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _notesController,
                  labelText: 'Operational Notes (Optional)',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Section 4: Document Attachments
                _buildSectionHeader(context, 'Required Verification Documents'),
                const SizedBox(height: 12),
                _buildDocUploadRow(context, 'Aadhaar Card', 'aadhaar', _aadhaarFileName),
                const SizedBox(height: 12),
                _buildDocUploadRow(context, 'PAN Card', 'pan', _panFileName),
                const SizedBox(height: 12),
                _buildDocUploadRow(context, 'Driving Licence', 'dl', _dlFileName),

                const SizedBox(height: 48),
                CustomButton(
                  text: 'Submit & Onboard Rider',
                  isLoading: _isSaving,
                  onPressed: _saveRider,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGold,
            letterSpacing: 0.5,
          ),
        ),
        const Divider(height: 8, thickness: 0.5),
      ],
    );
  }

  Widget _buildDocUploadRow(BuildContext context, String label, String type, String? fileName) {
    final theme = Theme.of(context);
    final isUploaded = fileName != null && !fileName.contains('Uploading');
    final isUploading = fileName != null && fileName.contains('Uploading');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF161924) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUploaded 
              ? AppTheme.successGreen.withOpacity(0.3) 
              : (isUploading ? AppTheme.warningSaffron.withOpacity(0.3) : Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (fileName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isUploaded ? AppTheme.successGreen : AppTheme.warningSaffron,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 36),
              backgroundColor: isUploaded 
                  ? AppTheme.successGreen.withOpacity(0.15) 
                  : (isUploading ? AppTheme.warningSaffron.withOpacity(0.15) : AppTheme.primaryGold.withOpacity(0.15)),
              foregroundColor: isUploaded 
                  ? AppTheme.successGreen 
                  : (isUploading ? AppTheme.warningSaffron : AppTheme.primaryGold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: Icon(isUploaded ? Icons.check_circle_outline_rounded : Icons.upload_file_rounded, size: 16),
            label: Text(isUploaded ? 'Uploaded' : (isUploading ? 'Pending' : 'Browse'), style: const TextStyle(fontSize: 11)),
            onPressed: isUploading || _isSaving ? null : () => _mockUploadDocument(type),
          ),
        ],
      ),
    );
  }
}
