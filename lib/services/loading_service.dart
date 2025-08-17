import 'package:flutter/material.dart';
import 'dart:developer' as developer;

/// Service for managing application-wide loading overlays
/// Provides a centralized way to show/hide loading indicators across the app
class LoadingService {
  /// Current overlay entry being displayed
  static OverlayEntry? _overlayEntry;
  
  /// Whether loading overlay is currently visible
  static bool _isShowing = false;
  
  /// Optional message to display with the loading indicator
  static String? _currentMessage;
  
  /// Timestamp when loading was started (for debugging)
  static DateTime? _startTime;

  /// Shows a loading overlay with optional message
  /// 
  /// [context] - BuildContext for accessing the overlay
  /// [message] - Optional text to display below the loading indicator
  /// [barrierDismissible] - Whether tapping outside dismisses the overlay
  static void show(
    BuildContext context, {
    String? message,
    bool barrierDismissible = false,
  }) {
    if (_isShowing) {
      developer.log('LoadingService: Loading already showing, ignoring duplicate show request');
      return;
    }

    _currentMessage = message;
    _startTime = DateTime.now();

    developer.log('LoadingService: Showing loading overlay${message != null ? ' with message: "$message"' : ''}');

    _overlayEntry = OverlayEntry(
      builder: (context) => _LoadingOverlay(
        message: message,
        barrierDismissible: barrierDismissible,
        onDismiss: barrierDismissible ? hide : null,
      ),
    );

    try {
      Overlay.of(context).insert(_overlayEntry!);
      _isShowing = true;
      developer.log('LoadingService: Loading overlay inserted successfully');
    } catch (e) {
      developer.log('LoadingService: Error inserting overlay: $e');
      _overlayEntry = null;
      _currentMessage = null;
      _startTime = null;
    }
  }

  /// Hides the currently displayed loading overlay
  static void hide() {
    if (!_isShowing || _overlayEntry == null) {
      developer.log('LoadingService: No loading overlay to hide');
      return;
    }

    final duration = _startTime != null 
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    developer.log('LoadingService: Hiding loading overlay (shown for ${duration.inMilliseconds}ms)');

    try {
      _overlayEntry!.remove();
      developer.log('LoadingService: Loading overlay removed successfully');
    } catch (e) {
      developer.log('LoadingService: Error removing overlay: $e');
    } finally {
      _overlayEntry = null;
      _isShowing = false;
      _currentMessage = null;
      _startTime = null;
    }
  }

  /// Updates the message of the currently displayed loading overlay
  /// 
  /// [message] - New message to display
  /// Returns true if message was updated, false if no overlay is showing
  static bool updateMessage(String? message) {
    if (!_isShowing || _overlayEntry == null) {
      developer.log('LoadingService: Cannot update message - no overlay showing');
      return false;
    }

    _currentMessage = message;
    _overlayEntry!.markNeedsBuild();
    
    developer.log('LoadingService: Updated loading message: "${message ?? 'null'}"');
    return true;
  }

  /// Checks if loading overlay is currently visible
  static bool get isShowing => _isShowing;

  /// Gets the current loading message
  static String? get currentMessage => _currentMessage;

  /// Gets how long the loading overlay has been showing
  static Duration? get showDuration {
    if (_startTime == null) return null;
    return DateTime.now().difference(_startTime!);
  }

  /// Shows loading with automatic timeout
  /// 
  /// [context] - BuildContext for accessing the overlay
  /// [timeout] - Maximum duration to show loading
  /// [message] - Optional message to display
  /// [onTimeout] - Callback when timeout is reached
  static void showWithTimeout(
    BuildContext context, {
    required Duration timeout,
    String? message,
    VoidCallback? onTimeout,
  }) {
    show(context, message: message);

    Future.delayed(timeout, () {
      if (_isShowing) {
        developer.log('LoadingService: Loading timeout reached (${timeout.inSeconds}s)');
        hide();
        onTimeout?.call();
      }
    });
  }

  /// Force hide loading overlay (use with caution)
  /// This method will hide the overlay even if there are errors
  static void forceHide() {
    developer.log('LoadingService: Force hiding loading overlay');
    
    try {
      _overlayEntry?.remove();
    } catch (e) {
      developer.log('LoadingService: Error in force hide: $e');
    }
    
    _overlayEntry = null;
    _isShowing = false;
    _currentMessage = null;
    _startTime = null;
  }
}

/// Private widget for the loading overlay UI
class _LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool barrierDismissible;
  final VoidCallback? onDismiss;

  const _LoadingOverlay({
    this.message,
    this.barrierDismissible = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: GestureDetector(
        onTap: barrierDismissible ? onDismiss : null,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3.0,
                ),
                if (message != null) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    message!,
                    style: const TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (barrierDismissible) ...[
                  const SizedBox(height: 12.0),
                  Text(
                    'Tap to dismiss',
                    style: TextStyle(
                      fontSize: 12.0,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
