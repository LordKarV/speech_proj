import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../components/app_label.dart';
import '../theme/ app_colors.dart';
import '../theme/app_dimensions.dart';

/// Loading overlay widget that displays a loading indicator with customizable message and progress
/// Can be used to block user interaction during async operations
class LoadingOverlay extends StatelessWidget {
  final String message;
  final String? subtitle;
  final double? progress; // 0.0 to 1.0, null for indeterminate progress
  final VoidCallback? onCancel;
  final bool showProgress;

  const LoadingOverlay({
    super.key,
    required this.message,
    this.subtitle,
    this.progress,
    this.onCancel,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    developer.log('⏳ LoadingOverlay: Building overlay with message: $message');
    if (progress != null) {
      developer.log('📊 LoadingOverlay: Progress: ${(progress! * 100).toInt()}%');
    }
    
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.marginXLarge),
          padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading Indicator - shows progress or spinning indicator
              if (progress != null && showProgress)
                _buildProgressIndicator()
              else
                _buildSpinningIndicator(),
              
              const SizedBox(height: AppDimensions.marginLarge),
              
              // Main loading message
              AppLabel.primary(
                message,
                size: LabelSize.large,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
              ),
              
              // Optional subtitle for additional context
              if (subtitle != null) ...[
                const SizedBox(height: AppDimensions.marginSmall),
                AppLabel.secondary(
                  subtitle!,
                  size: LabelSize.medium,
                  textAlign: TextAlign.center,
                ),
              ],
              
              // Progress percentage text
              if (progress != null && showProgress) ...[
                const SizedBox(height: AppDimensions.marginMedium),
                AppLabel.tertiary(
                  '${(progress! * 100).toInt()}% Complete',
                  size: LabelSize.small,
                  textAlign: TextAlign.center,
                ),
              ],
              
              // Optional cancel button
              if (onCancel != null) ...[
                const SizedBox(height: AppDimensions.marginLarge),
                TextButton(
                  onPressed: () {
                    developer.log('❌ LoadingOverlay: Cancel button pressed');
                    onCancel!();
                  },
                  child: AppLabel.primary(
                    'Cancel',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build circular progress indicator with determinate progress
  Widget _buildProgressIndicator() {
    return SizedBox(
      width: 60,
      height: 60,
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 4,
        backgroundColor: AppColors.border,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
      ),
    );
  }

  /// Build spinning circular progress indicator for indeterminate progress
  Widget _buildSpinningIndicator() {
    return SizedBox(
      width: 60,
      height: 60,
      child: CircularProgressIndicator(
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
      ),
    );
  }
}

/// Wrapper widget that conditionally shows loading overlay over child widget
/// Simplifies usage by handling the stack layout automatically
class LoadingOverlayWrapper extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String loadingMessage;
  final String? loadingSubtitle;
  final double? progress;
  final VoidCallback? onCancel;
  final bool showProgress;

  const LoadingOverlayWrapper({
    super.key,
    required this.child,
    required this.isLoading,
    required this.loadingMessage,
    this.loadingSubtitle,
    this.progress,
    this.onCancel,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    developer.log('🔄 LoadingOverlayWrapper: Building wrapper, isLoading: $isLoading');
    
    return Stack(
      children: [
        // Main content
        child,
        
        // Loading overlay (only shown when isLoading is true)
        if (isLoading)
          LoadingOverlay(
            message: loadingMessage,
            subtitle: loadingSubtitle,
            progress: progress,
            onCancel: onCancel,
            showProgress: showProgress,
          ),
      ],
    );
  }
}
