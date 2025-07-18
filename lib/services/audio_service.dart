import 'dart:convert';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart'; // Add this import
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'dart:typed_data';
import '../config/audio_config.dart';
import 'fft_service.dart';

/// Container for audio analysis data
class AudioData {
  final double amplitude;
  final Duration duration;
  final List<double>? spectrogramColumn;
  final double? rawDb;
  final String? filePath;
  
  AudioData({
    required this.amplitude, 
    required this.duration,
    this.spectrogramColumn,
    this.rawDb,
    this.filePath,
  });
  
  @override
  String toString() => 'AudioData(amplitude: ${amplitude.toStringAsFixed(3)}, duration: ${duration.inMilliseconds}ms, rawDb: $rawDb)';
}

/// Service for audio recording, playback, and real-time spectrogram analysis
class AudioService {
  // Flutter Sound components
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _playerSubscription;

  // Stream controllers for real-time data
  final StreamController<AudioData> _audioDataController = StreamController<AudioData>.broadcast();
  final StreamController<String> _errorController = StreamController<String>.broadcast();
  final StreamController<bool> _recordingStateController = StreamController<bool>.broadcast();
  
  // Public streams for UI components
  Stream<AudioData> get audioDataStream => _audioDataController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  // Spectrogram data storage
  final List<List<double>> _spectrogramData = [];
  List<List<double>> get spectrogramData => List.from(_spectrogramData);
  
  // Timing compensation for real-time analysis
  final List<DateTime> _columnTimestamps = [];
  DateTime? _recordingStartTime;
  Duration _processingDelay = Duration.zero;
  Duration _averageProcessingTime = Duration.zero;
  final List<Duration> _recentProcessingTimes = [];
  
  // Audio processing configuration
  final List<double> _audioBuffer = [];
  static int get _bufferSize => AudioConfig.bufferSize;
  static int get _hopSize => AudioConfig.hopSize;
  
  // Recording state tracking
  double _currentAmplitude = 0.0;
  Duration _recordingDuration = Duration.zero;
  String? _currentFilePath;
  String? _lastRecordingPath;
  
  // Audio analysis statistics
  int _processedWindows = 0;
  
  // Recording state flags
  bool _isRecording = false;
  bool _isInitialized = false;

  // Audio stream handling for real-time processing
  StreamController<Uint8List>? _audioStreamController;
  StreamSink<Uint8List>? _audioStreamSink;
  
  // Raw audio data storage for WAV file creation
  final List<double> _recordedSamples = [];

  // Timing compensation constants
  static const Duration _maxProcessingDelay = Duration(milliseconds: 200);
  static const int _timingHistorySize = 50;

  // Public getters for service state
  FlutterSoundRecorder? get recorder => _recorder;
  FlutterSoundPlayer? get player => _player;
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  double get currentAmplitude => _currentAmplitude;
  Duration get recordingDuration => _recordingDuration;
  String? get currentFilePath => _currentFilePath;
  String? get lastRecordingPath => _lastRecordingPath;
  
  // Timing compensation getters
  Duration get processingDelay => _processingDelay;
  Duration get averageProcessingTime => _averageProcessingTime;
  double get timePerColumn => AudioConfig.timePerColumn;

  /// Gets timing-compensated position for a spectrogram column
  /// Accounts for processing delays in real-time analysis
  Duration getCompensatedColumnTime(int columnIndex) {
    developer.log('AudioService: Getting compensated time for column $columnIndex');
    
    if (columnIndex < 0 || columnIndex >= _columnTimestamps.length || _recordingStartTime == null) {
      // Fallback to calculated time if no timing data available
      return Duration(milliseconds: (columnIndex * timePerColumn * 1000).round());
    }
    
    // Use actual timestamp when the column was generated
    final actualTime = _columnTimestamps[columnIndex].difference(_recordingStartTime!);
    
    // Apply predictive compensation for processing delay
    final compensatedTime = actualTime - _processingDelay;
    
    return Duration(milliseconds: math.max(0, compensatedTime.inMilliseconds));
  }

  /// Finds the spectrogram column index closest to a target time
  /// Uses timing compensation when available
  int getColumnIndexForTime(Duration targetTime) {
    developer.log('AudioService: Finding column index for time ${targetTime.inMilliseconds}ms');
    
    if (_columnTimestamps.isEmpty || _recordingStartTime == null) {
      // Fallback to calculated position
      return (targetTime.inMilliseconds / 1000.0 / timePerColumn).round()
          .clamp(0, _spectrogramData.length - 1);
    }
    
    // Find the column closest to the target time using actual timestamps
    int bestIndex = 0;
    Duration bestDifference = Duration(days: 1);
    
    for (int i = 0; i < _columnTimestamps.length; i++) {
      final compensatedTime = getCompensatedColumnTime(i);
      final difference = (compensatedTime - targetTime).abs();
      
      if (difference < bestDifference) {
        bestDifference = difference;
        bestIndex = i;
      }
    }
    
    return bestIndex.clamp(0, _spectrogramData.length - 1);
  }

