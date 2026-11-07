import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_snapshot.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_capture_session.dart';

abstract class BleDiagnosticsRepository<T extends BleCaptureSession> {
  Stream<BleScanEvent> get events;

  Future<void> discover();
  Future<void> startCapture(T configuration);
  Future<void> stop();
  Future<BleScanSnapshot> snapshot();
}
