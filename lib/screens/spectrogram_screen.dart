import 'package:flutter/material.dart';
import 'package:speech_app/screens/wav_playback_screen.dart';
import 'package:speech_app/widgets/spectrogram_widget.dart';
import 'package:speech_app/theme/app_dimensions.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../components/app_button.dart';
import '../components/app_card.dart';
import '../components/app_label.dart';
import '../services/audio_processing_service.dart';
import '../services/audio_service.dart';
import '../services/loading_service.dart';
import '../theme/ app_colors.dart';

/// Main screen for recording audio and displaying real-time spectrogram visualization
class SpectrogramScreen extends StatefulWidget {
  const SpectrogramScreen({super.key});

  @override
  State<SpectrogramScreen> createState() => _SpectrogramScreenState();
}

class _SpectrogramScreenState extends State<SpectrogramScreen> with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  
  // Stream subscriptions for audio service events
  StreamSubscription<AudioData>? _audioDataSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _recordingStateSubscription;
  
  // Recording state variables
  bool _isRecording = false;
  bool _isInitialized = false;
  String _currentError = '';
  
  // Audio visualization data
  double _currentAmplitude = 0.0;
  Duration _recordingDuration = Duration.zero;
  List<List<double>> _spectrogramData = [];
  
  // Animation controller for recording pulse effect
  late AnimationController _pulseController;
  
  // UI update timer for syncing with audio service
  Timer? _uiUpdateTimer;
  int _liveUpdateCount = 0;
  
  // Processing state variables
  bool _isProcessing = false;
  String _processingStatus = '';
  double _processingProgress = 0.0;
  bool _canCancelProcessing = true;

  @override
  void initState() {
    super.initState();
    developer.log('🎛️ SpectrogramScreen: Initializing...');
    _initializeAnimation();
    _startUIUpdateTimer();
    _initializeAudioService();
  }

  /// Initialize the pulse animation controller for recording visual feedback
  void _initializeAnimation() {
    developer.log('🎨 SpectrogramScreen: Setting up pulse animation');
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  /// Initialize the audio service and set up recording capabilities
  Future<void> _initializeAudioService() async {
    try {
      developer.log('🎛️ SpectrogramScreen: Initializing audio service...');
      
      final success = await _audioService.initialize();
      
      if (success) {
        setState(() {
          _isInitialized = true;
        });
        
        _setupStreamListeners();
        developer.log('✅ SpectrogramScreen: Audio service initialized successfully');
        await _startRecording();
      } else {
        setState(() {
          _currentError = 'Failed to initialize audio service';
        });
        developer.log('❌ SpectrogramScreen: Audio service initialization failed');
      }
    } catch (e) {
      setState(() {
        _currentError = 'Audio service error: $e';
      });
      developer.log('❌ SpectrogramScreen: Audio service initialization error: $e');
    }
  }

  /// Set up stream listeners for audio data, recording state, and errors
  void _setupStreamListeners() {
    developer.log('🎛️ SpectrogramScreen: Setting up stream listeners...');
    _cancelStreamSubscriptions();
    int streamUpdateCounter = 0;
    const int addEveryNUpdates = 1;
    
    // Listen to audio data stream for real-time updates
    _audioDataSubscription = _audioService.audioDataStream.listen(
      (audioData) {
        _liveUpdateCount++;
        streamUpdateCounter++;
        
        if (mounted) {
          setState(() {
            _currentAmplitude = audioData.amplitude;
            _recordingDuration = audioData.duration;
            
            // Add spectrogram column data with throttling
            if (audioData.spectrogramColumn != null && streamUpdateCounter >= addEveryNUpdates) {
              _spectrogramData.add(List<double>.from(audioData.spectrogramColumn!));
              streamUpdateCounter = 0;
              developer.log('📊 SpectrogramScreen: Added spectrogram column, total: ${_spectrogramData.length}');
            }
          });
          
          // Control pulse animation based on audio activity
          if (_isRecording && audioData.amplitude > 0.0) {
            if (!_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            }
          } else if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }
      },
      onError: (error) {
        developer.log('❌ SpectrogramScreen: Audio data stream error: $error');
        if (mounted) {
          setState(() {
            _currentError = 'Audio stream error: $error';
          });
        }
      },
    );
    
    // Listen to recording state changes
    _recordingStateSubscription = _audioService.recordingStateStream.listen(
      (isRecording) {
        developer.log('🎛️ SpectrogramScreen: Recording state changed: $isRecording');
        if (mounted) {
          setState(() {
            _isRecording = isRecording;
          });
          
          if (!isRecording) {
            _pulseController.stop();
            _pulseController.reset();
          }
        }
      },
    );
    
    // Listen to error stream
    _errorSubscription = _audioService.errorStream.listen(
      (error) {
        developer.log('❌ SpectrogramScreen: Received error: $error');
        if (mounted) {
          setState(() {
            _currentError = error;
          });
          
          _showErrorSnackBar('Audio Error: $error');
        }
      },
    );
    
    developer.log('✅ SpectrogramScreen: Stream listeners set up successfully');
  }

  /// Start periodic UI updates to sync with audio service data
  void _startUIUpdateTimer() {
    developer.log('⏰ SpectrogramScreen: Starting UI update timer');
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording && mounted) {
        final currentAmplitude = _audioService.currentAmplitude;
        final currentDuration = _audioService.recordingDuration;
        final serviceSpectrogramData = _audioService.spectrogramData;
        
        // Sync spectrogram data if service has more data than UI
        if (serviceSpectrogramData.length > _spectrogramData.length) {
          developer.log('🔄 SpectrogramScreen: Syncing spectrogram data - Service: ${serviceSpectrogramData.length}, UI: ${_spectrogramData.length}');
          
          setState(() {
            _spectrogramData = List<List<double>>.from(
              serviceSpectrogramData.map((col) => List<double>.from(col))
            );
            _currentAmplitude = currentAmplitude;
            _recordingDuration = currentDuration;
          });
        }
      }
    });
  }

  /// Cancel all active stream subscriptions
  void _cancelStreamSubscriptions() {
    developer.log('🗑️ SpectrogramScreen: Canceling stream subscriptions');
    _audioDataSubscription?.cancel();
    _errorSubscription?.cancel();
    _recordingStateSubscription?.cancel();
    _audioDataSubscription = null;
    _errorSubscription = null;
    _recordingStateSubscription = null;
  }

  /// Start audio recording and reset visualization data
  Future<void> _startRecording() async {
    if (!_isInitialized) {
      developer.log('⚠️ SpectrogramScreen: Cannot start recording - service not initialized');
      _showWarningSnackBar('Audio service not initialized');
      return;
    }

    developer.log('🎛️ SpectrogramScreen: Starting recording...');
    _liveUpdateCount = 0;
    
    setState(() {
      _spectrogramData.clear();
      _currentAmplitude = 0.0;
      _recordingDuration = Duration.zero;
    });
    
    final success = await _audioService.startRecording();
    
    if (success) {
      developer.log('✅ SpectrogramScreen: Recording started successfully');
      
      // Re-setup stream listeners if needed
      if (_audioDataSubscription == null) {
        developer.log('⚠️ SpectrogramScreen: Stream subscription was null, re-setting up...');
        _setupStreamListeners();
      }
    } else {
      developer.log('❌ SpectrogramScreen: Failed to start recording');
      _showErrorSnackBar('Failed to start recording');
    }
  }

  /// Stop audio recording and start processing workflow
  Future<void> _stopRecording() async {
    developer.log('🎛️ SpectrogramScreen: Stopping recording...');
    
    await _audioService.stopRecording();
    
    developer.log('✅ SpectrogramScreen: Recording stopped successfully. Total live updates received: $_liveUpdateCount');
    
    // Start processing workflow for audio analysis
    await _startProcessingWorkflow();
  }

  /// Start the audio processing workflow with loading states
  Future<void> _startProcessingWorkflow() async {
    final recordingPath = _audioService.lastRecordingPath;
    
    if (recordingPath == null || recordingPath.isEmpty) {
      developer.log('❌ SpectrogramScreen: No recording path available');
      _showErrorSnackBar('Recording file not found');
      return;
    }

    // Show processing overlay
    setState(() {
      _isProcessing = true;
      _processingStatus = 'Preparing audio for analysis...';
      _processingProgress = 0.0;
      _canCancelProcessing = true;
    });

    try {
      developer.log('🔄 SpectrogramScreen: Starting audio processing workflow...');

      LoadingService.show(context);

      // Update processing status
      setState(() {
        _processingStatus = 'Sending audio segments to iOS...';
        _processingProgress = 0.3;
      });

      // Process audio file and get analysis results
      final List<AudioAnalysisResult> results = await AudioProcessingService.processAudioFile(
        filePath: recordingPath
      );

      // Update completion status
      setState(() {
        _processingStatus = 'Processing complete! Got ${results.length} results';
        _processingProgress = 1.0;
      });

      LoadingService.hide();

      developer.log('✅ SpectrogramScreen: Processing workflow completed successfully');
      developer.log('📊 SpectrogramScreen: Received ${results.length} analysis results from iOS');

      // Log results for debugging
      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        developer.log('📋 SpectrogramScreen: Segment $i: ${result.success ? 'Success' : 'Failed'} - ${result.probableMatches.length} matches');
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Navigate to playback with results
        _navigateToPlayback();
      }

    } catch (e) {
      developer.log('❌ SpectrogramScreen: Processing failed: $e');
      
      LoadingService.hide();
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Processing failed: $e';
        });
        
        _showErrorSnackBar('Processing failed: $e');
        
        // Navigate to playback even if processing failed
        _navigateToPlayback();
      }
    }
  }

  /// Cancel processing and navigate to playback
  void _cancelProcessing() {
    developer.log('🚫 SpectrogramScreen: Canceling processing');
    setState(() {
      _isProcessing = false;
      _canCancelProcessing = false;
    });
    
    _navigateToPlayback();
  }

  /// Navigate to the playback screen with recorded audio and spectrogram data
  void _navigateToPlayback() {
    final recordingPath = _audioService.lastRecordingPath;
    
    if (recordingPath != null && recordingPath.isNotEmpty) {
      developer.log('🎵 SpectrogramScreen: Navigating to playback with file: $recordingPath');
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => WavPlaybackScreen(
            wavFilePath: recordingPath,
            spectrogramData: _spectrogramData,
            recordingDuration: _recordingDuration,
          ),
        ),
      );
    } else {
      developer.log('❌ SpectrogramScreen: No recording path available for playback');
      _showErrorSnackBar('Recording file not found');
    }
  }

  /// Cancel recording and return to previous screen
  void _cancelAndGoBack() {
    developer.log('🔙 SpectrogramScreen: Canceling and going back');
    _stopRecording();
    Navigator.of(context).pop();
  }

  /// Get formatted current date string
  String _getCurrentDate() {
    final now = DateTime.now();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  /// Show error message in a snackbar
  void _showErrorSnackBar(String message) {
    developer.log('🚨 SpectrogramScreen: Showing error snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppLabel.primary(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning message in a snackbar
  void _showWarningSnackBar(String message) {
    developer.log('⚠️ SpectrogramScreen: Showing warning snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppLabel.primary(message),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: _buildBody(),
    );
  }

  /// Build the main body of the screen
  Widget _buildBody() {
    if (!_isInitialized) {
      return _buildLoadingState();
    }

    return Column(
      children: [
        // Date and close button header
        _buildTopHeader(),

        // Main spectrogram visualization area
        _buildSpectrogramArea(),

        const SizedBox(height: AppDimensions.marginLarge),

        // Recording controls
        _buildControlBar(),

        // Error display if present
        if (_currentError.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.marginMedium),
          _buildErrorCard(),
        ],

        const Spacer(),
      ],
    );
  }

  /// Build loading state while initializing audio service
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 3,
          ),
          SizedBox(height: AppDimensions.marginLarge),
          AppLabel.secondary(
            'Initializing audio system...',
            size: LabelSize.large,
          ),
        ],
      ),
    );
  }

  /// Build top header with date and close button
  Widget _buildTopHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLarge),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppLabel.primary(
              _getCurrentDate(),
              size: LabelSize.large,
              fontWeight: FontWeight.bold,
            ),
            AppButton.secondary(
              onPressed: _cancelAndGoBack,
              size: ButtonSize.small,
              child: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  /// Build spectrogram visualization area
  Widget _buildSpectrogramArea() {
    return AppCard.basic(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.marginLarge),
      padding: const EdgeInsets.all(AppDimensions.paddingLarge),
      child: SizedBox(
        height: 300,
        width: double.infinity,
        child: _spectrogramData.isEmpty 
          ? _buildEmptySpectrogramState()
          : SpectrogramWidget(
              spectrogramData: _spectrogramData,
              isRecording: _isRecording,
              recordingDuration: _recordingDuration,
            ),
      ),
    );
  }

  /// Build empty state for spectrogram when no data is available
  Widget _buildEmptySpectrogramState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              Icons.graphic_eq_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: AppDimensions.marginLarge),
          AppLabel.primary(
            'Audio Spectrogram',
            size: LabelSize.large,
            fontWeight: FontWeight.bold,
          ),
          SizedBox(height: AppDimensions.marginSmall),
          AppLabel.secondary(
            'Start recording to see live audio visualization',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build control bar with recording controls and duration display
  Widget _buildControlBar() {
    return AppCard.basic(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.marginLarge),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingXLarge,
        vertical: AppDimensions.paddingLarge,
      ),
      child: Row(
        children: [
          // Cancel button
          AppButton.secondary(
            onPressed: _cancelAndGoBack,
            child: Text('Cancel'),
          ),

          const Spacer(),

          // Main record/stop button
          AppButton.primary(
            onPressed: _isRecording ? _stopRecording : _startRecording,
            size: ButtonSize.large,
            isLoading: !_isInitialized,
            child: Icon(
              _isRecording ? Icons.stop : Icons.fiber_manual_record,
              color: _isRecording ? AppColors.error : AppColors.textPrimary,
            ),
          ),

          const Spacer(),

          // Recording duration display
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMedium,
              vertical: AppDimensions.paddingSmall,
            ),
            decoration: BoxDecoration(
              color: _isRecording ? AppColors.accent.withOpacity(0.1) : AppColors.backgroundTertiary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
              border: Border.all(color: AppColors.border),
            ),
            child: AppLabel.primary(
              '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
              size: LabelSize.medium,
              fontWeight: FontWeight.bold,
              color: _isRecording ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build error card to display current errors
  Widget _buildErrorCard() {
    return AppCard.basic(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.marginLarge),
      color: AppColors.error.withOpacity(0.1),
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: AppDimensions.iconMedium,
          ),
          SizedBox(width: AppDimensions.marginSmall),
          Expanded(
            child: AppLabel.primary(
              _currentError,
              color: AppColors.error,
            ),
          ),
          AppButton.secondary(
            onPressed: () {
              setState(() {
                _currentError = '';
              });
            },
            size: ButtonSize.small,
            child: Icon(
              Icons.close_rounded,
              size: AppDimensions.iconMedium,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    developer.log('🗑️ SpectrogramScreen: Disposing resources...');
    
    _uiUpdateTimer?.cancel();
    _pulseController.dispose();
    _cancelStreamSubscriptions();
    _audioService.dispose();
    
    super.dispose();
  }
}
