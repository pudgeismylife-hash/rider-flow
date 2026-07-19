import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../controllers/auth_controller.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isError = false;
  String _errorMessage = '';

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isError = false;
    });

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() {
        _isError = true;
        _errorMessage = 'Please enter a 6-digit OTP code';
      });
      return;
    }

    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyOTP(widget.phoneNumber, otp);

    if (!success) {
      setState(() {
        _isError = true;
        _errorMessage = 'Invalid verification code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'Enter OTP Code',
                style: theme.textTheme.displayMedium?.copyWith(fontSize: 24),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We have sent a verification code to\n+91 ${widget.phoneNumber}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // Code Boxes Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),
              if (_isError) ...[
                const SizedBox(height: 20),
                Text(
                  _errorMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.errorRed,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 48),
              CustomButton(
                text: 'Verify & Sign In',
                isLoading: authState.isLoading,
                onPressed: _verifyOtp,
              ),
              const SizedBox(height: 28),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Trigger resend
                    ref.read(authControllerProvider.notifier).requestOTP(widget.phoneNumber);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('OTP code resent successfully'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                  },
                  child: const Text(
                    'Resend Code',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _buildDemoHint(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGold,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF161924)
              : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
              _verifyOtp();
            }
          } else {
            if (index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
      ),
    );
  }

  Widget _buildDemoHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryGold.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primaryGold, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'For evaluation, enter any 6 digits (e.g. 123456) to sign in.',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryGold),
            ),
          ),
        ],
      ),
    );
  }
}
