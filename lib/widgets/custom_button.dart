import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';

enum ButtonType { primary, secondary, outline }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double width;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;

    switch (widget.type) {
      case ButtonType.primary:
        backgroundColor = theme.colorScheme.primary;
        foregroundColor = theme.colorScheme.onPrimary;
        break;
      case ButtonType.secondary:
        backgroundColor = theme.colorScheme.primaryContainer;
        foregroundColor = theme.colorScheme.onPrimaryContainer;
        break;
      case ButtonType.outline:
        backgroundColor = Colors.transparent;
        foregroundColor = theme.colorScheme.onSurface;
        borderSide = BorderSide(
          color: theme.colorScheme.outline,
          width: 1,
        );
        break;
    }

    // Disable colors
    if (widget.onPressed == null && !widget.isLoading) {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      foregroundColor = theme.colorScheme.onSurfaceVariant;
      borderSide = null;
    }

    Widget child = widget.isLoading
        ? SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(
                widget.text,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    return AnimatedScale(
      scale: _isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) {
          if (widget.onPressed != null && !widget.isLoading) {
            setState(() => _isPressed = true);
          }
        },
        onTapUp: (_) {
          if (widget.onPressed != null && !widget.isLoading) {
            setState(() => _isPressed = false);
            widget.onPressed!();
          }
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: SizedBox(
          width: widget.width,
          height: 56, // Fixed height for standard touch target
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: AppRadii.radiusXl, // Extra round for modern look
              border: borderSide != null ? Border.fromBorderSide(borderSide) : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
