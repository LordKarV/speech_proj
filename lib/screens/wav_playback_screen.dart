import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:speech_app/widgets/spectrogram_widget.dart';
import 'package:speech_app/services/audio_service.dart';
import 'package:speech_app/services/audio_processing_service.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'dart:io';

import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_label.dart';
import '../theme/ app_colors.dart';
import '../theme/app_dimensions.dart';

/// Screen for playing back WAV files with speech analysis visualization
/// 
/// Features:
/// - Audio playback controls (play/pause/seek)
/// - Spectrogram visualization
/// - Speech analysis results display
/// - Integration with iOS audio processing service
class WavPlaybackScreen extends StatefulWidget {
  final String wavFilePath;
  final List<List<double>>? spectrogramData;
  final Duration? recordingDuration;
  
  const WavPlaybackScreen({
    super.key,
    required this.wavFilePath,
    this.spectrogramData,
    this.recordingDuration,
  });

  @override
  State<WavPlaybackScreen> createState() => _WavPlaybackScreenState();
}

class _WavPlaybackScreenState extends State<WavPlaybackScreen> 
    implements WavPlaybackController {
  
  // Audio Player
  FlutterSoundPlayer? _player;
  
  // Playback State
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  bool _hasFinishedPlaying = false;
  
  // Spectrogram Data
  List<List<double>> _spectrogramData = [];
  bool _isLoading = true;
  String _loadingStatus = 'Initializing...';
  
  // Seeking State
  bool _isSeeking = false;
  bool _isDragging = false;
  
  // File validation
  bool _isValidAudioFile = false;
  String? _audioFileError;

  // Analysis results from iOS processing service
  final List<Map<String, dynamic>> _analysisResults = [];

  @override
  void initState() {
    super.initState();
    developer.log('🎵 WavPlaybackScreen initState - File: ${widget.wavFilePath}');
    _initializePlayer();
  }

  /// Initialize the audio player and load necessary data
  Future<void> _initializePlayer() async {
    try {
      developer.log('🎵 Starting player initialization...');
      setState(() => _loadingStatus = 'Validating audio file...');
      
      await _validateAudioFile();
      
      if (!_isValidAudioFile) {
        developer.log('❌ Audio file validation failed: $_audioFileError');
        setState(() => _isLoading = false);
        _showError(_audioFileError ?? 'Invalid audio file');
        return;
      }
      
      setState(() => _loadingStatus = 'Initializing audio player...');
      
      _player = FlutterSoundPlayer();
      await _player!.openPlayer();
      
      developer.log('✅ Player opened successfully. Platform: ${Platform.isIOS ? "iOS" : Platform.isAndroid ? "Android" : "Other"}');
      
      if (widget.spectrogramData != null && widget.recordingDuration != null) {
        developer.log('🎵 Using pre-generated spectrogram data');
        _spectrogramData = widget.spectrogramData!;
        _totalDuration = widget.recordingDuration!;
        
        // Load analysis results from service
        _loadAnalysisResults();
        
        setState(() => _isLoading = false);
      } else {
        developer.log('🎵 Generating spectrogram from file...');
        await _loadSpectrogramUsingAudioService();
      }
      
      developer.log('✅ WAV Playback initialized - ${_spectrogramData.length} columns, ${_totalDuration.inSeconds}s duration');
      
    } catch (e, stackTrace) {
      developer.log('❌ Error initializing player: $e');
      developer.log('❌ Stack trace: $stackTrace');
      _showError('Failed to initialize audio player: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load analysis results from AudioProcessingService and format them for display
  void _loadAnalysisResults() async {
    _analysisResults.clear();
    
    // Get results from iOS service
    final results = AudioProcessingService.getLatestResults();
    
    if (results.isEmpty) {
      developer.log('⚠️ No analysis results available from iOS AudioProcessingService');
      return;
    }

    final totalSeconds = _totalDuration.inSeconds;
    
    for (final result in results) {
      if (result.success && result.probableMatches.isNotEmpty) {
        // Calculate time position based on fileIndex
        final segmentDuration = totalSeconds / results.length;
        final timeInSeconds = (result.fileIndex * segmentDuration + segmentDuration / 2).round();
        
        // Process each probable match
        for (int i = 0; i < result.probableMatches.length; i++) {
          final match = result.probableMatches[i];
          
          // Parse the match string (e.g., "repetition 1, probability 80")
          final parts = match.split(', probability ');
          final symptomName = parts.isNotEmpty ? parts[0] : 'Unknown symptom';
          final probabilityStr = parts.length > 1 ? parts[1] : '0';
          final probability = int.tryParse(probabilityStr) ?? 0;
          
          // Determine severity based on probability
          final severity = _getSeverityFromProbability(probability);
          final color = _getColorFromSeverity(severity);
          
          // Calculate slight time offset for multiple matches in same segment
          final adjustedTime = timeInSeconds + (i * 2);
          final finalTime = adjustedTime.clamp(0, totalSeconds - 1);
          
          final minutes = finalTime ~/ 60;
          final seconds = finalTime % 60;
          final timeString = '$minutes:${seconds.toString().padLeft(2, '0')}';
          
          _analysisResults.add({
            'type': _formatSymptomName(symptomName),
            'time': timeString,
            'seconds': finalTime,
            'severity': severity,
            'color': color,
            'description': _getSymptomDescription(symptomName),
            'probability': probability,
            'fileIndex': result.fileIndex,
          });
        }
      }
    }
    
    // Sort by time
    _analysisResults.sort((a, b) => a['seconds'].compareTo(b['seconds']));
    
    developer.log('🎯 Loaded ${_analysisResults.length} analysis results from iOS AudioProcessingService');
    
    // Update UI
    if (mounted) {
      setState(() {});
    }
  }

  /// Convert probability percentage to severity level
  String _getSeverityFromProbability(int probability) {
    if (probability >= 80) return 'Severe';
    if (probability >= 60) return 'Moderate';
    return 'Mild';
  }

  /// Get color for severity level
  Color _getColorFromSeverity(String severity) {
    switch (severity) {
      case 'Severe': return Colors.red;
      case 'Moderate': return Colors.orange;
      case 'Mild': return Colors.green;
      default: return Colors.grey;
    }
  }

  /// Format symptom names for display
  String _formatSymptomName(String symptomName) {
    // Convert "stutter symptom 1" to "Repetition 1" etc.
    if (symptomName.toLowerCase().contains('stutter symptom')) {
      final number = symptomName.replaceAll(RegExp(r'[^0-9]'), '');
      final types = ['Block', 'Repetition', 'Prolongation', 'Interjection'];
      final typeIndex = (int.tryParse(number) ?? 1) % types.length;
      return '${types[typeIndex]} $number';
    }
    return symptomName.replaceAll('stutter symptom', 'Speech Event');
  }

  /// Get description for symptom type
  String _getSymptomDescription(String symptomName) {
    if (symptomName.toLowerCase().contains('block')) return 'Speech blockage detected';
    if (symptomName.toLowerCase().contains('repetition')) return 'Sound repetition detected';
    if (symptomName.toLowerCase().contains('prolongation')) return 'Sound prolongation detected';
    if (symptomName.toLowerCase().contains('interjection')) return 'Filler word detected';
    return 'Speech disfluency detected';
  }

  /// Start audio playback from current position
  @override
  Future<void> play() async {
    if (_player == null || _isLoading) {
      developer.log('⚠️ Cannot play - player not ready. Player: ${_player == null ? "null" : "initialized"}, Loading: $_isLoading');
      return;
    }
    
    try {
      developer.log('🎵 Play attempt initiated. Current state - Playing: $_isPlaying, Finished: $_hasFinishedPlaying, Position: ${_currentPosition.inSeconds}s, Total Duration: ${_totalDuration.inSeconds}s');
      
      if (_hasFinishedPlaying && _currentPosition.inMilliseconds >= _totalDuration.inMilliseconds - 1000) {
        developer.log('🔄 Resetting to beginning - was at end and finished');
        _currentPosition = Duration.zero;
        _hasFinishedPlaying = false;
        setState(() {
          developer.log('🔄 UI updated with reset position: ${_currentPosition.inSeconds}s');
        });
      } else if (_hasFinishedPlaying) {
        developer.log('🔄 Clearing finished flag but keeping current position: ${_currentPosition.inSeconds}s');
        _hasFinishedPlaying = false;
      }
      
      developer.log('🎵 Starting playback from position: ${_currentPosition.inSeconds}s');
      
      final file = File(widget.wavFilePath);
      if (!await file.exists()) {
        developer.log('❌ File no longer exists at: ${widget.wavFilePath}');
        throw Exception('File no longer exists');
      }
      
      final fileSize = await file.length();
      developer.log('📁 Playing file: ${widget.wavFilePath}, Size: $fileSize bytes');
      
      try {
        developer.log('🛑 Stopping any existing playback...');
        await _player!.stopPlayer();
        await Future.delayed(const Duration(milliseconds: 150));
        developer.log('🛑 Existing playback stopped successfully');
      } catch (e) {
        developer.log('⚠️ No existing playback to stop or error stopping: $e');
      }
      
      setState(() {
        _isPlaying = true;
        developer.log('▶️ UI updated to playing state, _isPlaying: $_isPlaying');
      });
      
      developer.log('📊 Starting position tracking subscription...');
      await _player!.setSubscriptionDuration(const Duration(milliseconds: 50));
      developer.log('📊 Subscription duration set to 50ms for progress updates');
      _startPositionTracking();
      
      final playbackStartTime = DateTime.now().millisecondsSinceEpoch;
      developer.log('⏱️ Playback start time recorded: $playbackStartTime ms');
      
      developer.log('🎵 Initiating startPlayer with codec: pcm16WAV, URI: ${widget.wavFilePath}');
      await _player!.startPlayer(
        fromURI: widget.wavFilePath,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          final playbackEndTime = DateTime.now().millisecondsSinceEpoch;
          final playbackDuration = playbackEndTime - playbackStartTime;
          developer.log('🎵 Playback finished naturally after $playbackDuration ms');
          
          if (playbackDuration < 200) {
            developer.log('⚠️ Playback finished too quickly ($playbackDuration ms). Possible file format or corruption issue.');
            _showError('Playback ended immediately. File might be corrupted or incompatible.');
          }
          
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _hasFinishedPlaying = true;
              _currentPosition = _totalDuration;
              developer.log('🛑 UI updated to stopped state. Position set to end: ${_currentPosition.inSeconds}s, _isPlaying: $_isPlaying, _hasFinishedPlaying: $_hasFinishedPlaying');
            });
          }
        },
      );
      developer.log('✅ startPlayer call completed successfully');
      
      if (_currentPosition.inMilliseconds > 0) {
        developer.log('🎵 Seeking to current position: ${_currentPosition.inSeconds}s after playback start');
        await _player!.seekToPlayer(_currentPosition);
        developer.log('🎵 Seeked to: ${_currentPosition.inSeconds}s after start');
      } else {
        developer.log('🎵 No seek needed, starting from beginning');
      }
      
      developer.log('✅ Playback started successfully from ${_currentPosition.inSeconds}s');
      
    } catch (e, stackTrace) {
      developer.log('❌ Error starting playback: $e');
      developer.log('❌ Stack trace: $stackTrace');
      setState(() {
        _isPlaying = false;
        developer.log('❌ UI updated to stopped state due to error, _isPlaying: $_isPlaying');
      });
      _showError('Playback failed: $e. Check audio permissions and file validity.');
    }
  }

  /// Set up position tracking subscription for playback progress
  void _startPositionTracking() {
    _positionSubscription?.cancel();
    developer.log('📊 Position tracking subscription cancelled if existed, setting up new subscription');
    _positionSubscription = _player!.onProgress?.listen((event) {
      final newPosition = event.position;
      
      if (!_isDragging && !_isSeeking && mounted && _isPlaying && 
          newPosition.inMilliseconds <= _totalDuration.inMilliseconds + 1000) {
        
        setState(() {
          _currentPosition = newPosition;
          
          if (_currentPosition.inMilliseconds >= _totalDuration.inMilliseconds - 200) {
            _isPlaying = false;
            _hasFinishedPlaying = true;
            _currentPosition = _totalDuration;
          }
        });
      }
    });
    developer.log('📊 Position tracking subscription set up complete');
  }

  /// Pause audio playback
  @override
  Future<void> pause() async {
    if (_player == null) {
      developer.log('⚠️ Cannot pause - player not initialized');
      return;
    }
    
    try {
      developer.log('🎵 Pausing at ${_currentPosition.inSeconds}s');
      await _player!.pausePlayer();
      setState(() {
        _isPlaying = false;
        developer.log('⏸️ UI updated to paused state, _isPlaying: $_isPlaying');
      });
      _positionSubscription?.cancel();
      developer.log('⏸️ Playback paused and position tracking cancelled');
    } catch (e) {
      developer.log('❌ Error pausing: $e');
    }
  }

  /// Validate that the audio file exists and is properly formatted
  Future<void> _validateAudioFile() async {
    try {
      developer.log('🔍 Validating file: ${widget.wavFilePath}');
      
      final file = File(widget.wavFilePath);
      
      if (!await file.exists()) {
        _audioFileError = 'File does not exist: ${widget.wavFilePath}';
        developer.log('❌ File does not exist at specified path');
        return;
      }
      
      final fileSize = await file.length();
      developer.log('📁 File size: $fileSize bytes');
      if (fileSize < 44) {
        _audioFileError = 'File too small to be a valid WAV file ($fileSize bytes)';
        developer.log('❌ File too small for valid WAV');
        return;
      }
      
      try {
        final stat = await file.stat();
        developer.log('📁 File stats - Created: ${stat.changed}, Modified: ${stat.modified}, Accessed: ${stat.accessed}');
      } catch (e) {
        developer.log('⚠️ Could not retrieve file stats: $e');
      }
      
      _isValidAudioFile = true;
      developer.log('✅ Audio file validation passed');
      
    } catch (e) {
      _audioFileError = 'File validation error: $e';
      developer.log('❌ $_audioFileError');
    }
  }

  /// Load spectrogram data using AudioService
  Future<void> _loadSpectrogramUsingAudioService() async {
    try {
      developer.log('🎵 Loading spectrogram using AudioService...');
      
      final result = await AudioService.generateSpectrogram(
        filePath: widget.wavFilePath,
        onProgress: (status) {
          if (mounted) {
            setState(() => _loadingStatus = status);
          }
        },
      );
      
      _spectrogramData = result.data;
      _totalDuration = result.duration;
      
      // Load analysis results after spectrogram is loaded
      _loadAnalysisResults();
      
      setState(() => _isLoading = false);
      developer.log('✅ Spectrogram loaded - ${_spectrogramData.length} columns, ${_totalDuration.inSeconds}s');
      
    } catch (e) {
      setState(() => _isLoading = false);
      developer.log('❌ Error loading spectrogram: $e');
      _showError('Failed to load audio file: $e');
    }
  }

  // WavPlaybackController implementation
  @override
  bool get isPlaying => _isPlaying;
  
  @override
  Duration get currentPosition => _currentPosition;
  
  @override
  Duration get totalDuration => _totalDuration;
  
  @override
  int get currentColumnIndex {
    if (_totalDuration.inMilliseconds == 0 || _spectrogramData.isEmpty) return 0;
    final progress = _currentPosition.inMilliseconds / _totalDuration.inMilliseconds;
    return (progress * _spectrogramData.length).round().clamp(0, _spectrogramData.length - 1);
  }

  @override
  Future<void> seekToColumn(int columnIndex) async {
    if (_spectrogramData.isEmpty) return;
    
    final progress = columnIndex / _spectrogramData.length;
    final targetPosition = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round()
    );
    
    await seekToPosition(targetPosition);
  }

  @override
  Future<void> seekToPosition(Duration position) async {
    if (_player == null) {
      developer.log('⚠️ Cannot seek - player not initialized');
      return;
    }
    
    try {
      final seekStartTime = DateTime.now().millisecondsSinceEpoch;
      developer.log('🎵 Seeking to: ${position.inSeconds}s at $seekStartTime ms, Current State - Playing: $_isPlaying, Seeking: $_isSeeking, Dragging: $_isDragging');
      _isSeeking = true;
      _hasFinishedPlaying = false;
      
      setState(() {
        _currentPosition = position;
        developer.log('🎵 UI updated with seek position: ${_currentPosition.inSeconds}s');
      });
      
      if (_isPlaying) {
        await _player!.seekToPlayer(position);
        final seekEndTime = DateTime.now().millisecondsSinceEpoch;
        final seekDuration = seekEndTime - seekStartTime;
        developer.log('🎵 Seek operation completed to: ${position.inSeconds}s, Took: $seekDuration ms');
      } else {
        developer.log('🎵 Seek operation not performed on player as playback is paused/stopped');
      }
      
      _isSeeking = false;
      developer.log('🎵 Seeking state reset, _isSeeking: $_isSeeking');
    } catch (e) {
      _isSeeking = false;
      developer.log('❌ Seek error: $e, Resetting _isSeeking: $_isSeeking');
    }
  }

  /// Jump to a specific analysis result and start playback
  Future<void> _jumpToStutter(Map<String, dynamic> result) async {
    final targetSeconds = result['seconds'] as int;
    final targetPosition = Duration(seconds: targetSeconds);
    
    developer.log('🎯 Jumping to analysis result at ${targetSeconds}s: ${result['type']}');
    
    await seekToPosition(targetPosition);
    
    if (!_isPlaying) {
      await Future.delayed(const Duration(milliseconds: 300));
      await play();
    }
  }

