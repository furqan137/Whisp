import Flutter
import UIKit
import AppTrackingTransparency
import AdSupport

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    GeneratedPluginRegistrant.register(with: self)

    // Request App Tracking Transparency Permission
    if #available(iOS 14, *) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("Tracking Authorized")
                case .denied:
                    print("Tracking Denied")
                case .notDetermined:
                    print("Tracking Not Determined")
                case .restricted:
                    print("Tracking Restricted")
                @unknown default:
                    print("Unknown Tracking Status")
                }
            }
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}