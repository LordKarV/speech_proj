import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_app/widgets/spectrogram_widget.dart';

/// Custom painter for rendering spectrogram visualizations
/// Handles two modes: recording and playback
class SpectrogramPainter extends CustomPainter {
  /// 2D array of frequency magnitude data [time][frequency]
  final List<List<double>> spectrogramData;
  
  /// Whether currently in recording mode
  final bool isRecording;
  
  /// Current recording duration for display
  final Duration recordingDuration;
  
  /// Whether in WAV playback mode with seeking capabilities
  final bool isWavPlayback;
  
  /// Controller for WAV playback operations
  final WavPlaybackController? wavController;
  
  /// Whether user is currently dragging to seek
  final bool isDragging;
  
  /// Current drag position (0.0 to 1.0)
  final double dragProgress;
  
  /// Audio playback delay compensation in milliseconds
  final Duration playbackDelay;

  SpectrogramPainter({
    required this.spectrogramData,
    required this.isRecording,
    required this.recordingDuration,
    required this.isWavPlayback,
    this.wavController,
    required this.isDragging,
    this.dragProgress = 0.0,
    this.playbackDelay = const Duration(milliseconds: 0),
  });

  @override
  void paint(Canvas canvas, Size size) {
    developer.log('SpectrogramPainter: Starting paint with size: ${size.width}x${size.height}');
    
    // Early return if no data to paint
    if (spectrogramData.isEmpty) {
      developer.log('SpectrogramPainter: No spectrogram data available');
      return;
    }

    final maxFreqBins = spectrogramData.isNotEmpty ? spectrogramData.first.length : 0;
    if (maxFreqBins == 0) {
      developer.log('SpectrogramPainter: No frequency bins in data');
      return;
    }

    // Calculate frequency bin height
    final binHeight = size.height / maxFreqBins;
    final totalColumns = spectrogramData.length;
    
    developer.log('SpectrogramPainter: Rendering ${totalColumns} columns with ${maxFreqBins} frequency bins each');
    
    // Route to appropriate painting method based on mode
    if (isRecording) {
      developer.log('SpectrogramPainter: Painting in recording mode');
      _paintRecordingMode(canvas, size, binHeight, totalColumns);
    } else {
      // Must be playback mode (isWavPlayback should be true)
      developer.log('SpectrogramPainter: Painting in playback mode');
      _paintPlaybackMode(canvas, size, binHeight, totalColumns);
    }
  }

  /// Paints spectrogram in recording mode with auto-scrolling and recording indicator
  void _paintRecordingMode(Canvas canvas, Size size, double binHeight, int totalColumns) {
    developer.log('SpectrogramPainter: Recording mode - ${totalColumns} columns, duration: ${recordingDuration.inSeconds}s');
    
    // Draw white background for recording mode
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    
    const double columnWidth = 1.0;
    
    // Calculate how many columns can fit on screen
    final maxVisibleColumns = (size.width / columnWidth).ceil();
    developer.log('SpectrogramPainter: Max visible columns: ${maxVisibleColumns}');
    
    // Auto-scroll logic: show the latest data (rightmost)
    double startX;
    int startColumn = 0;
    
    if (totalColumns < maxVisibleColumns) {
      // Data fits on screen - align to right edge
      startX = size.width - (totalColumns * columnWidth);
      developer.log('SpectrogramPainter: Data fits on screen, aligning right');
    } else {
      // More data than screen width - scroll to show latest
      startX = 0.0;
      startColumn = totalColumns - maxVisibleColumns;
      developer.log('SpectrogramPainter: Scrolling to show latest data, start column: ${startColumn}');
    }
    
    // Clip canvas to prevent drawing outside bounds
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw spectrogram data columns
    for (int i = 0; i < math.min(totalColumns, maxVisibleColumns); i++) {
      final colIndex = startColumn + i;
      if (colIndex >= totalColumns) break;
      
      final column = spectrogramData[colIndex];
      final x = startX + (i * columnWidth);
      
      // Draw each frequency bin in the column
      for (int bin = 0; bin < column.length; bin++) {
        final magnitude = column[bin];
        final y = size.height - (bin + 1) * binHeight;
        
        final color = _getGrayscaleColor(magnitude);
        final rect = Rect.fromLTWH(x, y, columnWidth, binHeight);
        canvas.drawRect(rect, Paint()..color = color);
      }
    }
    
    // Draw recording indicator line
    final recordingLineX = totalColumns < maxVisibleColumns 
        ? startX + (totalColumns * columnWidth)
        : size.width;
    
    developer.log('SpectrogramPainter: Drawing recording line at x: ${recordingLineX}');
    canvas.drawLine(
      Offset(recordingLineX, 0),
      Offset(recordingLineX, size.height),
      Paint()
        ..color = Colors.red
        ..strokeWidth = 0.5,
    );
  }
  
