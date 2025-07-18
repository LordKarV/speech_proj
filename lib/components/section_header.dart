// components/layout/section_header.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_dimensions.dart';
import 'app_label.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLarge,
        vertical: AppDimensions.paddingMedium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fixed: replaced AppHeading.h3 with AppLabel.primary
                AppLabel.primary(
                  title,
                  size: LabelSize.large,
                  fontWeight: FontWeight.bold,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: AppDimensions.marginXSmall),
                  AppLabel.secondary(subtitle!),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
