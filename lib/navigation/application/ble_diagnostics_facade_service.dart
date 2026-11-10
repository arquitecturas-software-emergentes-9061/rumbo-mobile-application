import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_scan_snapshot.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/ble_capture_session.dart';
import 'package:rumbo_mobile_application/navigation/domain/repositories/ble_diagnostics_repository.dart';
import 'package:rumbo_mobile_application/navigation/infrastructure/permissions/ble_permission_service.dart';

/// Coordinates diagnostic use cases without exposing platform APIs to the UI.
class BleDiagnosticsFacadeService<T extends BleCaptureSession> {
  const BleDiagnosticsFacadeService({
    required this.bleDiagnosticsRepository,
    required this.blePermissionService,
  });

  final BleDiagnosticsRepository<T> bleDiagnosticsRepository;
  final BlePermissionService blePermissionService;

  Stream<BleScanEvent> get events => bleDiagnosticsRepository.events;

  Future<bool> discover() async {
    if (!await blePermissionService.requestScanPermissions()) return false;
    await bleDiagnosticsRepository.discover();
    return true;
  }

  Future<bool> startCapture(T configuration) async {
    if (!await blePermissionService.requestScanPermissions()) return false;
    await bleDiagnosticsRepository.startCapture(configuration);
    return true;
  }

  Future<void> stop() => bleDiagnosticsRepository.stop();

  Future<bool> startReferenceAdvertiser(String serviceUuid) async {
    if (!await blePermissionService.requestAdvertisePermission()) return false;
    await bleDiagnosticsRepository.startReferenceAdvertiser(serviceUuid);
    return true;
  }

  Future<void> stopReferenceAdvertiser() =>
      bleDiagnosticsRepository.stopReferenceAdvertiser();

  Future<BleScanSnapshot> snapshot() => bleDiagnosticsRepository.snapshot();

  Future<void> openSettings() => blePermissionService.openSettings();
}