/// Handle seek updates from spectrogram widget - SIMPLIFIED
void _handleSeekUpdate(double progress) {
  if (_totalDuration.inMilliseconds > 0) {
    final targetPosition = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round()
    );
    
    // ✅ ONLY update UI position during drag (no audio seeking)
    setState(() {
      _currentPosition = targetPosition;
    });
  }
}

/// Handle seek completion - ONLY for final audio seek
void _handleSeekComplete(double progress) {
  if (_totalDuration.inMilliseconds > 0) {
    final targetPosition = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round()
    );
    
    developer.log('🎯 Final audio seek to: ${targetPosition.inSeconds}s');
    
    setState(() {
      _hasFinishedPlaying = false;
      _currentPosition = targetPosition;
    });
    
    // ✅ ONLY seek audio on completion
    seekToPosition(targetPosition);
  }
}
  /// Format duration for display (MM:SS)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speech Analysis'),
        backgroundColor: AppColors.backgroundPrimary,
      ),
      backgroundColor: AppColors.backgroundPrimary,
      body: _isLoading ? _buildLoadingState() : _buildPlaybackInterface(),
    );
  }

  /// Build loading state UI
  Widget _buildLoadingState() {
    return Center(
      child: AppCard.elevated(
        padding: const EdgeInsets.all(AppDimensions.paddingXLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.accent,
              strokeWidth: 3,
            ),
            SizedBox(height: AppDimensions.marginLarge),
            AppLabel.primary(
              _loadingStatus,
              size: LabelSize.large,
              textAlign: TextAlign.center,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }

  /// Build main playback interface
  Widget _buildPlaybackInterface() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: SpectrogramWidget(
            spectrogramData: _spectrogramData,
            isRecording: false,
            recordingDuration: _totalDuration,
            isWavPlayback: true,
            wavController: this,
            onSeekUpdate: _handleSeekUpdate,
            onSeekComplete: _handleSeekComplete,
            onSeekStart: () {
              developer.log('🖱️ SpectrogramWidget seek started');
              setState(() {
                _isDragging = true;
                _isSeeking = true;
              });
            },
            onSeekEnd: () {
              developer.log('🖱️ SpectrogramWidget seek ended');
              setState(() {
                _isDragging = false;
                _isSeeking = false;
              });
            },
          ),
        ),
        
        _buildTinyControls(),
        
        Expanded(
          child: _buildActionableStutterList(),
        ),
      ],
    );
  }

  /// Build compact playback controls
  Widget _buildTinyControls() {
    return AppCard.basic(
      height: 80,
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.marginLarge,
        vertical: AppDimensions.marginSmall,
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Row(
        children: [
          AppButton.primary(
            onPressed: _isPlaying ? pause : play,
            size: ButtonSize.medium,
            child: Icon(
              _hasFinishedPlaying 
                  ? Icons.replay 
                  : (_isPlaying ? Icons.pause : Icons.play_arrow), 
              size: AppDimensions.iconMedium,
              color: Colors.white,
            ),
          ),
          
          SizedBox(width: AppDimensions.marginMedium),
          
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppLabel.primary(
                      _formatDuration(_currentPosition),
                      size: LabelSize.small,
                      fontWeight: FontWeight.w600,
                    ),
                    AppLabel.primary(
                      _formatDuration(_totalDuration),
                      size: LabelSize.small,
                      fontWeight: FontWeight.w600,
                    ),
                  ],
                ),
                
                SizedBox(height: AppDimensions.marginSmall),
                
                SizedBox(
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.accent,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 3,
                    ),
                    child: Slider(
                      value: _totalDuration.inMilliseconds > 0 
                          ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0,
                      onChangeStart: (value) {
                        developer.log('🖱️ Slider drag started, setting _isDragging: true');
                        setState(() {
                          _isDragging = true;
                          _isSeeking = true;
                        });
                      },
                      onChanged: (value) {
                        final targetPosition = Duration(
                          milliseconds: (_totalDuration.inMilliseconds * value).round()
                        );
                        setState(() => _currentPosition = targetPosition);
                      },
                      onChangeEnd: (value) {
                        final targetPosition = Duration(
                          milliseconds: (_totalDuration.inMilliseconds * value).round()
                        );
                        developer.log('🖱️ Slider drag ended, seeking to ${targetPosition.inSeconds}s');
                        
                        setState(() {
                          _hasFinishedPlaying = false;
                          _currentPosition = targetPosition;
                          _isDragging = false;
                          _isSeeking = false;
                        });
                        
                        seekToPosition(targetPosition);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build list of analysis results with tap-to-jump functionality
  Widget _buildActionableStutterList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.marginLarge,
            AppDimensions.marginMedium,
            AppDimensions.marginLarge,
            AppDimensions.marginSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppLabel.primary(
                'Speech Analysis Results',
                fontWeight: FontWeight.bold,
                size: LabelSize.large,
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingSmall,
                  vertical: AppDimensions.paddingXSmall,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundTertiary,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                ),
                child: AppLabel.primary(
                  '${_analysisResults.length}',
                  fontWeight: FontWeight.w500,
                  size: LabelSize.small,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _analysisResults.isEmpty 
            ? _buildNoResultsState()
            : ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.marginLarge,
                ),
                itemCount: _analysisResults.length,
                separatorBuilder: (context, index) => const SizedBox(
                  height: AppDimensions.marginSmall,
                ),
                itemBuilder: (context, index) {
                  final result = _analysisResults[index];
                  return AppCard.basic(
                    onTap: () => _jumpToStutter(result),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.paddingSmall,
                        horizontal: AppDimensions.paddingMedium,
                      ),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (result['color'] as Color).withOpacity(0.1),
                          
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                        ),
                        child: Icon(
                          _getIconForType(result['type']),
                          color: result['color'],
                          size: 20,
                        ),
                      ),
                      title: AppLabel.primary(
                        result['type'],
                        fontWeight: FontWeight.w600,
                        size: LabelSize.medium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AppLabel.secondary(
                          '${result['severity']} • ${result['probability']}% confidence',
                          size: LabelSize.small,
                        ),
                      ),
                      trailing: AppLabel.secondary(
                        result['time'],
                        fontWeight: FontWeight.w500,
                        size: LabelSize.small,
                      ),
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  /// Get appropriate icon for analysis result type
  IconData _getIconForType(String type) {
    if (type.toLowerCase().contains('block')) return Icons.block;
    if (type.toLowerCase().contains('repetition')) return Icons.repeat;
    if (type.toLowerCase().contains('prolongation')) return Icons.timeline;
    if (type.toLowerCase().contains('interjection')) return Icons.chat_bubble_outline;
    return Icons.analytics; // Default icon
  }

  /// Build empty state when no analysis results are available
  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 48,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: AppDimensions.marginMedium),
          AppLabel.secondary(
            'No speech events detected',
            size: LabelSize.medium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDimensions.marginSmall),
          AppLabel.tertiary(
            'The analysis didn\'t find any significant\nspeech disfluencies in this recording.',
            size: LabelSize.small,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Show error message to user
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppLabel.primary(message, color: Colors.white),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Show informational message to user
  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppLabel.primary(message, color: Colors.white),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    developer.log('🎵 Disposing...');
    _positionSubscription?.cancel();
    _player?.closePlayer();
    super.dispose();
  }
}
