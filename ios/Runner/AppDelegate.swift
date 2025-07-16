import UIKit
import Flutter
import FirebaseCore
import GoogleSignIn

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
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
