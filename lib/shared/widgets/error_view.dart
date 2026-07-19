import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'custom_button.dart';

class ErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    required this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.errorRed.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Something Went Wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              CustomButton(
                text: 'Try Again',
                onPressed: onRetry,
                type: ButtonType.outline,
                width: 160,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
