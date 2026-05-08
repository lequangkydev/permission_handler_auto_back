// Smoke integration test — verifies that the plugin's method channel is
// reachable on the host platform. Permission grants cannot be exercised
// without user interaction, so the assertion is intentionally light.

import 'package:permission_handler_auto_back/permission_handler_auto_back.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cancelPermissionAutoBack does not throw', (tester) async {
    await cancelPermissionAutoBack();
    expect(true, isTrue);
  });
}
