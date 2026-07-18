import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

class SnackbarUtil {
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(BuildContext context, String message, {required bool isError}) {
    final theme = Theme.of(context);
    final backgroundColor = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    final onBackgroundColor = isError ? theme.colorScheme.onError : theme.colorScheme.onPrimary;
    final icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: onBackgroundColor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onBackgroundColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.radiusLg,
        ),
        margin: const EdgeInsets.all(AppSpacing.lg),
        elevation: 6,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