  /// Paints spectrogram in playback mode with fixed cursor and scrolling data
  void _paintPlaybackMode(Canvas canvas, Size size, double binHeight, int totalColumns) {
    const double columnWidth = 1.0;
    final totalDataWidth = totalColumns * columnWidth;
    
    developer.log('SpectrogramPainter: Playback mode - ${totalColumns} columns, total width: ${totalDataWidth}px');
    
    // Calculate current playback progress with delay compensation
    double progress;
    if (isDragging) {
      progress = dragProgress;
      developer.log('SpectrogramPainter: Using drag progress: ${(progress * 100).toStringAsFixed(1)}%');
    } else if (wavController != null && wavController!.totalDuration.inMilliseconds > 0) {
      final rawPosition = wavController!.currentPosition;
      final totalDuration = wavController!.totalDuration;
      
      // Apply delay compensation only when actively playing
      if (rawPosition.inMilliseconds > 0 && rawPosition < totalDuration) {
        // Add delay to current position for visual synchronization
        final compensatedPosition = Duration(
          milliseconds: rawPosition.inMilliseconds + playbackDelay.inMilliseconds
        );
        
        progress = compensatedPosition.inMilliseconds / totalDuration.inMilliseconds;
        progress = progress.clamp(0.0, 1.0);
        
        developer.log('SpectrogramPainter: Applied delay compensation - Raw: ${rawPosition.inSeconds}s, '
            'Compensated: ${compensatedPosition.inSeconds}s');
      } else {
        // At beginning or end, use raw position without compensation
        progress = rawPosition.inMilliseconds / totalDuration.inMilliseconds;
        progress = progress.clamp(0.0, 1.0);
        developer.log('SpectrogramPainter: Using raw position: ${rawPosition.inSeconds}s');
      }
    } else {
      progress = 0.0;
      developer.log('SpectrogramPainter: No controller or duration, using 0% progress');
    }
    
    // Fixed cursor position in center of screen
    final fixedCursorX = size.width * 0.5;
    
    // Calculate scroll offset to move data under the centered cursor
    final targetDataX = progress * totalDataWidth;
    double scrollOffset = targetDataX - fixedCursorX;
    
    // Allow scrolling beyond edges for better user experience
    scrollOffset = scrollOffset.clamp(
      -fixedCursorX, // Can scroll left to show beginning
      math.max(0.0, totalDataWidth - fixedCursorX) // Can scroll right to show end
    );
    
    developer.log('SpectrogramPainter: Scroll offset: ${scrollOffset.toStringAsFixed(1)}px, '
        'cursor at: ${fixedCursorX}px');
    
    // Draw white background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    
    // Clip canvas to prevent drawing outside bounds
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Draw spectrogram data with horizontal scrolling
    int visibleColumns = 0;
    for (int col = 0; col < totalColumns; col++) {
      final column = spectrogramData[col];
      final x = (col * columnWidth) - scrollOffset;
      
      // Only draw columns that are visible (with small buffer for performance)
      if (x + columnWidth >= -10 && x <= size.width + 10) {
        visibleColumns++;
        
        // Draw each frequency bin in the column
        for (int bin = 0; bin < column.length; bin++) {
          final magnitude = column[bin];
          final y = size.height - (bin + 1) * binHeight;
          
          final color = _getGrayscaleColor(magnitude);
          final rect = Rect.fromLTWH(x, y, columnWidth, binHeight);
          canvas.drawRect(rect, Paint()..color = color);
        }
      }
    }
    
    developer.log('SpectrogramPainter: Drew ${visibleColumns} visible columns');
    
    // Draw fixed cursor line in center (changes color when dragging)
    canvas.drawLine(
      Offset(fixedCursorX, 0),
      Offset(fixedCursorX, size.height),
      Paint()
        ..color = isDragging ? Colors.orange : Colors.red
        ..strokeWidth = 1.5,
    );
    
    // Draw progress indicator at bottom
    _drawProgressBar(canvas, size, progress);
  }

