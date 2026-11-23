import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ArPlatformBridge {
  const ArPlatformBridge();

  static const _methods = MethodChannel('com.uitopic.rumbo/ar');
  static const _events = EventChannel('com.uitopic.rumbo/ar/events');
  static final _sharedEvents = _events.receiveBroadcastStream().map(
    (event) => Map<Object?, Object?>.from(event as Map),
  );

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<Object?, Object?>> get events {
    if (!isSupportedPlatform) return const Stream.empty();
    return _sharedEvents;
  }

  Future<void> openDemo(double headingDegrees) async {
    if (!isSupportedPlatform) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'El prototipo AR requiere Android.',
      );
    }
    await _methods.invokeMethod<void>('openDemo', {
      'headingDegrees': headingDegrees,
    });
  }

  Future<bool> exportTrackingCsv() async {
    if (!isSupportedPlatform) {
      throw PlatformException(
        code: 'UNSUPPORTED',
        message: 'La exportación AR requiere Android.',
      );
    }
    return await _methods.invokeMethod<bool>('exportTrackingCsv') ?? false;
  }

  Future<void> suspend() async {
    if (isSupportedPlatform) await _methods.invokeMethod<void>('suspend');
  }
}
