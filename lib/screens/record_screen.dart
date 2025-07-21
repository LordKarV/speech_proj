import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:fftea/fftea.dart';

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  late final FFT _fft;
  List<List<double>> _spectrogram = [];

  // Display configuration
  final int _nMels = 80;
  final int _fftSize = 4096;
  final int _maxSpectrogramLength = 100; // fewer columns → faster scroll
  final double _barBandHeight = 3.0;     // pixel height per mel band
  double get _barHeight => _nMels * _barBandHeight;
  final double _barTopOffset = 100.0;    // vertical position in px from top
  final double _scrollSpeed = 1.0;       // speed multiplier (>1 faster)

  late final List<List<double>> _melFilterBank;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _audioCapture.init();
    _fft = FFT(_fftSize);
    _melFilterBank = _createMelFilterBank(
      sampleRate: 44100,
      fftSize: _fftSize,
      nMel: _nMels,
      fMin: 0,
      fMax: 44100 / 2,
    );
  }

  List<List<double>> _createMelFilterBank({
    required int sampleRate,
    required int fftSize,
    required int nMel,
    required double fMin,
    required double fMax,
  }) {
    double hzToMel(double hz) => 2595 * math.log(1 + hz / 700) / math.ln10;
    double melToHz(double mel) => 700 * (math.pow(10, mel / 2595) - 1);

    final melMin = hzToMel(fMin);
    final melMax = hzToMel(fMax);
    final melPoints = List<double>.generate(
      nMel + 2,
      (i) => melMin + (melMax - melMin) * i / (nMel + 1),
    );
    final hzPoints = melPoints.map(melToHz).toList();
    final binFreqs = List<double>.generate(
      fftSize ~/ 2 + 1,
      (i) => i * sampleRate / fftSize,
    );

    final filterBank = List.generate(
      nMel,
      (_) => List<double>.filled(fftSize ~/ 2 + 1, 0.0),
    );

    for (int m = 0; m < nMel; m++) {
      final fLeft = hzPoints[m];
      final fCenter = hzPoints[m + 1];
      final fRight = hzPoints[m + 2];
      for (int k = 0; k < binFreqs.length; k++) {
        final freq = binFreqs[k];
        double weight = 0.0;
        if (freq >= fLeft && freq < fCenter) {
          weight = (freq - fLeft) / (fCenter - fLeft);
        } else if (freq >= fCenter && freq < fRight) {
          weight = (fRight - freq) / (fRight - fCenter);
        }
        filterBank[m][k] = weight;
      }
    }
    return filterBank;
  }

  Future<void> _startAudioStream() async {
    await _audioCapture.start(
      (data) => _processAudioData(data),
      (err) => print('Audio capture error: \$err'),
      sampleRate: 44100,
      bufferSize: _fftSize,
    );
  }

  Future<void> _stopAudioStream() async => _audioCapture.stop();

  void _processAudioData(dynamic data) {
    Float64List floatData;
    if (data is Float64List) {
      floatData = data;
    } else if (data is Float32List) {
      floatData = Float64List.fromList(data.toList());
    } else if (data is Int16List) {
      floatData = Float64List.fromList(data.map((e) => e.toDouble()).toList());
    } else {
      return;
    }

    final windowed = List<double>.generate(
      _fftSize,
      (i) => floatData[i] * (0.5 * (1 - math.cos(2 * math.pi * i / (_fftSize - 1))))
    );

    final freqComplex = _fft.realFft(windowed);
    final magnitudes = freqComplex.discardConjugates().magnitudes();

    final melEnergies = List<double>.generate(_nMels, (m) {
      double sum = 0.0;
      for (int k = 0; k < magnitudes.length; k++) {
        sum += magnitudes[k] * _melFilterBank[m][k];
      }
      return math.log(1 + sum);
    });

    setState(() {
      _spectrogram.add(melEnergies);
      if (_spectrogram.length > _maxSpectrogramLength) {
        _spectrogram.removeAt(0);
      }
    });
  }

  void _onRecordButtonPressed() {
    if (_isRecording) {
      _stopAudioStream();
    } else {
      setState(() => _spectrogram.clear());
      _startAudioStream();
    }
    setState(() => _isRecording = !_isRecording);
  }

  @override
  void dispose() {
    if (_isRecording) _audioCapture.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Live Mel‑Spectrogram'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Positioned(
            top: _barTopOffset,
            left: 0,
            right: 0,
            height: _barHeight,
            child: CustomPaint(
              painter: SpectrogramPainter(
                spectrogram: _spectrogram,
                maxLength: _maxSpectrogramLength,
                scrollSpeed: _scrollSpeed,
              ),
              size: Size(double.infinity, _barHeight),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 55.0),
              child: GestureDetector(
                onTap: _onRecordButtonPressed,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    )],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.fiber_manual_record,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpectrogramPainter extends CustomPainter {
  final List<List<double>> spectrogram;
  final int maxLength;
  final double scrollSpeed;

  SpectrogramPainter({required this.spectrogram, required this.maxLength, required this.scrollSpeed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final cols = spectrogram.length;
    if (cols == 0) return;
    final rows = spectrogram[0].length;
    final baseCellWidth = size.width / maxLength;
    final cellHeight = size.height / rows;

    for (int i = 0; i < cols; i++) {
      final x = size.width - (cols - i) * baseCellWidth * scrollSpeed;
      for (int y = 0; y < rows; y++) {
        final value = spectrogram[i][y];
        final normalized = (value / 5).clamp(0.0, 1.0);
        paint.color = Color.lerp(Colors.white, const Color.fromARGB(255, 93, 0, 109), normalized)!;
        canvas.drawRect(
          Rect.fromLTWH(
            x,
            size.height - (y + 1) * cellHeight,
            baseCellWidth * scrollSpeed,
            cellHeight,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpectrogramPainter old) => true;
}
