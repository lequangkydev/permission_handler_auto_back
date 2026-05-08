import Flutter
import UIKit

/// On iOS the plugin is intentionally a no-op: `permission_handler` already
/// covers the full permission lifecycle, and iOS does not allow apps to
/// programmatically come back to the foreground from the Settings app.
///
/// The Dart side checks `Platform.isAndroid` before invoking any method on
/// this channel, so calls should never actually arrive here. The handler
/// returns sensible defaults in case an integrator wires something up
/// directly.
public class PermissionHandlerAutoBackPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "permission_handler_auto_back",
      binaryMessenger: registrar.messenger()
    )
    let instance = PermissionHandlerAutoBackPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openSettingsAndAutoReturn":
      if let url = URL(string: UIApplication.openSettingsURLString),
         UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url, options: [:]) { _ in
          result(false)
        }
      } else {
        result(false)
      }
    case "cancel":
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
