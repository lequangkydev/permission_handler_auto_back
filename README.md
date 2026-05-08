# permission_handler_auto_back

[![pub package](https://img.shields.io/pub/v/permission_handler_auto_back.svg)](https://pub.dev/packages/permission_handler_auto_back)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A drop-in wrapper around [`permission_handler`](https://pub.dev/packages/permission_handler) that
**automatically returns the user back to your app on Android** after they grant a permission from
the system Settings page.

On Android certain permissions cannot be granted via a runtime dialog and instead require the user
to flip a switch in Settings — for example *All files access*, *Display over other apps*,
*Schedule exact alarms*, *Background location*, or any runtime permission that has been
permanently denied. Sending users into Settings is awkward because they then have to manually
navigate back. This plugin polls the system for the granted state, and as soon as the toggle flips
on, it brings your app back to the foreground.

On iOS the package is a thin re-export of `permission_handler` — iOS does not allow apps to come
back to the foreground from Settings programmatically, so the auto-back behavior is Android-only.

## Demo

![Permission auto-back demo](https://raw.githubusercontent.com/lequangkydev/permission_handler_auto_back/main/screenshots/demo_auto.gif)

## Features

- Re-exports the entire `permission_handler` API — keep using `Permission.camera.request()`,
  `PermissionStatus`, `openAppSettings()`, etc. Nothing breaks.
- Adds `Permission.requestWithAutoBack()` — a single call that:
  - shows the runtime dialog for normal permissions,
  - opens the right Settings page for "special" Android permissions,
  - opens the app details page when a permission is permanently denied,
  - polls the system every 500 ms until the permission is granted,
  - automatically pulls your app back to the foreground.
- Works with any launcher Activity — no need to know your `MainActivity` class name.
- Polling stops automatically after 5 minutes, when the engine detaches, or when you call
  `cancelPermissionAutoBack()`.

## Installation

```yaml
dependencies:
  permission_handler_auto_back: ^0.0.1
```

```bash
flutter pub get
```

You do **not** need to add `permission_handler` separately — it is re-exported by this package.

## Setup

Declare the permissions you actually use in your app's `AndroidManifest.xml` and iOS `Info.plist`,
exactly as you would for `permission_handler`. See the
[`permission_handler` setup guide](https://pub.dev/packages/permission_handler#setup) for the full
list. A starter set covering the cases this plugin specifically handles:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
    tools:ignore="ScopedStorage" />
```

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>Why you need the camera.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Why you need always-on location.</string>
```

### iOS — `permission_handler` preprocessor macros

`permission_handler`'s iOS code is gated by `#if PERMISSION_*` compile-time
macros. Without those macros defined, the underlying request silently
returns `denied` and no system dialog ever appears. Add them in
`ios/Podfile` inside the `post_install` block, listing only the
permissions your app actually uses (App Store reviewers flag unused
permission frameworks):

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_MICROPHONE=1',
        'PERMISSION_LOCATION=1',          # location, locationWhenInUse, locationAlways
        'PERMISSION_CONTACTS=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_NOTIFICATIONS=1',
        'PERMISSION_EVENTS=1',            # calendar
        # 'PERMISSION_REMINDERS=1',
        # 'PERMISSION_SPEECH_RECOGNIZER=1',
        # 'PERMISSION_MEDIA_LIBRARY=1',
        # 'PERMISSION_SENSORS=1',
        # 'PERMISSION_BLUETOOTH=1',
        # 'PERMISSION_APP_TRACKING_TRANSPARENCY=1',
        # 'PERMISSION_CRITICAL_ALERTS=1',
        # 'PERMISSION_ASSISTANT=1',
      ]
    end
  end
end
```

After editing the Podfile, run `cd ios && pod install --repo-update`
once so the new defines are baked into the Xcode project.

## Usage

```dart
import 'package:permission_handler_auto_back/permission_handler_auto_back.dart';

Future<void> requestAllFilesAccess() async {
  final status = await Permission.manageExternalStorage.requestWithAutoBack();
  if (status.isGranted) {
    // user toggled "All files access" ON in Settings, app is back in foreground
  }
}

Future<void> requestCamera() async {
  // Normal runtime permission. If the user has previously denied it twice, the
  // plugin will open the app details page and auto-back when granted.
  final status = await Permission.camera.requestWithAutoBack();
}
```

The full `permission_handler` API is still available on the imported `Permission`, so you can mix
and match:

```dart
final status = await Permission.notification.status;
if (status.isDenied) await openAppSettings();
```

### Cancelling an in-flight request

If your screen is disposed while the user is still in Settings, cancel the polling so the future
completes and resources are released:

```dart
@override
void dispose() {
  cancelPermissionAutoBack();
  super.dispose();
}
```

## Supported permissions

`requestWithAutoBack()` is an extension on `Permission`, so you can call it on **every
permission** that `permission_handler` exposes — `Permission.camera`, `Permission.contacts`,
`Permission.photos`, anything. The runtime dialog and status checks always work, identical to
calling `request()` directly.

What this plugin adds on top is the **auto-back-from-Settings** behavior, which has two
flavors on Android:

### Special permissions — open dedicated Settings page

These permissions cannot be granted via a runtime dialog at all; the user has to flip a switch
in a system Settings page. The plugin opens the right page directly and watches for the toggle.

| Permission | Settings page opened |
| --- | --- |
| `manageExternalStorage` | All files access |
| `systemAlertWindow` | Display over other apps |
| `requestInstallPackages` | Install unknown apps |
| `scheduleExactAlarm` | Alarms & reminders (Android 12+) |
| `ignoreBatteryOptimizations` | Battery optimization |
| `accessNotificationPolicy` | Do Not Disturb access |

### Runtime permissions — auto-back on permanent denial

These go through the normal runtime dialog. If the user has previously denied them twice and the
status is `permanentlyDenied`, the plugin opens the app details page and watches for the user to
toggle the permission on.

`camera`, `microphone`, `location`, `locationWhenInUse`, `locationAlways`, `contacts`, `phone`,
`sms`, `storage`, `photos`, `videos`, `audio`, `notification`, `calendar`, `calendarFullAccess`,
`calendarWriteOnly`, `sensors`, `sensorsAlways`, `bluetooth`, `bluetoothScan`, `bluetoothConnect`,
`bluetoothAdvertise`, `nearbyWifiDevices`, `activityRecognition`, `accessMediaLocation`.

> Note on `locationAlways`: the extension grants foreground location first if needed, then
> hands off to `permission_handler.request()` so the OS itself redirects the user straight
> to the app's location-permission page (Android 11+) or shows the *Allow all the time*
> dialog (Android 10). At the same time the native side polls
> `ACCESS_BACKGROUND_LOCATION` — the moment the user toggles *Allow all the time* the app
> is brought back to the foreground automatically, exactly like the special-permission flow.

### iOS-only permissions

`speech`, `mediaLibrary`, `photosAddOnly`, `reminders`, `appTrackingTransparency`,
`criticalAlerts`, `assistant`, `backgroundRefresh` — these go through `permission_handler`
unchanged. iOS does not support programmatic foreground return, so auto-back is a no-op on iOS.

> If you call `requestWithAutoBack()` on an Android permission that isn't in either of the two
> tables above and it ends up `permanentlyDenied`, the plugin falls back to
> `permission_handler`'s `openAppSettings()` without polling. You will need to detect the grant
> yourself via `AppLifecycleState.resumed`.

## How it works

```
Dart: Permission.manageExternalStorage.requestWithAutoBack()
  └─► MethodChannel("openSettingsAndAutoBack", { permission: "manageExternalStorage" })

Android (PermissionHandlerAutoBackPlugin):
  startActivity(ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
  Handler(mainLooper).postDelayed(check, 500)
    check:
      if Environment.isExternalStorageManager():
        startActivity(launchIntentForPackage(packageName)) with
          FLAG_ACTIVITY_NEW_TASK | CLEAR_TOP | SINGLE_TOP | EXCLUDE_FROM_RECENTS
        result.success(true)
      else if elapsed > 5min:
        result.success(false)
      else:
        repeat in 500ms
```

## FAQ

**Does this work with Flutter add-to-app?**
Yes — the plugin uses `getLaunchIntentForPackage()` to bring the app back, which works with any
launcher Activity registered in your manifest.

**What about iOS?**
iOS apps cannot programmatically return to the foreground from the Settings app. On iOS,
`requestWithAutoBack()` is a passthrough to `Permission.request()`. The user has to navigate
back manually. Listen to `AppLifecycleState.resumed` to refresh permission status.

**Can I have two auto-back flows in flight?**
No. Starting a second request cancels the first; the first call's future resolves to
`PermissionStatus.denied`.

## Contributing

Issues and pull requests are welcome at
<https://github.com/lequangkydev/permission_handler_auto_back>.

## License

MIT — see [LICENSE](LICENSE).