  /// Delegates spectrogram generation to FFTService
  /// Supports both file-based and sample-based input
  static Future<SpectrogramResult> generateSpectrogram({
    String? filePath,              
    List<double>? audioSamples,    
    Function(String)? onProgress,  
  }) async {
    developer.log('AudioService: Delegating spectrogram generation to FFTService');
    return await FFTService.generateSpectrogram(
      filePath: filePath,
      audioSamples: audioSamples,
      onProgress: onProgress,
    );
  }

  /// Initializes the audio recording and playback system
  /// Requests microphone permissions and sets up Flutter Sound
  Future<bool> initialize() async {
    developer.log('AudioService: Starting initialization');
    
    try {
      // Request microphone permission
      developer.log('AudioService: Requesting microphone permission');
      final status = await Permission.microphone.request();
      developer.log('AudioService: Permission status: $status');
      
      if (status != PermissionStatus.granted) {
        developer.log('AudioService: Microphone permission denied');
        _safeAddError('Microphone permission denied');
        return false;
      }
      
      developer.log('AudioService: Microphone permission granted');
      
      // Initialize Flutter Sound components
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();
      
      await _recorder!.openRecorder();
      await _player!.openPlayer();
      
      _isInitialized = true;
      developer.log('AudioService: Initialization complete');
      developer.log('AudioService: FFT Quality Settings: ${FFTService.getQualitySettings()}');
      return true;
      
    } catch (e) {
      developer.log('AudioService: Initialization error: $e');
      _safeAddError('Audio initialization failed: $e');
      return false;
    }
  }

