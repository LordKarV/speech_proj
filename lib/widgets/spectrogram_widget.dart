import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:speech_app/widgets/spectogram_painter.dart';

import '../config/audio_config.dart';

/// Interface for controlling WAV file playback
/// Provides methods for play/pause control and seeking functionality
abstract class WavPlaybackController {
  bool get isPlaying;
  Duration get currentPosition;
  Duration get totalDuration;
  int get currentColumnIndex;
  Future<void> play();
  Future<void> pause();
  Future<void> seekToColumn(int columnIndex);
  Future<void> seekToPosition(Duration position);
}

/// Interactive spectrogram widget that displays audio frequency data
/// Supports both recording visualization and WAV playback with seeking
class SpectrogramWidget extends StatefulWidget {
  /// 2D array representing frequency data over time
  final List<List<double>> spectrogramData;
  
  /// Whether the widget is currently recording audio
  final bool isRecording;
  
  /// Duration of current recording session
  final Duration recordingDuration;
  
  /// Whether the widget is in WAV playback mode (enables seeking)
  final bool isWavPlayback;
  
  /// Controller for WAV playback operations
  final WavPlaybackController? wavController;
  
  /// Callback fired when user starts seeking
  final VoidCallback? onSeekStart;
  
  /// Callback fired when user ends seeking
  final VoidCallback? onSeekEnd;
  
  /// Callback for visual position updates during dragging (no audio seeking)
  final Function(double progress)? onSeekUpdate;
  
  /// Callback for final audio seeking when drag completes
  final Function(double progress)? onSeekComplete;
  
  /// Delay compensation for audio playback synchronization
  final Duration playbackDelay;

  const SpectrogramWidget({
    super.key,
    required this.spectrogramData,
    this.isRecording = false,
    this.recordingDuration = Duration.zero,
    this.isWavPlayback = false,
    this.wavController,
    this.onSeekStart,
    this.onSeekEnd,
    this.onSeekUpdate,
    this.onSeekComplete,
    // Delay to compensate for audio processing latency
    this.playbackDelay = const Duration(milliseconds: AudioConfig.delayPlayback),
  });

  @override
  State<SpectrogramWidget> createState() => _SpectrogramWidgetState();
}

class _SpectrogramWidgetState extends State<SpectrogramWidget> {
  /// Whether user is currently dragging to seek
  bool _isDragging = false;
  
  /// Current drag position as progress (0.0 to 1.0)
  double _dragProgress = 0.0;
  
  /// Remembers if audio was playing before user started seeking
  bool _wasPlayingBeforeDrag = false;

