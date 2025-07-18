// components/text/app_label.dart
import 'package:flutter/material.dart';
import '../../theme/app_text_styles.dart';
import '../theme/ app_colors.dart';

enum LabelType {
  primary,
  secondary,
  tertiary,
  success,
  warning,
  error,
}

enum LabelSize {
  small,
  medium,
  large,
  xlarge,
}

class AppLabel extends StatelessWidget {
  const AppLabel(
    this.text, {
    super.key,
    this.type = LabelType.primary,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  });

  // Named constructors for common use cases
  const AppLabel.primary(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.primary;

  const AppLabel.secondary(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.secondary;

  const AppLabel.tertiary(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.tertiary;

  const AppLabel.error(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.error;

  const AppLabel.success(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.success;

  const AppLabel.warning(
    this.text, {
    super.key,
    this.size = LabelSize.medium,
    this.fontWeight,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  }) : type = LabelType.warning;

  final String text;
  final LabelType type;
  final LabelSize size;
  final FontWeight? fontWeight;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: _getTextStyle().copyWith(
        fontWeight: fontWeight,
        color: color ?? _getColor(),
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case LabelSize.small:
        return AppTextStyles.bodySmall;
      case LabelSize.medium:
        return AppTextStyles.bodyMedium;
      case LabelSize.large:
        return AppTextStyles.bodyLarge;
      case LabelSize.xlarge:
        return AppTextStyles.heading3;
    }
  }

  Color _getColor() {
    switch (type) {
      case LabelType.primary:
        return AppColors.textPrimary;
      case LabelType.secondary:
        return AppColors.textSecondary;
      case LabelType.tertiary:
        return AppColors.textTertiary;
      case LabelType.success:
        return AppColors.success;
      case LabelType.warning:
        return AppColors.warning;
      case LabelType.error:
        return AppColors.error;
    }
  }
}
