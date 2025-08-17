/// Centralized audio processing configuration
/// Just change the _currentPreset to switch quality settings!
class AudioConfig {
  // === 🎛️ CHANGE THIS LINE TO SWITCH PRESETS ===
  static const String _currentPreset = 'balanced'; // 'performance', 'balanced', or 'high_quality'
  
  // === Quality Presets ===
  static const Map<String, Map<String, dynamic>> _presets = {
     'performance': {
      'fftSize': 1536,
      'hopSize': 256,      // Better overlap than 384
      'numBands': 96,
      'description': 'Fast processing with good detail'
    },
    'balanced': {
      'fftSize': 2048,
      'hopSize': 256,
      'numBands': 128,
      'description': 'Optimal quality/performance balance'
    },
    'high_quality': {
      'fftSize': 2048,
      'hopSize': 128,      // Much better time resolution
      'numBands': 160,     // More frequency detail
      'description': 'Superior quality for detailed analysis'
    },
  };
  
  // === Core Audio Settings (Fixed) ===
  static const int delayPlayback = 300; // Delay in milliseconds for audio playback sync
  static const int sampleRate = 44100;
  static const int channels = 1;
  static const double maxFreq = 8000.0;
  static const int historySize = 300;
  static const int timingHistorySize = 50;
  
  // === Dynamic Settings (Based on Preset) ===
  static int get fftSize => _presets[_currentPreset]!['fftSize'] as int;
  static int get hopSize => _presets[_currentPreset]!['hopSize'] as int;
  static int get numBands => _presets[_currentPreset]!['numBands'] as int;
  static int get bufferSize => fftSize; // Always match FFT size

  //   Audio Stream: [0][1][2][3][4][5][6][7][8][9][10]...

  // Window 1:     [████████████████████████████████]     ← 2048 samples
  // Window 2:           [████████████████████████████████] ← 2048 samples  
  // Window 3:                 [████████████████████████████████] ← 2048 samples
  //               ↑     ↑     ↑
  //               0    384   768  ← Starting positions (hop size apart)

  
  // === Calculated Properties ===
  static double get timePerColumn => hopSize / sampleRate;
  static double get overlapPercentage => ((fftSize - hopSize) / fftSize * 100);
  static double get updateRateMs => (hopSize / sampleRate * 1000);
  static double get frequencyResolution => sampleRate / fftSize;
  
  // === Info Methods ===
  static String get currentPreset => _currentPreset;
  static String get currentDescription => _presets[_currentPreset]!['description'] as String;
  
  /// Get current configuration summary
  static Map<String, dynamic> getCurrentConfig() {
    return {
      'preset': currentPreset,
      'description': currentDescription,
      'sampleRate': sampleRate,
      'fftSize': fftSize,
      'hopSize': hopSize,
      'numBands': numBands,
      'maxFreq': maxFreq,
      'bufferSize': bufferSize,
      'overlapPercentage': '${overlapPercentage.toStringAsFixed(1)}%',
      'updateRateMs': '${updateRateMs.toStringAsFixed(1)}ms',
      'frequencyResolution': '${frequencyResolution.toStringAsFixed(1)}Hz',
      'timePerColumn': '${(timePerColumn * 1000).toStringAsFixed(2)}ms',
    };
  }
}