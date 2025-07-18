import 'dart:math' as math;
import 'dart:developer' as developer;
import 'dart:io';
import 'package:fftea/fftea.dart';

import '../config/audio_config.dart';

/// Result container for spectrogram data
class SpectrogramResult {
  final List<List<double>> data;
  final Duration duration;
  final int sampleCount;
  
  SpectrogramResult({
    required this.data,
    required this.duration,
    required this.sampleCount,
  });
}

/// Result container for WAV file data
class WavFileResult {
  final List<double> samples;
  final Duration duration;
  
  WavFileResult({
    required this.samples,
    required this.duration,
  });
}

/// Service class for FFT operations and spectrogram generation
class FFTService {
  // FFT configuration constants
  static int get _fftSize => AudioConfig.fftSize;
  static int get _hopSize => AudioConfig.hopSize;
  static int get _sampleRate => AudioConfig.sampleRate;
  static int get _numBands => AudioConfig.numBands;
  static double get _maxFreq => AudioConfig.maxFreq;
  static int get _historySize => AudioConfig.historySize;
  
   /// Returns current FFT processing configuration
  static Map<String, dynamic> getQualitySettings() {
    return AudioConfig.getCurrentConfig();
  }
  // Dynamic range tracking variables
  static double _globalMaxMagnitude = 0.0;
  static final List<double> _magnitudeHistory = [];
  static final List<double> _formantHistory = [];
  
  /// Generates spectrogram from file or audio samples
  /// Either [filePath] or [audioSamples] must be provided
  /// [onProgress] callback receives progress updates as strings
  static Future<SpectrogramResult> generateSpectrogram({
    String? filePath,              
    List<double>? audioSamples,    
    Function(String)? onProgress,  
  }) async {
    developer.log('FFTService: Starting spectrogram generation');
    
    try {
      List<double> samples;
      Duration duration;
      
      // Load audio data from file or use provided samples
      if (filePath != null) {
        developer.log('FFTService: Reading audio from file: $filePath');
        onProgress?.call('Reading WAV file...');
        final result = await _readWavFile(filePath);
        samples = result.samples;
        duration = result.duration;
        developer.log('FFTService: Loaded ${samples.length} samples from file');
      } else if (audioSamples != null) {
        developer.log('FFTService: Using provided audio samples: ${audioSamples.length}');
        samples = audioSamples;
        duration = Duration(milliseconds: (samples.length / _sampleRate * 1000).round());
      } else {
        throw ArgumentError('Either filePath or audioSamples must be provided');
      }
      
      // Process audio samples to generate spectrogram
      onProgress?.call('Analyzing frequency content...');
      final spectrogramData = await _processAudioSamples(samples, onProgress);
      
      developer.log('FFTService: Generated spectrogram with ${spectrogramData.length} time columns and $_numBands frequency bands');
      
      return SpectrogramResult(
        data: spectrogramData,
        duration: duration,
        sampleCount: samples.length,
      );
      
    } catch (e) {
      developer.log('FFTService: Error generating spectrogram: $e');
      rethrow;
    }
  }

  /// Processes audio samples using sliding window FFT to generate spectrogram data
  static Future<List<List<double>>> _processAudioSamples(
    List<double> samples, 
    Function(String)? onProgress,
  ) async {
    developer.log('FFTService: Starting audio processing with FFT size $_fftSize, hop size $_hopSize');
    
    final spectrogramColumns = <List<double>>[];
    final totalWindows = (samples.length - _fftSize) ~/ _hopSize;
    
    // Reset tracking variables for new processing session
    _magnitudeHistory.clear();
    _formantHistory.clear();
    _globalMaxMagnitude = 0.0;
    
    int processedWindows = 0;
    
    // Process audio using sliding window approach
    for (int start = 0; start < samples.length - _fftSize; start += _hopSize) {
      final windowSamples = samples.sublist(start, start + _fftSize);
      
      // Process this window with FFT
      final frequencyColumn = _processAudioWindow(windowSamples);
      spectrogramColumns.add(frequencyColumn);
      
      processedWindows++;
      
      // Report progress every 100 windows
      if (processedWindows % 100 == 0) {
        final progress = (processedWindows / totalWindows * 100).toStringAsFixed(1);
        onProgress?.call('Processing: $progress% (${spectrogramColumns.length} columns)');
        
        // Log dynamic range information
        if (_magnitudeHistory.isNotEmpty) {
          final dynamicMin = _magnitudeHistory.reduce(math.min) * 0.1;
          final dynamicMax = _magnitudeHistory.reduce(math.max) * 0.8;
          developer.log('FFTService: Current dynamic range - Min: ${dynamicMin.toStringAsFixed(4)}, Max: ${dynamicMax.toStringAsFixed(4)}');
        }
      }
    }
    
    developer.log('FFTService: Audio processing complete - generated ${spectrogramColumns.length} frequency columns');
    return spectrogramColumns;
  }

