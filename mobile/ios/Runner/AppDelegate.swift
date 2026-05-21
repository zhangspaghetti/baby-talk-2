import Flutter
import UIKit

final class LocalSensitiveDataBackupExcluder {
  func excludeDirectory(atPath path: String) throws -> Bool {
    var directoryUrl = URL(fileURLWithPath: path, isDirectory: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try directoryUrl.setResourceValues(values)

    let confirmedValues = try directoryUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
    return confirmedValues.isExcludedFromBackup == true
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var localSensitiveDataBackupChannel: FlutterMethodChannel?
  private let localSensitiveDataBackupExcluder = LocalSensitiveDataBackupExcluder()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureLocalSensitiveDataBackupChannelIfPossible()
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configureLocalSensitiveDataBackupChannelIfPossible()
  }

  private func configureLocalSensitiveDataBackupChannelIfPossible() {
    guard localSensitiveDataBackupChannel == nil,
          let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "baby_talk/local_sensitive_data_backup",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String,
            !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        result(FlutterError(code: "invalid_path", message: "Missing directory path.", details: nil))
        return
      }

      do {
        result(try self.localSensitiveDataBackupExcluder.excludeDirectory(atPath: path))
      } catch {
        result(
          FlutterError(
            code: "backup_exclusion_failed",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
    localSensitiveDataBackupChannel = channel
  }
}