  /// Draws progress bar at bottom of spectrogram
  void _drawProgressBar(Canvas canvas, Size size, double progress) {
    const double progressBarHeight = 2.0;
    final progressBarY = size.height - progressBarHeight;
    
    // Background progress bar
    canvas.drawRect(
      Rect.fromLTWH(0, progressBarY, size.width, progressBarHeight),
      Paint()..color = Colors.grey.shade300,
    );
    
    // Progress fill
    canvas.drawRect(
      Rect.fromLTWH(0, progressBarY, size.width * progress, progressBarHeight),
      Paint()..color = Colors.red.withOpacity(0.7),
    );
  }

  /// Converts magnitude value to grayscale color using logarithmic scaling
  Color _getGrayscaleColor(double magnitude) {
    // Apply logarithmic scaling for better visual representation
    final logMagnitude = magnitude > 0 ? math.log(1 + magnitude * 10) / math.log(11) : 0.0;
    final normalizedMag = logMagnitude.clamp(0.0, 1.0);
    
    // Map normalized magnitude to grayscale colors with smooth transitions
    if (normalizedMag < 0.05) {
      return Colors.white;
    } else if (normalizedMag < 0.15) {
      final t = (normalizedMag - 0.05) / 0.1;
      return Color.lerp(Colors.white, Colors.grey.shade100, t)!;
    } else if (normalizedMag < 0.3) {
      final t = (normalizedMag - 0.15) / 0.15;
      return Color.lerp(Colors.grey.shade100, Colors.grey.shade300, t)!;
    } else if (normalizedMag < 0.5) {
      final t = (normalizedMag - 0.3) / 0.2;
      return Color.lerp(Colors.grey.shade300, Colors.grey.shade500, t)!;
    } else if (normalizedMag < 0.7) {
      final t = (normalizedMag - 0.5) / 0.2;
      return Color.lerp(Colors.grey.shade500, Colors.grey.shade700, t)!;
    } else if (normalizedMag < 0.85) {
      final t = (normalizedMag - 0.7) / 0.15;
      return Color.lerp(Colors.grey.shade700, Colors.grey.shade900, t)!;
    } else {
      final t = (normalizedMag - 0.85) / 0.15;
      return Color.lerp(Colors.grey.shade900, Colors.black, t)!;
    }
  }

  @override
  bool shouldRepaint(covariant SpectrogramPainter oldDelegate) {
    // Determine if repaint is needed based on data or state changes
    final shouldRepaint = spectrogramData.length != oldDelegate.spectrogramData.length ||
           spectrogramData != oldDelegate.spectrogramData ||
           isRecording != oldDelegate.isRecording ||
           recordingDuration != oldDelegate.recordingDuration ||
           (isWavPlayback && wavController != null && 
            wavController!.currentPosition != oldDelegate.wavController?.currentPosition) ||
           isDragging != oldDelegate.isDragging ||
           dragProgress != oldDelegate.dragProgress ||
           playbackDelay != oldDelegate.playbackDelay;
    
    if (shouldRepaint) {
      developer.log('SpectrogramPainter: Repaint needed - data or state changed');
    }
    
    return shouldRepaint;
  }
}
