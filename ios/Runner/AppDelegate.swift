import UIKit
import Flutter
import FirebaseCore
import GoogleSignIn
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
      try session.setActive(true)
    } catch {
      print("⚠️ AVAudioSession setup failed: \(error)")
    }
    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(_ app: UIApplication, open url: URL,
                            options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    var handled: Bool = false

    if GIDSignIn.sharedInstance.hasPreviousSignIn() {
      handled = GIDSignIn.sharedInstance.handle(url)
    }

    if handled {
      return true
    }

    return super.application(app, open: url, options: options)
  }
}
