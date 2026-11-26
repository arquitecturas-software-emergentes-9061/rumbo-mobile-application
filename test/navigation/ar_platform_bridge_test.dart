import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/data_sources/ar_platform_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionChannel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );
  const arChannel = MethodChannel('com.uitopic.rumbo/ar');
  const bridge = ArPlatformBridge();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(permissionChannel, null);
    messenger.setMockMethodCallHandler(arChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('waits for camera permission before opening each Unity mode', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(permissionChannel, (call) async {
      calls.add(call.method);
      expect(call.arguments, [Permission.camera.value]);
      return {Permission.camera.value: PermissionStatus.granted.index};
    });
    messenger.setMockMethodCallHandler(arChannel, (call) async {
      calls.add(call.method);
      return null;
    });

    await bridge.openDemo(90);
    await bridge.openNavigation('Cardiología');

    expect(calls, [
      'requestPermissions',
      'openDemo',
      'requestPermissions',
      'openNavigation',
    ]);
  });

  test('keeps Flutter open when the user denies camera permission', () async {
    messenger.setMockMethodCallHandler(permissionChannel, (_) async {
      return {Permission.camera.value: PermissionStatus.denied.index};
    });
    messenger.setMockMethodCallHandler(arChannel, (_) async {
      fail('Unity opened without camera permission');
    });

    await expectLater(
      bridge.openDemo(90),
      throwsA(
        isA<PlatformException>().having(
          (error) => error.code,
          'code',
          'CAMERA_PERMISSION_REQUIRED',
        ),
      ),
    );
  });
}
