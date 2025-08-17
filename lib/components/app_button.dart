// components/buttons/app_button.dart
import 'package:flutter/material.dart';
import '../../theme/app_button_styles.dart';
import '../../theme/app_dimensions.dart';
import '../theme/ app_colors.dart'; 

enum ButtonVariant {
  primary,
  secondary,
  tertiary,
  danger,
  success,
}

enum ButtonSize {
  small,
  medium,
  large,
  xlarge,
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  });

  // Named constructors for common variants
  const AppButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  }) : variant = ButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  }) : variant = ButtonVariant.secondary;

  // Added missing tertiary constructor
  const AppButton.tertiary({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  }) : variant = ButtonVariant.tertiary;

  const AppButton.danger({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  }) : variant = ButtonVariant.danger;

  // Added success constructor for completeness
  const AppButton.success({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = ButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.fullWidth = false,
    this.icon,
  }) : variant = ButtonVariant.success;

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonVariant variant;
  final ButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final bool fullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (isDisabled || isLoading) ? null : onPressed;

    Widget buttonChild = isLoading
        ? SizedBox(
            width: _getIconSize(),
            height: _getIconSize(),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_getLoadingColor()),
            ),
          )
        : _buildButtonContent();

    final button = ElevatedButton(
      style: _getButtonStyle(),
      onPressed: effectiveOnPressed,
      child: buttonChild,
    );

    return fullWidth 
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }

  Widget _buildButtonContent() {
    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _getIconSize()),
          const SizedBox(width: AppDimensions.marginSmall), // Added const
          child,
        ],
      );
    }
    return child;
  }

  ButtonStyle _getButtonStyle() {
    switch (variant) {
      case ButtonVariant.primary:
        return _getSizedStyle(AppButtonStyles.primaryButton);
      case ButtonVariant.secondary:
        return _getSizedStyle(AppButtonStyles.secondaryButton);
      case ButtonVariant.tertiary:
        return _getSizedStyle(AppButtonStyles.tertiaryButton);
      case ButtonVariant.danger:
        return _getSizedStyle(AppButtonStyles.dangerButton);
      case ButtonVariant.success:
        return _getSizedStyle(AppButtonStyles.successButton);
    }
  }

  ButtonStyle _getSizedStyle(ButtonStyle baseStyle) {
    return baseStyle.copyWith(
      padding: WidgetStateProperty.all(_getPadding()),
      minimumSize: WidgetStateProperty.all(_getMinimumSize()),
    );
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingMedium,
          vertical: AppDimensions.paddingSmall,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLarge,
          vertical: AppDimensions.paddingMedium,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge,
          vertical: AppDimensions.paddingLarge,
        );
      case ButtonSize.xlarge:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXLarge * 1.5,
          vertical: AppDimensions.paddingLarge * 1.2,
        );
    }
  }

  Size _getMinimumSize() {
    switch (size) {
      case ButtonSize.small:
        return const Size(64, 32);
      case ButtonSize.medium:
        return const Size(80, 40);
      case ButtonSize.large:
        return const Size(100, 48);
      case ButtonSize.xlarge:
        return const Size(120, 56);
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppDimensions.iconSmall;
      case ButtonSize.medium:
        return AppDimensions.iconMedium;
      case ButtonSize.large:
        return AppDimensions.iconLarge;
      case ButtonSize.xlarge:
        return AppDimensions.iconXLarge;
    }
  }

  Color _getLoadingColor() {
    switch (variant) {
      case ButtonVariant.primary:
      case ButtonVariant.danger:
      case ButtonVariant.success:
        return Colors.white;
      case ButtonVariant.secondary:
      case ButtonVariant.tertiary:
        return AppColors.textPrimary;
    }
  }
}

// components/buttons/record_button.dart
class RecordButton extends StatefulWidget {
  const RecordButton({
    super.key,
    required this.onPressed,
    this.isRecording = false,
    this.isLoading = false,
    this.size = 70.0,
  });

  final VoidCallback onPressed;
  final bool isRecording;
  final bool isLoading;
  final double size;

  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(RecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRecording ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: widget.isLoading ? null : widget.onPressed,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.isRecording ? AppColors.error : AppColors.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (widget.isRecording ? AppColors.error : AppColors.accent)
                        .withOpacity(0.4),
                    blurRadius: 15,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.isLoading
                  ? Center(
                      child: SizedBox(
                        width: widget.size * 0.4,
                        height: widget.size * 0.4,
                        child: const CircularProgressIndicator( // Added const
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    )
                  : Icon(
                      widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white,
                      size: widget.size * 0.45,
                    ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}