  /// Processes a single audio window using FFT and returns frequency band magnitudes
  static List<double> _processAudioWindow(List<double> samples) {
    developer.log('FFTService: Processing audio window of ${samples.length} samples');
    
    try {
      // Apply Hamming window to reduce spectral leakage
      final windowedSamples = <double>[];
      for (int i = 0; i < samples.length; i++) {
        final window = 0.54 - 0.46 * math.cos(2 * math.pi * i / (samples.length - 1));
        windowedSamples.add(samples[i] * window);
      }

      // Compute FFT of windowed samples
      final fft = FFT(windowedSamples.length);
      final spectrum = fft.realFft(windowedSamples);

      // Calculate frequency bin parameters
      final binSize = _sampleRate / windowedSamples.length;
      final maxBinIndex = (_maxFreq / binSize).ceil().clamp(0, spectrum.length);
      
      developer.log('FFTService: FFT computed - bin size: ${binSize.toStringAsFixed(2)} Hz, max bin: $maxBinIndex');
      
      // Calculate magnitude for each frequency band
      final frequencyMagnitudes = <double>[];
      final binsPerBand = maxBinIndex.toDouble() / _numBands;
      
      for (int band = 0; band < _numBands; band++) {
        final startBin = (band * binsPerBand).floor();
        final endBin = ((band + 1) * binsPerBand).ceil().clamp(0, spectrum.length);
        
        double bandMagnitude = 0.0;
        int count = 0;
        
        // Average magnitude across bins in this frequency band
        for (int bin = startBin; bin < endBin; bin++) {
          if (bin < spectrum.length) {
            final real = spectrum[bin].x;
            final imag = spectrum[bin].y;
            final magnitude = math.sqrt(real * real + imag * imag);
            bandMagnitude += magnitude;
            count++;
          }
        }
        
        final avgMagnitude = count > 0 ? bandMagnitude / count : 0.0;
        frequencyMagnitudes.add(avgMagnitude);
      }

      // Update magnitude tracking for dynamic range calculation
      final maxMagnitude = frequencyMagnitudes.isEmpty ? 1.0 : frequencyMagnitudes.reduce(math.max);
      
      _magnitudeHistory.add(maxMagnitude);
      if (_magnitudeHistory.length > _historySize) {
        _magnitudeHistory.removeAt(0);
      }
      
      _globalMaxMagnitude = math.max(_globalMaxMagnitude, maxMagnitude);
      
      // Convert magnitudes to normalized grayscale values
      final grayscaleData = <double>[];
      
      // Calculate adaptive dynamic range based on magnitude history
      double dynamicMin = _magnitudeHistory.isNotEmpty 
          ? _magnitudeHistory.reduce(math.min) * 0.05
          : 0.0;
      double dynamicMax = _magnitudeHistory.isNotEmpty 
          ? _magnitudeHistory.reduce(math.max) * 0.85
          : 1.0;
      
      // Ensure valid range
      if (dynamicMax <= dynamicMin) {
        dynamicMax = dynamicMin + 0.1;
      }
      
      // Normalize each frequency band magnitude to 0-1 range
      for (int i = 0; i < frequencyMagnitudes.length; i++) {
        final magnitude = frequencyMagnitudes[i];
        
        if (magnitude <= dynamicMin) {
          grayscaleData.add(0.0);
        } else {
          final normalizedMagnitude = (magnitude - dynamicMin) / (dynamicMax - dynamicMin);
          final clampedValue = normalizedMagnitude.clamp(0.0, 1.0);
          
          // Apply gamma correction for better visual perception
          final gammaValue = math.pow(clampedValue, 0.6).toDouble();
          grayscaleData.add(gammaValue);
        }
      }

      developer.log('FFTService: Window processed - generated ${grayscaleData.length} frequency band values');
      return grayscaleData;

    } catch (e) {
      developer.log('FFTService: Error processing audio window: $e');
      return List<double>.filled(_numBands, 0.0);
    }
  }

