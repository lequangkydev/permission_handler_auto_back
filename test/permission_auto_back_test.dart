import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler_auto_back/permission_handler_auto_back.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('permission_handler_auto_back');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          if (call.method == 'openSettingsAndAutoReturn') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'cancelPermissionAutoBack invokes the cancel method on Android',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      await cancelPermissionAutoBack();

      expect(log, hasLength(1));
      expect(log.single.method, 'cancel');
    },
  );

  test('cancelPermissionAutoBack is a no-op on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    await cancelPermissionAutoBack();

    expect(log, isEmpty);
  });
}
