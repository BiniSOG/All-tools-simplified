import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Camera LED control. Replies false when the device has no torch.
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "toolbox/torch", binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { call, result in
        guard call.method == "set" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let on = call.arguments as? Bool,
          let device = AVCaptureDevice.default(for: .video),
          device.hasTorch
        else {
          result(false)
          return
        }
        do {
          try device.lockForConfiguration()
          device.torchMode = on ? .on : .off
          device.unlockForConfiguration()
          result(true)
        } catch {
          result(false)
        }
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
