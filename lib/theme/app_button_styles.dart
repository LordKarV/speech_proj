import 'package:flutter/material.dart';
import ' app_colors.dart';
import 'app_text_styles.dart';
import 'app_dimensions.dart';

class AppButtonStyles {
  AppButtonStyles._();

  // === PRIMARY ACTION BUTTON (Full Width) ===
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: Color.fromRGBO(
        (AppColors.accent.r * 255.0).round() & 0xff,
        (AppColors.accent.g * 255.0).round() & 0xff,
        (AppColors.accent.b * 255.0).round() & 0xff,
        0.3),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingLarge,
      vertical: AppDimensions.paddingLarge,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    textStyle: AppTextStyles.buttonLarge,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withAlpha(26);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withAlpha(13);
        }
        return null;
      },
    ),
  );

  // === SECONDARY ACTION BUTTON (Full Width) ===
  static final ButtonStyle secondaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.backgroundTertiary,
    foregroundColor: AppColors.textPrimary,
    elevation: 1,
    shadowColor: Color.fromRGBO(
        (AppColors.textSecondary.r * 255.0).round() & 0xff,
        (AppColors.textSecondary.g * 255.0).round() & 0xff,
        (AppColors.textSecondary.b * 255.0).round() & 0xff,
        0.2),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingLarge,
      vertical: AppDimensions.paddingLarge,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      side: const BorderSide(color: AppColors.border, width: 1),
    ),
    textStyle: AppTextStyles.buttonLarge,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Color.fromRGBO(
              (AppColors.textPrimary.r * 255.0).round() & 0xff,
              (AppColors.textPrimary.g * 255.0).round() & 0xff,
              (AppColors.textPrimary.b * 255.0).round() & 0xff,
              0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.fromRGBO(
              (AppColors.textPrimary.r * 255.0).round() & 0xff,
              (AppColors.textPrimary.g * 255.0).round() & 0xff,
              (AppColors.textPrimary.b * 255.0).round() & 0xff,
              0.04);
        }
        return null;
      },
    ),
  );

  // === TERTIARY ACTION BUTTON (Full Width Outline) - FIXED ===
  static final ButtonStyle tertiaryButton = OutlinedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textSecondary, // ← FIXED: Changed from accent to textSecondary
    elevation: 0,
    side: const BorderSide(color: AppColors.border, width: 1.5), // ← FIXED: Changed from accent to border
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingLarge,
      vertical: AppDimensions.paddingLarge,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    textStyle: AppTextStyles.buttonLarge,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Color.fromRGBO(
              (AppColors.textSecondary.r * 255.0).round() & 0xff, // ← FIXED: Changed from accent
              (AppColors.textSecondary.g * 255.0).round() & 0xff,
              (AppColors.textSecondary.b * 255.0).round() & 0xff,
              0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.fromRGBO(
              (AppColors.textSecondary.r * 255.0).round() & 0xff, // ← FIXED: Changed from accent
              (AppColors.textSecondary.g * 255.0).round() & 0xff,
              (AppColors.textSecondary.b * 255.0).round() & 0xff,
              0.06);
        }
        return null;
      },
    ),
  );

  // === DANGER BUTTON (Full Width) ===
  static final ButtonStyle dangerButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: Color.fromRGBO(
        (AppColors.error.r * 255.0).round() & 0xff,
        (AppColors.error.g * 255.0).round() & 0xff,
        (AppColors.error.b * 255.0).round() & 0xff,
        0.3),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingLarge,
      vertical: AppDimensions.paddingLarge,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    textStyle: AppTextStyles.buttonLarge,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withAlpha(26);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withAlpha(13);
        }
        return null;
      },
    ),
  );

  // === SUCCESS BUTTON (Full Width) ===
  static final ButtonStyle successButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: Colors.white,
    elevation: 2,
    shadowColor: Color.fromRGBO(
        (AppColors.success.r * 255.0).round() & 0xff,
        (AppColors.success.g * 255.0).round() & 0xff,
        (AppColors.success.b * 255.0).round() & 0xff,
        0.3),
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingLarge,
      vertical: AppDimensions.paddingLarge,
    ),
    minimumSize: const Size(double.infinity, AppDimensions.buttonHeightLarge),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
    ),
    textStyle: AppTextStyles.buttonLarge,
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.white.withAlpha(26);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withAlpha(13);
        }
        return null;
      },
    ),
  );

  // === COMPACT BUTTONS (For toolbars, etc.) ===
  static final ButtonStyle compactButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.backgroundTertiary,
    foregroundColor: AppColors.textPrimary,
    elevation: 1,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingMedium,
      vertical: AppDimensions.paddingSmall,
    ),
    minimumSize: const Size(0, AppDimensions.buttonHeightMedium),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
    textStyle: AppTextStyles.buttonMedium,
  );

  // === TEXT BUTTON ===
  static final ButtonStyle textButton = TextButton.styleFrom(
    foregroundColor: AppColors.accent,
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingMedium,
      vertical: AppDimensions.paddingMedium,
    ),
    minimumSize: const Size(0, AppDimensions.buttonHeightMedium),
    textStyle: AppTextStyles.buttonMedium,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Color.fromRGBO(
              (AppColors.accent.r * 255.0).round() & 0xff,
              (AppColors.accent.g * 255.0).round() & 0xff,
              (AppColors.accent.b * 255.0).round() & 0xff,
              0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.fromRGBO(
              (AppColors.accent.r * 255.0).round() & 0xff,
              (AppColors.accent.g * 255.0).round() & 0xff,
              (AppColors.accent.b * 255.0).round() & 0xff,
              0.06);
        }
        return null;
      },
    ),
  );

  // === ICON BUTTON ===
  static final ButtonStyle iconButton = IconButton.styleFrom(
    backgroundColor: AppColors.backgroundTertiary,
    foregroundColor: AppColors.textSecondary,
    padding: const EdgeInsets.all(AppDimensions.paddingMedium),
    minimumSize: const Size(AppDimensions.buttonHeightMedium, AppDimensions.buttonHeightMedium),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
    ),
  ).copyWith(
    overlayColor: WidgetStateProperty.resolveWith<Color?>(
      (Set<WidgetState> states) {
        if (states.contains(WidgetState.pressed)) {
          return Color.fromRGBO(
              (AppColors.textSecondary.r * 255.0).round() & 0xff,
              (AppColors.textSecondary.g * 255.0).round() & 0xff,
              (AppColors.textSecondary.b * 255.0).round() & 0xff,
              0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return Color.fromRGBO(
              (AppColors.textSecondary.r * 255.0).round() & 0xff,
              (AppColors.textSecondary.g * 255.0).round() & 0xff,
              (AppColors.textSecondary.b * 255.0).round() & 0xff,
              0.06);
        }
        return null;
      },
    ),
  );

  // === FLOATING ACTION BUTTON ===
  static final ButtonStyle floatingActionButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    elevation: 6,
    shadowColor: Color.fromRGBO(
        (AppColors.accent.r * 255.0).round() & 0xff,
        (AppColors.accent.g * 255.0).round() & 0xff,
        (AppColors.accent.b * 255.0).round() & 0xff,
        0.4),
    padding: const EdgeInsets.all(AppDimensions.paddingLarge),
    shape: const CircleBorder(),
  );

  // === RECORD BUTTON ===
  static final ButtonStyle recordButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    elevation: 4,
    shadowColor: Color.fromRGBO(
        (AppColors.error.r * 255.0).round() & 0xff,
        (AppColors.error.g * 255.0).round() & 0xff,
        (AppColors.error.b * 255.0).round() & 0xff,
        0.4),
    padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
    minimumSize: const Size(AppDimensions.recordButtonSize, AppDimensions.recordButtonSize),
    shape: const CircleBorder(),
  );

  // === PLAY BUTTON ===
  static final ButtonStyle playButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: Colors.white,
    elevation: 3,
    shadowColor: Color.fromRGBO(
        (AppColors.success.r * 255.0).round() & 0xff,
        (AppColors.success.g * 255.0).round() & 0xff,
        (AppColors.success.b * 255.0).round() & 0xff,
        0.4),
    padding: const EdgeInsets.all(AppDimensions.paddingLarge),
    minimumSize: const Size(AppDimensions.playButtonSize, AppDimensions.playButtonSize),
    shape: const CircleBorder(),
  );
}
