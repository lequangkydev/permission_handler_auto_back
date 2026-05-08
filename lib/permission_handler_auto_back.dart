/// Wrapper around `permission_handler` that brings your Flutter app back to
/// the foreground on Android once the user grants a permission from the
/// system Settings page.
///
/// On iOS this library is a thin re-export of `permission_handler` — iOS
/// does not allow apps to programmatically come back to the foreground from
/// Settings, so the auto-back behaviour is Android-only.
library;

export 'package:permission_handler/permission_handler.dart';

export 'src/permission_auto_back.dart';
