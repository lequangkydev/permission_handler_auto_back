import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Web registrar required by Flutter's plugin tooling. The auto-back flow
/// is Android-only; on web `requestWithAutoBack` delegates to
/// `permission_handler`'s web implementation, so [registerWith] has
/// nothing to do here.
class PermissionHandlerAutoBackWeb {
  static void registerWith(Registrar registrar) {}
}
