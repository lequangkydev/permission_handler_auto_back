import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

const MethodChannel _channel = MethodChannel('permission_handler_auto_back');

bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

/// Adds [requestWithAutoBack] on top of `permission_handler`'s [Permission].
///
/// On Android the method:
///   1. Requests the permission via the normal runtime dialog when applicable.
///   2. If the permission is a "special" one that requires the system Settings
///      page (e.g. [Permission.manageExternalStorage],
///      [Permission.systemAlertWindow], [Permission.locationAlways]) or has
///      become permanently denied, opens the corresponding Settings page,
///      polls the system for the granted state, and brings the app back to
///      the foreground automatically when the user toggles the switch on.
///
/// On iOS it is a passthrough to [Permission.request] — Settings auto-back
/// is not possible on iOS, so the user must navigate back manually.
extension PermissionAutoBack on Permission {
  Future<PermissionStatus> requestWithAutoBack() async {
    if (!_isAndroid) {
      // iOS / Web / Windows: permission_handler has a real implementation.
      // Linux / macOS: permission_handler ships no platform impl and the
      // method-channel call throws MissingPluginException — desktop
      // platforms don't have a runtime-permission concept, so treat the
      // permission as granted instead of bubbling the exception up.
      try {
        return await request();
      } on MissingPluginException {
        return PermissionStatus.granted;
      }
    }

    // `locationAlways` needs a hybrid flow: `permission_handler.request()`
    // makes the OS redirect to the app's location-permission page (the page
    // the user actually wants — not the generic app details page), while
    // the native plugin polls in parallel and brings the app back to the
    // foreground the moment the user toggles "Allow all the time".
    if (this == Permission.locationAlways) {
      return _requestLocationAlwaysWithAutoBack();
    }

    if (_isAndroidSpecialPermission(this)) {
      if (await isGranted) return PermissionStatus.granted;
      final granted = await _openSettingsAndAutoReturn(this);
      return granted ? PermissionStatus.granted : PermissionStatus.denied;
    }

    final status = await request();
    if (status.isPermanentlyDenied) {
      final granted = await _openSettingsAndAutoReturn(this);
      return granted
          ? PermissionStatus.granted
          : PermissionStatus.permanentlyDenied;
    }
    return status;
  }
}

Future<PermissionStatus> _requestLocationAlwaysWithAutoBack() async {
  if (await Permission.locationAlways.isGranted) {
    return PermissionStatus.granted;
  }

  // Foreground location is a prerequisite for background. If the user
  // declines fine location there is no point asking for the always
  // variant — return the foreground status verbatim.
  if (!await Permission.locationWhenInUse.isGranted) {
    final fine = await Permission.locationWhenInUse.request();
    if (!fine.isGranted) return fine;
  }

  // Native polling fires `bringAppToFront` the instant
  // ACCESS_BACKGROUND_LOCATION becomes granted.
  final pollFuture = _channel
      .invokeMethod<bool>('pollPermissionAndAutoReturn', <String, Object?>{
        'permission': 'locationAlways',
      })
      .then(
        (granted) => (granted ?? false)
            ? PermissionStatus.granted
            : PermissionStatus.denied,
      )
      .catchError((_) => PermissionStatus.denied);

  // OS-driven flow: on Android 11+ this opens the app's location-permission
  // page directly; on Android 10 it shows a runtime dialog with the
  // "Allow all the time" option.
  final requestFuture = Permission.locationAlways.request();

  // Whichever resolves first wins; abort the other.
  final winner = await Future.any<PermissionStatus>([
    pollFuture,
    requestFuture,
  ]);
  await cancelPermissionAutoBack();
  return winner;
}

/// Cancels any in-flight auto-back polling started by [requestWithAutoBack].
///
/// Call this from `dispose()` of the screen that initiated the request if you
/// need to abort the wait early. The future returned by the original
/// `requestWithAutoBack` will resolve to [PermissionStatus.denied].
Future<void> cancelPermissionAutoBack() async {
  if (!_isAndroid) return;
  try {
    await _channel.invokeMethod<void>('cancel');
  } on PlatformException {
    // Nothing in flight or plugin not attached — safe to ignore.
  }
}