  /// Reads WAV file and extracts audio samples
  static Future<WavFileResult> _readWavFile(String filePath) async {
    developer.log('FFTService: Reading WAV file: $filePath');
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('WAV file not found: $filePath');
      }
      
      final bytes = await file.readAsBytes();
      developer.log('FFTService: Read ${bytes.length} bytes from WAV file');
      
      // Validate minimum WAV file size
      if (bytes.length < 44) {
        throw Exception('Invalid WAV file - too small');
      }
      
      // Verify WAV file format headers
      final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      final waveHeader = String.fromCharCodes(bytes.sublist(8, 12));
      
      if (riffHeader != 'RIFF' || waveHeader != 'WAVE') {
        throw Exception('Invalid WAV file format');
      }
      
      developer.log('FFTService: WAV file format validated');
      
      // Find data chunk in WAV file
      int dataStart = 44;
      int dataSize = 0;
      
      for (int i = 12; i < bytes.length - 8; i++) {
        if (String.fromCharCodes(bytes.sublist(i, i + 4)) == 'data') {
          dataSize = bytes[i + 4] | (bytes[i + 5] << 8) | (bytes[i + 6] << 16) | (bytes[i + 7] << 24);
          dataStart = i + 8;
          developer.log('FFTService: Found data chunk at offset $dataStart with size $dataSize');
          break;
        }
      }
      
      // Extract 16-bit PCM audio samples
      final audioSamples = <double>[];
      final endIndex = math.min(bytes.length, dataStart + dataSize);
      
      for (int i = dataStart; i < endIndex - 1; i += 2) {
        final sample = (bytes[i] | (bytes[i + 1] << 8)).toSigned(16);
        // Normalize 16-bit sample to -1.0 to 1.0 range
        audioSamples.add(sample / 32768.0);
      }
      
      final duration = Duration(
        milliseconds: (audioSamples.length / _sampleRate * 1000).round()
      );
      
      developer.log('FFTService: Extracted ${audioSamples.length} audio samples, duration: ${duration.inSeconds}s');
      
      return WavFileResult(
        samples: audioSamples,
        duration: duration,
      );
      
    } catch (e) {
      developer.log('FFTService: Error reading WAV file: $e');
      rethrow;
    }
  }

  /// Processes real-time audio samples for live spectrogram display
  /// Ensures input samples are correct size for FFT processing
  static List<double> processRealtimeAudio(List<double> samples) {
    developer.log('FFTService: Processing real-time audio - ${samples.length} samples');
    
    // Ensure samples are correct size for FFT
    if (samples.length != _fftSize) {
      if (samples.length < _fftSize) {
        // Pad with zeros if too short
        samples = [...samples, ...List<double>.filled(_fftSize - samples.length, 0.0)];
        developer.log('FFTService: Padded samples to $_fftSize length');
      } else {
        // Truncate if too long
        samples = samples.sublist(0, _fftSize);
        developer.log('FFTService: Truncated samples to $_fftSize length');
      }
    }
    
    return _processAudioWindow(samples);
  }

  /// Resets magnitude tracking for new processing session
  static void resetTracking() {
    developer.log('FFTService: Resetting magnitude tracking');
    _magnitudeHistory.clear();
    _formantHistory.clear();
    _globalMaxMagnitude = 0.0;
  }
}
