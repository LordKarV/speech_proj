import 'dart:io';
import 'dart:math' as math;
import 'dart:developer' as developer;
import 'package:flutter/services.dart';

/// Service for processing audio files and communicating with iOS audio analysis
/// 
/// Handles loading WAV files, splitting them into 5-second segments,
/// and sending them to iOS for analysis via MethodChannel
class AudioProcessingService {
  // Audio processing constants
  static const int _sampleRate = 44100;
  static const int _segmentDurationSeconds = 5;
  static const int _samplesPerSegment = _sampleRate * _segmentDurationSeconds;
  
  // Method channel for iOS communication
  static const MethodChannel _channel = MethodChannel('audio_processing_channel');

  // Local storage for analysis results
  static final Map<String, List<AudioAnalysisResult>> _analysisResults = {};
  static final List<AudioAnalysisResult> _latestResults = [];

  /// Get stored results for a specific file
  static List<AudioAnalysisResult>? getResultsForFile(String filePath) {
    developer.log('🔍 getResultsForFile called for: $filePath');
    developer.log('📋 Available files in storage: ${_analysisResults.keys.toList()}');
    
    final results = _analysisResults[filePath];
    developer.log('📊 Found ${results?.length ?? 0} results for this file');
    
    if (results != null) {
      for (int i = 0; i < results.length; i++) {
        developer.log('📋 Result $i: ${results[i]}');
      }
    } else {
      developer.log('❌ No results found for file: $filePath');
    }
    
    return results;
  }

  /// Get the latest analysis results (from local storage)
  static List<AudioAnalysisResult> getLatestResults() {
    developer.log('🔍 getLatestResults called - returning ${_latestResults.length} results');
    for (int i = 0; i < _latestResults.length; i++) {
      developer.log('📋 Latest result $i: ${_latestResults[i]}');
    }
    return List.from(_latestResults);
  }

  /// Clear results stored in iOS service
  static Future<bool> clearResultsInIOS() async {
    try {
      final result = await _channel.invokeMethod('clearResults');
      developer.log('🗑️ iOS clear results returned: $result');
      return result == true;
    } catch (e) {
      developer.log('❌ Error clearing results in iOS: $e');
      return false;
    }
  }

  /// Get all stored results
  static Map<String, List<AudioAnalysisResult>> getAllResults() {
    developer.log('📊 getAllResults called - ${_analysisResults.length} files with results');
    return Map.from(_analysisResults);
  }

  /// Clear results for a specific file
  static void clearResultsForFile(String filePath) {
    developer.log('🗑️ Clearing results for file: $filePath');
    _analysisResults.remove(filePath);
  }

  /// Clear all stored results (both local and iOS)
  static Future<void> clearAllResults() async {
    developer.log('🗑️ Clearing all results...');
    _analysisResults.clear();
    _latestResults.clear();
    
    // Also clear iOS results
    try {
      await clearResultsInIOS();
      developer.log('🗑️ Cleared all results (local and iOS)');
    } catch (e) {
      developer.log('⚠️ Failed to clear iOS results: $e');
    }
  }

  /// Process a WAV file by splitting it into 5-second segments and send to iOS
  static Future<List<AudioAnalysisResult>> processAudioFile({
    required String filePath,
  }) async {
    developer.log('🎯 AudioProcessingService: Starting processing for $filePath');
    
    try {
      // Load the WAV file
      final audioData = await _loadWavFile(filePath);
      if (audioData.isEmpty) {
        throw Exception('Failed to load audio data from file');
      }

      developer.log('📊 Loaded ${audioData.length} audio samples');

      // Split audio into 5-second segments
      final audioSegments = await _splitIntoSegments(audioData);
      developer.log('✂️ Split into ${audioSegments.length} segments');

      if (audioSegments.isEmpty) {
        throw Exception('No audio segments created');
      }
      
      // Send all segments as a list to iOS and get results back
      final results = await _sendSegmentListToIOS(audioSegments);

      // Store results locally
      _storeResults(filePath, results);

      developer.log('✅ Processed ${audioSegments.length} segments, got ${results.length} results');

      return results;

    } catch (e) {
      developer.log('❌ AudioProcessingService error: $e');
      rethrow;
    }
  }

  /// Send list of audio segments to iOS and receive analysis results
  static Future<List<AudioAnalysisResult>> _sendSegmentListToIOS(List<List<double>> audioSegments) async {
    try {
      // Convert all segments to Uint8List (as bytes)
      final List<Uint8List> segmentBuffers = audioSegments
          .map((segment) => _convertToBytes(segment))
          .toList();
      
      developer.log('📤 Sending ${segmentBuffers.length} audio segments to iOS');
      
      final result = await _channel.invokeMethod('processAudioStreams', {
        'audioStreams': segmentBuffers,
      });
      
      developer.log('✅ iOS processing result: $result');
      
      // Parse results from iOS
      if (result is List) {
        final analysisResults = result
            .map((item) => AudioAnalysisResult.fromMap(Map<String, dynamic>.from(item)))
            .toList();
        
        developer.log('📋 Parsed ${analysisResults.length} analysis results');
        
        // Log each parsed result
        for (int i = 0; i < analysisResults.length; i++) {
          developer.log('📋 Parsed result $i: ${analysisResults[i]}');
          developer.log('📋 Result $i matches: ${analysisResults[i].probableMatches}');
        }
        
        return analysisResults;
      } else {
        throw Exception('Unexpected result format from iOS');
      }
      
    } catch (e) {
      developer.log('❌ Error sending audio segments to iOS: $e');
      rethrow;
    }
  }

