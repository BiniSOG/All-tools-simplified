import AVFoundation
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var meter: AVAudioRecorder?

  /// Starts the microphone for level metering only; the audio is discarded on stop.
  private func startMeter() -> String {
    stopMeter()
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
      try session.setActive(true)
      let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("meter.caf")
      let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatAppleLossless),
        AVSampleRateKey: 44100.0,
        AVNumberOfChannelsKey: 1,
      ]
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.isMeteringEnabled = true
      guard recorder.record() else { return "error" }
      meter = recorder
      return "ok"
    } catch {
      return "error"
    }
  }

  private func stopMeter() {
    if let recorder = meter {
      recorder.stop()
      recorder.deleteRecording()
      meter = nil
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      // Sound meter: "start" replies ok / denied / error, "level" replies loudness
      // relative to the microphone's maximum in decibels (0 = loudest, -160 = silence).
      let sound = FlutterMethodChannel(name: "toolbox/soundlevel", binaryMessenger: controller.binaryMessenger)
      sound.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(nil)
          return
        }
        switch call.method {
        case "start":
          AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
              result(granted ? self.startMeter() : "denied")
            }
          }
        case "level":
          if let recorder = self.meter {
            recorder.updateMeters()
            result(Double(recorder.averagePower(forChannel: 0)))
          } else {
            result(nil)
          }
        case "stop":
          self.stopMeter()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // Camera LED control. Replies false when the device has no torch.
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