Future<bool> _openSettingsAndAutoReturn(Permission permission) async {
  final key = _permissionKey(permission);
  if (key == null) {
    final opened = await openAppSettings();
    if (!opened) return false;
    return permission.isGranted;
  }
  try {
    final ok = await _channel.invokeMethod<bool>(
      'openSettingsAndAutoReturn',
      <String, Object?>{'permission': key},
    );
    return ok ?? false;
  } on PlatformException {
    return false;
  }
}

bool _isAndroidSpecialPermission(Permission p) =>
    p == Permission.manageExternalStorage ||
    p == Permission.systemAlertWindow ||
    p == Permission.requestInstallPackages ||
    p == Permission.scheduleExactAlarm ||
    p == Permission.ignoreBatteryOptimizations ||
    p == Permission.accessNotificationPolicy;
// `locationAlways` is intentionally NOT in this list. On Android 11+ the
// OS itself redirects the user to the app's location-permission settings
// page when `ACCESS_BACKGROUND_LOCATION` is requested via the standard
// runtime API; on Android 10 a normal runtime dialog with the "Allow all
// the time" option is shown. Routing it through `permission_handler.request()`
// reproduces both flows correctly. If it ends up permanently denied the
// extension still falls back to the auto-back path below.

String? _permissionKey(Permission p) {
  if (p == Permission.manageExternalStorage) return 'manageExternalStorage';
  if (p == Permission.systemAlertWindow) return 'systemAlertWindow';
  if (p == Permission.requestInstallPackages) return 'requestInstallPackages';
  if (p == Permission.scheduleExactAlarm) return 'scheduleExactAlarm';
  if (p == Permission.ignoreBatteryOptimizations) {
    return 'ignoreBatteryOptimizations';
  }
  if (p == Permission.accessNotificationPolicy) {
    return 'accessNotificationPolicy';
  }
  if (p == Permission.locationAlways) return 'locationAlways';
  if (p == Permission.notification) return 'notification';
  if (p == Permission.camera) return 'camera';
  if (p == Permission.microphone) return 'microphone';
  if (p == Permission.location || p == Permission.locationWhenInUse) {
    return 'location';
  }
  if (p == Permission.contacts) return 'contacts';
  if (p == Permission.phone) return 'phone';
  if (p == Permission.sms) return 'sms';
  if (p == Permission.storage) return 'storage';
  if (p == Permission.photos) return 'photos';
  if (p == Permission.videos) return 'videos';
  if (p == Permission.audio) return 'audio';
  // ignore: deprecated_member_use
  if (p == Permission.calendar) return 'calendar';
  if (p == Permission.calendarFullAccess) return 'calendarFullAccess';
  if (p == Permission.calendarWriteOnly) return 'calendarWriteOnly';
  if (p == Permission.sensors) return 'sensors';
  if (p == Permission.sensorsAlways) return 'sensorsAlways';
  if (p == Permission.bluetooth) return 'bluetooth';
  if (p == Permission.bluetoothScan) return 'bluetoothScan';
  if (p == Permission.bluetoothConnect) return 'bluetoothConnect';
  if (p == Permission.bluetoothAdvertise) return 'bluetoothAdvertise';
  if (p == Permission.nearbyWifiDevices) return 'nearbyWifiDevices';
  if (p == Permission.activityRecognition) return 'activityRecognition';
  if (p == Permission.accessMediaLocation) return 'accessMediaLocation';
  return null;
}

/// Dart-only registrar used by Flutter's plugin tooling on Linux, macOS
/// and Windows. The auto-back behaviour is Android-only and the
/// non-Android flow lives entirely in [PermissionAutoBack.requestWithAutoBack],
/// so [registerWith] has nothing to do.
class PermissionHandlerAutoBackPlatform {
  static void registerWith() {}
}