  /// Safely adds error to stream controller if not closed
  void _safeAddError(String error) {
    developer.log('AudioService: Error occurred: $error');
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  /// Safely adds audio data to stream controller if not closed
  void _safeAddAudioData(AudioData data) {
    if (!_audioDataController.isClosed) {
      _audioDataController.add(data);
    }
  }

  /// Safely adds recording state to stream controller if not closed
  void _safeAddRecordingState(bool state) {
    developer.log('AudioService: Recording state changed to: $state');
    if (!_recordingStateController.isClosed) {
      _recordingStateController.add(state);
    }
  }

  /// Generates unique file path for audio recordings
  /// Creates directory if it doesn't exist
  Future<String> getRecordingPath() async {
    developer.log('AudioService: Generating recording file path');
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'speech_recording_$timestamp.wav';
    final fullPath = '${directory.path}/$fileName';
    
    developer.log('AudioService: Recording path: $fullPath');
    
    // Ensure directory exists
    final dir = Directory(directory.path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      developer.log('AudioService: Created documents directory');
    }
    
    return fullPath;
  }

  /// Starts audio recording with real-time spectrogram analysis
  /// Sets up audio stream processing and timing compensation
  Future<bool> startRecording() async {
    developer.log('AudioService: Starting recording');
    
    if (!_isInitialized || _recorder == null) {
      developer.log('AudioService: Recorder not initialized');
      _safeAddError('Recorder not initialized');
      return false;
    }

    if (_isRecording) {
      developer.log('AudioService: Already recording');
      return true;
    }

    try {
      // Clear previous recording data
      _spectrogramData.clear();
      _columnTimestamps.clear();
      _audioBuffer.clear();
      _recordedSamples.clear();
      _resetTimingCompensation();
      
      // Reset FFTService tracking for new session
      FFTService.resetTracking();
      
      _recordingStartTime = DateTime.now();
      
      // Generate unique file path for this recording
      _currentFilePath = await getRecordingPath();
      developer.log('AudioService: Recording to file: $_currentFilePath');
      
      // Setup audio stream for real-time processing
      _setupAudioStream();
      
      // Start Flutter Sound recorder
      await _recorder!.startRecorder(
        toStream: _audioStreamSink!,
        codec: Codec.pcm16,
        numChannels: AudioConfig.channels, 
        sampleRate: AudioConfig.sampleRate, 
      );

      _isRecording = true;
      _safeAddRecordingState(true);
      
      // Setup decibel level monitoring
      await _setupDbMonitoring();
      
      developer.log('AudioService: Recording started successfully');
      return true;
      
    } catch (e, stackTrace) {
      developer.log('AudioService: Recording start error: $e');
      developer.log('AudioService: Stack trace: $stackTrace');
      _safeAddError('Recording start failed: $e');
      _isRecording = false;
      _safeAddRecordingState(false);
      return false;
    }
  }

  /// Sets up audio stream controller for real-time processing
  /// Handles incoming audio data and error conditions
  void _setupAudioStream() {
    developer.log('AudioService: Setting up audio stream');
    
    _audioStreamController = StreamController<Uint8List>();
    _audioStreamSink = _audioStreamController!.sink;
    
    _audioStreamController!.stream.listen(
      (audioBytes) {
        _processRawAudioData(audioBytes);
      },
      onError: (error) {
        developer.log('AudioService: Audio stream error: $error');
        _safeAddError('Audio stream error: $error');
      },
      onDone: () {
        developer.log('AudioService: Audio stream completed');
      },
    );
  }

/// Processes raw audio bytes from the microphone
/// Converts to samples, buffers data, and performs FFT analysis
void _processRawAudioData(Uint8List audioBytes) {
  try {
    // Convert raw bytes to normalized audio samples
    final samples = <double>[];
    for (int i = 0; i < audioBytes.length; i += 2) {
      if (i + 1 < audioBytes.length) {
        final sample = (audioBytes[i] | (audioBytes[i + 1] << 8)).toSigned(16);
        final normalizedSample = sample / 32768.0;
        samples.add(normalizedSample);
        _recordedSamples.add(normalizedSample);
      }
    }

    if (samples.isEmpty) return;

    // Add samples to processing buffer
    _audioBuffer.addAll(samples);

    // Process audio windows when buffer has enough data
    while (_audioBuffer.length >= _bufferSize) {
      final windowStartTime = DateTime.now();
      
      // Extract window of samples for FFT processing
      final windowSamples = _audioBuffer.sublist(0, _bufferSize);
      _audioBuffer.removeRange(0, _hopSize);

      // Calculate RMS amplitude for this window
      final rms = math.sqrt(
        windowSamples.map((s) => s * s).reduce((a, b) => a + b) / windowSamples.length
      );
      _currentAmplitude = rms;

      // Process window with FFTService to get frequency data
      final spectrogramColumn = FFTService.processRealtimeAudio(windowSamples);
      
      // 🔥 INCREMENT THE COUNTER HERE
      _processedWindows++;
      
      // Record timing information for compensation
      final columnGeneratedTime = DateTime.now();
      _addSpectrogramColumnWithTiming(spectrogramColumn, columnGeneratedTime);
      
      // Update processing delay estimates
      final windowProcessingTime = columnGeneratedTime.difference(windowStartTime);
      _updateProcessingDelay(windowProcessingTime);
    }

  } catch (e) {
    developer.log('AudioService: Raw audio processing error: $e');
  }
}

  /// Adds a new spectrogram column with timing information
  /// Manages memory usage and updates recording duration
  void _addSpectrogramColumnWithTiming(List<double> frequencyData, DateTime generatedTime) {
    _spectrogramData.add(List<double>.from(frequencyData));
    _columnTimestamps.add(generatedTime);
    
    // Limit memory usage by removing old data
    if (_spectrogramData.length > 10320) {
      _spectrogramData.removeAt(0);
      _columnTimestamps.removeAt(0);
    }
    
    // Update recording duration
    if (_recordingStartTime != null) {
      _recordingDuration = DateTime.now().difference(_recordingStartTime!);
    }
    
    // Log spectrogram statistics periodically
    if (_spectrogramData.length % 100 == 0) {
      final maxValue = frequencyData.reduce(math.max);
      final avgValue = frequencyData.reduce((a, b) => a + b) / frequencyData.length;
      final activePixels = frequencyData.where((v) => v > 0.3).length;
      final qualitySettings = FFTService.getQualitySettings();
      final compensatedTime = getCompensatedColumnTime(_spectrogramData.length - 1);
      
      developer.log('AudioService: Spectrogram column ${_spectrogramData.length} - Max: ${maxValue.toStringAsFixed(3)}, Avg: ${avgValue.toStringAsFixed(3)}, Active: $activePixels/${qualitySettings['numBands']}, Time: ${compensatedTime.inMilliseconds}ms, Delay: ${_processingDelay.inMilliseconds}ms');
    }
    
    // Send audio data to stream listeners
    _safeAddAudioData(AudioData(
      amplitude: _currentAmplitude,
      duration: _recordingDuration,
      spectrogramColumn: frequencyData,
      rawDb: null,
      filePath: _currentFilePath,
    ));
  }

  /// Updates processing delay estimate based on recent processing times
  /// Uses moving average with safety limits
  void _updateProcessingDelay(Duration processingTime) {
    // Add to recent processing times history
    _recentProcessingTimes.add(processingTime);
    
    // Keep only recent measurements for accuracy
    if (_recentProcessingTimes.length > _timingHistorySize) {
      _recentProcessingTimes.removeAt(0);
    }
    
    // Calculate average processing time
    if (_recentProcessingTimes.isNotEmpty) {
      final totalMs = _recentProcessingTimes
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b);
      
      _averageProcessingTime = Duration(
        milliseconds: (totalMs / _recentProcessingTimes.length).round()
      );
      
      // Set processing delay with safety buffer (20% extra)
      _processingDelay = Duration(
        milliseconds: (_averageProcessingTime.inMilliseconds * 1.2).round()
            .clamp(0, _maxProcessingDelay.inMilliseconds)
      );
    }
    
    // Log timing updates periodically
    if (_recentProcessingTimes.length % 20 == 0) {
      developer.log('AudioService: Processing delay updated - Delay: ${_processingDelay.inMilliseconds}ms, Average: ${_averageProcessingTime.inMilliseconds}ms');
    }
  }