  @override
  Widget build(BuildContext context) {
    developer.log('SpectrogramWidget: Building widget with ${widget.spectrogramData.length} data points');
    
    // Show empty state if no spectrogram data available
    if (widget.spectrogramData.isEmpty) {
      developer.log('SpectrogramWidget: No spectrogram data available, showing empty state');
      return _buildEmptyState();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        developer.log('SpectrogramWidget: Layout constraints - width: ${constraints.maxWidth}, height: ${constraints.maxHeight}');
        
        return GestureDetector(
          // Only enable touch interactions for WAV playback mode
          onTapDown: widget.isWavPlayback ? _handleTapDown : null,
          onPanStart: widget.isWavPlayback ? _handlePanStart : null,
          onPanUpdate: widget.isWavPlayback ? _handlePanUpdate : null,
          onPanEnd: widget.isWavPlayback ? _handlePanEnd : null,
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: SpectrogramPainter(
              spectrogramData: widget.spectrogramData,
              isRecording: widget.isRecording,
              recordingDuration: widget.recordingDuration,
              isWavPlayback: widget.isWavPlayback,
              wavController: widget.wavController,
              isDragging: _isDragging,
              dragProgress: _dragProgress,
              playbackDelay: widget.playbackDelay,
            ),
          ),
        );
      },
    );
  }

  /// Handles tap down events for immediate seeking
  void _handleTapDown(TapDownDetails details) {
    if (widget.wavController == null || !widget.isWavPlayback) {
      developer.log('SpectrogramWidget: Tap ignored - no controller or not in playback mode');
      return;
    }
    
    developer.log('SpectrogramWidget: Tap detected at x: ${details.localPosition.dx}');
    
    // Remember current playback state and pause if playing
    _wasPlayingBeforeDrag = widget.wavController!.isPlaying;
    if (_wasPlayingBeforeDrag) {
      developer.log('SpectrogramWidget: Pausing playback for tap seek');
      widget.wavController!.pause();
    }
    
    // Notify parent that seeking has started
    widget.onSeekStart?.call();
    
    setState(() {
      _isDragging = true;
    });
    
    // Calculate seek position and immediately seek for tap
    final progress = _calculateProgress(details.localPosition.dx);
    developer.log('SpectrogramWidget: Tap seek to progress: ${(progress * 100).toStringAsFixed(1)}%');
    
    _updateDragProgress(progress);
    _seekToPositionComplete(progress);
  }

  /// Handles start of drag gesture for seeking
  void _handlePanStart(DragStartDetails details) {
    if (widget.wavController == null || !widget.isWavPlayback) {
      developer.log('SpectrogramWidget: Drag start ignored - no controller or not in playback mode');
      return;
    }
    
    developer.log('SpectrogramWidget: Drag started at x: ${details.localPosition.dx}');
    
    // Remember current playback state and pause if playing
    _wasPlayingBeforeDrag = widget.wavController!.isPlaying;
    if (_wasPlayingBeforeDrag) {
      developer.log('SpectrogramWidget: Pausing playback for drag seek');
      widget.wavController!.pause();
    }
    
    // Notify parent that seeking has started
    widget.onSeekStart?.call();
    
    setState(() {
      _isDragging = true;
    });
  }

  /// Handles drag update events for visual seeking feedback
  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.wavController == null || !widget.isWavPlayback || !_isDragging) {
      return;
    }
    
    // Calculate progress
    final progress = _calculateProgress(details.localPosition.dx);
    
    // ✅ ONLY update local drag state for smooth visual feedback
    setState(() {
      _dragProgress = progress;
    });
    
    // ✅ ONLY notify parent for UI updates (no audio seeking during drag)
    widget.onSeekUpdate?.call(progress);
  }

  /// Handles end of drag gesture and performs final audio seeking
  void _handlePanEnd(DragEndDetails details) {
    if (widget.wavController == null || !widget.isWavPlayback) {
      return;
    }
    
    developer.log('SpectrogramWidget: Drag ended at progress: ${(_dragProgress * 100).toStringAsFixed(1)}%');
    
    // Perform final audio seek to drag position
    _seekToPositionComplete(_dragProgress);
    
    setState(() {
      _isDragging = false;
    });
    
    // Notify parent that seeking has ended
    widget.onSeekEnd?.call();
    
    // Resume playback if it was playing before drag started
    if (_wasPlayingBeforeDrag) {
      developer.log('SpectrogramWidget: Resuming playback after drag');
      Future.delayed(const Duration(milliseconds: 200), () {
        widget.wavController!.play();
      });
    }
  }

  /// Calculates seek progress from horizontal touch position
  /// Returns progress value between 0.0 and 1.0
double _calculateProgress(double x) {
  final RenderBox renderBox = context.findRenderObject() as RenderBox;
  final width = renderBox.size.width;
  
  // Left drag = forward in time, Right drag = backward in time
  final progress = (1.0 - (x / width)).clamp(0.0, 1.0);
  developer.log('SpectrogramWidget: Progress: ${(progress * 100).toStringAsFixed(1)}% from x: $x (inverted)');
  
  return progress;
}


  /// Updates visual drag progress for UI feedback
  void _updateDragProgress(double progress) {
    setState(() {
      _dragProgress = progress;
    });
    developer.log('SpectrogramWidget: Updated drag progress to: ${(progress * 100).toStringAsFixed(1)}%');
  }

  /// Performs final audio seeking with delay compensation
  void _seekToPositionComplete(double progress) {
    // Calculate raw target position from progress
    final rawTargetPosition = Duration(
      milliseconds: (widget.wavController!.totalDuration.inMilliseconds * progress).round()
    );
    
    // Apply delay compensation by seeking ahead
    final compensatedPosition = Duration(
      milliseconds: math.max(0, rawTargetPosition.inMilliseconds - widget.playbackDelay.inMilliseconds)
    );
    
    developer.log('SpectrogramWidget: Seeking - Raw: ${rawTargetPosition.inSeconds}s, '
        'Compensated: ${compensatedPosition.inSeconds}s (delay: ${widget.playbackDelay.inMilliseconds}ms)');
    
    // Use callback for seeking if available, otherwise fallback to direct seeking
    if (widget.onSeekComplete != null) {
      widget.onSeekComplete!(progress);
    } else {
      developer.log('SpectrogramWidget: Using direct seeking fallback');
      widget.wavController!.seekToPosition(compensatedPosition);
    }
  }

  /// Builds empty state widget when no spectrogram data is available
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade100,
      child: const Center(
        child: Text(
          'No audio data',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