  /// Store analysis results locally
  static void _storeResults(String filePath, List<AudioAnalysisResult> results) {
    developer.log('💾 _storeResults called with ${results.length} results for: $filePath');
    
    _analysisResults[filePath] = results;
    _latestResults.clear();
    _latestResults.addAll(results);
    
    developer.log('💾 Stored ${results.length} results for file: $filePath');
    developer.log('📊 Total files with results: ${_analysisResults.length}');
    developer.log('📊 Latest results count: ${_latestResults.length}');
    
    // Log what we actually stored
    developer.log('🔍 Verification - stored results for $filePath:');
    final storedResults = _analysisResults[filePath];
    if (storedResults != null) {
      for (int i = 0; i < storedResults.length; i++) {
        developer.log('📋 Stored result $i: ${storedResults[i]}');
      }
    }
  }

  /// Convert audio samples to bytes for iOS
  static Uint8List _convertToBytes(List<double> samples) {
    final bytes = <int>[];
    for (final sample in samples) {
      // Convert double (-1.0 to 1.0) back to 16-bit PCM
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      bytes.add(intSample & 0xFF);        // Low byte
      bytes.add((intSample >> 8) & 0xFF); // High byte
    }
    return Uint8List.fromList(bytes);
  }

  /// Load WAV file and extract audio samples
  static Future<List<double>> _loadWavFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $filePath');
      }

      final bytes = await file.readAsBytes();
      developer.log('📁 File size: ${bytes.length} bytes');

      if (bytes.length < 44) {
        throw Exception('Invalid WAV file: too small');
      }

      // Skip WAV header (44 bytes) and read audio data
      final audioBytes = bytes.sublist(44);
      final samples = <double>[];

      // Convert 16-bit PCM to double values (-1.0 to 1.0)
      for (int i = 0; i < audioBytes.length - 1; i += 2) {
        final sample = (audioBytes[i] | (audioBytes[i + 1] << 8));
        final normalizedSample = sample > 32767 
            ? (sample - 65536) / 32768.0 
            : sample / 32767.0;
        samples.add(normalizedSample);
      }

      developer.log('🎵 Extracted ${samples.length} audio samples');
      return samples;

    } catch (e) {
      developer.log('❌ Error loading WAV file: $e');
      rethrow;
    }
  }

  /// Split audio data into 5-second segments
  static Future<List<List<double>>> _splitIntoSegments(List<double> audioData) async {
    final segments = <List<double>>[];
    final totalSamples = audioData.length;
    final segmentCount = (totalSamples / _samplesPerSegment).ceil();

    developer.log('📐 Total samples: $totalSamples, Segments needed: $segmentCount');

    for (int i = 0; i < segmentCount; i++) {
      final startIndex = i * _samplesPerSegment;
      final endIndex = math.min(startIndex + _samplesPerSegment, totalSamples);
      
      if (startIndex >= totalSamples) break;

      final segmentData = audioData.sublist(startIndex, endIndex);

      // Only include segments with meaningful data (at least 0.5 seconds worth)
      if (segmentData.length >= _sampleRate ~/ 2) {
        segments.add(segmentData);
        developer.log('📊 Segment $i: ${segmentData.length} samples');
      }
    }

    return segments;
  }
}

/// Data model for audio analysis results
class AudioAnalysisResult {
  final int fileIndex;
  final bool success;
  final List<String> probableMatches;

  AudioAnalysisResult({
    required this.fileIndex,
    required this.success,
    required this.probableMatches,
  });

  factory AudioAnalysisResult.fromMap(Map<String, dynamic> map) {
    developer.log('🔄 AudioAnalysisResult.fromMap called with: $map');
    
    final result = AudioAnalysisResult(
      fileIndex: map['fileIndex'] ?? 0,
      success: map['success'] ?? false,
      probableMatches: List<String>.from(map['probableMatches'] ?? []),
    );
    
    developer.log('✅ Created AudioAnalysisResult: $result');
    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'fileIndex': fileIndex,
      'success': success,
      'probableMatches': probableMatches,
    };
  }

  @override
  String toString() {
    return 'AudioAnalysisResult(fileIndex: $fileIndex, success: $success, matches: ${probableMatches.length}, probableMatches: $probableMatches)';
  }
}