  /// Resets timing compensation tracking for new recording session
  void _resetTimingCompensation() {
    developer.log('AudioService: Resetting timing compensation');
    _processingDelay = Duration.zero;
    _averageProcessingTime = Duration.zero;
    _recentProcessingTimes.clear();
    _columnTimestamps.clear();
  }

/// Creates WAV file from recorded audio samples using WAV library
Future<void> _createWavFile() async {
  if (_currentFilePath == null || _recordedSamples.isEmpty) return;
  
  try {
    developer.log('AudioService: Creating WAV file: $_currentFilePath');
    
    // Convert normalized samples (-1.0 to 1.0) to the format expected by the wav package
    // The wav package expects List<Float64List> where outer list is channels, inner is samples
    final List<Float64List> audioChannels = [Float64List.fromList(_recordedSamples)]; // Single channel
    
    // Create WAV file using the library - much simpler!
    final wav = Wav(audioChannels, AudioConfig.sampleRate);
    
    // Write to file
    final file = File(_currentFilePath!);
    await file.writeAsBytes(wav.write());
    
    developer.log('AudioService: WAV file created successfully - ${_recordedSamples.length} samples, ${AudioConfig.sampleRate}Hz');
    
  } catch (e) {
    developer.log('AudioService: Error creating WAV file: $e');
    rethrow; // Let caller handle the error appropriately
  }
}

// Helper method to convert integer to bytes (little-endian)
List<int> _intToBytes(int value, int length) {
  final buffer = BytesBuilder();
  for (int i = 0; i < length; i++) {
    buffer.addByte((value >> (i * 8)) & 0xFF);
  }
  return buffer.toBytes();
}


 /// Sets up decibel level monitoring for recording
/// Provides real-time audio level feedback
Future<void> _setupDbMonitoring() async {
  developer.log('AudioService: Setting up dB monitoring');
  
  try {
    await _recorder!.setSubscriptionDuration(const Duration(milliseconds: 50));
    
    _recorderSubscription = _recorder!.onProgress?.listen(
      (data) {
        if (!_isRecording) return;
        
        final realDbLevel = data.decibels;
        if (realDbLevel != null && realDbLevel.isFinite && !realDbLevel.isNaN) {
          
          final dbAmplitude = _convertDbToAmplitude(realDbLevel);
          if (dbAmplitude > _currentAmplitude) {
            _currentAmplitude = dbAmplitude;
          }
          
          // 🔥 USE THE CORRECT COUNTER HERE
          // Log dB levels periodically
          if (_processedWindows % 100 == 0 && _processedWindows > 0) {
            developer.log('AudioService: dB Level: ${realDbLevel.toStringAsFixed(1)} dB, Amplitude: ${dbAmplitude.toStringAsFixed(3)}, Windows: $_processedWindows');
          }
        }
      },
      onError: (error) {
        developer.log('AudioService: dB monitoring error: $error');
      },
    );
    
  } catch (e) {
    developer.log('AudioService: Failed to setup dB monitoring: $e');
  }
}

