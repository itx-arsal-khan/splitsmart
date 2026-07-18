import 'package:flutter/material.dart';
import '../theme/app_styles.dart';

class CustomCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasShadow;
  final BorderRadius? borderRadius;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.hasShadow = true,
    this.borderRadius,
  });

  @override
  State<CustomCard> createState() => _CustomCardState();
}

class _CustomCardState extends State<CustomCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget cardChild = Container(
      width: double.infinity,
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: widget.color ?? Theme.of(context).cardColor,
        borderRadius: widget.borderRadius ?? AppRadii.radiusXl,
        boxShadow: widget.hasShadow 
          ? (isDark ? AppShadows.darkShadow : AppShadows.lightShadow) 
          : null,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      return AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onTap!();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: cardChild,
        ),
      );
    }

    return cardChild;
  }
}
