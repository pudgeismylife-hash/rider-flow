import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

enum ButtonType { primary, secondary, danger, outline }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide border = BorderSide.none;

    switch (type) {
      case ButtonType.primary:
        bg = AppTheme.primaryGold;
        fg = Colors.black;
        break;
      case ButtonType.secondary:
        bg = isDark ? const Color(0xFF1E2230) : Colors.grey.shade200;
        fg = isDark ? Colors.white : Colors.black;
        break;
      case ButtonType.danger:
        bg = AppTheme.errorRed;
        fg = Colors.white;
        break;
      case ButtonType.outline:
        bg = Colors.transparent;
        fg = AppTheme.primaryGold;
        border = const BorderSide(color: AppTheme.primaryGold, width: 1.5);
        break;
    }

    final buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null && !isLoading) ...[
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
        ],
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else
          Text(text),
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: type == ButtonType.primary ? 2 : 0,
          shadowColor: type == ButtonType.primary ? AppTheme.primaryGold.withOpacity(0.3) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: border,
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: buttonContent,
      ),
    );
  }
}