  /// Stops recording and creates final WAV file
  /// Exports spectrogram data and cleans up resources
  Future<bool> stopRecording() async {
    if (!_isRecording || _recorder == null) return false;

    try {
      developer.log('AudioService: Stopping recording');
      
      // Cancel monitoring subscriptions
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;
      
      // Stop Flutter Sound recorder
      await _recorder!.stopRecorder();
      
      // Close audio stream
      await _audioStreamController?.close();
      _audioStreamController = null;
      _audioStreamSink = null;
      
      _isRecording = false;
      _safeAddRecordingState(false);
      
      // Create WAV file from recorded samples
      await _createWavFile();
      
      // Save path for potential playback
      _lastRecordingPath = _currentFilePath;
      
      // Export spectrogram data if recording exists
      if (_currentFilePath != null) {
        final exportPath = _currentFilePath!.replaceFirst('.wav', '_spectrogram.csv');
        await exportSpectrogramData(exportPath);
      }
      
      final qualitySettings = FFTService.getQualitySettings();
      developer.log('AudioService: Recording stopped successfully');
      developer.log('AudioService: Spectrogram: ${_spectrogramData.length} columns x ${qualitySettings['numBands']} bands');
      developer.log('AudioService: WAV file: $_currentFilePath');
      developer.log('AudioService: Timing delay: ${_processingDelay.inMilliseconds}ms');
      
      return true;
    } catch (e) {
      developer.log('AudioService: Stop recording error: $e');
      _safeAddError('Stop recording failed: $e');
      return false;
    }
  }

  /// Exports spectrogram data to CSV file with timing information
  /// Includes both raw and compensated timing columns
  Future<void> exportSpectrogramData(String filePath) async {
    developer.log('AudioService: Exporting spectrogram data to: $filePath');
    
    try {
      final StringBuffer buffer = StringBuffer();
      final qualitySettings = FFTService.getQualitySettings();
      final numBands = qualitySettings['numBands'] as int;
      final hopSize = qualitySettings['hopSize'] as int;
      
      // Create CSV header with timing information
      buffer.write('Time(s),CompensatedTime(s)');
      for (int i = 0; i < numBands; i++) {
        buffer.write(',FreqBand$i');
      }
      buffer.writeln();
      
      final double timeStep = hopSize / AudioConfig.sampleRate.toDouble();
      
      // Export each time column with frequency data
      for (int t = 0; t < _spectrogramData.length; t++) {
        final time = (t * timeStep).toStringAsFixed(4);
        final compensatedTime = (getCompensatedColumnTime(t).inMilliseconds / 1000.0).toStringAsFixed(4);
        buffer.write('$time,$compensatedTime');
        
        for (int f = 0; f < _spectrogramData[t].length; f++) {
          final grayscaleValue = _spectrogramData[t][f].toStringAsFixed(6);
          buffer.write(',$grayscaleValue');
        }
        buffer.writeln();
      }
      
      final file = File(filePath);
      await file.writeAsString(buffer.toString());
      developer.log('AudioService: Spectrogram data exported successfully');
      
    } catch (e) {
      developer.log('AudioService: Error exporting spectrogram data: $e');
    }
  }

  /// Converts decibel level to normalized amplitude (0.0 to 1.0)
  /// Maps typical speech range (-80dB to -10dB) to amplitude scale
  double _convertDbToAmplitude(double dbLevel) {
    if (dbLevel <= -80.0) return 0.0;
    if (dbLevel >= -10.0) return 1.0;
    
    final amplitude = (dbLevel + 80.0) / 70.0;
    return amplitude.clamp(0.0, 1.0);
  }

  /// Resets all adaptive tracking systems for new recording session
  void resetAdaptiveMapping() {
    developer.log('AudioService: Resetting adaptive mapping');
    _resetTimingCompensation();
    _audioBuffer.clear();
    _recordedSamples.clear();
    
    // Reset FFTService tracking
    FFTService.resetTracking();
  }

  /// Cleans up resources and closes all streams
  Future<void> dispose() async {
    developer.log('AudioService: Starting disposal');
    
    _isRecording = false;
    
    // Cancel all subscriptions
    await _recorderSubscription?.cancel();
    await _playerSubscription?.cancel();
    await _audioStreamController?.close();
    
    // Close Flutter Sound components
    await _recorder?.closeRecorder();
    await _player?.closePlayer();
    
    // Close stream controllers
    await _audioDataController.close();
    await _errorController.close();
    await _recordingStateController.close();
    
    // Clear references
    _recorder = null;
    _player = null;
    _isInitialized = false;
    
    // Clear timing compensation data
    _columnTimestamps.clear();
    _recentProcessingTimes.clear();
    
    developer.log('AudioService: Disposal complete');
  }
}
