import 'package:flutter/services.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/ble_capture_request.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/ble_scan_event_model.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/models/ble_scan_snapshot_model.dart';

/// Android platform-channel data source. It contains no navigation rules.
class BlePlatformDataProvider {
  const BlePlatformDataProvider();

  static const _methods = MethodChannel('com.uitopic.rumbo/ble_scan');
  static const _events = EventChannel('com.uitopic.rumbo/ble_scan/events');

  Stream<BleScanEventModel> get events =>
      _events.receiveBroadcastStream().map(BleScanEventModel.fromPlatform);

  Future<void> discover() => _methods.invokeMethod<void>('discover');

  Future<void> startCapture(BleCaptureRequest request) {
    return _methods.invokeMethod<void>('startCapture', request.toMap());
  }

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  Future<bool> exportCsv() async =>
      await _methods.invokeMethod<bool>('exportCsv') ?? false;

  Future<int> androidSdkVersion() async {
    return await _methods.invokeMethod<int>('androidSdkVersion') ?? 0;
  }

  Future<BleScanSnapshotModel> snapshot() async {
    final result = await _methods.invokeMapMethod<Object?, Object?>('snapshot');
    if (result == null) throw PlatformException(code: 'EMPTY_SNAPSHOT');
    return BleScanSnapshotModel(result);
  }
}
