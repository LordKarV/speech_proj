// components/cards/app_card.dart
import 'package:flutter/material.dart';
import '../../theme/app_dimensions.dart';
import '../theme/ app_colors.dart'; // ✅ Fixed import path

enum CardVariant {
  basic,
  elevated,
  outlined,
  filled,
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.variant = CardVariant.basic,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.color,
  });

  // Named constructors
  const AppCard.basic({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.color,
  }) : variant = CardVariant.basic;

  const AppCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.color,
  }) : variant = CardVariant.elevated;

  const AppCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.width,
    this.height,
    this.color,
  }) : variant = CardVariant.outlined;

  final Widget child;
  final CardVariant variant;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // ✅ MINIMAL padding - only if explicitly provided
    final cardContent = padding != null 
        ? Padding(padding: padding!, child: child)
        : child; // ✅ NO default padding!

    final card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: _getDecoration(),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              child: cardContent,
            )
          : cardContent,
    );

    return card;
  }

  BoxDecoration _getDecoration() {
    switch (variant) {
      case CardVariant.basic:
        return BoxDecoration(
          color: color ?? AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        );

      case CardVariant.elevated:
        return BoxDecoration(
          color: color ?? AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          boxShadow: [
            BoxShadow(
              color: AppColors.overlay,
              blurRadius: AppDimensions.elevationMedium,
              spreadRadius: 0,
              offset: const Offset(0, 2), // ✅ Reduced shadow offset
            ),
          ],
        );

      case CardVariant.outlined:
        return BoxDecoration(
          color: color ?? AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(color: AppColors.border),
        );

      case CardVariant.filled:
        return BoxDecoration(
          color: color ?? AppColors.backgroundTertiary,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        );
    }
  }
}
