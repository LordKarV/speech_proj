import AVFoundation
import Flutter
import Foundation
import UIKit

/// Service class for handling audio processing operations via Flutter method channel
class PythonAudioProcessingService {
    static let shared = PythonAudioProcessingService()

    private init() {
        print("🎵 PythonAudioProcessingService: Initializing singleton instance")
    }

    /// Setup the Flutter method channel for communication with Dart side
    /// - Parameter channel: FlutterMethodChannel instance for handling method calls
    func setupChannel(_ channel: FlutterMethodChannel) {
        print("📡 PythonAudioProcessingService: Setting up method channel handler")
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            print("📞 PythonAudioProcessingService: Received method call: \(call.method)")
            self?.handleMethodCall(call: call, result: result)
        }

        print("✅ PythonAudioProcessingService: Audio processing channel setup complete")
    }

    /// Handle incoming method calls from Flutter
    /// - Parameters:
    ///   - call: FlutterMethodCall containing method name and arguments
    ///   - result: FlutterResult callback to return response to Flutter
    func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🎯 PythonAudioProcessingService: Processing method: \(call.method)")

        switch call.method {
        case "processAudioStreams":
            print("🔊 PythonAudioProcessingService: Handling processAudioStreams request")
            processAudioStreams(arguments: call.arguments, result: result)
        default:
            print("❌ PythonAudioProcessingService: Unknown method: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }

    /// Process multiple audio streams for speech analysis
    /// - Parameters:
    ///   - arguments: Arguments containing audio stream data
    ///   - result: FlutterResult callback for returning analysis results
    private func processAudioStreams(arguments: Any?, result: @escaping FlutterResult) {
        print("🔍 PythonAudioProcessingService: Processing audio streams request")
        print("📝 PythonAudioProcessingService: Raw arguments received: \(String(describing: arguments))")

        // Validate arguments structure
        guard let args = arguments as? [String: Any] else {
            print("❌ PythonAudioProcessingService: Failed to cast arguments to dictionary")
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS", 
                    message: "Arguments not a dictionary", 
                    details: nil
                )
            )
            return
        }

        print("📋 PythonAudioProcessingService: Arguments keys: \(args.keys)")

        // Extract audio streams from arguments
        guard let audioStreams = args["audioStreams"] as? [FlutterStandardTypedData] else {
            print("❌ PythonAudioProcessingService: Failed to extract audioStreams from arguments")
            print("📋 PythonAudioProcessingService: audioStreams type: \(type(of: args["audioStreams"]))")
            result(
                FlutterError(
                    code: "INVALID_ARGUMENTS", 
                    message: "Invalid audio streams", 
                    details: nil
                )
            )
            return
        }

        print("🔊 PythonAudioProcessingService: Successfully extracted \(audioStreams.count) audio streams")

        // Process audio streams on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            print("🔄 PythonAudioProcessingService: Starting background audio processing")
            var analysisResults: [SoundAnalysisResult] = []

            // Analyze each audio stream individually
            for (index, audioData) in audioStreams.enumerated() {
                print("🎵 PythonAudioProcessingService: Processing stream \(index) with \(audioData.data.count) bytes")
                let analysisResult = self.analyzeAudio(data: audioData.data, fileIndex: index)
                analysisResults.append(analysisResult)
                print("✅ PythonAudioProcessingService: Completed analysis for stream \(index)")
            }

            print("📊 PythonAudioProcessingService: Total analysis results: \(analysisResults.count)")

            // Return results to Flutter on main queue
            DispatchQueue.main.async {
                let resultArray = analysisResults.map { $0.toDictionary() }
                print("📤 PythonAudioProcessingService: Sending back \(resultArray.count) results to Flutter")
                print("📤 PythonAudioProcessingService: Results preview: \(resultArray)")
                result(resultArray)
            }
        }
    }

    /// Analyze individual audio data for speech patterns and stutter detection
    /// - Parameters:
    ///   - data: Raw audio data bytes
    ///   - fileIndex: Index of the audio file being processed
    /// - Returns: SoundAnalysisResult containing analysis results
    private func analyzeAudio(data: Data, fileIndex: Int) -> SoundAnalysisResult {
        print("🔍 PythonAudioProcessingService: Analyzing audio segment \(fileIndex): \(data.count) bytes")

        // Simulate processing time for realistic behavior
        print("⏳ PythonAudioProcessingService: Simulating audio analysis processing time")
        Thread.sleep(forTimeInterval: 0.1)

        // Simulate analysis success/failure (90% success rate for testing)
        let success = Double.random(in: 0...1) > 0.1
        print("🎲 PythonAudioProcessingService: Analysis success simulation: \(success)")

        let probableMatches: [String]
        if success {
            print("✅ PythonAudioProcessingService: Generating probable matches for successful analysis")
            probableMatches = generateProbableMatches()
        } else {
            print("❌ PythonAudioProcessingService: No matches for failed analysis")
            probableMatches = []
        }

        print("✅ PythonAudioProcessingService: Analysis complete for segment \(fileIndex): success=\(success), matches=\(probableMatches.count)")

        return SoundAnalysisResult(
            fileIndex: fileIndex,
            success: success,
            probableMatches: probableMatches
        )
    }

    /// Generate simulated probable matches 
    /// - Returns: Array of strings representing detected speech patterns
    private func generateProbableMatches() -> [String] {
        print("🎯 PythonAudioProcessingService: Generating probable speech pattern matches")
        
        let allMatches = [
          "sound repetition detected, probability 80",
            "syllable repetition found, probability 50",
            "word repetition identified, probability 75",
            "sound prolongation detected, probability 30",
            "silent block observed, probability 90",
            "prolongation detected, probability 85",
            "repetition pattern found, probability 70",
            "block behavior identified, probability 60",
        ]

        // Randomly select 2-5 matches for realistic variation
        let matchCount = Int.random(in: 2...5)
        let selectedMatches = allMatches.shuffled().prefix(matchCount)
        
        print("🔢 PythonAudioProcessingService: Generated \(matchCount) probable matches")
        
        return Array(selectedMatches)
    }
}

/// Result structure for sound analysis operations
/// Contains analysis results for individual audio segments
struct SoundAnalysisResult {
    let fileIndex: Int              // Index of the processed audio file
    let success: Bool              // Whether analysis completed successfully
    let probableMatches: [String]  // Array of detected speech patterns

    /// Convert result to dictionary format for Flutter communication
    /// - Returns: Dictionary representation of analysis results
    func toDictionary() -> [String: Any] {
        return [
            "fileIndex": fileIndex,
            "success": success,
            "probableMatches": probableMatches,
        ]
    }
}
