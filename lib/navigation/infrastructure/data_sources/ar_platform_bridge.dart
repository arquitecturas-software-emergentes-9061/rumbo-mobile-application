import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ArPlatformBridge {
  const ArPlatformBridge();

  static const _methods = MethodChannel('com.uitopic.rumbo/ar');
  static const _events = EventChannel('com.uitopic.rumbo/ar/events');

  bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Stream<Map<Object?, Object?>> get events {
    if (!isSupportedPlatform) return const Stream.empty();
    return _events.receiveBroadcastStream().map(
      (event) => Map<Object?, Object?>.from(event as Map),
    );
  }

  Future<void> openDemo(double headingDegrees) async {
    if (!isSupportedPlatform) {
      throw PlatformException(code: 'UNSUPPORTED', message: 'El prototipo AR requiere Android.');
    }
    await _methods.invokeMethod<void>('openDemo', {
      'headingDegrees': headingDegrees,
    });
  }
}
