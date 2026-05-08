## 0.0.2

* Declare plugin support for Web, Windows, Linux and macOS so pub.dev no
  longer flags them as unsupported. The auto-back behaviour stays
  Android-only; on Web and Windows `requestWithAutoBack()` delegates to
  `permission_handler`'s native implementation, and on Linux/macOS — where
  `permission_handler` ships no platform code — it short-circuits to
  `PermissionStatus.granted` instead of throwing
  `MissingPluginException`.

## 0.0.1

Initial release. Re-exports `permission_handler` and adds the
`Permission.requestWithAutoBack()` extension that opens the right Android
Settings page when needed, polls the system for the granted state, and
brings the host app back to the foreground automatically when the user
toggles the permission on.

* Re-exports the full `permission_handler` API.
* Adds `Permission.requestWithAutoBack()`:
  - Opens the appropriate Android Settings page for special permissions
    (`manageExternalStorage`, `systemAlertWindow`,
    `requestInstallPackages`, `scheduleExactAlarm`,
    `ignoreBatteryOptimizations`, `accessNotificationPolicy`).
  - Falls back to the app details page for any runtime permission that
    has been permanently denied.
  - Polls the system every 500 ms and brings the host app back to the
    foreground automatically once the permission is granted.
  - For `Permission.locationAlways` it grants foreground location first,
    then delegates to `permission_handler.request()` so the OS itself
    redirects the user to the app's location-permission page (Android
    11+) or shows the *Allow all the time* dialog (Android 10), while
    the native side polls `ACCESS_BACKGROUND_LOCATION` in parallel and
    auto-backs as soon as the toggle flips on.
* Adds `cancelPermissionAutoBack()` to abort an in-flight polling loop.
* Runtime permission auto-back covers `camera`, `microphone`, `location`,
  `locationWhenInUse`, `locationAlways`, `contacts`, `phone`, `sms`,
  `storage`, `photos`, `videos`, `audio`, `notification`, `calendar`,
  `calendarFullAccess`, `calendarWriteOnly`, `sensors`, `sensorsAlways`,
  `bluetooth`, `bluetoothScan`, `bluetoothConnect`, `bluetoothAdvertise`,
  `nearbyWifiDevices`, `activityRecognition`, `accessMediaLocation`.
* iOS is a passthrough to `permission_handler`; auto-back is Android-only
  because iOS does not support programmatic foreground return from the
  Settings app.
* README documents the `permission_handler` iOS preprocessor macros
  (`PERMISSION_CAMERA=1`, `PERMISSION_LOCATION=1`, …) that must be
  declared in `ios/Podfile` for the system permission dialog to appear.
* Example app demonstrates a recovery dialog that opens app settings
  when `requestWithAutoBack()` resolves to `permanentlyDenied`.

This package supersedes
[`flutter_permission_auto_return`](https://pub.dev/packages/flutter_permission_auto_return),
which has been discontinued in favor of this one.
